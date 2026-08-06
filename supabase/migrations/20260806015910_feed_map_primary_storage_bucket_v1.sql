-- Return spot_images.storage_bucket from home-feed and map RPCs so the client
-- can sign primary images against the correct private bucket
-- (legacy `spots` vs moderated `approved_spot_images`).
--
-- Changing RETURNS TABLE requires DROP + CREATE (CREATE OR REPLACE cannot
-- widen the return row type).

-- ---------------------------------------------------------------------------
-- get_home_feed_v1
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_home_feed_v1(
  integer, double precision, double precision, uuid, boolean
);

CREATE FUNCTION public.get_home_feed_v1(
  p_limit integer DEFAULT 24,
  p_viewer_lat double precision DEFAULT NULL::double precision,
  p_viewer_lng double precision DEFAULT NULL::double precision,
  p_batch_id uuid DEFAULT extensions.gen_random_uuid(),
  p_force_seen_fallback boolean DEFAULT false
)
RETURNS TABLE(
  spot_id uuid,
  user_id uuid,
  vibe_tag_id uuid,
  caption text,
  latitude double precision,
  longitude double precision,
  location_name text,
  likes_count bigint,
  saves_count bigint,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  author_username text,
  author_profile_image_url text,
  author_is_private boolean,
  vibe_name text,
  primary_storage_path text,
  primary_public_url text,
  primary_storage_bucket text,
  source_bucket text,
  rank_position integer,
  ranking_score double precision,
  seen_before boolean,
  last_seen_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
#variable_conflict use_column
declare
    v_user_id uuid := auth.uid();
    v_limit integer := least(greatest(coalesce(p_limit, 24), 1), 50);
    v_unseen_count integer;
begin
    if v_user_id is null then
        raise exception 'get_home_feed_v1 requires auth.uid()';
    end if;

    with following as (
        select f.followee_id as author_id
        from public.follows f
        where f.follower_id = v_user_id
    ),
    blocked as (
        select ub.blocked_user_id as author_id
        from public.user_blocks ub
        where ub.blocker_id = v_user_id
        union
        select ub.blocker_id as author_id
        from public.user_blocks ub
        where ub.blocked_user_id = v_user_id
    ),
    eligible_unseen as (
        select s.id
          from public.spots s
          join public.users u on u.id = s.user_id
          left join following fl on fl.author_id = s.user_id
          left join blocked b on b.author_id = s.user_id
          left join public.feed_impressions fi on fi.user_id = v_user_id and fi.spot_id = s.id
          left join public.user_hidden_spots hs on hs.user_id = v_user_id and hs.spot_id = s.id
         where b.author_id is null
           and hs.spot_id is null
           and fi.spot_id is null
           and u.suspended_for_reports_at is null
           and coalesce(u.account_status, 'active') not in ('suspended', 'banned')
           and s.hidden_at is null
           and coalesce(s.moderation_status, 'approved') = 'approved'
           and (
                 s.user_id = v_user_id
              or coalesce(u.is_private, false) = false
              or fl.author_id is not null
           )
    )
    select count(*) into v_unseen_count from eligible_unseen;

    return query
    with following as (
        select f.followee_id as author_id
        from public.follows f
        where f.follower_id = v_user_id
    ),
    blocked as (
        select ub.blocked_user_id as author_id
        from public.user_blocks ub
        where ub.blocker_id = v_user_id
        union
        select ub.blocker_id as author_id
        from public.user_blocks ub
        where ub.blocked_user_id = v_user_id
    ),
    base as (
        select
            s.id as spot_id,
            s.user_id,
            s.vibe_tag_id,
            s.caption,
            s.latitude,
            s.longitude,
            s.location_name,
            s.likes_count,
            s.saves_count,
            s.created_at,
            s.updated_at,
            u.username as author_username,
            u.profile_image_url as author_profile_image_url,
            coalesce(u.is_private, false) as author_is_private,
            vt.name as vibe_name,
            (fl.author_id is not null) as is_followed,
            (fi.spot_id is not null) as seen_before,
            fi.last_seen_at,
            coalesce(uva.score, 0) as raw_vibe_score,
            coalesce(uca.score, 0) as raw_creator_score,
            case
                when p_viewer_lat is not null and p_viewer_lng is not null and s.location is not null then
                    ST_Distance(s.location, ST_SetSRID(ST_MakePoint(p_viewer_lng, p_viewer_lat), 4326)::geography)
                else null
            end as distance_meters
          from public.spots s
          join public.users u on u.id = s.user_id
          left join public.vibe_tags vt on vt.id = s.vibe_tag_id
          left join following fl on fl.author_id = s.user_id
          left join blocked b on b.author_id = s.user_id
          left join public.feed_impressions fi on fi.user_id = v_user_id and fi.spot_id = s.id
          left join public.user_hidden_spots hs on hs.user_id = v_user_id and hs.spot_id = s.id
          left join public.user_vibe_affinities uva on uva.user_id = v_user_id and uva.vibe_tag_id = s.vibe_tag_id
          left join public.user_creator_affinities uca on uca.user_id = v_user_id and uca.creator_id = s.user_id
         where b.author_id is null
           and hs.spot_id is null
           and u.suspended_for_reports_at is null
           and coalesce(u.account_status, 'active') not in ('suspended', 'banned')
           and s.hidden_at is null
           and coalesce(s.moderation_status, 'approved') = 'approved'
           and (
                 s.user_id = v_user_id
              or coalesce(u.is_private, false) = false
              or fl.author_id is not null
           )
           and (
                 v_unseen_count = 0
              or p_force_seen_fallback = true
              or fi.spot_id is null
           )
    ),
    scored as (
        select
            b.*,
            case
                when b.seen_before = false and b.is_followed = true then 'following_new'
                when b.seen_before = false then 'personalized_unseen'
                else 'seen_fallback'
            end as source_bucket,
            case
                when b.distance_meters is null then 0.5
                when b.distance_meters <= 25000 then 1.0
                else greatest(0.0, least(1.0, 25000.0 / nullif(b.distance_meters, 0)))
            end as distance_score,
            exp(-greatest(0, extract(epoch from (now() - b.created_at)) / 3600.0) / 72.0) as freshness_score,
            (1.0 / (1.0 + exp(-b.raw_vibe_score / 5.0))) as vibe_affinity_score,
            (1.0 / (1.0 + exp(-b.raw_creator_score / 5.0))) as creator_affinity_score
          from base b
    ),
    ranked as (
        select
            sc.*,
            case
                when sc.source_bucket = 'following_new' then 1000.0 + sc.freshness_score
                when sc.source_bucket = 'seen_fallback' then
                      0.10 * sc.freshness_score
                    + 0.45 * sc.vibe_affinity_score
                    + 0.35 * sc.creator_affinity_score
                    + 0.10 * sc.distance_score
                else
                      0.35 * sc.vibe_affinity_score
                    + 0.25 * sc.creator_affinity_score
                    + 0.15 * case when sc.is_followed then 1.0 else 0.0 end
                    + 0.15 * sc.freshness_score
                    + 0.10 * sc.distance_score
            end as ranking_score
          from scored sc
    ),
    final_rows as (
        select
            r.*,
            row_number() over (
                order by
                    case r.source_bucket when 'following_new' then 0 when 'personalized_unseen' then 1 else 2 end asc,
                    case when r.source_bucket = 'following_new' then r.created_at end desc nulls last,
                    case when r.source_bucket = 'following_new' then r.spot_id end desc nulls last,
                    case when r.source_bucket = 'seen_fallback' then r.last_seen_at end asc nulls first,
                    r.ranking_score desc,
                    r.created_at desc,
                    r.spot_id desc
            )::integer as rank_position
          from ranked r
         order by
            case r.source_bucket when 'following_new' then 0 when 'personalized_unseen' then 1 else 2 end asc,
            case when r.source_bucket = 'following_new' then r.created_at end desc nulls last,
            case when r.source_bucket = 'following_new' then r.spot_id end desc nulls last,
            case when r.source_bucket = 'seen_fallback' then r.last_seen_at end asc nulls first,
            r.ranking_score desc,
            r.created_at desc,
            r.spot_id desc
         limit v_limit
    ),
    with_primary_image as (
        select
            fr.*,
            img.storage_path as primary_storage_path,
            img.public_url as primary_public_url,
            img.storage_bucket as primary_storage_bucket
          from final_rows fr
          left join lateral (
            select si.storage_path, si.public_url, si.storage_bucket
              from public.spot_images si
             where si.spot_id = fr.spot_id
             order by si.sort_index asc
             limit 1
          ) img on true
    ),
    upserted as (
        insert into public.feed_impressions (
            user_id, spot_id, first_seen_at, last_seen_at, seen_count,
            first_source, last_source, first_rank, last_rank,
            first_score, last_score, first_batch_id, last_batch_id, updated_at
        )
        select
            v_user_id, wpi.spot_id, now(), now(), 1,
            wpi.source_bucket, wpi.source_bucket, wpi.rank_position, wpi.rank_position,
            wpi.ranking_score, wpi.ranking_score, p_batch_id, p_batch_id, now()
          from with_primary_image wpi
        on conflict (user_id, spot_id) do update set
            last_seen_at = now(),
            seen_count = public.feed_impressions.seen_count + 1,
            last_source = excluded.last_source,
            last_rank = excluded.last_rank,
            last_score = excluded.last_score,
            last_batch_id = excluded.last_batch_id,
            updated_at = now()
        returning spot_id
    )
    select
        wpi.spot_id,
        wpi.user_id,
        wpi.vibe_tag_id,
        wpi.caption,
        wpi.latitude,
        wpi.longitude,
        wpi.location_name,
        wpi.likes_count,
        wpi.saves_count,
        wpi.created_at,
        wpi.updated_at,
        wpi.author_username,
        wpi.author_profile_image_url,
        wpi.author_is_private,
        wpi.vibe_name,
        wpi.primary_storage_path,
        wpi.primary_public_url,
        wpi.primary_storage_bucket,
        wpi.source_bucket,
        wpi.rank_position,
        wpi.ranking_score,
        wpi.seen_before,
        wpi.last_seen_at
      from with_primary_image wpi
      where exists (select 1 from upserted u where u.spot_id = wpi.spot_id)
      order by wpi.rank_position asc;
end;
$function$;

GRANT EXECUTE ON FUNCTION public.get_home_feed_v1(
  integer, double precision, double precision, uuid, boolean
) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- get_map_spots_v1
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_map_spots_v1(
  double precision, double precision, double precision, double precision,
  double precision, double precision, integer
);

CREATE FUNCTION public.get_map_spots_v1(
  p_min_lat double precision,
  p_min_lng double precision,
  p_max_lat double precision,
  p_max_lng double precision,
  p_center_lat double precision,
  p_center_lng double precision,
  p_limit integer DEFAULT 250
)
RETURNS TABLE(
  spot_id uuid,
  user_id uuid,
  vibe_tag_id uuid,
  caption text,
  latitude double precision,
  longitude double precision,
  location_name text,
  created_at timestamp with time zone,
  author_username text,
  author_profile_image_url text,
  vibe_name text,
  primary_storage_path text,
  primary_public_url text,
  primary_storage_bucket text,
  distance_meters double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
declare
    v_user_id uuid := auth.uid();
    v_limit integer := least(greatest(coalesce(p_limit, 250), 1), 500);
begin
    if v_user_id is null then
        raise exception 'get_map_spots_v1 requires auth.uid()';
    end if;

    return query
    with following as (
        select f.followee_id as author_id
          from public.follows f
         where f.follower_id = v_user_id
    ),
    blocked as (
        select ub.blocked_user_id as author_id
          from public.user_blocks ub
         where ub.blocker_id = v_user_id
        union
        select ub.blocker_id as author_id
          from public.user_blocks ub
         where ub.blocked_user_id = v_user_id
    ),
    center_point as (
        select ST_SetSRID(ST_MakePoint(p_center_lng, p_center_lat), 4326)::geography as g
    ),
    boxed as (
        select s.*,
               ST_Distance(s.location, cp.g) as distance_meters
          from public.spots s
          cross join center_point cp
         where s.latitude between least(p_min_lat, p_max_lat) and greatest(p_min_lat, p_max_lat)
           and s.longitude between least(p_min_lng, p_max_lng) and greatest(p_min_lng, p_max_lng)
           and s.location is not null
    )
    select
        b.id as spot_id,
        b.user_id,
        b.vibe_tag_id,
        b.caption,
        b.latitude,
        b.longitude,
        b.location_name,
        b.created_at,
        u.username as author_username,
        u.profile_image_url as author_profile_image_url,
        vt.name as vibe_name,
        img.storage_path as primary_storage_path,
        img.public_url as primary_public_url,
        img.storage_bucket as primary_storage_bucket,
        b.distance_meters
      from boxed b
      join public.users u on u.id = b.user_id
      left join public.vibe_tags vt on vt.id = b.vibe_tag_id
      left join following fl on fl.author_id = b.user_id
      left join blocked bl on bl.author_id = b.user_id
      left join public.user_hidden_spots hs on hs.user_id = v_user_id and hs.spot_id = b.id
      left join lateral (
        select si.storage_path, si.public_url, si.storage_bucket
          from public.spot_images si
         where si.spot_id = b.id
         order by si.sort_index asc
         limit 1
      ) img on true
     where bl.author_id is null
       and hs.spot_id is null
       and (
             b.user_id = v_user_id
          or coalesce(u.is_private, false) = false
          or fl.author_id is not null
       )
     order by b.distance_meters asc, b.created_at desc, b.id desc
     limit v_limit;
end;
$function$;

GRANT EXECUTE ON FUNCTION public.get_map_spots_v1(
  double precision, double precision, double precision, double precision,
  double precision, double precision, integer
) TO anon, authenticated, service_role;
