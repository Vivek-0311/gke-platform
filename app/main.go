// demo-app: a small HTTP service used to show the platform working end to end.
//
//   - GET /         returns a greeting loaded from Secret Manager at startup
//   - GET /healthz  liveness probe
//   - GET /readyz   readiness probe (fails while shutting down)
//   - GET /metrics  Prometheus metrics (requests, latency, build info)
//
// The secret is fetched with Workload Identity: the pod asks the GKE metadata
// server for a short-lived token, then calls the Secret Manager REST API.
// No service-account keys and no client libraries are involved.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"
)

var version = "dev" // set at build time with -ldflags "-X main.version=<sha>"

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	greeting := os.Getenv("GREETING")
	if greeting == "" {
		greeting = "Hello from GKE!"
	}

	if secret := os.Getenv("GREETING_SECRET"); secret != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		value, err := fetchSecret(ctx, http.DefaultClient, metadataURL, secretManagerURL, secret)
		cancel()
		if err != nil {
			slog.Warn("could not read secret, using default greeting", "secret", secret, "error", err)
		} else {
			greeting = value
			slog.Info("greeting loaded from Secret Manager", "secret", secret)
		}
	}

	var ready atomic.Bool
	ready.Store(true)

	m := newMetrics(version)
	srv := &http.Server{
		Addr:              ":" + envOr("PORT", "8080"),
		Handler:           newMux(greeting, &ready, m),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		slog.Info("starting", "addr", srv.Addr, "version", version)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	// Graceful shutdown: stop reporting ready, let the load balancer drain,
	// then finish in-flight requests.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop

	slog.Info("shutting down")
	ready.Store(false)
	time.Sleep(drainDelay())

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("shutdown error", "error", err)
	}
}

func newMux(greeting string, ready *atomic.Bool, m *metrics) http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte(greeting + "\n"))
	})

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("ok\n"))
	})

	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if !ready.Load() {
			http.Error(w, "shutting down", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ready\n"))
	})

	mux.Handle("GET /metrics", m)

	return m.instrument(mux)
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func drainDelay() time.Duration {
	d, err := time.ParseDuration(envOr("DRAIN_DELAY", "5s"))
	if err != nil {
		return 5 * time.Second
	}
	return d
}
