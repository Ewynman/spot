-- Deleting a Spot cascades to spot_likes / spot_bookmarks. Those AFTER DELETE
-- triggers call _record_feed_event_for_user_v1, which inserted into
-- user_feed_events while the parent spots row was mid-delete, violating
-- user_feed_events_spot_id_fkey and aborting the whole Spot delete.
--
-- Also fix record_feed_event_v1, which previously inserted a zero-strength
-- event when the Spot was already gone (same FK failure for client telemetry
-- after optimistic local removal).

create or replace function public._record_feed_event_for_user_v1(
  p_user_id uuid,
  p_spot_id uuid,
  p_event_type text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_creator_id uuid;
  v_vibe_tag_id uuid;
  v_delta double precision;
begin
  if p_user_id is null or p_spot_id is null then
    return;
  end if;

  select s.user_id, s.vibe_tag_id
    into v_creator_id, v_vibe_tag_id
    from public.spots s
   where s.id = p_spot_id;

  -- Spot already gone (or mid CASCADE delete): skip telemetry rather than
  -- inserting a row that cannot satisfy user_feed_events_spot_id_fkey.
  if not found then
    return;
  end if;

  v_delta := public.feed_event_weight_v1(p_event_type);

  insert into public.user_feed_events (
    user_id, spot_id, creator_id, vibe_tag_id,
    event_type, event_strength, dwell_ms, metadata
  ) values (
    p_user_id, p_spot_id, v_creator_id, v_vibe_tag_id,
    p_event_type, v_delta, null, coalesce(p_metadata, '{}'::jsonb)
  );

  if v_vibe_tag_id is not null and v_delta <> 0 then
    insert into public.user_vibe_affinities (
      user_id, vibe_tag_id, score, positive_events, negative_events,
      last_event_at, updated_at
    ) values (
      p_user_id, v_vibe_tag_id,
      greatest(-20, least(20, v_delta)),
      case when v_delta > 0 then 1 else 0 end,
      case when v_delta < 0 then 1 else 0 end,
      now(), now()
    )
    on conflict (user_id, vibe_tag_id)
    do update set
      score = greatest(-20, least(20, public.user_vibe_affinities.score + excluded.score)),
      positive_events = public.user_vibe_affinities.positive_events + excluded.positive_events,
      negative_events = public.user_vibe_affinities.negative_events + excluded.negative_events,
      last_event_at = now(),
      updated_at = now();
  end if;

  if v_creator_id is not null and v_creator_id <> p_user_id and v_delta <> 0 then
    insert into public.user_creator_affinities (
      user_id, creator_id, score, positive_events, negative_events,
      last_event_at, updated_at
    ) values (
      p_user_id, v_creator_id,
      greatest(-20, least(20, v_delta)),
      case when v_delta > 0 then 1 else 0 end,
      case when v_delta < 0 then 1 else 0 end,
      now(), now()
    )
    on conflict (user_id, creator_id)
    do update set
      score = greatest(-20, least(20, public.user_creator_affinities.score + excluded.score)),
      positive_events = public.user_creator_affinities.positive_events + excluded.positive_events,
      negative_events = public.user_creator_affinities.negative_events + excluded.negative_events,
      last_event_at = now(),
      updated_at = now();
  end if;
end;
$function$;

create or replace function public.record_feed_event_v1(
  p_spot_id uuid,
  p_event_type text,
  p_dwell_ms integer default null::integer,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_creator_id uuid;
  v_vibe_tag_id uuid;
  v_delta double precision;
begin
  if v_user_id is null then
    raise exception 'record_feed_event_v1 requires auth.uid()';
  end if;

  select s.user_id, s.vibe_tag_id
    into v_creator_id, v_vibe_tag_id
    from public.spots s
   where s.id = p_spot_id;

  -- Missing Spot: no-op. Do not insert into user_feed_events (FK would fail).
  if not found then
    return;
  end if;

  v_delta := public.feed_event_weight_v1(p_event_type);

  insert into public.user_feed_events (
    user_id, spot_id, creator_id, vibe_tag_id,
    event_type, event_strength, dwell_ms, metadata
  ) values (
    v_user_id, p_spot_id, v_creator_id, v_vibe_tag_id,
    p_event_type, v_delta, p_dwell_ms, coalesce(p_metadata, '{}'::jsonb)
  );

  if v_vibe_tag_id is not null and v_delta <> 0 then
    insert into public.user_vibe_affinities (
      user_id, vibe_tag_id, score, positive_events, negative_events, last_event_at, updated_at
    ) values (
      v_user_id, v_vibe_tag_id,
      greatest(-20, least(20, v_delta)),
      case when v_delta > 0 then 1 else 0 end,
      case when v_delta < 0 then 1 else 0 end,
      now(), now()
    )
    on conflict (user_id, vibe_tag_id)
    do update set
      score = greatest(-20, least(20, public.user_vibe_affinities.score + excluded.score)),
      positive_events = public.user_vibe_affinities.positive_events + excluded.positive_events,
      negative_events = public.user_vibe_affinities.negative_events + excluded.negative_events,
      last_event_at = now(),
      updated_at = now();
  end if;

  if v_creator_id is not null and v_creator_id <> v_user_id and v_delta <> 0 then
    insert into public.user_creator_affinities (
      user_id, creator_id, score, positive_events, negative_events, last_event_at, updated_at
    ) values (
      v_user_id, v_creator_id,
      greatest(-20, least(20, v_delta)),
      case when v_delta > 0 then 1 else 0 end,
      case when v_delta < 0 then 1 else 0 end,
      now(), now()
    )
    on conflict (user_id, creator_id)
    do update set
      score = greatest(-20, least(20, public.user_creator_affinities.score + excluded.score)),
      positive_events = public.user_creator_affinities.positive_events + excluded.positive_events,
      negative_events = public.user_creator_affinities.negative_events + excluded.negative_events,
      last_event_at = now(),
      updated_at = now();
  end if;

  if p_event_type in ('hide', 'report') then
    insert into public.user_hidden_spots (
      user_id, spot_id, reason, metadata, updated_at
    ) values (
      v_user_id, p_spot_id, p_event_type, coalesce(p_metadata, '{}'::jsonb), now()
    )
    on conflict (user_id, spot_id)
    do update set
      reason = excluded.reason,
      metadata = excluded.metadata,
      updated_at = now();
  end if;
end;
$function$;
