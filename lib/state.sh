#!/usr/bin/env bash

# state.sh - JSON state file management utilities using jq
#
# This library provides functions for managing persistent JSON state at
# $KYLDVS_PREFIX/state.json. State is used to track setup step completion
# and enable fast re-runs and undo capabilities.
#
# Required environment variable:
#   KYLDVS_PREFIX - Base directory where state.json will be stored
#
# State file structure:
#   {
#     "version": "1.0.0",
#     "steps": {
#       "step_id": {
#         "status": "completed",
#         "timestamp": "2025-11-24T12:00:00Z",
#         ...
#       }
#     }
#   }

set -euo pipefail

# Get the path to the state file
_state_file_path() {
  if [[ -z "${KYLDVS_STATE:-}" ]]; then
    echo "Error: KYLDVS_STATE environment variable is not set" >&2
    return 1
  fi
  echo "${KYLDVS_STATE}"
}

# state_init - Initialize empty state file if it doesn't exist
#
# Creates a new state file with the initial JSON structure:
# {"version": "1.0.0", "steps": {}}
#
# Returns:
#   0 on success (file created or already exists)
#   1 on failure
#
# Example:
#   state_init
state_init() {
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Create directory if it doesn't exist
  local state_dir
  state_dir="$(dirname "${state_file}")"
  if [[ ! -d "${state_dir}" ]]; then
    if ! mkdir -p "${state_dir}" 2>/dev/null; then
      echo "Error: Failed to create state directory: ${state_dir}" >&2
      return 1
    fi
  fi

  # Create state file if it doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    local init_json='{"version":"1.0.0","steps":{}}'
    if ! echo "${init_json}" | jq '.' > "${state_file}" 2>/dev/null; then
      echo "Error: Failed to create state file: ${state_file}" >&2
      return 1
    fi
  fi

  return 0
}

# state_read - Read and output the entire state file
#
# Reads the state file and outputs it as formatted JSON to stdout.
# If the state file doesn't exist, initializes it first.
#
# Returns:
#   0 on success (state output to stdout)
#   1 on failure
#
# Example:
#   state_read
state_read() {
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Read and format with jq
  if ! jq '.' "${state_file}" 2>/dev/null; then
    echo "Error: Failed to read state file or invalid JSON: ${state_file}" >&2
    return 1
  fi

  return 0
}

