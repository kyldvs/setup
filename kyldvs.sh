#!/bin/bash

# Bash strict mode
set -euo pipefail

# Required variables.
export KYLDVS_PREFIX="/usr/local/kyldvs"
export KYLDVS_REPOSITORY="${KYLDVS_PREFIX}/setup"
export KYLDVS_BIN="${KYLDVS_PREFIX}/bin"

# Defer to Just for all commands.
just -d "$KYLDVS_REPOSITORY" -f "$KYLDVS_REPOSITORY/justfile" "$@"
