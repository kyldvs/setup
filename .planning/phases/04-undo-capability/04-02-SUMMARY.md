---
phase: 04-undo-capability
plan: 02
status: complete
completed: 2025-11-24
---

# Phase 4 Plan 2 Summary: Undo Command Integration

## Objective

Integrate undo commands into justfile and state tracking to enable users to revert completed setup steps, connecting the undo functions (from 04-01) to the justfile interface for user-facing undo capability.

## What Was Implemented

### 1. Undo Status Tracking Functions (lib/state.sh)

Added five new state management functions to support undo operations:

#### state_mark_undone()
- Marks a step as "undone" in state.json
- Records undone_at timestamp
- Validates step exists before updating
- Uses atomic writes to prevent corruption

#### state_is_undoable()
- Boolean check if a step can be undone
- Returns true if status is "complete" AND subtype is reversible (brew, brew-cask, mac-defaults)
- Returns false for pending, undone, or non-reversible steps
- Used by undo command for validation

#### state_list_undoable()
- Returns tab-separated list of all undoable steps
- Format: step_id<TAB>description<TAB>subtype
- Filters for completed steps with reversible subtypes
- Returns empty string if no undoable steps exist

#### state_get_subtype()
- Retrieves the subtype field for a given step_id
- Used by undo command to determine which undo function to call
- Returns empty and exit code 1 if step doesn't exist

#### state_get_description()
- Retrieves the description field for a given step_id
- Used by undo command to show user-friendly step description
- Returns empty and exit code 1 if step doesn't exist

### 2. Undo Commands in Justfile (tasks/setup/justfile)

#### `just setup undo <step-id>`
- User-facing command to undo a completed step
- Validates step is undoable before proceeding
- Shows helpful error messages if step cannot be undone
- Displays step description and type before undoing
- Calls appropriate undo function based on subtype (brew, brew-cask, mac-defaults)
- Marks step as undone in state.json
- Provides clear success message and instructions for re-applying

Error handling includes:
- Step not found
- Step not completed
- Step not reversible (wrong subtype)
- Step already undone
- Guidance to run `just setup undo-list` to see available steps

#### `just setup undo-list`
- User-facing command to list all undoable steps
- Shows formatted table with columns: Step ID, Description, Type
- Displays "No steps available to undo" when list is empty
- Uses printf for aligned column formatting
- Shows only completed steps with reversible subtypes

### 3. Updated Step Execution (lib/state.sh - run_step function)

Enhanced the `run_step` wrapper to handle "undone" status:

**Previous behavior:**
- "complete" → skip with "[skip]" message
- "pending" → execute step

**New behavior:**
- "complete" → skip with "[skip]" message (unchanged)
- "undone" → skip with "[undone]" message and re-apply instructions
- "pending" → execute step (unchanged)

The undone message includes:
- Yellow color coding (if terminal supports it)
- Step description
- Instruction: "run 'just setup <step-id>' to re-apply"

### 4. Help Text

Help text is automatically provided through recipe comments:
- `# Undo a completed setup step by ID` for `undo` command
- `# List steps that can be undone` for `undo-list` command

These comments are displayed by the prelude/task/justfile help system.

## Files Created/Modified

### Modified
- `/Users/kad/kyldvs/setup/lib/state.sh` - Added 5 undo status tracking functions (231 lines added)
- `/Users/kad/kyldvs/setup/tasks/setup/justfile` - Added undo and undo-list recipes (129 lines added)

### Created
- `/Users/kad/kyldvs/setup/.planning/phases/04-undo-capability/04-02-SUMMARY.md` - This summary document

## Implementation Decisions

### 1. Status Model
Chose three-state model for steps:
- "pending" - not yet completed
- "complete" - successfully completed
- "undone" - was completed but then reversed

This preserves history and allows re-application without losing step metadata.

### 2. Undo Validation
Implemented strict validation in `state_is_undoable()`:
- Must be status "complete" (not pending or already undone)
- Must have reversible subtype (brew, brew-cask, or mac-defaults)
- This prevents users from undoing incomplete or non-reversible steps

