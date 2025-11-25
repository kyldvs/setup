#!/usr/bin/env bash
# Unit tests for undo functions in lib/state.sh
#
# Tests cover:
# - undo_brew: brew package uninstallation
# - undo_brew_cask: brew cask uninstallation
# - undo_mac_defaults: macOS defaults restoration/deletion
# - Error handling and edge cases
#
# Usage:
#   bash test/lib/test_state_undo.sh

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Find repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the state library
if [[ ! -f "${REPO_ROOT}/lib/state.sh" ]]; then
  echo "Error: Could not find lib/state.sh" >&2
  exit 1
fi

source "${REPO_ROOT}/lib/state.sh"

# Test helper functions
print_test_header() {
  echo ""
  echo "===================================="
  echo "Test: $1"
  echo "===================================="
}

assert_success() {
  local test_name="$1"
  local command="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command"; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

assert_failure() {
  local test_name="$1"
  local command="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command"; then
    echo -e "${RED}✗ FAIL${NC}: $test_name (expected failure, got success)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  else
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  fi
}

assert_equals() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Setup test environment
setup_test_env() {
  # Create temporary test directory
  export KYLDVS_PREFIX="/tmp/kyldvs-test-$$"
  mkdir -p "${KYLDVS_PREFIX}"

  # Initialize state file
  state_init
}

# Teardown test environment
teardown_test_env() {
  if [[ -d "${KYLDVS_PREFIX}" ]]; then
    rm -rf "${KYLDVS_PREFIX}"
  fi
}

# Create a mock completed step in state
create_mock_step() {
  local step_id="$1"
  local subtype="$2"
  local params="$3"

  local state_file="${KYLDVS_PREFIX}/state.json"

  local step_json
  step_json=$(jq -n \
    --arg id "$step_id" \
    --arg st "$subtype" \
    --argjson params "$params" \
    '{
      id: $id,
      description: "Test step",
      kind: "automated",
      subtype: $st,
      status: "complete",
      completed_at: "2025-11-24T00:00:00Z",
      params: $params
    }')

  local new_state
  new_state=$(jq --argjson step "$step_json" ".steps[\"$step_id\"] = \$step" "$state_file")
  echo "$new_state" | jq '.' > "$state_file"
}

# Mock brew command for testing
mock_brew() {
  echo "#!/usr/bin/env bash" > "${KYLDVS_PREFIX}/brew"
  cat >> "${KYLDVS_PREFIX}/brew" << 'EOF'
# Mock brew command for testing
case "$1" in
  list)
    if [[ "$2" == "test-package" ]] || [[ "$2" == "cowsay" ]]; then
      exit 0  # Package is installed
    elif [[ "$2" == "--cask" ]] && [[ "$3" == "test-cask" ]]; then
      exit 0  # Cask is installed
    else
      exit 1  # Package not found
    fi
    ;;
  uninstall)
    if [[ "$2" == "test-package" ]] || [[ "$2" == "cowsay" ]]; then
      echo "Uninstalling $2..."
      exit 0
    elif [[ "$2" == "--cask" ]] && [[ "$3" == "test-cask" ]]; then
      echo "Uninstalling cask $3..."
      exit 0
    else
      exit 1
    fi
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "${KYLDVS_PREFIX}/brew"
  export PATH="${KYLDVS_PREFIX}:${PATH}"
}

# Mock defaults command for testing
mock_defaults() {
  echo "#!/usr/bin/env bash" > "${KYLDVS_PREFIX}/defaults"
  cat >> "${KYLDVS_PREFIX}/defaults" << 'EOF'
# Mock defaults command for testing
case "$1" in
  read)
    if [[ "$2" == "com.apple.dock" ]] && [[ "$3" == "orientation" ]]; then
      echo "left"
      exit 0
    else
      exit 1
    fi
    ;;
  write)
    echo "Writing $2 $3 to $4"
    exit 0
    ;;
  delete)
    echo "Deleting $2 $3"
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "${KYLDVS_PREFIX}/defaults"
  export PATH="${KYLDVS_PREFIX}:${PATH}"
}

# Mock killall for testing
mock_killall() {
  echo "#!/usr/bin/env bash" > "${KYLDVS_PREFIX}/killall"
  cat >> "${KYLDVS_PREFIX}/killall" << 'EOF'
# Mock killall command for testing
echo "Restarting $1..."
exit 0
EOF
  chmod +x "${KYLDVS_PREFIX}/killall"
  export PATH="${KYLDVS_PREFIX}:${PATH}"
}

