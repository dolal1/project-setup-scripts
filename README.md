# 🚀 Project Setup Scripts Collection

A collection of automated project setup scripts for various technology stacks. Some create a
standard full-stack app; the **tiered** scripts create an app sold in tiers (for example Basic,
Standard, Premium), where a client release contains only the code for the tiers that client has.

Every generated project also gets an [AI agent commit review gate](#-ai-agent-commit-review-gate),
so anyone working on it with an LLM has a human approve each commit.

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

### 🐘 Laravel, tiered

**File**: `scripts/setup_laravel_tiered_project.sh`

Creates a Laravel 12 app whose tiers above core are removable modules in `modules/<Tier>/`:

- Module loader driven by one setting (`<PREFIX>_TIER`)
- Laravel Pennant feature switches, with an artisan command to list and change them
- Role-based permissions and a `<x-can>` Blade component that also knows which tiers are in the build
- An arch test that stops core code from depending on a module
- A sample module per tier, with tests that pass at every tier
- CI that runs the suite once per tier
- `scripts/build-release.sh`, which builds a client release without the higher tiers, checks
  nothing leaked, runs the stripped build's tests, and outputs a fresh one-commit repo and zip

```bash
./scripts/setup_laravel_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium

# Or build into an existing repo (e.g. one holding the project's planning docs), keeping its files
./scripts/setup_laravel_tiered_project.sh path/to/repo --prefix myapp --into-existing
```

See the [Tiered Modules contract](docs/tiered-modules.md) for how the tiers, permissions and
release build work.

### 🐍 Django, tiered

**File**: `scripts/setup_django_tiered_project.sh`

The same tier contract as the Laravel script, for a server-rendered Django 5.2 app:

- Each tier above core is a Django app in `modules/<tier>/`, added to `INSTALLED_APPS` and the URLs
  only when it's at or below `<PREFIX>_TIER` and present on disk
- Feature switches (stored as django-waffle switches, so they show in the admin) and a
  `<prefix>_feature` management command
- `Role` and `Permission` enums checked by `User.has_perm`, which also stops superusers passing
  checks for tiers that aren't in the build; a `{% can %}` template tag and `{% menu %}`
- Migrations generated per module, an arch test, sample modules with tests at every tier, a CI tier
  matrix, and the same `scripts/build-release.sh`

```bash
./scripts/setup_django_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
./scripts/setup_django_tiered_project.sh path/to/repo --prefix myapp --into-existing
```

### 🔧 More Scripts Coming Soon

- Node.js Express + TypeScript, tiered (same tier contract)
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

#### Option 3: Symlink into User's Local Bin

```bash
# Create user bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Link (don't copy) the scripts
ln -s "$(pwd)"/scripts/setup_*.sh ~/.local/bin/

# Ensure ~/.local/bin is in PATH (add to ~/.bashrc if needed)
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
source ~/.bashrc

# Now you can run from anywhere:
setup_django_typescript_project.sh
```

> **Link, don't copy.** The scripts load `scripts/common/` and `templates/` from this
> repository. They follow symlinks to find them, but a copied script can't.

## 📋 Prerequisites

Different scripts may require different tools. Check the individual script documentation for specific requirements.

### Common Requirements

- Git, Bash 4+
- Docker & Docker Compose (Django + TypeScript)
- Node.js (Latest LTS) (Django + TypeScript)
- Python 3.11+ (Django + TypeScript)
- PHP 8.2+ with `pdo_sqlite`, and Composer (Laravel tiered; the generated tests run on SQLite)
- Python 3.10+ with `venv` (Django tiered)

### Installation Check

Run this command to verify prerequisites:

```bash
# Check all dependencies
./scripts/setup_django_typescript_project.sh --check-deps
```

## 🏗️ Project Structure

```text
setup-project/
├── scripts/                    # Setup scripts
│   ├── setup_django_typescript_project.sh
│   ├── setup_laravel_tiered_project.sh
│   ├── setup_django_tiered_project.sh
│   ├── common/                 # Shared helpers: templating, AI guardrails, tier handling
│   ├── propose-commit.sh       # This repo's own commit review helper
│   └── README.md
├── templates/                  # Files the scripts render into new projects
│   ├── ai-agents/              # AGENTS.md, CLAUDE.md, .claude/settings.json, propose-commit.sh
│   ├── tiered-common/          # build-release.sh and release.exclude, for every tiered stack
│   ├── laravel-tiered/         # Laravel tiered app and sample module
│   └── django-tiered/          # Django tiered app and sample module
├── docs/                       # Documentation
│   ├── django-typescript-setup.md
│   ├── tiered-modules.md
│   ├── docker-maintenance.md
│   └── troubleshooting.md
├── .github/
│   └── workflows/
│       └── test-scripts.yml    # CI/CD testing
├── tests/                      # Script tests
│   ├── test_script.sh
│   ├── test_all_script.sh
│   ├── test_ai_guardrails.sh
│   └── test_tiered_common.sh
├── AGENTS.md                   # Rules for AI agents working on this repo
├── CLAUDE.md
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
./tests/test_all_script.sh

# Test specific script
./tests/test_script.sh setup_django_typescript_project
./tests/test_script.sh setup_laravel_tiered_project
./tests/test_script.sh setup_django_tiered_project

# Fast checks of the shared helpers (no installs, a few seconds)
./tests/test_ai_guardrails.sh
./tests/test_tiered_common.sh
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
- [Tiered Modules contract](docs/tiered-modules.md) — how tiered apps load modules, check permissions and build client releases
- [Docker Maintenance Guide](docs/docker-maintenance.md) — reclaiming disk space and rebuilding containers without losing your database
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🔒 Security

All scripts include security best practices:

- Dependency vulnerability scanning
- Secret detection
- Code quality checks
- Container security scanning
- No hardcoded secrets or credentials

## 🤖 AI Agent Commit Review Gate

Every setup script adds these files to the project it creates (skip them with
`--no-ai-guardrails`):

| File | What it does |
| --- | --- |
| `AGENTS.md` | Rules any coding agent reads: before committing, show `git status`, the diff summary and the exact message, then wait for a human to approve. Never push, add remotes or create repos without approval |
| `CLAUDE.md` | Points Claude Code at `AGENTS.md` |
| `.claude/settings.json` | Makes Claude Code stop and ask before `git commit`, `git push`, `git remote add`, `git reset --hard`, `gh repo create/fork` and release builds |
| `scripts/propose-commit.sh` | Shows what's staged and the proposed message, then asks `Commit? [y/N/e/d]`. It reads the answer from the terminal, so an agent can't approve its own commit by piping in "y" |

This repository uses the same gate for its own development.

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

| Script              | Linux | macOS | Windows (WSL2) | Docker Required |
|---------------------|-------|-------|----------------|-----------------|
| Django + TypeScript | ✅    | ✅    | ✅             | Yes             |
| Laravel, tiered     | ✅    | ✅    | ✅             | No              |
| Django, tiered      | ✅    | ✅    | ✅             | No              |

---

*Maintained by the community • Built with ❤️ for developers*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/dolal1/project-setup-scripts.svg)](https://github.com/dolal1/project-setup-scripts/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/dolal1/project-setup-scripts.svg)](https://github.com/dolal1/project-setup-scripts/issues)
[![CI](https://github.com/dolal1/project-setup-scripts/workflows/Test%20Setup%20Scripts/badge.svg)](https://github.com/dolal1/project-setup-scripts/actions)
