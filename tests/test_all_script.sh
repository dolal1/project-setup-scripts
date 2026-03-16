#!/bin/bash

# Run all script tests

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../scripts"

print_info "Running all setup script tests..."

# Find all setup scripts
SCRIPTS=$(find "$SCRIPTS_DIR" -name "setup_*.sh" -type f)

if [ -z "$SCRIPTS" ]; then
    print_error "No setup scripts found in $SCRIPTS_DIR"
    exit 1
fi

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Run tests for each script
for script_path in $SCRIPTS; do
    script_name=$(basename "$script_path" .sh)
    
    print_info "Testing: $script_name"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if "$SCRIPT_DIR/test_script.sh" "$script_name"; then
        print_success "PASSED: $script_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        print_error "FAILED: $script_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo ""
done

# Print summary
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    print_success "All tests passed! 🎉"
    exit 0
else
    print_error "$FAILED_TESTS test(s) failed"
    exit 1
fi