# --- Test Cases ---

test_logging_functions() {
  print_test_header "Logging Functions"

  setup_test_env

  # Test that logging functions exist
  assert_success "log_undo_info exists" "declare -f log_undo_info > /dev/null"
  assert_success "log_undo_warn exists" "declare -f log_undo_warn > /dev/null"
  assert_success "log_undo_error exists" "declare -f log_undo_error > /dev/null"

  # Test that they produce output
  assert_success "log_undo_info produces output" "[[ -n \"\$(log_undo_info 'test' 2>&1)\" ]]"
  assert_success "log_undo_warn produces output" "[[ -n \"\$(log_undo_warn 'test' 2>&1)\" ]]"
  assert_success "log_undo_error produces output" "[[ -n \"\$(log_undo_error 'test' 2>&1)\" ]]"

  teardown_test_env
}

test_helper_functions() {
  print_test_header "Helper Functions"

  setup_test_env

  # Test _check_jq
  assert_success "_check_jq detects jq" "_check_jq"

  # Test _check_state_file with existing file
  assert_success "_check_state_file succeeds with existing state" "_check_state_file"

  # Test _check_state_file with missing file
  rm -f "${KYLDVS_PREFIX}/state.json"
  assert_failure "_check_state_file fails with missing state" "_check_state_file"

  # Restore state file
  state_init

  teardown_test_env
}

test_validate_step_for_undo() {
  print_test_header "Validate Step for Undo"

  setup_test_env

  # Test with non-existent step
  assert_failure "Fails for non-existent step" "_validate_step_for_undo 'nonexistent-step' 2>/dev/null"

  # Create a step with pending status
  create_mock_step "pending-step" "brew" '{"package":"test"}'
  jq '.steps["pending-step"].status = "pending"' "${KYLDVS_PREFIX}/state.json" > "${KYLDVS_PREFIX}/state.json.tmp"
  mv "${KYLDVS_PREFIX}/state.json.tmp" "${KYLDVS_PREFIX}/state.json"

  assert_failure "Fails for pending step" "_validate_step_for_undo 'pending-step' 2>/dev/null"

  # Create a completed step
  create_mock_step "completed-step" "brew" '{"package":"test"}'

  assert_success "Succeeds for completed step" "_validate_step_for_undo 'completed-step'"

  teardown_test_env
}

test_undo_brew() {
  print_test_header "undo_brew Function"

  setup_test_env
  mock_brew

  # Test with non-existent step
  assert_failure "Fails for non-existent step" "undo_brew 'nonexistent-step' 2>/dev/null"

  # Create a completed brew step
  create_mock_step "brew-install-test-package" "brew" '{"package":"test-package"}'

  assert_success "Successfully undoes brew package" "undo_brew 'brew-install-test-package' 2>/dev/null"

  # Verify state was updated
  local status
  status=$(jq -r '.steps["brew-install-test-package"].status' "${KYLDVS_PREFIX}/state.json")
  assert_equals "Step marked as pending after undo" "pending" "$status"

  # Test with already-uninstalled package
  create_mock_step "brew-install-missing" "brew" '{"package":"missing-package"}'
  assert_success "Handles already-uninstalled package" "undo_brew 'brew-install-missing' 2>/dev/null"

  # Test with wrong subtype
  create_mock_step "wrong-subtype" "brew-cask" '{"package":"test"}'
  assert_failure "Fails for wrong subtype" "undo_brew 'wrong-subtype' 2>/dev/null"

  teardown_test_env
}

test_undo_brew_cask() {
  print_test_header "undo_brew_cask Function"

  setup_test_env
  mock_brew

  # Create a completed brew-cask step
  create_mock_step "brew-cask-test-cask" "brew-cask" '{"cask":"test-cask"}'

  assert_success "Successfully undoes brew cask" "undo_brew_cask 'brew-cask-test-cask' 2>/dev/null"

  # Verify state was updated
  local status
  status=$(jq -r '.steps["brew-cask-test-cask"].status' "${KYLDVS_PREFIX}/state.json")
  assert_equals "Step marked as pending after undo" "pending" "$status"

  # Test with missing cask
  create_mock_step "brew-cask-missing" "brew-cask" '{"cask":"missing-cask"}'
  assert_success "Handles already-uninstalled cask" "undo_brew_cask 'brew-cask-missing' 2>/dev/null"

  # Test with wrong subtype
  create_mock_step "wrong-cask-subtype" "brew" '{"cask":"test"}'
  assert_failure "Fails for wrong subtype" "undo_brew_cask 'wrong-cask-subtype' 2>/dev/null"

  teardown_test_env
}

