#!/usr/bin/env bash
# Manual Step Prompting for Setup Tasks
#
# Provides interactive prompting for manual configuration steps that require
# human action, with state tracking to enable fast skips on re-runs.
#
# USAGE:
#   source "$KYLDVS_REPO/lib/manual.sh"
#   run_manual_step <step_id> <description> <instruction_lines...>
#
# EXAMPLE:
#   run_manual_step "arc-login" "Arc browser login" \
#     "1. Open Arc browser" \
#     "2. Click profile icon" \
#     "3. Complete login"
#
# BEHAVIOR:
#   - First run: Prompts user with instructions
#   - User confirms (y): Records completion, continues
#   - User exits (n): Exits script with error
#   - User skips (s): Continues without recording (will prompt again next time)
#   - Subsequent runs: Skips completed steps with message
#
# STATE:
#   Stored in: $KYLDVS_PREFIX/state.json
#   Format: {"steps": {"<step_id>": {"kind": "manual", "status": "complete", ...}}}

set -euo pipefail

# Get the path to the state file
_manual_state_file_path() {
  # Set KYLDVS_PREFIX with fallback to default based on OS
  if [[ -z "${KYLDVS_PREFIX:-}" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      export KYLDVS_PREFIX="/usr/local/kyldvs"
    else
      export KYLDVS_PREFIX="/home/kyldvs"
    fi
  fi
  echo "${KYLDVS_PREFIX}/state.json"
}

# Initialize state file if it doesn't exist
_manual_state_init() {
  local state_file
  state_file="$(_manual_state_file_path)"

  # Create directory if it doesn't exist
  local state_dir
  state_dir="$(dirname "${state_file}")"
  if [[ ! -d "${state_dir}" ]]; then
    mkdir -p "${state_dir}" 2>/dev/null || {
      echo "Error: Failed to create state directory: ${state_dir}" >&2
      return 1
    }
  fi

  # Create state file if it doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    local init_json='{"version":"1.0","steps":{}}'
    echo "${init_json}" | jq '.' > "${state_file}" 2>/dev/null || {
      echo "Error: Failed to create state file: ${state_file}" >&2
      return 1
    }
  fi

  return 0
}

# Check if a manual step is complete
_manual_step_is_complete() {
  local step_id="$1"
  local state_file
  state_file="$(_manual_state_file_path)"

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    _manual_state_init || return 1
  fi

  # Query step status
  local status
  status=$(jq -r ".steps[\"${step_id}\"].status // empty" "${state_file}" 2>/dev/null) || return 1

  # Return 0 (true) if complete, 1 (false) otherwise
  if [[ "${status}" == "complete" ]]; then
    return 0
  else
    return 1
  fi
}

# Record manual step completion
_manual_step_record_complete() {
  local step_id="$1"
  local description="$2"
  local state_file
  state_file="$(_manual_state_file_path)"

  # Initialize if doesn't exist
  if [[ ! -f "${state_file}" ]]; then
    _manual_state_init || return 1
  fi

  # Get current timestamp in ISO8601 UTC format
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read current state
  local current_state
  current_state=$(cat "${state_file}") || {
    echo "Error: Failed to read current state" >&2
    return 1
  }

  # Update step with completion
  local new_state
  new_state=$(echo "${current_state}" | jq \
    --arg id "${step_id}" \
    --arg desc "${description}" \
    --arg ts "${timestamp}" \
    ".steps[\"${step_id}\"] = {
      id: \$id,
      description: \$desc,
      kind: \"manual\",
      status: \"complete\",
      completed_at: \$ts
    }" 2>/dev/null) || {
    echo "Error: Failed to record step completion with jq" >&2
    return 1
  }

  # Write back atomically
  local temp_file="${state_file}.tmp.$$"
  echo "${new_state}" | jq '.' > "${temp_file}" 2>/dev/null || {
    echo "Error: Failed to write to temporary state file" >&2
    rm -f "${temp_file}"
    return 1
  }

  mv "${temp_file}" "${state_file}" 2>/dev/null || {
    echo "Error: Failed to move temporary file to state file" >&2
    rm -f "${temp_file}"
    return 1
  }

  return 0
}

# run_manual_step - Prompt user to complete manual steps with state tracking
#
# Prompts user to complete manual steps, records completion in state.json
#
# Args:
#   step_id: Unique identifier for this manual step (e.g., "arc-login")
#   description: Brief description shown in skip message
#   instructions: One or more lines of instructions to display
#
# Behavior:
#   - If already complete: print "[skip] <description>" and return
#   - If not complete: display instructions, prompt for confirmation
#   - On "y": record completion in state.json
#   - On "n": exit without recording completion
#   - On "s": skip without recording (allows re-prompt next time)
#
# State format in state.json:
#   "steps": {
#     "arc-login": {
#       "kind": "manual",
#       "status": "complete",
#       "description": "Arc browser login",
#       "completed_at": "2025-11-24T23:45:00Z"
#     }
#   }
run_manual_step() {
  if [[ $# -lt 2 ]]; then
    echo "Error: run_manual_step requires at least 2 arguments (step_id, description, [instructions...])" >&2
    return 1
  fi

  local step_id="$1"
  local description="$2"
  shift 2
  local instructions=("$@")

  # Check if step is already complete
  if _manual_step_is_complete "${step_id}"; then
    # Print skip message with color if terminal
    if [[ -t 1 ]]; then
      echo -e "\033[90m[skip] ${description}\033[0m"
    else
      echo "[skip] ${description}"
    fi
    return 0
  fi

  # Step not complete - prompt user
  echo ""
  echo "=== Manual Step Required ==="
  echo ""
  echo "${description}"
  echo ""

  # Display instructions
  for instruction in "${instructions[@]}"; do
    echo "  ${instruction}"
  done
  echo ""

  # Prompt user
  while true; do
    echo -n "Complete these steps, then: (y)es to confirm, (n)o to exit, (s)kip for now: "
    read -r response

    case "${response}" in
      y|Y|yes|Yes|YES)
        # Record completion
        if _manual_step_record_complete "${step_id}" "${description}"; then
          echo "Step completed and recorded."
          return 0
        else
          echo "Error: Failed to record step completion" >&2
          return 1
        fi
        ;;
      n|N|no|No|NO)
        # Exit without recording
        echo "Exiting without completing step."
        return 1
        ;;
      s|S|skip|Skip|SKIP)
        # Skip without recording
        echo "Skipping for now (will prompt again next time)."
        return 0
        ;;
      *)
        echo "Invalid response. Please enter 'y', 'n', or 's'."
        ;;
    esac
  done
}
