# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Claude Code PM system - a comprehensive project management workflow that integrates Claude Code with GitHub Issues, Git worktrees, and parallel AI agents for spec-driven development.

## System Architecture

The system is organized around the `.claude/` directory:

```
.claude/
├── CLAUDE.md           # Core rules and philosophy
├── agents/             # Specialized task agents
├── commands/           # Command definitions (PM, context, testing, etc.)
├── context/            # Project-wide context files
├── epics/              # Local workspace for epics and tasks
├── prds/               # Product Requirements Documents
├── rules/              # Additional rule files
└── scripts/            # Automation scripts
```

## Common Commands

### Project Management Commands
- `/pm:init` - Initialize PM system with GitHub integration
- `/pm:prd-new <name>` - Create new Product Requirements Document
- `/pm:prd-parse <name>` - Convert PRD to technical epic
- `/pm:epic-oneshot <name>` - Decompose epic and sync to GitHub
- `/pm:issue-start <number>` - Begin work on GitHub issue
- `/pm:next` - Get next priority task
- `/pm:status` - Show overall project status

### Context Management
- `/context:create` - Generate initial project context
- `/context:update` - Refresh context with recent changes
- `/context:prime` - Load context into current session

### Testing
- `/testing:prime` - Configure testing setup
- `/testing:run [target]` - Execute tests with analysis

## Core Philosophy

### Spec-Driven Development
Every line of code must trace back to a specification. Follow the 5-phase discipline:
1. **Brainstorm** - Think deeper than comfortable
2. **Document** - Write specs that leave nothing to interpretation
3. **Plan** - Architect with explicit technical decisions
4. **Execute** - Build exactly what was specified
5. **Track** - Maintain transparent progress

### Sub-Agent Usage
Always use specialized agents for heavy work to preserve context:
- **file-analyzer**: Analyze verbose files and logs
- **code-analyzer**: Search code, analyze bugs, trace logic flow
- **test-runner**: Execute tests and analyze results
- **parallel-worker**: Coordinate parallel work streams

### Error Handling Strategy
- **Fail fast** for critical configuration
- **Log and continue** for optional features
- **Graceful degradation** when external services unavailable

## GitHub Integration

The system uses GitHub Issues as the source of truth:
- Issues maintain project state and progress
- Comments provide audit trail
- Labels organize work (`epic:name`, `task:name`)
- Uses `gh-sub-issue` extension for parent-child relationships

## Parallel Execution Model

Issues are decomposed into multiple parallel work streams:
- Multiple agents work simultaneously in the same worktree
- Each agent handles specific concerns (database, API, UI, tests)
- Main conversation stays clean and strategic
- Complex orchestration happens locally, syncs simply to GitHub

## Development Workflow

1. **Create PRD**: `/pm:prd-new feature-name` - Comprehensive brainstorming
2. **Plan Implementation**: `/pm:prd-parse feature-name` - Technical breakdown
3. **Decompose Tasks**: `/pm:epic-oneshot feature-name` - Create GitHub issues
4. **Execute Parallel**: `/pm:issue-start <number>` - Launch specialized agents
5. **Track Progress**: `/pm:status` - Monitor overall progress

## File Conventions

- PRDs: `.claude/prds/feature-name.md`
- Epics: `.claude/epics/feature-name/epic.md`
- Tasks: Initially `001.md`, `002.md` → renamed to `{issue-id}.md` after GitHub sync
- Context: `.claude/context/` - Project documentation for context preservation

## Integration with Existing Tools

- **GitHub CLI**: Required for issue management (`gh` command)
- **Git Worktrees**: For isolated parallel development
- **GitHub Issues**: Central coordination and progress tracking
- Works with existing GitHub workflows and team processes

## Key Benefits

- **Context Preservation**: Never lose project state between sessions
- **Parallel Execution**: Multiple agents working simultaneously
- **Full Traceability**: Complete audit trail from PRD to production
- **Team Collaboration**: Human and AI agents work together transparently
- **GitHub Native**: Uses tools teams already trust