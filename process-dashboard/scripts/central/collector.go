package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"flag"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// AgentPayload represents the JSON structure sent by collector.sh
type AgentPayload struct {
	Timestamp string          `json:"timestamp"`
	Host      string          `json:"host"`
	Metrics   json.RawMessage `json:"metrics"`
}

func main() {
	// Command-line flags / environment fallbacks
	var (
		addr      = flag.String("addr", ":8443", "Address to listen on (e.g., ':8443')")
		tlsCert   = flag.String("tls-cert", os.Getenv("TLS_CERT"), "Path to server TLS certificate (PEM)")
		tlsKey    = flag.String("tls-key", os.Getenv("TLS_KEY"), "Path to server TLS private key (PEM)")
		caBundle  = flag.String("ca-bundle", os.Getenv("CA_BUNDLE"), "Path to CA bundle for mTLS client cert verification (PEM)")
	)
	flag.Parse()

	// Validate required flags
	if *tlsCert == "" || *tlsKey == "" || *caBundle == "" {
		log.Fatal("tls-cert, tls-key, and ca-bundle must all be provided (via flags or environment variables)")
	}

	// Load server certificate and key
	serverCert, err := tls.LoadX509KeyPair(*tlsCert, *tlsKey)
	if err != nil {
		log.Fatalf("Failed to load server certificate/key: %v", err)
	}

	// Load CA bundle to verify client certificates
	caCertPEM, err := os.ReadFile(*caBundle)
	if err != nil {
		log.Fatalf("Failed to read CA bundle: %v", err)
	}
	caCertPool := x509.NewCertPool()
	if !caCertPool.AppendCertsFromPEM(caCertPEM) {
		log.Fatal("Failed to append CA bundle to pool")
	}

	// Configure TLS to require and verify client certificates
	tlsConfig := &tls.Config{
		Certificates: []tls.Certificate{serverCert},
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    caCertPool,
		MinVersion:   tls.VersionTLS12,
	}

	server := &http.Server{
		Addr:         *addr,
		Handler:      http.HandlerFunc(metricsHandler),
		TLSConfig:    tlsConfig,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  30 * time.Second,
	}

	log.Printf("Starting collector on %s (TLS, mTLS required)\n", *addr)
	if err := server.ListenAndServeTLS("", ""); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed: %v", err)
	}
}

// metricsHandler handles POST /metrics requests
func metricsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}

	// Ensure URL path is exactly /metrics
	if r.URL.Path != "/metrics" {
		http.NotFound(w, r)
		return
	}

	// Limit body size to prevent abuse (e.g., 1MB)
	const maxBody = 1 << 20
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)

	// Read full body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("Error reading body: %v", err)
		http.Error(w, "Unable to read request body", http.StatusBadRequest)
		return
	}

	// Parse JSON into AgentPayload
	var payload AgentPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		log.Printf("Invalid JSON payload: %v", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// For now, just log the received payload on stdout
	log.Printf("Received metrics from host=%s at timestamp=%s, raw metrics=%s\n",
		payload.Host, payload.Timestamp, string(payload.Metrics),
	)

	// Respond with 200 OK
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}
