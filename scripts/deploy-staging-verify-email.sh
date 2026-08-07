#!/usr/bin/env bash
# Deploys Edge Function: staging-verify-email → Spot staging only.
#
# Hard-rejects production project refs. JWT verification is disabled because
# signup confirmation runs before a session exists; the function body enforces
# staging project, kill switch, code, and email allowlist.
#
# Prerequisites:
#   - Run from repo root.
#   - Authenticate: npx supabase login  OR  SUPABASE_ACCESS_TOKEN
#   - Set function secrets (never commit values):
#       STAGING_TEST_AUTH_ENABLED=true
#       STAGING_TEST_AUTH_CODE=<UT####>   # optional; defaults to UT1234
#       STAGING_TEST_AUTH_EMAILS=<emails> # optional; empty = any email allowed
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STAGING_PROJECT_REF="aeurigbbohyxvtsfiyul"
PRODUCTION_PROJECT_REF="gomdoguewaawdlvijahg"
PROJECT_REF="${1:-$STAGING_PROJECT_REF}"

if [[ "$PROJECT_REF" == "$PRODUCTION_PROJECT_REF" ]]; then
  echo "Refusing to deploy staging-verify-email to production ($PRODUCTION_PROJECT_REF)." >&2
  exit 1
fi

if [[ "$PROJECT_REF" != "$STAGING_PROJECT_REF" ]]; then
  echo "Refusing unknown project ref: $PROJECT_REF (expected staging $STAGING_PROJECT_REF)." >&2
  exit 1
fi

echo "Deploying staging-verify-email → project ${PROJECT_REF} (verify_jwt=false)"
npx -y supabase@latest functions deploy staging-verify-email \
  --project-ref "${PROJECT_REF}" \
  --no-verify-jwt
echo "Done. Confirm secrets STAGING_TEST_AUTH_* are set on staging only."
