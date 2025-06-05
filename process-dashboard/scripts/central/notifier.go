package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// Alert represents a single Alertmanager alert in the webhook payload.
type Alert struct {
	Status       string            `json:"status"`       // "firing" or "resolved"
	Labels       map[string]string `json:"labels"`       // alert labels (e.g., "alertname", "host", "severity")
	Annotations  map[string]string `json:"annotations"`  // optional annotations (e.g., "summary", "description")
	StartsAt     time.Time         `json:"startsAt"`     // when alert started
	EndsAt       time.Time         `json:"endsAt"`       // when alert ended (if resolved)
	GeneratorURL string            `json:"generatorURL"` // link to Prometheus instance
}

// AlertmanagerPayload is the top‐level structure sent by Alertmanager.
type AlertmanagerPayload struct {
	Alerts []Alert `json:"alerts"`
	// Many other fields exist (status, groupLabels, etc.), but we only need Alerts[] for now.
}

// Configuration flags (with environment‐variable fallbacks)
var (
	addr           = flag.String("addr", ":9090", "Address to listen on (e.g., ':9090')")
	slackWebhook   = flag.String("slack-webhook", os.Getenv("SLACK_WEBHOOK"), "Slack webhook URL")
	pagerDutyToken = flag.String("pagerduty-token", os.Getenv("PAGERDUTY_TOKEN"), "PagerDuty API token")
	smtpHost       = flag.String("smtp-host", os.Getenv("SMTP_HOST"), "SMTP server host:port")
)

// dispatchNotification is a stub that would eventually send out notifications.
// For now, it logs a dummy JSON payload to stdout.
func dispatchNotification(channel, message string) {
	// Build a dummy payload
	payload := map[string]string{
		"channel": channel,
		"message": message,
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		log.Printf("[ERROR] Failed to marshal dispatch payload: %v\n", err)
		return
	}
	log.Printf("[INFO] Dispatching alert: %s\n", string(encoded))
}

func main() {
	flag.Parse()

	// Basic validation: ensure at least one channel is configured, otherwise warn
	if *slackWebhook == "" && *pagerDutyToken == "" && *smtpHost == "" {
		log.Println("[WARN] No notification channels configured (SLACK_WEBHOOK, PAGERDUTY_TOKEN, SMTP_HOST). All dispatches will be no‐ops.")
	}

	http.HandleFunc("/alert", alertHandler)

	server := &http.Server{
		Addr:         *addr,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
		IdleTimeout:  15 * time.Second,
	}

	log.Printf("Starting notifier on %s (POST /alert)\n", *addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Notifier server failed: %v", err)
	}
}

// alertHandler processes POST /alert requests from Alertmanager (webhook).
func alertHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST is allowed", http.StatusMethodNotAllowed)
		return
	}
	if r.URL.Path != "/alert" {
		http.NotFound(w, r)
		return
	}

	// Limit body size to avoid abuse (e.g., 512 KB)
	const maxBody = 512 << 10
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)
	defer r.Body.Close()

	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("[ERROR] Error reading request body: %v\n", err)
		http.Error(w, "Unable to read request body", http.StatusBadRequest)
		return
	}

	// Unmarshal into AlertmanagerPayload
	var payload AlertmanagerPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		log.Printf("[ERROR] Invalid JSON payload: %v\n", err)
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// For each alert, build a simple message and dispatch to all configured channels
	for _, alert := range payload.Alerts {
		// Example: host might be in alert.Labels["host"], alertname in alert.Labels["alertname"]
		host := alert.Labels["host"]
		alertName := alert.Labels["alertname"]
		status := alert.Status
		message := fmt.Sprintf("Host '%s' alert '%s' is %s", host, alertName, status)

		// Dispatch to Slack if configured
		if *slackWebhook != "" {
			dispatchNotification("slack", message)
			// (In a real implementation, you'd HTTP POST to slackWebhook with a JSON payload.)
		}

		// Dispatch to PagerDuty if configured
		if *pagerDutyToken != "" {
			dispatchNotification("pagerduty", message)
			// (In a real implementation, you'd call PagerDuty Events API.)
		}

		// Dispatch via email if configured
		if *smtpHost != "" {
			dispatchNotification("email", message)
			// (In a real implementation, you'd connect to smtpHost and send an email.)
		}
	}

	// Respond with 200 OK
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Received"))
}
