-- ============================================================
-- DIRIKITA: MATCHING ALGORITHM + DELIVERY FEE CALCULATION
-- ============================================================
-- Schemas involved:
--   consumer_orders, consumer_orders_produce (cop),
--   consumer_orders_variety_group (covg),
--   consumer_orders_variety (cov)
--   farmer_offers (fo), farmer_offers_allocations (foa),
--   offer_order_match (oom),
--   produce_varieties (pv), produce_variety_listing (pvl),
--   users, user_consumers, user_farmers, user_carriers
-- ============================================================
-- ============================================================
-- SELECTION TYPE ENUM
-- Describes the outcome of the matching algorithm per cov row.
-- ============================================================
--
-- MATCHED    → This variety was selected by the algorithm as the winner
--              and successfully allocated to a farmer offer.
--
-- SKIPPED    → This variety was in the group but was NOT selected
--              (another variety won, or this one had no stock).
--
-- OPEN       → The entire group failed to fulfil the required quantity.
--              No foa/oom rows are created. Awaiting manual resolution
--              or re-matching when new offers arrive.
--
-- FULFILLED  → (reserved) Full quantity was met across allocations.
--              Can be used as a final-state stamp on cov rows
--              that contributed to a fully matched group.
--
-- DENIED     → (reserved) Explicitly rejected, e.g. by admin/farmer.
--
-- ============================================================
-- If not already created:
-- do $$ begin
--   create type public.selection_type as enum
--     ('MATCHED','SKIPPED','OPEN','FULFILLED','DENIED');
-- exception when duplicate_object then null; end $$;
-- ============================================================
-- ============================================================
-- SECTION 1: CONFIG TABLE (ALL TUNABLE CONSTANTS)
-- ============================================================
create table if not exists public.dirikita_config (
    key text primary key,
    value numeric not null,
    description text
);
insert into public.dirikita_config (key, value, description)
values (
        'consumer_max_days',
        30,
        'Max days ahead consumer date_needed is accepted'
    ),
    (
        'quality_fee_saver',
        0.00,
        'Saver: 0% quality fee on market price'
    ),
    (
        'quality_fee_regular',
        0.05,
        'Regular: 5% quality fee on market price'
    ),
    (
        'quality_fee_select',
        0.15,
        'Select: 15% quality fee on market price'
    ),
    (
        'free_shipping_threshold',
        2222,
        'PHP order total from one farmer to waive delivery fee entirely'
    ),
    (
        'road_factor',
        1.3,
        'Multiplier: straight-line km → estimated road km (PH roads)'
    ),
    (
        'van_threshold_kg',
        50,
        'Min kg from one farmer to apply van rate'
    ),
    (
        'truck_threshold_kg',
        150,
        'Min kg from one farmer to apply truck rate'
    ),
    (
        'rate_per_km_standard',
        12,
        'Standard rate PHP/km (small orders)'
    ),
    (
        'rate_per_km_van',
        8,
        'Van rate PHP/km (medium batch)'
    ),
    (
        'rate_per_km_truck',
        5,
        'Truck rate PHP/km (large batch)'
    ),
    (
        'local_max_km',
        30,
        'Max straight-line km to be considered local'
    ),
    (
        'local_base_fee',
        30,
        'Base fee PHP for local deliveries'
    ),
    (
        'far_base_fee',
        80,
        'Base fee PHP for far deliveries'
    ),
    (
        'far_surcharge',
        50,
        'Extra surcharge PHP for far deliveries'
    ),
    (
        'density_radius_km',
        2,
        'Radius km to count nearby consumer orders for density check'
    ),
    (
        'density_high_min_orders',
        5,
        'Min nearby orders to qualify for high density discount'
    ),
    (
        'density_mid_min_orders',
        2,
        'Min nearby orders to qualify for medium density discount'
    ),
    (
        'density_high_discount',
        0.50,
        'High density: 50% off delivery fee'
    ),
    (
        'density_mid_discount',
        0.25,
        'Medium density: 25% off delivery fee'
    ),
    (
        'combined_ship_min_items',
        5,
        'Min distinct items from same farmer to apply combined shipping'
    ),
    (
        'base_delivery_fee',
        45,
        'Flat base delivery fee PHP added to every order regardless of distance'
    ),
    (
        'local_search_radius_km',
        30,
        'Initial search radius km for local-priority farmer matching'
    ),
    (
        'score_w_proximity',
        0.50,
        'Farmer score weight: proximity to consumer'
    ),
    (
        'score_w_harvest',
        0.30,
        'Farmer score weight: harvest timing / peak season match'
    ),
    (
        'score_w_efficiency',
        0.20,
        'Farmer score weight: can fulfill full quantity in one go'
    ) on conflict (key) do nothing;
-- Convenience reader
create or replace function om_cfg(p_key text) returns numeric language sql stable as $$
select value
from dirikita_config
where key = p_key;
$$;
-- ============================================================
-- SECTION 2: DELIVERY FEE CALCULATION
-- ============================================================
create or replace function om_calculate_delivery_fee(
        p_consumer_id text,
        p_farmer_id text,
        p_total_kg numeric,
        p_order_amount numeric,
        p_item_count integer
    ) returns numeric language plpgsql stable as $$
declare v_consumer_loc geography;
v_farmer_loc geography;
v_straight_km numeric;
v_road_km numeric;
v_rate_per_km numeric;
v_base_fee numeric;
v_surcharge numeric := 0;
v_gross_fee numeric;
v_nearby_count integer;
v_density_disc numeric := 0;
v_net_fee numeric;
v_per_item_fee numeric;
begin -- 1. FREE SHIPPING CHECK
if p_order_amount >= om_cfg('free_shipping_threshold') then return om_cfg('base_delivery_fee');
end if;
-- 2. FETCH LOCATIONS
select u.location into v_consumer_loc
from user_consumers uc
    join users u on u.id = uc.user_id
