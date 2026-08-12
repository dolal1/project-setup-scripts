# Troubleshooting Guide

Common issues and solutions for setup scripts.

## 🔧 General Issues

### Script Permission Denied

```bash
# Make script executable
chmod +x scripts/setup_*.sh

# Or run with bash explicitly
bash scripts/setup_django_typescript_project.sh
```

### Missing Dependencies

#### Python Not Found

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3.11 python3.11-venv

# macOS
brew install python@3.11
```

#### Node.js Not Found

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew install node
```

#### Docker Not Found

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose
sudo usermod -aG docker $USER

# macOS
brew install docker
```

### Git Issues

#### Git Not Initialized

```bash
cd your-project
git init
git add .
git commit -m "Initial commit"
```

#### Permission Issues

```bash
# Configure git if not done
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 🐳 Docker Issues

> 💡 For disk space cleanup, safe pruning, and rebuilding without losing your database,
> see the [Docker Maintenance Guide](docker-maintenance.md).

### Docker Permission Denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Restart your shell session or run:
newgrp docker

# Test docker access
docker run hello-world
```

### Port Already in Use

```bash
# Find what's using the port
sudo lsof -i :3000
sudo lsof -i :8000
sudo lsof -i :5432

# Kill the process
sudo kill -9 <PID>

# Or change ports in docker-compose.yml
```

### Container Build Failures

```bash
# Clean Docker cache: stopped containers, unused networks, all unused images,
# and build cache. Prompts before deleting; add -f to skip the prompt.
# Volumes are untouched unless you add --volumes — so your database survives.
docker system prune -a

# Rebuild without cache
docker-compose build --no-cache

# Check logs for specific errors
docker-compose logs <service-name>
```

⚠️ Never add `--volumes` to `docker system prune`, and never run `docker volume prune -a`.
With containers stopped, every volume looks unused — including your database and every
other project's. See the "`LINKS 0` Trap" section of [Docker Maintenance](docker-maintenance.md).

### Volume Permission Issues

```bash
# On Linux, fix volume permissions
sudo chown -R $USER:$USER .

