package main

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func buildMultipartBody(t *testing.T, fields map[string]string) (*bytes.Buffer, string) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	for k, v := range fields {
		if err := mw.WriteField(k, v); err != nil {
			t.Fatalf("failed to write multipart field %q: %v", k, err)
		}
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("failed to close multipart writer: %v", err)
	}
	return &buf, mw.FormDataContentType()
}

func TestTranscriptJSONPayload(t *testing.T) {
	var gotPath string
	var gotToken string
	var gotRequestID string
	var gotPayload hermesPayload

	hermes := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotToken = r.Header.Get("X-Gitlab-Token")
		gotRequestID = r.Header.Get("X-Request-ID")
		if err := json.NewDecoder(r.Body).Decode(&gotPayload); err != nil {
			t.Errorf("failed to decode upstream payload: %v", err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusAccepted)
	}))
	defer hermes.Close()

	handler := newHandler("pebble-secret", "hermes-secret", hermes.URL+"/webhooks", hermes.Client())

	body := `{"transcription":"Testing the new JSON web book style.","recordedAt":1795216032195,"client":"ring"}`
	req := httptest.NewRequest(http.MethodPost, "/transcript", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer pebble-secret")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("function", "agent")
	req.Header.Set("X-Index-Delivery", "ring_EA2E518FBEB0-272-1a97089b-aecf-47b7-a951-6aa2451e39c9")
	req.Header.Set("X-Index-Trigger", "single-click-hold")
	req.Header.Set("X-Index-Webhook-Version", "1")

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d: %s", rec.Code, rec.Body.String())
	}
	if gotPath != "/webhooks/pebble-agent" {
		t.Fatalf("expected upstream path /webhooks/pebble-agent, got %q", gotPath)
	}
	if gotToken != "hermes-secret" {
		t.Fatalf("expected X-Gitlab-Token hermes-secret, got %q", gotToken)
	}
	if gotRequestID != "ring_EA2E518FBEB0-272-1a97089b-aecf-47b7-a951-6aa2451e39c9" {
		t.Fatalf("expected delivery ID as X-Request-ID, got %q", gotRequestID)
	}
	if gotPayload.Transcription != "Testing the new JSON web book style." {
		t.Fatalf("unexpected transcription: %q", gotPayload.Transcription)
	}
	if gotPayload.RecordedAt != "2026-11-20T23:07:12Z" {
		t.Fatalf("expected recordedAt 2026-11-20T23:07:12Z, got %q", gotPayload.RecordedAt)
	}
	if gotPayload.Client != "ring" {
		t.Fatalf("expected client ring, got %q", gotPayload.Client)
	}
	if gotPayload.Trigger != "single-click-hold" {
		t.Fatalf("expected trigger single-click-hold, got %q", gotPayload.Trigger)
	}
}

func TestTranscriptMultipartPayload(t *testing.T) {
	var gotPath string
	var gotRequestID string
	var gotPayload hermesPayload

	hermes := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotRequestID = r.Header.Get("X-Request-ID")
		if err := json.NewDecoder(r.Body).Decode(&gotPayload); err != nil {
			t.Errorf("failed to decode upstream payload: %v", err)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusAccepted)
	}))
	defer hermes.Close()

	handler := newHandler("pebble-secret", "hermes-secret", hermes.URL+"/webhooks", hermes.Client())

	body, contentType := buildMultipartBody(t, map[string]string{
		"transcription": "Legacy multipart transcript",
		"recordedAt":    "2026-11-20T23:07:12Z",
		"client":        "ring",
	})
	req := httptest.NewRequest(http.MethodPost, "/transcript", body)
	req.Header.Set("Authorization", "Bearer pebble-secret")
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("function", "agent")

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d: %s", rec.Code, rec.Body.String())
	}
	if gotPath != "/webhooks/pebble-agent" {
		t.Fatalf("expected upstream path /webhooks/pebble-agent, got %q", gotPath)
	}
	if len(gotRequestID) != 64 {
		t.Fatalf("expected 64-char sha256 fallback request ID, got %q", gotRequestID)
	}
	if gotPayload.Transcription != "Legacy multipart transcript" {
		t.Fatalf("unexpected transcription: %q", gotPayload.Transcription)
	}
	if gotPayload.RecordedAt != "2026-11-20T23:07:12Z" {
		t.Fatalf("expected recordedAt 2026-11-20T23:07:12Z, got %q", gotPayload.RecordedAt)
	}
	if gotPayload.Client != "ring" {
		t.Fatalf("expected client ring, got %q", gotPayload.Client)
	}
}

func TestTranscriptSearchRouteAndFallbackID(t *testing.T) {
	var gotPath string
	var gotRequestID string
	var gotPayload hermesPayload

	hermes := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotRequestID = r.Header.Get("X-Request-ID")
		_ = json.NewDecoder(r.Body).Decode(&gotPayload)
		w.WriteHeader(http.StatusOK)
	}))
	defer hermes.Close()

	handler := newHandler("pebble-secret", "hermes-secret", hermes.URL+"/webhooks", hermes.Client())

	body := `{"transcription":"what is the weather"}`
	req := httptest.NewRequest(http.MethodPost, "/transcript", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer pebble-secret")
	req.Header.Set("Content-Type", "application/json; charset=utf-8")
	req.Header.Set("function", "search")

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d: %s", rec.Code, rec.Body.String())
	}
	if gotPath != "/webhooks/pebble-search" {
		t.Fatalf("expected /webhooks/pebble-search, got %q", gotPath)
	}
	if len(gotRequestID) != 64 {
		t.Fatalf("expected 64-char sha256 fallback request ID, got %q", gotRequestID)
	}
	if _, err := time.Parse(time.RFC3339, gotPayload.RecordedAt); err != nil {
		t.Fatalf("expected valid RFC3339 fallback recordedAt, got %q: %v", gotPayload.RecordedAt, err)
	}
}

