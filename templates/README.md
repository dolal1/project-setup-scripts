# 📁 Templates Directory

This directory contains template files used by the setup scripts to generate consistent project structures.

## 🧩 Templates in use

These are rendered by `render_template` in `scripts/common/render.sh`, which replaces every
`{{KEY}}` with its value. Values may contain any characters, including `&`, `/` and newlines.

```text
templates/
├── ai-agents/                  # Commit review gate, added to every generated project
│   ├── AGENTS.md.template      # {{PROJECT_NAME}}, {{PROJECT_RULES}}
│   ├── CLAUDE.md.template
│   ├── claude-settings.json.template
│   └── propose-commit.sh.template
├── tiered-common/              # Shared by every tiered stack
│   ├── build-release.sh.template   # {{PROJECT_NAME}}, {{PREFIX_UPPER}}, {{TIERS}}
│   └── release.exclude.template
├── laravel-tiered/             # setup_laravel_tiered_project.sh
│   ├── app/ config/ database/ resources/ tests/   # core loader, permissions, components, tests
│   ├── module/                 # rendered once per tier above core into modules/<Tier>/
│   ├── github/workflows/ci.yml.template            # becomes .github/workflows/ci.yml
│   ├── scripts/release-stack.sh.template           # Laravel hooks for build-release.sh
│   └── README.md.template
├── django-tiered/              # setup_django_tiered_project.sh
│   ├── config/ core/ templates/                    # settings, loader, permissions, tags, tests
│   ├── module/                 # rendered once per tier above core into modules/<tier>/
│   ├── github/workflows/ci.yml.template
│   ├── scripts/release-stack.sh.template           # Django hooks for build-release.sh
│   └── requirements*.txt, pytest.ini, env.example, gitignore, README.md templates
└── node-tiered/                # setup_node_tiered_project.sh
    ├── src/ views/ test/       # loader, permissions, features, sessions, CSRF, CLIs, tests
    ├── module/                 # rendered once per tier above core into modules/<tier>/
    ├── github/workflows/ci.yml.template
    ├── scripts/release-stack.sh.template           # Node hooks for build-release.sh
    └── package.json, tsconfig.json, vitest.config.ts, env.example, gitignore, README.md templates
```

Laravel tiered placeholders: `{{PREFIX}}`, `{{PREFIX_UPPER}}`, `{{CORE_TIER}}`, `{{TOP_TIER}}`,
`{{TIERS_PHP}}`, `{{TIERS_JSON}}`, `{{LOWER_TIERS_JSON}}`, and per module `{{MODULE}}`,
`{{MODULE_TIER}}`, `{{MODULE_REQUIRES_PHP}}`, `{{MODULE_ORDER}}`. GitHub Actions expressions such
as `${{ matrix.tier }}` are left alone, because only the listed keys are replaced.

## 🏗️ Structure of the earlier templates

The Django + TypeScript script still writes most of its files inline; the templates below are
kept for moving it onto `render_template` later.

```text
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
