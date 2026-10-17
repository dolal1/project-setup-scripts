#!/bin/bash

# Tests the stack-neutral tier helpers (scripts/common/tiered.sh) and the release builder
# (templates/tiered-common/build-release.sh.template) against a stub stack, so the contract
# is proven before any framework is involved.

# "A && B || fail" is intended throughout: fail exits.
# shellcheck disable=SC2015

set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$TESTS_DIR/.."
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# The release builder commits into a fresh repo; CI runners have no git identity
export GIT_AUTHOR_NAME="Test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test" GIT_COMMITTER_EMAIL="test@example.com"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# shellcheck source=SCRIPTDIR/../scripts/common/render.sh
source "$REPO_DIR/scripts/common/render.sh"
# shellcheck source=SCRIPTDIR/../scripts/common/tiered.sh
source "$REPO_DIR/scripts/common/tiered.sh"

# --- prefix and tier validation -------------------------------------------------------
validate_prefix salon 2> /dev/null || fail "salon should be a valid prefix"
validate_prefix tms 2> /dev/null || fail "tms should be a valid prefix"
for bad in tenant app Salon s 1abc way-too-long-prefix-x; do
    if validate_prefix "$bad" 2> /dev/null; then fail "prefix '$bad' should be rejected"; fi
done
pass "validate_prefix accepts project prefixes and rejects reserved or malformed ones"

for bad in basic "basic,basic" "basic,Standard" "basic,,premium"; do
    if parse_tiers "$bad" 2> /dev/null; then fail "tiers '$bad' should be rejected"; fi
done
parse_tiers "basic,standard,premium" || fail "basic,standard,premium should parse"
[ "${TIERS[*]}" = "basic standard premium" ] || fail "TIERS wrong: ${TIERS[*]}"
[ "$(tiers_json)" = '["basic", "standard", "premium"]' ] || fail "tiers_json wrong: $(tiers_json)"
[ "$(studly premium)" = "Premium" ] || fail "studly wrong"
pass "parse_tiers, tiers_json and studly"

parse_tiered_args "$WORK_DIR/new-app" --prefix demo --tiers=basic,pro --name "Demo App" < /dev/null \
    || fail "parse_tiered_args rejected valid flags"
[ "$PREFIX" = demo ] && [ "${TIERS[*]}" = "basic pro" ] && [ "$PROJECT_NAME" = "Demo App" ] \
    && ! $INTO_EXISTING && $AI_GUARDRAILS || fail "parse_tiered_args set the wrong values"
mkdir -p "$WORK_DIR/full" && touch "$WORK_DIR/full/x"
if parse_tiered_args "$WORK_DIR/full" --prefix demo < /dev/null 2> /dev/null; then
    fail "a non-empty directory without --into-existing should be rejected"
fi
if parse_tiered_args "$WORK_DIR/full" --prefix demo --into-existing < /dev/null 2> /dev/null; then
    fail "--into-existing on a non-repo should be rejected"
fi
parse_tiered_args < <(printf 'proj\ndemo\n\n') > /dev/null 2>&1 || fail "prompted input rejected"
[ "$TARGET_DIR" = proj ] && [ "${TIERS[*]}" = "basic standard premium" ] || fail "prompt defaults wrong"
pass "parse_tiered_args handles flags, prompts and directory checks"

# --- moving a built app into an existing docs-first repo ------------------------------
existing="$WORK_DIR/existing" built="$WORK_DIR/built"
mkdir -p "$existing/docs" "$built/docs" "$built/app"
git -C "$existing" init -q
printf '# Client README\n' > "$existing/README.md"
printf 'plan\n' > "$existing/docs/00-plan.md"
printf '/notes/\n.env\n' > "$existing/.gitignore"
printf '# Framework README\n' > "$built/README.md"
printf 'framework docs\n' > "$built/docs/00-plan.md"
printf 'new\n' > "$built/docs/framework.md"
printf 'code\n' > "$built/app/core.txt"
printf '.env\n/vendor/\n' > "$built/.gitignore"
printf '# Planning\n\n## Project rules\n\n- Planning rule\n' > "$existing/AGENTS.md"
printf '# App\n\n## Commit review gate\n\n- gate\n\n## Project rules\n\n- App rule\n' > "$built/AGENTS.md"
move_into_existing "$built" "$existing" 2> /dev/null
grep -q -- '- Planning rule' "$existing/AGENTS.md" && grep -q '^## App rules$' "$existing/AGENTS.md" \
    && grep -q -- '- App rule' "$existing/AGENTS.md" || fail "AGENTS.md rules not merged"
