-- ============================================================
-- update_produce
-- Updates an existing produce row + upserts nested varieties + listings.
--
-- Authorization rules (enforced inside the function):
--   • ADMIN role → can update produce details, varieties, AND listings
--   • Any other role (farmer, consumer, etc.) → can update produce
--     details and varieties only; listing writes are SILENTLY SKIPPED
--     (raises an exception instead – change to a silent skip if preferred)
--
-- Params:
--   p_user_id  uuid   – the acting user's id (role looked up from users)
--   p_id        uuid   – the produce row to update
--   p_payload   jsonb  – full nested object (same shape as create_produce)
--
-- Returns: p_id (the produce uuid, unchanged).
-- ============================================================
create or replace function public.update_produce(
        p_user_id uuid,
        p_id uuid,
        p_payload jsonb
    ) returns uuid language plpgsql security definer as $$
declare v_user_role public.user_role;
v_is_admin boolean;
v_variety_id uuid;
v_variety jsonb;
v_listing jsonb;
begin -- ── 0. Role check ────────────────────────────────────────────────────────
select role into v_user_role
from public.users
where id = p_user_id;
if not found then raise exception 'User % not found',
p_user_id;
end if;
v_is_admin := (v_user_role = 'ADMIN');
-- ── 1. Update produce ────────────────────────────────────────────────────
update public.produce
set english_name = CASE
        WHEN p_payload ? 'english_name' THEN p_payload->>'english_name'
        ELSE english_name
    END,
    scientific_name = CASE
        WHEN p_payload ? 'scientific_name' THEN p_payload->>'scientific_name'
        ELSE scientific_name
    END,
    base_unit = CASE
        WHEN p_payload ? 'base_unit' THEN p_payload->>'base_unit'
        ELSE base_unit
    END,
    image_url = CASE
        WHEN p_payload ? 'image_url' THEN p_payload->>'image_url'
        ELSE image_url
    END,
    category = CASE
        WHEN p_payload ? 'category' THEN p_payload->>'category'
        ELSE category
    END,
    storage_group = CASE
        WHEN p_payload ? 'storage_group' THEN p_payload->>'storage_group'
        ELSE storage_group
    END,
    respiration_rate = CASE
        WHEN p_payload ? 'respiration_rate' THEN p_payload->>'respiration_rate'
        ELSE respiration_rate
    END,
    is_ethylene_producer = CASE
        WHEN p_payload ? 'is_ethylene_producer' THEN coalesce(
            (p_payload->>'is_ethylene_producer')::boolean,
            false
        )
        ELSE is_ethylene_producer
    END,
    is_ethylene_sensitive = CASE
        WHEN p_payload ? 'is_ethylene_sensitive' THEN coalesce(
            (p_payload->>'is_ethylene_sensitive')::boolean,
            false
        )
        ELSE is_ethylene_sensitive
    END,
    crush_weight_tolerance = CASE
        WHEN p_payload ? 'crush_weight_tolerance' THEN coalesce(
            (p_payload->>'crush_weight_tolerance')::integer,
            5
        )
        ELSE crush_weight_tolerance
    END,
    cross_contamination_risk = CASE
        WHEN p_payload ? 'cross_contamination_risk' THEN nullif(p_payload->>'cross_contamination_risk', '')::integer
        ELSE cross_contamination_risk
    END,
    updated_at = now()
where id = p_id;
if not found then raise exception 'produce % not found',
p_id;
end if;
-- ── 2. Upsert varieties ──────────────────────────────────────────────────
if p_payload ? 'varieties' then for v_variety in
select *
from jsonb_array_elements(coalesce(p_payload->'varieties', '[]'::jsonb)) loop if v_variety->>'variety_id' is not null then -- UPDATE existing variety
update public.produce_varieties
set variety_name = v_variety->>'variety_name',
    is_native = coalesce((v_variety->>'is_native')::boolean, false),
    breeding_type = (v_variety->>'breeding_type')::public.breeding_category,
    days_to_maturity_min = nullif(v_variety->>'days_to_maturity_min', '')::integer,
    days_to_maturity_max = nullif(v_variety->>'days_to_maturity_max', '')::integer,
    philippine_season = (v_variety->>'philippine_season')::public.ph_season_type,
    flood_tolerance = nullif(v_variety->>'flood_tolerance', '')::integer,
    handling_fragility = nullif(v_variety->>'handling_fragility', '')::integer,
    shelf_life_days = coalesce(
        nullif(v_variety->>'shelf_life_days', '')::integer,
        7
    ),
    optimal_storage_temp_c = nullif(v_variety->>'optimal_storage_temp_c', '')::real,
    packaging_requirement = v_variety->>'packaging_requirement',
    appearance_desc = v_variety->>'appearance_desc',
    image_url = v_variety->>'image_url',
    updated_at = now()
where variety_id = (v_variety->>'variety_id')::uuid
    and produce_id = p_id
