#!/usr/bin/env bash
# allocate-ci-build-number.sh
#
# Allocates the next iOS CI build number, updates Spot.xcodeproj locally, and
# persists the allocated number on the unprotected branch `ci/build-number`
# (file: BUILD_NUMBER).
#
# Why a branch (not Actions variables / not main):
# - GITHUB_TOKEN cannot read/write repository Actions variables (admin-only API).
# - Branch rulesets block GITHUB_TOKEN from pushing bump commits to main/release/*.
# - `ci/build-number` is intentionally unprotected so deploy/TestFlight can push.
#
# The checked-in CURRENT_PROJECT_VERSION is used as a floor so a stale counter
# cannot move the number backwards.
#
# Requires: git + push access to refs/heads/ci/build-number
#   (workflow permission: contents: write).
#
# Usage: ./scripts/allocate-ci-build-number.sh
#
# Env overrides:
#   SPOT_IOS_BUILD_NUMBER_REF   default: ci/build-number
#   SPOT_IOS_BUILD_NUMBER_FILE  default: BUILD_NUMBER
#
# Outputs (stdout): the new build number
# When GITHUB_OUTPUT is set: previous_build / new_build

set -euo pipefail

BUILD_REF="${SPOT_IOS_BUILD_NUMBER_REF:-ci/build-number}"
BUILD_FILE="${SPOT_IOS_BUILD_NUMBER_FILE:-BUILD_NUMBER}"
PROJECT_FILE="Spot.xcodeproj/project.pbxproj"
REPO_ROOT="$(pwd)"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "error: $PROJECT_FILE not found (run from repo root)" >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not a git repository" >&2
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

git fetch origin "+refs/heads/${BUILD_REF}:refs/remotes/origin/${BUILD_REF}" 2>/dev/null || true

STORED=""
if git rev-parse --verify "origin/${BUILD_REF}" >/dev/null 2>&1; then
  STORED="$(git show "origin/${BUILD_REF}:${BUILD_FILE}" 2>/dev/null | tr -d '[:space:]' || true)"
fi

BASE="$PBX_BUILD"
if [[ -n "$STORED" && "$STORED" =~ ^[0-9]+$ ]] && (( STORED > PBX_BUILD )); then
  BASE="$STORED"
fi

NEW_BUILD=$((BASE + 1))

echo "pbxproj build: $PBX_BUILD"
echo "stored counter (origin/${BUILD_REF}:${BUILD_FILE}): ${STORED:-<unset>}"
echo "allocating build: $NEW_BUILD"

./scripts/increment-build-number.sh "$NEW_BUILD"

WT="$(mktemp -d "${TMPDIR:-/tmp}/spot-build-number.XXXXXX")"
cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$WT"
}
trap cleanup EXIT

if git rev-parse --verify "origin/${BUILD_REF}" >/dev/null 2>&1; then
  git worktree add --detach "$WT" "origin/${BUILD_REF}" >/dev/null
else
  git worktree add --detach "$WT" HEAD >/dev/null
  git -C "$WT" checkout --orphan "$BUILD_REF" >/dev/null
  # Orphan checkout keeps the index from HEAD; clear it so the branch stays tiny.
  git -C "$WT" rm -rf --quiet . >/dev/null 2>&1 || true
  find "$WT" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
fi

printf '%s\n' "$NEW_BUILD" > "${WT}/${BUILD_FILE}"
cat > "${WT}/README.md" <<'EOF'
# CI iOS build number

Unprotected counter branch used by `deploy.yml` / `testflight.yml`.

- `BUILD_NUMBER` is the last allocated CI build (source of truth for Firebase / TestFlight).
- Do **not** add branch protection here — `GITHUB_TOKEN` must be able to push.
- Do **not** merge this branch into `main`.

Advance manually if needed:

```bash
git fetch origin ci/build-number
git show origin/ci/build-number:BUILD_NUMBER
# then push a commit that sets BUILD_NUMBER ahead of the highest shipped build
```
EOF

git -C "$WT" add "$BUILD_FILE" README.md
git -C "$WT" \
  -c user.name="github-actions[bot]" \
  -c user.email="github-actions[bot]@users.noreply.github.com" \
  commit -m "Set iOS CI build number to ${NEW_BUILD} [skip ci]" >/dev/null

git -C "$WT" push origin "HEAD:refs/heads/${BUILD_REF}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "previous_build=$BASE"
    echo "new_build=$NEW_BUILD"
  } >> "$GITHUB_OUTPUT"
fi

echo "$NEW_BUILD"
