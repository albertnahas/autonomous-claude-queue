# Autonomous Claude Queue

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://claude.com/code)

A Claude Code plugin that enables autonomous, continuous task execution through an intelligent task queue system with session isolation and safety mechanisms.

## Overview

The Autonomous Claude Queue transforms Claude Code into an autonomous agent that can work through multiple tasks sequentially without manual intervention. Each session operates independently, allowing multiple autonomous workflows to run simultaneously while maintaining safety through circuit breakers and comprehensive logging.

### Key Features

- ✅ **Session-Specific Isolation** - Multiple autonomous sessions can run simultaneously without conflicts
- ✅ **Circuit Breaker Safety** - Max iterations, stall detection, and automatic failure handling
- ✅ **Task Lifecycle Management** - Pending → In Progress → Completed/Failed with full tracking
- ✅ **Multi-Session Support** - Each session tracks its own progress independently
- ✅ **Comprehensive Debugging** - Detailed logging with multiple view modes
- ✅ **Security First** - Explicit opt-in required, session whitelist, no accidental activation

## Quick Start

### Installation

**Option 1: Install via Marketplace (Recommended)**

```bash
# Add the marketplace
/plugin marketplace add albertnahas/autonomous-claude-queue

# Install the plugin
/plugin install autonomous-claude-queue
```

**Option 2: Manual Installation**

```bash
# Clone from GitHub
git clone https://github.com/albertnahas/autonomous-claude-queue.git
cd autonomous-claude-queue

# Use with Claude Code
cc --plugin-dir $(pwd)
```

Or copy to your Claude plugins directory:

```bash
cp -r autonomous-claude-queue ~/.claude/plugins/
```

### Basic Usage

```bash
# 1. Add tasks to queue
/todo "Fix authentication bug"
/todo "Update API documentation; Add tests for login flow"

# 2. Enable autonomous mode
/queue-toggle

# 3. Claude will automatically work through tasks

# 4. Monitor progress
/todo status
```

That's it! Claude will now work through your tasks autonomously, committing changes and moving to the next task automatically.

## How It Works

### The Hook System

The plugin uses a **Stop hook** that intercepts Claude's normal stopping behavior:

1. When Claude attempts to stop, the hook checks if autonomous mode is enabled
2. If enabled, it evaluates the current task status
3. If task is complete, it assigns the next task from the queue
4. Uses exit code 2 to **block** the stop and force Claude to continue

This creates a continuous loop where Claude works through tasks until the queue is empty.

### Session Isolation

Each Claude Code session operates independently:

- **Session Whitelist**: Only explicitly enabled sessions run autonomously
- **Independent State**: Each session tracks its own progress and iteration count
- **Unique Task Assignment**: Sessions never work on the same task
- **Parallel Execution**: Multiple terminals can run autonomous sessions simultaneously

### Safety Mechanisms

**Circuit Breaker Protection:**
- Maximum iteration limit (default: 10, configurable)
- Stall detection monitors file changes
- Automatic task failure after threshold
- Failed task logging with detailed reasons

**Manual Override:**
- Tasks can be manually removed from queue
- Sessions can be disabled at any time
- Queue can be paused globally
- Emergency stop available

## Commands

### `/todo`

Add tasks or view queue status.

```bash
# Add single task
/todo "Task description"

# Add multiple tasks (semicolon-separated)
/todo "Task 1; Task 2; Task 3"

# View queue status
/todo status
```

**Status output shows:**
- Pending tasks count and preview
- In-progress tasks with session IDs
- Completed tasks awaiting validation
- Failed tasks (if any)

### `/queue-toggle`

Enable or disable autonomous mode for the current session.

```bash
# Enable autonomous mode
/queue-toggle

# Disable autonomous mode (run again)
/queue-toggle
```

**How it works**: Creates a marker file that the Stop hook processes on your next interaction, adding or removing your session ID from the whitelist.

## Task Completion Workflow

When working on a task, Claude will periodically ask for self-evaluation:

```
🔍 SELF-EVALUATION REQUIRED (Iteration 3/10)

Current task: Fix authentication bug

Is this task 100% complete?

If YES:
  1. Review all changes
  2. Create git commit with descriptive message
  3. Remove this task line from todo-in-progress.md:
     - Fix authentication bug [session:abc123]

If NO: Continue working
```

**To mark complete:**
1. Verify task is 100% done
2. Commit changes: `git add . && git commit -m "Fix auth bug in login handler"`
3. Edit `todo-in-progress.md` and delete the task line

**If not complete:** Continue working until all requirements are met.

## Configuration

### Environment Variables

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

1. **Session whitelist** (recommended): `/queue-toggle`
2. **Environment variable**: `CLAUDE_AUTONOMOUS_MODE=true`

