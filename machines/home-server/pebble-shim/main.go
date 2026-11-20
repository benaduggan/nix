package main

import (
	"bytes"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log"
	"math"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	maxJSONBytes      = 1 << 20
	maxMultipartBytes = 25 << 20
)

type pebblePayload struct {
	Transcription string          `json:"transcription"`
	RecordedAt    json.RawMessage `json:"recordedAt"`
	Client        string          `json:"client"`
	Test          flexibleBool    `json:"test"`
}

type parsedTranscript struct {
	transcription string
	recordedAt    string
	client        string
	test          bool
}

type hermesPayload struct {
	Transcription string `json:"transcription"`
	RecordedAt    string `json:"recordedAt"`
	Client        string `json:"client,omitempty"`
	Trigger       string `json:"trigger,omitempty"`
}

type flexibleBool bool

func (b *flexibleBool) UnmarshalJSON(data []byte) error {
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		*b = false
		return nil
	}
	var v bool
	if err := json.Unmarshal(trimmed, &v); err == nil {
		*b = flexibleBool(v)
		return nil
	}
	var s string
	if err := json.Unmarshal(trimmed, &s); err == nil {
		s = strings.TrimSpace(s)
		if s == "" {
			*b = false
			return nil
		}
		parsed, err := strconv.ParseBool(s)
		if err != nil {
			return err
		}
		*b = flexibleBool(parsed)
		return nil
	}
	return errors.New("expected boolean or boolean string")
}

func formatUnixTimestamp(v int64) string {
	if v == 0 {
		return ""
	}
	if v >= 1e11 || v <= -1e11 {
		return time.UnixMilli(v).UTC().Format(time.RFC3339)
	}
	return time.Unix(v, 0).UTC().Format(time.RFC3339)
}

func parseRecordedAtString(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	if parsed, err := strconv.ParseInt(s, 10, 64); err == nil {
		return formatUnixTimestamp(parsed)
	}
	return s
}

func parseRecordedAt(raw json.RawMessage) (string, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return "", nil
	}

	var n int64
	if err := json.Unmarshal(trimmed, &n); err == nil {
		return formatUnixTimestamp(n), nil
	}

	var f float64
	if err := json.Unmarshal(trimmed, &f); err == nil {
		if math.IsNaN(f) || math.IsInf(f, 0) {
			return "", errors.New("invalid recordedAt timestamp")
		}
		return formatUnixTimestamp(int64(f)), nil
	}

	var s string
	if err := json.Unmarshal(trimmed, &s); err == nil {
		return parseRecordedAtString(s), nil
	}

	return "", errors.New("recordedAt must be a unix timestamp or string")
}

func parseJSONRequest(w http.ResponseWriter, r *http.Request) (parsedTranscript, int, string) {
	r.Body = http.MaxBytesReader(w, r.Body, maxJSONBytes)
	var incoming pebblePayload
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&incoming); err != nil {
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) {
			return parsedTranscript{}, http.StatusRequestEntityTooLarge, "request body too large"
		}
		return parsedTranscript{}, http.StatusBadRequest, "invalid JSON payload"
	}
	if err := dec.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return parsedTranscript{}, http.StatusBadRequest, "invalid JSON payload"
	}

	recordedAt, err := parseRecordedAt(incoming.RecordedAt)
	if err != nil {
		return parsedTranscript{}, http.StatusBadRequest, "invalid recordedAt value"
	}

	return parsedTranscript{
		transcription: strings.TrimSpace(incoming.Transcription),
		recordedAt:    recordedAt,
		client:        strings.TrimSpace(incoming.Client),
		test:          bool(incoming.Test),
	}, 0, ""
}

func parseMultipartRequest(w http.ResponseWriter, r *http.Request) (parsedTranscript, int, string) {
	r.Body = http.MaxBytesReader(w, r.Body, maxMultipartBytes)
	if err := r.ParseMultipartForm(8 << 20); err != nil {
		status := http.StatusBadRequest
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) || strings.Contains(err.Error(), "request body too large") {
			status = http.StatusRequestEntityTooLarge
		}
		return parsedTranscript{}, status, "invalid or oversized multipart form"
	}
	if r.MultipartForm != nil {
		defer r.MultipartForm.RemoveAll()
	}

	return parsedTranscript{
		transcription: strings.TrimSpace(r.FormValue("transcription")),
		recordedAt:    parseRecordedAtString(r.FormValue("recordedAt")),
		client:        strings.TrimSpace(r.FormValue("client")),
		test:          strings.EqualFold(strings.TrimSpace(r.FormValue("test")), "true"),
	}, 0, ""
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

func newHandler(webhookSecret, hermesSecret, hermesURL string, client *http.Client) http.Handler {
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

		mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
		if err != nil {
			http.Error(w, "content-type must be application/json or multipart/form-data", http.StatusUnsupportedMediaType)
			return
		}

		var incoming parsedTranscript
		var errStatus int
		var errMsg string
		switch mediaType {
		case "application/json":
			incoming, errStatus, errMsg = parseJSONRequest(w, r)
		case "multipart/form-data":
			incoming, errStatus, errMsg = parseMultipartRequest(w, r)
		default:
			http.Error(w, "content-type must be application/json or multipart/form-data", http.StatusUnsupportedMediaType)
			return
		}
		if errStatus != 0 {
			http.Error(w, errMsg, errStatus)
			return
		}

		trigger := strings.TrimSpace(r.Header.Get("X-Index-Trigger"))

		// Intercept Pebble app test pings
		if incoming.test || strings.EqualFold(trigger, "test") {
			log.Printf("received Pebble test ping for function=%s trigger=%s", function, trigger)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			_, _ = io.WriteString(w, `{"status":"test_ok"}`)
			return
		}

		if incoming.transcription == "" {
			http.Error(w, "transcription is required", http.StatusBadRequest)
			return
		}

		recordedAt := incoming.recordedAt
		if recordedAt == "" {
			recordedAt = time.Now().UTC().Format(time.RFC3339)
		}

		payload, err := json.Marshal(hermesPayload{
			Transcription: incoming.transcription,
			RecordedAt:    recordedAt,
			Client:        incoming.client,
			Trigger:       trigger,
		})
		if err != nil {
			http.Error(w, "could not encode request", http.StatusInternalServerError)
			return
		}

		requestID := strings.TrimSpace(r.Header.Get("X-Index-Delivery"))
		if requestID == "" {
			digest := sha256.Sum256(append(append([]byte(function+"\x00"), []byte(recordedAt+"\x00")...), []byte(incoming.transcription)...))
			requestID = hex.EncodeToString(digest[:])
		}

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

		log.Printf("accepted request_id=%s function=%s trigger=%s recorded_at=%s", requestID, function, trigger, recordedAt)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		_, _ = io.WriteString(w, `{"status":"accepted"}`)
	})

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"status":"ok"}`)
	})

	return mux
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
	handler := newHandler(webhookSecret, hermesSecret, hermesURL, client)

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = "0.0.0.0:8765"
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}

	log.Printf("Pebble Hermes shim listening on %s", addr)
	log.Fatal(server.ListenAndServe())
}
