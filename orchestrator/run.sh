#!/bin/bash
# run.sh — Main orchestrator entry point
# Called by cron every 5 minutes. Checks for work, launches Claude Code sessions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_DIR="$HOME/.claude-agent"
LOCK_FILE="$LOCK_DIR/agent.lock"
LOG_PREFIX="[orchestrator]"

# --- Logging ---
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*" >&2; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX ERROR: $*" >&2; }

# --- Load config ---
CONFIG_FILE="$SCRIPT_DIR/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
  error "config.env not found at $CONFIG_FILE"
  exit 1
fi
set -a
source "$CONFIG_FILE"
set +a

# --- Lock file management ---
acquire_lock() {
  mkdir -p "$LOCK_DIR"

  if [[ -f "$LOCK_FILE" ]]; then
    local pid
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      log "Agent already running (PID $pid). Exiting."
      exit 0
    else
      log "Stale lock file found (PID $pid). Removing."
      rm -f "$LOCK_FILE"
    fi
  fi

  echo $$ > "$LOCK_FILE"
  log "Lock acquired (PID $$)"
}

release_lock() {
  rm -f "$LOCK_FILE"
  log "Lock released"
}

# --- Cleanup on exit ---
cleanup() {
  local exit_code=$?
  release_lock
  # Clean up worktrees if they were created
  if [[ -n "${WORKTREE_PATHS:-}" ]]; then
    for wt in $WORKTREE_PATHS; do
      if [[ -d "$wt" ]]; then
        local repo_dir
        repo_dir="$(dirname "$wt")"
        log "Removing worktree: $wt"
        git -C "$repo_dir" worktree remove "$wt" --force 2>/dev/null || true
      fi
    done
  fi
  log "Orchestrator exiting (code $exit_code)"
}
trap cleanup EXIT INT TERM

# --- Dashboard API helpers ---
api_get() {
  local path="$1"
  curl -sf -H "Authorization: Bearer $DASHBOARD_API_KEY" \
    -H "Accept: application/json" \
    "${DASHBOARD_URL}/api/v1${path}"
}

api_patch() {
  local path="$1" data="$2"
  curl -sf -X PATCH \
    -H "Authorization: Bearer $DASHBOARD_API_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$data" \
    "${DASHBOARD_URL}/api/v1${path}"
}

api_post() {
  local path="$1" data="$2"
  curl -sf -X POST \
    -H "Authorization: Bearer $DASHBOARD_API_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$data" \
    "${DASHBOARD_URL}/api/v1${path}"
}

# --- Auth health check ---
check_claude_auth() {
  if ! claude --version >/dev/null 2>&1; then
    error "Claude Code not found on PATH"
    send_sms_alert "Claude Code not found on PATH. Agent cannot run."
    exit 1
  fi

  # Quick auth check — run a trivial prompt
  if ! claude -p "echo ok" --max-turns 1 >/dev/null 2>&1; then
    error "Claude Code auth check failed — token may be expired"
    send_sms_alert "Claude Code auth expired. Run 'claude login' on VPS to re-authenticate."
    exit 1
  fi
}

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

# --- Pull latest code ---
pull_repos() {
  log "Pulling latest from repos..."
  for repo in "$TRACKER_REPO" "$ERP_REPO" "$COMMPORTAL_REPO"; do
    if [[ -d "$repo" ]]; then
      git -C "$repo" fetch origin --quiet 2>/dev/null || true
      # Only pull if on main/master and working tree is clean
      local branch
      branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        if git -C "$repo" diff --quiet 2>/dev/null; then
          git -C "$repo" pull --ff-only --quiet 2>/dev/null || true
        fi
      fi
    fi
  done
}

