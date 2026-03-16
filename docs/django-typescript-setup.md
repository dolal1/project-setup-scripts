# Django + React TypeScript Setup Guide

Complete guide for the Django + React TypeScript project setup script.

## 🎯 Overview

This script creates a production-ready full-stack web application with:

- **Backend**: Django REST Framework
- **Frontend**: React with TypeScript (Vite)
- **Database**: PostgreSQL
- **Cache/Queue**: Redis + Celery
- **Containerization**: Docker Compose
- **Testing**: Comprehensive test suites
- **Security**: Multiple security scanning tools
- **Quality**: Code formatting and linting tools

## 📋 Prerequisites

### Required Software
- **Python 3.11+**
- **Node.js 18+** (LTS recommended)
- **Docker** and **Docker Compose**
- **Git**

### System Requirements
- Linux, macOS, or WSL2 on Windows
- 4GB+ RAM for containers
- 2GB+ free disk space

### Installation Commands

#### Ubuntu/Debian
```bash
# Update package list
sudo apt update

# Install Python
sudo apt install python3.11 python3.11-venv python3-pip

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Docker
sudo apt install docker.io docker-compose
sudo usermod -aG docker $USER

# Install Git
sudo apt install git
```

#### macOS
```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install python@3.11 node docker git
```

## 🚀 Usage

### 1. Run the Setup Script

```bash
cd setup-project
./scripts/setup_django_typescript_project.sh
```

### 2. Follow Interactive Prompts

The script will ask for:
- **Project name**: `my-awesome-app`
- **Virtual environment name**: `my-awesome-app-venv` (default)

### 3. Wait for Setup Completion

The script will:
- Create project structure
- Initialize Git repository
- Set up Django backend with virtual environment
- Create React TypeScript frontend
- Configure Docker containers
- Install all dependencies
- Set up development tools

## 📁 Generated Project Structure

```
my-awesome-app/
├── backend/                    # Django REST API
│   ├── core/                  # Main Django project
│   ├── api/                   # API endpoints
│   ├── accounts/              # User management
│   ├── my-awesome-app-venv/   # Virtual environment
│   ├── requirements.txt       # Production deps
│   ├── requirements-dev.txt   # Dev dependencies
│   ├── manage.py             # Django management
│   ├── pytest.ini           # Test configuration
│   ├── pyproject.toml        # Python tools config
│   └── Dockerfile           # Backend container
├── frontend/                   # React TypeScript app
│   ├── src/                  # Source code
│   ├── public/               # Static assets
│   ├── package.json          # Node dependencies
│   ├── vite.config.ts        # Vite configuration
│   ├── tsconfig.json         # TypeScript config
│   ├── .eslintrc.cjs         # ESLint rules
│   └── Dockerfile           # Frontend container
├── docker-compose.yml         # Multi-service setup
├── .env                      # Environment variables
├── .gitignore               # Git ignore rules
├── scripts.sh               # Dev/test scripts
├── start_dev.sh             # Quick start script
└── README.md                # Project documentation
```

## 🛠️ Development Workflow

### Starting Development Environment

```bash
# Quick start (recommended)
./start_dev.sh

# Or manual start
docker-compose up --build
```

### Accessing Services

After starting containers:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **Django Admin**: http://localhost:8000/admin
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

### Running Tests

```bash
# Run all tests and quality checks
./scripts.sh all

# Individual commands
./scripts.sh test      # Run tests only
./scripts.sh quality   # Code quality checks
./scripts.sh security  # Security scans
```

### Manual Development Setup

#### Backend Setup
```bash
cd backend
source my-awesome-app-venv/bin/activate  # Activate virtual env
python manage.py migrate                 # Run migrations
python manage.py createsuperuser        # Create admin user
python manage.py runserver              # Start development server
```

#### Frontend Setup
```bash
cd frontend
npm install           # Install dependencies
npm run dev          # Start development server
npm run test         # Run tests
npm run build        # Build for production
```

## 🔧 Configuration

### Environment Variables

Edit the `.env` file to customize your setup:

```bash
# Project Configuration
PROJECT_NAME=my-awesome-app
VENV_NAME=my-awesome-app-venv

# Django Settings
DEBUG=True
DJANGO_SECRET_KEY=your-secret-key-here

# Database Configuration
DB_NAME=my_awesome_app_db
DB_USER=postgres
DB_PASSWORD=postgres
```

### Django Settings

Key configurations in `backend/core/settings.py`:
- CORS settings for frontend communication
- Database configuration
- REST Framework setup
- Security settings for production

### Frontend Configuration

TypeScript and React setup in `frontend/`:
- Vite for fast development builds
- ESLint and Prettier for code quality
- Vitest for testing
- TypeScript strict mode enabled

## 🧪 Testing

### Backend Testing (Django)
```bash
cd backend
source my-awesome-app-venv/bin/activate
pytest                          # Run all tests
pytest --cov                   # With coverage
pytest tests/test_api.py       # Specific test file
```

### Frontend Testing (React)
```bash
cd frontend
npm run test           # Run tests
npm run test:ui        # Interactive testing UI
npm run coverage       # Generate coverage report
```

## 🔒 Security Tools

The setup includes multiple security scanning tools:

### Python Security (Backend)
- **Bandit**: Scans for security issues in Python code
- **Safety**: Checks for known vulnerabilities in dependencies
- **Ruff**: Fast linter with security rules

### JavaScript Security (Frontend)
- **npm audit**: Checks for vulnerable npm packages
- **Semgrep**: Static analysis for security issues

### Container Security
- **Trivy**: Scans container images and filesystems
- **TruffleHog**: Detects secrets in code

### Running Security Scans
```bash
./scripts.sh security
```

## 🎨 Code Quality Tools

### Python (Backend)
- **Black**: Code formatting
- **isort**: Import sorting
- **mypy**: Type checking
- **Ruff**: Fast linting

### TypeScript (Frontend)
- **ESLint**: Code linting
- **Prettier**: Code formatting
- **TypeScript**: Type checking

### Running Quality Checks
```bash
./scripts.sh quality
```

## 🐳 Docker Services

The setup includes these Docker services:

1. **frontend**: React development server
2. **backend**: Django application
3. **celery-worker**: Background task processor
4. **postgres**: PostgreSQL database
5. **redis**: Redis cache and message broker

### Managing Docker Services

```bash
# Start all services
docker-compose up

# Start specific service
docker-compose up postgres

# View logs
docker-compose logs backend

# Stop services
docker-compose down

# Rebuild containers
docker-compose up --build
```

## 🚀 Production Deployment

### Security Checklist

Before deploying to production:

1. **Change secret keys**:
   ```bash
   # Generate new Django secret key
   python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
   ```

2. **Update environment variables**:
   - Set `DEBUG=False`
   - Configure production database
   - Set proper `ALLOWED_HOSTS`

3. **SSL/HTTPS**: Configure SSL certificates

4. **Static files**: Set up proper static file serving

5. **Monitoring**: Add logging and monitoring

### Environment Setup

```bash
# Production environment variables
DEBUG=False
DJANGO_SECRET_KEY=your-production-secret-key
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
DB_HOST=your-production-db-host
```

## 🔧 Troubleshooting

### Common Issues

#### Docker Permission Issues
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Restart terminal session
```

#### Port Already in Use
```bash
# Find process using port
sudo lsof -i :3000
sudo lsof -i :8000

# Stop the process
sudo kill -9 <PID>
```

#### Virtual Environment Issues
```bash
# Recreate virtual environment
rm -rf backend/my-awesome-app-venv
cd backend
python3 -m venv my-awesome-app-venv
source my-awesome-app-venv/bin/activate
pip install -r requirements.txt
```

#### Database Connection Issues
```bash
# Reset database
docker-compose down
docker volume prune
docker-compose up --build
```

### Getting Help

1. Check the generated project's README
2. Review Docker container logs
3. Verify all dependencies are installed
4. Create an issue in the setup-project repository

## 📞 Support

For issues with this setup script:
- Create an issue in the GitHub repository
- Check the troubleshooting guide
- Review the generated project documentation

---

Happy coding with your new Django + React TypeScript project! 🚀