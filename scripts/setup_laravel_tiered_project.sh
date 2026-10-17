#!/bin/bash

# Setup Laravel Tiered Project
# Creates a Laravel 12 app sold in tiers, where every tier above core is a removable module:
# a module loader, Pennant feature switches, role permissions with <x-can>, an arch test,
# sample tier modules, a tier-matrix CI workflow and a release builder that strips unbought
# tiers. The contract is in docs/tiered-modules.md.
#
#   setup_laravel_tiered_project.sh my-app --prefix myapp --tiers basic,standard,premium
#   setup_laravel_tiered_project.sh . --prefix salon --into-existing   # inside a docs-first repo
#
# Set LARAVEL_PHP_PLATFORM (default 8.2.0) to the lowest PHP the client's host runs; Composer
# then locks dependency versions that work there.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
LT="$TEMPLATES_DIR/laravel-tiered"
# shellcheck source=SCRIPTDIR/common/render.sh
source "$SCRIPT_DIR/common/render.sh"
# shellcheck source=SCRIPTDIR/common/ai-guardrails.sh
source "$SCRIPT_DIR/common/ai-guardrails.sh"
# shellcheck source=SCRIPTDIR/common/tiered.sh
source "$SCRIPT_DIR/common/tiered.sh"

PHP_PLATFORM="${LARAVEL_PHP_PLATFORM:-8.2.0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

trap 'print_error "Script failed on line $LINENO"' ERR

