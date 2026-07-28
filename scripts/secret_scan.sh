#!/usr/bin/env bash
# Fails CI if obvious service-role / embedded JWT-style secrets appear in app sources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

scan_dirs=(Spot SpotTests SpotUITests)
if command -v rg >/dev/null 2>&1; then
  if rg -n --glob '!**/node_modules/**' \
    'service_role|sb_secret_|SUPABASE_SERVICE_ROLE_KEY\s*=\s*["'\'']?sb_|SUPABASE_.*(ANON|SERVICE_ROLE).*=\s*["'\'']?eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' \
    "${scan_dirs[@]}" 2>/dev/null; then
    echo "secret_scan.sh: disallowed pattern found (see rg output above)." >&2
    exit 1
  fi
else
  if grep -RInE 'service_role|sb_secret_|SUPABASE_SERVICE_ROLE_KEY=|SUPABASE_.*(ANON|SERVICE_ROLE).*=.*eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' "${scan_dirs[@]}" 2>/dev/null | grep -v node_modules; then
    echo "secret_scan.sh: disallowed pattern found (see grep output above)." >&2
    exit 1
  fi
fi

echo "secret_scan.sh: OK"
