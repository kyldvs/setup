#!/bin/bash

# TODO: Utils to check a command, install via brew, check command version, etc.

# Check if brew is installed.
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