# --- Find work ---
find_project() {
  # 0. Critical projects jump the queue regardless of status
  log "Checking for critical projects..."
  local critical
  critical=$(api_get "/projects/next_critical" 2>/dev/null || echo "")

  if [[ -n "$critical" ]]; then
    local critical_id
    critical_id=$(echo "$critical" | jq -r '.id // empty' 2>/dev/null)
    if [[ -n "$critical_id" ]]; then
      log "Found critical project: #${critical_id}"
      echo "$critical"
      return 0
    fi
  fi

  # 1. Check for waiting projects with unread replies (resume work)
  log "Checking for waiting projects with replies..."
  local waiting
  waiting=$(api_get "/projects/waiting_with_replies" 2>/dev/null || echo "[]")

  if [[ "$waiting" != "[]" && -n "$waiting" ]]; then
    local first_id
    first_id=$(echo "$waiting" | jq -r '.[0].id // empty' 2>/dev/null)
    if [[ -n "$first_id" ]]; then
      log "Found waiting project with replies: #${first_id}"
      echo "$waiting" | jq '.[0]'
      return 0
    fi
  fi

  # 2. Before starting new work, check if the project owner already has too many items pending
  log "Checking human pending count..."
  local pending_json
  pending_json=$(api_get "/projects/human_pending_count" 2>/dev/null || echo "")

  if [[ -n "$pending_json" ]]; then
    local blocked
    blocked=$(echo "$pending_json" | jq -r '.blocked // false' 2>/dev/null)
    if [[ "$blocked" == "true" ]]; then
      local count limit
      count=$(echo "$pending_json" | jq -r '.count')
      limit=$(echo "$pending_json" | jq -r '.limit')
      log "Human pending limit reached (${count}/${limit}). Skipping new work."
      return 1
    fi
  fi

  # 3. Check for stale PR reviews (no Copilot feedback after 45 min)
  log "Checking for stale PR reviews..."
  local stale
  stale=$(api_get "/projects/stale_pr_review" 2>/dev/null || echo "[]")

  if [[ "$stale" != "[]" && -n "$stale" ]]; then
    local first_id
    first_id=$(echo "$stale" | jq -r '.[0].id // empty' 2>/dev/null)
    if [[ -n "$first_id" ]]; then
      log "Found stale PR review: #${first_id}"
      echo "$stale" | jq '.[0]'
      return 0
    fi
  fi

  # 4. Check for next queued project
  log "Checking for next queued project..."
  local next
  next=$(api_get "/projects/next_available" 2>/dev/null || echo "")

  if [[ -n "$next" ]]; then
    local next_id
    next_id=$(echo "$next" | jq -r '.id // empty' 2>/dev/null)
    if [[ -n "$next_id" ]]; then
      log "Found queued project: #${next_id}"
      echo "$next"
      return 0
    fi
  fi

  # 5. No queued projects — check Honeybadger for new faults
  log "No queued projects. Checking Honeybadger for new faults..."
  local project_from_hb
  project_from_hb=$(check_honeybadger_faults)
  if [[ -n "$project_from_hb" ]]; then
    echo "$project_from_hb"
    return 0
  fi

  log "No work available."
  return 1
}

