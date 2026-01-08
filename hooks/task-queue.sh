#!/bin/bash
set -euo pipefail

# Task Queue Hook for Claude Code
# Triggers when the main agent stops to check for queued tasks
# Uses exit code 2 to BLOCK stoppage and force continuation with next task
# Includes circuit breaker safety mechanisms and prompt-based completion

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Comprehensive logging for debugging
LOG_FILE="$CWD/.claude/task-queue-debug.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Log rotation - truncate if larger than 1MB (keep last 1000 lines)
if [[ -f "$LOG_FILE" ]]; then
  LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  if [[ "$LOG_SIZE" -gt 1048576 ]]; then
    tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
fi

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "═══════════════════════════════════════════════════════════════"
log "HOOK TRIGGERED - Stop hook invoked"
log "CWD: $CWD"

# Get session ID FIRST - critical for session-specific state management
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
if [[ -z "$SESSION_ID" ]]; then
  # Cannot proceed without session ID - allow normal stop
  log "ERROR: No session_id provided in input - cannot proceed with autonomous mode"
  log "EXIT: Allowing normal stop (exit 0)"
  exit 0
fi
log "Session ID from input: $SESSION_ID"

# State directory - define early since other files depend on it
STATE_DIR="$CWD/.claude"

TODO_FILE="$CWD/todo.md"
IN_PROGRESS_FILE="$CWD/todo-in-progress.md"
COMPLETED_FILE="$CWD/todo-completed.md"
DISABLE_FILE="$STATE_DIR/task-queue-disabled"
FAILED_TASKS_FILE="$STATE_DIR/task-queue-failed.md"
WHITELIST_FILE="$STATE_DIR/task-queue-allowed-sessions"
MARKER_FILE="$STATE_DIR/task-queue-toggle-request"

# Session-specific state files to prevent conflicts
ITERATION_COUNT_FILE="$STATE_DIR/task-queue-iteration-count-$SESSION_ID"
CURRENT_TASK_FILE="$STATE_DIR/task-queue-current-task-$SESSION_ID"

# Configurable threshold
MAX_ITERATIONS=${CLAUDE_TASK_MAX_ITERATIONS:-10}

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Check for toggle request marker file and process it
if [[ -f "$MARKER_FILE" ]]; then
  log "TOGGLE REQUEST: Marker file detected - processing toggle request"
  mkdir -p "$(dirname "$WHITELIST_FILE")"
  touch "$WHITELIST_FILE"

  if grep -qF "$SESSION_ID" "$WHITELIST_FILE" 2>/dev/null; then
    # Session is in whitelist - remove it (disable)
    grep -vF "$SESSION_ID" "$WHITELIST_FILE" > "$WHITELIST_FILE.tmp" && mv "$WHITELIST_FILE.tmp" "$WHITELIST_FILE"
    log "  ✓ Removed session $SESSION_ID from whitelist (DISABLED)"
    rm -f "$MARKER_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "✓ Task queue DISABLED for this session" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Session: $SESSION_ID" >&2
    echo "Status: ❌ DISABLED (normal mode)" >&2
    echo "═══════════════════════════════════════════════════════════════" >&2
    log "EXIT: Allowing stop after disabling queue (exit 0)"
    exit 0
  else
    # Session not in whitelist - add it (enable)
    echo "$SESSION_ID" >> "$WHITELIST_FILE"
    log "  ✓ Added session $SESSION_ID to whitelist (ENABLED)"
    rm -f "$MARKER_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "✓ Task queue ENABLED for this session" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Session: $SESSION_ID" >&2
    echo "Status: ✅ ENABLED (autonomous mode)" >&2
    echo "" >&2
    echo "Checking for tasks..." >&2
    # Continue execution to check for tasks (don't exit here)
  fi
fi

log "Files configured:"
log "  TODO_FILE: $TODO_FILE (exists: $([ -f "$TODO_FILE" ] && echo "yes" || echo "no"))"
log "  IN_PROGRESS_FILE: $IN_PROGRESS_FILE (exists: $([ -f "$IN_PROGRESS_FILE" ] && echo "yes" || echo "no"))"
log "  WHITELIST_FILE: $WHITELIST_FILE (exists: $([ -f "$WHITELIST_FILE" ] && echo "yes" || echo "no"))"
log "  DISABLE_FILE: $DISABLE_FILE (exists: $([ -f "$DISABLE_FILE" ] && echo "yes" || echo "no"))"

