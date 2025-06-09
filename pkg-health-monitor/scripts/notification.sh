#!/usr/bin/env bash
# scripts/notification.sh — email & Slack notification functions
set -euo pipefail
IFS=$'\n\t'

# send_email <subject> <body>
function send_email() {
    local subject="$1"
    local body="$2"

    if [[ -z "${EMAIL_RECIPIENT:-}" ]]; then
        echo "⚠️  Skipping email: no EMAIL_RECIPIENT configured"
        return 0
    fi

    echo "${body}" | mailx -s "${subject}" "${EMAIL_RECIPIENT}" &&
        echo "✅ Email sent to ${EMAIL_RECIPIENT}" ||
        echo "❌ Failed to send email to ${EMAIL_RECIPIENT}"
}

# send_slack <message>
function send_slack() {
    local message="$1"

    if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
        echo "⚠️  Skipping Slack: no SLACK_WEBHOOK_URL configured"
        return 0
    fi

    # prepend prefix if set
    if [[ -n "${SLACK_MESSAGE_PREFIX:-}" ]]; then
        message="${SLACK_MESSAGE_PREFIX} ${message}"
    fi

    local payload
    payload=$(printf '{"text":"%s"}' "${message}")

    curl -s -X POST -H 'Content-Type: application/json' --data "${payload}" "${SLACK_WEBHOOK_URL}" &&
        echo "✅ Slack notification sent" ||
        echo "❌ Slack notification failed"
}
