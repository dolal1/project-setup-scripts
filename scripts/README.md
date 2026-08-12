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

```bash
#!/bin/bash

set -e

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
