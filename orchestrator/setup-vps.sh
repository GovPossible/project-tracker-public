#!/bin/bash
# setup-vps.sh — Provision a fresh Ubuntu 22.04+ VPS for the Project Tracker agent
#
# Usage: sudo ./setup-vps.sh [username]
# Defaults to 'deploy' if no username provided.
# Then follow the manual steps at the end.

set -euo pipefail

AGENT_USER="${1:-deploy}"
WORKSPACE_DIR="/home/${AGENT_USER}/workspace/project-tracker"
LOG_DIR="/var/log/claude-agent"

echo "=== Project Tracker Agent VPS Setup ==="
echo ""

# --- System packages ---
echo "[1/9] Installing system packages..."
apt-get update -qq
apt-get install -y -qq \
  autoconf \
  automake \
  bison \
  build-essential \
  curl \
  git \
  jq \
  libffi-dev \
  libgdbm-dev \
  libncurses5-dev \
  libpq-dev \
  libreadline-dev \
  libssl-dev \
  libtool \
  libxml2-dev \
  libxslt1-dev \
  libyaml-dev \
  postgresql \
  postgresql-contrib \
  pkg-config \
  software-properties-common \
  zlib1g-dev

# --- GitHub CLI (via official apt repo) ---
echo "[2/9] Installing GitHub CLI..."
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt-get update -qq
  apt-get install -y -qq gh
fi