**Note:** `cdp` (--dangerously-skip-permissions) does **not** auto-enable the queue.

## File Organization

```
project-root/
├── todo.md                              # Pending tasks
├── todo-in-progress.md                  # Currently processing
├── todo-completed.md                    # Completed tasks
└── .claude/
    ├── task-queue-failed.md             # Failed tasks log
    ├── task-queue-allowed-sessions      # Session whitelist
    ├── task-queue-iteration-count-*     # Per-session counters
    ├── task-queue-current-task-*        # Per-session current task
    └── task-queue-debug.log             # Comprehensive debug log
```

## Debugging

### Debug Logging

View comprehensive logs with the utility script:

```bash
# Show last 50 lines
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh

# Follow log in real-time
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh follow

# Show only last hook run
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run

# Show decision points
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh decisions

# Show errors only
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh errors
```

### Common Issues

**Queue not starting:**
```bash
# Check session authorization
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh last-run

# Enable autonomous mode
/queue-toggle

# Verify tasks exist
cat todo.md
```

**Task stuck in loop:**
```bash
# Check iteration count
cat .claude/task-queue-iteration-count-*

# Manually complete
# 1. Commit current work
# 2. Remove from todo-in-progress.md
```

**Multiple sessions interfering:**
```bash
# Clean up stale sessions
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh

# Check session states
cat todo-in-progress.md
```

## Multi-Session Example

Run multiple autonomous sessions in parallel:

```bash
# Terminal 1
claude
/todo "Implement feature A; Write tests for A"
/queue-toggle  # Session A starts working

# Terminal 2
claude
/todo "Fix bug B; Update docs for B"
/queue-toggle  # Session B starts working independently

# Terminal 3 (regular session)
claude
/todo "Add task C"  # Safe - won't trigger autonomous mode
```

Each session:
- Gets its own task from the queue
- Tracks progress independently
- Commits and completes separately
- Never interferes with others

## Best Practices

### Writing Effective Tasks

**✅ Good tasks** (specific and actionable):
```
- Fix authentication bug in src/auth/login.ts line 42
- Add dark mode toggle to Settings page with theme persistence
- Update API documentation for /users endpoint with examples
```

**❌ Avoid vague tasks** (lead to loops):
```
- Improve performance
- Make it better
- Fix bugs
```

### Task Management

1. **Monitor failed tasks**: Check `.claude/task-queue-failed.md` regularly
2. **Validate completions**: Review `todo-completed.md` before clearing
3. **Clean up sessions**: Run cleanup script periodically
4. **Adjust thresholds**: Increase `CLAUDE_TASK_MAX_ITERATIONS` for complex tasks

### Session Guidelines

1. **Use isolation**: Keep experimental work in separate sessions
2. **One mode per session**: Don't toggle mid-task
3. **One session per terminal**: Avoid confusion
4. **Monitor states**: Check debug logs to understand behavior

## Maintenance

### Cleanup Operations

```bash
# Clean up stale session files
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh

# Clear validated completed tasks
rm todo-completed.md

# Clear failed tasks log
rm .claude/task-queue-failed.md

# Clear debug log
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh clear
```

### Regular Maintenance

- **Weekly**: Run session cleanup script
- **After major work**: Clear completed and failed logs
- **Before archiving**: Clear all queue state files
- **When debugging**: Review debug log for patterns

## Advanced Usage

See [USAGE-EXAMPLES.md](./USAGE-EXAMPLES.md) for:
- Real-world usage scenarios
- Complex multi-session workflows
- Integration with CI/CD
- Team collaboration patterns
- Advanced troubleshooting

## Security Considerations

The queue system is designed with security in mind:

- **Explicit opt-in required**: No accidental activation
- **Session whitelist**: Only authorized sessions run autonomously
- **Regular sessions unaffected**: Commands work normally
- **Circuit breaker**: Prevents runaway loops
- **Comprehensive logging**: Full audit trail

## Troubleshooting

For comprehensive troubleshooting, consult the skill:

```bash
# In Claude Code
"How do I troubleshoot the autonomous queue?"
"Queue not starting, help me debug"
"Task stuck in loop, what should I do?"
```

The autonomous-queue-usage skill provides detailed guidance for:
- Queue activation issues
- Task loop problems
- Session conflicts
- Completion failures
- Performance problems

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Author

**Albert Nahas**
Email: albert@nahas.dev
GitHub: [@albertnahas](https://github.com/albertnahas)

## Acknowledgments

Built with [Claude Code](https://claude.com/code) - the AI-powered coding assistant.

---

**Need help?** Open an issue on [GitHub](https://github.com/albertnahas/autonomous-claude-queue/issues)
