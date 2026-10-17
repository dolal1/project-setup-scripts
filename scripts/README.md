# 📜 Setup Scripts

This directory contains automated project setup scripts for various technology stacks.

## 🎯 Usage

Each script is standalone and can be run independently:

```bash
./setup_<technology_stack>_project.sh
```

## 📝 Available Scripts

### Django + React TypeScript

**File**: `setup_django_typescript_project.sh`
**Description**: Full-stack web application with Django REST API and React frontend
**Technologies**: Django, PostgreSQL, React, TypeScript, Docker, Celery, Redis
**Security Tools**: bandit, ruff, semgrep, trivy, trufflehog

```bash
./setup_django_typescript_project.sh
```

### Laravel, tiered

**File**: `setup_laravel_tiered_project.sh`
**Description**: Laravel 12 app sold in tiers; every tier above core is a removable module, and
`scripts/build-release.sh` builds client releases without the higher tiers
**Technologies**: Laravel 12, Laravel Pennant, PHPUnit, GitHub Actions
**Contract**: [docs/tiered-modules.md](../docs/tiered-modules.md)

```bash
./setup_laravel_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
./setup_laravel_tiered_project.sh path/to/repo --prefix myapp --into-existing
./setup_laravel_tiered_project.sh --help
```

Set `LARAVEL_PHP_PLATFORM` (default `8.2.0`) to the lowest PHP version the client's host runs.

### Django, tiered

**File**: `setup_django_tiered_project.sh`
**Description**: Django 5.2 app sold in tiers; every tier above core is a removable Django app in
`modules/<tier>/`, and `scripts/build-release.sh` builds client releases without the higher tiers
**Technologies**: Django 5.2 LTS, django-waffle, pytest-django, GitHub Actions
**Contract**: [docs/tiered-modules.md](../docs/tiered-modules.md)

```bash
./setup_django_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
./setup_django_tiered_project.sh path/to/repo --prefix myapp --into-existing
```

Set `DJANGO_PYTHON_VERSION` (default `3.12`) for the Python version the generated CI uses.

### Node.js, tiered

**File**: `setup_node_tiered_project.sh`
**Description**: Node.js app (Express 5, TypeScript, EJS, Knex) sold in tiers; every tier above core
is a removable folder in `modules/<tier>/`, and `scripts/build-release.sh` builds client releases
without the higher tiers
**Technologies**: Express 5, TypeScript, EJS, Knex (SQLite, MySQL), Vitest, Supertest, GitHub Actions
**Contract**: [docs/tiered-modules.md](../docs/tiered-modules.md)

```bash
./setup_node_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
./setup_node_tiered_project.sh path/to/repo --prefix myapp --into-existing
```

Set `NODE_CI_VERSION` (default `22`) for the Node.js version the generated CI uses.

## 🧰 Shared helpers (`common/`)

Sourced by the setup scripts, never run directly:

| File | Provides |
| --- | --- |
| `common/render.sh` | `render_template <src> <dst> KEY=VALUE...` |
| `common/ai-guardrails.sh` | `apply_ai_guardrails`: the commit review gate every generated project gets |
| `common/tiered.sh` | Argument parsing and prompts, prefix and tier checks, `--into-existing`, `apply_tiered_common` |

## 🔧 Script Requirements

### All Scripts

- Bash 4.0+
- Git
- Internet connection for downloading dependencies

### Django TypeScript Script

- Python 3.11+
- Node.js 18+
- Docker & Docker Compose
- npm/yarn

### Node Tiered Script

- Node.js 22+ and npm

### Django Tiered Script

- Python 3.10+ with the `venv` and `sqlite3` modules

### Laravel Tiered Script

- PHP 8.2+ (with `pdo_sqlite` to run the generated tests)
- Composer 2

## 📋 Script Features

All setup scripts include:

- ✅ Interactive prompts for configuration
- ✅ Dependency checking
- ✅ Git repository initialization
- ✅ Docker containerization
- ✅ Development and production configurations
- ✅ Testing framework setup
- ✅ Code quality tools
- ✅ Security scanning tools
- ✅ Comprehensive documentation

## 🧪 Testing Your Script

Before submitting a new script:

1. Test with different project names
2. Test with different virtual environment names
3. Verify all dependencies are correctly installed
4. Ensure Docker containers start properly
5. Verify tests run successfully
6. Check security scans work

## 📖 Script Template

When creating new scripts, follow this structure:

Source the shared helpers and apply the AI guardrails at the end, so every generated project
gets the commit review gate:

```bash
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
source "$SCRIPT_DIR/common/render.sh"
source "$SCRIPT_DIR/common/ai-guardrails.sh"

# Script metadata
SCRIPT_NAME="Setup <Technology> Project"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="Creates a <technology> project with <features>"

# Colors and utility functions
# ... (copy from existing scripts)

# Dependency checking
check_dependencies() {
    # Check required tools
}

# Main setup logic
main() {
    # Your setup logic here

    # Last step, unless --no-ai-guardrails was given
    apply_ai_guardrails "$TEMPLATES_DIR" "$PWD" "$PROJECT_NAME" "- Project-specific rules for agents"
}

# Error handling
trap 'echo "Script failed on line $LINENO"' ERR

# Run main function
main "$@"
```

## 🤝 Contributing Scripts

1. Follow the naming convention: `setup_<stack>_project.sh`
2. Include comprehensive error handling
3. Add interactive prompts for user input
4. Include dependency checking
5. Add comprehensive documentation
6. Test thoroughly before submitting

## 📞 Support

For script-specific issues, check the individual script's documentation or create an issue in the repository.
