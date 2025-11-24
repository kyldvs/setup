# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Overview

This is a personal macOS/Linux setup automation repository. It bootstraps a new
machine by installing applications, configuring system settings, and linking
dotfiles.

## Commands

All commands use [Just](https://github.com/casey/just) as the task runner. The
main entry point is the `kyldvs` command (after bootstrap), which defers to
Just.

```bash
# Bootstrap a fresh machine (run from curl)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/kyldvs/setup/HEAD/bootstrap.sh)"

# After bootstrap, the kyldvs command is available
kyldvs help              # Show all available commands
kyldvs sync              # Pull latest changes from github
kyldvs setup all         # Run all setup tasks
kyldvs setup ...         # Other specific setup commands
```