where uc.consumer_id = p_consumer_id
limit 1;
select u.location into v_farmer_loc
from user_farmers uf
    join users u on u.id = uf.user_id
where uf.farmer_id = p_farmer_id
limit 1;
if v_consumer_loc is null
or v_farmer_loc is null then return om_cfg('far_base_fee') + om_cfg('far_surcharge') + om_cfg('base_delivery_fee');
end if;
-- 3. DISTANCE
v_straight_km := ST_Distance(v_consumer_loc, v_farmer_loc) / 1000.0;
v_road_km := v_straight_km * om_cfg('road_factor');
-- 4. BATCH RATE
if p_total_kg >= om_cfg('truck_threshold_kg') then v_rate_per_km := om_cfg('rate_per_km_truck');
elsif p_total_kg >= om_cfg('van_threshold_kg') then v_rate_per_km := om_cfg('rate_per_km_van');
else v_rate_per_km := om_cfg('rate_per_km_standard');
end if;
-- 5. DISTANCE TIER
if v_straight_km <= om_cfg('local_max_km') then v_base_fee := om_cfg('local_base_fee');
v_surcharge := 0;
else v_base_fee := om_cfg('far_base_fee');
v_surcharge := om_cfg('far_surcharge');
end if;
-- 6. GROSS FEE
v_gross_fee := v_base_fee + (v_road_km * v_rate_per_km) + v_surcharge;
-- 7. BAYANIHAN DENSITY DISCOUNT
select count(distinct co.consumer_id) into v_nearby_count
from consumer_orders co
    join user_consumers uc2 on uc2.consumer_id = co.consumer_id
    join users u2 on u2.id = uc2.user_id
where co.consumer_id <> p_consumer_id
    and co.is_active = true
    and ST_DWithin(
        u2.location,
        v_consumer_loc,
        om_cfg('density_radius_km') * 1000
    );
if v_nearby_count >= om_cfg('density_high_min_orders') then v_density_disc := om_cfg('density_high_discount');
elsif v_nearby_count >= om_cfg('density_mid_min_orders') then v_density_disc := om_cfg('density_mid_discount');
end if;
v_net_fee := v_gross_fee * (1 - v_density_disc);
-- 8. COMBINED SHIPPING
if p_item_count >= om_cfg('combined_ship_min_items')::integer then v_per_item_fee := v_net_fee / p_item_count;
else v_per_item_fee := v_net_fee;
end if;
v_per_item_fee := v_per_item_fee + om_cfg('base_delivery_fee');
return round(v_per_item_fee, 2);
end;
$$;
-- ============================================================
-- SECTION 3: FARMER SCORING
-- ============================================================
create or replace function om_score_farmer_offer(
        p_consumer_id text,
        p_farmer_id text,
        p_offer_id uuid,
        p_quantity numeric,
        p_date_needed date
    ) returns numeric language plpgsql stable as $$
declare v_consumer_loc geography;
v_farmer_loc geography;
v_distance_km numeric;
v_local_max numeric := om_cfg('local_search_radius_km');
v_proximity_score numeric;
v_harvest_score numeric;
v_efficiency_score numeric;
v_final_score numeric;
v_remaining numeric;
v_peak_months text [];
v_current_month text;
begin -- PROXIMITY
select u.location into v_consumer_loc
from user_consumers uc
    join users u on u.id = uc.user_id
where uc.consumer_id = p_consumer_id
limit 1;
select u.location into v_farmer_loc
from user_farmers uf
    join users u on u.id = uf.user_id
where uf.farmer_id = p_farmer_id
limit 1;
if v_consumer_loc is null
or v_farmer_loc is null then v_proximity_score := 0.1;
else v_distance_km := ST_Distance(v_consumer_loc, v_farmer_loc) / 1000.0;
v_proximity_score := greatest(0, 1 - (v_distance_km / v_local_max));
end if;
-- HARVEST TIMING
v_current_month := to_char(p_date_needed, 'Mon');
select pv.peak_months into v_peak_months
from farmer_offers fo
    join produce_varieties pv on pv.variety_id = fo.variety_id
where fo.offer_id = p_offer_id
limit 1;
if v_peak_months is not null
and v_current_month = any(v_peak_months) then v_harvest_score := 1.0;
else v_harvest_score := 0.3;
end if;
-- EFFICIENCY
select fo.remaining_quantity into v_remaining
from farmer_offers fo
where fo.offer_id = p_offer_id;
if v_remaining >= p_quantity then v_efficiency_score := 1.0;
else v_efficiency_score := v_remaining / p_quantity;
end if;
v_final_score := (v_proximity_score * om_cfg('score_w_proximity')) + (v_harvest_score * om_cfg('score_w_harvest')) + (
    v_efficiency_score * om_cfg('score_w_efficiency')
);
return round(v_final_score, 4);
end;
$$;
-- ============================================================
-- SECTION 4: MAIN MATCHING FUNCTION
-- ============================================================
-- selection_type states written to consumer_orders_variety:
--
--   MATCHED  → winning variety row that received allocations
--   SKIPPED  → other varieties in the group that were not used
--   OPEN     → ALL cov rows in the group when the algorithm
--               could not fulfil the quantity at all
--               (no foa / oom rows are created for OPEN groups)
--
-- Payload shape (unchanged from previous version):
-- {
--   "payment_method": "Cash"|"GCash"|...,
--   "p_orders": [
--     {
--       "produce_id": "uuid",
--       "quality": "Saver"|"Regular"|"Select",
--       "order_items": [
--         {
--           "variety_ids": ["uuid", ...],   -- empty/[""] = is_any
--           "form": "Raw"|"Milled"|...,
--           "quantity": 100,
--           "date_needed": "2026-03-05",
--           "cpls_id": "uuid|null"          -- consumer price lock subscription
--         }
--       ]
--     }
--   ]
-- }
-- ============================================================
create or replace function om_place_and_match_order(
        p_payload jsonb,
        p_note text default null
    ) returns jsonb language plpgsql security definer as $$
