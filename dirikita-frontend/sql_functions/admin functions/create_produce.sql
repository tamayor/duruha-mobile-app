-- ============================================================
-- create_produce
-- Creates a produce row + nested varieties + listings atomically.
--
-- Authorization:
--   Only users with role = 'ADMIN' may call this function.
--   Raises an exception for any other role.
--
-- Params:
--   p_user_id  uuid   – the acting user's id (role looked up from users)
--   p_payload  jsonb  – full nested object (see Flutter ProduceRepository)
--
-- Payload shape:
-- {
--   "english_name":            text,
--   "scientific_name":         text,
--   "base_unit":               text,
--   "image_url":               text,
--   "category":                text,
--   "storage_group":           text,
--   "respiration_rate":        text,   -- 'Low' | 'Medium' | 'High'
--   "is_ethylene_producer":    bool,
--   "is_ethylene_sensitive":   bool,
--   "crush_weight_tolerance":  int,    -- 1-5
--   "cross_contamination_risk":int,    -- 1-5 (or null)
--   "varieties": [
--     {
--       "variety_name":            text,
--       "is_native":               bool,
--       "breeding_type":           text,
--       "days_to_maturity_min":    int,
--       "days_to_maturity_max":    int,
--       "philippine_season":       text,
--       "flood_tolerance":         int,   -- 1-5
--       "handling_fragility":      int,   -- 1-5
--       "shelf_life_days":         int,
--       "optimal_storage_temp_c":  real,
--       "packaging_requirement":   text,
--       "appearance_desc":         text,
--       "image_url":               text,
--       "listings": [
--         {
--           "produce_form":              text,
--           "farmer_to_trader_price":    numeric,
--           "farmer_to_duruha_price":    numeric,
--           "duruha_to_consumer_price":  numeric,
--           "market_to_consumer_price":  numeric
--         }
--       ]
--     }
--   ]
-- }
--
-- Returns: uuid of the newly created produce row.
-- ============================================================
create or replace function public.create_produce(p_user_id uuid, p_payload jsonb) returns uuid language plpgsql security definer as $$
declare v_user_role public.user_role;
v_produce_id uuid;
v_variety_id uuid;
v_variety jsonb;
v_listing jsonb;
begin -- ── 0. Role check – ADMIN only ────────────────────────────────────────────
select role into v_user_role
from public.users
where id = p_user_id;
if not found then raise exception 'User % not found',
p_user_id;
end if;
if v_user_role <> 'ADMIN' then raise exception 'Permission denied: only ADMIN users can create produce (got role: %)',
v_user_role;
end if;
-- ── 1. Insert produce ────────────────────────────────────────────────────
insert into public.produce (
        english_name,
        scientific_name,
        base_unit,
        image_url,
        category,
        storage_group,
        respiration_rate,
        is_ethylene_producer,
        is_ethylene_sensitive,
        crush_weight_tolerance,
        cross_contamination_risk,
        updated_at
    )
values (
        p_payload->>'english_name',
        p_payload->>'scientific_name',
        p_payload->>'base_unit',
        p_payload->>'image_url',
        p_payload->>'category',
        p_payload->>'storage_group',
        p_payload->>'respiration_rate',
        coalesce(
            (p_payload->>'is_ethylene_producer')::boolean,
            false
        ),
        coalesce(
            (p_payload->>'is_ethylene_sensitive')::boolean,
            false
        ),
        coalesce(
            (p_payload->>'crush_weight_tolerance')::integer,
            5
        ),
        nullif(p_payload->>'cross_contamination_risk', '')::integer,
        now()
    )
returning id into v_produce_id;
-- ── 2. Insert varieties ──────────────────────────────────────────────────
for v_variety in
select *
from jsonb_array_elements(coalesce(p_payload->'varieties', '[]'::jsonb)) loop
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
        v_produce_id,
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
-- ── 3. Insert listings for this variety ──────────────────────────────
for v_listing in
select *
from jsonb_array_elements(coalesce(v_variety->'listings', '[]'::jsonb)) loop
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
end loop;
end loop;
return v_produce_id;
end;
$$;