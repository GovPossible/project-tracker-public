#!/bin/bash
# health-check.sh — Run every 30 minutes to verify the agent is operational
# Sends SMS alert if the orchestrator hasn't run successfully recently.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/claude-agent/orchestrator.log"
HEALTH_FILE="$HOME/.claude-agent/last_healthy"
ALERT_COOLDOWN_FILE="$HOME/.claude-agent/last_alert"
ALERT_COOLDOWN_SECONDS=3600  # Don't alert more than once per hour

# Load config for Twilio
CONFIG_FILE="$SCRIPT_DIR/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 1
fi
set -a
source "$CONFIG_FILE"
set +a

send_sms_alert() {
  local message="$1"
  if [[ -n "${TWILIO_ACCOUNT_SID:-}" && -n "${TWILIO_AUTH_TOKEN:-}" ]]; then
    curl -sf -X POST \
      "https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json" \
      -u "${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}" \
      --data-urlencode "From=${TWILIO_FROM}" \
      --data-urlencode "To=${TWILIO_TO}" \
      --data-urlencode "Body=[Agent] ${message}" \
      >/dev/null 2>&1 || true
  fi
}

should_alert() {
  if [[ ! -f "$ALERT_COOLDOWN_FILE" ]]; then
    return 0
  fi
  local last_alert
  last_alert=$(cat "$ALERT_COOLDOWN_FILE")
  local now
  now=$(date +%s)
  if (( now - last_alert > ALERT_COOLDOWN_SECONDS )); then
    return 0
  fi
  return 1
}

record_alert() {
  mkdir -p "$(dirname "$ALERT_COOLDOWN_FILE")"
  date +%s > "$ALERT_COOLDOWN_FILE"
}

# Check if log file exists and has been written to in the last 30 minutes
if [[ ! -f "$LOG_FILE" ]]; then
  if should_alert; then
    send_sms_alert "Orchestrator log file missing. Agent may not be configured."
    record_alert
  fi
  exit 1
fi

# Check the last log entry timestamp
last_log_time=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo "0")
now=$(date +%s)
age=$(( now - last_log_time ))

if (( age > 1800 )); then  # 30 minutes
  if should_alert; then
    send_sms_alert "Orchestrator hasn't logged in ${age}s. Cron may be stopped."
    record_alert
  fi
  exit 1
fi

# Check if the last run had errors
last_line=$(tail -1 "$LOG_FILE" 2>/dev/null || echo "")
if echo "$last_line" | grep -qi "ERROR.*auth\|ERROR.*token\|ERROR.*expired"; then
  if should_alert; then
    send_sms_alert "Claude Code auth error detected. Run 'claude login' on VPS."
    record_alert
  fi
  exit 1
fi

# All good — record healthy timestamp
mkdir -p "$(dirname "$HEALTH_FILE")"
date +%s > "$HEALTH_FILE"
