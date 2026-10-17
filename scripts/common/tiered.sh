#!/usr/bin/env bash
# Shared argument handling and checks for the tiered scaffolders
# (setup_<stack>_tiered_project.sh). Source it, don't run it.
#
# The contract these helpers implement is documented in docs/tiered-modules.md.

# The globals set here (TARGET_DIR, PROJECT_NAME, PREFIX, TIERS, ...) are read by the caller.
# shellcheck disable=SC2034

# Prefixes that already mean something in a framework or in a typical client domain.
# "tenant" is the example that bit a rental project: it means a renter there and
# multi-tenancy in Laravel packages, so TENANT_TIER would be ambiguous.
TIERED_RESERVED_PREFIXES=(app application config core module modules tier tiers tenant
    tenants laravel django node test tests admin user users feature features)

# tiered_usage <script_name>
tiered_usage() {
    cat <<EOF
Usage: $1 <dir> --prefix <prefix> [--tiers basic,standard,premium] [--name "Display Name"]
       [--into-existing] [--no-ai-guardrails]

  <dir>              Project directory to create (or an existing repo with --into-existing)
  --prefix           Short lowercase name for the tier setting, e.g. "salon" gives SALON_TIER
  --tiers            Ordered, comma-separated. The first tier is core; each later one is a module
  --name             Human-readable project name (defaults to <dir>'s basename)
  --into-existing    Build into an existing git repo (e.g. a docs-first client repo), keeping
                     its README, docs and .gitignore entries
  --no-ai-guardrails Skip AGENTS.md, CLAUDE.md, .claude/settings.json and propose-commit.sh

Run with no arguments to be prompted.
EOF
}

# validate_prefix <prefix>: returns 1 with a message on stderr if unusable
validate_prefix() {
    local prefix="$1" reserved
    if [[ ! "$prefix" =~ ^[a-z][a-z0-9]{1,15}$ ]]; then
        echo "Prefix '$prefix' must be 2-16 lowercase letters or digits, starting with a letter." >&2
        return 1
    fi
    for reserved in "${TIERED_RESERVED_PREFIXES[@]}"; do
        if [[ "$prefix" == "$reserved" ]]; then
            echo "Prefix '$prefix' is reserved: it already means something in the framework or a" >&2
            echo "common client domain, so ${prefix^^}_TIER would be ambiguous. Use something" >&2
            echo "project-specific, e.g. an abbreviation of the product name (tms, salon)." >&2
            return 1
        fi
    done
}

# parse_tiers <comma,separated> : fills the global TIERS array, returns 1 on bad input
parse_tiers() {
    local raw="$1" tier seen=" "
    IFS=',' read -r -a TIERS <<< "$raw"
    if (( ${#TIERS[@]} < 2 )); then
        echo "Need at least two tiers (core plus one module); got '$raw'." >&2
        return 1
    fi
    for tier in "${TIERS[@]}"; do
        if [[ ! "$tier" =~ ^[a-z][a-z0-9]*$ ]]; then
            echo "Tier '$tier' must be lowercase letters or digits, starting with a letter." >&2
            return 1
        fi
        if [[ "$seen" == *" $tier "* ]]; then
            echo "Tier '$tier' is listed twice." >&2
            return 1
        fi
        seen+="$tier "
    done
}

# studly <word>: basic -> Basic
studly() {
    printf '%s' "${1^}"
}

# tiers_json [tier ...]: the given tiers (default: the TIERS array) as a JSON list, for CI matrices
tiers_json() {
    local out="" tier
    (( $# )) || set -- "${TIERS[@]}"
    for tier in "$@"; do
        out+="${out:+, }\"$tier\""
    done
    printf '[%s]' "$out"
}

# parse_tiered_args "$@": sets TARGET_DIR PROJECT_NAME PREFIX TIERS INTO_EXISTING AI_GUARDRAILS.
# Prompts for anything missing when stdin is a terminal or piped input is available.
parse_tiered_args() {
    TARGET_DIR="" PROJECT_NAME="" PREFIX="" INTO_EXISTING=false AI_GUARDRAILS=true
    local tiers_raw="" script_name
    script_name="$(basename "$0")"

    while (( $# )); do
        case "$1" in
            --prefix) PREFIX="${2:-}"; shift 2 ;;
            --prefix=*) PREFIX="${1#*=}"; shift ;;
            --tiers) tiers_raw="${2:-}"; shift 2 ;;
            --tiers=*) tiers_raw="${1#*=}"; shift ;;
            --name) PROJECT_NAME="${2:-}"; shift 2 ;;
            --name=*) PROJECT_NAME="${1#*=}"; shift ;;
            --into-existing) INTO_EXISTING=true; shift ;;
            --no-ai-guardrails) AI_GUARDRAILS=false; shift ;;
            -h | --help) tiered_usage "$script_name"; exit 0 ;;
            -*) echo "Unknown option: $1" >&2; tiered_usage "$script_name" >&2; return 1 ;;
            *)
                if [[ -n "$TARGET_DIR" ]]; then
                    echo "Only one project directory may be given." >&2
                    return 1
                fi
                TARGET_DIR="$1"; shift
                ;;
        esac
    done

    if [[ -z "$TARGET_DIR" ]]; then
        read -r -p "Project directory (e.g. my-app): " TARGET_DIR || true
    fi
    if [[ -z "$PREFIX" ]]; then
        read -r -p "Tier prefix (e.g. salon gives SALON_TIER): " PREFIX || true
    fi
    if [[ -z "$tiers_raw" ]]; then
        read -r -p "Tiers, lowest first (default: basic,standard,premium): " tiers_raw || true
    fi
    tiers_raw="${tiers_raw:-basic,standard,premium}"

    if [[ -z "$TARGET_DIR" ]]; then
        echo "A project directory is required." >&2
        return 1
    fi
    PROJECT_NAME="${PROJECT_NAME:-$(basename "$TARGET_DIR")}"
    validate_prefix "$PREFIX" || return 1
    parse_tiers "$tiers_raw" || return 1

    if $INTO_EXISTING; then
        if ! git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
            echo "--into-existing needs $TARGET_DIR to be an existing git repository." >&2
            return 1
        fi
    elif [[ -e "$TARGET_DIR" ]] && [[ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
        echo "$TARGET_DIR already exists and is not empty. Use --into-existing to build into it." >&2
        return 1
    fi
}

# apply_tiered_common <templates_dir> <project_dir>: writes scripts/build-release.sh and
# release.exclude. The stack script must also write scripts/release-stack.sh (see the contract).
apply_tiered_common() {
    local templates="$1/tiered-common" project="$2"
    render_template "$templates/build-release.sh.template" "$project/scripts/build-release.sh" \
        "PROJECT_NAME=$PROJECT_NAME" "PREFIX_UPPER=${PREFIX^^}" "TIERS=${TIERS[*]}"
    chmod +x "$project/scripts/build-release.sh"
    render_template "$templates/release.exclude.template" "$project/release.exclude"
}

# merge_gitignore <src> <dst>: appends lines from src that dst doesn't already have
merge_gitignore() {
    local src="$1" dst="$2" line added=false
    touch "$dst"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        if ! grep -qxF -- "$line" "$dst"; then
            if ! $added; then
                printf '\n# Added by %s\n' "$(basename "$0")" >> "$dst"
                added=true
            fi
            printf '%s\n' "$line" >> "$dst"
        fi
    done < "$src"
}

# copy_missing_files <src_dir> <dst_dir>: copies files that dst lacks, never overwriting.
# (cp -n changed meaning across coreutils versions and differs on macOS, so it's avoided.)
copy_missing_files() {
    local src="$1" dst="$2" rel
    while IFS= read -r -d '' rel; do
        rel="${rel#./}"
        if [[ ! -e "$dst/$rel" ]]; then
            mkdir -p "$(dirname "$dst/$rel")"
            cp -p "$src/$rel" "$dst/$rel"
        fi
    done < <(cd "$src" && find . \( -type f -o -type l \) -print0)
}

# move_into_existing <built_dir> <target_dir>: moves a freshly built app into an existing repo
# without overwriting files the repo already has (README, docs, etc.). .gitignore is merged.
move_into_existing() {
    local built="$1" target="$2" entry name
    if [[ -f "$built/.gitignore" ]]; then
        merge_gitignore "$built/.gitignore" "$target/.gitignore"
        rm -f "$built/.gitignore"
    fi
    rm -rf "$built/.git"
    shopt -s dotglob
    for entry in "$built"/*; do
        name="$(basename "$entry")"
        if [[ -e "$target/$name" ]]; then
            if [[ -d "$entry" && -d "$target/$name" ]]; then
                copy_missing_files "$entry" "$target/$name"
            else
                echo "Kept existing $name (the generated one was not copied)." >&2
            fi
        else
            mv "$entry" "$target/$name"
        fi
    done
    shopt -u dotglob
}
