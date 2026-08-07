#!/bin/bash

# validate-coverage.sh
# Validates that the lines this PR adds or modifies are covered by tests.
#
# This measures *changed-line* coverage, not whole-file coverage. Whole-file
# coverage asks "is this entire file well tested?", which punishes any edit to
# a legacy low-coverage file: a four-line threading fix in a 341-line Supabase
# repository would require retro-covering the whole repository to land. The
# question a PR gate should ask is "is the code this PR wrote tested?", which
# is what this script enforces.
#
# Usage: ./validate-coverage.sh <xcresult-path> <base-branch> <coverage-threshold> [min-changed-lines]
#
# Arguments:
#   xcresult-path:      Path to the .xcresult bundle
#   base-branch:        Base branch to compare against (e.g., origin/main)
#   coverage-threshold: Minimum percentage of changed executable lines covered
#   min-changed-lines:  Files with fewer changed executable lines than this are
#                       reported but not enforced (default 10). Below roughly
#                       this size a single uncovered line swings the percentage
#                       so hard that the number stops carrying signal.
#
# Exit codes:
#   0: Coverage meets threshold
#   1: Coverage below threshold or validation error
#
# Note: written for bash 3.2 (the default /bin/bash on macOS runners), so no
# associative arrays.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
XCRESULT_PATH="${1}"
BASE_BRANCH="${2:-origin/main}"
COVERAGE_THRESHOLD="${3:-80}"
MIN_CHANGED_LINES="${4:-10}"

if [ -z "$XCRESULT_PATH" ]; then
    echo -e "${RED}Error: xcresult path is required${NC}"
    echo "Usage: $0 <xcresult-path> [base-branch] [coverage-threshold] [min-changed-lines]"
    exit 1
fi

if [ ! -d "$XCRESULT_PATH" ]; then
    echo -e "${RED}Error: xcresult bundle not found at $XCRESULT_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}=== Changed-Line Coverage Validation ===${NC}"
echo "Coverage threshold: ${COVERAGE_THRESHOLD}% of changed executable lines"
echo "Enforced once a file has at least ${MIN_CHANGED_LINES} changed executable lines"
echo "Scope: Spot/ production Swift including Views; excludes Models/Logs and tests"
echo "Base branch: ${BASE_BRANCH}"
echo "xcresult: ${XCRESULT_PATH}"
echo ""

# Get the list of changed Swift files
echo -e "${BLUE}Getting changed files...${NC}"
git fetch origin "${BASE_BRANCH##*/}" --depth=1 2>/dev/null || true

# Production scope includes Spot/Views and excludes Spot/Models/Logs (log enums).
# `--diff-filter=d` drops deleted files, which have no lines left to cover.
CHANGED_FILES=$(
    git diff --name-only --diff-filter=d "${BASE_BRANCH}" -- '*.swift' \
        | python3 -c '
import sys
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location(
    "coverage_scope",
    Path("scripts/coverage_scope.py"),
)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
for line in sys.stdin:
    path = line.strip()
    if path and mod.is_in_coverage_scope(path):
        print(path)
'
)

if [ -z "$CHANGED_FILES" ]; then
    echo -e "${GREEN}✓ No in-scope production Swift files changed - skipping coverage check${NC}"
    exit 0
fi

echo "Changed production files:"
echo "$CHANGED_FILES" | sed 's/^/  - /'
echo ""

# Extract coverage data
echo -e "${BLUE}Extracting coverage data...${NC}"
COVERAGE_JSON=$(xcrun xccov view --report --json "$XCRESULT_PATH")

if [ -z "$COVERAGE_JSON" ]; then
    echo -e "${YELLOW}⚠ Warning: Could not extract coverage data${NC}"
    echo "This might happen if:"
    echo "  - Tests didn't run"
    echo "  - Code coverage wasn't enabled"
    echo "  - No code was executed during tests"
    exit 1
fi

# Create temporary directory for analysis
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "$COVERAGE_JSON" > "$TEMP_DIR/coverage.json"

echo -e "${BLUE}Analyzing coverage of changed lines...${NC}"
echo ""

FAILED_FILES=()
PASSED_FILES=()
SKIPPED_FILES=()
TOTAL_LINES=0
COVERED_LINES=0

