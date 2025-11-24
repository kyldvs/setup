# Read up on just here: https://github.com/casey/just

# --- Setup ---

import "tasks/prelude/root/justfile"
_default: help

# --- Alias ---

# Generates environment variables for the 'kyldvs' command.
[group("alias")]
[no-exit-message]
@shellenv *args:
  just bootstrap shellenv "$@"

# Pulls the latest changes to 'kyldvs' from github.
[group("alias")]
[no-exit-message]
@sync *args:
  just bootstrap sync "$@"

# --- Tasks ---

# Tasks referenced in the bootstrap script, generally for setup.
[group("tasks")]
[no-exit-message]
@bootstrap *args:
  just -d `pwd` -f "tasks/bootstrap/justfile" -- "$@"

# Tasks for developing the kyldvs repo itself.
[group("tasks")]
[no-exit-message]
@dev *args:
  just -d `pwd` -f "tasks/dev/justfile" -- "$@"

# Install different tools and packages.
[group("tasks")]
[no-exit-message]
@install *args:
  just -d `pwd` -f "tasks/install/justfile" -- "$@"