### 3. Error Messages
Designed comprehensive error messages that:
- Explain why the operation failed
- Provide actionable guidance (e.g., "Run 'just setup undo-list'")
- List possible reasons for failure
- Guide users to correct usage

### 4. User Experience
- Clear visual feedback with color coding (when terminal supports it)
- Consistent message format across all operations
- Tab-separated internal format for easy parsing
- Formatted table output for user display
- Graceful handling of empty state

### 5. Re-application Flow
- Undone steps are automatically skipped in `just setup all`
- Users must explicitly run individual step commands to re-apply
- This prevents accidental re-application of intentionally undone steps
- Clear instructions provided on how to re-apply

## Example Workflow

### 1. List undoable steps
```bash
$ just setup undo-list
Step ID              Description                          Type
----------------------------------------------------------------------
brew-install         Install brew packages and casks      brew-cask
mac-dock             Configure macOS dock                 mac-defaults
mac-defaults         Set macOS system defaults            mac-defaults
```

### 2. Undo a step
```bash
$ just setup undo mac-dock
Undoing: Configure macOS dock
Type: mac-defaults

[INFO] Undoing macOS defaults: com.apple.dock orientation
[INFO] Deleting defaults key (no original value stored)
[INFO] Deleted com.apple.dock orientation
[INFO] Restarting affected services: Dock
[INFO] Successfully undid macOS defaults change and updated state

Step undone successfully
Run 'just setup <step>' to re-apply
```

### 3. Verify skip behavior
```bash
$ just setup all
[skip] Link dotfiles using stow
[skip] Install brew packages and casks
[undone] Configure macOS dock - run 'just setup mac-dock' to re-apply
[skip] Set macOS system defaults
```

### 4. Re-apply undone step
```bash
$ just setup mac-dock
# Executes dock configuration again
# Status changes from "undone" back to "complete"
```

## Deviations from Plan

### Minor Adjustments

1. **Undo function already calls _mark_step_undone**: The undo functions from 04-01 already call `_mark_step_undone()` internally, so the undo recipe also calls `state_mark_undone()`. This is intentional - the undo functions mark as "pending" while the wrapper marks as "undone" for proper state tracking.

2. **Removed checkmark emoji**: Plan showed "✓ Step undone successfully" but we used plain text to avoid emoji unless user explicitly requests it (per CLAUDE.md guidelines).

3. **Color scheme**: Used yellow (33m) for [undone] messages to distinguish from gray [skip] messages, making the status difference clear to users.

## Success Criteria Met

- [x] Users can undo completed brew, brew-cask, and mac-defaults steps
- [x] Users can see which steps are available to undo via `just setup undo-list`
- [x] State correctly tracks "undone" status with timestamp
- [x] Undone steps are skipped in `just setup all` with clear messaging
- [x] Individual step commands can re-apply undone steps
- [x] All error messages are helpful and guide users to correct usage
- [x] Help text documents the new commands (via recipe comments)
- [x] State functions (state_mark_undone, state_is_undoable, state_list_undoable) implemented
- [x] Helper functions (state_get_subtype, state_get_description) implemented
- [x] Undo command validates and calls appropriate undo function
- [x] Undo-list command shows formatted table of undoable steps

## Phase 4 Completion

With this plan complete, Phase 4 (Undo Capability) is now fully implemented:
- Plan 04-01: Undo functions for reversible operations (complete)
- Plan 04-02: Undo command integration in justfile (complete)

The system now provides complete undo capability for reversible setup operations, allowing users to:
- Experiment with different configurations safely
- Revert unwanted changes
- Re-apply steps after undoing
- Track undo history via state.json

## Next Phase Readiness

The setup state tracking system is now complete with all four phases implemented:
1. State Foundation - Complete
2. Step Integration - Complete
3. Manual Steps - Complete
4. Undo Capability - Complete

The system is production-ready and provides:
- Fast idempotent setup operations
- Manual step prompting with user confirmation
- Reversible operations with undo/redo capability
- Complete state tracking and history

No further phases are planned for the state tracking system.