# state_write - Write entire JSON state to file
#
# Accepts a JSON string and writes it to the state file atomically
# using a temporary file and mv to prevent corruption.
#
# Args:
#   $1 - JSON string to write
#
# Returns:
#   0 on success
#   1 on failure (invalid JSON or write error)
#
# Example:
#   state_write '{"version":"1.0.0","steps":{}}'
state_write() {
  if [[ $# -ne 1 ]]; then
    echo "Error: state_write requires exactly 1 argument (JSON string)" >&2
    return 1
  fi

  local json="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Validate JSON before writing
  if ! echo "${json}" | jq '.' > /dev/null 2>&1; then
    echo "Error: Invalid JSON provided to state_write" >&2
    return 1
  fi

  # Create directory if it doesn't exist
  local state_dir
  state_dir="$(dirname "${state_file}")"
  if [[ ! -d "${state_dir}" ]]; then
    if ! mkdir -p "${state_dir}" 2>/dev/null; then
      echo "Error: Failed to create state directory: ${state_dir}" >&2
      return 1
    fi
  fi

  # Write atomically using temp file
  local temp_file="${state_file}.tmp.$$"
  if ! echo "${json}" | jq '.' > "${temp_file}" 2>/dev/null; then
    echo "Error: Failed to write to temporary state file" >&2
    rm -f "${temp_file}"
    return 1
  fi

  if ! mv "${temp_file}" "${state_file}" 2>/dev/null; then
    echo "Error: Failed to move temporary file to state file" >&2
    rm -f "${temp_file}"
    return 1
  fi

  return 0
}

# state_get - Get value for a specific key using jq path syntax
#
# Queries the state file using jq path syntax and returns the value
# to stdout. Returns empty string if key doesn't exist.
#
# Args:
#   $1 - jq path (e.g., ".steps.brew_install.status")
#
# Returns:
#   0 on success (value output to stdout, may be empty)
#   1 on failure
#
# Example:
#   status=$(state_get ".steps.brew_install.status")
state_get() {
  if [[ $# -ne 1 ]]; then
    echo "Error: state_get requires exactly 1 argument (jq path)" >&2
    return 1
  fi

  local key="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Query with jq, output raw string, return empty string if null
  local result
  if ! result=$(jq -r "${key} // empty" "${state_file}" 2>/dev/null); then
    echo "Error: Failed to query state file with key: ${key}" >&2
    return 1
  fi

  echo "${result}"
  return 0
}

# state_set - Set value for a specific key using jq
#
# Updates a specific key in the state file with the provided value.
# Reads current state, updates with jq, writes back atomically.
# Supports both string and JSON values.
#
# Args:
#   $1 - jq path (e.g., ".steps.brew_install.status")
#   $2 - value to set (string or JSON)
#
# Returns:
#   0 on success
#   1 on failure
#
# Example:
#   state_set ".steps.brew_install.status" "completed"
#   state_set ".steps.brew_install" '{"status":"completed","timestamp":"2025-11-24"}'
state_set() {
  if [[ $# -ne 2 ]]; then
    echo "Error: state_set requires exactly 2 arguments (jq path, value)" >&2
    return 1
  fi

  local key="$1"
  local value="$2"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Read current state
  local current_state
  if ! current_state=$(cat "${state_file}"); then
    echo "Error: Failed to read current state" >&2
    return 1
  fi

  # Try to parse value as JSON first, otherwise treat as string
  local new_state
  if echo "${value}" | jq '.' > /dev/null 2>&1; then
    # Value is valid JSON, use it directly
    if ! new_state=$(echo "${current_state}" | jq "${key} = ${value}" 2>/dev/null); then
      echo "Error: Failed to update state with jq" >&2
      return 1
    fi
  else
    # Value is a string, pass it as a jq arg
    if ! new_state=$(echo "${current_state}" | jq --arg val "${value}" "${key} = \$val" 2>/dev/null); then
      echo "Error: Failed to update state with jq" >&2
      return 1
    fi
  fi

  # Write back atomically
  state_write "${new_state}"
}

# step_register - Register a new step in the state file
#
# Creates or updates a step entry in state.json under the "steps" object.
# Initializes the step with status="pending" and empty timestamp.
#
# Args:
#   $1 - step_id (unique identifier)
#   $2 - description (human-readable description)
#   $3 - kind (automated|manual)
#   $4 - subtype (brew|brew-cask|mac-defaults|other)
#
# Returns:
#   0 on success
#   1 on validation failure or write error
#
# Example:
#   step_register "install-git" "Install git via Homebrew" "automated" "brew"
step_register() {
  if [[ $# -ne 4 ]]; then
    echo "Error: step_register requires exactly 4 arguments (step_id, description, kind, subtype)" >&2
    return 1
  fi

  local step_id="$1"
  local description="$2"
  local kind="$3"
  local subtype="$4"

  # Validate kind
  if [[ "${kind}" != "automated" && "${kind}" != "manual" ]]; then
    echo "Error: kind must be 'automated' or 'manual', got: ${kind}" >&2
    return 1
  fi

  # Validate subtype
  if [[ "${subtype}" != "brew" && "${subtype}" != "brew-cask" && "${subtype}" != "mac-defaults" && "${subtype}" != "other" ]]; then
    echo "Error: subtype must be 'brew', 'brew-cask', 'mac-defaults', or 'other', got: ${subtype}" >&2
    return 1
  fi

  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Read current state
  local current_state
  if ! current_state=$(cat "${state_file}"); then
    echo "Error: Failed to read current state" >&2
    return 1
  fi

  # Create step object and merge into .steps[step_id]
  local step_json
  step_json=$(jq -n \
    --arg id "${step_id}" \
    --arg desc "${description}" \
    --arg k "${kind}" \
    --arg st "${subtype}" \
    '{
      id: $id,
      description: $desc,
      kind: $k,
      subtype: $st,
      status: "pending",
      timestamp: ""
    }')

  # Update state with new step
  local new_state
  if ! new_state=$(echo "${current_state}" | jq --argjson step "${step_json}" ".steps[\"${step_id}\"] = \$step" 2>/dev/null); then
    echo "Error: Failed to register step with jq" >&2
    return 1
  fi

  # Write back atomically
  state_write "${new_state}"
}

# step_get_status - Get the status of a step
#
# Retrieves the status field for a given step_id from state.json.
# Returns "pending" or "complete" to stdout.
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 on success (status output to stdout)
#   1 if step doesn't exist (empty output)
#
# Example:
#   status=$(step_get_status "install-git")
step_get_status() {
  if [[ $# -ne 1 ]]; then
    echo "Error: step_get_status requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Query step status
  local status
  if ! status=$(jq -r ".steps[\"${step_id}\"].status // empty" "${state_file}" 2>/dev/null); then
    echo "Error: Failed to query step status" >&2
    return 1
  fi

  # Return empty string and exit code 1 if step doesn't exist
  if [[ -z "${status}" ]]; then
    return 1
  fi

  echo "${status}"
  return 0
}

# step_is_complete - Check if a step is complete (boolean)
#
# Returns boolean exit code based on step completion status.
# Use in if statements: if step_is_complete "my-step"; then skip; fi
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 (true) if step status is "complete"
#   1 (false) otherwise (including missing step)
#
# Example:
#   if step_is_complete "install-git"; then
#     echo "Git already installed"
#   fi
step_is_complete() {
  if [[ $# -ne 1 ]]; then
    echo "Error: step_is_complete requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local status

  # Get status, suppress error output for cleaner boolean usage
  status=$(step_get_status "${step_id}" 2>/dev/null) || return 1

  # Return 0 (true) if complete, 1 (false) otherwise
  if [[ "${status}" == "complete" ]]; then
    return 0
  else
    return 1
  fi
}

# step_mark_complete - Mark a step as complete with timestamp
#
# Updates a step's status to "complete" and records the current timestamp
# in ISO8601 UTC format.
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 on success
#   1 if step doesn't exist or write fails
#
# Example:
#   step_mark_complete "install-git"
step_mark_complete() {
  if [[ $# -ne 1 ]]; then
    echo "Error: step_mark_complete requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Check if step exists
  local step_exists
  step_exists=$(jq -r ".steps[\"${step_id}\"] // empty" "${state_file}" 2>/dev/null)
  if [[ -z "${step_exists}" ]]; then
    echo "Error: Step does not exist: ${step_id}" >&2
    return 1
  fi

  # Get current timestamp in ISO8601 UTC format
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read current state
  local current_state
  if ! current_state=$(cat "${state_file}"); then
    echo "Error: Failed to read current state" >&2
    return 1
  fi

  # Update step status and timestamp
  local new_state
  if ! new_state=$(echo "${current_state}" | jq \
    --arg ts "${timestamp}" \
    ".steps[\"${step_id}\"].status = \"complete\" | .steps[\"${step_id}\"].timestamp = \$ts" \
    2>/dev/null); then
    echo "Error: Failed to mark step complete with jq" >&2
    return 1
  fi

  # Write back atomically
  state_write "${new_state}"
}

# run_step - Wrapper function that checks state before running steps and records completion
#
# This is the bridge between the state management system and justfile recipes.
# It checks if a step is already complete (fast no-op), executes the command if needed,
# and records completion on success.
#
# Args:
#   $1 - step_id (unique identifier)
#   $2 - description (human-readable description)
#   $3 - kind (automated|manual)
#   $4 - subtype (brew|brew-cask|mac-defaults|other)
#   $5 - command (shell command to execute)
#
# Returns:
#   0 if step was skipped (already complete) or command succeeded
#   Non-zero if command failed
#
# Example:
#   run_step "install-git" "Install git via Homebrew" "automated" "brew" "brew install git"
run_step() {
  if [[ $# -ne 5 ]]; then
    echo "Error: run_step requires exactly 5 arguments (step_id, description, kind, subtype, command)" >&2
    return 1
  fi

  local step_id="$1"
  local description="$2"
  local kind="$3"
  local subtype="$4"
  local command="$5"

  # Set KYLDVS_PREFIX with fallback to $HOME/.kyldvs if not set
  if [[ -z "${KYLDVS_PREFIX:-}" ]]; then
    export KYLDVS_PREFIX="${HOME}/.kyldvs"
  fi

  local state_file="${KYLDVS_PREFIX}/state.json"

  # Initialize state file if it doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Check if step is already complete
  local status
  status=$(jq -r ".steps[\"${step_id}\"].status // empty" "${state_file}" 2>/dev/null)

  if [[ "${status}" == "complete" ]]; then
    # Step already complete - print skip message with color if terminal
    if [[ -t 1 ]]; then
      echo -e "\033[90m[skip] ${description}\033[0m"
    else
      echo "[skip] ${description}"
    fi
    return 0
  fi

  if [[ "${status}" == "undone" ]]; then
    # Step was undone - print undone message with color if terminal
    if [[ -t 1 ]]; then
      echo -e "\033[33m[undone]\033[0m ${description} - run 'just setup ${step_id}' to re-apply"
    else
      echo "[undone] ${description} - run 'just setup ${step_id}' to re-apply"
    fi
    return 0
  fi

  # Step not complete - register it first if it doesn't exist
  local step_exists
  step_exists=$(jq -r ".steps[\"${step_id}\"] // empty" "${state_file}" 2>/dev/null)
  if [[ -z "${step_exists}" ]]; then
    step_register "${step_id}" "${description}" "${kind}" "${subtype}" || return 1
  fi

  # Run the command and capture exit code
  local exit_code=0
  eval "${command}" || exit_code=$?

  # If command succeeded, mark step as complete
  if [[ ${exit_code} -eq 0 ]]; then
    # Get current timestamp in ISO8601 UTC format
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read current state
    local current_state
    if ! current_state=$(cat "${state_file}"); then
      echo "Error: Failed to read current state" >&2
      return 1
    fi

    # Update step with all required fields
    local new_state
    if ! new_state=$(echo "${current_state}" | jq \
      --arg id "${step_id}" \
      --arg desc "${description}" \
      --arg k "${kind}" \
      --arg st "${subtype}" \
      --arg ts "${timestamp}" \
      ".steps[\"${step_id}\"] = {
        id: \$id,
        description: \$desc,
        kind: \$k,
        subtype: \$st,
        status: \"complete\",
        completed_at: \$ts
      }" 2>/dev/null); then
      echo "Error: Failed to record step completion with jq" >&2
      return 1
    fi

    # Write back atomically
    if ! state_write "${new_state}"; then
      echo "Error: Failed to write state after step completion" >&2
      return 1
    fi
  fi

  # Return the command's exit code
  return ${exit_code}
}

# --- Undo Functions ---

# Logging functions for undo operations
log_undo_info() {
  local message="$1"
  if [[ -t 1 ]]; then
    echo -e "\033[34m[INFO]\033[0m ${message}"
  else
    echo "[INFO] ${message}"
  fi
}

log_undo_warn() {
  local message="$1"
  if [[ -t 1 ]]; then
    echo -e "\033[33m[WARN]\033[0m ${message}" >&2
  else
    echo "[WARN] ${message}" >&2
  fi
}

log_undo_error() {
  local message="$1"
  if [[ -t 1 ]]; then
    echo -e "\033[31m[ERROR]\033[0m ${message}" >&2
  else
    echo "[ERROR] ${message}" >&2
  fi
}

# Check if jq is available
_check_jq() {
  if ! command -v jq &> /dev/null; then
    log_undo_error "jq is required for state operations but not found in PATH"
    return 1
  fi
  return 0
}

# Check if state file exists and is readable
_check_state_file() {
  local state_file
  state_file="$(_state_file_path)" || return 1

  if [[ ! -f "${state_file}" ]]; then
    log_undo_error "State file does not exist: ${state_file}"
    return 1
  fi

  if [[ ! -r "${state_file}" ]]; then
    log_undo_error "State file is not readable: ${state_file}"
    return 1
  fi

  return 0
}

# Validate that a step exists and is completed
_validate_step_for_undo() {
  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Check if step exists
  local step_exists
  step_exists=$(jq -r ".steps[\"${step_id}\"] // empty" "${state_file}" 2>/dev/null)
  if [[ -z "${step_exists}" ]]; then
    log_undo_error "Step not found in state: ${step_id}"
    return 1
  fi

  # Check if step is completed
  local status
  status=$(jq -r ".steps[\"${step_id}\"].status // empty" "${state_file}" 2>/dev/null)
  if [[ "${status}" != "complete" ]]; then
    log_undo_error "Step was not completed, cannot undo: ${step_id} (status: ${status})"
    return 1
  fi

  return 0
}

# Mark a step as undone
_mark_step_undone() {
  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Get current timestamp in ISO8601 UTC format
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read current state
  local current_state
  if ! current_state=$(cat "${state_file}"); then
    log_undo_error "Failed to read current state"
    return 1
  fi

  # Update step status to pending and record undo timestamp
  local new_state
  if ! new_state=$(echo "${current_state}" | jq \
    --arg ts "${timestamp}" \
    ".steps[\"${step_id}\"].status = \"pending\" | .steps[\"${step_id}\"].undone_at = \$ts" \
    2>/dev/null); then
    log_undo_error "Failed to update step status with jq"
    return 1
  fi

  # Write back atomically
  if ! state_write "${new_state}"; then
    log_undo_error "Failed to write state after undo"
    return 1
  fi

  return 0
}

# undo_brew - Undo a brew package installation
#
# Uninstalls a brew package that was previously installed and tracked in state.
# Validates that the step exists and was completed before attempting uninstall.
#
# Args:
#   $1 - step_id (the ID used when the step was registered)
#
# Returns:
#   0 on success (package uninstalled and state updated)
#   1 on failure
#
# Example:
#   undo_brew "brew-install-cowsay"
undo_brew() {
  if [[ $# -ne 1 ]]; then
    log_undo_error "undo_brew requires exactly 1 argument (step_id)"
    return 1
  fi

  local step_id="$1"

  # Check dependencies
  _check_jq || return 1
  _check_state_file || return 1

  # Validate step can be undone
  _validate_step_for_undo "${step_id}" || return 1

  local state_file
  state_file="$(_state_file_path)" || return 1

  # Get step details
  local step_data
  step_data=$(jq -r ".steps[\"${step_id}\"]" "${state_file}" 2>/dev/null)

  local subtype
  subtype=$(echo "${step_data}" | jq -r ".subtype // empty")

  # Verify this is a brew step
  if [[ "${subtype}" != "brew" ]]; then
    log_undo_error "Step is not a brew step (subtype: ${subtype})"
    return 1
  fi

  # Extract package name from step_id (e.g., "brew-install-cowsay" -> "cowsay")
  # Try to get from params first, otherwise parse from step_id
  local package
  package=$(echo "${step_data}" | jq -r ".params.package // empty")

  if [[ -z "${package}" ]]; then
    # Try to extract from step_id
    if [[ "${step_id}" =~ brew-install-(.+)$ ]]; then
      package="${BASH_REMATCH[1]}"
    elif [[ "${step_id}" =~ brew-(.+)$ ]]; then
      package="${BASH_REMATCH[1]}"
    else
      log_undo_error "Could not determine package name from step: ${step_id}"
      return 1
    fi
  fi

  log_undo_info "Uninstalling brew package: ${package}"

  # Check if package is actually installed
  if ! brew list "${package}" &> /dev/null; then
    log_undo_warn "Package '${package}' is not installed (already removed?)"
    # Still mark as undone since it's not present
    _mark_step_undone "${step_id}" || return 1
    log_undo_info "Step marked as undone: ${step_id}"
    return 0
  fi

  # Uninstall the package
  if ! brew uninstall "${package}" 2>&1; then
    log_undo_error "Failed to uninstall package: ${package}"
    return 1
  fi

  # Mark step as undone
  _mark_step_undone "${step_id}" || return 1

  log_undo_info "Successfully uninstalled ${package} and updated state"
  return 0
}

# undo_brew_cask - Undo a brew cask installation
#
# Uninstalls a brew cask application that was previously installed and tracked in state.
# Validates that the step exists and was completed before attempting uninstall.
#
# Args:
#   $1 - step_id (the ID used when the step was registered)
#
# Returns:
#   0 on success (cask uninstalled and state updated)
#   1 on failure
#
# Example:
#   undo_brew_cask "brew-cask-wezterm"
undo_brew_cask() {
  if [[ $# -ne 1 ]]; then
    log_undo_error "undo_brew_cask requires exactly 1 argument (step_id)"
    return 1
  fi

  local step_id="$1"

  # Check dependencies
  _check_jq || return 1
  _check_state_file || return 1

  # Validate step can be undone
  _validate_step_for_undo "${step_id}" || return 1

  local state_file
  state_file="$(_state_file_path)" || return 1

  # Get step details
  local step_data
  step_data=$(jq -r ".steps[\"${step_id}\"]" "${state_file}" 2>/dev/null)

  local subtype
  subtype=$(echo "${step_data}" | jq -r ".subtype // empty")

  # Verify this is a brew-cask step
  if [[ "${subtype}" != "brew-cask" ]]; then
    log_undo_error "Step is not a brew-cask step (subtype: ${subtype})"
    return 1
  fi

  # Extract cask name from step_id or params
  local cask
  cask=$(echo "${step_data}" | jq -r ".params.cask // empty")

  if [[ -z "${cask}" ]]; then
    # Try to extract from step_id
    if [[ "${step_id}" =~ brew-cask-(.+)$ ]]; then
      cask="${BASH_REMATCH[1]}"
    else
      log_undo_error "Could not determine cask name from step: ${step_id}"
      return 1
    fi
  fi

  log_undo_info "Uninstalling brew cask: ${cask}"

  # Check if cask is actually installed
  if ! brew list --cask "${cask}" &> /dev/null; then
    log_undo_warn "Cask '${cask}' is not installed (already removed?)"
    # Still mark as undone since it's not present
    _mark_step_undone "${step_id}" || return 1
    log_undo_info "Step marked as undone: ${step_id}"
    return 0
  fi

  # Uninstall the cask
  if ! brew uninstall --cask "${cask}" 2>&1; then
    log_undo_error "Failed to uninstall cask: ${cask}"
    log_undo_warn "Some casks may leave files that require manual cleanup"
    return 1
  fi

  # Mark step as undone
  _mark_step_undone "${step_id}" || return 1

  log_undo_info "Successfully uninstalled ${cask} and updated state"
  log_undo_warn "Note: Some cask files may remain in ~/Applications or ~/Library"
  return 0
}

# undo_mac_defaults - Undo a macOS defaults change
#
# Restores or deletes a macOS defaults setting that was previously changed.
# If an original value was stored, restores it; otherwise deletes the key.
# Restarts affected system services (Dock, Finder, SystemUIServer) as needed.
#
# Args:
#   $1 - step_id (the ID used when the step was registered)
#
# Returns:
#   0 on success (setting restored/deleted and state updated)
#   1 on failure
#
# Example:
#   undo_mac_defaults "mac-defaults-dock-orientation"
undo_mac_defaults() {
  if [[ $# -ne 1 ]]; then
    log_undo_error "undo_mac_defaults requires exactly 1 argument (step_id)"
    return 1
  fi

  local step_id="$1"

  # Check dependencies
  _check_jq || return 1
  _check_state_file || return 1

  # Validate step can be undone
  _validate_step_for_undo "${step_id}" || return 1

  local state_file
  state_file="$(_state_file_path)" || return 1

  # Get step details
  local step_data
  step_data=$(jq -r ".steps[\"${step_id}\"]" "${state_file}" 2>/dev/null)

  local subtype
  subtype=$(echo "${step_data}" | jq -r ".subtype // empty")

  # Verify this is a mac-defaults step
  if [[ "${subtype}" != "mac-defaults" ]]; then
    log_undo_error "Step is not a mac-defaults step (subtype: ${subtype})"
    return 1
  fi

  # Extract defaults parameters
  local domain key type value original_value
  domain=$(echo "${step_data}" | jq -r ".params.domain // empty")
  key=$(echo "${step_data}" | jq -r ".params.key // empty")
  type=$(echo "${step_data}" | jq -r ".params.type // empty")
  value=$(echo "${step_data}" | jq -r ".params.value // empty")
  original_value=$(echo "${step_data}" | jq -r ".params.original_value // empty")

  if [[ -z "${domain}" ]] || [[ -z "${key}" ]]; then
    log_undo_error "Missing domain or key in step params: ${step_id}"
    return 1
  fi

  log_undo_info "Undoing macOS defaults: ${domain} ${key}"

  # Determine whether to restore original value or delete
  if [[ -n "${original_value}" ]] && [[ "${original_value}" != "null" ]]; then
    # Restore original value
    log_undo_info "Restoring original value: ${original_value}"

    # Determine type if not stored
    if [[ -z "${type}" ]] || [[ "${type}" == "null" ]]; then
      # Try to infer type
      if [[ "${original_value}" == "true" ]] || [[ "${original_value}" == "false" ]]; then
        type="-bool"
      elif [[ "${original_value}" =~ ^-?[0-9]+$ ]]; then
        type="-int"
      elif [[ "${original_value}" =~ ^-?[0-9]+\.[0-9]+$ ]]; then
        type="-float"
      else
        type="-string"
      fi
    fi

    if ! defaults write "${domain}" "${key}" ${type} "${original_value}" 2>&1; then
      log_undo_error "Failed to restore defaults: ${domain} ${key}"
      return 1
    fi

    log_undo_info "Restored ${domain} ${key} to: ${original_value}"
  else
    # Delete the key
    log_undo_info "Deleting defaults key (no original value stored)"

    # Check if key exists
    if defaults read "${domain}" "${key}" &> /dev/null; then
      if ! defaults delete "${domain}" "${key}" 2>&1; then
        log_undo_error "Failed to delete defaults: ${domain} ${key}"
        return 1
      fi
      log_undo_info "Deleted ${domain} ${key}"
    else
      log_undo_warn "Key '${key}' not found in domain '${domain}' (already removed?)"
    fi
  fi

  # Determine which services need restart based on domain
  local needs_restart=false
  local restart_services=()

  if [[ "${domain}" == *"dock"* ]]; then
    restart_services+=("Dock")
    needs_restart=true
  fi

  if [[ "${domain}" == *"finder"* ]] || [[ "${domain}" == "NSGlobalDomain" ]]; then
    restart_services+=("Finder")
    needs_restart=true
  fi

  if [[ "${domain}" == *"screencapture"* ]] || [[ "${domain}" == "NSGlobalDomain" ]]; then
    restart_services+=("SystemUIServer")
    needs_restart=true
  fi

  # Restart affected services
  if [[ "${needs_restart}" == "true" ]]; then
    log_undo_info "Restarting affected services: ${restart_services[*]}"
    for service in "${restart_services[@]}"; do
      if ! killall "${service}" 2>&1; then
        log_undo_warn "Failed to restart ${service} (may not be running)"
      fi
    done
  fi

  # Mark step as undone
  _mark_step_undone "${step_id}" || return 1

  log_undo_info "Successfully undid macOS defaults change and updated state"
  return 0
}

# --- Undo Status Tracking Functions ---

# state_mark_undone - Mark a step as undone in state.json
#
# Updates a step's status to "undone" and records the current timestamp.
# This status indicates the step was completed but then reversed.
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 on success
#   1 if step doesn't exist or write fails
#
# Example:
#   state_mark_undone "brew-install-git"
state_mark_undone() {
  if [[ $# -ne 1 ]]; then
    echo "Error: state_mark_undone requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    state_init || return 1
  fi

  # Check if step exists
  local step_exists
  step_exists=$(jq -r ".steps[\"${step_id}\"] // empty" "${state_file}" 2>/dev/null)
  if [[ -z "${step_exists}" ]]; then
    echo "Error: Step does not exist: ${step_id}" >&2
    return 1
  fi

  # Get current timestamp in ISO8601 UTC format
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read current state
  local current_state
  if ! current_state=$(cat "${state_file}"); then
    echo "Error: Failed to read current state" >&2
    return 1
  fi

  # Update step status to undone and add undone_at timestamp
  local new_state
  if ! new_state=$(echo "${current_state}" | jq \
    --arg ts "${timestamp}" \
    ".steps[\"${step_id}\"].status = \"undone\" | .steps[\"${step_id}\"].undone_at = \$ts" \
    2>/dev/null); then
    echo "Error: Failed to mark step undone with jq" >&2
    return 1
  fi

  # Write back atomically
  state_write "${new_state}"
}

# state_is_undoable - Check if a step can be undone (boolean)
#
# Returns true if step status is "complete" and subtype is reversible.
# Reversible subtypes: brew, brew-cask, mac-defaults
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 (true) if step is undoable
#   1 (false) otherwise
#
# Example:
#   if state_is_undoable "brew-install-git"; then
#     echo "Can undo this step"
#   fi
state_is_undoable() {
  if [[ $# -ne 1 ]]; then
    echo "Error: state_is_undoable requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    return 1
  fi

  # Get step status and subtype
  local status subtype
  status=$(jq -r ".steps[\"${step_id}\"].status // empty" "${state_file}" 2>/dev/null)
  subtype=$(jq -r ".steps[\"${step_id}\"].subtype // empty" "${state_file}" 2>/dev/null)

  # Return false if step doesn't exist
  if [[ -z "${status}" ]] || [[ -z "${subtype}" ]]; then
    return 1
  fi

  # Return true if status is complete and subtype is reversible
  if [[ "${status}" == "complete" ]] && [[ "${subtype}" == "brew" || "${subtype}" == "brew-cask" || "${subtype}" == "mac-defaults" ]]; then
    return 0
  else
    return 1
  fi
}

# state_list_undoable - List all undoable steps
#
# Returns tab-separated list of steps that can be undone.
# Output format: step_id<TAB>description<TAB>subtype
# Only includes completed steps with reversible subtypes.
#
# Returns:
#   0 on success (list output to stdout, may be empty)
#   1 on failure
#
# Example:
#   state_list_undoable | while IFS=$'\t' read -r id desc subtype; do
#     echo "Can undo: $id ($subtype)"
#   done
state_list_undoable() {
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    return 0
  fi

  # Query for completed steps with reversible subtypes
  # Output tab-separated: id, description, subtype
  jq -r '.steps | to_entries[] | select(.value.status == "complete" and (.value.subtype == "brew" or .value.subtype == "brew-cask" or .value.subtype == "mac-defaults")) | [.key, .value.description, .value.subtype] | @tsv' "${state_file}" 2>/dev/null || return 1

  return 0
}

# state_get_subtype - Get the subtype of a step
#
# Retrieves the subtype field for a given step_id from state.json.
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 on success (subtype output to stdout)
#   1 if step doesn't exist (empty output)
#
# Example:
#   subtype=$(state_get_subtype "install-git")
state_get_subtype() {
  if [[ $# -ne 1 ]]; then
    echo "Error: state_get_subtype requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    return 1
  fi

  # Query step subtype
  local subtype
  if ! subtype=$(jq -r ".steps[\"${step_id}\"].subtype // empty" "${state_file}" 2>/dev/null); then
    echo "Error: Failed to query step subtype" >&2
    return 1
  fi

  # Return empty string and exit code 1 if step doesn't exist
  if [[ -z "${subtype}" ]]; then
    return 1
  fi

  echo "${subtype}"
  return 0
}

# state_get_description - Get the description of a step
#
# Retrieves the description field for a given step_id from state.json.
#
# Args:
#   $1 - step_id
#
# Returns:
#   0 on success (description output to stdout)
#   1 if step doesn't exist (empty output)
#
# Example:
#   desc=$(state_get_description "install-git")
state_get_description() {
  if [[ $# -ne 1 ]]; then
    echo "Error: state_get_description requires exactly 1 argument (step_id)" >&2
    return 1
  fi

  local step_id="$1"
  local state_file
  state_file="$(_state_file_path)" || return 1

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    return 1
  fi

  # Query step description
  local description
  if ! description=$(jq -r ".steps[\"${step_id}\"].description // empty" "${state_file}" 2>/dev/null); then
    echo "Error: Failed to query step description" >&2
    return 1
  fi

  # Return empty string and exit code 1 if step doesn't exist
  if [[ -z "${description}" ]]; then
    return 1
  fi

  echo "${description}"
  return 0
}
