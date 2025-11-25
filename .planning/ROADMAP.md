# Roadmap: Setup State Tracking

## Overview

Add JSON-based state tracking to the setup system, progressing from core state management through step integration, manual step handling, and finally undo capability for reversible operations.

## Phases

- [x] **Phase 1: State Foundation** - JSON state file management with jq utilities and step data model - Completed 2025-11-24
- [x] **Phase 2: Step Integration** - Convert existing setup steps to use state tracking - Completed 2025-11-24
- [x] **Phase 3: Manual Steps** - User prompting for manual configuration steps - Completed 2025-11-24
- [x] **Phase 4: Undo Capability** - Reversible operations for brew, brew-cask, mac-defaults - Completed 2025-11-24

## Phase Details

### Phase 1: State Foundation
**Goal**: Core state management - create, read, update JSON state file with jq
**Depends on**: Nothing (first phase)
**Plans**: 2 plans

Plans:
- [x] 01-01: State file utilities (init, read, write with jq) - Completed 2025-11-24
- [x] 01-02: Step data model (id, description, kind, subtype, status) - Completed 2025-11-24

### Phase 2: Step Integration
**Goal**: Existing setup steps check state before running and record completion
**Depends on**: Phase 1
**Plans**: 2 plans

Plans:
- [x] 02-01: Step wrapper function (check-before-run, record-on-complete) - Completed 2025-11-24
- [x] 02-02: Convert existing justfile recipes to use wrapper - Completed 2025-11-24

### Phase 3: Manual Steps
**Goal**: Manual steps prompt user and record completion status
**Depends on**: Phase 2
**Plans**: 1 plan

Plans:
- [x] 03-01: Manual step prompting with user confirmation and state recording - Completed 2025-11-24

### Phase 4: Undo Capability
**Goal**: Reversible step subtypes can be undone (brew, brew-cask, mac-defaults)
**Depends on**: Phase 3
**Plans**: 2 plans

Plans:
- [x] 04-01: Undo functions for each reversible subtype - Completed 2025-11-24
- [x] 04-02: Undo command integration in justfile - Completed 2025-11-24

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. State Foundation | 2/2 | Complete | 2025-11-24 |
| 2. Step Integration | 2/2 | Complete | 2025-11-24 |
| 3. Manual Steps | 1/1 | Complete | 2025-11-24 |
| 4. Undo Capability | 2/2 | Complete | 2025-11-24 |