declare -- auth
    v_auth_uid uuid;
p_consumer_id text;
-- order level
v_order_id uuid;
v_orders_arr jsonb;
v_order_obj jsonb;
v_order_payment_method public.payment_method;
-- produce level
v_produce_id uuid;
v_quality text;
v_quality_fee_rate numeric;
v_cop_id uuid;
v_cop_quality_fee numeric;
-- item level
v_items_arr jsonb;
v_item_obj jsonb;
v_variety_ids jsonb;
v_winning_variety_id uuid;
v_form text;
v_quantity numeric;
v_remaining_needed numeric;
v_date_needed date;
v_is_any boolean;
v_item_index integer;
-- covg / cov
v_covg_id uuid;
v_cov_id uuid;
v_cov_k integer;
-- offer loop
v_offer record;
v_alloc_qty numeric;
v_listing_id uuid;
v_consumer_price numeric;
v_farmer_price numeric;
v_farmer_is_price_locked boolean;
v_farmer_lock_credit numeric;
v_farmer_lock_deduct numeric;
v_farmer_fpls_id uuid;
v_used_offer_ids uuid [] := '{}';
v_foa_id uuid;
v_oom_id uuid;
-- delivery
v_delivery_fee numeric;
v_default_carrier text := 'car_000001';
-- quality fee
v_quality_fee_amt numeric;
v_total_market_val numeric;
-- price lock (consumer)
v_item_cpls_id uuid;
v_item_price_lock boolean;
v_cpls_id uuid;
v_lock_price numeric;
v_lock_total_value numeric;
v_cpls_remaining numeric;
-- result
v_result jsonb;
v_success_count integer := 0;
v_failed_count integer := 0;
v_errors jsonb := '[]'::jsonb;
-- loop counters
i integer;
j integer;
begin -- --------------------------------------------------------
-- 0. RESOLVE consumer_id FROM auth.uid()
-- --------------------------------------------------------
v_auth_uid := auth.uid();
if v_auth_uid is null then raise exception 'user_id is required' using hint = 'Bad Request',
errcode = 'P0001';
end if;
select uc.consumer_id into p_consumer_id
from user_consumers uc
where uc.user_id = v_auth_uid
limit 1;
if p_consumer_id is null then raise exception 'No consumer profile found for this user' using hint = 'Bad Request',
errcode = 'P0001';
end if;
-- --------------------------------------------------------
-- 1. CREATE consumer_orders record
-- --------------------------------------------------------
v_order_payment_method := coalesce(
    (p_payload->>'payment_method')::public.payment_method,
    'Cash'::public.payment_method
);
insert into consumer_orders (consumer_id, note, is_active, payment_method)
values (
        p_consumer_id,
        p_note,
        true,
        v_order_payment_method
    )
returning order_id into v_order_id;
if jsonb_typeof(p_payload) = 'array' then v_orders_arr := p_payload;
else v_orders_arr := p_payload->'p_orders';
end if;
if v_orders_arr is null
or jsonb_array_length(v_orders_arr) = 0 then raise exception 'p_orders array is missing or empty' using hint = 'Bad Request',
errcode = 'P0001';
end if;
-- --------------------------------------------------------
-- 2. LOOP EACH PRODUCE GROUP
-- --------------------------------------------------------
for i in 0..jsonb_array_length(v_orders_arr) - 1 loop v_order_obj := v_orders_arr->i;
v_produce_id := (v_order_obj->>'produce_id')::uuid;
v_quality := v_order_obj->>'quality';
v_quality_fee_rate := case
    v_quality
    when 'Saver' then om_cfg('quality_fee_saver')
    when 'Regular' then om_cfg('quality_fee_regular')
    when 'Select' then om_cfg('quality_fee_select')
    else 0
end;
insert into consumer_orders_produce (order_id, quality, produce_id, quality_fee)
values (
        v_order_id,
        v_quality::public.quality,
        v_produce_id,
        0
    )
returning cop_id into v_cop_id;
v_cop_quality_fee := 0;
-- --------------------------------------------------------
-- 3. LOOP EACH ORDER ITEM (variety slot / group)
-- --------------------------------------------------------
v_items_arr := v_order_obj->'order_items';
for j in 0..jsonb_array_length(v_items_arr) - 1 loop v_item_obj := v_items_arr->j;
v_variety_ids := v_item_obj->'variety_ids';
v_form := v_item_obj->>'form';
v_quantity := (v_item_obj->>'quantity')::numeric;
v_date_needed := (v_item_obj->>'date_needed')::date;
v_item_index := j;
v_remaining_needed := v_quantity;
v_total_market_val := 0;
v_used_offer_ids := '{}';
-- Consumer price lock setup
v_item_cpls_id := (v_item_obj->>'cpls_id')::uuid;
v_item_price_lock := false;
v_cpls_id := null;
v_lock_price := null;
v_lock_total_value := 0;
v_cpls_remaining := 0;
if v_order_payment_method = 'Cash'::public.payment_method
and v_item_cpls_id is not null then
select cpls.cpls_id,
    coalesce(cpls.remaining_credits, 0) into v_cpls_id,
    v_cpls_remaining