# Check if task queue is disabled
if [[ -f "$DISABLE_FILE" ]] || [[ "${CLAUDE_TASK_QUEUE:-}" == "disabled" ]]; then
  log "DECISION: Queue is disabled (disable file exists or CLAUDE_TASK_QUEUE=disabled)"
  log "EXIT: Allowing normal stop (exit 0)"
  exit 0  # Disabled, allow stopping
fi
log "CHECK: Queue not disabled, continuing..."

# CRITICAL: Only activate queue for explicitly opt-in sessions
# This prevents regular Claude sessions and commands from triggering the queue
log "Checking session authorization..."
log "  Whitelist file: $WHITELIST_FILE"
log "  Whitelist exists: $([ -f "$WHITELIST_FILE" ] && echo "yes" || echo "no")"

if [[ -f "$WHITELIST_FILE" ]]; then
  log "  Whitelist contents:"
  while IFS= read -r line; do
    log "    - $line"
  done < "$WHITELIST_FILE"
fi

# Check if this session is explicitly allowed via whitelist
SESSION_ALLOWED=false
if [[ -f "$WHITELIST_FILE" ]] && grep -qF "$SESSION_ID" "$WHITELIST_FILE" 2>/dev/null; then
  SESSION_ALLOWED=true
  log "  ✓ Session $SESSION_ID found in whitelist"
else
  log "  ✗ Session $SESSION_ID NOT in whitelist"
fi

log "Authorization checks:"
log "  SESSION_ALLOWED: $SESSION_ALLOWED"
log "  CLAUDE_AUTONOMOUS_MODE: ${CLAUDE_AUTONOMOUS_MODE:-not set}"

# Queue only activates when ANY of these conditions are met:
# 1. Session ID is in the whitelist file (enabled via /queue-toggle)
# 2. Explicitly enabled via environment variable (CLAUDE_AUTONOMOUS_MODE=true)
#
# NOTE: cdp (--dangerously-skip-permissions) does NOT auto-enable the queue
# You must explicitly enable with /queue-toggle
if [[ "$SESSION_ALLOWED" != "true" ]] && \
   [[ "${CLAUDE_AUTONOMOUS_MODE:-}" != "true" ]]; then
  log "DECISION: Session not authorized for autonomous mode"
  log "EXIT: Allowing normal stop (exit 0)"
  log "═══════════════════════════════════════════════════════════════"
  exit 0  # Not an autonomous session, allow normal stopping
fi

log "✓ Session authorized for autonomous mode - continuing..."

# Function to mark task as failed and move to next
mark_task_failed() {
  local task="$1"
  local reason="$2"

  log "FAILURE: Marking task as failed"
  log "  Task: $task"
  log "  Reason: $reason"

  # Append to failed tasks file
  mkdir -p "$(dirname "$FAILED_TASKS_FILE")"
  echo "- [FAILED: $reason] $task" >> "$FAILED_TASKS_FILE"

  # Remove just this task from in-progress file
  if [[ -f "$IN_PROGRESS_FILE" ]]; then
    grep -vF -- "- $task" "$IN_PROGRESS_FILE" > "$IN_PROGRESS_FILE.tmp" && mv "$IN_PROGRESS_FILE.tmp" "$IN_PROGRESS_FILE"
    # Clean up empty file
    if [[ ! -s "$IN_PROGRESS_FILE" ]]; then
      rm -f "$IN_PROGRESS_FILE"
    fi
  fi

  # Reset session-specific state
  rm -f "$ITERATION_COUNT_FILE" "$CURRENT_TASK_FILE"
  log "  State files cleaned up"

  echo "⚠️  Task failed: $reason" >&2
  echo "   Task: $task" >&2
  echo "   See $FAILED_TASKS_FILE for details" >&2
  echo "" >&2
}

# Check if there's a task currently in progress for this session
log "Checking for current task in progress..."
log "  IN_PROGRESS_FILE exists: $([ -f "$IN_PROGRESS_FILE" ] && echo "yes" || echo "no")"