check_dependencies() {
    local missing=()
    command -v php > /dev/null || missing+=("php")
    command -v composer > /dev/null || missing+=("composer")
    command -v git > /dev/null || missing+=("git")
    if (( ${#missing[@]} )); then
        print_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
    if ! php -r 'exit(version_compare(PHP_VERSION, "8.2.0", ">=") ? 0 : 1);'; then
        print_error "PHP 8.2 or newer is required (found $(php -r 'echo PHP_VERSION;'))."
        exit 1
    fi
    if ! php -m | grep -qi '^pdo_sqlite$'; then
        print_warning "PHP has no pdo_sqlite extension. The app's tests use SQLite in memory and"
        print_warning "won't run locally until it's installed (e.g. sudo apt install php-sqlite3)."
    fi
}

# php_insert <file> <anchor> <text> [before|after]: inserts text next to the first occurrence of
# anchor, failing loudly if the Laravel skeleton no longer contains it.
php_insert() {
    # shellcheck disable=SC2016  # PHP code: the $ variables are PHP's
    php -r '
        [, $file, $anchor, $text, $where] = $argv;
        $source = file_get_contents($file);
        $at = strpos($source, $anchor);
        if ($at === false) {
            fwrite(STDERR, "Could not find the expected code in $file; the Laravel skeleton may have changed.\n");
            exit(1);
        }
        $at = $where === "before" ? $at : $at + strlen($anchor);
        file_put_contents($file, substr_replace($source, $text, $at, 0));
    ' -- "$1" "$2" "$3" "${4:-after}"
}

# Joins arguments as a PHP list body: 'a', 'b'
php_list() {
    local out="" item
    for item in "$@"; do
        out+="${out:+, }'$item'"
    done
    printf '%s' "$out"
}

lt() {
    render_template "$LT/$1.template" "$2" "${VARS[@]}"
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
    local php_version="${PHP_PLATFORM%.*}"

    VARS=(
        "PROJECT_NAME=$PROJECT_NAME" "PREFIX=$PREFIX" "PREFIX_UPPER=$prefix_upper"
        "CORE_TIER=$core" "CORE_TIER_LABEL=$(studly "$core")" "TOP_TIER=$top"
        "TIERS_PHP=$(php_list "${TIERS[@]}")" "TIERS_JSON=$(tiers_json)" "LOWER_TIERS_JSON=$(tiers_json "${lower[@]}")"
        "TIERS_SPACED=${TIERS[*]}" "TIERS_LABEL=${labels_joined//,/, }"
        "PHP_VERSION=$php_version"
    )

    local app
    if $INTO_EXISTING; then
        app="$(mktemp -d)/app"
    else
        app="$TARGET_DIR"
    fi

    print_status "Creating Laravel 12 app for $PROJECT_NAME (tiers: ${TIERS[*]}, setting ${prefix_upper}_TIER)"
    composer create-project laravel/laravel:^12.0 "$app" --no-interaction --prefer-dist --no-progress
    cd "$app"

    print_status "Locking dependencies for PHP $PHP_PLATFORM and adding Laravel Pennant..."
    composer config platform.php "$PHP_PLATFORM"
    composer require laravel/pennant:^1.0 --no-update
    composer update --no-interaction --no-progress
    php artisan vendor:publish --provider="Laravel\\Pennant\\PennantServiceProvider" --no-interaction

    print_status "Adding the tier module loader, permissions and components..."
    # shellcheck disable=SC2016  # PHP code: the $ variables are PHP's
    php -r '
        $composer = json_decode(file_get_contents("composer.json"), true);
        $composer["autoload"]["psr-4"]["Modules\\"] = "modules/";
        file_put_contents("composer.json", json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)."\n");
    '

    local file
    for file in \
        app/Support/Modules.php app/Support/Menu.php \
        app/Support/Permissions/PermissionContract.php app/Support/Permissions/RegistersPermissions.php \
        app/Enums/Role.php app/Enums/Permission.php app/Providers/ModulesServiceProvider.php \
        app/View/Components/Can.php app/View/Components/Menu.php \
        resources/views/components/can.blade.php resources/views/components/menu.blade.php \
        app/Console/Commands/FeatureCommand.php \
        database/migrations/0001_01_01_000003_add_role_to_users_table.php \
        tests/Feature/ArchTest.php tests/Feature/PermissionsTest.php tests/Unit/ModulesTest.php \
        scripts/release-stack.sh; do
        lt "$file" "$file"
    done
    lt config/tier.php "config/$PREFIX.php"
    lt github/workflows/ci.yml .github/workflows/ci.yml
    chmod +x scripts/release-stack.sh

    php_insert bootstrap/providers.php "use App\\Providers\\AppServiceProvider;" $'\nuse App\\Providers\\ModulesServiceProvider;'
    php_insert bootstrap/providers.php "    AppServiceProvider::class," $'\n    ModulesServiceProvider::class,'
    php_insert app/Models/User.php "use Database\\Factories\\UserFactory;" $'use App\\Enums\\Role;\n' before
    php_insert app/Models/User.php "        'email'," $'\n        \'role\','
    php_insert app/Models/User.php "            'password' => 'hashed',"  $'\n            \'role\' => Role::class,'
    php_insert phpunit.xml "    </testsuites>" \
        $'        <testsuite name="Modules">\n            <directory>modules/*/Tests</directory>\n        </testsuite>\n' before
    php_insert phpunit.xml '        <env name="MAIL_MAILER"' $'        <env name="PENNANT_STORE" value="array"/>\n' before

    local env_file
    for env_file in .env.example .env; do
        [[ -f "$env_file" ]] && printf '\n# Active tier: %s\n%s_TIER=%s\n' "${TIERS[*]}" "$prefix_upper" "$top" >> "$env_file"
    done

    print_status "Adding sample modules for ${TIERS[*]:1}..."
    local i module requires
    for (( i = 1; i < ${#TIERS[@]}; i++ )); do
        module="$(studly "${TIERS[$i]}")"
        requires=""
        (( i > 1 )) && requires="'${TIERS[$i-1]}'"
        local mvars=("${VARS[@]}" "MODULE=$module" "MODULE_TIER=${TIERS[$i]}"
            "MODULE_REQUIRES_PHP=$requires" "MODULE_ORDER=$(( i * 100 ))")
        local m="$LT/module" dest="modules/$module"
        render_template "$m/module.php.template" "$dest/module.php" "${mvars[@]}"
        render_template "$m/ServiceProvider.php.template" "$dest/${module}ServiceProvider.php" "${mvars[@]}"
        render_template "$m/Permission.php.template" "$dest/Permission.php" "${mvars[@]}"
        render_template "$m/routes/web.php.template" "$dest/routes/web.php" "${mvars[@]}"
        render_template "$m/resources/views/example.blade.php.template" "$dest/resources/views/example.blade.php" "${mvars[@]}"
        render_template "$m/database/migrations/create_examples_table.php.template" \
            "$dest/database/migrations/2026_01_01_$(printf '%06d' "$i")_create_${TIERS[$i]}_examples_table.php" "${mvars[@]}"
        render_template "$m/Tests/ExampleTest.php.template" "$dest/Tests/ExampleTest.php" "${mvars[@]}"
    done

    composer dump-autoload --no-interaction > /dev/null

    apply_tiered_common "$TEMPLATES_DIR" "$PWD"

    if $AI_GUARDRAILS; then
        print_status "Adding AI agent commit review gate (AGENTS.md, CLAUDE.md, .claude/settings.json)..."
        apply_ai_guardrails "$TEMPLATES_DIR" "$PWD" "$PROJECT_NAME" "$(cat <<EOF
- The tier setting is \`${prefix_upper}_TIER\` (\`config('$PREFIX.tier')\`); tiers, lowest first: ${TIERS[*]}.
- Core (\`app/\`, \`config/\`, \`database/\`, \`resources/\`, \`routes/\`, \`tests/\`) never references
  \`Modules\\\` or a module's view namespace. \`tests/Feature/ArchTest.php\` enforces it. Modules plug
  into core through hooks in \`app/Support/\` (add a hook there rather than calling a module).
- Work for a tier above $core goes in \`modules/<Tier>/\`: its routes, views, migrations, Pennant
  features, \`Permission\` enum and \`Tests/\`.
- Before proposing a commit, run the suite at every tier:
  \`for t in ${TIERS[*]}; do ${prefix_upper}_TIER=\$t php artisan test || break; done\`
- \`scripts/build-release.sh\` produces what a client receives. Run it only when the human asks.
EOF
)"
    fi

    if $INTO_EXISTING; then
        print_status "Moving the app into $TARGET_DIR (existing files are kept)..."
        local built="$PWD"
        cd - > /dev/null
        move_into_existing "$built" "$TARGET_DIR"
        rm -rf "$(dirname "$built")"
        cd "$TARGET_DIR"
    else
        lt README.md README.md
        git init -q
    fi
    # Local planning notes and release records never go into git
    grep -qx '/notes/' .git/info/exclude 2> /dev/null || echo "/notes/" >> "$(git rev-parse --git-path info/exclude)"

    print_success "Created $PROJECT_NAME with tiers: ${TIERS[*]}"
    echo
    echo "Next steps:"
    echo "  cd $TARGET_DIR"
    echo "  php artisan migrate"
    echo "  for t in ${TIERS[*]}; do ${prefix_upper}_TIER=\$t php artisan test || break; done"
    echo "  Review the files, then make the first commit (nothing has been committed)."
}

main "$@"