from consumer_price_lock_subscriptions cpls
where cpls.cpls_id = v_item_cpls_id
    and cpls.consumer_id = p_consumer_id
    and cpls.status = 'active'
    and cpls.ends_at > now()
limit 1;
if v_cpls_id is not null then v_item_price_lock := true;
end if;
end if;
-- Detect is_any
v_is_any := false;
if jsonb_array_length(v_variety_ids) = 0 then v_is_any := true;
elsif jsonb_array_length(v_variety_ids) = 1
and (v_variety_ids->>0) = '' then v_is_any := true;
end if;
-- --------------------------------------------------------
-- 4. INSERT consumer_orders_variety_group (covg)
--    cpls_id is written as null here — it is only stamped
--    back after the offer loop confirms the lock was actually
--    applied (i.e. credits were sufficient).  This prevents
--    covg from referencing a subscription that ended up not
--    being used due to insufficient remaining_credits.
-- --------------------------------------------------------
insert into consumer_orders_variety_group (
        item_index,
        form,
        quantity,
        is_any,
        cop_id,
        date_needed,
        cpls_id
    )
values (
        v_item_index,
        v_form,
        v_quantity,
        v_is_any,
        v_cop_id,
        v_date_needed,
        null
    )
returning covg_id into v_covg_id;
-- --------------------------------------------------------
-- 4b. PRE-INSERT cov rows — ALL varieties in the list,
--     ordered by priority score so the best variety is
--     item_index 0.  All start as SKIPPED; the offer loop
--     flips each one to MATCHED as it gets allocated.
--     For is_any groups, cov rows are created on-the-fly.
-- --------------------------------------------------------
v_cov_k := -1;
if not v_is_any then
declare v_pre_rec record;
begin for v_pre_rec in
select (val.v)::uuid as variety_uuid,
    pvl.listing_id as listing_id,
    pvl.duruha_to_consumer_price as unit_price,
    coalesce(
        (
            select sum(fo2.remaining_quantity)
            from farmer_offers fo2
            where fo2.variety_id = (val.v)::uuid
                and fo2.is_active = true
                and fo2.remaining_quantity > 0
                and (
                    fo2.available_from is null
                    or fo2.available_from <= v_date_needed
                )
        ),
        0
    ) as total_stock
from jsonb_array_elements_text(v_variety_ids) as val(v)
    join produce_variety_listing pvl on pvl.variety_id = (val.v)::uuid
    and lower(pvl.produce_form) = lower(v_form)
where val.v <> ''
order by -- 1. Has stock at all
    case
        when coalesce(
            (
                select sum(fo2.remaining_quantity)
                from farmer_offers fo2
                where fo2.variety_id = (val.v)::uuid
                    and fo2.is_active = true
                    and fo2.remaining_quantity > 0
                    and (
                        fo2.available_from is null
                        or fo2.available_from <= v_date_needed
                    )
            ),
            0
        ) > 0 then 0
        else 1
    end asc,
    -- 2. Closest farmer
    (
        select min(
                case
                    when u2.location is not null
                    and uc_u2.location is not null then ST_Distance(u2.location, uc_u2.location)
                    else 999999999
                end
            )
        from farmer_offers fo2
            join user_farmers uf2 on uf2.farmer_id = fo2.farmer_id
            join users u2 on u2.id = uf2.user_id
            join user_consumers uc2 on uc2.consumer_id = p_consumer_id
            join users uc_u2 on uc_u2.id = uc2.user_id
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
            and (
                fo2.available_from is null
                or fo2.available_from <= v_date_needed
            )
    ) asc,
    -- 3. Most total stock (take as much as possible first)
    coalesce(
        (
            select sum(fo2.remaining_quantity)
            from farmer_offers fo2
            where fo2.variety_id = (val.v)::uuid
                and fo2.is_active = true
                and fo2.remaining_quantity > 0
                and (
                    fo2.available_from is null
                    or fo2.available_from <= v_date_needed
                )
        ),
        0
    ) desc,
    -- 4. available_from nearest to date_needed
    (
        select min(
                abs(
                    coalesce(fo2.available_from, v_date_needed) - v_date_needed
                )
            )
        from farmer_offers fo2
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
    ) asc loop v_cov_k := v_cov_k + 1;
insert into consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        selection_type,
        variable_consumer_price,
        price_lock
    )
values (
        v_covg_id,
        v_cov_k,
        v_pre_rec.variety_uuid,
        v_pre_rec.listing_id,
        false,
        'SKIPPED'::public.selection_type,
        v_pre_rec.unit_price,
        v_pre_rec.unit_price
    );