# --- Honeybadger fault → project creation ---
check_honeybadger_faults() {
  # Add your Honeybadger project IDs here
  local HB_PROJECTS=(${HONEYBADGER_PROJECT_IDS:-})
  local HB_API="https://app.honeybadger.io/v2"
  local auth
  auth=$(echo -n "${HONEYBADGER_AUTH_TOKEN}:" | base64)

  for project_id in "${HB_PROJECTS[@]}"; do
    local faults
    faults=$(curl -sf -H "Authorization: Basic $auth" \
      -H "Accept: application/json" \
      "${HB_API}/projects/${project_id}/faults?q=-is:resolved&order=recent" 2>/dev/null || echo "")

    if [[ -z "$faults" ]]; then continue; fi

    local fault_count
    fault_count=$(echo "$faults" | jq '.results | length' 2>/dev/null || echo "0")

    for ((i = 0; i < fault_count && i < 3; i++)); do
      local fault_id klass message
      fault_id=$(echo "$faults" | jq -r ".results[$i].id")
      klass=$(echo "$faults" | jq -r ".results[$i].klass")
      message=$(echo "$faults" | jq -r ".results[$i].message")

      # Check if a project already exists for this fault
      # We create a project via the dashboard API and it checks uniqueness on honeybadger_fault_id
      local repo_name project_name
      # Map Honeybadger project IDs to repo names — customize for your setup
      # Set HONEYBADGER_PROJECT_MAP in config.env as "hb_id:repo_name:display_name,..."
      repo_name="unknown"; project_name="Unknown"
      IFS=',' read -ra HB_MAP <<< "${HONEYBADGER_PROJECT_MAP:-}"
      for mapping in "${HB_MAP[@]}"; do
        IFS=':' read -r hb_id hb_repo hb_name <<< "$mapping"
        if [[ "$project_id" == "$hb_id" ]]; then
          repo_name="$hb_repo"
          project_name="$hb_name"
          break
        fi
      done

      local environment notices_count component action
      environment=$(echo "$faults" | jq -r ".results[$i].environment // \"production\"")
      notices_count=$(echo "$faults" | jq -r ".results[$i].notices_count // 0")
      component=$(echo "$faults" | jq -r ".results[$i].component // \"N/A\"")
      action=$(echo "$faults" | jq -r ".results[$i].action // \"N/A\"")

      local description
      description="**Honeybadger Fault** #${fault_id} in ${project_name}\n**Class**: ${klass}\n**Message**: ${message}\n**Environment**: ${environment}\n**Occurrences**: ${notices_count}\n**Component**: ${component}\n**Action**: ${action}\n\nFix this bug in the codebase. Check the Honeybadger fault detail for the full backtrace."

      local payload
      payload=$(jq -n \
        --arg title "BUGFIX: ${klass} — ${message}" \
        --arg desc "$description" \
        --arg fault_id "$fault_id" \
        --arg hb_key "$project_id" \
        --arg repo "$repo_name" \
        '{project: {title: $title, description: $desc, priority: "low", source: "honeybadger", honeybadger_fault_id: $fault_id, honeybadger_project_key: $hb_key, repos: [$repo]}}')

      local result
      result=$(api_post "/projects" "$payload" 2>/dev/null || echo "")

      if [[ -n "$result" ]]; then
        local new_id
        new_id=$(echo "$result" | jq -r '.id // empty' 2>/dev/null)
        if [[ -n "$new_id" ]]; then
          log "Created project #${new_id} from Honeybadger fault #${fault_id}"
          echo "$result"
          return 0
        fi
      fi
    done
  done
}

# --- Worktree setup ---
setup_worktree() {
  local repo_path="$1" branch_name="$2"
  local worktree_path="${repo_path}-agent-worktree"

  # Ensure we're on main before creating worktree
  local default_branch
  default_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

  git -C "$repo_path" fetch origin --quiet 2>/dev/null || true

  # Create branch from origin/main if it doesn't exist
  if ! git -C "$repo_path" show-ref --verify --quiet "refs/heads/${branch_name}"; then
    if git -C "$repo_path" ls-remote --exit-code --heads origin "${branch_name}" >/dev/null 2>&1; then
      git -C "$repo_path" branch "${branch_name}" --track "origin/${branch_name}" >/dev/null 2>&1 || true
    else
      local main_branch
      if git -C "$repo_path" show-ref --verify --quiet refs/remotes/origin/main; then
        main_branch="origin/main"
      else
        main_branch="origin/master"
      fi
      git -C "$repo_path" branch "${branch_name}" "$main_branch" >/dev/null 2>&1 || true
    fi
  fi

  # Remove any existing worktree using this branch (may be at a different path)
  local existing_wt
  existing_wt=$(git -C "$repo_path" worktree list --porcelain 2>/dev/null | awk -v branch="branch refs/heads/${branch_name}" '/^worktree /{wt=$0} $0==branch{print wt}' | sed 's/^worktree //')
  if [[ -n "$existing_wt" ]]; then
    log "Removing existing worktree for ${branch_name} at ${existing_wt}"
    git -C "$repo_path" worktree remove "$existing_wt" --force 2>/dev/null || rm -rf "$existing_wt"
  fi

  # Also remove stale worktree at our target path if it exists with a different branch
  if [[ -d "$worktree_path" ]]; then
    git -C "$repo_path" worktree remove "$worktree_path" --force 2>/dev/null || rm -rf "$worktree_path"
  fi

  # Create worktree
  local wt_output
  if wt_output=$(git -C "$repo_path" worktree add "$worktree_path" "$branch_name" 2>&1); then
    log "Created worktree: $worktree_path on branch $branch_name"
  else
    log "ERROR creating worktree: $wt_output"
    # Worktree may exist from a previous run with a stale lock — try pruning and retry
    git -C "$repo_path" worktree prune 2>/dev/null || true
    if wt_output=$(git -C "$repo_path" worktree add "$worktree_path" "$branch_name" 2>&1); then
      log "Created worktree after prune: $worktree_path on branch $branch_name"
    else
      log "FATAL: Cannot create worktree after prune: $wt_output"
      return 1
    fi
  fi

  WORKTREE_PATHS="${WORKTREE_PATHS:-} $worktree_path"
  echo "$worktree_path"
}

