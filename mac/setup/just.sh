#!/bin/bash

# TODO: Utils to check a command, install via brew, check command version, etc.

# Check if just is installed.
if ! command -v just &> /dev/null; then
  echo "Just not found. Installing Just via Homebrew..."
  brew install just
fi