func TestTranscriptTestPings(t *testing.T) {
	upstreamCalled := false
	hermes := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		upstreamCalled = true
		w.WriteHeader(http.StatusOK)
	}))
	defer hermes.Close()

	handler := newHandler("pebble-secret", "hermes-secret", hermes.URL+"/webhooks", hermes.Client())

	multipartPing, multipartCT := buildMultipartBody(t, map[string]string{"test": "true"})

	cases := []struct {
		name        string
		contentType string
		body        string
		trigger     string
	}{
		{name: "json bool true", contentType: "application/json", body: `{"test":true}`},
		{name: "json string true", contentType: "application/json", body: `{"test":"true"}`},
		{name: "json trigger header", contentType: "application/json", body: `{"transcription":"ping"}`, trigger: "test"},
		{name: "multipart test true", contentType: multipartCT, body: multipartPing.String()},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/transcript", strings.NewReader(tc.body))
			req.Header.Set("Authorization", "Bearer pebble-secret")
			req.Header.Set("Content-Type", tc.contentType)
			req.Header.Set("function", "agent")
			if tc.trigger != "" {
				req.Header.Set("X-Index-Trigger", tc.trigger)
			}

			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != http.StatusOK {
				t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
			}
			if rec.Body.String() != `{"status":"test_ok"}` {
				t.Fatalf("unexpected body: %s", rec.Body.String())
			}
		})
	}

	if upstreamCalled {
		t.Fatal("expected test pings not to reach Hermes")
	}
}

func TestTranscriptErrors(t *testing.T) {
	hermes := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer hermes.Close()

	handler := newHandler("pebble-secret", "hermes-secret", hermes.URL+"/webhooks", hermes.Client())

	cases := []struct {
		name        string
		auth        string
		function    string
		contentType string
		body        string
		wantStatus  int
	}{
		{
			name:        "missing auth",
			function:    "agent",
			contentType: "application/json",
			body:        `{"transcription":"hello"}`,
			wantStatus:  http.StatusUnauthorized,
		},
		{
			name:        "invalid function",
			auth:        "Bearer pebble-secret",
			function:    "other",
			contentType: "application/json",
			body:        `{"transcription":"hello"}`,
			wantStatus:  http.StatusBadRequest,
		},
		{
			name:        "unsupported media type",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "text/plain",
			body:        `hello`,
			wantStatus:  http.StatusUnsupportedMediaType,
		},
		{
			name:        "malformed multipart",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "multipart/form-data; boundary=abc",
			body:        `not valid multipart`,
			wantStatus:  http.StatusBadRequest,
		},
		{
			name:        "malformed json",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "application/json",
			body:        `{bad`,
			wantStatus:  http.StatusBadRequest,
		},
		{
			name:        "trailing json",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "application/json",
			body:        `{"transcription":"hello"}{"extra":true}`,
			wantStatus:  http.StatusBadRequest,
		},
		{
			name:        "empty transcription",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "application/json",
			body:        `{"transcription":"   "}`,
			wantStatus:  http.StatusBadRequest,
		},
		{
			name:        "invalid recordedAt",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "application/json",
			body:        `{"transcription":"hello","recordedAt":{"bad":true}}`,
			wantStatus:  http.StatusBadRequest,
		},
		{
			name:        "oversized json body",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "application/json",
			body:        `{"transcription":"` + strings.Repeat("a", maxJSONBytes) + `"}`,
			wantStatus:  http.StatusRequestEntityTooLarge,
		},
		{
			name:        "upstream error",
			auth:        "Bearer pebble-secret",
			function:    "agent",
			contentType: "application/json",
			body:        `{"transcription":"hello"}`,
			wantStatus:  http.StatusBadGateway,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/transcript", strings.NewReader(tc.body))
			if tc.auth != "" {
				req.Header.Set("Authorization", tc.auth)
			}
			if tc.function != "" {
				req.Header.Set("function", tc.function)
			}
			if tc.contentType != "" {
				req.Header.Set("Content-Type", tc.contentType)
			}

			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != tc.wantStatus {
				t.Fatalf("expected status %d, got %d: %s", tc.wantStatus, rec.Code, rec.Body.String())
			}
		})
	}
}

func TestParseRecordedAt(t *testing.T) {
	cases := []struct {
		name    string
		raw     string
		want    string
		wantErr bool
	}{
		{name: "unix ms", raw: `1795216032195`, want: "2026-11-20T23:07:12Z"},
		{name: "unix sec", raw: `1795216032`, want: "2026-11-20T23:07:12Z"},
		{name: "numeric string ms", raw: `"1795216032195"`, want: "2026-11-20T23:07:12Z"},
		{name: "rfc3339 string", raw: `"2026-11-20T23:07:12Z"`, want: "2026-11-20T23:07:12Z"},
		{name: "zero", raw: `0`, want: ""},
		{name: "null", raw: `null`, want: ""},
		{name: "empty", raw: ``, want: ""},
		{name: "object error", raw: `{}`, wantErr: true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := parseRecordedAt(json.RawMessage(tc.raw))
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected error, got %q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tc.want {
				t.Fatalf("expected %q, got %q", tc.want, got)
			}
		})
	}
}
