package main

import (
	"bytes"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const maxRequestBytes = 25 << 20

type hermesPayload struct {
	Transcription string `json:"transcription"`
	RecordedAt    string `json:"recordedAt"`
	Client        string `json:"client,omitempty"`
}

func readCredential(name, variable string) string {
	dir := os.Getenv("CREDENTIALS_DIRECTORY")
	if dir != "" {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err == nil {
			value := strings.TrimSpace(string(data))
			return strings.TrimSpace(strings.TrimPrefix(value, variable+"="))
		}
	}
	value := strings.TrimSpace(os.Getenv(variable))
	return strings.TrimSpace(strings.TrimPrefix(value, variable+"="))
}

func main() {
	webhookSecret := readCredential("pebble-webhook-secret", "PEBBLE_WEBHOOK_SECRET")
	hermesSecret := readCredential("hermes-webhook-secret", "WEBHOOK_SECRET")
	if webhookSecret == "" || hermesSecret == "" {
		log.Fatal("Pebble and Hermes webhook credentials are required")
	}

	hermesURL := strings.TrimRight(os.Getenv("HERMES_WEBHOOK_URL"), "/")
	if hermesURL == "" {
		hermesURL = "http://127.0.0.1:8644/webhooks"
	}

	client := &http.Client{Timeout: 10 * time.Second}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /transcript", func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		auth := strings.TrimPrefix(authHeader, "Bearer ")
		if len(auth) != len(webhookSecret) || subtle.ConstantTimeCompare([]byte(auth), []byte(webhookSecret)) != 1 {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		function := strings.ToLower(strings.TrimSpace(r.Header.Get("function")))
		route := ""
		switch function {
		case "agent":
			route = "pebble-agent"
		case "search":
			route = "pebble-search"
		default:
			http.Error(w, "function must be agent or search", http.StatusBadRequest)
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, maxRequestBytes)
		if err := r.ParseMultipartForm(8 << 20); err != nil {
			status := http.StatusBadRequest
			if strings.Contains(err.Error(), "request body too large") {
				status = http.StatusRequestEntityTooLarge
			}
			http.Error(w, "invalid or oversized multipart form", status)
			return
		}
		if r.MultipartForm != nil {
			defer r.MultipartForm.RemoveAll()
		}

		// Intercept Pebble app test pings
		if r.FormValue("test") == "true" {
			log.Printf("received Pebble test ping for function=%s", function)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(w, `{"status":"test_ok"}`)
			return
		}

		transcription := strings.TrimSpace(r.FormValue("transcription"))
		if transcription == "" {
			http.Error(w, "transcription is required", http.StatusBadRequest)
			return
		}
		recordedAt := strings.TrimSpace(r.FormValue("recordedAt"))
		if recordedAt == "" {
			recordedAt = time.Now().UTC().Format(time.RFC3339)
		}

		payload, err := json.Marshal(hermesPayload{
			Transcription: transcription,
			RecordedAt:    recordedAt,
			Client:        strings.TrimSpace(r.FormValue("client")),
		})
		if err != nil {
			http.Error(w, "could not encode request", http.StatusInternalServerError)
			return
		}

		digest := sha256.Sum256(append(append([]byte(function+"\x00"), []byte(recordedAt+"\x00")...), []byte(transcription)...))
		requestID := hex.EncodeToString(digest[:])
		upstream, err := http.NewRequestWithContext(r.Context(), http.MethodPost, hermesURL+"/"+route, bytes.NewReader(payload))
		if err != nil {
			http.Error(w, "could not create upstream request", http.StatusInternalServerError)
			return
		}
		upstream.Header.Set("Content-Type", "application/json")
		upstream.Header.Set("X-Gitlab-Token", hermesSecret)
		upstream.Header.Set("X-Request-ID", requestID)

		response, err := client.Do(upstream)
		if err != nil {
			log.Printf("Hermes unavailable request_id=%s: %v", requestID, err)
			http.Error(w, "Hermes gateway unavailable", http.StatusBadGateway)
			return
		}
		defer response.Body.Close()
		_, _ = io.Copy(io.Discard, response.Body)
		if response.StatusCode < 200 || response.StatusCode >= 300 {
			log.Printf("Hermes rejected request_id=%s status=%d", requestID, response.StatusCode)
			http.Error(w, "Hermes rejected webhook", http.StatusBadGateway)
			return
		}

		log.Printf("accepted request_id=%s function=%s recorded_at=%s", requestID, function, recordedAt)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		_, _ = io.WriteString(w, `{"status":"accepted"}`)
	})

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"status":"ok"}`)
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = "0.0.0.0:8765"
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}

	log.Printf("Pebble Hermes shim listening on %s", addr)
	log.Fatal(server.ListenAndServe())
}
