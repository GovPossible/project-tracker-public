# Setup Guide

This guide walks you through setting up the project tracker for your own repos. There are three components: a Rails dashboard, an MCP server, and a cron-based orchestrator.

## Prerequisites

- Ruby 3.2+ and Bundler
- Node.js 20+
- PostgreSQL
- [Homebrew](https://brew.sh/) (Linux or macOS)
- A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) subscription (Max plan or API key)
- A VPS or always-on server for the orchestrator (Ubuntu 22.04+ recommended)

### Optional services

- **Mailgun** — email notifications when the agent needs your input
- **Twilio** — SMS notifications for urgent items
- **Cloudinary** — file/image attachments on projects and replies
- **Honeybadger** — auto-create projects from production errors
- **Hatchbox** — trigger staging deploys from the agent
- **GitHub Webhooks** — auto-create replies from PR reviews

## 1. Dashboard (Rails app)

The dashboard is a standard Rails 8 app in `dashboard/`. Deploy it anywhere you'd deploy Rails — Hatchbox, Render, Fly, a VPS, etc.

### Local development

```bash
cd dashboard
bundle install
rails db:create db:migrate
bin/dev   # starts Rails + Tailwind watcher
```

### Environment variables

Set these on your production host:

| Variable | Required | Description |
|---|---|---|
| `POSTGRES_USER` | yes | Database username |
| `POSTGRES_PASSWORD` | yes | Database password |
| `DASHBOARD_API_KEY` | yes | Bearer token for API auth (generate with `rails secret`) |
| `DASHBOARD_URL` | yes | Public URL of your dashboard (e.g. `https://projects.example.com`) |
| `MAILGUN_API_KEY` | no | For email notifications |
| `MAILGUN_DOMAIN` | no | Your Mailgun sending domain |
| `NOTIFICATION_EMAIL` | no | Where to send notifications |
| `CLOUDINARY_CLOUD_NAME` | no | For file/image uploads |
| `CLOUDINARY_UPLOAD_PRESET` | no | Unsigned upload preset |
| `GITHUB_WEBHOOK_SECRET` | no | For verifying GitHub webhook payloads |

### Create your admin user

```bash
rails console
User.create!(email_address: "you@example.com", password: "your-password")
```

### API authentication

All API requests require a Bearer token:

```
Authorization: Bearer <DASHBOARD_API_KEY>
```

The orchestrator and MCP server both use this to communicate with the dashboard.

### Adding repos

After the dashboard is running, navigate to **Repos** in the nav bar and add each repository the agent will work on. For each repo, provide:

- **Name** — short identifier (e.g., `my-app`), used in project assignments
- **GitHub URL** — full URL to clone from
- **Framework** — Rails, Node.js, or Other (determines setup steps)
- **Ruby version / Gemset** — for RVM-based projects
- **Test command** — how to run the full test suite

When you save a repo, it starts with `pending` status. The orchestrator will automatically clone it, install dependencies, and set up the database on its next run. Once setup completes, the status changes to `ready` and the repo appears as a checkbox option when creating projects.

If setup fails, the setup log is displayed on the repo's show page. Fix the issue and click **Retry Setup**.

## 2. Quality Tools (prove_it & turbocommit)

Two Homebrew-installable CLI tools provide automated quality gates and commit management for Claude Code sessions:

- **[prove_it](https://github.com/searlsco/prove_it)** — runs tests, linting, and security scans automatically when Claude finishes a response. Configured via `.claude/prove_it/config.json`.
- **[turbocommit](https://github.com/searlsco/turbocommit)** — generates commit messages and auto-commits when Claude completes work. Runs as a Claude Code Stop hook.

### Installation

```bash
brew tap searlsco/tap
brew install searlsco/tap/prove_it
brew install searlsco/tap/turbocommit
```

### How they integrate

Both tools hook into Claude Code at different levels:

**prove_it** uses Claude Code's project-level hooks (`.claude/prove_it/config.json`):
- **SessionStart** — prints a briefing of outstanding work
- **PreToolUse** — guards its own config files from being modified by Claude
- **Stop** — runs fast tests (changed files only), linting (StandardRB), full test suite, and Brakeman security scan

The Stop tasks use conditional triggers:
- `fast-tests` and `lint` run after every Claude response that edits source files
- `full-tests` and `security` run only when Claude signals "done" (end of a task)

**turbocommit** runs as a Claude Code settings hook (`~/.claude/settings.json`):
- Fires on every Stop event
- Generates a commit message from staged changes and commits automatically

### Test scripts

prove_it calls two test scripts included in this repo:

- `script/test_fast` — maps modified source files to their test files and runs only those
- `script/test` — runs the full Rails test suite

### Configuration

The prove_it config at `.claude/prove_it/config.json` is checked into the repo. The `config.local.json` file (gitignored) can override settings locally.

You'll want to customize:
- The `sources` array if you change the project structure
- The `lint` command if you use a different linter
- The RVM gemset in `script/test` and `script/test_fast` to match your setup

## 3. MCP Server (Claude Code tools)

The MCP server gives Claude Code access to project management tools, email, SMS, and deploy triggers. It runs as a subprocess of Claude Code via stdio transport.

```bash
cd mcp-server
npm install
```

### Claude Code configuration

Create a `.mcp.json` in the project-tracker root (this file is gitignored):

```json
{
  "mcpServers": {
    "project-tracker-agent": {
      "command": "node",
      "args": ["/absolute/path/to/project-tracker/mcp-server/src/index.js"],
      "env": {
        "DASHBOARD_URL": "https://projects.example.com",
        "DASHBOARD_API_KEY": "your-api-key",
        "MAILGUN_API_KEY": "your-mailgun-key",
        "MAILGUN_DOMAIN": "mail.example.com",
        "MAILGUN_FROM": "agent@mail.example.com",
        "MAILGUN_TO": "you@example.com",
        "TWILIO_ACCOUNT_SID": "your-sid",
        "TWILIO_AUTH_TOKEN": "your-token",
        "TWILIO_FROM": "+10000000000",
        "TWILIO_TO": "+10000000000",
        "HONEYBADGER_AUTH_TOKEN": "your-hb-token",
        "HONEYBADGER_PROJECT_MAP": "{\"12345\":{\"repo\":\"my-app\",\"name\":\"My App\"}}",
        "HATCHBOX_ERP_WEBHOOK": "https://app.hatchbox.io/webhooks/deployments/YOUR_TOKEN",
        "HATCHBOX_COMMPORTAL_WEBHOOK": "https://app.hatchbox.io/webhooks/deployments/YOUR_TOKEN"
      }
    }
  }
}
```

Only include the env vars for services you're using. `DASHBOARD_URL` and `DASHBOARD_API_KEY` are the only required ones.

## 4. Orchestrator (VPS)

The orchestrator is a set of shell scripts that run on cron. Every 5 minutes it checks for work and launches Claude Code sessions.

### Automated setup

On a fresh Ubuntu 22.04+ VPS:

```bash
sudo ./orchestrator/setup-vps.sh deploy
```

This installs system packages, PostgreSQL, Node.js, Claude Code CLI, RVM, Ruby, and Homebrew. It then prints manual steps for cloning repos and configuring secrets.

### Manual configuration

1. **Copy config:**
   ```bash
   cp orchestrator/config.env.example orchestrator/config.env
   ```

2. **Edit `config.env`** with your actual values. At minimum you need:
   - `DASHBOARD_URL` and `DASHBOARD_API_KEY`
   - `WORKSPACE_DIR` and repo paths

3. **Copy Claude Code settings:**
   ```bash
   cp orchestrator/settings.json.example ~/.claude/settings.json
   ```
   Edit the permissions to match your repo structure and RVM gemsets. This file also includes Stop hooks for `prove_it verify` and `turbocommit commit` — make sure both are installed via Homebrew (see section 2).

4. **Create `.mcp.json`** in the project-tracker root (see MCP Server section above).

5. **Authenticate Claude Code:**
   ```bash
   claude login
   ```
   If you're on a headless VPS, use SSH port forwarding: `ssh -L 8080:localhost:8080 user@vps-ip`

6. **Install crontab:**
   ```bash
   # Edit orchestrator/crontab.example to update paths first
   crontab orchestrator/crontab.example
   ```

### How the orchestrator finds work

The orchestrator checks for work in this priority order:

1. **Critical projects** — any status, always jump the queue
2. **Waiting projects with replies** — resume work on projects where you've responded
3. **Stale PR reviews** — PRs idle for 45+ minutes (Copilot may be done)
4. **Queued projects** — next in line by priority
5. **Honeybadger faults** — auto-creates projects from unresolved production errors

It also enforces a "human pending" limit — if too many projects are waiting for your review, it pauses new work.

### Monitoring

```bash
# Live orchestrator output
tail -f /var/log/claude-agent/orchestrator.log

# Health check output (runs every 30 min, sends SMS if something's wrong)
tail -f /var/log/claude-agent/health-check.log
```

## 5. GitHub Webhooks (optional)

To have PR review comments automatically appear as replies on projects:

1. In your GitHub repo settings, add a webhook:
   - **URL:** `https://projects.example.com/api/v1/webhooks/github`
   - **Content type:** `application/json`
   - **Secret:** Same value as `GITHUB_WEBHOOK_SECRET`
   - **Events:** Pull request reviews, Pull request review comments, Issue comments

2. For inbound email replies (Mailgun):
   - Configure a Mailgun route to forward to `https://projects.example.com/api/v1/webhooks/mailgun`

3. For inbound SMS replies (Twilio):
   - Set the Twilio webhook URL to `https://projects.example.com/api/v1/webhooks/twilio`

## Workflow overview

```
You create a project in the dashboard
        ↓
Orchestrator picks it up (cron, every 5 min)
        ↓
Claude Code works on it (creates branch, writes code, runs tests)
        ↓
Agent creates a PR and requests Copilot review
        ↓
Copilot reviews → agent addresses feedback
        ↓
Agent requests your review, moves to "staging"
        ↓
You review, merge, done
```

At any point the agent can email/SMS you with questions. You reply via the dashboard, email, or SMS, and the orchestrator resumes the session.

## Customizing for your repos

Repos are managed via the dashboard UI — no code changes needed to add or remove repos. The orchestrator dynamically resolves repo names to local paths via the dashboard API.

To customize agent behavior per repo:

1. **`orchestrator/AGENT_INSTRUCTIONS.md`** — update the coding conventions and workflow for your stack
2. **`orchestrator/settings.json.example`** — update Claude Code permissions for your test commands
3. **`orchestrator/setup-repo.sh`** — customize the clone/setup steps if you need additional setup beyond the defaults (bundle install, npm install, db:create/migrate)
