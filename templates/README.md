# 📁 Templates Directory

This directory contains template files used by the setup scripts to generate consistent project structures.

## 🏗️ Structure

```
templates/
├── django/                     # Django-specific templates
│   ├── settings/
│   │   ├── base.py.template
│   │   ├── development.py.template
│   │   └── production.py.template
│   ├── models/
│   │   └── base_model.py.template
│   ├── views/
│   │   └── api_base.py.template
│   └── docker/
│       └── Dockerfile.django.template
├── react/                      # React/TypeScript templates
│   ├── components/
│   │   ├── App.tsx.template
│   │   └── Layout.tsx.template
│   ├── hooks/
│   │   └── useApi.ts.template
│   ├── config/
│   │   ├── vite.config.ts.template
│   │   └── tsconfig.json.template
│   └── docker/
│       └── Dockerfile.react.template
├── docker/                     # Docker templates
│   ├── docker-compose.yml.template
│   ├── docker-compose.prod.yml.template
│   └── .dockerignore.template
├── configs/                    # Configuration templates
│   ├── .env.template
│   ├── .gitignore.template
│   ├── .eslintrc.cjs.template
│   └── prettier.config.js.template
├── scripts/                    # Script templates
│   ├── start_dev.sh.template
│   ├── scripts.sh.template
│   └── deploy.sh.template
├── docs/                       # Documentation templates
│   ├── README.md.template
│   ├── API.md.template
│   └── CONTRIBUTING.md.template
└── github/                     # GitHub templates
    ├── workflows/
    │   ├── ci.yml.template
    │   └── cd.yml.template
    └── ISSUE_TEMPLATE/
        ├── bug_report.md.template
        └── feature_request.md.template
```

## 🎯 Template Usage

Templates use placeholder variables that get replaced by setup scripts:

- `{{PROJECT_NAME}}` - Project name
- `{{VENV_NAME}}` - Virtual environment name
- `{{AUTHOR_NAME}}` - Author/organization name
- `{{AUTHOR_EMAIL}}` - Author email
- `{{PROJECT_DESCRIPTION}}` - Project description
- `{{PYTHON_VERSION}}` - Python version
- `{{NODE_VERSION}}` - Node.js version

## 🔧 Adding New Templates

1. Create template file with `.template` extension
2. Use placeholder variables for dynamic content
3. Update setup scripts to process the template
4. Test with different configurations