# Plan 02-02 Summary: Convert Existing Recipes to Use run_step

**Plan**: `.planning/phases/02-step-integration/02-02-PLAN.md`
**Status**: Complete
**Date**: 2025-11-24

## Objective

Convert 8 existing setup recipes to use the `run_step` wrapper with automated state tracking, enabling fast re-runs and skip messages for completed steps.

## Tasks Completed

### Task 1: Convert brew, home, and brew-services recipes
- **brew recipe**: Wrapped with `run_step "brew-install" ... "brew-cask"`
  - Uses brew-cask subtype because it includes both casks and regular brew packages
- **home recipe**: Wrapped with `run_step "home-dotfiles" ... "other"`
  - Uses other subtype for dotfile symlinking (doesn't fit brew/mac-defaults)
- **brew-services recipe**: Wrapped with `run_step "brew-services" ... "brew"`
  - Uses brew subtype for brew services commands

### Task 2: Convert docker, mac-dock, and mac-defaults recipes
- **docker recipe**: Wrapped with `run_step "docker-desktop" ... "brew-cask"`
  - Uses brew-cask subtype (installs .dmg application like brew cask)
- **mac-dock recipe**: Wrapped with `run_step "mac-dock" ... "mac-defaults"`
  - Uses mac-defaults subtype (dockutil modifies dock preferences)
- **mac-defaults recipe**: Wrapped with `run_step "mac-defaults" ... "mac-defaults"`
  - Uses mac-defaults subtype (defaults write commands)

### Task 3: Convert nvm and rust recipes
- **nvm recipe**: Wrapped with `run_step "nvm" ... "other"`
  - Uses other subtype (custom curl installer)
- **rust recipe**: Wrapped with `run_step "rust" ... "other"`
  - Uses other subtype (rustup curl installer)
  - Updated from previous "setup-rust-rustup" to "rust" for consistency

### Task 4: Verification (Skipped per instructions)
- Skipped all verification steps as instructed

## Files Modified

- `/Users/kad/kyldvs/setup/tasks/setup/justfile` - All 8 recipes converted to use run_step wrapper

## Recipes Converted

| Recipe | Step ID | Description | Kind | Subtype |
|--------|---------|-------------|------|---------|
| brew | brew-install | Install brew packages and casks | automated | brew-cask |
| home | home-dotfiles | Link dotfiles using stow | automated | other |
| brew-services | brew-services | Start brew services | automated | brew |
| docker | docker-desktop | Install Docker Desktop | automated | brew-cask |
| mac-dock | mac-dock | Configure macOS dock | automated | mac-defaults |
| mac-defaults | mac-defaults | Set macOS system defaults | automated | mac-defaults |
| nvm | nvm | Install Node Version Manager | automated | other |
| rust | rust | Install Rust via rustup | automated | other |

## Arc Recipe

The `arc` recipe was intentionally left unchanged as it contains manual steps that will be handled in Phase 3 (Manual Steps).

## Implementation Decisions

1. **Subtype Classifications**:
   - `brew-cask`: Used for both brew recipe (mixed casks/packages) and docker (dmg install)
   - `mac-defaults`: Used for dock configuration and system defaults
   - `brew`: Used specifically for brew services commands
   - `other`: Used for custom curl installers (nvm, rust) and dotfile symlinking

2. **Quote Escaping**: Multi-line commands passed to `run_step` use single quotes to avoid shell expansion issues. Internal single quotes are escaped using `'"'"'` pattern where needed.

3. **Function Definitions**: Functions like `try_remove_dock_item` and `ensure_defaults` are defined within the command string passed to `run_step`, maintaining the same logic as before.

4. **REPO_ROOT Discovery**: Each recipe includes the standard boilerplate for:
   - Setting KYLDVS_PREFIX based on OS
   - Finding repository root by looking for lib/state.sh
   - Sourcing the state library

## State Tracking Benefits

With these changes:
- Completed steps will show `[skip] <description>` on re-run
- State persists in `$KYLDVS_PREFIX/state.json`
- `just setup all` becomes a fast no-op when everything is complete
- Each step records completion timestamp in ISO8601 format

## Next Steps

Ready for Phase 3: Manual step handling for the arc recipe with user prompting and completion confirmation.
