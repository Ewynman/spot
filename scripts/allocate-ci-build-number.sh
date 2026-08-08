#!/usr/bin/env bash
# allocate-ci-build-number.sh
#
# Allocates the next iOS CI build number and updates Spot.xcodeproj locally.
#
# Source of truth: repository Actions variable SPOT_IOS_BUILD_NUMBER (override
# with SPOT_IOS_BUILD_NUMBER_VAR). The checked-in CURRENT_PROJECT_VERSION is
# used as a floor so a stale variable cannot move the number backwards.
#
# This script does not commit or push. On this user-owned repository, GitHub
# Actions cannot bypass branch rulesets, so deploy workflows must not push
# bump commits to protected branches.
#
# Requires: gh authenticated for the repo, with permission to read/write
# repository Actions variables (workflow permission: actions: write).
#
# Usage: ./scripts/allocate-ci-build-number.sh
#
# Outputs (stdout): the new build number
# When GITHUB_OUTPUT is set: previous_build / new_build

set -euo pipefail

VAR_NAME="${SPOT_IOS_BUILD_NUMBER_VAR:-SPOT_IOS_BUILD_NUMBER}"
PROJECT_FILE="Spot.xcodeproj/project.pbxproj"
REPO="${GITHUB_REPOSITORY:-}"

if [[ -z "$REPO" ]]; then
  echo "error: GITHUB_REPOSITORY must be set" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "error: $PROJECT_FILE not found" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required" >&2
  exit 1
fi

PBX_BUILD="$(
  grep -m 1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" \
    | sed 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/'
)"
if [[ -z "$PBX_BUILD" || ! "$PBX_BUILD" =~ ^[0-9]+$ ]]; then
  echo "error: could not read CURRENT_PROJECT_VERSION from $PROJECT_FILE" >&2
  exit 1
fi

STORED="$(gh variable get "$VAR_NAME" -R "$REPO" 2>/dev/null || true)"
BASE="$PBX_BUILD"
if [[ -n "$STORED" && "$STORED" =~ ^[0-9]+$ ]] && (( STORED > PBX_BUILD )); then
  BASE="$STORED"
fi

NEW_BUILD=$((BASE + 1))

echo "pbxproj build: $PBX_BUILD"
echo "stored variable ($VAR_NAME): ${STORED:-<unset>}"
echo "allocating build: $NEW_BUILD"

gh variable set "$VAR_NAME" -R "$REPO" --body "$NEW_BUILD"
./scripts/increment-build-number.sh "$NEW_BUILD"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "previous_build=$BASE"
    echo "new_build=$NEW_BUILD"
  } >> "$GITHUB_OUTPUT"
fi

echo "$NEW_BUILD"
