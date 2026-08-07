#!/bin/bash

# show-uncovered-changed-lines.sh
# Lists changed executable lines that have 0 hits in an xcresult coverage archive.
#
# Usage: ./scripts/show-uncovered-changed-lines.sh <xcresult-path> [base-branch]
#
# Exit codes:
#   0: Always (informational). Prints uncovered lines per in-scope file.

set -e

XCRESULT_PATH="${1}"
BASE_BRANCH="${2:-origin/main}"

if [ -z "$XCRESULT_PATH" ] || [ ! -d "$XCRESULT_PATH" ]; then
    echo "Usage: $0 <xcresult-path> [base-branch]" >&2
    exit 1
fi

NAME_STATUS=$(
    git diff --find-renames --name-status --diff-filter=d "${BASE_BRANCH}" -- '*.swift' || true
)

CHANGED_ENTRIES=$(
    NAME_STATUS="$NAME_STATUS" python3 -c '
import os
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location(
    "coverage_scope",
    Path("scripts/coverage_scope.py"),
)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
for new_path, old_path in mod.changed_files_from_name_status(
    os.environ.get("NAME_STATUS", ""),
    for_enforcement=True,
):
    print("%s\t%s" % (new_path, old_path or ""))
'
)

if [ -z "$CHANGED_ENTRIES" ]; then
    echo "No enforceable production Swift changes vs ${BASE_BRANCH}."
    exit 0
fi

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

xcrun xccov view --report --json "$XCRESULT_PATH" > "$TEMP_DIR/coverage.json"

echo "Uncovered changed executable lines vs ${BASE_BRANCH} (enforcement scope):"
echo ""

while IFS=$'\t' read -r file old_path; do
    [ -z "$file" ] && continue

    RECORDED_PATH=$(jq -r --arg filepath "$file" '
        .targets[].files[]
        | select(.path | endswith($filepath))
        | .path
    ' "$TEMP_DIR/coverage.json" 2>/dev/null | head -n 1)

    if [ -z "$RECORDED_PATH" ] || [ "$RECORDED_PATH" = "null" ]; then
        echo "• $file: no coverage data"
        continue
    fi

    if [ -n "$old_path" ]; then
        DIFF_ARGS=(--find-renames "${BASE_BRANCH}" -- "$old_path" "$file")
    else
        DIFF_ARGS=(--find-renames "${BASE_BRANCH}" -- "$file")
    fi
    git diff -U0 "${DIFF_ARGS[@]}" | awk '
        /^@@/ {
            match($0, /\+[0-9]+(,[0-9]+)?/)
            spec = substr($0, RSTART + 1, RLENGTH - 1)
            split(spec, parts, ",")
            start = parts[1]
            count = (parts[2] == "" ? 1 : parts[2])
            for (i = 0; i < count; i++) print start + i
        }
    ' > "$TEMP_DIR/changed_lines.txt"

    xcrun xccov view --archive --file "$RECORDED_PATH" "$XCRESULT_PATH" > "$TEMP_DIR/file_cov.txt" 2>/dev/null || true

    UNCOVERED=$(awk '
        NR == FNR { changed[$1] = 1; next }
        {
            line = $1
            sub(/:$/, "", line)
            if (!(line in changed)) next
            if ($2 == "*") next
            if ($2 + 0 == 0) print line
        }
    ' "$TEMP_DIR/changed_lines.txt" "$TEMP_DIR/file_cov.txt")

    if [ -z "$UNCOVERED" ]; then
        echo "✓ $file: all changed executable lines covered"
    else
        echo "✗ $file:"
        echo "$UNCOVERED" | sed 's/^/    line /'
    fi
done <<< "$CHANGED_ENTRIES"
