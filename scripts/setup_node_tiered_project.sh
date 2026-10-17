#!/bin/bash

# Setup Node Tiered Project
# Creates a server-rendered Node.js app (Express 5, TypeScript, EJS, Knex) sold in tiers, where
# every tier above core is a removable module: a module loader driven by one setting, feature
# switches, role permissions with a can() view helper, database sessions and CSRF, an arch test,
# sample tier modules, a tier-matrix CI workflow and a release builder that strips unbought
# tiers. The contract is in docs/tiered-modules.md.
#
#   setup_node_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
#   setup_node_tiered_project.sh . --prefix salon --into-existing   # inside a docs-first repo
#
# Set NODE_CI_VERSION (default 22) for the Node.js version the generated CI uses.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
NT="$TEMPLATES_DIR/node-tiered"
# shellcheck source=SCRIPTDIR/common/render.sh
source "$SCRIPT_DIR/common/render.sh"
# shellcheck source=SCRIPTDIR/common/ai-guardrails.sh
source "$SCRIPT_DIR/common/ai-guardrails.sh"
# shellcheck source=SCRIPTDIR/common/tiered.sh
source "$SCRIPT_DIR/common/tiered.sh"

NODE_VERSION="${NODE_CI_VERSION:-22}"

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
    command -v node > /dev/null || missing+=("node")
    command -v npm > /dev/null || missing+=("npm")
    command -v git > /dev/null || missing+=("git")
    if (( ${#missing[@]} )); then
        print_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
    if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)'; then
        print_error "Node.js 22 or newer is required (found $(node --version))."
        exit 1
    fi
}

# Joins arguments as a JSON/TypeScript list body: "a", "b"
quoted_list() {
    local out="" item
    for item in "$@"; do
        out+="${out:+, }\"$item\""
    done
    printf '%s' "$out"
}

nt() {
    render_template "$NT/$1.template" "$2" "${VARS[@]}"
}

main() {
    print_status "Checking dependencies..."
    check_dependencies
    parse_tiered_args "$@"

    local prefix_upper="${PREFIX^^}" core="${TIERS[0]}" top="${TIERS[-1]}"
    local lower=("${TIERS[@]:0:${#TIERS[@]}-1}") labels=() tier
    for tier in "${TIERS[@]}"; do labels+=("$(studly "$tier")"); done
    local labels_joined package_name
    labels_joined="$(IFS=,; echo "${labels[*]}")"
    # npm package names are lowercase; "." means the current directory's name
    package_name="$(basename "$TARGET_DIR")"
    [[ "$package_name" == "." ]] && package_name="$(basename "$PWD")"
    package_name="$(printf '%s' "$package_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-')"

    VARS=(
        "PROJECT_NAME=$PROJECT_NAME" "PACKAGE_NAME=$package_name" "PREFIX=$PREFIX" "PREFIX_UPPER=$prefix_upper"
        "CORE_TIER=$core" "CORE_TIER_LABEL=$(studly "$core")" "TOP_TIER=$top"
        "TIERS_TS=$(quoted_list "${TIERS[@]}")" "TIERS_JSON=$(tiers_json)" "LOWER_TIERS_JSON=$(tiers_json "${lower[@]}")"
        "TIERS_SPACED=${TIERS[*]}" "TIERS_LABEL=${labels_joined//,/, }" "NODE_VERSION=$NODE_VERSION"
        "DEV_SESSION_SECRET=dev-only-$(node -e 'console.log(require("node:crypto").randomBytes(24).toString("hex"))')"
    )

    local app
    if $INTO_EXISTING; then
        app="$(mktemp -d)/app"
    else
        app="$TARGET_DIR"
    fi
    mkdir -p "$app"
    cd "$app"

    print_status "Creating Node.js app for $PROJECT_NAME (tiers: ${TIERS[*]}, setting ${prefix_upper}_TIER)"
    local file
    for file in \
        package.json tsconfig.json vitest.config.ts \
        src/config/paths.ts src/config/env.ts src/app.ts src/server.ts src/migrations/core.ts \
        src/support/modules.ts src/support/db.ts src/support/features.ts src/support/permissions.ts \
        src/support/menu.ts src/support/auth.ts src/support/csrf.ts src/support/session-store.ts \
        src/cli/migrate.ts src/cli/feature.ts src/cli/create-user.ts \
        views/home.ejs views/login.ejs views/partials/header.ejs views/partials/footer.ejs \
        views/partials/menu.ejs views/partials/upgrade-hint.ejs \
        test/helpers.ts test/arch.test.ts test/modules.test.ts test/permissions.test.ts \
        scripts/release-stack.sh; do
        nt "$file" "$file"
    done
    nt env.example .env.example
    nt gitignore .gitignore
    nt github/workflows/ci.yml .github/workflows/ci.yml
    chmod +x scripts/release-stack.sh

    print_status "Adding sample modules for ${TIERS[*]:1}..."
    local i module requires dest
    for (( i = 1; i < ${#TIERS[@]}; i++ )); do
        module="$(studly "${TIERS[$i]}")"
        requires=""
        (( i > 1 )) && requires="\"${TIERS[$i-1]}\""
        local mvars=("${VARS[@]}" "MODULE=$module" "MODULE_TIER=${TIERS[$i]}"
            "MODULE_REQUIRES_JSON=$requires" "MODULE_ORDER=$(( i * 100 ))"
            "MODULE_MIGRATION_PREFIX=$(printf '%04d' "$(( i * 100 ))")")
        dest="modules/${TIERS[$i]}"
        for file in module.json src/index.ts src/routes.ts src/migrations.ts test/example.test.ts; do
            render_template "$NT/module/$file.template" "$dest/$file" "${mvars[@]}"
        done
        render_template "$NT/module/views/example.ejs.template" "$dest/views/${TIERS[$i]}/example.ejs" "${mvars[@]}"
    done

    print_status "Installing dependencies..."
    npm install --no-audit --no-fund --save express@^5 ejs express-session helmet knex better-sqlite3 mysql2 > /dev/null
    npm install --no-audit --no-fund --save-dev typescript tsx vitest supertest \
        @types/node@^22 @types/express @types/express-session @types/supertest > /dev/null
    npm run --silent typecheck

    apply_tiered_common "$TEMPLATES_DIR" "$PWD"

    if $AI_GUARDRAILS; then
        print_status "Adding AI agent commit review gate (AGENTS.md, CLAUDE.md, .claude/settings.json)..."
        apply_ai_guardrails "$TEMPLATES_DIR" "$PWD" "$PROJECT_NAME" "$(cat <<EOF
- The tier setting is \`${prefix_upper}_TIER\` (\`config.tier\` in \`src/config/env.ts\`); tiers, lowest first: ${TIERS[*]}.
- Core (\`src/\`, \`views/\`, \`test/\`) never imports from \`modules/\` or renders a module's views.
  \`test/arch.test.ts\` enforces it. Modules plug into core through the \`ModuleContext\` hooks
  (router, features, permissions, menu); add a hook there rather than calling a module.
- Work for a tier above $core goes in \`modules/<tier>/\`: \`src/index.ts\` (\`register()\` and
  \`migrations\`), routes, \`views/<tier>/\` and \`test/\`.
- Before proposing a commit, run the typecheck and the suite at every tier:
  \`npm run typecheck && for t in ${TIERS[*]}; do ${prefix_upper}_TIER=\$t npm test || break; done\`
- \`scripts/build-release.sh\` produces what a client receives. Run it only when the human asks.
EOF
)"
    fi

    if $INTO_EXISTING; then
        print_status "Moving the app into $TARGET_DIR (existing files are kept)..."
        local built="$PWD"
        cd - > /dev/null
        rm -rf "$built/node_modules"
        move_into_existing "$built" "$TARGET_DIR"
        rm -rf "$(dirname "$built")"
        cd "$TARGET_DIR"
        npm ci --no-audit --no-fund > /dev/null
    else
        nt README.md README.md
        git init -q
    fi
    # Local planning notes and release records never go into git
    grep -qx '/notes/' "$(git rev-parse --absolute-git-dir)/info/exclude" 2> /dev/null \
        || echo "/notes/" >> "$(git rev-parse --absolute-git-dir)/info/exclude"

    print_success "Created $PROJECT_NAME with tiers: ${TIERS[*]}"
    echo
    echo "Next steps:"
    echo "  cd $TARGET_DIR"
    echo "  npm run migrate && npm run create-user -- admin admin && npm run dev"
    echo "  for t in ${TIERS[*]}; do ${prefix_upper}_TIER=\$t npm test || break; done"
    echo "  Review the files, then make the first commit (nothing has been committed)."
}

main "$@"
