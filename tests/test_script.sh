#!/bin/bash

# Test runner for individual setup scripts

set -e

SCRIPT_NAME="$1"
if [ -z "$SCRIPT_NAME" ]; then
    echo "Usage: $0 <script-name-without-extension>"
    echo "Example: $0 setup_django_typescript_project"
    exit 1
fi

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${TESTS_DIR}/../scripts/${SCRIPT_NAME}.sh"
TEST_PROJECT_NAME="test-${SCRIPT_NAME}-$$"
TEST_DIR="/tmp/setup-script-tests"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Cleanup function
cleanup() {
    if [ -d "$TEST_DIR/$TEST_PROJECT_NAME" ]; then
        echo "Cleaning up test project..."
        rm -rf "$TEST_DIR/$TEST_PROJECT_NAME"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "Testing script: $SCRIPT_NAME"
echo "Test project: $TEST_PROJECT_NAME"
echo "Test directory: $TEST_DIR"

if [ ! -f "$SCRIPT_PATH" ]; then
    print_error "Script not found: $SCRIPT_PATH"
    exit 1
fi

# Make script executable
chmod +x "$SCRIPT_PATH"

# Run the script with test inputs
echo "Running script with automated inputs..."
echo -e "${TEST_PROJECT_NAME}\n${TEST_PROJECT_NAME}-venv" | "$SCRIPT_PATH"

# Verify project was created
if [ ! -d "$TEST_PROJECT_NAME" ]; then
    print_error "Project directory was not created"
    exit 1
fi

print_success "Project directory created"

cd "$TEST_PROJECT_NAME"

# Common checks for all projects
echo "Running common verification checks..."

# Check Git repository
if [ ! -d ".git" ]; then
    print_error "Git repository not initialized"
    exit 1
fi

print_success "Git repository initialized"

# Check README exists
if [ ! -f "README.md" ]; then
    print_error "README.md not found"
    exit 1
fi

print_success "README.md exists"

# Check .gitignore exists
if [ ! -f ".gitignore" ]; then
    print_error ".gitignore not found"
    exit 1
fi

print_success ".gitignore exists"

# Script-specific checks
case "$SCRIPT_NAME" in
    "setup_django_typescript_project")
        echo "Running Django TypeScript specific checks..."
        
        # Check backend structure
        if [ ! -d "backend" ]; then
            print_error "Backend directory not found"
            exit 1
        fi
        
        if [ ! -d "frontend" ]; then
            print_error "Frontend directory not found"
            exit 1
        fi
        
        if [ ! -f "docker-compose.yml" ]; then
            print_error "docker-compose.yml not found"
            exit 1
        fi
        
        if [ ! -f ".env" ]; then
            print_error ".env file not found"
            exit 1
        fi
        
        # Check Django files
        if [ ! -f "backend/manage.py" ]; then
            print_error "Django manage.py not found"
            exit 1
        fi
        
        # Check React files
        if [ ! -f "frontend/package.json" ]; then
            print_error "Frontend package.json not found"
            exit 1
        fi
        
        if [ ! -f "frontend/tsconfig.json" ]; then
            print_error "TypeScript config not found"
            exit 1
        fi
        
        # Test Docker Compose validation
        if command -v docker-compose &> /dev/null; then
            docker-compose config > /dev/null
            print_success "Docker Compose configuration valid"
        else
            print_warning "Docker Compose not available, skipping validation"
        fi
        
        print_success "All Django TypeScript checks passed"
        ;;
    *)
        print_warning "No specific tests for script: $SCRIPT_NAME"
        ;;
esac

print_success "All tests passed for $SCRIPT_NAME!"

echo ""
echo "Test Summary:"
echo "- Script: $SCRIPT_NAME"
echo "- Project: $TEST_PROJECT_NAME"
echo "- Status: SUCCESS"