[ "$(grep -c '^## Commit review gate$' "$existing/AGENTS.md")" = 0 ] || fail "AGENTS.md merge duplicated the gate section"
grep -q 'Client README' "$existing/README.md" || fail "existing README was overwritten"
grep -q '^plan$' "$existing/docs/00-plan.md" || fail "existing doc was overwritten"
[ -f "$existing/docs/framework.md" ] && [ -f "$existing/app/core.txt" ] || fail "new files not moved in"
[ "$(grep -cx '.env' "$existing/.gitignore")" = 1 ] && grep -qx '/vendor/' "$existing/.gitignore" \
    || fail ".gitignore not merged correctly"
pass "move_into_existing keeps existing files and merges .gitignore"

# --- release builder against a stub stack ---------------------------------------------
project="$WORK_DIR/demo-ms"
mkdir -p "$project/app" "$project/modules/standard" "$project/modules/premium" "$project/docs" "$project/notes"
cd "$project"
git init -q
echo "/notes/" >> .git/info/exclude
PROJECT_NAME="Demo M.S" PREFIX=demo
parse_tiers "basic,standard,premium"
apply_tiered_common "$REPO_DIR/templates" "$project"
cat > scripts/release-stack.sh <<'EOF'
stack_module_dir() { echo "modules/$1"; }
stack_leak_patterns() { echo "Modules\\\\${1^}\\\\"; }
stack_install_dev() { touch .installed; }
# The stripped build's own test: only the bought tiers are present
stack_test() { [ -d modules/standard ] && [ ! -d modules/premium ] && [ "$DEMO_TIER" = standard ]; }
stack_install_prod() { rm -f .installed; }
EOF
printf 'core\n' > app/core.txt
printf 'namespace Modules\\Standard\\;\n' > modules/standard/Feature.php
printf 'namespace Modules\\Premium\\;\n' > modules/premium/Feature.php
printf 'pricing\n' > docs/06-tiers.md
printf 'APP_NAME=demo\nDEMO_TIER=premium\n' > .env.example
git add -A && git commit -qm "dev repo"

RELEASE_OUT="$WORK_DIR/out" scripts/build-release.sh standard 1.2.0 > "$WORK_DIR/release.log" 2>&1 \
    || { cat "$WORK_DIR/release.log"; fail "build-release.sh standard failed"; }
zip="$WORK_DIR/out/demo-ms-1.2.0-standard.zip"
[ -f "$zip" ] || fail "release zip not created"
mkdir "$WORK_DIR/unzipped" && (cd "$WORK_DIR/unzipped" && unzip -q "$zip")
rel="$WORK_DIR/unzipped/demo-ms-1.2.0-standard"
[ -f "$rel/app/core.txt" ] && [ -d "$rel/modules/standard" ] || fail "bought tiers missing from release"
[ ! -e "$rel/modules/premium" ] || fail "premium module shipped"
for internal in docs AGENTS.md scripts/build-release.sh scripts/release-stack.sh release.exclude; do
    [ ! -e "$rel/$internal" ] || fail "internal path shipped: $internal"
done
grep -qx 'DEMO_TIER=standard' "$rel/.env.example" || fail ".env.example tier not set"
[ "$(git -C "$rel" rev-list --count HEAD)" = 1 ] || fail "client repo should have exactly one commit"
[ "$(git -C "$rel" log -1 --format=%s)" = "Demo M.S v1.2.0 (Standard)" ] || fail "client commit message wrong"
grep -q '| 1.2.0 | Standard |' notes/releases.md || fail "release not recorded in notes/releases.md"
grep -q "$(sha256sum "$zip" | cut -d' ' -f1)" notes/releases.md || fail "recorded SHA-256 doesn't match"
pass "build-release.sh ships only bought tiers as a one-commit repo and records the SHA-256"

# A core reference to a removed tier must fail the build
printf 'use Modules\\Premium\\Feature;\n' > app/core.txt
git commit -qam "core leaks premium"
if RELEASE_OUT="$WORK_DIR/out" scripts/build-release.sh standard 1.2.1 > "$WORK_DIR/leak.log" 2>&1; then
    fail "build-release.sh should fail when core mentions a removed tier"
fi
grep -q 'app/core.txt' "$WORK_DIR/leak.log" || fail "leak report doesn't name the file"
pass "leak check stops a release that mentions a removed tier"

if scripts/build-release.sh gold 1.0.0 > /dev/null 2>&1; then fail "unknown tier accepted"; fi
pass "unknown tier rejected"

pass "All tiered-common tests passed"
