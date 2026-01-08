#!/bin/bash
set -euo pipefail

# Cleanup Stale Session Files
# Removes session-specific state files for sessions that no longer have tasks in progress

CWD="${1:-.}"
STATE_DIR="$CWD/.claude"
IN_PROGRESS_FILE="$CWD/todo-in-progress.md"
WHITELIST_FILE="$STATE_DIR/task-queue-allowed-sessions"

if [[ ! -d "$STATE_DIR" ]]; then
  echo "No state directory found at $STATE_DIR"
  exit 0
fi

# Extract all active session IDs from in-progress file
ACTIVE_SESSIONS=()
if [[ -f "$IN_PROGRESS_FILE" ]]; then
  while IFS= read -r line; do
    if [[ "$line" =~ \[session:([^]]+)\] ]]; then
      ACTIVE_SESSIONS+=("${BASH_REMATCH[1]}")
    fi
  done < "$IN_PROGRESS_FILE"
fi

echo "Active sessions: ${#ACTIVE_SESSIONS[@]}"
for session in "${ACTIVE_SESSIONS[@]}"; do
  echo "  - $session"
done
echo ""

# Find all session-specific state files
STALE_COUNT=0
for file in "$STATE_DIR"/task-queue-*-*; do
  [[ ! -f "$file" ]] && continue

  # Extract session ID from filename
  filename=$(basename "$file")
  if [[ "$filename" =~ task-queue-(iteration-count|current-task|initial-hash)-(.+)$ ]]; then
    SESSION_ID="${BASH_REMATCH[2]}"

    # Check if this session is still active
    IS_ACTIVE=false
    for active in "${ACTIVE_SESSIONS[@]}"; do
      if [[ "$active" == "$SESSION_ID" ]]; then
        IS_ACTIVE=true
        break
      fi
    done

    if [[ "$IS_ACTIVE" == false ]]; then
      echo "Removing stale state file: $filename (session: $SESSION_ID)"
      rm -f "$file"
      ((STALE_COUNT++))
    fi
  fi
done

if [[ $STALE_COUNT -eq 0 ]]; then
  echo "No stale session files found."
else
  echo ""
  echo "✅ Cleaned up $STALE_COUNT stale session state files"
fi

# Clean up whitelist file - remove stale session IDs
if [[ -f "$WHITELIST_FILE" ]] && [[ -s "$WHITELIST_FILE" ]]; then
  echo ""
  echo "Cleaning whitelist file..."

  WHITELIST_CLEANED=0
  TEMP_WHITELIST="$WHITELIST_FILE.tmp"
  > "$TEMP_WHITELIST"

  while IFS= read -r session_id; do
    [[ -z "$session_id" ]] && continue

    # Check if this session is still active
    IS_ACTIVE=false
    for active in "${ACTIVE_SESSIONS[@]}"; do
      if [[ "$active" == "$session_id" ]]; then
        IS_ACTIVE=true
        break
      fi
    done

    if [[ "$IS_ACTIVE" == true ]]; then
      echo "$session_id" >> "$TEMP_WHITELIST"
    else
      echo "Removing stale session from whitelist: $session_id"
      ((WHITELIST_CLEANED++))
    fi
  done < "$WHITELIST_FILE"

  mv "$TEMP_WHITELIST" "$WHITELIST_FILE"

  if [[ $WHITELIST_CLEANED -eq 0 ]]; then
    echo "Whitelist is clean - all sessions are active"
  else
    echo "✅ Cleaned up $WHITELIST_CLEANED stale session(s) from whitelist"
  fi
fi

echo ""
echo "Cleanup complete!"
