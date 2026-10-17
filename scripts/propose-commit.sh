#!/usr/bin/env bash
# Show what is about to be committed and commit only after a human approves on the terminal.
#
# Usage:
#   1. git add <files>
#   2. write the commit message to "$(git rev-parse --git-path COMMIT_PROPOSAL)"
#   3. scripts/propose-commit.sh [--diff]
#
# The answer is read from /dev/tty, not stdin, so it cannot be supplied by piping input in.

set -euo pipefail

show_diff=false
[[ "${1:-}" == "--diff" ]] && show_diff=true

proposal="$(git rev-parse --git-path COMMIT_PROPOSAL)"

if [[ ! -s "$proposal" ]]; then
    echo "No commit message proposed. Write it to $proposal first." >&2
    exit 1
fi

if git diff --cached --quiet; then
    echo "Nothing is staged. Stage the changes to commit with git add first." >&2
    exit 1
fi

if ! { exec 3</dev/tty; } 2>/dev/null; then
    echo "propose-commit.sh needs an interactive terminal for the approval prompt." >&2
    echo "Ask a human to run it." >&2
    exit 1
fi

while true; do
    echo "===== git status ====="
    git status --short
    echo
    echo "===== staged changes ====="
    if $show_diff; then
        git --no-pager diff --cached
    else
        git --no-pager diff --cached --stat
    fi
    echo
    echo "===== proposed commit message ====="
    cat "$proposal"
    echo "==================================="
    echo

    read -r -u 3 -p "Commit? [y]es / [N]o / [e]dit message / [d]iff: " answer
    case "$answer" in
        y | Y | yes)
            git commit -F "$proposal"
            rm -f "$proposal"
            exit 0
            ;;
        e | E)
            "${EDITOR:-vi}" "$proposal" <&3
            ;;
        d | D)
            show_diff=true
            ;;
        *)
            echo "Not committed. The proposal is kept at $proposal." >&2
            exit 1
            ;;
    esac
done
