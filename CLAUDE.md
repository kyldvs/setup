# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

<!-- <beads-rules> -->

# Issue Tracking

This project uses [bd (beads)](https://github.com/steveyegge/beads) for issue
tracking. Use `bd` commands instead of markdown TODOs.

## Quick Start

- `bd ready` - Show issues ready to work (no blockers)
- `bd create "Title" -t task` - Create new issue
- `bd update <id> --status in_progress` - Claim work
- `bd close <id>` - Mark complete

## Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item
- `epic` - Large feature with subtasks
- `chore` - Maintenance

## Priorities

- `0` Critical, `1` High, `2` Medium (default), `3` Low, `4` Backlog

## Labels (Task Maturity)

- `spike` - Research/investigation task that will generate other refined tasks
- `draft` - Task needing more information before work can begin
- `refined` - Vetted task ready to start immediately

## Rules

- Use bd for ALL task tracking (no markdown TODOs)
- Link discovered work with `--deps discovered-from:<id>`
- Check `bd ready` before asking "what to work on"

<!-- </beads-rules> -->

<!-- <sdd-rules> -->

# Spec-Driven Development

This project uses spec-driven development (SDD) for feature work.

## Quick Start

- Use the **pm** subagent to create a new spec with beads issue
- Use the **researcher** subagent to research codebase and external sources
- Use the **historian** subagent to record changes to history

## Workflow

1. **Create spec**: Ask pm subagent to create spec for feature
2. **Refine**: Add scenarios, requirements, success criteria
3. **Plan**: Break into tasks with `bd create`
4. **Implement**: Work through tasks
5. **Record**: historian subagent logs significant changes
6. **Close**: `bd close <id>`

## File Locations

- Specs: `docs/specs/<name>/spec.md`
- Spec index: `docs/specs/index.md`
- History: `docs/history/current.md`

## Rules

- Every feature MUST have a spec before implementation
- Every spec MUST link to a beads issue (via `beads-id` frontmatter)
- Record significant changes with historian subagent
- Use researcher subagent before making architectural decisions

<!-- </sdd-rules> -->

## Overview

This is a personal macOS/Linux setup automation repository. It bootstraps a new
machine by installing applications, configuring system settings, and linking
dotfiles.

## Commands

All commands use [Just](https://github.com/casey/just) as the task runner. The
main entry point is the `kyldvs` command (after bootstrap), which defers to
Just.

```bash
# Bootstrap a fresh machine (run from curl)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/kyldvs/setup/HEAD/bootstrap.sh)"

# After bootstrap, the kyldvs command is available
kyldvs help              # Show all available commands
kyldvs sync              # Pull latest changes from github
kyldvs setup all         # Run all setup tasks
kyldvs setup ...         # Other specific setup commands
```
