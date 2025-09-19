---
allowed-tools: Bash, Read, Write, LS, Task
---

# Issue Start

Begin work on a GitHub issue with parallel agents based on work stream analysis.

## Usage
```
/pm:issue-start <issue_number>
```

## Quick Check

1. **Get issue details:**
   ```bash
   gh issue view 4 --json state,title,labels,body
   ```
   If it fails: "❌ Cannot access issue #4. Check number or run: gh auth login"

2. **Find local task file:**
   - First check if `.claude/epics/*/4.md` exists (new naming)
   - If not found, search for file containing `github:.*issues/4` in frontmatter (old naming)
   - If not found: "❌ No local task for issue #4. This issue may have been created outside the PM system."

3. **Check for analysis:**
   ```bash
   test -f .claude/epics/*/4-analysis.md || echo "❌ No analysis found for issue #4
   
   Run: /pm:issue-analyze 4 first
   Or: /pm:issue-start 4 --analyze to do both"
   ```
   If no analysis exists and no --analyze flag, stop execution.

## Instructions

### 1. Ensure Worktree Exists

Check if epic worktree exists:
```bash
# Find epic name from task file
epic_name={extracted_from_path}

# Check worktree
if ! git worktree list | grep -q "epic-$epic_name"; then
  echo "❌ No worktree for epic. Run: /pm:epic-start $epic_name"
  exit 1
fi
```

### 2. Read Analysis

Read `.claude/epics/{epic_name}/4-analysis.md`:
- Parse parallel streams
- Identify which can start immediately
- Note dependencies between streams

### 3. Setup Progress Tracking

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create workspace structure:
```bash
mkdir -p .claude/epics/{epic_name}/updates/4
```

Update task file frontmatter `updated` field with current datetime.

### 4. Launch Parallel Agents

For each stream that can start immediately:

Create `.claude/epics/{epic_name}/updates/4/stream-{X}.md`:
```markdown
---
issue: 4
stream: {stream_name}
agent: {agent_type}
started: {current_datetime}
status: in_progress
---

# Stream {X}: {stream_name}

## Scope
{stream_description}

## Files
{file_patterns}

## Progress
- Starting implementation
```

Launch agent using Task tool:
```yaml
Task:
  description: "Issue #4 Stream {X}"
  subagent_type: "{agent_type}"
  prompt: |
    You are working on Issue #4 in the epic worktree.
    
    Worktree location: ../epic-{epic_name}/
    Your stream: {stream_name}
    
    Your scope:
    - Files to modify: {file_patterns}
    - Work to complete: {stream_description}
    
    Requirements:
    1. Read full task from: .claude/epics/{epic_name}/{task_file}
    2. Work ONLY in your assigned files
    3. Commit frequently with format: "Issue #4: {specific change}"
    4. Update progress in: .claude/epics/{epic_name}/updates/4/stream-{X}.md
    5. Follow coordination rules in /rules/agent-coordination.md
    
    If you need to modify files outside your scope:
    - Check if another stream owns them
    - Wait if necessary
    - Update your progress file with coordination notes
    
    Complete your stream's work and mark as completed when done.
```

### 5. GitHub Assignment

```bash
# Assign to self and mark in-progress
gh issue edit 4 --add-assignee @me --add-label "in-progress"
```

### 6. Output

```
✅ Started parallel work on issue #4

Epic: {epic_name}
Worktree: ../epic-{epic_name}/

Launching {count} parallel agents:
  Stream A: {name} (Agent-1) ✓ Started
  Stream B: {name} (Agent-2) ✓ Started
  Stream C: {name} - Waiting (depends on A)

Progress tracking:
  .claude/epics/{epic_name}/updates/4/

Monitor with: /pm:epic-status {epic_name}
Sync updates: /pm:issue-sync 4
```

## Error Handling

If any step fails, report clearly:
- "❌ {What failed}: {How to fix}"
- Continue with what's possible
- Never leave partial state

## Important Notes

Follow `/rules/datetime.md` for timestamps.
Keep it simple - trust that GitHub and file system work.