#!/bin/bash

# Issue Start Script
# Begin work on a GitHub issue with parallel agents based on work stream analysis

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
  echo -e "${RED}❌ $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✅ $1${NC}"
}

warning() {
  echo -e "${YELLOW}⚠️ $1${NC}"
}

info() {
  echo -e "${BLUE}ℹ️ $1${NC}"
}

# Check arguments
if [ $# -eq 0 ]; then
  error "Usage: $0 <issue_number> [--analyze]"
fi

ISSUE_NUMBER="$1"
ANALYZE_FLAG="$2"

# Validate issue number is numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
  error "Issue number must be numeric: $ISSUE_NUMBER"
fi

echo "🚀 Starting work on issue #$ISSUE_NUMBER"
echo ""

# 1. Quick Check - Get issue details
echo "🔍 Checking issue details..."
if ! gh issue view "$ISSUE_NUMBER" --json state,title,labels,body > /dev/null 2>&1; then
  error "Cannot access issue #$ISSUE_NUMBER. Check number or run: gh auth login"
fi

ISSUE_DATA=$(gh issue view "$ISSUE_NUMBER" --json state,title,labels,body)
ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
ISSUE_STATE=$(echo "$ISSUE_DATA" | jq -r '.state')

if [ "$ISSUE_STATE" != "OPEN" ]; then
  error "Issue #$ISSUE_NUMBER is not open (state: $ISSUE_STATE)"
fi

success "Issue #$ISSUE_NUMBER: $ISSUE_TITLE"

# 2. Find local task file
echo ""
echo "📁 Finding local task file..."

TASK_FILE=""
EPIC_NAME=""

# First check new naming convention: .claude/epics/*/{issue}.md
for epic_dir in .claude/epics/*/; do
  if [ -f "${epic_dir}${ISSUE_NUMBER}.md" ]; then
    TASK_FILE="${epic_dir}${ISSUE_NUMBER}.md"
    EPIC_NAME=$(basename "$epic_dir")
    break
  fi
done

# If not found, search old naming convention
if [ -z "$TASK_FILE" ]; then
  TASK_FILE=$(find .claude/epics -name "*.md" -exec grep -l "github:.*issues/$ISSUE_NUMBER" {} \; 2>/dev/null | head -1)
  if [ -n "$TASK_FILE" ]; then
    EPIC_NAME=$(basename "$(dirname "$TASK_FILE")")
  fi
fi

if [ -z "$TASK_FILE" ]; then
  error "No local task for issue #$ISSUE_NUMBER. This issue may have been created outside the PM system."
fi

success "Found task file: $TASK_FILE"
info "Epic: $EPIC_NAME"

# 3. Check for analysis
echo ""
echo "🔬 Checking for analysis..."
ANALYSIS_FILE=".claude/epics/$EPIC_NAME/${ISSUE_NUMBER}-analysis.md"

if [ ! -f "$ANALYSIS_FILE" ]; then
  if [ "$ANALYZE_FLAG" = "--analyze" ]; then
    warning "No analysis found for issue #$ISSUE_NUMBER"
    echo "Run: /pm:issue-analyze $ISSUE_NUMBER first"
    echo "Or: /pm:issue-start $ISSUE_NUMBER --analyze to do both"
    exit 1
  else
    error "No analysis found for issue #$ISSUE_NUMBER

Run: /pm:issue-analyze $ISSUE_NUMBER first
Or: /pm:issue-start $ISSUE_NUMBER --analyze to do both"
  fi
fi

success "Analysis found: $ANALYSIS_FILE"

# 4. Ensure worktree exists
echo ""
echo "🌳 Checking epic worktree..."
WORKTREE_NAME="epic-$EPIC_NAME"

if ! git worktree list | grep -q "$WORKTREE_NAME"; then
  error "No worktree for epic. Run: /pm:epic-start $EPIC_NAME"
fi

WORKTREE_PATH="../$WORKTREE_NAME"
success "Worktree exists: $WORKTREE_PATH"

# 5. Read and parse analysis
echo ""
echo "📊 Reading analysis..."

if [ ! -r "$ANALYSIS_FILE" ]; then
  error "Cannot read analysis file: $ANALYSIS_FILE"
fi

# Extract streams that can start immediately using grep and sed
STREAMS_READY=""

# Create temporary file to process streams
TEMP_FILE=$(mktemp)
grep -n "^### Stream\|^\*\*Agent Type\*\*\|^\*\*Can Start\*\*" "$ANALYSIS_FILE" > "$TEMP_FILE"

# Process each stream
current_letter=""
current_name=""
current_agent=""
current_can_start=""

while IFS=':' read -r line_num remainder; do
  content="$remainder"
  if echo "$content" | grep -q "^### Stream"; then
    # Process previous stream if complete
    if [[ "$current_can_start" == "immediately" && -n "$current_agent" && -n "$current_letter" ]]; then
      if [[ -n "$STREAMS_READY" ]]; then
        STREAMS_READY="$STREAMS_READY"$'\n'"$current_letter|$current_name|$current_agent"
      else
        STREAMS_READY="$current_letter|$current_name|$current_agent"
      fi
    fi
    
    # Start new stream
    current_letter=$(echo "$content" | sed 's/^### Stream \([A-Z]\): .*/\1/')
    current_name=$(echo "$content" | sed 's/^### Stream [A-Z]: \(.*\)/\1/')
    current_agent=""
    current_can_start=""
    
  elif echo "$content" | grep -q "^\*\*Agent Type\*\*:"; then
    current_agent=$(echo "$content" | sed 's/^\*\*Agent Type\*\*: \(.*\)/\1/')
    
  elif echo "$content" | grep -q "^\*\*Can Start\*\*: immediately"; then
    current_can_start="immediately"
  fi
done < "$TEMP_FILE"

# Process last stream
if [[ "$current_can_start" == "immediately" && -n "$current_agent" && -n "$current_letter" ]]; then
  if [[ -n "$STREAMS_READY" ]]; then
    STREAMS_READY="$STREAMS_READY"$'\n'"$current_letter|$current_name|$current_agent"
  else
    STREAMS_READY="$current_letter|$current_name|$current_agent"
  fi
fi

rm -f "$TEMP_FILE"

if [ -z "$STREAMS_READY" ]; then
  error "No streams ready to start immediately. Check analysis file."
fi

# 6. Setup progress tracking
echo ""
echo "📈 Setting up progress tracking..."

CURRENT_DATETIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
UPDATES_DIR=".claude/epics/$EPIC_NAME/updates/$ISSUE_NUMBER"

mkdir -p "$UPDATES_DIR"
success "Created updates directory: $UPDATES_DIR"

# Update task file frontmatter with current datetime
if command -v sed > /dev/null; then
  # Use sed to update the updated field in frontmatter
  sed -i.bak "s/^updated: .*/updated: $CURRENT_DATETIME/" "$TASK_FILE" 2>/dev/null || {
    # Fallback: add updated field if it doesn't exist
    sed -i.bak "/^---$/i\\
updated: $CURRENT_DATETIME" "$TASK_FILE"
  }
  rm -f "${TASK_FILE}.bak"
fi

# 7. Launch parallel agents
echo ""
echo "🤖 Launching parallel agents..."

STREAM_COUNT=0
AGENT_COMMANDS=""

while IFS='|' read -r stream_letter stream_name agent_type; do
  if [ -z "$stream_letter" ]; then continue; fi
  
  STREAM_COUNT=$((STREAM_COUNT + 1))
  
  
  # Create stream progress file
  STREAM_FILE="$UPDATES_DIR/stream-$stream_letter.md"
  
  cat > "$STREAM_FILE" << EOF
---
issue: $ISSUE_NUMBER
stream: $stream_name
agent: $agent_type
started: $CURRENT_DATETIME
status: in_progress
---

# Stream $stream_letter: $stream_name

## Scope
Starting implementation for assigned work stream.

## Files
See analysis file for file patterns.

## Progress
- Starting implementation
EOF

  success "Created stream file: $STREAM_FILE"
  
  # Note: The actual Task tool invocation would happen in the calling Claude Code environment
  # This script just sets up the structure and reports what needs to be done
  AGENT_COMMANDS="$AGENT_COMMANDS
Stream $stream_letter: $stream_name ($agent_type)"

done <<< "$STREAMS_READY"

# 8. GitHub assignment
echo ""
echo "🐙 Updating GitHub issue..."

if gh issue edit "$ISSUE_NUMBER" --add-assignee @me --add-label "in-progress" 2>/dev/null; then
  success "Assigned issue to self and marked in-progress"
else
  warning "Could not update GitHub issue (may not have permissions)"
fi

# 9. Output summary
echo ""
echo "✅ Started parallel work on issue #$ISSUE_NUMBER"
echo ""
echo "Epic: $EPIC_NAME"
echo "Worktree: $WORKTREE_PATH"
echo ""
echo "Ready to launch $STREAM_COUNT parallel agents:$AGENT_COMMANDS"
echo ""
echo "Progress tracking:"
echo "  $UPDATES_DIR"
echo ""
echo "Next steps:"
echo "  Monitor with: /pm:epic-status $EPIC_NAME"
echo "  Sync updates: /pm:issue-sync $ISSUE_NUMBER"
echo ""
echo "Note: Actual agent launching requires Claude Code Task tool invocation."
echo "This script has prepared the environment and tracking structure."

exit 0