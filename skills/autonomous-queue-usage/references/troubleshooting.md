# Autonomous Queue Troubleshooting Guide

Comprehensive troubleshooting guide for the Autonomous Claude Queue system.

## Table of Contents

1. [Queue Not Starting](#queue-not-starting)
2. [Tasks Stuck in Loop](#tasks-stuck-in-loop)
3. [Session Conflicts](#session-conflicts)
4. [Task Completion Issues](#task-completion-issues)
5. [Performance Problems](#performance-problems)
6. [Hook Not Executing](#hook-not-executing)
7. [Debug Log Analysis](#debug-log-analysis)
8. [Edge Cases](#edge-cases)

## Queue Not Starting

### Symptom

Queue doesn't activate when expected. Claude stops normally instead of continuing with next task.

### Diagnostic Steps

1. **Check debug log for authorization:**
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run
   ```
   Look for:
   - "Session not authorized for autonomous mode"
   - "Queue is disabled"
   - "No TODO_FILE - queue is empty"

2. **Verify session is in whitelist:**
   ```bash
   cat .claude/task-queue-allowed-sessions
   ```
   Should contain your session ID.

3. **Check todo.md exists and has tasks:**
   ```bash
   cat todo.md
   ```
   Tasks must start with `- ` (dash and space).

4. **Verify hook is configured:**
   Check `.claude/settings.json` or plugin's `hooks/hooks.json` for Stop hook registration.

### Solutions

**If session not authorized:**
```bash
/queue-toggle  # Enable autonomous mode for current session
```

**If queue disabled:**
```bash
# Remove disable file if it exists
rm .claude/task-queue-disabled

# Unset environment variable if set
unset CLAUDE_TASK_QUEUE
```

**If todo.md missing or empty:**
```bash
# Add tasks
/todo "Task to complete"
```

**If todo.md format wrong:**
```bash
# Fix format - tasks must start with dash-space
echo "- First task" > todo.md
echo "- Second task" >> todo.md
```

## Tasks Stuck in Loop

### Symptom

Task repeatedly iterates without completing or being marked failed.

### Diagnostic Steps

1. **Check iteration count:**
   ```bash
   cat .claude/task-queue-iteration-count-<session-id>
   ```

2. **Review task progress in debug log:**
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run
   ```
   Look for:
   - Iteration count increasing
   - "Task still in progress"
   - File hash changes (or lack thereof)

3. **Check max iterations threshold:**
   ```bash
   echo $CLAUDE_TASK_MAX_ITERATIONS  # Default is 10
   ```

### Root Causes

**Vague task description:**
- Task: "Improve performance" → Too vague
- Solution: Make specific: "Reduce API response time for /users endpoint to < 200ms"

**Task requires manual input:**
- Task: "Ask user about color preference" → Requires interaction
- Solution: Remove from autonomous queue, handle manually

**Task is too complex:**
- Task: "Rewrite entire authentication system" → Too large
- Solution: Break into smaller tasks

**File changes not being detected:**
- Circuit breaker relies on file hash changes
- Solution: Ensure task makes actual file modifications

### Solutions

**Increase iteration threshold for complex tasks:**
```bash
export CLAUDE_TASK_MAX_ITERATIONS=20
```

**Manually mark task complete:**
```bash
# Commit current work
git add . && git commit -m "Progress on task"

# Remove from in-progress
# Edit todo-in-progress.md and delete the task line
```

**Manually fail task:**
```bash
# Remove task from in-progress file
# It will be marked as failed by next hook run
```

**Break complex task into smaller pieces:**
```bash
/todo "Subtask 1; Subtask 2; Subtask 3"
```

## Session Conflicts

### Symptom

Multiple sessions appear to be working on same task or interfering with each other.

### Diagnostic Steps

1. **Check session IDs in in-progress file:**
   ```bash
   cat todo-in-progress.md
   ```
   Each line should have unique session ID: `[session:abc123]`

2. **List active sessions:**
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh sessions
   ```

3. **Check for stale sessions:**
   ```bash
   ls .claude/task-queue-*-*
   ```
   Look for files with session IDs that no longer exist.

### Root Causes

**Stale session state files:**
- Session ended but state files remain
- Solution: Run cleanup script

**Multiple sessions enabled accidentally:**
- Multiple terminals with autonomous mode
- Solution: Disable unintended sessions

**Race condition on task assignment:**
- Two sessions enabled simultaneously grab same task
- Solution: Queue assigns tasks atomically per session

### Solutions

**Clean up stale sessions:**
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh
```

**Disable specific session:**
```bash
# In that session's terminal
/queue-toggle  # Disables if already enabled
```

**Manually remove session from whitelist:**
```bash
# Edit .claude/task-queue-allowed-sessions
# Remove the problematic session ID line
```

**Reassign stuck task:**
```bash
# Remove from in-progress.md
# Will return to todo.md on next iteration
# Next session will pick it up
```

## Task Completion Issues

### Symptom

Tasks complete but don't move to completed file, or keep reappearing.

### Diagnostic Steps

1. **Check if task was removed from in-progress:**
   ```bash
   cat todo-in-progress.md
   ```

2. **Verify git commit was made:**
   ```bash
   git log -1  # Check last commit
   ```

3. **Check completed file:**
   ```bash
   cat todo-completed.md
   ```

4. **Review debug log for completion detection:**
   ```bash
   bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run | grep COMPLETION
   ```

### Root Causes

**Task not removed from in-progress file:**
- Completion requires manual removal
- Solution: Edit `todo-in-progress.md` and delete task line

**Session ID mismatch:**
- Task has different session ID than current session
- Solution: Remove correct line (with correct session ID)

**No git commit made:**
- System expects commit before marking complete
- Solution: Commit changes before removing from in-progress

### Solutions

**Proper completion workflow:**
```bash
# 1. Verify task is done
# 2. Commit changes
git add .
git commit -m "Completed: Task description"

# 3. Remove from in-progress file
# Edit todo-in-progress.md
# Delete line: - Task description [session:abc123]
```

**Move task to completed manually:**
```bash
# If already committed but not moved
echo "- [$(date '+%Y-%m-%d %H:%M')] Task description [session:abc123]" >> todo-completed.md
# Then remove from in-progress.md
```

## Performance Problems

### Symptom

Queue operates slowly, or hook takes long time to execute.

### Diagnostic Steps

1. **Check hook execution time in debug log:**
   ```bash
   # Compare timestamps between "HOOK TRIGGERED" and "EXIT" lines
   bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run
   ```

2. **Check log file size:**
   ```bash
   ls -lh .claude/task-queue-debug.log
   ```
   Log should auto-rotate at 1MB.

3. **Check for large state files:**
   ```bash
   ls -lh .claude/task-queue-*
   ```

### Root Causes

**Log file too large:**
- Log rotation not working
- Solution: Manual cleanup or check rotation logic

**Many stale session files:**
- Sessions ended but files remain
- Solution: Run cleanup

**Slow file I/O:**
- Project on slow filesystem
- Solution: Move to faster storage or reduce logging

### Solutions

**Clear debug log:**
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh clear
```

**Clean up state files:**
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh
```

**Reduce logging detail:**
- Hook already includes log rotation
- No action needed if rotation working

## Hook Not Executing

### Symptom

Stop hook doesn't run at all when Claude stops.

### Diagnostic Steps

1. **Verify plugin is installed:**
   ```bash
   cc --list-plugins
   ```

2. **Check hooks configuration:**
   ```bash
   cat .claude-plugin/hooks/hooks.json
   # Or plugin location: autonomous-claude-queue/hooks/hooks.json
   ```

3. **Test with debug mode:**
   ```bash
   claude --debug
   ```
   Look for hook registration and execution logs.

4. **Check hook script exists and is executable:**
   ```bash
   ls -l $CLAUDE_PLUGIN_ROOT/hooks/task-queue.sh
   # Should show execute permissions
   ```

### Root Causes

**Plugin not installed:**
- Plugin not in Claude Code's plugin directory
- Solution: Install plugin properly

**Hook not registered:**
- hooks.json missing or malformed
- Solution: Validate hooks.json

**Hook script not executable:**
- Missing execute permissions
- Solution: `chmod +x`

**Hook script has syntax error:**
- Bash syntax error prevents execution
- Solution: Test script directly

### Solutions

**Install plugin:**
```bash
# Option 1: Use plugin directory
cc --plugin-dir /path/to/autonomous-claude-queue

# Option 2: Copy to Claude plugins directory
cp -r autonomous-claude-queue ~/.claude/plugins/
```

**Validate hooks.json:**
```bash
# Check JSON syntax
jq . $CLAUDE_PLUGIN_ROOT/hooks/hooks.json
```

**Make script executable:**
```bash
chmod +x $CLAUDE_PLUGIN_ROOT/hooks/task-queue.sh
```

**Test script directly:**
```bash
echo '{"session_id":"test","cwd":"'$PWD'"}' | \
  bash $CLAUDE_PLUGIN_ROOT/hooks/task-queue.sh
echo "Exit code: $?"
```

## Debug Log Analysis

### Understanding Log Structure

The debug log uses structured sections:

```
[timestamp] ═══════════════════════════════════
[timestamp] HOOK TRIGGERED - Stop hook invoked
[timestamp] CWD: /path/to/project
[timestamp] Session ID from input: abc123
...
[timestamp] DECISION: [Reason for action]
[timestamp] EXIT: [Exit code and reason]
[timestamp] ═══════════════════════════════════
```

### Key Log Markers

**HOOK TRIGGERED** - Hook started
**Session ID** - Current session identifier
**CHECK** - Verification step
**DECISION** - Action taken
**EXIT** - Hook completed
**FAILURE** - Task failed
**COMPLETION** - Task completed

### Common Log Patterns

**Normal task assignment:**
```
HOOK TRIGGERED
Session ID: abc123
✓ Session authorized
No current task
✓ Found first task: Task description
DECISION: Starting new task
EXIT: Blocking stop (exit 2)
```

**Task continuation:**
```
HOOK TRIGGERED
Session ID: abc123
✓ Session authorized
Current task: Task description
Task still in progress
New iteration count: 5 (max: 10)
DECISION: Prompting for completion
EXIT: Blocking stop (exit 2)
```

**Task completion:**
```
HOOK TRIGGERED
Session ID: abc123
COMPLETION: Task was manually removed
Task moved to completed file
EXIT: Allowing stop (exit 0)
```

**Max iterations exceeded:**
```
HOOK TRIGGERED
Session ID: abc123
Current task: Task description
New iteration count: 11 (max: 10)
DECISION: Max iterations exceeded
FAILURE: Marking task as failed
```

### Debug Log Commands

```bash
# Show full log
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh all

# Follow in real-time
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh follow

# Show only last run
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run

# Show only decisions
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh decisions

# Show errors
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh errors

# Show sessions
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh sessions
```

## Edge Cases

### Empty Queue After Task Completion

**Scenario:** Last task completes, queue empty, but hook still blocks.

**Solution:** Hook should detect empty queue and exit 0. Check debug log for "No TODO_FILE - queue is empty" message.

### Session Ends While Task In Progress

**Scenario:** User exits Claude while task is processing.

**Expected behavior:** Task remains in `todo-in-progress.md` with session ID. Run cleanup script to remove stale session state.

**Recovery:**
```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh
```

Task will return to `todo.md` if session files are cleaned.

### Concurrent Task Assignment

**Scenario:** Two sessions enabled simultaneously, both try to grab first task.

**Expected behavior:** Queue assigns tasks atomically. Each session gets unique task. Verify in `todo-in-progress.md` - each line should have different session ID.

### Task Removed But Not Committed

**Scenario:** Task removed from in-progress before git commit.

**Expected behavior:** Task moves to completed file. User should commit separately.

**Best practice:** Always commit before removing task to maintain git history.

### Whitelist File Corruption

**Scenario:** `task-queue-allowed-sessions` file becomes corrupted or malformed.

**Solution:**
```bash
# Recreate whitelist
> .claude/task-queue-allowed-sessions

# Re-enable autonomous mode
/queue-toggle
```

### Hook Timeout

**Scenario:** Hook takes longer than timeout (60s default) to execute.

**Diagnosis:** Check if hook is waiting on slow operations.

**Solution:** Hook is designed to complete quickly (<1s typical). If timing out, check for:
- Slow filesystem
- Large log files
- Network operations (shouldn't have any)

### Multiple Plugins With Stop Hooks

**Scenario:** Other plugins also have Stop hooks that conflict.

**Expected behavior:** All Stop hooks run in parallel. Queue hook should coexist peacefully.

**Potential issue:** If another hook exits with code 2 (blocking), behavior may be unpredictable.

**Solution:** Review all Stop hooks in `.claude/settings.json` and plugin configurations. Ensure they're compatible.

## Getting Help

If issues persist after troubleshooting:

1. **Collect diagnostic information:**
   ```bash
   # Debug log last run
   bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run > debug.txt

   # Session state
   ls -la .claude/task-queue-* >> debug.txt

   # Queue files
   cat todo.md todo-in-progress.md todo-completed.md >> debug.txt 2>&1
   ```

2. **Check for known issues:**
   - Review plugin repository issues
   - Check documentation updates

3. **File issue with:**
   - Complete debug log excerpt
   - Steps to reproduce
   - Expected vs actual behavior
   - Plugin version and Claude Code version

## Prevention Best Practices

Avoid common issues by following these practices:

1. **Write specific tasks** - Avoid vague descriptions
2. **Monitor failed tasks** - Check `.claude/task-queue-failed.md` regularly
3. **Run cleanup periodically** - Remove stale sessions weekly
4. **Use debug mode during testing** - `claude --debug` shows detailed logs
5. **Validate completions** - Review completed tasks before clearing
6. **Adjust thresholds for complex tasks** - Increase max iterations as needed
7. **Keep one session per terminal** - Avoid confusion
8. **Commit regularly** - Maintain git history for all task completions
