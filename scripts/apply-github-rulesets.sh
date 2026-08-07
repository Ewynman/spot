#!/usr/bin/env bash
# Apply repository rulesets from .github/rulesets/*.json via the GitHub REST API.
#
# Requires: gh CLI authenticated with repo admin access.
# Usage: ./scripts/apply-github-rulesets.sh
#
# Idempotent: updates an existing ruleset when the name matches, otherwise creates it.
# Retries without merge_queue / bypass_actors when the API rejects those fields.

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-Ewynman/spot-ios-app}"
RULESET_DIR="$(cd "$(dirname "$0")/.." && pwd)/.github/rulesets"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required" >&2
  exit 1
fi

ruleset_id_for_name() {
  local name="$1"
  gh api "repos/${REPO}/rulesets" --paginate --jq ".[] | select(.name == \"${name}\") | .id"
}

apply_payload() {
  local name="$1"
  local payload="$2"
  local id

  id="$(ruleset_id_for_name "$name" || true)"
  if [[ -n "$id" ]]; then
    echo "$payload" | gh api "repos/${REPO}/rulesets/${id}" --method PUT --input -
  else
    echo "$payload" | gh api "repos/${REPO}/rulesets" --method POST --input -
  fi
}

should_retry_without_extras() {
  local err="$1"
  [[ "$err" == *"merge_queue"* || "$err" == *"bypass_actors"* || "$err" == *"GitHub Actions integration"* ]]
}

apply_ruleset() {
  local file="$1"
  local name payload fallback err status

  name="$(jq -r '.name' "$file")"
  payload="$(cat "$file")"
  echo "Applying ruleset: ${name}"

  set +e
  err="$(apply_payload "$name" "$payload" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "  applied"
    return 0
  fi

  if ! should_retry_without_extras "$err"; then
    echo "error: failed to apply ${file}" >&2
    echo "$err" >&2
    return 1
  fi

  echo "  API rejected merge_queue and/or bypass_actors; retrying with core rules only."
  echo "  Finish merge queue + GitHub Actions bypass in the UI — see .github/rulesets/README.md"

  fallback="$(jq 'del(.bypass_actors) | .rules = [.rules[] | select(.type != "merge_queue")]' "$file")"
  apply_payload "$name" "$fallback" >/dev/null
  echo "  applied core rules"
}

for file in "${RULESET_DIR}"/*.json; do
  [[ -f "$file" ]] || continue
  apply_ruleset "$file"
done

echo "Done. Review rulesets at: https://github.com/${REPO}/settings/rules"