while IFS= read -r file; do
    [ -z "$file" ] && continue

    # The archive records absolute build-machine paths, so resolve the recorded
    # path by suffix rather than assuming the checkout location.
    RECORDED_PATH=$(jq -r --arg filepath "$file" '
        .targets[].files[]
        | select(.path | endswith($filepath))
        | .path
    ' "$TEMP_DIR/coverage.json" 2>/dev/null | head -n 1)

    if [ -z "$RECORDED_PATH" ] || [ "$RECORDED_PATH" = "null" ]; then
        echo -e "${YELLOW}⚠ No coverage data found for: $file${NC}"
        echo "  (File may have no executable lines or wasn't included in test target)"
        continue
    fi

    # New-side line numbers touched by this PR. `-U0` keeps hunks tight to the
    # actual edits; each header looks like `@@ -12,3 +40,5 @@`.
    git diff -U0 "${BASE_BRANCH}" -- "$file" | awk '
        /^@@/ {
            match($0, /\+[0-9]+(,[0-9]+)?/)
            spec = substr($0, RSTART + 1, RLENGTH - 1)
            split(spec, parts, ",")
            start = parts[1]
            count = (parts[2] == "" ? 1 : parts[2])
            for (i = 0; i < count; i++) print start + i
        }
    ' > "$TEMP_DIR/changed_lines.txt"

    if [ ! -s "$TEMP_DIR/changed_lines.txt" ]; then
        echo -e "${YELLOW}⚠ $file: no added or modified lines${NC}"
        continue
    fi

    # Per-line execution counts: "  42: 3" for executable lines, "  42: *" for
    # non-executable ones (comments, declarations, blank lines).
    xcrun xccov view --archive --file "$RECORDED_PATH" "$XCRESULT_PATH" > "$TEMP_DIR/file_cov.txt" 2>/dev/null || true

    if [ ! -s "$TEMP_DIR/file_cov.txt" ]; then
        echo -e "${YELLOW}⚠ Could not read per-line coverage for: $file${NC}"
        continue
    fi

    RESULT=$(awk '
        NR == FNR { changed[$1] = 1; next }
        {
            line = $1
            sub(/:$/, "", line)
            if (!(line in changed)) next
            if ($2 == "*") next          # not executable
            total++
            if ($2 + 0 > 0) covered++
        }
        END { printf "%d %d", total + 0, covered + 0 }
    ' "$TEMP_DIR/changed_lines.txt" "$TEMP_DIR/file_cov.txt")

    FILE_TOTAL=$(echo "$RESULT" | cut -d' ' -f1)
    FILE_COVERED=$(echo "$RESULT" | cut -d' ' -f2)

    if [ "$FILE_TOTAL" -eq 0 ]; then
        echo -e "${BLUE}• $file: no executable lines changed (comments/declarations only)${NC}"
        continue
    fi

    FILE_PERCENT=$((FILE_COVERED * 100 / FILE_TOTAL))

    TOTAL_LINES=$((TOTAL_LINES + FILE_TOTAL))
    COVERED_LINES=$((COVERED_LINES + FILE_COVERED))

    if [ "$FILE_TOTAL" -lt "$MIN_CHANGED_LINES" ]; then
        echo -e "${YELLOW}• $file: ${FILE_PERCENT}% (${FILE_COVERED}/${FILE_TOTAL} changed lines) - below ${MIN_CHANGED_LINES}-line enforcement floor, not enforced${NC}"
        SKIPPED_FILES+=("$file:${FILE_PERCENT}%")
    elif [ "$FILE_PERCENT" -lt "$COVERAGE_THRESHOLD" ]; then
        echo -e "${RED}✗ $file: ${FILE_PERCENT}% (${FILE_COVERED}/${FILE_TOTAL} changed lines)${NC}"
        FAILED_FILES+=("$file:${FILE_PERCENT}%")
    else
        echo -e "${GREEN}✓ $file: ${FILE_PERCENT}% (${FILE_COVERED}/${FILE_TOTAL} changed lines)${NC}"
        PASSED_FILES+=("$file")
    fi
done <<< "$CHANGED_FILES"

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "Files enforced: $((${#PASSED_FILES[@]} + ${#FAILED_FILES[@]}))"
echo "Passed: ${#PASSED_FILES[@]}"
echo "Failed: ${#FAILED_FILES[@]}"
if [ "${#SKIPPED_FILES[@]}" -gt 0 ]; then
    echo "Below enforcement floor: ${#SKIPPED_FILES[@]}"
fi

if [ "$TOTAL_LINES" -gt 0 ]; then
    OVERALL_COVERAGE=$((COVERED_LINES * 100 / TOTAL_LINES))
    echo "Overall changed-line coverage: ${OVERALL_COVERAGE}% (${COVERED_LINES}/${TOTAL_LINES} lines)"
fi

echo ""

# Report results
if [ "${#FAILED_FILES[@]}" -gt 0 ]; then
    echo -e "${RED}❌ Coverage validation FAILED${NC}"
    echo ""
    echo "The lines changed in these files are below the ${COVERAGE_THRESHOLD}% threshold:"
    for failed in "${FAILED_FILES[@]}"; do
        echo -e "  ${RED}✗${NC} $failed"
    done
    echo ""
    echo "Please add tests covering the new/changed code in these files."
    echo ""
    echo "Tips:"
    echo "  - Add unit tests in SpotTests/ for new logic"
    echo "  - Use mocks/fakes for dependencies"
    echo "  - Test both happy path and error cases"
    echo "  - Only the lines you changed are measured, so covering them is enough"
    exit 1
else
    echo -e "${GREEN}✅ Changed lines meet the ${COVERAGE_THRESHOLD}% coverage threshold${NC}"
    exit 0
fi
