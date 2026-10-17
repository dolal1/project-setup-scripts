#!/bin/bash

set -e

# Resolve through symlinks so templates are found when the script is linked onto PATH
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
# shellcheck source=SCRIPTDIR/common/render.sh
source "$SCRIPT_DIR/common/render.sh"
# shellcheck source=SCRIPTDIR/common/ai-guardrails.sh
source "$SCRIPT_DIR/common/ai-guardrails.sh"

AI_GUARDRAILS=true
for arg in "$@"; do
    case "$arg" in
        --no-ai-guardrails) AI_GUARDRAILS=false ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and run the script again."
        exit 1
    fi
}

print_status "Checking dependencies..."
check_dependencies

# Get project name from user
read -p "Enter your project name (e.g., my-app): " PROJECT_NAME

if [[ -z "$PROJECT_NAME" ]]; then
    print_error "Project name cannot be empty"
    exit 1
fi

# Validate project name
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    print_error "Project name can only contain letters, numbers, hyphens, and underscores"
    exit 1
fi

# Get virtual environment name from user
read -p "Enter virtual environment name (default: ${PROJECT_NAME}-venv): " VENV_NAME
VENV_NAME=${VENV_NAME:-"${PROJECT_NAME}-venv"}

# Validate virtual environment name
if [[ ! "$VENV_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    print_error "Virtual environment name can only contain letters, numbers, hyphens, and underscores"
    exit 1
fi

print_status "Creating project: $PROJECT_NAME"
print_status "Virtual environment: $VENV_NAME"

# Create main project directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Initialize Git repository
print_status "Initializing Git repository..."
git init
cat > .gitignore << 'EOL'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST
*.manifest
*.spec
pip-log.txt
pip-delete-this-directory.txt
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/
.pytype/
.cov/
.mypy_cache/
.dmypy.json
dmypy.json
.pyre/
.pytype/
cython_debug/

# Django
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal
media/
staticfiles/
static/

# Virtual Environment
*/venv/
*/*-venv/
.env
.env.local
.env.*.local

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*
.DS_Store
*.tsbuildinfo
.npm
.eslintcache

# Build outputs
dist/
build/
*.tgz
*.tar.gz

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Docker
.dockerignore

# Security scan results
.trivyignore
security-reports/
bandit-report.json
semgrep-report.json

# Test coverage
htmlcov/
.coverage
coverage.json
EOL

print_status "Setting up Django backend..."

# Create Django backend
mkdir -p backend
cd backend

# Create Django project using official Django with custom venv name
python3 -m venv "$VENV_NAME"
source "$VENV_NAME/bin/activate"

# Install development and security tools
pip install --upgrade pip
pip install django djangorestframework django-cors-headers psycopg2-binary celery redis python-decouple
pip install pytest pytest-django pytest-cov factory-boy faker
pip install bandit ruff black isort mypy types-requests
pip install safety

django-admin startproject core .

# Create basic Django apps
python manage.py startapp api
python manage.py startapp accounts

cd ..

print_status "Setting up React TypeScript frontend..."

# Create React frontend with TypeScript template
npm create vite@latest frontend -- --template react-ts
cd frontend

# Install additional dependencies
npm install
npm install -D @testing-library/react @testing-library/jest-dom @testing-library/user-event
npm install -D vitest jsdom @vitest/ui @vitest/coverage-v8
npm install -D eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser
npm install -D prettier eslint-config-prettier eslint-plugin-prettier

# Update package.json with test scripts
npm pkg set scripts.test="vitest"
npm pkg set scripts.test:ui="vitest --ui"
npm pkg set scripts.coverage="vitest --coverage"
npm pkg set scripts.lint="eslint src --ext ts,tsx --report-unused-disable-directives --max-warnings 0"
npm pkg set scripts.lint:fix="eslint src --ext ts,tsx --fix"
npm pkg set scripts.format="prettier --write src/**/*.{ts,tsx,js,jsx,json,css,md}"
npm pkg set scripts.type-check="tsc --noEmit"

cd ..

print_status "Creating Docker configuration..."

# Create docker-compose.yml
cat > docker-compose.yml << EOL
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: \${PROJECT_NAME:-myapp}-frontend
    ports:
      - '3000:3000'
    volumes:
      - ./frontend:/app
      - node_modules:/app/node_modules
    environment:
      - VITE_API_BASE_URL=\${VITE_API_BASE_URL:-http://localhost:8000}
    depends_on:
      - backend
    networks:
      - app_network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: \${PROJECT_NAME:-myapp}-backend
    ports:
      - '8000:8000'
    volumes:
      - ./backend:/app
      - backend_venv:/app/${VENV_NAME}
    environment:
      - VENV_NAME=${VENV_NAME}
      - DJANGO_ENVIRONMENT=\${DJANGO_ENVIRONMENT:-development}
      - DJANGO_SECRET_KEY=\${DJANGO_SECRET_KEY:-your-secret-key-here}
      - DEBUG=\${DEBUG:-True}
      - DB_ENGINE=\${DB_ENGINE:-django.db.backends.postgresql}
      - DB_NAME=\${DB_NAME:-myapp_db}
      - DB_USER=\${DB_USER:-postgres}
      - DB_PASSWORD=\${DB_PASSWORD:-postgres}
      - DB_HOST=\${DB_HOST:-postgres}
      - DB_PORT=\${DB_PORT:-5432}
      - CELERY_BROKER_URL=\${CELERY_BROKER_URL:-redis://redis:6379/0}
      - CELERY_RESULT_BACKEND=\${CELERY_RESULT_BACKEND:-redis://redis:6379/0}
    command: >
      bash -c "source ${VENV_NAME}/bin/activate &&
               python manage.py migrate &&
               python manage.py collectstatic --noinput &&
               python manage.py runserver 0.0.0.0:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - app_network

  celery-worker:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: \${PROJECT_NAME:-myapp}-celery
    volumes:
      - ./backend:/app
      - backend_venv:/app/${VENV_NAME}
    environment:
      - VENV_NAME=${VENV_NAME}
      - DJANGO_ENVIRONMENT=\${DJANGO_ENVIRONMENT:-development}
      - DJANGO_SECRET_KEY=\${DJANGO_SECRET_KEY:-your-secret-key-here}
      - DB_ENGINE=\${DB_ENGINE:-django.db.backends.postgresql}
      - DB_NAME=\${DB_NAME:-myapp_db}
      - DB_USER=\${DB_USER:-postgres}
      - DB_PASSWORD=\${DB_PASSWORD:-postgres}
      - DB_HOST=\${DB_HOST:-postgres}
      - DB_PORT=\${DB_PORT:-5432}
      - CELERY_BROKER_URL=\${CELERY_BROKER_URL:-redis://redis:6379/0}
      - CELERY_RESULT_BACKEND=\${CELERY_RESULT_BACKEND:-redis://redis:6379/0}
    command: bash -c "source ${VENV_NAME}/bin/activate && celery --app=core worker --loglevel=info"
    depends_on:
      - backend
      - redis
      - postgres
    networks:
      - app_network

  postgres:
    image: postgres:15-alpine
    container_name: \${PROJECT_NAME:-myapp}-postgres
    ports:
      - '5432:5432'
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=\${DB_NAME:-myapp_db}
      - POSTGRES_USER=\${DB_USER:-postgres}
      - POSTGRES_PASSWORD=\${DB_PASSWORD:-postgres}
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U \${DB_USER:-postgres} -d \${DB_NAME:-myapp_db}']
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app_network

  redis:
    image: redis:7-alpine
    container_name: \${PROJECT_NAME:-myapp}-redis
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
    networks:
      - app_network

volumes:
  postgres_data:
  redis_data:
  node_modules:
  backend_venv:

networks:
  app_network:
    driver: bridge
EOL

print_status "Creating environment configuration..."

# Create .env file
cat > .env << EOL
# Project Configuration
PROJECT_NAME=${PROJECT_NAME}
VENV_NAME=${VENV_NAME}

# Django Configuration
DJANGO_ENVIRONMENT=development
DJANGO_SECRET_KEY=your-secret-key-change-this-in-production
DEBUG=True

# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=${PROJECT_NAME}_db
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=postgres
DB_PORT=5432

# Redis/Celery Configuration
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Frontend Configuration
VITE_API_BASE_URL=http://localhost:8000
EOL

print_status "Creating Docker files..."

# Backend Dockerfile
cat > backend/Dockerfile << EOL
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update \\
    && apt-get install -y --no-install-recommends \\
        postgresql-client \\
        build-essential \\
        libpq-dev \\
        curl \\
    && rm -rf /var/lib/apt/lists/*

# Install security scanners
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

# Copy requirements and install Python dependencies
COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -r requirements-dev.txt

# Copy project
COPY . .

# Create static and media directories
RUN mkdir -p static media

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOL

# Frontend Dockerfile
cat > frontend/Dockerfile << 'EOL'
FROM node:18-alpine

WORKDIR /app

# Install security scanner
RUN npm install -g semgrep

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
EOL

print_status "Creating backend requirements..."

cat > backend/requirements.txt << 'EOL'
Django>=4.2.0,<5.0.0
djangorestframework>=3.14.0
django-cors-headers>=4.0.0
psycopg2-binary>=2.9.0
celery>=5.2.0
redis>=4.5.0
python-decouple>=3.8
Pillow>=9.5.0
gunicorn>=20.1.0
EOL

cat > backend/requirements-dev.txt << 'EOL'
# Testing
pytest>=7.4.0
pytest-django>=4.5.0
pytest-cov>=4.1.0
pytest-mock>=3.11.0
factory-boy>=3.3.0
faker>=19.0.0

# Code Quality
black>=23.0.0
isort>=5.12.0
ruff>=0.0.280
bandit>=1.7.5
safety>=2.3.0

# Type Checking
mypy>=1.5.0
django-stubs>=4.2.0
types-requests>=2.31.0

# Documentation
sphinx>=7.1.0
sphinx-rtd-theme>=1.3.0
EOL

print_status "Creating Django settings with security..."

# ...existing code...
cat > backend/core/settings.py << 'EOL'
from pathlib import Path
from decouple import config
import os

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('DJANGO_SECRET_KEY', default='your-secret-key-here')
DEBUG = config('DEBUG', default=True, cast=bool)

ALLOWED_HOSTS = ['*'] if DEBUG else config('ALLOWED_HOSTS', default='localhost,127.0.0.1').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'api',
    'accounts',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': config('DB_ENGINE', default='django.db.backends.postgresql'),
        'NAME': config('DB_NAME', default='myapp_db'),
        'USER': config('DB_USER', default='postgres'),
        'PASSWORD': config('DB_PASSWORD', default='postgres'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'static'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# CORS settings
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
] if DEBUG else config('CORS_ALLOWED_ORIGINS', default='').split(',')

CORS_ALLOW_CREDENTIALS = True

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
    ],
}

# Celery Configuration
CELERY_BROKER_URL = config('CELERY_BROKER_URL', default='redis://localhost:6379/0')
CELERY_RESULT_BACKEND = config('CELERY_RESULT_BACKEND', default='redis://localhost:6379/0')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE

# Security Settings
if not DEBUG:
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_REDIRECT_EXEMPT = []
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    X_FRAME_OPTIONS = 'DENY'
EOL

# Create test configuration
cat > backend/pytest.ini << 'EOL'
[tool:pytest]
DJANGO_SETTINGS_MODULE = core.settings
python_files = tests.py test_*.py *_tests.py
python_classes = Test*
python_functions = test_*
addopts = --tb=short --strict-markers --disable-warnings --cov=. --cov-report=html --cov-report=term-missing
markers = 
    slow: marks tests as slow (deselect with '-m "not slow"')
    integration: marks tests as integration tests
    unit: marks tests as unit tests
EOL

# Create ruff configuration
cat > backend/pyproject.toml << 'EOL'
[tool.ruff]
target-version = "py311"
line-length = 88
select = [
    "E",  # pycodestyle errors
    "W",  # pycodestyle warnings
    "F",  # pyflakes
    "I",  # isort
    "B",  # flake8-bugbear
    "C4", # flake8-comprehensions
    "UP", # pyupgrade
]
ignore = []

[tool.ruff.per-file-ignores]
"__init__.py" = ["E402"]
"**/{tests,docs,tools}/*" = ["E402"]

[tool.black]
line-length = 88
target-version = ['py311']
include = '\.pyi?$'

[tool.isort]
profile = "black"
multi_line_output = 3
line_length = 88

[tool.mypy]
python_version = "3.11"
check_untyped_defs = true
ignore_missing_imports = true
warn_unused_ignores = true
warn_redundant_casts = true
warn_unused_configs = true
plugins = ["mypy_django_plugin.main"]

[tool.django-stubs]
django_settings_module = "core.settings"

[tool.coverage.run]
source = "."
omit = [
    "manage.py",
    "*/settings/*",
    "*/migrations/*",
    "*/venv/*",
    "*/*-venv/*",
    "*/env/*",
    "*/tests/*",
    "*/test_*",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
]
EOL

# Create bandit configuration
cat > backend/.bandit << 'EOL'
[bandit]
exclude_dirs = ['tests', 'migrations', 'venv', '*-venv']
skips = ['B101', 'B601']
EOL

print_status "Creating frontend configurations..."

# Update vite.config.ts for testing
cat > frontend/vite.config.ts << 'EOL'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    css: true,
  },
})
EOL

# Create test setup file
mkdir -p frontend/src/test
cat > frontend/src/test/setup.ts << 'EOL'
import '@testing-library/jest-dom'
EOL

# Create ESLint configuration
cat > frontend/.eslintrc.cjs << 'EOL'
module.exports = {
  root: true,
  env: { browser: true, es2020: true },
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    'eslint-config-prettier',
  ],
  ignorePatterns: ['dist', '.eslintrc.cjs'],
  parser: '@typescript-eslint/parser',
  plugins: ['react-refresh', '@typescript-eslint', 'prettier'],
  rules: {
    'react-refresh/only-export-components': [
      'warn',
      { allowConstantExport: true },
    ],
    'prettier/prettier': 'error',
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/no-explicit-any': 'warn',
  },
}
EOL

# Create Prettier configuration
cat > frontend/.prettierrc << 'EOL'
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 80
}
EOL

# Create sample test
cat > frontend/src/App.test.tsx << 'EOL'
import { render, screen } from '@testing-library/react'
import App from './App'

test('renders learn react link', () => {
  render(<App />)
  const linkElement = screen.getByText(/learn react/i)
  expect(linkElement).toBeInTheDocument()
})
EOL

print_status "Creating security and test scripts..."

# Create comprehensive development scripts
cat > scripts.sh << 'EOL'
#!/bin/bash

# Development and testing scripts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Security scan function
security_scan() {
    print_status "Running security scans..."
    
    # Backend security scans
    print_status "Scanning backend..."
    cd backend
    
    if [ -d "$VENV_NAME" ]; then
        source "$VENV_NAME/bin/activate"
        
        # Python security tools
        print_status "Running bandit..."
        bandit -r . -f json -o bandit-report.json || print_warning "Bandit found issues"
        
        print_status "Running safety check..."
        safety check --json --output safety-report.json || print_warning "Safety found vulnerabilities"
        
        print_status "Running ruff..."
        ruff check . || print_warning "Ruff found issues"
        
        deactivate
    else
        print_error "Virtual environment not found. Run setup first."
    fi
    
    cd ..
    
    # Frontend security scans
    print_status "Scanning frontend..."
    cd frontend
    
    if [ -f "package.json" ]; then
        print_status "Running npm audit..."
        npm audit --audit-level high || print_warning "npm audit found vulnerabilities"
        
        print_status "Running semgrep..."
        npx semgrep --config=auto src/ || print_warning "Semgrep found issues"
    fi
    
    cd ..
    
    # Container security scan
    print_status "Running Trivy container scan..."
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        -v $PWD:/workspace aquasec/trivy:latest fs --security-checks vuln,secret /workspace || print_warning "Trivy found issues"
    
    # Secret scanning
    print_status "Running TruffleHog..."
    docker run --rm -v "$PWD:/pwd" trufflesecurity/trufflehog:latest git file:///pwd || print_warning "TruffleHog found secrets"
    
    print_success "Security scans completed!"
}

# Test function
run_tests() {
    print_status "Running tests..."
    
    # Backend tests
    print_status "Running backend tests..."
    cd backend
    
    if [ -d "$VENV_NAME" ]; then
        source "$VENV_NAME/bin/activate"
        python -m pytest --cov-report=html --cov-report=term-missing || print_error "Backend tests failed"
        deactivate
    else
        print_error "Virtual environment not found"
    fi
    
    cd ..
    
    # Frontend tests
    print_status "Running frontend tests..."
    cd frontend
    npm run test || print_error "Frontend tests failed"
    npm run coverage || print_warning "Coverage generation failed"
    cd ..
    
    print_success "Tests completed!"
}

# Code quality function
code_quality() {
    print_status "Running code quality checks..."
    
    # Backend
    cd backend
    if [ -d "$VENV_NAME" ]; then
        source "$VENV_NAME/bin/activate"
        
        print_status "Running black..."
        black . || print_warning "Black formatting needed"
        
        print_status "Running isort..."
        isort . || print_warning "Import sorting needed"
        
        print_status "Running mypy..."
        mypy . || print_warning "Type checking issues found"
        
        deactivate
    fi
    cd ..
    
    # Frontend
    cd frontend
    print_status "Running frontend linting..."
    npm run lint || print_warning "Linting issues found"
    npm run format || print_warning "Formatting needed"
    npm run type-check || print_warning "TypeScript issues found"
    cd ..
    
    print_success "Code quality checks completed!"
}

# Main script logic
case "$1" in
    "security")
        security_scan
        ;;
    "test")
        run_tests
        ;;
    "quality")
        code_quality
        ;;
    "all")
        code_quality
        run_tests
        security_scan
        ;;
    *)
        echo "Usage: $0 {security|test|quality|all}"
        echo "  security - Run security scans"
        echo "  test     - Run all tests"
        echo "  quality  - Run code quality checks"
        echo "  all      - Run everything"
        exit 1
        ;;
