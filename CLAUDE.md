# Project Tracker

Claude automation agent system for Project Tracker. Contains three components:

## Components

### dashboard/
Rails 7.1 app deployed on Hatchbox. Serves as:
- Web UI for the admin to monitor and manage projects
- REST API for the MCP server and orchestrator

### mcp-server/
Node.js MCP server (stdio transport) that provides tools to Claude Code sessions:
- Project management (read/update status, log activity)
- Email via Mailgun
- SMS via Twilio
- Honeybadger fault management
- Hatchbox staging deploys

### orchestrator/
Shell scripts for cron-based execution:
- `run.sh` — main entry point, runs every 5 minutes
- Checks for available work, launches Claude Code sessions

## Development

### Dashboard
```bash
cd dashboard
bin/dev              # Start Rails server + Tailwind watcher
rails test           # Run tests
rails db:migrate     # Run migrations
```

### MCP Server
```bash
cd mcp-server
npm install          # Install dependencies
npm test             # Run tests
```

## Deployment

### Dashboard
Deploy the `dashboard/` directory to any Rails-capable host. Push to `main` triggers auto-deploy if configured.

### Orchestrator (VPS)
The orchestrator runs on a VPS as a dedicated user.

**After changes to orchestrator files**, pull on the VPS:
```bash
ssh <user>@<your-vps-ip>
cd ~/workspace/project-tracker && git pull
```

**After changes to MCP server**, rebuild on the VPS:
```bash
cd ~/workspace/project-tracker/mcp-server && git pull && npm install
```

**Key VPS paths:**
- Config: `~/workspace/project-tracker/orchestrator/config.env`
- Logs: `/var/log/claude-agent/orchestrator.log`
- Health check logs: `/var/log/claude-agent/health-check.log`
- Lock file: `~/.claude-agent/agent.lock`
- Crontab: `crontab -l` (runs every 5 min)

**Monitoring:**
```bash
tail -f /var/log/claude-agent/orchestrator.log    # Live orchestrator output
tail -f /var/log/claude-agent/health-check.log    # Health check output
```

**Fresh VPS setup:** See `orchestrator/setup-vps.sh` and the manual steps it prints.

**Ruby/OpenSSL notes (Ubuntu 24.04):**
- Ruby 3.0.5 requires system OpenSSL 1.1 (`libssl1.1` + `libssl-dev` 1.1 debs)
- Ruby 3.2.9 uses system OpenSSL 3 natively (`--with-openssl-dir=/usr`)

## Conventions
- Follow the same coding conventions as erp and commportal-v2 CLAUDE.md files
- Use double colon (::) notation for namespacing in the Rails app
- Use Standard Ruby for linting (not RuboCop)
- Use TailwindBuilder for forms
- CRUD controllers, PORO-based design (no service objects)
