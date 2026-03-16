# 🚀 Project Setup Scripts Collection

A collection of automated project setup scripts for various technology stacks.

## 📁 Available Setup Scripts

### 🐍 Django + React TypeScript
**File**: `scripts/setup_django_typescript_project.sh`

Creates a full-stack project with:
- Django REST Framework backend
- React TypeScript frontend (Vite)
- PostgreSQL database
- Redis for caching/Celery
- Docker containerization
- Comprehensive testing setup
- Security scanning tools (bandit, ruff, semgrep, trivy, trufflehog)
- Code quality tools (ESLint, Prettier, Black, isort, mypy)

```bash
cd setup-project
./scripts/setup_django_typescript_project.sh
```

### 🔧 More Scripts Coming Soon
- Python FastAPI + React setup
- Node.js Express + Vue.js setup
- Django + Next.js setup
- Microservices setup with Docker Compose

## 🎯 Quick Start

### Local Usage

1. **Clone this repository**:
   ```bash
   git clone https://github.com/dolal1/setup-project.git
   cd setup-project
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x scripts/*.sh
   ```

3. **Run the setup**:
   ```bash
   ./scripts/setup_django_typescript_project.sh
   ```

4. **Follow the prompts** to configure your project

### System-Wide Installation (Optional)

To use these scripts from anywhere on your system:

#### Option 1: Add to PATH (Recommended)
```bash
# Add scripts directory to your PATH
echo 'export PATH="$PATH:'$(pwd)'/scripts"' >> ~/.bashrc
# For zsh users:
# echo 'export PATH="$PATH:'$(pwd)'/scripts"' >> ~/.zshrc

# Reload your shell configuration
source ~/.bashrc  # or source ~/.zshrc

# Now you can run from anywhere:
setup_django_typescript_project.sh
```

#### Option 2: Symlink to /usr/local/bin
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Create symlinks (requires sudo)
sudo ln -s $(pwd)/scripts/setup_django_typescript_project.sh /usr/local/bin/
sudo ln -s $(pwd)/scripts/setup_*.sh /usr/local/bin/

# Now you can run from anywhere:
setup_django_typescript_project.sh
```

#### Option 3: Copy to User's Local Bin
```bash
# Create user bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Copy scripts
cp scripts/*.sh ~/.local/bin/

# Ensure ~/.local/bin is in PATH (add to ~/.bashrc if needed)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc

# Now you can run from anywhere:
setup_django_typescript_project.sh
```

## 📋 Prerequisites

Different scripts may require different tools. Check the individual script documentation for specific requirements.

### Common Requirements
- Git
- Docker & Docker Compose
- Node.js (Latest LTS)
- Python 3.11+

### Installation Check
Run this command to verify prerequisites:

```bash
# Check all dependencies
./scripts/setup_django_typescript_project.sh --check-deps
```

## 🏗️ Project Structure

```
setup-project/
├── scripts/                    # Setup scripts
│   ├── setup_django_typescript_project.sh
│   └── README.md
├── templates/                  # Template files (for future use)
├── docs/                       # Documentation
│   ├── django-typescript-setup.md
│   └── troubleshooting.md
├── .github/
│   └── workflows/
│       └── test-scripts.yml    # CI/CD testing
├── tests/                      # Script tests
│   ├── test_script.sh
│   └── run_all_tests.sh
├── LICENSE
├── .gitignore
└── README.md
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-setup-script`
3. Add your setup script to the `scripts/` directory
4. Update this README with your script details
5. Add tests for your script
6. Test your script thoroughly
7. Submit a pull request

### Script Naming Convention
- Use descriptive names: `setup_<backend>_<frontend>_project.sh`
- Include technology versions if specific
- Add brief description at the top of each script
- Follow the template structure in `scripts/README.md`

### Adding a New Script

1. **Create the script**:
   ```bash
   cp scripts/setup_django_typescript_project.sh scripts/setup_your_new_script.sh
   # Modify the new script for your technology stack
   ```

2. **Add tests**:
   ```bash
   # Test your script
   ./tests/test_script.sh setup_your_new_script
   ```

3. **Update documentation**:
   - Add script description to this README
   - Create documentation in `docs/` if needed
   - Update `scripts/README.md`

## 🧪 Testing

Run the test suite to verify scripts work correctly:

```bash
# Test all scripts
./tests/run_all_tests.sh

# Test specific script
./tests/test_script.sh setup_django_typescript_project
```

### Manual Testing

For manual testing of scripts:

```bash
# Create test project
mkdir -p /tmp/test-setup
cd /tmp/test-setup

# Run script
/path/to/setup-project/scripts/setup_django_typescript_project.sh

# Clean up
rm -rf /tmp/test-setup
```

## 📖 Documentation

Detailed documentation for each setup script is available in the `docs/` directory:

- [Django + TypeScript Setup Guide](docs/django-typescript-setup.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🔒 Security

All scripts include security best practices:
- Dependency vulnerability scanning
- Secret detection
- Code quality checks
- Container security scanning
- No hardcoded secrets or credentials

## 🚀 Usage Examples

### Creating a New Django + React Project

```bash
# From anywhere if installed system-wide
setup_django_typescript_project.sh

# Or locally
cd setup-project
./scripts/setup_django_typescript_project.sh
```

### Quick Project Setup for Development

```bash
# Create project in current directory
echo -e "my-app\nmy-app-venv" | setup_django_typescript_project.sh

# Start development environment
cd my-app
./start_dev.sh
```

## 🔧 Configuration

### Environment Variables

Some scripts support configuration via environment variables:

```bash
# Set default project settings
export DEFAULT_PROJECT_NAME="my-company-app"
export DEFAULT_PYTHON_VERSION="3.11"
export DEFAULT_NODE_VERSION="18"

# Run script with defaults
setup_django_typescript_project.sh
```

### Script Modification

To customize scripts for your organization:

1. Fork the repository
2. Modify scripts in the `scripts/` directory
3. Update default configurations
4. Add your organization's specific tools/requirements

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## 🙋‍♀️ Support

- 📫 Create an issue for bug reports
- 💡 Create an issue for feature requests
- 📖 Check the [docs](docs/) for detailed guides
- 🤝 Contribute new setup scripts!
- 🔍 Check [troubleshooting guide](docs/troubleshooting.md) for common issues

## ✨ Features

- ✅ **Interactive Setup**: User-friendly prompts
- ✅ **Dependency Checking**: Automatic prerequisite verification
- ✅ **Docker Ready**: Containerized development environment
- ✅ **Security First**: Built-in security scanning
- ✅ **Quality Assured**: Code formatting and linting
- ✅ **Test Coverage**: Comprehensive testing setup
- ✅ **Documentation**: Auto-generated project docs
- ✅ **Cross-Platform**: Works on Linux, macOS, and WSL2

---

**Happy Coding!** 🚀

---

## 📊 Script Compatibility

| Script | Linux | macOS | Windows (WSL2) | Docker Required |
|--------|-------|-------|----------------|-----------------|
| Django + TypeScript | ✅ | ✅ | ✅ | Yes |

---

*Maintained by the community • Built with ❤️ for developers*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/dolal1/project-setup-scripts.svg)](https://github.com/dolal1/project-setup-scripts/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/dolal1/project-setup-scripts.svg)](https://github.com/dolal1/project-setup-scripts/issues)
[![CI](https://github.com/dolal1/project-setup-scripts/workflows/Test%20Setup%20Scripts/badge.svg)](https://github.com/dolal1/project-setup-scripts/actions)