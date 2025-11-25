#!/usr/bin/env bash

# test_state.sh - Comprehensive test for step lifecycle functions
#
# This script demonstrates the full step lifecycle:
# 1. Initialize state
# 2. Register multiple steps with different kinds/subtypes
# 3. Verify all start as pending
# 4. Mark some complete
# 5. Verify status changes and timestamps exist
# 6. Test error cases (invalid kind/subtype, missing step operations)

set -euo pipefail

# Use a temporary test directory
export KYLDVS_PREFIX="/tmp/test-state-$$"
mkdir -p "${KYLDVS_PREFIX}"

# Source the state library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/state.sh
source "${SCRIPT_DIR}/state.sh"

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function for assertions
assert_success() {
  local description="$1"
  if [[ $? -eq 0 ]]; then
    echo "  ✓ ${description}"
    ((TESTS_PASSED++))
  else
    echo "  ✗ ${description}"
    ((TESTS_FAILED++))
  fi
}

assert_failure() {
  local description="$1"
  if [[ $? -ne 0 ]]; then
    echo "  ✓ ${description}"
    ((TESTS_PASSED++))
  else
    echo "  ✗ ${description}"
    ((TESTS_FAILED++))
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local description="$3"
  if [[ "${expected}" == "${actual}" ]]; then
    echo "  ✓ ${description}"
    ((TESTS_PASSED++))
  else
    echo "  ✗ ${description} (expected: '${expected}', got: '${actual}')"
    ((TESTS_FAILED++))
  fi
}

echo "===== Step Lifecycle Test ====="
echo ""

# Test 1: Initialize state
echo "Test 1: Initialize state"
state_init
assert_success "State initialized"
[[ -f "${KYLDVS_PREFIX}/state.json" ]]
assert_success "State file exists"
echo ""

# Test 2: Register steps with different kinds/subtypes
echo "Test 2: Register multiple steps"
step_register "install-git" "Install git via Homebrew" "automated" "brew"
assert_success "Registered brew step"

step_register "install-chrome" "Install Google Chrome" "automated" "brew-cask"
assert_success "Registered brew-cask step"

step_register "set-dock-size" "Set dock icon size" "automated" "mac-defaults"
assert_success "Registered mac-defaults step"

step_register "configure-arc" "Configure Arc browser settings" "manual" "other"
assert_success "Registered manual step"
echo ""

# Test 3: Verify all start as pending
echo "Test 3: Verify all steps start as pending"
status=$(step_get_status "install-git")
assert_equals "pending" "${status}" "Git step is pending"

status=$(step_get_status "install-chrome")
assert_equals "pending" "${status}" "Chrome step is pending"

status=$(step_get_status "set-dock-size")
assert_equals "pending" "${status}" "Dock step is pending"

status=$(step_get_status "configure-arc")
assert_equals "pending" "${status}" "Arc step is pending"
echo ""

# Test 4: Test step_is_complete for pending steps
echo "Test 4: Test step_is_complete for pending steps"
step_is_complete "install-git"
assert_failure "Git step is not complete"

step_is_complete "install-chrome"
assert_failure "Chrome step is not complete"
echo ""

# Test 5: Mark some steps complete
echo "Test 5: Mark steps complete"
step_mark_complete "install-git"
assert_success "Marked git step complete"

step_mark_complete "install-chrome"
assert_success "Marked chrome step complete"
echo ""

# Test 6: Verify status changes and timestamps
echo "Test 6: Verify status changes and timestamps"
status=$(step_get_status "install-git")
assert_equals "complete" "${status}" "Git step is now complete"

status=$(step_get_status "install-chrome")
assert_equals "complete" "${status}" "Chrome step is now complete"

timestamp=$(state_get ".steps.\"install-git\".timestamp")
[[ -n "${timestamp}" ]]
assert_success "Git step has timestamp"

timestamp=$(state_get ".steps.\"install-chrome\".timestamp")
[[ -n "${timestamp}" ]]
assert_success "Chrome step has timestamp"

# Verify timestamp format (ISO8601)
timestamp=$(state_get ".steps.\"install-git\".timestamp")
[[ "${timestamp}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
assert_success "Timestamp is ISO8601 format"
echo ""

# Test 7: Test step_is_complete for completed steps
echo "Test 7: Test step_is_complete for completed steps"
step_is_complete "install-git"
assert_success "Git step is complete (returns 0)"

step_is_complete "install-chrome"
assert_success "Chrome step is complete (returns 0)"

step_is_complete "set-dock-size"
assert_failure "Dock step is still pending (returns 1)"
echo ""

# Test 8: Error cases - invalid kind
echo "Test 8: Error cases - invalid kind"
step_register "invalid-kind" "Test step" "invalid" "brew" 2>/dev/null
assert_failure "Rejected invalid kind"
echo ""

# Test 9: Error cases - invalid subtype
echo "Test 9: Error cases - invalid subtype"
step_register "invalid-subtype" "Test step" "automated" "invalid" 2>/dev/null
assert_failure "Rejected invalid subtype"
echo ""

# Test 10: Error cases - missing step operations
echo "Test 10: Error cases - missing step operations"
step_get_status "nonexistent-step" 2>/dev/null
assert_failure "get_status returns error for missing step"

step_mark_complete "nonexistent-step" 2>/dev/null
assert_failure "mark_complete returns error for missing step"

step_is_complete "nonexistent-step"
assert_failure "is_complete returns false for missing step"
echo ""

# Test 11: Verify JSON structure
echo "Test 11: Verify JSON structure"
steps_object=$(state_get ".steps")
[[ -n "${steps_object}" ]]
assert_success "Steps object exists in state"

git_step=$(state_get ".steps.\"install-git\"")
[[ -n "${git_step}" ]]
assert_success "Git step exists in steps object"

# Verify all required fields
description=$(state_get ".steps.\"install-git\".description")
assert_equals "Install git via Homebrew" "${description}" "Git step has correct description"

kind=$(state_get ".steps.\"install-git\".kind")
assert_equals "automated" "${kind}" "Git step has correct kind"

subtype=$(state_get ".steps.\"install-git\".subtype")
assert_equals "brew" "${subtype}" "Git step has correct subtype"
echo ""

# Cleanup
echo "===== Cleanup ====="
rm -rf "${KYLDVS_PREFIX}"
echo "Removed test directory: ${KYLDVS_PREFIX}"
echo ""

# Summary
echo "===== Test Summary ====="
echo "Tests passed: ${TESTS_PASSED}"
echo "Tests failed: ${TESTS_FAILED}"
echo ""

if [[ ${TESTS_FAILED} -eq 0 ]]; then
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
