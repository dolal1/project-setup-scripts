#!/bin/bash

# Tests the shared AI-agent guardrails (scripts/common/ai-guardrails.sh) in isolation,
# without running a full setup script.

set -e

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$TESTS_DIR/.."
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# shellcheck source=SCRIPTDIR/../scripts/common/render.sh
source "$REPO_DIR/scripts/common/render.sh"
# shellcheck source=SCRIPTDIR/../scripts/common/ai-guardrails.sh
source "$REPO_DIR/scripts/common/ai-guardrails.sh"

# render_template keeps "&", slashes and newlines literal
printf 'a {{X}} b\n' > "$WORK_DIR/t.template"
render_template "$WORK_DIR/t.template" "$WORK_DIR/t.out" "X=one & two/three
four"
[ "$(cat "$WORK_DIR/t.out")" = "a one & two/three
four b" ] || fail "render_template mangled special characters: $(cat "$WORK_DIR/t.out")"
pass "render_template inserts values literally"

project="$WORK_DIR/demo"
mkdir -p "$project"
printf 'vendor/\n' > "$project/.gitignore"
(cd "$project" && git init -q)

apply_ai_guardrails "$REPO_DIR/templates" "$project" "demo" "- Core never imports from modules/."
apply_ai_guardrails "$REPO_DIR/templates" "$project" "demo" "- Core never imports from modules/."

for f in AGENTS.md CLAUDE.md .claude/settings.json scripts/propose-commit.sh; do
    [ -f "$project/$f" ] || fail "$f not created"
done
pass "guardrail files created"

grep -q '^# Working on demo with an AI coding agent' "$project/AGENTS.md" || fail "project name not filled in AGENTS.md"
grep -q -- '- Core never imports from modules/.' "$project/AGENTS.md" || fail "project rules not filled in AGENTS.md"
! grep -q '{{' "$project/AGENTS.md" || fail "unfilled placeholder left in AGENTS.md"
grep -qx '@AGENTS.md' "$project/CLAUDE.md" || fail "CLAUDE.md does not import AGENTS.md"
pass "AGENTS.md and CLAUDE.md filled in"

for rule in 'Bash(git commit:*)' 'Bash(git push:*)' 'Bash(gh repo create:*)'; do
    jq -e --arg r "$rule" '.permissions.ask | index($r)' "$project/.claude/settings.json" > /dev/null \
        || fail ".claude/settings.json is missing ask rule $rule"
done
pass ".claude/settings.json is valid JSON with the ask rules"

[ "$(grep -cx '.claude/settings.local.json' "$project/.gitignore")" = 1 ] || fail ".gitignore entry missing or duplicated"
pass ".gitignore entry added once"

[ -x "$project/scripts/propose-commit.sh" ] || fail "propose-commit.sh is not executable"
cd "$project"
echo "hello" > file.txt
git add file.txt
printf 'Add file\n' > "$(git rev-parse --git-path COMMIT_PROPOSAL)"
# Piped "y" must not approve the commit: the prompt reads /dev/tty, never stdin.
# setsid drops the controlling terminal, as an agent's shell has none.
echo y | setsid scripts/propose-commit.sh > /dev/null 2>&1 || true
if git rev-parse --verify -q HEAD > /dev/null; then
    fail "propose-commit.sh committed without a terminal approval"
fi
pass "propose-commit.sh refuses to commit without a terminal"

pass "All AI guardrail tests passed"
