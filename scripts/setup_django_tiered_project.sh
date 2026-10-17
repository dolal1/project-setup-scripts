#!/bin/bash

# Setup Django Tiered Project
# Creates a server-rendered Django 5.2 app sold in tiers, where every tier above core is a
# removable Django app: a module loader driven by one setting, django-waffle feature switches,
# role permissions with a {% can %} template tag, an arch test, sample tier modules, a
# tier-matrix CI workflow and a release builder that strips unbought tiers. The contract is in
# docs/tiered-modules.md.
#
#   setup_django_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
#   setup_django_tiered_project.sh . --prefix salon --into-existing   # inside a docs-first repo
#
# Set DJANGO_PYTHON_VERSION (default 3.12) for the Python version CI uses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
DT="$TEMPLATES_DIR/django-tiered"
# shellcheck source=SCRIPTDIR/common/render.sh
source "$SCRIPT_DIR/common/render.sh"
# shellcheck source=SCRIPTDIR/common/ai-guardrails.sh
source "$SCRIPT_DIR/common/ai-guardrails.sh"
# shellcheck source=SCRIPTDIR/common/tiered.sh
source "$SCRIPT_DIR/common/tiered.sh"

PYTHON_VERSION="${DJANGO_PYTHON_VERSION:-3.12}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

trap 'print_error "Script failed on line $LINENO"' ERR