esac
EOL

chmod +x scripts.sh

# Update the start script
cat > start_dev.sh << 'EOL'
#!/bin/bash

# Start development environment
echo "Starting development environment..."

# Build and start containers
docker-compose up --build

EOL

chmod +x start_dev.sh

print_status "Creating comprehensive README..."

cat > README.md << EOL
# $PROJECT_NAME

A full-stack Django + React TypeScript project with comprehensive testing, security scanning, and development tools.

## 🚀 Features

- **Backend**: Django REST Framework with PostgreSQL
- **Frontend**: React with TypeScript and Vite
- **Testing**: Comprehensive test suites for both frontend and backend
- **Security**: Built-in security scanning with multiple tools
- **Code Quality**: Linting, formatting, and type checking
- **Containerization**: Docker and Docker Compose setup
- **Task Queue**: Celery with Redis
- **Virtual Environment**: Custom named environment (\`$VENV_NAME\`)

## 📋 Prerequisites

- Docker and Docker Compose
- Node.js 18+
- Python 3.11+
- Git

## 🏗️ Quick Start

1. **Setup**:
   \`\`\`bash
   cd $PROJECT_NAME
   cp .env.example .env  # Edit as needed
   \`\`\`

2. **Start Development**:
   \`\`\`bash
   ./start_dev.sh
   # Or manually:
   docker-compose up --build
   \`\`\`

3. **Access Applications**:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - Admin: http://localhost:8000/admin

## 🧪 Testing & Quality

Run all checks:
\`\`\`bash
./scripts.sh all
\`\`\`

Individual commands:
\`\`\`bash
./scripts.sh test      # Run tests
./scripts.sh quality   # Code quality checks  
./scripts.sh security  # Security scans
\`\`\`

### Backend Testing
\`\`\`bash
cd backend
source $VENV_NAME/bin/activate
pytest --cov-report=html
\`\`\`

### Frontend Testing
\`\`\`bash
cd frontend
npm run test
npm run coverage
npm run type-check
\`\`\`

## 🔒 Security Tools

- **Bandit**: Python security linter
- **Safety**: Python dependency vulnerability scanner
- **Ruff**: Fast Python linter
- **npm audit**: Node.js dependency scanner
- **Semgrep**: Static analysis tool
- **Trivy**: Container vulnerability scanner
- **TruffleHog**: Secret scanner

## 🛠️ Development

### Backend Setup
\`\`\`bash
cd backend
python -m venv $VENV_NAME
source $VENV_NAME/bin/activate  # Linux/macOS
# $VENV_NAME\\Scripts\\activate  # Windows
pip install -r requirements.txt
pip install -r requirements-dev.txt
python manage.py migrate
python manage.py createsuperuser
\`\`\`

### Frontend Setup
\`\`\`bash
cd frontend
npm install
npm run dev
\`\`\`

### Code Formatting
\`\`\`bash
# Backend
cd backend && source $VENV_NAME/bin/activate
black .
isort .
ruff check . --fix

# Frontend  
cd frontend
npm run format
npm run lint:fix
\`\`\`

## 📁 Project Structure

\`\`\`
$PROJECT_NAME/
├── backend/                 # Django backend
│   ├── core/               # Main Django project
│   ├── api/                # API endpoints
│   ├── accounts/           # User management
│   ├── $VENV_NAME/         # Python virtual environment
│   ├── requirements.txt    # Production dependencies
│   ├── requirements-dev.txt # Development dependencies
│   ├── pytest.ini         # Test configuration
│   ├── pyproject.toml      # Python tools config
│   └── .bandit            # Security scan config
├── frontend/               # React TypeScript frontend
│   ├── src/
│   │   ├── test/          # Test utilities
│   │   └── App.test.tsx   # Sample tests
│   ├── vite.config.ts     # Vite configuration
│   ├── .eslintrc.cjs      # ESLint configuration
│   └── .prettierrc       # Prettier configuration
├── docker-compose.yml     # Multi-service setup
├── .env                   # Environment variables
├── .gitignore            # Git ignore patterns
├── start_dev.sh          # Development startup script
├── scripts.sh            # Testing and security scripts
└── README.md
\`\`\`

## 🐳 Docker Services

- **frontend**: React development server
- **backend**: Django application server
- **celery-worker**: Background task processor
- **postgres**: PostgreSQL database
- **redis**: Redis cache and message broker

## 📊 API Endpoints

- Health Check: \`GET /api/health/\`
- API Info: \`GET /api/info/\`

## 🔧 Environment Variables

Key variables in \`.env\`:

- \`PROJECT_NAME\`: Project identifier
- \`VENV_NAME\`: Virtual environment name ($VENV_NAME)
- \`DJANGO_SECRET_KEY\`: Django secret (change in production!)
- \`DEBUG\`: Development mode flag
- \`DB_*\`: Database configuration
- \`CELERY_*\`: Task queue configuration

## 🏭 Production Deployment

1. **Security**: Update \`DJANGO_SECRET_KEY\` and other sensitive variables
2. **Database**: Configure production PostgreSQL 
3. **Static Files**: Set up proper static file serving
4. **HTTPS**: Enable SSL/TLS certificates
5. **Monitoring**: Add logging and monitoring tools

## 📝 Git Workflow

\`\`\`bash
# Initial commit
git add .
git commit -m "Initial project setup"

# Add remote and push
git remote add origin <your-repo-url>
git branch -M main  
git push -u origin main
\`\`\`

## 🤝 Contributing

1. Run tests: \`./scripts.sh test\`
2. Check code quality: \`./scripts.sh quality\`
3. Run security scans: \`./scripts.sh security\`
4. Commit changes with clear messages

## 📄 License

[MIT License](LICENSE) - see LICENSE file for details

---

**Virtual Environment**: $VENV_NAME  
**Created**: $(date)  
**Happy Coding!** 🚀
EOL

if $AI_GUARDRAILS; then
    print_status "Adding AI agent commit review gate (AGENTS.md, CLAUDE.md, .claude/settings.json)..."
    apply_ai_guardrails "$TEMPLATES_DIR" "$PWD" "$PROJECT_NAME"
fi

print_success "Enhanced project scaffold created successfully!"
print_status "🎉 Project: $PROJECT_NAME"
print_status "🐍 Virtual Environment: $VENV_NAME"
print_status ""
print_status "📋 Next steps:"
echo "1. cd $PROJECT_NAME"
echo "2. Edit .env file with your configuration"
echo "3. Run: ./start_dev.sh"
echo "4. Run tests: ./scripts.sh test"
echo "5. Run security scans: ./scripts.sh security"
echo "6. Access frontend: http://localhost:3000"
echo "7. Access backend: http://localhost:8000"

print_warning "🔒 Security reminders:"
echo "- Change DJANGO_SECRET_KEY in production"
echo "- Review and update all default passwords"
echo "- Run security scans regularly"
echo "- Keep dependencies updated"

print_warning "📝 Don't forget to:"
echo "- Initialize git: git init (already done)"
echo "- Add remote: git remote add origin <url>"
echo "- Make initial commit: git add . && git commit -m 'Initial setup'"
echo "- Regular security scanning"

print_success "🚀 Happy coding!"