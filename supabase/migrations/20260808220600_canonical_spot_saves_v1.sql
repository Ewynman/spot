-- Canonical Spot saves and collection memberships must be unique and idempotent.
-- Remove legacy duplicates before adding the database invariants.

with ranked_bookmarks as (
  select
    ctid,
    row_number() over (
      partition by user_id, spot_id
      order by ctid
    ) as duplicate_rank
  from public.spot_bookmarks
)
delete from public.spot_bookmarks
where ctid in (
  select ctid
  from ranked_bookmarks
  where duplicate_rank > 1
);

with ranked_memberships as (
  select
    ctid,
    row_number() over (
      partition by collection_id, spot_id
      order by sort_index, ctid
    ) as duplicate_rank
  from public.bookmark_collection_spots
)
delete from public.bookmark_collection_spots
where ctid in (
  select ctid
  from ranked_memberships
  where duplicate_rank > 1
);

-- Collections are metadata for a canonical save, never an independent save path.
delete from public.bookmark_collection_spots bcs
using public.bookmark_collections bc
where bcs.collection_id = bc.id
  and not exists (
    select 1
    from public.spot_bookmarks sb
    where sb.user_id = bc.user_id
      and sb.spot_id = bcs.spot_id
  );

create unique index if not exists spot_bookmarks_user_spot_uidx
  on public.spot_bookmarks (user_id, spot_id);

create unique index if not exists bookmark_collection_spots_collection_spot_uidx
  on public.bookmark_collection_spots (collection_id, spot_id);

create or replace function public.enforce_collection_spot_is_saved_v1()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.bookmark_collections bc
    join public.spot_bookmarks sb
      on sb.user_id = bc.user_id
     and sb.spot_id = new.spot_id
    where bc.id = new.collection_id
  ) then
    raise exception 'Spot must be saved before it can be added to a collection'
      using errcode = '23503';
  end if;

  return new;
end;
$$;

drop trigger if exists bookmark_collection_spots_require_save
  on public.bookmark_collection_spots;
create trigger bookmark_collection_spots_require_save
before insert or update on public.bookmark_collection_spots
for each row execute function public.enforce_collection_spot_is_saved_v1();

revoke all on function public.enforce_collection_spot_is_saved_v1() from public;

-- Keep memberships consistent even if a bookmark is deleted outside remove_saved_spot_v1.
create or replace function public.cleanup_collection_spots_on_bookmark_delete_v1()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from public.bookmark_collection_spots bcs
  using public.bookmark_collections bc
  where bcs.collection_id = bc.id
    and bc.user_id = old.user_id
    and bcs.spot_id = old.spot_id;

  return old;
end;
$$;

drop trigger if exists spot_bookmarks_cleanup_collection_spots
  on public.spot_bookmarks;
create trigger spot_bookmarks_cleanup_collection_spots
after delete on public.spot_bookmarks
for each row execute function public.cleanup_collection_spots_on_bookmark_delete_v1();

revoke all on function public.cleanup_collection_spots_on_bookmark_delete_v1() from public;

-- Atomically remove collection metadata before removing the canonical save.
-- This is invoker-security code, so existing RLS policies still authorize both deletes.
-- The AFTER DELETE trigger above is a safety net for direct spot_bookmarks deletes.
create or replace function public.remove_saved_spot_v1(p_spot_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from public.bookmark_collection_spots bcs
  using public.bookmark_collections bc
  where bcs.collection_id = bc.id
    and bc.user_id = (select auth.uid())
    and bcs.spot_id = p_spot_id;

  delete from public.spot_bookmarks
  where user_id = (select auth.uid())
    and spot_id = p_spot_id;
end;
$$;

revoke all on function public.remove_saved_spot_v1(uuid) from public;
grant execute on function public.remove_saved_spot_v1(uuid) to authenticated;
