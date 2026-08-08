-- Complete, atomic Edit Spot mutation for ordered media, vibes, and location.
-- Replacement assets must already have passed the existing moderation pipeline.

alter table public.spot_images
  add column if not exists id uuid default gen_random_uuid();

update public.spot_images
set id = gen_random_uuid()
where id is null;

alter table public.spot_images
  alter column id set default gen_random_uuid(),
  alter column id set not null;

create unique index if not exists spot_images_id_uidx
  on public.spot_images (id);

create or replace function public.update_spot_editor_v1(
  p_spot_id uuid,
  p_vibe_tag_ids uuid[],
  p_latitude double precision,
  p_longitude double precision,
  p_location_name text,
  p_media_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_is_pro boolean;
  v_entitled_max_images integer;
  v_entitled_max_vibes integer;
  v_current_image_count integer;
  v_current_vibe_count integer;
  v_final_image_count integer;
  v_final_vibe_count integer;
  v_item jsonb;
  v_existing_image_id uuid;
  v_linked_image_id uuid;
  v_media_asset_id uuid;
  v_retained_image_ids uuid[] := '{}'::uuid[];
  v_new_asset_ids uuid[] := '{}'::uuid[];
  v_removed_asset_ids uuid[] := '{}'::uuid[];
  v_index integer := 0;
  v_vibe_id uuid;
  v_bucket text;
  v_path text;
  v_width integer;
  v_height integer;
  v_aspect_ratio numeric;
  v_display_aspect_ratio numeric;
  v_orientation text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select s.user_id
    into v_owner
  from public.spots s
  where s.id = p_spot_id
  for update;

  if v_owner is null then
    raise exception 'spot not found';
  end if;
  if v_owner <> v_uid then
    raise exception 'not authorized';
  end if;

  select count(*) into v_current_image_count
  from public.spot_images si
  where si.spot_id = p_spot_id;

  if p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    raise exception 'invalid coordinates';
  end if;
  if length(trim(coalesce(p_location_name, ''))) < 1 then
    raise exception 'location name required';
  end if;

  if p_media_items is null or jsonb_typeof(p_media_items) <> 'array' then
    raise exception 'p_media_items must be an array';
  end if;
  v_final_image_count := jsonb_array_length(p_media_items);
  if v_final_image_count < 1 then
    raise exception 'A spot needs at least one photo.';
  end if;

  if p_vibe_tag_ids is null then
    raise exception 'p_vibe_tag_ids required';
  end if;
  v_final_vibe_count := coalesce(array_length(p_vibe_tag_ids, 1), 0);
  if v_final_vibe_count < 1 then
    raise exception 'At least one vibe is required.';
  end if;
  if v_final_vibe_count <> (
    select count(distinct vibe_id)
    from unnest(p_vibe_tag_ids) as vibe_id
  ) then
    raise exception 'duplicate vibe_tag_ids';
  end if;

  select count(*) into v_current_vibe_count
  from public.spot_vibe_tags svt
  where svt.spot_id = p_spot_id;

  v_is_pro := coalesce(public.spot_user_effective_is_pro(v_uid), false);
  v_entitled_max_images := greatest(
    case when v_is_pro then 5 else 1 end,
    v_current_image_count
  );
  v_entitled_max_vibes := greatest(
    case when v_is_pro then 5 else 1 end,
    v_current_vibe_count
  );

  if v_final_image_count > v_entitled_max_images then
    raise exception 'Too many photos for this spot.';
  end if;
  if v_final_vibe_count > v_entitled_max_vibes then
    raise exception 'Too many vibes for this spot.';
  end if;

  foreach v_vibe_id in array p_vibe_tag_ids loop
    if not exists (
      select 1 from public.vibe_tags vt where vt.id = v_vibe_id
    ) then
      raise exception 'invalid vibe_tag_id';
    end if;
  end loop;

  -- Validate every final media reference before mutating any rows.
  for v_item in select value from jsonb_array_elements(p_media_items) loop
    v_existing_image_id := nullif(v_item->>'existing_image_id', '')::uuid;
    v_media_asset_id := nullif(v_item->>'media_asset_id', '')::uuid;

    if (v_existing_image_id is null) = (v_media_asset_id is null) then
      raise exception 'Each media item must contain exactly one media reference.';
    end if;

    if v_existing_image_id is not null then
      if v_existing_image_id = any(v_retained_image_ids) then
        raise exception 'duplicate existing image';
      end if;
      if not exists (
        select 1
        from public.spot_images si
        where si.id = v_existing_image_id
          and si.spot_id = p_spot_id
      ) then
        raise exception 'invalid existing image';
      end if;
      v_retained_image_ids := array_append(v_retained_image_ids, v_existing_image_id);
    else
      if v_media_asset_id = any(v_new_asset_ids) then
        raise exception 'duplicate media asset';
      end if;
      if not exists (
        select 1
        from public.media_assets ma
        where ma.id = v_media_asset_id
          and ma.owner_id = v_uid
          and ma.kind = 'spot_image'
          and ma.status = 'approved'
          and (ma.linked_spot_id is null or ma.linked_spot_id = p_spot_id)
          and ma.approved_bucket is not null
          and ma.approved_path is not null
      ) then
        raise exception 'invalid or unavailable media asset';
      end if;
      v_linked_image_id := null;
      select si.id into v_linked_image_id
      from public.spot_images si
      where si.spot_id = p_spot_id
        and si.media_asset_id = v_media_asset_id
      limit 1;
      if v_linked_image_id is not null then
        if v_linked_image_id = any(v_retained_image_ids) then
          raise exception 'duplicate existing image';
        end if;
        v_retained_image_ids := array_append(v_retained_image_ids, v_linked_image_id);
      end if;
      v_new_asset_ids := array_append(v_new_asset_ids, v_media_asset_id);
    end if;
  end loop;

  select coalesce(array_agg(si.media_asset_id), '{}'::uuid[])
    into v_removed_asset_ids
  from public.spot_images si
  where si.spot_id = p_spot_id
    and si.media_asset_id is not null
    and not (si.id = any(v_retained_image_ids));

  -- Move retained rows out of the 0...4 range before assigning final positions.
  update public.spot_images
  set sort_index = sort_index + 1000
  where spot_id = p_spot_id;

  delete from public.spot_images
  where spot_id = p_spot_id
    and not (id = any(v_retained_image_ids));

  v_index := 0;
  for v_item in select value from jsonb_array_elements(p_media_items) loop
    v_existing_image_id := nullif(v_item->>'existing_image_id', '')::uuid;
    v_media_asset_id := nullif(v_item->>'media_asset_id', '')::uuid;

    if v_existing_image_id is not null then
      update public.spot_images
      set sort_index = v_index
      where id = v_existing_image_id
        and spot_id = p_spot_id;
    else
      v_linked_image_id := null;
      select si.id into v_linked_image_id
      from public.spot_images si
      where si.spot_id = p_spot_id
        and si.media_asset_id = v_media_asset_id
      limit 1;

      if v_linked_image_id is not null then
        update public.spot_images
        set sort_index = v_index
        where id = v_linked_image_id;
        v_index := v_index + 1;
        continue;
      end if;

      select
        ma.approved_bucket,
        ma.approved_path,
        ma.width,
        ma.height
      into v_bucket, v_path, v_width, v_height
      from public.media_assets ma
      where ma.id = v_media_asset_id;

      if coalesce(v_width, 0) > 0 and coalesce(v_height, 0) > 0 then
        v_aspect_ratio := v_width::numeric / v_height::numeric;
        v_display_aspect_ratio := public.spot_clamp_display_aspect_ratio(v_aspect_ratio);
        if v_width::numeric > v_height::numeric * 1.05 then
          v_orientation := 'landscape';
        elsif v_height::numeric > v_width::numeric * 1.05 then
          v_orientation := 'portrait';
        else
          v_orientation := 'square';
        end if;
      else
        v_aspect_ratio := 1.0;
        v_display_aspect_ratio := 1.0;
        v_orientation := 'square';
      end if;

      insert into public.spot_images (
        spot_id,
        storage_path,
        public_url,
        sort_index,
        storage_bucket,
        media_asset_id,
        width,
        height,
        aspect_ratio,
        display_aspect_ratio,
        orientation
      )
      values (
        p_spot_id,
        v_path,
        v_path,
        v_index,
        v_bucket,
        v_media_asset_id,
        v_width,
        v_height,
        v_aspect_ratio,
        v_display_aspect_ratio,
        v_orientation
      );

      update public.media_assets
      set linked_spot_id = p_spot_id,
          updated_at = now()
      where id = v_media_asset_id;
    end if;
    v_index := v_index + 1;
  end loop;

  if cardinality(v_removed_asset_ids) > 0 then
    update public.media_assets
    set status = 'deleted',
        linked_spot_id = null,
        updated_at = now()
    where id = any(v_removed_asset_ids)
      and owner_id = v_uid;
  end if;

  delete from public.spot_vibe_tags where spot_id = p_spot_id;
  for v_index in 1..v_final_vibe_count loop
    insert into public.spot_vibe_tags (spot_id, vibe_tag_id, sort_order)
    values (p_spot_id, p_vibe_tag_ids[v_index], v_index - 1);
  end loop;

  update public.spots
  set vibe_tag_id = p_vibe_tag_ids[1],
      latitude = p_latitude,
      longitude = p_longitude,
      location_name = trim(coalesce(p_location_name, '')),
      media_count = v_final_image_count,
      media_display_aspect_ratio = (
        select si.display_aspect_ratio
        from public.spot_images si
        where si.spot_id = p_spot_id
        order by si.sort_index
        limit 1
      ),
      media_layout_version = 1
  where id = p_spot_id;
end;
$$;

revoke all on function public.update_spot_editor_v1(
  uuid, uuid[], double precision, double precision, text, jsonb
) from public;

grant execute on function public.update_spot_editor_v1(
  uuid, uuid[], double precision, double precision, text, jsonb
) to authenticated;

comment on function public.update_spot_editor_v1(
  uuid, uuid[], double precision, double precision, text, jsonb
) is 'Atomically updates an owned Spot draft after replacement images pass moderation.';
