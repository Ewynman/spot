-- Staging-only rate limiting for internal test email verification Edge Function.
-- Service-role access only; no client policies. Production must not enable the
-- related function secrets (see docs/product/internal-test-email-verification-prd.md).

create table if not exists public.staging_test_auth_attempts (
  id uuid primary key default gen_random_uuid(),
  pending_user_id uuid not null,
  attempted_at timestamptz not null default now()
);

create index if not exists staging_test_auth_attempts_pending_user_attempted_idx
  on public.staging_test_auth_attempts (pending_user_id, attempted_at desc);

alter table public.staging_test_auth_attempts enable row level security;

revoke all on table public.staging_test_auth_attempts from anon, authenticated;
grant select, insert, delete on table public.staging_test_auth_attempts to service_role;

comment on table public.staging_test_auth_attempts is
  'Service-role-only attempt log for staging-verify-email rate limiting. No client access.';
