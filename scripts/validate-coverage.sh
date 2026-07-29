#!/bin/bash

# validate-coverage.sh
# Validates that code coverage meets the minimum threshold for changed files
# 
# Usage: ./validate-coverage.sh <xcresult-path> <base-branch> <coverage-threshold>
# 
# Arguments:
#   xcresult-path: Path to the .xcresult bundle
#   base-branch: Base branch to compare against (e.g., origin/main)
#   coverage-threshold: Minimum coverage percentage (e.g., 80)
#
# Exit codes:
#   0: Coverage meets threshold
#   1: Coverage below threshold or validation error

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

if [ -z "$XCRESULT_PATH" ]; then
    echo -e "${RED}Error: xcresult path is required${NC}"
    echo "Usage: $0 <xcresult-path> [base-branch] [coverage-threshold]"
    exit 1
fi

if [ ! -d "$XCRESULT_PATH" ]; then
    echo -e "${RED}Error: xcresult bundle not found at $XCRESULT_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}=== Code Coverage Validation ===${NC}"
echo "Coverage threshold: ${COVERAGE_THRESHOLD}%"
echo "Base branch: ${BASE_BRANCH}"
echo "xcresult: ${XCRESULT_PATH}"
echo ""

# Get the list of changed Swift files
echo -e "${BLUE}Getting changed files...${NC}"
git fetch origin "${BASE_BRANCH##*/}" --depth=1 2>/dev/null || true

# SwiftUI view execution is measured by the separate SpotUITests scheme, not by
# this unit-test job. Enforce unit coverage on changed non-view production code.
CHANGED_FILES=$(git diff --name-only "${BASE_BRANCH}" -- '*.swift' | grep -E '^Spot/' | grep -v '^Spot/Views/' | grep -v 'SpotTests/' | grep -v 'SpotUITests/' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo -e "${GREEN}✓ No production Swift files changed - skipping coverage check${NC}"
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

# Parse coverage for changed files
echo -e "${BLUE}Analyzing coverage for changed files...${NC}"
echo ""

FAILED_FILES=()
PASSED_FILES=()
TOTAL_LINES=0
COVERED_LINES=0

while IFS= read -r file; do
    # Normalize file path
    NORMALIZED_FILE=$(echo "$file" | sed 's/^\.\///')
    
    # Extract coverage for this specific file using jq
    FILE_COVERAGE=$(echo "$COVERAGE_JSON" | jq -r --arg filepath "$NORMALIZED_FILE" '
        .targets[] | 
        .files[] | 
        select(.path | endswith($filepath)) | 
        {
            path: .path,
            lineCoverage: .lineCoverage,
            coveredLines: .coveredLines,
            executableLines: .executableLines
        }
    ' 2>/dev/null || echo "")
    
    if [ -z "$FILE_COVERAGE" ]; then
        echo -e "${YELLOW}⚠ No coverage data found for: $NORMALIZED_FILE${NC}"
        echo "  (File may have no executable lines or wasn't included in test target)"
        continue
    fi
    
    # Parse coverage values
    LINE_COVERAGE=$(echo "$FILE_COVERAGE" | jq -r '.lineCoverage' 2>/dev/null || echo "0")
    COVERED=$(echo "$FILE_COVERAGE" | jq -r '.coveredLines' 2>/dev/null || echo "0")
    EXECUTABLE=$(echo "$FILE_COVERAGE" | jq -r '.executableLines' 2>/dev/null || echo "0")
    
    # Convert to percentage (multiply by 100)
    COVERAGE_PERCENT=$(echo "$LINE_COVERAGE" | awk '{printf "%.0f", $1 * 100}')
    COVERAGE_PERCENT_INT=${COVERAGE_PERCENT%.*}
    
    TOTAL_LINES=$((TOTAL_LINES + EXECUTABLE))
    COVERED_LINES=$((COVERED_LINES + COVERED))
    
    # Check if coverage meets threshold
    if [ "$COVERAGE_PERCENT_INT" -lt "$COVERAGE_THRESHOLD" ]; then
        echo -e "${RED}✗ $NORMALIZED_FILE: ${COVERAGE_PERCENT_INT}% (${COVERED}/${EXECUTABLE} lines)${NC}"
        FAILED_FILES+=("$NORMALIZED_FILE:${COVERAGE_PERCENT_INT}%")
    else
        echo -e "${GREEN}✓ $NORMALIZED_FILE: ${COVERAGE_PERCENT_INT}% (${COVERED}/${EXECUTABLE} lines)${NC}"
        PASSED_FILES+=("$NORMALIZED_FILE")
    fi
done <<< "$CHANGED_FILES"

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "Changed files analyzed: $((${#PASSED_FILES[@]} + ${#FAILED_FILES[@]}))"
echo "Passed: ${#PASSED_FILES[@]}"
echo "Failed: ${#FAILED_FILES[@]}"

if [ "$TOTAL_LINES" -gt 0 ]; then
    OVERALL_COVERAGE=$((COVERED_LINES * 100 / TOTAL_LINES))
    echo "Overall coverage of changed files: ${OVERALL_COVERAGE}% (${COVERED_LINES}/${TOTAL_LINES} lines)"
fi

echo ""

# Report results
if [ "${#FAILED_FILES[@]}" -gt 0 ]; then
    echo -e "${RED}❌ Coverage validation FAILED${NC}"
    echo ""
    echo "The following files do not meet the ${COVERAGE_THRESHOLD}% coverage threshold:"
    for failed in "${FAILED_FILES[@]}"; do
        echo -e "  ${RED}✗${NC} $failed"
    done
    echo ""
    echo "Please add tests to cover the new/changed code in these files."
    echo ""
    echo "Tips:"
    echo "  - Add unit tests in SpotTests/ for new logic"
    echo "  - Use mocks/fakes for dependencies"
    echo "  - Test both happy path and error cases"
    echo "  - Aim for 100% coverage on new code when practical"
    exit 1
else
    echo -e "${GREEN}✅ All changed files meet the ${COVERAGE_THRESHOLD}% coverage threshold${NC}"
    exit 0
fi