end loop;
end;
end if;
-- --------------------------------------------------------
-- 6. FILL ORDER: local-radius pass
--    Iterate ranked offers, allocate until fully fulfilled
-- --------------------------------------------------------
for v_offer in with ranked_offers as (
    select fo.offer_id,
        fo.farmer_id,
        fo.variety_id,
        fo.remaining_quantity,
        fo.listing_id,
        fo.is_price_locked as farmer_is_price_locked,
        fo.remaining_price_lock_credit as farmer_lock_credit,
        fo.fpls_id as farmer_fpls_id,
        fo.available_from,
        fo.available_to,
        pvl.duruha_to_consumer_price as variable_consumer_price,
        pvl.farmer_to_duruha_price as variable_farmer_price,
        pvl.listing_id as pvl_listing_id,
        om_score_farmer_offer(
            p_consumer_id,
            fo.farmer_id,
            fo.offer_id,
            v_remaining_needed,
            v_date_needed
        ) as match_score,
        row_number() over (
            partition by fo.offer_id
            order by pvl.listing_id
        ) as rn
    from farmer_offers fo
        join produce_varieties pv on pv.variety_id = fo.variety_id
        join produce_variety_listing pvl on pvl.listing_id = fo.listing_id
        or (
            fo.listing_id is null
            and pvl.variety_id = fo.variety_id
            and lower(pvl.produce_form) = lower(v_form)
        )
    where pv.produce_id = v_produce_id
        and lower(pvl.produce_form) = lower(v_form)
        and fo.is_active = true
        and fo.remaining_quantity > 0
        and (
            fo.available_from is null
            or fo.available_from <= v_date_needed
        ) -- specific variety: restrict to winner; is_any: local radius only
        and (
            v_is_any = false
            or fo.variety_id = v_winning_variety_id
            or exists (
                select 1
                from user_farmers uf
                    join users u on u.id = uf.user_id
                    join user_consumers uc on uc.consumer_id = p_consumer_id
                    join users uc_u on uc_u.id = uc.user_id
                where uf.farmer_id = fo.farmer_id
                    and (
                        u.location is null
                        or uc_u.location is null
                        or ST_DWithin(
                            u.location,
                            uc_u.location,
                            om_cfg('local_search_radius_km') * 1000
                        )
                    )
            )
        )
        and (
            -- is_any: already filtered by local radius above
            -- specific: restrict to varieties in the payload list
            v_is_any = true
            or fo.variety_id in (
                select (val.v)::uuid
                from jsonb_array_elements_text(v_variety_ids) as val(v)
                where val.v <> ''
            )
        )
)
select offer_id,
    farmer_id,
    variety_id,
    remaining_quantity,
    listing_id,
    farmer_is_price_locked,
    farmer_lock_credit,
    farmer_fpls_id,
    variable_consumer_price,
    variable_farmer_price,
    pvl_listing_id,
    match_score
from ranked_offers
where rn = 1
order by match_score desc,
    abs(
        coalesce(available_from, v_date_needed) - v_date_needed
    ) asc,
    abs(
        coalesce(available_to, v_date_needed) - v_date_needed
    ) asc,
    remaining_quantity desc,
    coalesce(available_to, v_date_needed) - v_date_needed desc loop exit
    when v_remaining_needed <= 0;
v_alloc_qty := least(v_remaining_needed, v_offer.remaining_quantity);
v_consumer_price := v_offer.variable_consumer_price;
v_farmer_price := v_offer.variable_farmer_price;
v_listing_id := v_offer.pvl_listing_id;
v_farmer_is_price_locked := coalesce(v_offer.farmer_is_price_locked, false);
v_farmer_lock_credit := coalesce(v_offer.farmer_lock_credit, 0);
v_farmer_lock_deduct := v_alloc_qty * v_farmer_price;
v_farmer_fpls_id := v_offer.farmer_fpls_id;
-- ------------------------------------------------
-- 6a. CONSUMER PRICE LOCK — resolve BEFORE any writes
--
                --     We now know v_consumer_price and v_alloc_qty so
--     we can compute the exact credit cost and decide
--     whether the lock actually applies for this
--     allocation.  All subsequent inserts use the
--     resolved v_item_price_lock flag so cov, foa and
--     oom are always written with the correct state.
-- ------------------------------------------------
if v_item_price_lock
and v_cpls_id is not null then v_lock_price := v_consumer_price;
v_lock_total_value := v_lock_price * v_alloc_qty;
if v_lock_total_value > v_cpls_remaining then -- Insufficient credits → downgrade to no lock for this allocation
v_item_price_lock := false;
v_cpls_id := null;
else -- Deduct now so the flag stays true for all writes below
update consumer_price_lock_subscriptions
set remaining_credits = remaining_credits - v_lock_total_value,
    updated_at = now()
where cpls_id = v_cpls_id;
v_cpls_remaining := v_cpls_remaining - v_lock_total_value;
end if;
end if;
-- ------------------------------------------------
-- 6b / 6c. RESOLVE cov for this allocation
--
--   is_any=true  → insert new cov row as MATCHED (auto-assigned)
--   is_any=false → flip the pre-inserted SKIPPED row for
--                  this specific variety to MATCHED.
--                  Multiple varieties may be MATCHED in the
--                  same group as the fill cascades through
--                  the priority-ordered list.
-- ------------------------------------------------
if v_is_any then v_cov_k := v_cov_k + 1;
insert into consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        selection_type,
        variable_consumer_price,
        price_lock,
        final_price
    )
values (
        v_covg_id,
        v_cov_k,
        v_offer.variety_id,
        v_listing_id,
        true,
        'MATCHED'::public.selection_type,
        v_consumer_price,
        v_consumer_price,
        case
            when v_item_price_lock then v_consumer_price
            else null
        end
    )
returning cov_id into v_cov_id;
else -- For specific varieties: the cov row may already be MATCHED
-- (a previous offer for the same variety already flipped it).
-- If still SKIPPED → flip to MATCHED and capture cov_id.
-- If already MATCHED → just reuse the existing cov_id.
update consumer_orders_variety
set selection_type = 'MATCHED'::public.selection_type,
    variable_consumer_price = v_consumer_price,
    price_lock = v_consumer_price,
    final_price = case
        when v_item_price_lock then v_consumer_price
        else null
    end