check_dependencies() {
    local missing=()
    command -v python3 > /dev/null || missing+=("python3")
    command -v git > /dev/null || missing+=("git")
    if (( ${#missing[@]} )); then
        print_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
    if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'; then
        print_error "Python 3.10 or newer is required (found $(python3 --version))."
        exit 1
    fi
    if ! python3 -c 'import venv, sqlite3' 2> /dev/null; then
        print_error "Python's venv and sqlite3 modules are required (e.g. sudo apt install python3-venv)."
        exit 1
    fi
}

# Joins arguments as a Python list body: "a", "b"
py_list() {
    local out="" item
    for item in "$@"; do
        out+="${out:+, }\"$item\""
    done
    printf '%s' "$out"
}

dt() {
    render_template "$DT/$1.template" "$2" "${VARS[@]}"
}

main() {
    print_status "Checking dependencies..."
    check_dependencies
    parse_tiered_args "$@"

    local prefix_upper="${PREFIX^^}" core="${TIERS[0]}" top="${TIERS[-1]}"
    local lower=("${TIERS[@]:0:${#TIERS[@]}-1}") labels=() tier
    for tier in "${TIERS[@]}"; do labels+=("$(studly "$tier")"); done
    local labels_joined
    labels_joined="$(IFS=,; echo "${labels[*]}")"

    VARS=(
        "PROJECT_NAME=$PROJECT_NAME" "PREFIX=$PREFIX" "PREFIX_UPPER=$prefix_upper"
        "CORE_TIER=$core" "CORE_TIER_LABEL=$(studly "$core")" "TOP_TIER=$top"
        "TIERS_PY=$(py_list "${TIERS[@]}")" "TIERS_JSON=$(tiers_json)" "LOWER_TIERS_JSON=$(tiers_json "${lower[@]}")"
        "TIERS_SPACED=${TIERS[*]}" "TIERS_LABEL=${labels_joined//,/, }" "PYTHON_VERSION=$PYTHON_VERSION"
        "DEV_SECRET_KEY=django-insecure-$(python3 -c 'import secrets; print(secrets.token_urlsafe(40))')"
    )

    local app
    if $INTO_EXISTING; then
        app="$(mktemp -d)/app"
    else
        app="$TARGET_DIR"
    fi
    mkdir -p "$app"
    cd "$app"

    print_status "Creating Django app for $PROJECT_NAME (tiers: ${TIERS[*]}, setting ${prefix_upper}_TIER)"
    local file
    for file in \
        manage.py config/env.py config/settings.py config/urls.py config/wsgi.py \
        core/apps.py core/models.py core/admin.py core/permissions.py core/features.py core/menu.py \
        core/modules.py core/views.py core/urls.py core/templatetags/tiers.py \
        core/tests/test_arch.py core/tests/test_modules.py core/tests/test_permissions.py \
        templates/base.html templates/core/home.html \
        requirements.txt requirements-dev.txt pytest.ini scripts/release-stack.sh; do
        dt "$file" "$file"
    done
    dt core/management/commands/feature.py "core/management/commands/${PREFIX}_feature.py"
    dt env.example .env.example
    dt gitignore .gitignore
    dt github/workflows/ci.yml .github/workflows/ci.yml
    mkdir -p modules core/migrations
    touch config/__init__.py core/__init__.py core/templatetags/__init__.py core/tests/__init__.py \
        core/management/__init__.py core/management/commands/__init__.py core/migrations/__init__.py \
        modules/__init__.py
    chmod +x manage.py scripts/release-stack.sh

    print_status "Adding sample modules for ${TIERS[*]:1}..."
    local i module requires dest
    for (( i = 1; i < ${#TIERS[@]}; i++ )); do
        module="$(studly "${TIERS[$i]}")"
        requires=""
        (( i > 1 )) && requires="\"${TIERS[$i-1]}\""
        local mvars=("${VARS[@]}" "MODULE=$module" "MODULE_TIER=${TIERS[$i]}"
            "MODULE_REQUIRES_PY=$requires" "MODULE_ORDER=$(( i * 100 ))")
        dest="modules/${TIERS[$i]}"
        for file in module.py apps.py permissions.py models.py views.py urls.py tests/test_example.py; do
            render_template "$DT/module/$file.template" "$dest/$file" "${mvars[@]}"
        done
        render_template "$DT/module/templates/example.html.template" \
            "$dest/templates/${TIERS[$i]}/example.html" "${mvars[@]}"
        touch "$dest/__init__.py" "$dest/tests/__init__.py"
        mkdir -p "$dest/migrations" && touch "$dest/migrations/__init__.py"
    done

    print_status "Installing Django in .venv and generating migrations..."
    python3 -m venv .venv
    .venv/bin/pip install --quiet --disable-pip-version-check -r requirements-dev.txt
    # Every app is installed at the top tier, so every app gets its migration
    env "${prefix_upper}_TIER=$top" .venv/bin/python manage.py makemigrations core "${TIERS[@]:1}" --no-input > /dev/null

    apply_tiered_common "$TEMPLATES_DIR" "$PWD"

    if $AI_GUARDRAILS; then
        print_status "Adding AI agent commit review gate (AGENTS.md, CLAUDE.md, .claude/settings.json)..."
        apply_ai_guardrails "$TEMPLATES_DIR" "$PWD" "$PROJECT_NAME" "$(cat <<EOF
- The tier setting is \`${prefix_upper}_TIER\` (\`settings.${prefix_upper}_TIER\`); tiers, lowest first: ${TIERS[*]}.
- Core (\`config/\`, \`core/\`, \`templates/\`) never imports from \`modules\` or uses a module's URL
  namespace or template folder. \`core/tests/test_arch.py\` enforces it. Modules plug into core
  through hooks in \`core/\` (\`core.menu\`, \`core.permissions\`, \`core.features\`); add a hook there
  rather than calling a module.
- Work for a tier above $core goes in \`modules/<tier>/\`: its models, migrations, URLs, templates,
  switches (\`features.define\`), \`Permission\` enum and \`tests/\`. Wire it in the module's \`apps.py\`.
- Run \`makemigrations\` with the top tier active: \`${prefix_upper}_TIER=$top python manage.py makemigrations\`.
- Before proposing a commit, run the suite at every tier:
  \`for t in ${TIERS[*]}; do ${prefix_upper}_TIER=\$t .venv/bin/pytest -q || break; done\`
- \`scripts/build-release.sh\` produces what a client receives. Run it only when the human asks.
EOF
)"
    fi

    if $INTO_EXISTING; then
        print_status "Moving the app into $TARGET_DIR (existing files are kept)..."
        local built="$PWD"
        cd - > /dev/null
        rm -rf "$built/.venv"
        move_into_existing "$built" "$TARGET_DIR"
        rm -rf "$(dirname "$built")"
        cd "$TARGET_DIR"
        python3 -m venv .venv
        .venv/bin/pip install --quiet --disable-pip-version-check -r requirements-dev.txt
    else
        dt README.md README.md
        git init -q
    fi
    # Local planning notes and release records never go into git
    grep -qx '/notes/' "$(git rev-parse --absolute-git-dir)/info/exclude" 2> /dev/null \
        || echo "/notes/" >> "$(git rev-parse --absolute-git-dir)/info/exclude"

    print_success "Created $PROJECT_NAME with tiers: ${TIERS[*]}"
    echo
    echo "Next steps:"
    echo "  cd $TARGET_DIR && . .venv/bin/activate"
    echo "  cp .env.example .env && python manage.py migrate && python manage.py createsuperuser"
    echo "  for t in ${TIERS[*]}; do ${prefix_upper}_TIER=\$t pytest -q || break; done"
    echo "  Review the files, then make the first commit (nothing has been committed)."
}

main "$@"