# --- Build Claude Code prompt ---
build_prompt() {
  local project_id="$1" project_json="$2" is_resume="$3"

  local title description repos status
  title=$(echo "$project_json" | jq -r '.title')
  description=$(echo "$project_json" | jq -r '.description')
  repos=$(echo "$project_json" | jq -r '.repos // [] | join(", ")')
  status=$(echo "$project_json" | jq -r '.status')

  local prompt=""

  if [[ "$is_resume" == "true" && "$status" == "pr_review" ]]; then
    prompt="You are resuming work on project #${project_id}: \"${title}\".

The project is in pr_review status and has been idle for 45+ minutes. Check for unread replies using check_replies — if there are Copilot/GitHub review comments, address them, push fixes, and set status back to 'pr_review' to wait for Copilot's re-review.

If there are NO unread review comments, check the last commit time on the PR branch using 'git log -1 --format=%ci'. If the last commit was more than 45 minutes ago AND Copilot has no outstanding change requests (check with 'gh pr reviews <number>'), then Copilot has likely finished. Add the project owner as reviewer ('gh pr edit <number> --add-reviewer <GITHUB_USERNAME>') and update status to 'staging'. Then use reply_to_feedback to post a markdown summary of the work for the project owner's review — include what was changed and why, key files modified, any design decisions or trade-offs, and test coverage.

If the last commit was recent (under 45 minutes), Copilot may still be reviewing. Set status back to 'pr_review' and stop — the orchestrator will check again later.

"
  elif [[ "$is_resume" == "true" ]]; then
    prompt="You are resuming work on project #${project_id}: \"${title}\".

The project was in waiting_input status and has received replies. Use the check_replies tool to read the replies, then continue working on the project based on the feedback received.

"
  else
    prompt="You are working on project #${project_id}: \"${title}\".

Use the get_current_project tool to read the full project details, then implement the requirements.

"
  fi

  if [[ -n "$repos" ]]; then
    prompt+="Project repos: ${repos}
"
  else
    prompt+="No target repos specified. Determine which repo(s) this project belongs to by reading the project description. The options are 'erp' and 'commportal-v2'. Update the project repos using set_project_branches before starting work. If you cannot determine the repo with high confidence, use send_email to ask the project owner which repo(s) this project targets, update status to 'waiting_input', and stop.
"
  fi

  prompt+="
WORKFLOW:
1. Read the project details using get_current_project
2. Update status to 'working' using update_project_status
3. Create a feature branch in the target repo(s): feature/project-${project_id}-<short-description>
4. Record the branch names using set_project_branches
5. Implement the requirements, committing as you go
6. Run tests and ensure they pass
7. When done, push the branch and create a PR via 'gh pr create'
8. Request copilot review: 'gh pr edit <number> --add-reviewer copilot'
9. Wait for and address copilot feedback
10. Add the project owner as reviewer: 'gh pr edit <number> --add-reviewer <GITHUB_USERNAME>'
11. Record PR URLs using set_project_branches
12. Update status to 'pr_review' using update_project_status
13. Stop working — the orchestrator will pick up the next project

COMMUNICATION:
- If you need input from the project owner, use send_email with a clear question
- For short yes/no questions, use send_sms instead
- After sending a message, update status to 'waiting_input' and STOP
- When you resume, check_replies will have the project owner's response

IMPORTANT:
- Always log significant actions using add_activity_log
- If you encounter an error you cannot resolve after 3 attempts, update status to 'failed' with details
- Never force-push to main/master
- Always create PRs, never push directly to main"

  echo "$prompt"
}