CURRENT_TASK=""
if [[ -f "$IN_PROGRESS_FILE" ]] && [[ -s "$IN_PROGRESS_FILE" ]]; then
  # Look for a task marked with this session ID
  CURRENT_TASK=$(grep "^[[:space:]]*-.*\[session:$SESSION_ID\]" "$IN_PROGRESS_FILE" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*\[session:[^]]*\][[:space:]]*$//' || echo "")

  if [[ -n "$CURRENT_TASK" ]]; then
    log "  ✓ Found task for session $SESSION_ID: $CURRENT_TASK"
  else
    log "  ✗ No task found for session $SESSION_ID in in-progress file"
  fi

  # If no session-marked task found, check if we were tracking a task from previous iteration
  if [[ -z "$CURRENT_TASK" ]] && [[ -f "$CURRENT_TASK_FILE" ]]; then
    log "  Checking CURRENT_TASK_FILE for saved task..."
    # Read the task we were working on from state
    SAVED_TASK=$(cat "$CURRENT_TASK_FILE" 2>/dev/null || echo "")
    log "    Saved task: $SAVED_TASK"
    # Check if that task still exists in the in-progress file with our session ID
    if [[ -n "$SAVED_TASK" ]] && grep -qF "- $SAVED_TASK [session:$SESSION_ID]" "$IN_PROGRESS_FILE"; then
      CURRENT_TASK="$SAVED_TASK"
      log "    ✓ Restored task from state file: $CURRENT_TASK"
    else
      log "    ✗ Saved task not found in in-progress file"
    fi
  fi
else
  log "  IN_PROGRESS_FILE is empty or doesn't exist"
fi

log "Current task determined: ${CURRENT_TASK:-[none]}"

if [[ -n "$CURRENT_TASK" ]]; then
  log "Processing current task: $CURRENT_TASK"

  # Check if task was manually removed (signals completion)
  if ! grep -qF "- $CURRENT_TASK [session:$SESSION_ID]" "$IN_PROGRESS_FILE"; then
    log "COMPLETION: Task was manually removed from in-progress (signaling completion)"

    # Move task to completed
    echo "- [$(date '+%Y-%m-%d %H:%M')] $CURRENT_TASK [session:$SESSION_ID]" >> "$COMPLETED_FILE"
    rm -f "$ITERATION_COUNT_FILE" "$CURRENT_TASK_FILE"
    log "  Task moved to completed file"
    log "  State files cleaned up"
    echo "✓ Task completed: $CURRENT_TASK" >&2
  else
    log "Task still in progress, checking iteration..."
    # Task still in progress - increment counter (with validation)
    ITERATION_COUNT=0
    if [[ -f "$ITERATION_COUNT_FILE" ]]; then
      # Validate file contains numeric value only
      FILE_CONTENT=$(<"$ITERATION_COUNT_FILE" 2>/dev/null || echo "")
      if [[ "$FILE_CONTENT" =~ ^[0-9]+$ ]]; then
        ITERATION_COUNT="$FILE_CONTENT"
        log "  Previous iteration count: $ITERATION_COUNT"
      else
        log "  WARNING: Invalid iteration count in file, resetting to 0"
      fi
    fi
    ITERATION_COUNT=$((ITERATION_COUNT + 1))
    echo "$ITERATION_COUNT" > "$ITERATION_COUNT_FILE"
    log "  New iteration count: $ITERATION_COUNT (max: $MAX_ITERATIONS)"

    # Check max iterations
    if [[ $ITERATION_COUNT -gt $MAX_ITERATIONS ]]; then
      log "DECISION: Max iterations exceeded"
      mark_task_failed "$CURRENT_TASK" "Max iterations ($MAX_ITERATIONS) exceeded"
      # Fall through to pick up next task from queue
    else
      # Ask Claude to self-evaluate and confirm completion
      log "DECISION: Prompting Claude for task completion confirmation"
      log "EXIT: Blocking stop to get completion confirmation (exit 2)"
      cat << EOF >&2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SELF-EVALUATION REQUIRED (Iteration $ITERATION_COUNT/$MAX_ITERATIONS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current task: $CURRENT_TASK

Is this task 100% complete?

If YES:
  1. Review all changes made for this task
  2. Create a git commit with a descriptive message that explains WHAT was changed
     (not just repeating the task description)
  3. THEN remove this task line from todo-in-progress.md:
     - $CURRENT_TASK [session:$SESSION_ID]

If NO: Continue working until 100% complete.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
      exit 2
    fi
  fi
fi

# No task in progress, check for next task in queue
log "No current task - checking for next task in queue..."
log "  TODO_FILE exists: $([ -f "$TODO_FILE" ] && echo "yes" || echo "no")"

if [[ ! -f "$TODO_FILE" ]]; then
  log "DECISION: No TODO_FILE - queue is empty"
  log "EXIT: Allowing stop - all tasks completed (exit 0)"
  log "═══════════════════════════════════════════════════════════════"
  echo "✓ Task queue is empty. All tasks completed!" >&2
  exit 0
fi

# Read the file and find the first task (line starting with -)
log "Parsing TODO_FILE to find next task..."
FIRST_TASK=""
REMAINING_TASKS=""
FOUND_FIRST=false

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines at the start
  if [[ -z "$line" ]] && [[ "$FOUND_FIRST" == false ]]; then
    continue
  fi

  # Check if line starts with dash (task marker)
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]](.+)$ ]] && [[ "$FOUND_FIRST" == false ]]; then
    # Extract task content (remove the dash and leading/trailing whitespace)
    FIRST_TASK=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')
    FOUND_FIRST=true
    continue
  fi

  # Add remaining lines to REMAINING_TASKS
  if [[ "$FOUND_FIRST" == true ]]; then
    if [[ -z "$REMAINING_TASKS" ]]; then
      REMAINING_TASKS="$line"
    else
      REMAINING_TASKS="$REMAINING_TASKS"$'\n'"$line"
    fi
  fi
