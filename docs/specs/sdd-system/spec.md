---
beads-id: k-ngh
status: in-progress
created: 2025-11-24
updated: 2025-11-24
---

# SDD System Implementation

## Context
**Beads Issue**: k-ngh

Set up a spec-driven development process with custom sub-agents, a `./docs` folder for specs/plans, and tight beads integration. Adopts patterns from GitHub's spec-kit but uses custom implementations for flexibility.

## User Scenarios

### P1: Create a New Feature Spec
- **Given** a feature idea
- **When** running `/pm <feature description>`
- **Then** a beads issue is created, spec folder is made, and template is populated

### P1: Record Changes
- **Given** completed work
- **When** running `/historian <summary>`
- **Then** entry is added to `docs/history/current.md` with date and details

### P2: Research Context
- **Given** a question about codebase or external info
- **When** running `/researcher <query>`
- **Then** relevant code patterns, beads issues, and external sources are found

## Requirements
- **FR-001**: System MUST provide `/researcher` command for codebase and external search
- **FR-002**: System MUST provide `/historian` command for change logging
- **FR-003**: System MUST provide `/pm` command for spec creation
- **FR-004**: All specs MUST link to beads issues via frontmatter
- **FR-005**: History MUST auto-archive at 50 entries

## Success Criteria
- **SC-001**: All three sub-agents functional and documented in CLAUDE.md
- **SC-002**: Spec index links specs to beads issues
- **SC-003**: History archiving works correctly

## Notes
- PM agent can chain-call researcher for context
- No external CLI dependencies (spec-kit patterns only)
