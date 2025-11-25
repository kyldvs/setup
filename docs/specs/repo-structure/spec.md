---
beads-id: k-olq
status: draft
created: 2025-11-24
updated: 2025-11-24
---

# Repository Structure and Justfile Organization

## Context

This spec documents the architecture of the kyldvs/setup repository - a personal macOS/Linux setup automation system. Understanding the "why" behind these choices helps maintain consistency when extending the system.

## Repository Structure

```
/Users/kad/kyldvs/setup/
├── bootstrap.sh           # Curl-able entry point
├── kyldvs.sh              # Main command wrapper
├── justfile               # Root orchestrator
├── links/                 # Dotfiles (GNU Stow)
├── tasks/                 # Modular justfiles
│   ├── prelude/           # Shared settings
│   ├── bootstrap/         # Initial setup
│   ├── dev/               # Development tasks
│   └── setup/             # System configuration
├── docs/                  # Specs and history
└── cache/                 # Build artifacts (gitignored)
```

**Why this structure?**

- **links/** uses GNU Stow convention - each subdirectory mirrors home structure, enabling in-place editing while keeping changes in git
- **tasks/** separates concerns by functional area - bootstrap (one-time), setup (repeatable), dev (repo maintenance)
- **cache/** keeps large downloads out of git while remaining reproducible

## Justfile Architecture

```
justfile (root orchestrator)
├── imports: tasks/prelude/root/justfile
└── delegates to:
    ├── tasks/bootstrap/justfile
    ├── tasks/dev/justfile
    └── tasks/setup/justfile
        └── each imports: tasks/prelude/task/justfile
```

**Why this pattern?**

- **Root orchestrator** - single entry point routes to specialized task files, keeping each file focused and testable
- **Prelude imports** - shared shell settings (`bash -uc`, positional args) avoid repetition and ensure consistency
- **Two prelude types** - root prelude shows all commands, task prelude shows only its namespace (via `self` variable)
- **Explicit delegation** (`just -d pwd -f path`) - avoids working directory confusion, makes dependencies clear

## Design Decisions

**Why Just over Make?**
- Modern syntax with clear error messages
- Built-in `--list` for discoverability
- Native argument passing without workarounds
- No implicit rules or magic behavior

**Why GNU Stow for dotfiles?**
- Symlinks mean edits happen in the repo (changes tracked in git)
- Handles nested directory structures automatically
- Standard tool with predictable behavior
- Easy to add/remove application configs

**Why /usr/local/kyldvs?**
- Unix convention for local installations
- User-writable after initial bootstrap (no ongoing sudo)
- Isolated from system packages and Homebrew
- Consistent location across all machines

**Why separate bootstrap vs setup?**
- Bootstrap runs once on fresh machine (curl-able, minimal deps)
- Setup is idempotent (safe to re-run anytime)
- Clear mental model: "bootstrap gets you started, setup keeps you current"

## Related Issues

- k-ngh - Spec-driven development system
- k-63a - Automate macOS system settings (spike)
- k-3wa - Automate postgres setup
- k-dmo - Automate zsh-syntax-highlighting setup
- k-88l - Automate zsh-autosuggestions setup
- k-mcr - Figure out NVM automation (spike)

## References

- [Just Documentation](https://github.com/casey/just)
- [GNU Stow Documentation](https://www.gnu.org/software/stow/)
- [macOS Defaults Reference](https://macos-defaults.com/)