where covg_id = v_covg_id
    and variety_id = v_offer.variety_id
    and selection_type = 'SKIPPED'::public.selection_type
returning cov_id into v_cov_id;
-- If already MATCHED by a prior offer, fetch the existing cov_id
if v_cov_id is null then
select cov_id into v_cov_id
from consumer_orders_variety
where covg_id = v_covg_id
    and variety_id = v_offer.variety_id
    and selection_type = 'MATCHED'::public.selection_type
limit 1;
end if;
end if;
-- Guard: skip foa/oom entirely if cov_id could not be resolved
if v_cov_id is null then raise warning 'Skipping allocation: cov_id is null for variety % in covg %',
v_offer.variety_id,
v_covg_id;
continue;
end if;
-- ------------------------------------------------
-- 6d. CREATE foa
-- ------------------------------------------------
if v_farmer_is_price_locked
and v_farmer_lock_credit >= v_farmer_lock_deduct then
insert into farmer_offers_allocations (
        offer_id,
        quantity,
        variable_farmer_price,
        price_lock,
        final_price,
        fpls_id,
        is_paid,
        cov_id
    )
values (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        v_farmer_price,
        v_farmer_fpls_id,
        false,
        v_cov_id
    )
returning foa_id into v_foa_id;
update farmer_offers
set remaining_price_lock_credit = remaining_price_lock_credit - v_farmer_lock_deduct,
    remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = now()
where offer_id = v_offer.offer_id;
else
insert into farmer_offers_allocations (
        offer_id,
        quantity,
        variable_farmer_price,
        price_lock,
        final_price,
        fpls_id,
        is_paid,
        cov_id
    )
values (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        null,
        -- final_price null until settled
        null,
        false,
        v_cov_id
    )
returning foa_id into v_foa_id;
update farmer_offers
set remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = now()
where offer_id = v_offer.offer_id;
end if;
v_used_offer_ids := array_append(v_used_offer_ids, v_offer.offer_id);
-- ------------------------------------------------
-- 6e. QUALITY FEE accumulation
-- ------------------------------------------------
v_quality_fee_amt := coalesce(v_consumer_price, 0) * v_alloc_qty * v_quality_fee_rate;
v_total_market_val := v_total_market_val + coalesce(v_consumer_price, 0) * v_alloc_qty;
v_cop_quality_fee := v_cop_quality_fee + v_quality_fee_amt;
-- ------------------------------------------------
-- 6f. DELIVERY FEE — calculate but defer final write
--     We collect all oom rows per variety first, then
--     in step 6g we zero out all but the most expensive.
-- ------------------------------------------------
v_delivery_fee := om_calculate_delivery_fee(
    p_consumer_id,
    v_offer.farmer_id,
    v_alloc_qty,
    coalesce(v_consumer_price, 0) * v_alloc_qty,
    1
);
-- ------------------------------------------------
-- 6g. CREATE oom — store with calculated fee for now
-- ------------------------------------------------
insert into offer_order_match (
        cov_id,
        foa_id,
        delivery_status,
        dispatch_at,
        delivery_fee,
        carrier_id,
        consumer_has_paid
    )
values (
        v_cov_id,
        v_foa_id,
        'PENDING',
        '2100-01-01 00:00:00+00'::timestamptz,
        v_delivery_fee,
        v_default_carrier,
        v_order_payment_method <> 'Cash'::public.payment_method
    )
returning oom_id into v_oom_id;
v_success_count := v_success_count + 1;
v_remaining_needed := v_remaining_needed - v_alloc_qty;
end loop;
-- local pass
-- ------------------------------------------------
-- 6h. DELIVERY FEE RESOLUTION per variety
--     For each MATCHED cov in this group, keep only
--     ONE oom row with the highest delivery fee.
--     All other oom rows for that cov get zeroed.
--     Handles:
--       • 1 offer          → fee unchanged, nothing zeroed
--       • N offers, diff fees → max fee kept, rest → 0
--       • N offers, same fee → 1 arbitrary kept, rest → 0
--         (resolved by picking lowest oom_id as keeper)
-- ------------------------------------------------
update offer_order_match oom_zero
set delivery_fee = 0
from consumer_orders_variety cov_m
where cov_m.covg_id = v_covg_id
    and cov_m.selection_type = 'MATCHED'::public.selection_type
    and oom_zero.cov_id = cov_m.cov_id
    and oom_zero.oom_id <> (
        -- keeper: highest fee; tie-break by lowest oom_id (deterministic)
        select oom_keep.oom_id
        from offer_order_match oom_keep
        where oom_keep.cov_id = cov_m.cov_id
        order by oom_keep.delivery_fee desc,
            oom_keep.oom_id asc
        limit 1
    );