# Or rebuild containers with correct user
docker-compose down
docker-compose up --build
```

## 🐍 Python/Django Issues

### Virtual Environment Issues

#### Cannot Activate Virtual Environment

```bash
# Recreate virtual environment
rm -rf backend/*-venv
cd backend
python3 -m venv my-project-venv
source my-project-venv/bin/activate

# Install requirements
pip install -r requirements.txt
```

#### Python Version Issues

```bash
# Check Python version
python3 --version

# Install specific version (Ubuntu)
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11

# Create venv with specific version
python3.11 -m venv my-project-venv
```

### Django Database Issues

#### Migration Errors

```bash
cd backend
source *-venv/bin/activate

# Reset migrations
python manage.py migrate --fake-initial

# Or delete and recreate
rm -rf api/migrations/0*.py
rm -rf accounts/migrations/0*.py
python manage.py makemigrations
python manage.py migrate
```

#### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose ps

# Restart database
docker-compose restart postgres

# Check database logs
docker-compose logs postgres
```

### Package Installation Issues

#### Pip Install Failures

```bash
# Upgrade pip first
pip install --upgrade pip

# Install with verbose output
pip install -v -r requirements.txt

# Clear pip cache
pip cache purge
```

## ⚛️ Node.js/React Issues

### NPM Installation Issues

#### Permission Errors

```bash
# Fix npm permissions (Linux/macOS)
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'

# Add to ~/.bashrc or ~/.zshrc:
export PATH=~/.npm-global/bin:$PATH

# Or use node version manager
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install node
```

#### Package Installation Failures

```bash
# Clear npm cache
npm cache clean --force

# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install

# Try with different registry
npm install --registry https://registry.npmmirror.com/
```

### TypeScript Issues

#### Type Errors

```bash
# Update TypeScript
npm install -D typescript@latest

# Clear TypeScript cache
rm -rf node_modules/.cache

# Check TypeScript config
npx tsc --noEmit
```

### Vite Issues

#### Port 3000 Already in Use

```bash
# Kill process using port 3000
sudo lsof -i :3000
sudo kill -9 <PID>

# Or change port in vite.config.ts:
export default defineConfig({
  server: {
    port: 3001
  }
})
```

#### Build Issues

```bash
# Clear Vite cache
rm -rf node_modules/.vite

# Try building with more memory
NODE_OPTIONS="--max-old-space-size=4096" npm run build
```

## 🔒 Security Tool Issues

### Bandit Issues

```bash
# Install bandit in virtual environment
source backend/*-venv/bin/activate
pip install bandit[toml]

# Run with specific configuration
bandit -r . -f json -o bandit-report.json
```

### Trivy Issues

```bash
# Install trivy (Ubuntu)
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# macOS
brew install trivy
```

### TruffleHog Issues

```bash
# Install trufflehog
pip install trufflehog3

# Or download binary
wget https://github.com/trufflesecurity/trufflehog/releases/latest/download/trufflehog_linux_amd64.tar.gz
```

## 🧪 Testing Issues

### Pytest Issues

```bash
# Install pytest in virtual environment
source backend/*-venv/bin/activate
pip install pytest pytest-django pytest-cov

# Run with verbose output
pytest -v

# Clear pytest cache
pytest --cache-clear
```

### Frontend Test Issues

```bash
# Install test dependencies
npm install --save-dev @testing-library/react @testing-library/jest-dom vitest

# Run tests with debug info
npm run test -- --reporter=verbose

# Clear test cache
rm -rf node_modules/.cache
```

## 💾 Database Issues

### PostgreSQL Connection Issues

```bash
# Check if PostgreSQL container is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Connect to database manually
docker-compose exec postgres psql -U postgres -d your_database_name
```

### Redis Connection Issues

```bash
# Check Redis container
docker-compose ps redis

# Test Redis connection
docker-compose exec redis redis-cli ping

# Check Redis logs
docker-compose logs redis
```

## 🔄 Environment Issues

### Environment Variables Not Loading

```bash
# Check .env file exists and has correct format
cat .env

# Ensure no spaces around = in .env file
# Wrong: KEY = value
# Right: KEY=value

# Load environment manually
source .env
export $(cat .env | xargs)
```

### Path Issues

```bash
# Check if directories exist
ls -la backend/
ls -la frontend/

# Fix path permissions
chmod 755 backend/ frontend/
```

## 🚀 Performance Issues

### Slow Container Startup

```bash
# Check system resources
docker system df
docker system events

# Prune unused containers/images
docker system prune

# Reclaim orphaned anonymous volumes. Note: this compose file uses NAMED
# volumes throughout, so expect this to reclaim little or nothing here —
# images and build cache are where the space goes.
docker volume prune -f

# Use lighter base images in Dockerfiles
```

See [Docker Maintenance](docker-maintenance.md) for a full space audit.

### Memory Issues

```bash
# Increase Docker memory limit in Docker Desktop
# Or add swap space (Linux)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 📞 Getting More Help

### Debug Mode

```bash
# Run scripts with debug mode
bash -x scripts/setup_django_typescript_project.sh

# Enable Django debug mode
export DEBUG=True
```

### Log Collection

```bash
# Collect all logs
docker-compose logs > docker-logs.txt
npm run test > test-logs.txt 2>&1
pytest > pytest-logs.txt 2>&1
```

### Common Log Locations

- Docker logs: `docker-compose logs <service>`
- Django logs: `backend/logs/` (if configured)
- Node.js logs: Usually in terminal output
- System logs: `/var/log/` (Linux)

### Reporting Issues

When reporting issues, include:

1. Operating system and version
2. Python, Node.js, Docker versions
3. Full error message
4. Steps to reproduce
5. Relevant log files

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Django Documentation](https://docs.djangoproject.com/)
- [React Documentation](https://react.dev/)
- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- [Vite Documentation](https://vitejs.dev/)

---

Need more help? Create an issue in the GitHub repository with detailed information about your problem!
