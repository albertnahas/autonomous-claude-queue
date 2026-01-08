---
description: Toggle autonomous task queue on/off for current session
allowed-tools: Bash
model: claude-3-5-haiku-20241022
---

!`
# Queue toggle works by creating a marker file that the Stop hook will process
# The hook has access to the actual session ID, so it can add/remove it from the whitelist

MARKER_FILE=".claude/task-queue-toggle-request"
mkdir -p .claude

# Create marker file to signal toggle request
# The Stop hook will detect this and process the toggle with the correct session ID
echo "toggle" > "$MARKER_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Queue toggle requested"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The task queue will be toggled for this session."
echo "Status will be confirmed on next stop."
`
