package main

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"sync"
	"time"
)

// A tiny Prometheus exporter (text format) so the app has no dependencies.

var latencyBuckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5}

type metrics struct {
	version string

	mu       sync.Mutex
	requests map[[3]string]uint64 // method, path, code -> count
	buckets  []uint64             // cumulative counts per latencyBuckets entry
	count    uint64
	sum      float64
}

func newMetrics(version string) *metrics {
	return &metrics{
		version:  version,
		requests: map[[3]string]uint64{},
		buckets:  make([]uint64, len(latencyBuckets)),
	}
}

type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

// instrument records count and latency for every request. Unknown paths are
// grouped as "other" so random URLs can't blow up label cardinality.
func (m *metrics) instrument(next http.Handler) http.Handler {
	known := map[string]bool{"/": true, "/healthz": true, "/readyz": true, "/metrics": true}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, code: http.StatusOK}
		next.ServeHTTP(rec, r)
		elapsed := time.Since(start).Seconds()

		path := r.URL.Path
		if !known[path] {
			path = "other"
		}

		m.mu.Lock()
		defer m.mu.Unlock()
		m.requests[[3]string{r.Method, path, strconv.Itoa(rec.code)}]++
		m.count++
		m.sum += elapsed
		for i, le := range latencyBuckets {
			if elapsed <= le {
				m.buckets[i]++
			}
		}
	})
}

func (m *metrics) ServeHTTP(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")

	m.mu.Lock()
	defer m.mu.Unlock()

	fmt.Fprintln(w, "# HELP demo_app_build_info Build information.")
	fmt.Fprintln(w, "# TYPE demo_app_build_info gauge")
	fmt.Fprintf(w, "demo_app_build_info{version=%q} 1\n", m.version)

	fmt.Fprintln(w, "# HELP http_requests_total HTTP requests by method, path and status code.")
	fmt.Fprintln(w, "# TYPE http_requests_total counter")
	keys := make([][3]string, 0, len(m.requests))
	for k := range m.requests {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		return keys[i][0]+keys[i][1]+keys[i][2] < keys[j][0]+keys[j][1]+keys[j][2]
	})
	for _, k := range keys {
		fmt.Fprintf(w, "http_requests_total{method=%q,path=%q,code=%q} %d\n", k[0], k[1], k[2], m.requests[k])
	}

	fmt.Fprintln(w, "# HELP http_request_duration_seconds Request latency.")
	fmt.Fprintln(w, "# TYPE http_request_duration_seconds histogram")
	for i, le := range latencyBuckets {
		fmt.Fprintf(w, "http_request_duration_seconds_bucket{le=%q} %d\n", strconv.FormatFloat(le, 'f', -1, 64), m.buckets[i])
	}
	fmt.Fprintf(w, "http_request_duration_seconds_bucket{le=\"+Inf\"} %d\n", m.count)
	fmt.Fprintf(w, "http_request_duration_seconds_sum %g\n", m.sum)
	fmt.Fprintf(w, "http_request_duration_seconds_count %d\n", m.count)
}
