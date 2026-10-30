package main

import (
	"context"
	"encoding/base64"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

func newTestServer(t *testing.T, ready bool) *httptest.Server {
	t.Helper()
	var r atomic.Bool
	r.Store(ready)
	srv := httptest.NewServer(newMux("hi there", &r, newMetrics("test")))
	t.Cleanup(srv.Close)
	return srv
}

func get(t *testing.T, url string) (int, string) {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(b)
}

func TestRoutes(t *testing.T) {
	srv := newTestServer(t, true)

	tests := []struct {
		path string
		code int
		body string
	}{
		{"/", 200, "hi there"},
		{"/healthz", 200, "ok"},
		{"/readyz", 200, "ready"},
		{"/nope", 404, ""},
	}
	for _, tt := range tests {
		code, body := get(t, srv.URL+tt.path)
		if code != tt.code || !strings.Contains(body, tt.body) {
			t.Errorf("GET %s = %d %q, want %d containing %q", tt.path, code, body, tt.code, tt.body)
		}
	}
}

func TestNotReadyWhileShuttingDown(t *testing.T) {
	srv := newTestServer(t, false)
	if code, _ := get(t, srv.URL+"/readyz"); code != http.StatusServiceUnavailable {
		t.Fatalf("readyz = %d, want 503", code)
	}
}

func TestMetrics(t *testing.T) {
	srv := newTestServer(t, true)
	get(t, srv.URL+"/")
	get(t, srv.URL+"/random-path")

	_, body := get(t, srv.URL+"/metrics")
	for _, want := range []string{
		`demo_app_build_info{version="test"} 1`,
		`http_requests_total{method="GET",path="/",code="200"} 1`,
		`http_requests_total{method="GET",path="other",code="404"} 1`,
		`http_request_duration_seconds_count`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("metrics missing %q\n%s", want, body)
		}
	}
}

func TestFetchSecret(t *testing.T) {
	fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.HasSuffix(r.URL.Path, "/token"):
			if r.Header.Get("Metadata-Flavor") != "Google" {
				http.Error(w, "missing header", http.StatusForbidden)
				return
			}
			_, _ = io.WriteString(w, `{"access_token":"tok"}`)
		case strings.HasSuffix(r.URL.Path, "/versions/latest:access"):
			if r.Header.Get("Authorization") != "Bearer tok" {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			data := base64.StdEncoding.EncodeToString([]byte("from secret manager"))
			_, _ = io.WriteString(w, `{"payload":{"data":"`+data+`"}}`)
		default:
			http.NotFound(w, r)
		}
	}))
	defer fake.Close()

	got, err := fetchSecret(context.Background(), fake.Client(), fake.URL, fake.URL, "projects/p/secrets/s")
	if err != nil {
		t.Fatal(err)
	}
	if got != "from secret manager" {
		t.Fatalf("got %q", got)
	}
}
