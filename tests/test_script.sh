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
        rm -rf "${TEST_DIR:?}/${TEST_PROJECT_NAME:?}"
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
case "$SCRIPT_NAME" in
    setup_*_tiered_project)
        "$SCRIPT_PATH" "$TEST_PROJECT_NAME" --prefix demo --tiers basic,standard,premium < /dev/null
        ;;
    *)
        echo -e "${TEST_PROJECT_NAME}\n${TEST_PROJECT_NAME}-venv" | "$SCRIPT_PATH"
        ;;
esac

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

# Check the AI agent commit review gate (skipped only with --no-ai-guardrails)
for guardrail in AGENTS.md CLAUDE.md .claude/settings.json scripts/propose-commit.sh; do
    if [ ! -f "$guardrail" ]; then
        print_error "AI guardrail file not found: $guardrail"
        exit 1
    fi
done

print_success "AI agent commit review gate present"

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
    "setup_laravel_tiered_project")
        echo "Running Laravel tiered specific checks..."

        for f in config/demo.php app/Support/Modules.php app/View/Components/Can.php \
            modules/Standard/module.php modules/Premium/module.php tests/Feature/ArchTest.php \
            scripts/build-release.sh scripts/release-stack.sh release.exclude .github/workflows/ci.yml; do
            if [ ! -f "$f" ]; then
                print_error "Expected file not found: $f"
                exit 1
            fi
        done
        if grep -qE '\{\{[A-Z_]+\}\}' config/demo.php modules/*/module.php .github/workflows/ci.yml AGENTS.md; then
            print_error "Unfilled {{PLACEHOLDER}} left in generated files"
            exit 1
        fi
        print_success "Tier modules, components and release tooling generated"

        if ! php -m | grep -qi '^pdo_sqlite$'; then
            print_warning "PHP has no pdo_sqlite; skipping the tier test runs and release builds"
        else
            for tier in basic standard premium; do
                DEMO_TIER=$tier php artisan test
            done
            print_success "Test suite passes at every tier"

            export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
            export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"
            git add -A
            git commit -qm "test fixture"
            for tier in basic standard; do
                RELEASE_OUT="$TEST_DIR/releases-$$" scripts/build-release.sh "$tier" 1.0.0
                unzip -q -o "$TEST_DIR/releases-$$/$TEST_PROJECT_NAME-1.0.0-$tier.zip" -d "$TEST_DIR/releases-$$"
            done
            release="$TEST_DIR/releases-$$/$TEST_PROJECT_NAME-1.0.0-basic"
            if [ -e "$release/modules/Standard" ] || [ -e "$release/AGENTS.md" ] || [ -e "$release/.github" ]; then
                print_error "Basic release still contains a higher tier or internal files"
                exit 1
            fi
            # shellcheck disable=SC1003  # the backslashes are a regex for Modules\Standard\
            if grep -rIlE --exclude-dir=vendor 'Modules\\(Standard|Premium)\\' "$release"; then
                print_error "Basic release still references Standard or Premium code"
                exit 1
            fi
            rm -rf "$TEST_DIR/releases-$$"
            print_success "Lower-tier releases build, pass their own tests and contain no higher tier"
        fi

        print_success "All Laravel tiered checks passed"
        ;;
    "setup_django_tiered_project")
        echo "Running Django tiered specific checks..."

        for f in manage.py config/settings.py core/modules.py core/templatetags/tiers.py \
            core/management/commands/demo_feature.py core/migrations/0001_initial.py \
            modules/standard/module.py modules/standard/migrations/0001_initial.py \
            modules/premium/module.py core/tests/test_arch.py \
            scripts/build-release.sh scripts/release-stack.sh release.exclude .github/workflows/ci.yml; do
            if [ ! -f "$f" ]; then
                print_error "Expected file not found: $f"
                exit 1
            fi
        done
        if grep -rqE '\{\{[A-Z_]+\}\}' config core modules templates .github AGENTS.md .env.example; then
            print_error "Unfilled {{PLACEHOLDER}} left in generated files"
            exit 1
        fi
        print_success "Tier modules, template tags, migrations and release tooling generated"

        .venv/bin/python manage.py check
        .venv/bin/python manage.py makemigrations --check --dry-run
        for tier in basic standard premium; do
            DEMO_TIER=$tier .venv/bin/pytest -q
        done
        print_success "Test suite passes at every tier"

        export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
        export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"
        git add -A
        git commit -qm "test fixture"
        for tier in basic standard; do
            RELEASE_OUT="$TEST_DIR/releases-$$" scripts/build-release.sh "$tier" 1.0.0
            unzip -q -o "$TEST_DIR/releases-$$/$TEST_PROJECT_NAME-1.0.0-$tier.zip" -d "$TEST_DIR/releases-$$"
        done
        release="$TEST_DIR/releases-$$/$TEST_PROJECT_NAME-1.0.0-basic"
        if [ -e "$release/modules/standard" ] || [ -e "$release/AGENTS.md" ] || [ -e "$release/.venv" ]; then
            print_error "Basic release still contains a higher tier or internal files"
            exit 1
        fi
        if grep -rlE 'modules\.(standard|premium)\b' "$release" --exclude-dir=.git; then
            print_error "Basic release still references Standard or Premium code"
            exit 1
        fi
        rm -rf "$TEST_DIR/releases-$$"
        print_success "Lower-tier releases build, pass their own tests and contain no higher tier"

        print_success "All Django tiered checks passed"
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