-- --------------------------------------------------------
-- FALLBACK: widen geo search for is_any if still unfulfilled
-- --------------------------------------------------------
if v_is_any
and v_remaining_needed > 0 then for v_offer in with ranked_offers as (
    select fo.offer_id,
        fo.farmer_id,
        fo.variety_id,
        fo.remaining_quantity,
        fo.listing_id,
        fo.is_price_locked as farmer_is_price_locked,
        fo.remaining_price_lock_credit as farmer_lock_credit,
        fo.fpls_id as farmer_fpls_id,
        fo.available_from,
        fo.available_to,
        pvl.duruha_to_consumer_price as variable_consumer_price,
        pvl.farmer_to_duruha_price as variable_farmer_price,
        pvl.listing_id as pvl_listing_id,
        om_score_farmer_offer(
            p_consumer_id,
            fo.farmer_id,
            fo.offer_id,
            v_remaining_needed,
            v_date_needed
        ) as match_score,
        row_number() over (
            partition by fo.offer_id
            order by pvl.listing_id
        ) as rn
    from farmer_offers fo
        join produce_varieties pv on pv.variety_id = fo.variety_id
        join produce_variety_listing pvl on pvl.listing_id = fo.listing_id
        or (
            fo.listing_id is null
            and pvl.variety_id = fo.variety_id
            and lower(pvl.produce_form) = lower(v_form)
        )
    where pv.produce_id = v_produce_id
        and lower(pvl.produce_form) = lower(v_form)
        and fo.is_active = true
        and fo.remaining_quantity > 0
        and (
            fo.available_from is null
            or fo.available_from <= v_date_needed
        ) -- exclude offers already used in local pass
        and (
            cardinality(v_used_offer_ids) = 0
            or fo.offer_id <> all(v_used_offer_ids)
        )
)
select offer_id,
    farmer_id,
    variety_id,
    remaining_quantity,
    listing_id,
    farmer_is_price_locked,
    farmer_lock_credit,
    farmer_fpls_id,
    variable_consumer_price,
    variable_farmer_price,
    pvl_listing_id,
    match_score
from ranked_offers
where rn = 1
order by match_score desc,
    abs(
        coalesce(available_from, v_date_needed) - v_date_needed
    ) asc,
    abs(
        coalesce(available_to, v_date_needed) - v_date_needed
    ) asc,
    remaining_quantity desc,
    coalesce(available_to, v_date_needed) - v_date_needed desc loop exit
    when v_remaining_needed <= 0;
v_alloc_qty := least(v_remaining_needed, v_offer.remaining_quantity);
v_consumer_price := v_offer.variable_consumer_price;
v_farmer_price := v_offer.variable_farmer_price;
v_listing_id := v_offer.pvl_listing_id;
v_farmer_is_price_locked := coalesce(v_offer.farmer_is_price_locked, false);
v_farmer_lock_credit := coalesce(v_offer.farmer_lock_credit, 0);
v_farmer_lock_deduct := v_alloc_qty * v_farmer_price;
v_farmer_fpls_id := v_offer.farmer_fpls_id;
-- ------------------------------------------------
-- FALLBACK 6a. CONSUMER PRICE LOCK — resolve BEFORE
--              any writes (same fix as local pass)
-- ------------------------------------------------
if v_item_price_lock
and v_cpls_id is not null then v_lock_price := v_consumer_price;
v_lock_total_value := v_lock_price * v_alloc_qty;
if v_lock_total_value > v_cpls_remaining then v_item_price_lock := false;
v_cpls_id := null;
else
update consumer_price_lock_subscriptions
set remaining_credits = remaining_credits - v_lock_total_value,
    updated_at = now()
where cpls_id = v_cpls_id;
v_cpls_remaining := v_cpls_remaining - v_lock_total_value;
end if;
end if;
-- Fallback is always is_any → insert new MATCHED cov
v_cov_k := v_cov_k + 1;
insert into consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        selection_type,
        variable_consumer_price,
        price_lock,
        final_price
    )
values (
        v_covg_id,
        v_cov_k,
        v_offer.variety_id,
        v_listing_id,
        true,
        'MATCHED'::public.selection_type,
        v_consumer_price,
        v_consumer_price,
        case
            when v_item_price_lock then v_consumer_price
            else null
        end
    )
returning cov_id into v_cov_id;
if v_farmer_is_price_locked
and v_farmer_lock_credit >= v_farmer_lock_deduct then
insert into farmer_offers_allocations (
        offer_id,
        quantity,
        variable_farmer_price,
        price_lock,
        final_price,
        fpls_id,
        is_paid,
        cov_id
    )
values (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        v_farmer_price,
        v_farmer_fpls_id,
        false,
        v_cov_id
    )
returning foa_id into v_foa_id;
update farmer_offers
set remaining_price_lock_credit = remaining_price_lock_credit - v_farmer_lock_deduct,
    remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = now()
where offer_id = v_offer.offer_id;
else
insert into farmer_offers_allocations (
        offer_id,
        quantity,
        variable_farmer_price,
        price_lock,
        final_price,
        fpls_id,
        is_paid,
        cov_id
    )
values (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        null,
        null,
        false,
        v_cov_id
    )
returning foa_id into v_foa_id;
update farmer_offers
set remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = now()
where offer_id = v_offer.offer_id;
end if;
v_used_offer_ids := array_append(v_used_offer_ids, v_offer.offer_id);
v_quality_fee_amt := coalesce(v_consumer_price, 0) * v_alloc_qty * v_quality_fee_rate;
v_total_market_val := v_total_market_val + coalesce(v_consumer_price, 0) * v_alloc_qty;
v_cop_quality_fee := v_cop_quality_fee + v_quality_fee_amt;
v_delivery_fee := om_calculate_delivery_fee(
    p_consumer_id,
    v_offer.farmer_id,
    v_alloc_qty,
    coalesce(v_consumer_price, 0) * v_alloc_qty,
    1
);
insert into offer_order_match (
        cov_id,
        foa_id,
        delivery_status,
        dispatch_at,
        delivery_fee,
        carrier_id,
        consumer_has_paid
    )
values (
        v_cov_id,
        v_foa_id,
        'PENDING',
        '2100-01-01 00:00:00+00'::timestamptz,
        v_delivery_fee,
        v_default_carrier,
        v_order_payment_method <> 'Cash'::public.payment_method
    )