returning variety_id into v_variety_id;
if not found then v_variety_id := null;
end if;
end if;
-- INSERT new variety (no variety_id provided, or the update matched nothing)
if v_variety_id is null then
insert into public.produce_varieties (
        produce_id,
        variety_name,
        is_native,
        breeding_type,
        days_to_maturity_min,
        days_to_maturity_max,
        philippine_season,
        flood_tolerance,
        handling_fragility,
        shelf_life_days,
        optimal_storage_temp_c,
        packaging_requirement,
        appearance_desc,
        image_url,
        updated_at
    )
values (
        p_id,
        v_variety->>'variety_name',
        coalesce((v_variety->>'is_native')::boolean, false),
        (v_variety->>'breeding_type')::public.breeding_category,
        nullif(v_variety->>'days_to_maturity_min', '')::integer,
        nullif(v_variety->>'days_to_maturity_max', '')::integer,
        (v_variety->>'philippine_season')::public.ph_season_type,
        nullif(v_variety->>'flood_tolerance', '')::integer,
        nullif(v_variety->>'handling_fragility', '')::integer,
        coalesce(
            nullif(v_variety->>'shelf_life_days', '')::integer,
            7
        ),
        nullif(v_variety->>'optimal_storage_temp_c', '')::real,
        v_variety->>'packaging_requirement',
        v_variety->>'appearance_desc',
        v_variety->>'image_url',
        now()
    )
returning variety_id into v_variety_id;
end if;
-- ── 3. Upsert listings – ADMIN only ──────────────────────────────────
if not v_is_admin then -- Non-admin: skip listing writes entirely for this variety
v_variety_id := null;
continue;
end if;
for v_listing in
select *
from jsonb_array_elements(coalesce(v_variety->'listings', '[]'::jsonb)) loop if v_listing->>'listing_id' is not null then -- UPDATE existing listing
update public.produce_variety_listing
set produce_form = v_listing->>'produce_form',
    farmer_to_trader_price = coalesce(
        nullif(v_listing->>'farmer_to_trader_price', '')::numeric,
        0
    ),
    farmer_to_duruha_price = coalesce(
        nullif(v_listing->>'farmer_to_duruha_price', '')::numeric,
        0
    ),
    duruha_to_consumer_price = coalesce(
        nullif(v_listing->>'duruha_to_consumer_price', '')::numeric,
        0
    ),
    market_to_consumer_price = coalesce(
        nullif(v_listing->>'market_to_consumer_price', '')::numeric,
        0
    ),
    updated_at = now()
where listing_id = (v_listing->>'listing_id')::uuid
    and variety_id = v_variety_id;
if not found then -- listing_id stale / wrong variety → insert fresh
insert into public.produce_variety_listing (
        variety_id,
        produce_form,
        farmer_to_trader_price,
        farmer_to_duruha_price,
        duruha_to_consumer_price,
        market_to_consumer_price,
        updated_at
    )
values (
        v_variety_id,
        v_listing->>'produce_form',
        coalesce(
            nullif(v_listing->>'farmer_to_trader_price', '')::numeric,
            0
        ),
        coalesce(
            nullif(v_listing->>'farmer_to_duruha_price', '')::numeric,
            0
        ),
        coalesce(
            nullif(v_listing->>'duruha_to_consumer_price', '')::numeric,
            0
        ),
        coalesce(
            nullif(v_listing->>'market_to_consumer_price', '')::numeric,
            0
        ),
        now()
    );
end if;
else -- INSERT new listing (no listing_id)
insert into public.produce_variety_listing (
        variety_id,
        produce_form,
        farmer_to_trader_price,
        farmer_to_duruha_price,
        duruha_to_consumer_price,
        market_to_consumer_price,
        updated_at
    )
values (
        v_variety_id,
        v_listing->>'produce_form',
        coalesce(
            nullif(v_listing->>'farmer_to_trader_price', '')::numeric,
            0
        ),
        coalesce(
            nullif(v_listing->>'farmer_to_duruha_price', '')::numeric,
            0
        ),
        coalesce(
            nullif(v_listing->>'duruha_to_consumer_price', '')::numeric,
            0
        ),
        coalesce(
            nullif(v_listing->>'market_to_consumer_price', '')::numeric,
            0
        ),
        now()
    );
end if;
end loop;
-- reset for next iteration
v_variety_id := null;
end loop;
end if;
-- end varieties check
-- ── 4. Upsert dialects ──────────────────────────────────────────────────
-- Delete existing dialects for this produce, then re-insert from payload
if p_payload ? 'dialects' then
delete from public.produce_dialects
where produce_id = p_id;
declare v_dialect jsonb;
v_dialect_id uuid;
begin for v_dialect in
select *
from jsonb_array_elements(coalesce(p_payload->'dialects', '[]'::jsonb)) loop -- Look up dialect_id from dialect_name
select id into v_dialect_id
from public.dialects
where dialect_name = v_dialect->>'dialect_name';
if v_dialect_id is not null then
insert into public.produce_dialects (produce_id, dialect_id, local_name)
values (p_id, v_dialect_id, v_dialect->>'local_name');
end if;
end loop;
end;
end if;
-- end dialects check
return p_id;
end;
$$;