# --- Node.js 20 LTS ---
echo "[3/9] Installing Node.js 20 LTS..."
if ! command -v node &>/dev/null || [[ "$(node -v | cut -d. -f1 | tr -d v)" -lt 18 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
fi

# --- Claude Code CLI ---
echo "[4/9] Installing Claude Code CLI..."
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
fi

# --- PostgreSQL setup ---
echo "[5/9] Configuring PostgreSQL..."
sudo -u postgres createuser -s "${AGENT_USER}" 2>/dev/null || true
read -sp "Enter PostgreSQL password for ${AGENT_USER}: " PG_PASSWORD
echo
sudo -u postgres psql -c "ALTER USER ${AGENT_USER} WITH PASSWORD '${PG_PASSWORD}';" 2>/dev/null || true

# --- Log directory ---
echo "[6/9] Creating log directory..."
mkdir -p "$LOG_DIR"
chown "${AGENT_USER}:${AGENT_USER}" "$LOG_DIR"

# --- Logrotate ---
echo "[7/9] Installing logrotate config..."
cp "$(dirname "$0")/logrotate.conf" /etc/logrotate.d/claude-agent

# --- The rest runs as the agent user ---
echo "[8/9] Switching to user ${AGENT_USER} for remaining setup..."

sudo -u "${AGENT_USER}" bash << 'USEREOF'
set -eo pipefail

WORKSPACE_DIR="/home/${USER}/workspace/project-tracker"

# --- RVM + Ruby ---
echo "[8a] Installing RVM and Ruby..."
if ! command -v rvm &>/dev/null; then
  curl -sSL https://get.rvm.io | bash -s stable
  source "$HOME/.rvm/scripts/rvm"
fi

source "$HOME/.rvm/scripts/rvm" 2>/dev/null || true
rvm autolibs read-only

# Build OpenSSL 1.1 for Ruby 3.0.x compatibility (Ubuntu 24.04 ships OpenSSL 3)
echo "[8a-1] Building OpenSSL for RVM..."
rvm pkg install openssl

# Ruby 3.0.5 for erp
rvm install 3.0.5 --with-openssl-dir=$HOME/.rvm/usr --quiet-curl || true
rvm use 3.0.5
rvm gemset create erp-rails-70-ruby-3
rvm use 3.0.5@erp-rails-70-ruby-3
gem install bundler --no-document

# Ruby 3.2.9 for commportal and project-tracker (uses system OpenSSL 3.x natively)
rvm install 3.2.9 --with-openssl-dir=/usr --quiet-curl || true
rvm use 3.2.9
rvm gemset create commportal-v2
rvm use 3.2.9@commportal-v2
gem install bundler --no-document

rvm gemset create project-tracker
rvm use 3.2.9@project-tracker
gem install bundler --no-document

# --- Homebrew ---
echo "[8b] Installing Homebrew..."
if ! command -v brew &>/dev/null && [[ ! -d /home/linuxbrew/.linuxbrew ]]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# --- prove_it + turbocommit ---
echo "[8c] Installing prove_it and turbocommit..."
brew tap searlsco/tap 2>/dev/null || true
brew install searlsco/tap/prove_it 2>/dev/null || true
brew install searlsco/tap/turbocommit 2>/dev/null || true

# --- Workspace setup ---
echo "[8d] Setting up workspace..."
mkdir -p "$WORKSPACE_DIR"

# --- Agent state directory ---
mkdir -p "$HOME/.claude-agent"

USEREOF

echo ""
echo "[9/9] Setup verification..."
echo "  gh:          $(gh --version 2>/dev/null | head -1 || echo 'MISSING')"
echo "  node:        $(node --version 2>/dev/null || echo 'MISSING')"
echo "  claude:      $(claude --version 2>/dev/null | head -1 || echo 'MISSING')"
echo "  jq:          $(jq --version 2>/dev/null || echo 'MISSING')"
echo "  postgresql:  $(pg_isready 2>/dev/null && echo 'running' || echo 'not running')"
echo ""
echo "=== Automated setup complete ==="
echo ""
echo "=== Manual Steps Required ==="
echo ""
echo "1. Clone repos (as ${AGENT_USER}):"
echo "   cd ${WORKSPACE_DIR}"
echo "   gh auth login"
echo "   gh repo clone Project Tracker/erp"
echo "   gh repo clone Project Tracker/commportal-v2"
echo "   gh repo clone Project Tracker/project-tracker"
echo ""
echo "2. Install repo dependencies:"
echo "   cd erp && rvm use 3.0.5@erp-rails-70-ruby-3 && bundle install"
echo "   cd ../commportal-v2 && rvm use 3.2.9@commportal-v2 && bundle install"
echo "   cd ../project-tracker/mcp-server && npm install"
echo ""
echo "3. Copy and fill in config:"
echo "   cp ${WORKSPACE_DIR}/project-tracker/orchestrator/config.env.example \\"
echo "      ${WORKSPACE_DIR}/project-tracker/orchestrator/config.env"
echo "   # Edit config.env with actual API keys"
echo ""
echo "4. Set up Claude Code:"
echo "   claude login    # Requires browser — use SSH port forwarding:"
echo "   # ssh -L 8080:localhost:8080 <vps-ip>"
echo ""
echo "5. Copy MCP config:"
echo "   # Create .mcp.json in project-tracker/ with env vars"
echo "   # (see .mcp.json on dev machine for reference)"
echo ""
echo "6. Copy Claude Code settings:"
echo "   cp ${WORKSPACE_DIR}/project-tracker/orchestrator/settings.json.example \\"
echo "      ~/.claude/settings.json"
echo ""
echo "7. Set up databases:"
echo "   cd ${WORKSPACE_DIR}/erp"
echo "   rvm use 3.0.5@erp-rails-70-ruby-3"
echo "   bundle exec rails db:create db:migrate"
echo "   cd ${WORKSPACE_DIR}/commportal-v2"
echo "   rvm use 3.2.9@commportal-v2"
echo "   bundle exec rails db:create db:migrate"
echo ""
echo "8. Install crontab:"
echo "   crontab ${WORKSPACE_DIR}/project-tracker/orchestrator/crontab.example"
echo ""
echo "9. Test the orchestrator:"
echo "   ${WORKSPACE_DIR}/project-tracker/orchestrator/run.sh"
echo ""
