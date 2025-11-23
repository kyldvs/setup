#!/bin/bash

# Bash strict mode
set -euo pipefail

# Required variables.
KYLDVS_PREFIX="/usr/local/kyldvs"
KYLDVS_REPOSITORY="${KYLDVS_PREFIX}/setup"
KYLDVS_BIN="${KYLDVS_PREFIX}/bin"

# TODO: Move these to the justfile.

# Handle the shellenv command to output PATH setup
if [[ "${1:-}" == "shellenv" ]]; then
  cat <<EOS
export PATH="${KYLDVS_BIN}:\${PATH}"
export KYLDVS_PREFIX="${KYLDVS_PREFIX}"
export KYLDVS_REPOSITORY="${KYLDVS_REPOSITORY}"
EOS
  exit 0
fi

# Handle the shellenv command to output PATH setup
if [[ "${1:-}" == "sync" ]]; then
  # Pull the latest changes from the repository.
  echo "Syncing Kyldvs repository..."
  git -C "${KYLDVS_REPOSITORY}" pull origin main
  exit 0
fi

# Default behavior for other commands or no arguments
echo "Thanks for installing Kyldvs!"
echo
echo "Available commands:"
echo "  kyldvs shellenv  - Output shell environment setup"
echo "  kyldvs sync      - Sync the Kyldvs repository with the latest changes"
echo
