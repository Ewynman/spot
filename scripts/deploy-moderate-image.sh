#!/usr/bin/env bash
# Deploys Edge Function: moderate-image → Supabase project aeurigbbohyxvtsfiyul
#
# Prerequisites:
#   - Run from repo root (or fix ROOT below).
#   - Authenticate once:  npx supabase login
#     OR set SUPABASE_ACCESS_TOKEN (Dashboard → Account → Access Tokens).
#   - Azure secrets must exist on the project (see docs/engineering/image-moderation.md
#     and docs/engineering/supabase-environment-setup-guide.md).
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PROJECT_REF="aeurigbbohyxvtsfiyul"

echo "Deploying moderate-image → project ${PROJECT_REF}"
echo "Source: ${ROOT}/supabase/functions/moderate-image/"
npx -y supabase@latest functions deploy moderate-image --project-ref "${PROJECT_REF}"
echo "Done. Verify Dashboard → Edge Functions → moderate-image → Code (full Azure handler)."
echo "Docs: docs/engineering/image-moderation.md"
