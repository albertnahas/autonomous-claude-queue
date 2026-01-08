#!/bin/bash

# View Task Queue Debug Logs
# Usage: bash .claude/hooks/view-queue-logs.sh [options]

LOG_FILE=".claude/task-queue-debug.log"
ACTION="${1:-tail}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No debug log found at $LOG_FILE"
  echo ""
  echo "The log will be created when the task queue hook runs."
  echo "Enable queue with: /queue-toggle"
  exit 0
fi

case "$ACTION" in
  tail)
    # Show last 50 lines
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE DEBUG LOG (last 50 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -50 "$LOG_FILE"
    ;;

  all)
    # Show full log
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE DEBUG LOG (full)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$LOG_FILE"
    ;;

  follow)
    # Follow log in real-time
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE DEBUG LOG (following...)"
    echo "Press Ctrl+C to stop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -f "$LOG_FILE"
    ;;

  last-run)
    # Show only the last hook invocation
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE DEBUG LOG (last run only)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # Find the last separator and show everything after it
    tac "$LOG_FILE" | awk '/═════════════════════════════════════════════════════════════/{found=1} found' | tac
    ;;

  clear)
    # Clear the log
    > "$LOG_FILE"
    echo "✅ Debug log cleared"
    ;;

  decisions)
    # Show only decision points
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE DECISIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep "DECISION:" "$LOG_FILE"
    ;;

  errors)
    # Show errors and failures
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE ERRORS & FAILURES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -E "FAILURE:|ERROR:" "$LOG_FILE"
    ;;

  sessions)
    # Show session-related logs
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TASK QUEUE SESSIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep "Session ID" "$LOG_FILE"
    ;;

  help|--help|-h)
    cat << 'EOF'
Task Queue Debug Log Viewer

Usage: bash .claude/hooks/view-queue-logs.sh [action]

Actions:
  tail       Show last 50 lines (default)
  all        Show full log
  follow     Follow log in real-time (Ctrl+C to stop)
  last-run   Show only the last hook invocation
  decisions  Show only decision points
  errors     Show only errors and failures
  sessions   Show session-related logs
  clear      Clear the log file
  help       Show this help message

Examples:
  bash .claude/hooks/view-queue-logs.sh
  bash .claude/hooks/view-queue-logs.sh follow
  bash .claude/hooks/view-queue-logs.sh decisions
  bash .claude/hooks/view-queue-logs.sh clear

Log file location: .claude/task-queue-debug.log
EOF
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Run with 'help' to see available actions"
    exit 1
    ;;
esac