returning oom_id into v_oom_id;
v_success_count := v_success_count + 1;
v_remaining_needed := v_remaining_needed - v_alloc_qty;
end loop;
-- fallback pass
-- ------------------------------------------------
-- FALLBACK 6h. DELIVERY FEE RESOLUTION per variety
--     Same logic as local pass 6h — keep highest fee,
--     zero out the rest for each MATCHED cov in group.
-- ------------------------------------------------
update offer_order_match oom_zero
set delivery_fee = 0
from consumer_orders_variety cov_m
where cov_m.covg_id = v_covg_id
    and cov_m.selection_type = 'MATCHED'::public.selection_type
    and oom_zero.cov_id = cov_m.cov_id
    and oom_zero.oom_id <> (
        select oom_keep.oom_id
        from offer_order_match oom_keep
        where oom_keep.cov_id = cov_m.cov_id
        order by oom_keep.delivery_fee desc,
            oom_keep.oom_id asc
        limit 1
    );
end if;
-- --------------------------------------------------------
-- 7. WRITE cpls_id back to covg if the consumer price lock
--    was actually applied (credits were sufficient).
--    v_cpls_id is nulled out in 6a when credits fail, so
--    this correctly writes null for unconfirmed locks.
-- --------------------------------------------------------
update consumer_orders_variety_group
set cpls_id = v_cpls_id
where covg_id = v_covg_id;
-- --------------------------------------------------------
-- 8. POST-MATCH: stamp OPEN on all cov rows in this group
--    if the algorithm could not fulfil the quantity at all.
--
            --    OPEN means:
--      • No foa or oom rows were created for this group
--      • The group is waiting for new farmer offers or
--        manual intervention
--      • All cov rows (MATCHED / SKIPPED pre-inserts) are
--        overwritten to OPEN so the UI can surface it clearly
--
            --    If partially fulfilled (remaining_needed > 0 but some
--    allocations did happen), we keep MATCHED on used rows
--    and mark leftover as OPEN on the covg level only
--    (via the errors payload — no cov-level change for partial).
-- --------------------------------------------------------
if v_remaining_needed >= v_quantity then -- Zero allocations made for this group → mark everything OPEN
update consumer_orders_variety
set selection_type = 'OPEN'::public.selection_type
where covg_id = v_covg_id;
v_failed_count := v_failed_count + 1;
v_errors := v_errors || jsonb_build_object(
    'covg_id',
    v_covg_id,
    'produce_id',
    v_produce_id,
    'form',
    v_form,
    'date_needed',
    v_date_needed,
    'requested_qty',
    v_quantity,
    'unfulfilled_qty',
    v_remaining_needed,
    'reason',
    'No farmer offer available — group set to OPEN'
);
elsif v_remaining_needed > 0 then -- Partially fulfilled — record it but don't override cov states
v_failed_count := v_failed_count + 1;
v_errors := v_errors || jsonb_build_object(
    'covg_id',
    v_covg_id,
    'produce_id',
    v_produce_id,
    'form',
    v_form,
    'date_needed',
    v_date_needed,
    'requested_qty',
    v_quantity,
    'unfulfilled_qty',
    v_remaining_needed,
    'reason',
    'Insufficient stock — partial fulfilment'
);
end if;
end loop;
-- items loop (j)
-- --------------------------------------------------------
-- 9. WRITE FINAL quality_fee to cop
-- --------------------------------------------------------
update consumer_orders_produce
set quality_fee = v_cop_quality_fee
where cop_id = v_cop_id;
end loop;
-- orders loop (i)
return jsonb_build_object(
    'order_id',
    v_order_id,
    'success',
    v_failed_count = 0,
    'message',
    case
        when v_failed_count = 0 then 'Order placed successfully'
        when v_success_count = 0 then 'Order failed — no stock available'
        else 'Order partially placed — some items could not be fulfilled'
    end,
    'matched',
    v_success_count,
    'failed',
    v_failed_count,
    'errors',
    case
        when v_failed_count > 0 then v_errors
        else '[]'::jsonb
    end
);
end;
$$;
-- ============================================================
-- SECTION 5: USAGE EXAMPLE
-- ============================================================
--
-- select om_place_and_match_order(
--   '{
--     "payment_method": "Cash",
--     "p_orders": [
--       {
--         "produce_id": "b1c2d3e4-f5a6-b7c8-d9e0-f1a2b3c4d5e6",
--         "quality": "Regular",
--         "order_items": [
--           {
--             "variety_ids": [""],
--             "form": "Raw",
--             "quantity": 122,
--             "date_needed": "2026-03-05"
--           }
--         ]
--       },
--       {
--         "produce_id": "5984584f-0ded-4958-8ae6-0cebbff83459",
--         "quality": "Regular",
--         "order_items": [
--           {
--             "variety_ids": [
--               "f424795f-9219-4176-bbe3-1d71f088feb1",
--               "89c17740-d1d1-4bc7-bf3b-2a73f50305f3",
--               "915e2bcb-cc47-4cd6-957d-7ee4d6699151"
--             ],
--             "form": "Milled",
--             "quantity": 111,
--             "date_needed": "2026-03-26"
--           }
--         ]
--       }
--     ]
--   }'::jsonb,
--   'Please handle with care'
-- );
--
-- ============================================================
-- ADJUSTING CONSTANTS (no code redeployment needed):
-- ============================================================
--
-- update dirikita_config set value = 0.10 where key = 'quality_fee_regular';
-- update dirikita_config set value = 40   where key = 'local_search_radius_km';
-- update dirikita_config set value = 0.60 where key = 'density_high_discount';