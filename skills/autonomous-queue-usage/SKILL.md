---
name: Autonomous Queue Usage
description: This skill should be used when the user asks about "autonomous queue", "task queue", "autonomous mode", "how to use the queue", "queue not working", "enable autonomous mode", "add tasks to queue", "/queue-toggle", "/todo command", or mentions continuous task execution, unattended task processing, or session-specific autonomous behavior.
version: 1.0.0
---

# Autonomous Queue Usage

## Overview

The Autonomous Claude Queue is a session-specific task processing system that enables continuous, unattended task execution. The system uses a Stop hook to intercept Claude's normal stopping behavior and automatically feed the next task from a queue, allowing Claude to work through multiple tasks without manual intervention.

**Key capabilities:**
- Process multiple tasks sequentially without stopping
- Session-specific isolation (multiple autonomous sessions can run simultaneously)
- Circuit breaker safety mechanisms (max iterations, stall detection)
- Multi-session support with task assignment tracking
- Comprehensive debug logging for troubleshooting

## Core Concepts

### Session Isolation

Each Claude Code session operates independently with its own task assignment and progress tracking. Sessions must explicitly opt in to autonomous mode, preventing accidental activation.

**Session-specific state files:**
- `task-queue-iteration-count-<session-id>` - Iteration counter
- `task-queue-current-task-<session-id>` - Currently assigned task
- `task-queue-allowed-sessions` - Session whitelist

### Task Lifecycle

Tasks progress through distinct states:

1. **Pending** → Listed in `todo.md`
2. **In Progress** → Moved to `todo-in-progress.md` with session ID tag
3. **Completed** → Moved to `todo-completed.md` with timestamp
4. **Failed** → Logged to `.claude/task-queue-failed.md` with reason

### Circuit Breaker Safety

Prevent infinite loops with automatic safeguards:
- Maximum iteration limit (default: 10, configurable via `CLAUDE_TASK_MAX_ITERATIONS`)
- Stall detection (monitors file changes between iterations)
- Failed task tracking with detailed reasons
- Session-specific iteration counting

## Quick Start Workflow

### 1. Add Tasks to Queue

Use the `/todo` command to add tasks:

```bash
# Add single task
/todo "Fix login bug"

# Add multiple tasks (semicolon-separated)
/todo "Task 1; Task 2; Task 3"

# View current queue status
/todo status
```

Tasks are stored in `todo.md` in the project root and processed in order.

### 2. Enable Autonomous Mode

Use `/queue-toggle` to enable autonomous mode for the current session:

```bash
/queue-toggle
```

**How it works:** The command creates a marker file that the Stop hook processes on your next interaction. The hook adds your session ID to the whitelist, enabling autonomous behavior.

**Toggle again to disable:** Running `/queue-toggle` when already enabled will disable autonomous mode for the session.

### 3. Monitor Progress

Check queue status to see task progress:

```bash
/todo status
```

**Status output shows:**
- Pending tasks count and preview
- In-progress tasks with session IDs
- Completed tasks awaiting validation
- Failed tasks (if any)

### 4. Task Completion Workflow

When the autonomous queue is active, Claude will work on assigned tasks. After each iteration, the system prompts for self-evaluation:

**Completion criteria:**
1. Task is 100% complete
2. Changes are committed to git with descriptive message
3. Task line is removed from `todo-in-progress.md`

**To mark task complete:**
```bash
# 1. Verify task is complete
# 2. Commit changes
git add . && git commit -m "Descriptive message explaining what changed"

# 3. Remove task from in-progress file
# Edit todo-in-progress.md and delete the line:
# - Task description [session:abc123]
```

**If task is not complete:** Continue working until all requirements are met.

## Multi-Session Support

Multiple autonomous sessions can run simultaneously without conflicts:

```bash
# Terminal 1
claude
/queue-toggle  # Session A picks up Task 1

# Terminal 2
claude
/queue-toggle  # Session B picks up Task 2

# Terminal 3 (regular session)
claude
/todo "Task 3"  # Safe - won't trigger autonomous mode
```

Each session:
- Gets its own task from the queue
- Tracks progress independently
- Commits and completes tasks separately
- Never interferes with other sessions

## Configuration

### Environment Variables

Control queue behavior via environment variables:

```bash
# Maximum iterations before failing task (default: 10)
export CLAUDE_TASK_MAX_ITERATIONS=15

# Disable queue entirely
export CLAUDE_TASK_QUEUE=disabled

# Force enable autonomous mode (bypass whitelist)
export CLAUDE_AUTONOMOUS_MODE=true
```

### Activation Methods

Autonomous mode activates when **either** condition is met:

1. **Session whitelist** (recommended): Use `/queue-toggle` to add session to whitelist
2. **Environment variable**: Set `CLAUDE_AUTONOMOUS_MODE=true`

