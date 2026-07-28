#!/usr/bin/env python3
"""Read-only staging diagnostics for missing home-feed Spots."""

from __future__ import annotations

import os
import sys

from apply_supabase_migration_mcp import MCPClient, response_text


ENDPOINT = (
    "https://mcp.supabase.com/mcp"
    "?project_ref=aeurigbbohyxvtsfiyul&features=database"
)


def run_sql(client: MCPClient, query: str) -> str:
    result = client.call_tool("execute_sql", {"query": query}, retries=2)
    return response_text(result)


def main() -> int:
    access_token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not access_token:
        print("SUPABASE_ACCESS_TOKEN is not configured", file=sys.stderr)
        return 2

    client = MCPClient(ENDPOINT, access_token)
    client.initialize()

    migrations = client.call_tool("list_migrations", {})
    print("=== STAGING MIGRATION HISTORY ===")
    print(response_text(migrations))

    counts_sql = """
select
  (select count(*) from auth.users) as auth_users_total,
  (select count(*) from public.users) as profiles_total,
  (select count(*) from public.spots) as spots_total,
  (
    select count(*)
    from public.spots s
    join public.users u on u.id = s.user_id
    where s.hidden_at is null
      and coalesce(s.moderation_status, 'approved') = 'approved'
      and coalesce(u.account_status, 'active') not in ('suspended', 'banned')
      and u.suspended_for_reports_at is null
  ) as spots_globally_feed_eligible,
  (
    select count(*) from public.spots
    where hidden_at is not null
  ) as spots_hidden,
  (
    select count(*) from public.spots
    where coalesce(moderation_status, 'approved') <> 'approved'
  ) as spots_not_approved,
  (
    select count(*) from public.users
    where coalesce(account_status, 'active') in ('suspended', 'banned')
       or suspended_for_reports_at is not null
  ) as filtered_authors,
  (
    select count(*) from public.spot_images
  ) as spot_images_total,
  (
    select count(*) from public.media_assets
  ) as media_assets_total;
""".strip()
    print("=== STAGING DATA COUNTS ===")
    print(run_sql(client, counts_sql))

    schema_sql = """
select
  to_regprocedure('public.get_home_feed_v1()') is not null
    or exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'get_home_feed_v1'
    ) as home_feed_rpc_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_home_feed_status_v1'
  ) as home_feed_status_rpc_exists,
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.spots'::regclass
  ) as spots_rls_enabled,
  (
    select relforcerowsecurity
    from pg_class
    where oid = 'public.spots'::regclass
  ) as spots_rls_forced,
  has_table_privilege('authenticated', 'public.spots', 'select')
    as authenticated_can_select_spots;
""".strip()
    print("=== STAGING FEED SCHEMA ===")
    print(run_sql(client, schema_sql))

    print("Staging diagnostics completed without modifying data.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
