# Usage Examples

Practical examples and real-world scenarios for the Autonomous Claude Queue.

## Table of Contents

1. [Basic Workflows](#basic-workflows)
2. [Feature Development](#feature-development)
3. [Bug Fixing Sprint](#bug-fixing-sprint)
4. [Documentation Updates](#documentation-updates)
5. [Refactoring Projects](#refactoring-projects)
6. [Multi-Session Workflows](#multi-session-workflows)
7. [Team Collaboration](#team-collaboration)
8. [Integration Scenarios](#integration-scenarios)

## Basic Workflows

### Simple Task List

**Scenario**: You have a list of small tasks to complete.

```bash
# Add all tasks at once
/todo "Fix typo in README; Update dependencies; Run security audit"

# Enable autonomous mode
/queue-toggle

# Claude will:
# 1. Fix typo in README → commit
# 2. Update dependencies → commit
# 3. Run security audit → commit
# 4. Stop when queue is empty
```

**Expected outcome**: Three separate commits, each completing one task.

### Single Complex Task

**Scenario**: One task requires multiple iterations to complete.

```bash
# Add complex task
/todo "Implement user authentication with email and password"

# Set higher iteration limit for complex task
export CLAUDE_TASK_MAX_ITERATIONS=20

# Enable autonomous mode
/queue-toggle

# Claude will:
# - Break down implementation into steps
# - Work through each step
# - Self-evaluate after each iteration
# - Complete when 100% done (up to 20 iterations)
```

**Task completion criteria**:
1. Auth routes implemented
2. Database models created
3. Validation added
4. Tests written
5. Documentation updated

## Feature Development

### Full Feature Implementation

**Scenario**: Implement a complete feature from scratch.

```bash
# Break feature into logical tasks
/todo "Create database schema for blog posts"
/todo "Implement blog post CRUD API endpoints"
/todo "Add blog post validation and error handling"
/todo "Write unit tests for blog API"
/todo "Write integration tests for blog feature"
/todo "Add API documentation for blog endpoints"
/todo "Update frontend to use new blog API"

# Enable autonomous mode
/queue-toggle

# Claude will work through each task sequentially
# Each task gets committed separately
# Full audit trail in git history
```

**Benefits**:
- Clear separation of concerns
- Atomic commits per task
- Easy to review progress
- Can stop/resume at any point

### Feature with Dependencies

**Scenario**: Tasks that must complete in order.

```bash
# Tasks have natural dependencies
/todo "Create User model and migration"
/todo "Add user authentication endpoints (depends on User model)"
/todo "Add user profile endpoints (depends on auth)"
/todo "Write tests for user endpoints"

# Enable autonomous mode
/queue-toggle

# Claude completes in order:
# 1. User model → commit
# 2. Auth endpoints → commit (uses User model)
# 3. Profile endpoints → commit (uses auth)
# 4. Tests → commit
```

**Safety**: Each task commits before moving to next, so dependencies are always available.

## Bug Fixing Sprint

### Multiple Bug Fixes

**Scenario**: You have a list of bugs from an issue tracker.

```bash
# Copy bug list from issue tracker
/todo "Fix memory leak in dashboard polling (Issue #123)"
/todo "Fix broken image upload on mobile (Issue #124)"
/todo "Fix date formatting in Safari (Issue #125)"
/todo "Fix API timeout handling (Issue #126)"
/todo "Fix missing error messages in login form (Issue #127)"

# Enable autonomous mode
/queue-toggle

# Claude will:
# - Work through each bug
# - Create fix → test → commit
# - Include issue number in commit message
# - Move to next bug
```

**Commit messages** will include issue numbers for traceability:
```
Fix memory leak in dashboard polling (#123)
Fix broken image upload on mobile (#124)
...
```

### Bug Fix with Root Cause Analysis

**Scenario**: Complex bug requiring investigation.

```bash
# Single complex bug
/todo "Investigate and fix intermittent authentication failures (Issue #200)"

# Increase iteration limit for investigation
export CLAUDE_TASK_MAX_ITERATIONS=25

# Enable autonomous mode
/queue-toggle

# Claude will:
# 1. Investigate logs and code
# 2. Identify root cause
# 3. Implement fix
# 4. Add regression tests
# 5. Document findings
# 6. Commit when complete
```

## Documentation Updates

### Comprehensive Documentation Sprint

**Scenario**: Update all documentation across project.

```bash
# Documentation tasks
/todo "Update README with new features"
/todo "Add API documentation for v2 endpoints"
/todo "Create deployment guide"
/todo "Write troubleshooting guide"
/todo "Update contributing guidelines"
/todo "Add code examples to docs"

# Enable autonomous mode
/queue-toggle

# Claude will:
# - Complete each doc task
# - Ensure consistency across docs
# - Commit each separately
```

**Benefits**:
- Consistent documentation style
- Complete coverage
- Atomic commits per doc section

### Documentation Following Code Changes

**Scenario**: Update docs after implementing features.

```bash
# Implementation tasks first
/todo "Implement OAuth2 authentication"
/todo "Add rate limiting to API"

# Then documentation tasks
/todo "Document OAuth2 setup in README"
/todo "Add OAuth2 examples to API docs"
/todo "Document rate limit headers"
/todo "Update API changelog"

# Enable autonomous mode
/queue-toggle

# Code implementation completes first
# Then documentation updates referencing the implementation
```

## Refactoring Projects

### Incremental Refactoring

**Scenario**: Refactor codebase gradually without breaking changes.

```bash
# Break refactoring into safe increments
/todo "Extract UserService from UserController"
/todo "Move validation logic to UserValidator class"
/todo "Refactor database queries to use query builder"
/todo "Extract error handling to middleware"
/todo "Update tests for refactored code"
/todo "Remove deprecated functions"

# Enable autonomous mode
/queue-toggle

# Each refactoring step:
# - Makes targeted change
# - Ensures tests pass
# - Commits immediately
# - Moves to next step
```

**Safety**: Small, atomic refactorings with tests ensure nothing breaks.

### Test-Driven Refactoring

**Scenario**: Add tests before refactoring.

```bash
# Tests first, then refactoring
/todo "Add tests for existing UserController functionality"
/todo "Refactor UserController with confidence"
/todo "Add tests for error edge cases"
/todo "Refactor error handling based on tests"

# Enable autonomous mode
/queue-toggle

# Tests written first ensure refactoring doesn't break functionality
```

## Multi-Session Workflows

### Parallel Feature Development

**Scenario**: Multiple developers (or sessions) working on different features.

```bash
# Terminal 1 - Feature A
claude
/todo "Implement blog post creation"
/todo "Add blog post validation"
/todo "Write blog post tests"
/queue-toggle
# Session A works on blog feature

# Terminal 2 - Feature B
claude
/todo "Implement user profile editing"
/todo "Add profile image upload"
/todo "Write profile tests"
/queue-toggle
# Session B works on profile feature independently

# Terminal 3 - Bug fixes
claude
/todo "Fix login redirect issue"
/todo "Fix mobile menu bug"
/queue-toggle
# Session C works on bugs
```

**Result**: Three features/fixes developed in parallel without conflicts.

### Split Complex Task

**Scenario**: Break large task into parallel subtasks.

```bash
# Terminal 1 - Frontend
claude
/todo "Create blog post form UI"
/todo "Add blog post list view"
/todo "Implement blog post editing UI"
/queue-toggle

# Terminal 2 - Backend
claude
/todo "Implement blog post API endpoints"
/todo "Add blog post database models"
/todo "Write API tests"
/queue-toggle

# Both sessions work simultaneously
# Merge results when both complete
```

### Emergency Fix While Feature Development

**Scenario**: Critical bug needs fix while feature development continues.

```bash
# Terminal 1 - Ongoing feature work (autonomous)
claude
/todo "Continue implementing payment integration"
/queue-toggle
# Long-running feature work

# Terminal 2 - Emergency bug fix (manual)
claude
# Fix critical production bug manually
# Commit and deploy immediately
# Exit

# Terminal 1 continues autonomous feature work unaffected
```

## Team Collaboration

### Task Handoff

**Scenario**: One developer prepares tasks for another.

```bash
# Developer A creates task list
/todo "Implement user registration API"
/todo "Add email verification flow"
/todo "Create password reset functionality"

# Commits task list to git
git add todo.md
git commit -m "Add authentication tasks for Dev B"
git push

# Developer B pulls and starts
git pull
/queue-toggle
# Autonomous work begins on shared task list
```

### Code Review Preparation

**Scenario**: Prepare multiple PRs for review.

```bash
# Create separate tasks for each PR
/todo "Feature: Blog post creation (target: feature/blog-posts branch)"
/todo "Feature: User profiles (target: feature/user-profiles branch)"
/todo "Refactor: Extract services (target: refactor/services branch)"

# Enable autonomous mode
/queue-toggle

# Each task:
# 1. Completes implementation
# 2. Commits to appropriate branch
# 3. Ready for PR creation
```

### Documentation Handoff

**Scenario**: Developer implements, technical writer documents.

```bash
# Developer implements features
/todo "Implement feature X"
/todo "Write technical notes for feature X"
/queue-toggle

# After completion, technical writer reviews notes
# And creates user-facing documentation
```

## Integration Scenarios

### CI/CD Integration

**Scenario**: Prepare commits for automated CI/CD pipeline.

```bash
# Tasks that must pass CI individually
/todo "Add feature X with tests"
/todo "Update API version"
/todo "Update changelog"

# Enable autonomous mode
/queue-toggle

# Each task commits separately
# CI runs on each commit
# Failed commits are easy to identify
```

### Pre-Commit Hook Integration

**Scenario**: Each commit must pass linting and formatting.

```bash
# Assume pre-commit hooks configured for:
# - ESLint
# - Prettier
# - Type checking

/todo "Add user dashboard feature"
/todo "Add admin panel feature"
/todo "Add reporting feature"

# Enable autonomous mode
/queue-toggle

# Each task:
# 1. Implements feature
# 2. Runs pre-commit hooks automatically
# 3. Fixes any linting/format issues
# 4. Commits only when hooks pass
```

### Pull Request Workflow

**Scenario**: Create multiple PRs from autonomous work.

```bash
# Each task becomes a PR
/todo "Feature: Dark mode toggle"
/todo "Feature: Export to CSV"
/todo "Feature: Advanced filters"

# Enable autonomous mode
/queue-toggle

# After completion:
# 1. Each feature has separate commit
# 2. Create branch per feature
# 3. Create PR per branch
# 4. Review and merge independently
```

## Advanced Patterns

### Conditional Tasks

**Scenario**: Tasks depend on success of previous tasks.

```bash
# Primary task
/todo "Run full test suite"

# Monitor for completion
/todo status

# If tests pass, add deployment tasks
/todo "Deploy to staging"
/todo "Run smoke tests on staging"
/todo "Deploy to production"

/queue-toggle
```

### Batch Processing

**Scenario**: Process multiple similar items.

```bash
# Generate task list programmatically
echo "- Update user avatar for user ID 1001" >> todo.md
echo "- Update user avatar for user ID 1002" >> todo.md
echo "- Update user avatar for user ID 1003" >> todo.md
# ... 100 more users

/queue-toggle

# Each user processed and committed separately
# Can stop/resume at any point
```

### Recovery from Failure

**Scenario**: Some tasks fail, need to retry or skip.

```bash
# Initial task list
/todo "Task A; Task B; Task C; Task D; Task E"
/queue-toggle

# After run, check failures
cat .claude/task-queue-failed.md

# Output:
# - [FAILED: Max iterations exceeded] Task C

# Retry failed task with higher threshold
export CLAUDE_TASK_MAX_ITERATIONS=20
/todo "Task C (retry with more iterations)"
/queue-toggle

# Or skip and continue with remaining work
# Failed task stays in log for review
```

### Monitoring Long-Running Queues

**Scenario**: Monitor autonomous work progress.

```bash
# Terminal 1 - Autonomous work
/todo "Task 1; Task 2; Task 3; ... Task 20"
/queue-toggle

# Terminal 2 - Monitor progress
watch -n 10 'bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh decisions'

# Or follow log in real-time
bash $CLAUDE_PLUGIN_ROOT/scripts/view-queue-logs.sh follow
```

## Tips and Tricks

### Task Granularity

**Too granular** (inefficient):
```bash
/todo "Import React"
/todo "Create component file"
/todo "Add props interface"
/todo "Implement render method"
```

**Too broad** (will hit iteration limit):
```bash
/todo "Implement entire user management system"
```

**Just right**:
```bash
/todo "Implement user list component with pagination"
/todo "Implement user detail view"
/todo "Add user creation form"
```

### Iteration Threshold Guidelines

| Task Complexity | Max Iterations | Example |
|-----------------|----------------|---------|
| Simple fix | 5-10 (default) | Fix typo, update config |
| Medium task | 10-15 | Implement CRUD endpoint |
| Complex feature | 15-25 | Authentication system |
| Investigation | 20-30 | Debug intermittent issue |

### Commit Message Quality

The quality of commits depends on task descriptions:

**Good task** → **Good commit**:
```
Task: "Fix memory leak in dashboard polling (Issue #123)"
Commit: "Fix memory leak in dashboard polling (#123)

Reduced polling interval and added cleanup on unmount
to prevent memory accumulation."
```

**Vague task** → **Vague commit**:
```
Task: "Fix bug"
Commit: "Fix bug

Made some changes."
```

### Emergency Stop

If you need to stop autonomous execution immediately:

```bash
# Option 1: Disable autonomous mode
/queue-toggle

# Option 2: Remove session from whitelist
# Edit .claude/task-queue-allowed-sessions
# Remove your session ID line

# Option 3: Globally disable queue
export CLAUDE_TASK_QUEUE=disabled
```

### Best Time to Use Autonomous Mode

**✅ Great for**:
- Multiple small, similar tasks
- Batch updates across files
- Documentation sprints
- Bug fixing sessions
- Incremental refactoring
- Repetitive work

**❌ Avoid for**:
- Tasks requiring user input
- Exploratory work
- Design decisions
- Architecture planning
- Code review
- Testing new ideas

## Workflow Examples

### Morning Task Planning

```bash
# Review yesterday's work
git log --oneline -10

# Plan today's tasks
/todo "Complete feature X from yesterday"
/todo "Fix bug reported overnight"
/todo "Update docs for completed features"
/todo "Prepare demo for standup"

# Start autonomous work
/queue-toggle

# Focus on other work while Claude executes
```

### End of Day Cleanup

```bash
# Clean up completed work
rm todo-completed.md

# Clear failed tasks after review
rm .claude/task-queue-failed.md

# Clean up stale sessions
bash $CLAUDE_PLUGIN_ROOT/scripts/cleanup-stale-sessions.sh

# Commit queue state for tomorrow
git add todo.md .claude/task-queue-*
git commit -m "Save task queue state"
```

### Sprint Planning

```bash
# Break sprint stories into tasks
/todo "Story 1: User can create blog posts"
/todo "Story 2: User can edit blog posts"
/todo "Story 3: User can delete blog posts"
/todo "Story 4: User can view blog post history"

# Set appropriate threshold for story complexity
export CLAUDE_TASK_MAX_ITERATIONS=20

# Start sprint work
/queue-toggle

# Monitor progress daily via /todo status
```

## Conclusion

The Autonomous Claude Queue is a powerful tool for automating sequential task execution. Use it to:

- **Increase productivity** by handling repetitive tasks
- **Maintain quality** through atomic commits and safety mechanisms
- **Enable parallelism** with multi-session support
- **Preserve history** with detailed logging and git commits

Start with simple workflows and gradually adopt more complex patterns as you become comfortable with the system.

For more information, see:
- [README.md](./README.md) - Main documentation
- [Skill documentation](./skills/autonomous-queue-usage/SKILL.md) - Detailed usage guide
- [Troubleshooting guide](./skills/autonomous-queue-usage/references/troubleshooting.md) - Problem solving