test_undo_mac_defaults() {
  print_test_header "undo_mac_defaults Function"

  setup_test_env
  mock_defaults
  mock_killall

  # Test restoring original value
  create_mock_step "mac-defaults-dock-orientation" "mac-defaults" '{
    "domain":"com.apple.dock",
    "key":"orientation",
    "type":"-string",
    "value":"left",
    "original_value":"bottom"
  }'

  assert_success "Successfully restores original value" "undo_mac_defaults 'mac-defaults-dock-orientation' 2>/dev/null"

  # Verify state was updated
  local status
  status=$(jq -r '.steps["mac-defaults-dock-orientation"].status' "${KYLDVS_PREFIX}/state.json")
  assert_equals "Step marked as pending after undo" "pending" "$status"

  # Test deleting key without original value
  create_mock_step "mac-defaults-new-key" "mac-defaults" '{
    "domain":"com.apple.dock",
    "key":"newkey",
    "type":"-string",
    "value":"newvalue"
  }'

  assert_success "Successfully deletes key without original" "undo_mac_defaults 'mac-defaults-new-key' 2>/dev/null"

  # Test with wrong subtype
  create_mock_step "wrong-defaults-subtype" "brew" '{}'
  assert_failure "Fails for wrong subtype" "undo_mac_defaults 'wrong-defaults-subtype' 2>/dev/null"

  # Test with missing domain/key
  create_mock_step "incomplete-defaults" "mac-defaults" '{}'
  assert_failure "Fails with missing domain/key" "undo_mac_defaults 'incomplete-defaults' 2>/dev/null"

  teardown_test_env
}

test_mark_step_undone() {
  print_test_header "Mark Step Undone"

  setup_test_env

  # Create a completed step
  create_mock_step "test-step" "brew" '{"package":"test"}'

  assert_success "Successfully marks step as undone" "_mark_step_undone 'test-step'"

  # Verify status changed to pending
  local status
  status=$(jq -r '.steps["test-step"].status' "${KYLDVS_PREFIX}/state.json")
  assert_equals "Status is pending" "pending" "$status"

  # Verify undone_at timestamp was recorded
  local undone_at
  undone_at=$(jq -r '.steps["test-step"].undone_at' "${KYLDVS_PREFIX}/state.json")
  assert_success "undone_at timestamp recorded" "[[ -n '$undone_at' ]] && [[ '$undone_at' != 'null' ]]"

  teardown_test_env
}

test_undo_functions_exist() {
  print_test_header "Undo Functions Exist"

  assert_success "undo_brew exists" "declare -f undo_brew > /dev/null"
  assert_success "undo_brew_cask exists" "declare -f undo_brew_cask > /dev/null"
  assert_success "undo_mac_defaults exists" "declare -f undo_mac_defaults > /dev/null"
}

test_error_handling() {
  print_test_header "Error Handling"

  setup_test_env

  # Test with missing KYLDVS_PREFIX
  unset KYLDVS_PREFIX
  assert_failure "Fails with missing KYLDVS_PREFIX" "_state_file_path 2>/dev/null"

  # Restore environment
  setup_test_env

  # Test with corrupted state file
  echo "invalid json" > "${KYLDVS_PREFIX}/state.json"
  assert_failure "Fails with corrupted state file" "undo_brew 'test-step' 2>/dev/null"

  teardown_test_env
}

# --- Run All Tests ---

main() {
  echo "========================================"
  echo "State Undo Functions Test Suite"
  echo "========================================"

  test_undo_functions_exist
  test_logging_functions
  test_helper_functions
  test_validate_step_for_undo
  test_mark_step_undone
  test_undo_brew
  test_undo_brew_cask
  test_undo_mac_defaults
  test_error_handling

  echo ""
  echo "========================================"
  echo "Test Results"
  echo "========================================"
  echo "Tests Run:    $TESTS_RUN"
  echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
  echo "========================================"

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
  fi
}

# Run tests
main
