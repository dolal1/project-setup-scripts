#!/usr/bin/env bash
# Adds the AI-agent commit review gate to a generated project. Source it, don't run it.
#
# Needs render.sh sourced first. Templates live in templates/ai-agents/.

# apply_ai_guardrails <templates_dir> <project_dir> <project_name> [project_rules]
apply_ai_guardrails() {
    local templates="$1/ai-agents" project="$2" name="$3"
    local rules="${4:-No project-specific rules yet. Add them here as the project grows.}"

    render_template "$templates/AGENTS.md.template" "$project/AGENTS.md" \
        "PROJECT_NAME=$name" "PROJECT_RULES=$rules"
    render_template "$templates/CLAUDE.md.template" "$project/CLAUDE.md"
    render_template "$templates/claude-settings.json.template" "$project/.claude/settings.json"
    render_template "$templates/propose-commit.sh.template" "$project/scripts/propose-commit.sh"
    chmod +x "$project/scripts/propose-commit.sh"

    # Personal Claude Code overrides stay out of git; the shared settings.json is committed.
    if [[ -f "$project/.gitignore" ]] && ! grep -qx '.claude/settings.local.json' "$project/.gitignore"; then
        printf '\n# AI agent personal settings\n.claude/settings.local.json\n' >> "$project/.gitignore"
    fi
}
