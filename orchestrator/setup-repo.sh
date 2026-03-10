#!/usr/bin/env bash
# Called by the orchestrator to clone and set up a new repo.
# Usage: setup-repo.sh <repo_id> <github_url> <repo_name> [framework] [ruby_version] [gemset]
#
# Reports status back to the dashboard API.
set -euo pipefail

REPO_ID="$1"
GITHUB_URL="$2"
REPO_NAME="$3"
FRAMEWORK="${4:-}"
RUBY_VERSION="${5:-}"
GEMSET="${6:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.env"

REPO_PATH="${WORKSPACE_DIR}/${REPO_NAME}"
LOG=""

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  LOG+="$msg"$'\n'
  echo "$msg"
}

update_status() {
  local status="$1"
  local escaped_log
  escaped_log=$(echo "$LOG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

  curl -s -X PATCH "${DASHBOARD_URL}/api/v1/repos/${REPO_ID}" \
    -H "Authorization: Bearer ${DASHBOARD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"repo\":{\"setup_status\":\"${status}\",\"setup_log\":${escaped_log},\"local_path\":\"${REPO_PATH}\"}}" \
    > /dev/null 2>&1 || true
}

# Mark as setting up
update_status "setting_up"

# Clone the repo
if [ -d "$REPO_PATH" ]; then
  log "Directory $REPO_PATH already exists, pulling latest..."
  cd "$REPO_PATH"
  git pull origin "$(git symbolic-ref --short HEAD)" 2>&1 | while read -r line; do log "$line"; done
else
  log "Cloning $GITHUB_URL into $REPO_PATH..."
  git clone "$GITHUB_URL" "$REPO_PATH" 2>&1 | while read -r line; do log "$line"; done
fi

cd "$REPO_PATH"
log "Working directory: $REPO_PATH"

# Ruby/RVM setup
if [ -n "$RUBY_VERSION" ]; then
  log "Setting up Ruby $RUBY_VERSION via RVM..."
  source "$HOME/.rvm/scripts/rvm"

  if ! rvm list strings | grep -q "$RUBY_VERSION"; then
    log "Installing Ruby $RUBY_VERSION..."
    rvm install "$RUBY_VERSION" --with-openssl-dir=/usr 2>&1 | tail -5 | while read -r line; do log "$line"; done
  else
    log "Ruby $RUBY_VERSION already installed."
  fi

  if [ -n "$GEMSET" ]; then
    log "Creating gemset $GEMSET..."
    rvm "$RUBY_VERSION" do rvm gemset create "$GEMSET" 2>&1 | while read -r line; do log "$line"; done
  fi
fi

# Framework-specific setup
case "$FRAMEWORK" in
  rails)
    log "Running bundle install..."
    if [ -n "$RUBY_VERSION" ] && [ -n "$GEMSET" ]; then
      rvm "$RUBY_VERSION@$GEMSET" do bundle install 2>&1 | tail -5 | while read -r line; do log "$line"; done
    else
      bundle install 2>&1 | tail -5 | while read -r line; do log "$line"; done
    fi

    log "Running db:create and db:migrate..."
    if [ -n "$RUBY_VERSION" ] && [ -n "$GEMSET" ]; then
      rvm "$RUBY_VERSION@$GEMSET" do bundle exec bin/rails db:create db:migrate 2>&1 | while read -r line; do log "$line"; done || log "DB setup had warnings (may already exist)"
    else
      bundle exec bin/rails db:create db:migrate 2>&1 | while read -r line; do log "$line"; done || log "DB setup had warnings (may already exist)"
    fi
    ;;
  node)
    log "Running npm install..."
    npm install 2>&1 | tail -5 | while read -r line; do log "$line"; done
    ;;
  *)
    log "No framework-specific setup."
    ;;
esac

log "Setup complete."
update_status "ready"
