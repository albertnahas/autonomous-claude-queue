---
name: todo
description: Add task(s) to the autonomous task queue or view status
args:
  - name: tasks
    description: Task description(s) to add. Use "status" to view queue status instead.
    required: false
---

Add tasks to the autonomous queue or view status.

## Usage

```bash
# Add tasks
/todo "Fix login bug"
/todo "Task 1; Task 2; Task 3"

# View status
/todo status
```

## Implementation

```bash
#!/bin/bash
set -euo pipefail

TASKS="${1:-status}"

# Get project root
PROJECT_ROOT="$PWD"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel)"
fi

TODO_FILE="$PROJECT_ROOT/todo.md"
IN_PROGRESS_FILE="$PROJECT_ROOT/todo-in-progress.md"
COMPLETED_FILE="$PROJECT_ROOT/todo-completed.md"
FAILED_FILE="$PROJECT_ROOT/.claude/task-queue-failed.md"
WHITELIST_FILE="$PROJECT_ROOT/.claude/task-queue-allowed-sessions"

# Status view
if [[ "$TASKS" == "status" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 TASK QUEUE STATUS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Pending
  if [[ -f "$TODO_FILE" ]]; then
    PENDING_COUNT=$(grep -c '^[[:space:]]*-' "$TODO_FILE" 2>/dev/null || echo "0")
    echo "⏳ Pending: $PENDING_COUNT"
    if [[ $PENDING_COUNT -gt 0 ]] && [[ $PENDING_COUNT -le 3 ]]; then
      grep '^[[:space:]]*-' "$TODO_FILE"
    elif [[ $PENDING_COUNT -gt 3 ]]; then
      grep '^[[:space:]]*-' "$TODO_FILE" | head -3
      echo "   ... and $((PENDING_COUNT - 3)) more"
    fi
  else
    echo "⏳ Pending: 0"
  fi
  echo ""

  # In progress (by session)
  if [[ -f "$IN_PROGRESS_FILE" ]]; then
    IN_PROGRESS_COUNT=$(grep -c '^[[:space:]]*-' "$IN_PROGRESS_FILE" 2>/dev/null || echo "0")
    echo "🔄 In Progress: $IN_PROGRESS_COUNT"
    if [[ $IN_PROGRESS_COUNT -gt 0 ]]; then
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+)[[:space:]]+\[session:([^]]+)\] ]]; then
          TASK="${BASH_REMATCH[1]}"
          SESSION="${BASH_REMATCH[2]}"
          echo "   [$SESSION] $TASK"
        fi
      done < "$IN_PROGRESS_FILE"
    fi
  else
    echo "🔄 In Progress: 0"
  fi
  echo ""

  # Completed
  if [[ -f "$COMPLETED_FILE" ]]; then
    COMPLETED_COUNT=$(grep -c '^[[:space:]]*-' "$COMPLETED_FILE" 2>/dev/null || echo "0")
    echo "✅ Completed: $COMPLETED_COUNT (awaiting validation)"
    if [[ $COMPLETED_COUNT -gt 0 ]] && [[ $COMPLETED_COUNT -le 3 ]]; then
      tail -3 "$COMPLETED_FILE"
    fi
  else
    echo "✅ Completed: 0"
  fi
  echo ""

  # Failed
  if [[ -f "$FAILED_FILE" ]]; then
    FAILED_COUNT=$(grep -c '^[[:space:]]*-' "$FAILED_FILE" 2>/dev/null || echo "0")
    if [[ $FAILED_COUNT -gt 0 ]]; then
      echo "❌ Failed: $FAILED_COUNT (see .claude/task-queue-failed.md)"
      echo ""
    fi
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Commands:"
  echo "  /todo \"task\"       - Add task to queue"
  echo "  /queue-toggle      - Enable/disable autonomous mode"
  echo ""
  echo "Cleanup:"
  echo "  bash .claude/hooks/cleanup-stale-sessions.sh"
  echo "  rm todo-completed.md    # Clear validated tasks"
  echo "  rm .claude/task-queue-failed.md  # Clear failed tasks"

  exit 0
fi

# Add tasks
echo "$TASKS" | sed 's/;/\n/g' | while IFS= read -r task; do
  [[ -z "$task" ]] && continue
  task=$(echo "$task" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  if [[ "$task" =~ ^- ]]; then
    echo "$task" >> "$TODO_FILE"
  else
    echo "- $task" >> "$TODO_FILE"
  fi
done

TASK_COUNT=$(grep -c '^[[:space:]]*-' "$TODO_FILE" 2>/dev/null || echo "0")

echo "✅ Task(s) added to queue"
echo "📋 Total tasks in queue: $TASK_COUNT"
echo ""
echo "💡 Start autonomous mode: /queue-toggle"
```
