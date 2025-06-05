package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

// SimpleHost represents a host entry in the /api/v1/hosts response.
type SimpleHost struct {
	Host     string `json:"host"`
	LastSeen string `json:"lastSeen"`
}

// jwtMiddleware is a stub that checks for an Authorization: Bearer <token> header.
// If missing or not starting with "Bearer ", it returns HTTP 401 Unauthorized.
// In a real implementation, you would validate the JWT signature, claims, etc.
func jwtMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
			return
		}
		parts := strings.Fields(authHeader)
		if len(parts) != 2 || parts[0] != "Bearer" || parts[1] == "" {
			http.Error(w, "Invalid Authorization header", http.StatusUnauthorized)
			return
		}
		// In a real implementation, validate parts[1] (the token) here.
		next.ServeHTTP(w, r)
	})
}

// healthzHandler responds with a simple JSON health check.
func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	resp := map[string]string{"status": "ok"}
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// prometheusHandler returns a dummy Prometheus metric.
func prometheusHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	// In a real implementation, this would reflect actual uptime or metrics.
	uptimeMetric := "proc_dash_uptime_seconds 1234\n"
	w.Write([]byte(uptimeMetric))
}

// hostsHandler returns a JSON array of hosts.
// Currently returns a static skeleton; in future, it would query a store.
func hostsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Example static data; ideally, this comes from an in-memory or persistent store.
	hosts := []SimpleHost{
		{
			Host:     "host1",
			LastSeen: time.Now().UTC().Format(time.RFC3339),
		},
		{
			Host:     "host2",
			LastSeen: time.Now().Add(-5 * time.Minute).UTC().Format(time.RFC3339),
		},
	}

	if err := json.NewEncoder(w).Encode(hosts); err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func main() {
	// Read address from environment or default to ":8080"
	addr := os.Getenv("API_ADDR")
	if addr == "" {
		addr = ":8080"
	}

	mux := http.NewServeMux()

	// Public endpoint (no auth)
	mux.HandleFunc("/healthz", healthzHandler)

	// Protected endpoints
	protected := http.NewServeMux()
	protected.HandleFunc("/metrics/prometheus", prometheusHandler)
	protected.HandleFunc("/api/v1/hosts", hostsHandler)

	// Wrap protected endpoints with JWT middleware
	mux.Handle("/metrics/prometheus", jwtMiddleware(protected))
	mux.Handle("/api/v1/hosts", jwtMiddleware(protected))

	server := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
		IdleTimeout:  15 * time.Second,
	}

	log.Printf("Starting API server on %s\n", addr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("API server failed: %v", err)
	}
}