done < "$TODO_FILE"

# If no tasks found, clean up and exit
if [[ -z "$FIRST_TASK" ]]; then
  log "DECISION: No tasks found in TODO_FILE - queue is empty"
  log "EXIT: Allowing stop - all tasks completed (exit 0)"
  log "═══════════════════════════════════════════════════════════════"
  echo "✓ Task queue is empty. All tasks completed!" >&2
  exit 0
fi

log "  ✓ Found first task: $FIRST_TASK"
log "Assigning task to session $SESSION_ID..."

# Add first task to todo-in-progress.md (append, don't overwrite for multi-session support)
if [[ -f "$IN_PROGRESS_FILE" ]]; then
  echo "- $FIRST_TASK [session:$SESSION_ID]" >> "$IN_PROGRESS_FILE"
  log "  Appended to existing IN_PROGRESS_FILE"
else
  echo "- $FIRST_TASK [session:$SESSION_ID]" > "$IN_PROGRESS_FILE"
  log "  Created new IN_PROGRESS_FILE"
fi

# Save task for this session (session-specific state)
echo "$FIRST_TASK" > "$CURRENT_TASK_FILE"
log "  Saved task to: $CURRENT_TASK_FILE"

# Reset iteration counter (session-specific)
rm -f "$ITERATION_COUNT_FILE"
log "  Reset iteration counter"

# Update todo.md with remaining tasks
if [[ -n "$REMAINING_TASKS" ]]; then
  if ! echo "$REMAINING_TASKS" > "$TODO_FILE"; then
    log "  ERROR: Failed to write TODO_FILE"
  else
    log "  Updated TODO_FILE with remaining tasks"
  fi
else
  # Remove the file if no tasks remain
  rm -f "$TODO_FILE"
  log "  Removed TODO_FILE (no remaining tasks)"
fi

# Calculate remaining task count
REMAINING_COUNT=$(echo "$REMAINING_TASKS" | grep -c '^[[:space:]]*-' || echo "0")
log "Remaining tasks in queue: $REMAINING_COUNT"

log "DECISION: Starting new task"
log "EXIT: Blocking stop to start task (exit 2)"
log "═══════════════════════════════════════════════════════════════"

# Use exit code 2 to BLOCK stoppage and force continuation
# The error message becomes the next task for Claude
cat << EOF >&2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 TASK QUEUE: Next Task (Remaining: $REMAINING_COUNT)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$FIRST_TASK

Circuit breaker initialized: Max $MAX_ITERATIONS iterations, stall detection enabled.
EOF

# Exit code 2 blocks Claude from stopping and shows the error message
# This forces Claude to continue with the next task automatically
exit 2