**Note:** Using `cdp` (--dangerously-skip-permissions) does **not** automatically enable the queue. Explicit opt-in is required.

## File Organization

The system uses several files for state management:

```
project-root/
├── todo.md                              # Pending tasks
├── todo-in-progress.md                  # Currently processing
├── todo-completed.md                    # Completed, awaiting validation
└── .claude/
    ├── task-queue-failed.md             # Failed tasks log
    ├── task-queue-allowed-sessions      # Session whitelist
    ├── task-queue-iteration-count-*     # Per-session iteration counts
    ├── task-queue-current-task-*        # Per-session current task
    └── task-queue-debug.log             # Comprehensive debug log
```

## Troubleshooting

### Debug Logging

The system writes comprehensive logs to `.claude/task-queue-debug.log`. View logs using the utility script:

```bash
# Show last 50 lines
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh

# Follow log in real-time
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh follow

# Show only last hook run
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run

# Show only decision points
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh decisions

# Show all available options
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh help
```

### Common Issues

**Queue not starting:**
1. Check debug log: `bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run`
2. Look for "Session not authorized" or "Queue is disabled" messages
3. Verify autonomous mode is enabled: `/queue-toggle`
4. Ensure `todo.md` exists with tasks starting with `- `

**Task stuck in loop:**
1. Check iteration count in debug log
2. Circuit breaker will auto-fail after max iterations
3. Manually skip by removing task from `todo-in-progress.md`

**Multiple sessions interfering:**
1. Check session IDs in debug log: `bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh sessions`
2. Each session should have unique task
3. Check `todo-in-progress.md` for session ID tags
4. Run cleanup if sessions ended: `bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh`

### Cleanup Operations

Remove stale session files and validated tasks:

```bash
# Clean up stale session state files
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh

# Clear validated completed tasks
rm todo-completed.md

# Clear failed tasks
rm .claude/task-queue-failed.md
```

## Best Practices

### Writing Effective Tasks

**Good tasks** are specific and actionable:
```
- Fix authentication bug in login.ts line 42
- Add dark mode toggle to Settings page
- Update API documentation for /users endpoint
```

**Avoid vague tasks** that lead to loops:
```
- Improve performance
- Make it better
- Fix bugs
```

### Task Monitoring

1. **Monitor failed tasks regularly:** Check `.claude/task-queue-failed.md` to understand failures
2. **Validate completions:** Review `todo-completed.md` before clearing
3. **Clean up stale sessions:** Run cleanup script periodically
4. **Adjust iteration thresholds:** Increase `CLAUDE_TASK_MAX_ITERATIONS` for complex tasks

### Session Management

1. **Use session isolation:** Keep experimental work in separate sessions
2. **Don't mix autonomous and manual work:** Avoid toggling mode mid-task
3. **One session per terminal:** Don't enable multiple sessions in one terminal
4. **Monitor session states:** Check debug logs to understand session behavior

## Additional Resources

### Utility Scripts

Available in `$CLAUDE_PLUGIN_ROOT/scripts/`:

- **`cleanup-stale-sessions.sh`** - Remove session files for ended sessions
- **`view-queue-logs.sh`** - Advanced log viewer with multiple modes

### Reference Files

For detailed troubleshooting and advanced patterns:

- **`references/troubleshooting.md`** - Comprehensive troubleshooting guide with solutions for edge cases and complex scenarios

### Debug Log Features

The debug log includes:
- Session ID and authorization checks
- File existence and contents verification
- Task assignment and progress tracking
- Iteration counts and hash changes
- All decision points (why hook exited, blocked, etc.)
- Failure and completion events

## Security Considerations

The queue system includes several security features:

- **Explicit opt-in required:** Sessions must explicitly enable autonomous mode
- **Session whitelist:** Only authorized sessions can run autonomously
- **Regular sessions unaffected:** Commands and normal usage don't trigger queue
- **Circuit breaker:** Prevents runaway task loops
- **Comprehensive logging:** All decisions tracked for audit

## Architecture Notes

### Hook Implementation

The system uses a Stop hook that:
1. Checks if session is authorized for autonomous mode
2. Evaluates current task progress and completion
3. Assigns next task from queue if current task is done
4. Uses exit code 2 to block stoppage and force continuation
5. Provides self-evaluation prompts for task completion

### State Management

Session-specific state prevents conflicts:
- Each session tracks its own iteration count
- Tasks are tagged with session IDs in `todo-in-progress.md`
- Whitelist controls which sessions can run autonomously
- Cleanup utilities remove stale session files

### Performance Considerations

The system is designed for efficiency:
- Hook executes in under 1 second for most operations
- Log rotation prevents unbounded log growth
- State files are small and fast to read/write
- Circuit breaker prevents excessive iterations
