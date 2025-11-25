# Setup State Tracking

**One-liner**: Add JSON-based state tracking to the setup system with step status, undo capability, and manual step prompting.

## Problem

The current `just setup all` command runs all setup tasks sequentially with no memory of what's been done. Re-running is slow (checks each step), there's no way to undo changes, and manual steps (like Arc configuration) are just comments in scripts.

## Success Criteria

- [ ] `just setup all` is a fast no-op when everything is complete (reads JSON, skips all)
- [ ] Completed steps show `[skip] <description>` messages
- [ ] Manual steps prompt user and record completion status
- [ ] Reversible step subtypes (brew, brew-cask, mac-defaults) can be undone
- [ ] State persists at `$KYLDVS_PREFIX/state.json`

## Constraints

- `jq` installed in bootstrap.sh alongside `just` (required for state management)
- Shell scripts only (no additional runtime dependencies)
- Must work with existing justfile structure
- Step kinds: `automated`, `manual`
- Step subtypes: `brew`, `brew-cask`, `mac-defaults`, `other`

## Out of Scope

- GUI or TUI interface
- Remote state sync
- Rollback to specific points in time (just individual step undo)
- Dependency ordering between steps (current sequential order is fine)
