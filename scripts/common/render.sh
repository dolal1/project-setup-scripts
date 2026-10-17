#!/usr/bin/env bash
# Shared template rendering for the setup scripts. Source it, don't run it.

# Bash 5.2+ treats "&" in a ${var//pattern/replacement} replacement as the matched text.
# Turn that off so values containing "&" are inserted literally.
shopt -u patsub_replacement 2>/dev/null || true

# render_template <src> <dst> [KEY=VALUE ...]
# Copies <src> to <dst>, replacing every {{KEY}} with VALUE. Values may span several lines.
render_template() {
    local src="$1" dst="$2"
    shift 2

    local content pair key value
    content="$(<"$src")"
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        content="${content//\{\{$key\}\}/$value}"
    done

    mkdir -p "$(dirname "$dst")"
    printf '%s\n' "$content" > "$dst"
}
