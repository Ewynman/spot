-- P0 auth reliability: provide the pre-auth username availability contract and
-- enforce case-insensitive uniqueness at the database boundary.
--
-- The RPC intentionally returns only a boolean. Invalid candidates return
-- false, while the client performs the same syntax validation before calling
-- it so invalid input can be presented separately from a taken username.
--
-- Canonical database normalization is lower(btrim(username)). Usernames are
-- restricted to ASCII by the shared client contract, avoiding locale-specific
-- differences between Swift and PostgreSQL lowercasing.

create unique index if not exists users_username_normalized_uidx
  on public.users (lower(btrim(username)))
  where username is not null;

create or replace function public.is_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_username is not null
    and btrim(p_username) ~ '^[A-Za-z0-9][A-Za-z0-9._-]{1,18}[A-Za-z0-9]$'
    and btrim(p_username) !~ '[._-]{2}'
    and lower(btrim(p_username)) <> all (array[
      'admin',
      'administrator',
      'moderator',
      'mod',
      'support',
      'help',
      'owner',
      'official',
      'spot',
      'spotapp',
      'team',
      'system',
      'apple',
      'google',
      'meta',
      'spotteam'
    ])
    and not exists (
      select 1
      from public.users u
      where lower(btrim(u.username)) = lower(btrim(p_username))
    );
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;

comment on index public.users_username_normalized_uidx is
  'Atomically enforces username uniqueness using lower(btrim(username)); the '
  'is_username_available RPC is advisory only.';

comment on function public.is_username_available(text) is
  'Returns whether a syntactically valid, non-reserved username is currently '
  'unclaimed. SECURITY DEFINER permits the pre-auth check without granting '
  'anon access to public.users. Final uniqueness is enforced by '
  'users_username_normalized_uidx.';
