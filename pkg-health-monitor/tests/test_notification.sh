#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFY_SH="${SCRIPT_ROOT}/scripts/notification.sh"

function mailx() { echo "mailx got args: $*"; }
function curl() { echo "curl got args: $*"; }

source "${NOTIFY_SH}"

export EMAIL_RECIPIENT="test@example.com"
export EMAIL_SUBJECT="TestSubject"
EMAIL_OUT=$(send_email "TestSubject" "This is a test")
echo "${EMAIL_OUT}" | grep -q "mailx got args:" ||
    {
        echo "❌ send_email did not invoke mailx"
        exit 1
    }

export SLACK_WEBHOOK_URL="https://example.com/hook"
export SLACK_MESSAGE_PREFIX="[Test]"
SLACK_OUT=$(send_slack "Hello Slack")
echo "${SLACK_OUT}" | grep -q "curl got args:" ||
    {
        echo "❌ send_slack did not invoke curl"
        exit 1
    }

echo "✅ Notification tests passed."