# --- Main ---
main() {
  log "=== Orchestrator starting ==="

  acquire_lock
  check_claude_auth
  pull_repos

  # Find work
  local project_json
  if ! project_json=$(find_project); then
    log "No work to do. Exiting."
    exit 0
  fi

  local project_id status repos
  project_id=$(echo "$project_json" | jq -r '.id')
  status=$(echo "$project_json" | jq -r '.status')
  repos=$(echo "$project_json" | jq -r '.repos // [] | .[]' 2>/dev/null)

  log "Working on project #${project_id} (status: ${status})"

  # Determine if this is a resume (waiting_input with replies, or stale pr_review)
  local is_resume="false"
  if [[ "$status" == "waiting_input" || "$status" == "pr_review" ]]; then
    is_resume="true"
  fi

  # Set up worktrees for target repos
  local primary_cwd=""
  WORKTREE_PATHS=""

  for repo in $repos; do
    local repo_path branch_name worktree
    case "$repo" in
      erp) repo_path="$ERP_REPO" ;;
      commportal-v2|commportal) repo_path="$COMMPORTAL_REPO" ;;
      *) log "Unknown repo: $repo, skipping"; continue ;;
    esac

    branch_name="feature/project-${project_id}"
    worktree=$(setup_worktree "$repo_path" "$branch_name") || continue

    if [[ -z "$primary_cwd" && -d "$worktree" ]]; then
      primary_cwd="$worktree"
    fi
  done

  # Fall back to workspace dir if no worktrees created
  if [[ -z "$primary_cwd" ]]; then
    primary_cwd="$WORKSPACE_DIR"
  fi

  # Update status to working
  if [[ "$status" != "working" ]]; then
    api_patch "/projects/${project_id}" '{"project":{"status":"working"}}' >/dev/null 2>&1 || true
    api_post "/projects/${project_id}/activities" '{"activity":{"action":"started","details":"Orchestrator launched Claude Code session"}}' >/dev/null 2>&1 || true
  fi

  # Build prompt
  local prompt
  prompt=$(build_prompt "$project_id" "$project_json" "$is_resume")

  # Export PROJECT_ID for the MCP server
  export PROJECT_ID="$project_id"

  # Launch Claude Code
  log "Launching Claude Code in $primary_cwd"

  local agent_instructions="$SCRIPT_DIR/AGENT_INSTRUCTIONS.md"

  local exit_code=0
  pushd "$primary_cwd" > /dev/null
  claude --dangerously-skip-permissions \
    -p "$prompt" \
    --max-turns 200 \
    --append-system-prompt "$(cat "$agent_instructions")" \
    || exit_code=$?
  popd > /dev/null

  # Log completion
  if [[ $exit_code -eq 0 ]]; then
    log "Claude Code session completed successfully"
    api_post "/projects/${project_id}/activities" \
      '{"activity":{"action":"session_completed","details":"Claude Code session ended normally"}}' \
      >/dev/null 2>&1 || true
  else
    log "Claude Code session exited with code $exit_code"
    api_post "/projects/${project_id}/activities" \
      "{\"activity\":{\"action\":\"session_error\",\"details\":\"Claude Code exited with code ${exit_code}\"}}" \
      >/dev/null 2>&1 || true
  fi

  log "=== Orchestrator complete ==="
}

main "$@"
