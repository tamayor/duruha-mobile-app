-- ============================================================
-- DIRIKITA: MATCHING ALGORITHM + DELIVERY FEE CALCULATION
-- ============================================================
-- Schemas involved:
--   consumer_orders, consumer_orders_produce (cop),
--   consumer_orders_variety_group (copvs),
--   consumer_orders_variety (cov)
--   farmer_offers (fo), farmer_offers_allocations (foa),
--   offer_order_match (oom),
--   produce_varieties (pv), produce_variety_listing (pvl),
--   users, user_consumers, user_farmers, user_carriers
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
values -- Date window constraints
    (
        'consumer_max_days',
        30,
        'Max days ahead consumer date_needed is accepted'
    ),
    -- farmer_max_days removed: no upper cap on available_to, priority ordering handles freshness
    -- Quality tier fee multipliers
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
    -- Delivery: free shipping
    (
        'free_shipping_threshold',
        2222,
        'PHP order total from one farmer to waive delivery fee entirely'
    ),
    -- Delivery: road factor
    (
        'road_factor',
        1.3,
        'Multiplier: straight-line km → estimated road km (PH roads)'
    ),
    -- Delivery: batch thresholds (kg from one farmer in one order)
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
    -- Delivery: rate per road-km (PHP/km)
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
    -- Delivery: distance tiers
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
    -- Delivery: Bayanihan neighbor density
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
    -- Matching: combined shipping item threshold
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
        'free_shipping_threshold',
        2222,
        'PHP order total from one farmer to waive delivery fee entirely'
    ),
    -- Matching: local proximity radius for priority search (km)
    (
        'local_search_radius_km',
        30,
        'Initial search radius km for local-priority farmer matching'
    ),
    -- Matching: scoring weights (must conceptually sum to 1.0)
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
create or replace function cfg(p_key text) returns numeric language sql stable as $$
select value
from dirikita_config
where key = p_key;
$$;
-- ============================================================
-- SECTION 2: DELIVERY FEE CALCULATION
-- ============================================================
-- Per farmer per order. Returns the fee for one copvs item
-- after splitting combined shipping across all items from
-- the same farmer.
--
-- Call once per (consumer, farmer) pair, then divide by item count.
-- ============================================================
create or replace function calculate_delivery_fee(
        p_consumer_id text,
        p_farmer_id text,
        p_total_kg numeric,
        -- total kg ordered from this farmer
        p_order_amount numeric,
        -- total PHP value from this farmer
        p_item_count integer -- distinct copvs items from this farmer
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
-- Waives distance fee but ₱45 base fare always applies
if p_order_amount >= cfg('free_shipping_threshold') then return cfg('base_delivery_fee');
end if;
-- 2. FETCH LOCATIONS (geography columns on users table)
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
-- No location data: return flat far base fee + base delivery fee
if v_consumer_loc is null
or v_farmer_loc is null then return cfg('far_base_fee') + cfg('far_surcharge') + cfg('base_delivery_fee');
end if;
-- 3. REAL DISTANCE: straight-line → road estimate
v_straight_km := ST_Distance(v_consumer_loc, v_farmer_loc) / 1000.0;
v_road_km := v_straight_km * cfg('road_factor');
-- 4. BATCH RATE based on total kg from this farmer
if p_total_kg >= cfg('truck_threshold_kg') then v_rate_per_km := cfg('rate_per_km_truck');
elsif p_total_kg >= cfg('van_threshold_kg') then v_rate_per_km := cfg('rate_per_km_van');
else v_rate_per_km := cfg('rate_per_km_standard');
end if;
-- 5. DISTANCE TIER: local vs far
if v_straight_km <= cfg('local_max_km') then v_base_fee := cfg('local_base_fee');
v_surcharge := 0;
else v_base_fee := cfg('far_base_fee');
v_surcharge := cfg('far_surcharge');
end if;
-- 6. GROSS FEE
v_gross_fee := v_base_fee + (v_road_km * v_rate_per_km) + v_surcharge;
-- 7. BAYANIHAN DENSITY DISCOUNT
--    Count other active consumer orders near this consumer
select count(distinct co.consumer_id) into v_nearby_count
from consumer_orders co
    join user_consumers uc2 on uc2.consumer_id = co.consumer_id
    join users u2 on u2.id = uc2.user_id
where co.consumer_id <> p_consumer_id
    and co.is_active = true
    and ST_DWithin(
        u2.location,
        v_consumer_loc,
        cfg('density_radius_km') * 1000 -- meters
    );
if v_nearby_count >= cfg('density_high_min_orders') then v_density_disc := cfg('density_high_discount');
elsif v_nearby_count >= cfg('density_mid_min_orders') then v_density_disc := cfg('density_mid_discount');
end if;
v_net_fee := v_gross_fee * (1 - v_density_disc);
-- 8. COMBINED SHIPPING: split across all items from this farmer
--    If fewer items than threshold, each item bears full fee
if p_item_count >= cfg('combined_ship_min_items')::integer then v_per_item_fee := v_net_fee / p_item_count;
else v_per_item_fee := v_net_fee;
end if;
-- Add flat base delivery fee regardless of distance
v_per_item_fee := v_per_item_fee + cfg('base_delivery_fee');
return round(v_per_item_fee, 2);
end;
$$;
-- ============================================================
-- SECTION 3: FARMER SCORING (for "Any Variety" ranking)
-- ============================================================
-- Returns a score 0–1 for a given farmer+offer vs a copvs item.
-- Higher = better match.
-- Factors: proximity, harvest timing, can fulfill full qty.
-- ============================================================
create or replace function score_farmer_offer(
        p_consumer_id text,
        p_farmer_id text,
        p_offer_id uuid,
        p_quantity numeric,
        -- consumer required quantity
        p_date_needed date
    ) returns numeric language plpgsql stable as $$
declare v_consumer_loc geography;
v_farmer_loc geography;
v_distance_km numeric;
v_local_max numeric := cfg('local_search_radius_km');
v_proximity_score numeric;
v_harvest_score numeric;
v_efficiency_score numeric;
v_final_score numeric;
v_remaining numeric;
v_peak_months text [];
v_current_month text;
begin -- PROXIMITY SCORE (0–1): closer = higher, beyond local = 0
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
-- unknown location: deprioritize but don't exclude
else v_distance_km := ST_Distance(v_consumer_loc, v_farmer_loc) / 1000.0;
-- Linear decay: 1.0 at 0km, 0.0 at local_max_km, capped at 0 beyond
v_proximity_score := greatest(0, 1 - (v_distance_km / v_local_max));
end if;
-- HARVEST TIMING SCORE (0–1): is requested month in peak_months?
v_current_month := to_char(p_date_needed, 'Mon');
-- e.g. 'Mar'
select pv.peak_months into v_peak_months
from farmer_offers fo
    join produce_varieties pv on pv.variety_id = fo.variety_id
where fo.offer_id = p_offer_id
limit 1;
if v_peak_months is not null
and v_current_month = any(v_peak_months) then v_harvest_score := 1.0;
else v_harvest_score := 0.3;
-- off-peak but still available
end if;
-- EFFICIENCY SCORE (0–1): can farmer fill full quantity?
select fo.remaining_quantity into v_remaining
from farmer_offers fo
where fo.offer_id = p_offer_id;
if v_remaining >= p_quantity then v_efficiency_score := 1.0;
else -- partial fill: score proportionally
v_efficiency_score := v_remaining / p_quantity;
end if;
-- WEIGHTED FINAL SCORE
v_final_score := (v_proximity_score * cfg('score_w_proximity')) + (v_harvest_score * cfg('score_w_harvest')) + (v_efficiency_score * cfg('score_w_efficiency'));
return round(v_final_score, 4);
end;
$$;
-- ============================================================
-- SECTION 4: MAIN MATCHING FUNCTION
-- ============================================================
-- Accepts the JSON payload from your Flutter app.
-- Payload shape:
-- {
--   "p_orders": [
--     {
--       "produce_id": "uuid",
--       "quality": "Saver"|"Regular"|"Select",
--       "order_items": [
--         {
--           "variety_ids": ["uuid", ...],  -- empty string = is_any
--           "form": "Raw"|"Milled"|...,
--           "quantity": 122,
--           "date_needed": "2026-03-05"
--         }
--       ]
--     }
--   ],
--   "p_note": "optional note",
--   "p_consumer_id": "consumer_text_id"
-- }
--
-- Returns: order_id of the created consumer_orders record,
--          plus summary of matches attempted.
-- ============================================================
-- ============================================================
-- SECTION 4: MAIN MATCHING FUNCTION
-- ============================================================
-- Resolves consumer_id from auth.uid() — no user param needed.
-- Supports:
--   • Multiple variety_ids: picks highest remaining_quantity first,
--     fills remainder from next, creates one foa + oom per offer used.
--   • is_any (empty/[""]): auto-assigns best local farmer variety.
--   • quality_fee computed per produce group and stored on cop.quality_fee.
--   • farmer_offers.remaining_quantity decremented per allocation.
-- • foa.variable_farmer_price = produce_variety_listing.farmer_to_duruha_price
-- ============================================================
create or replace function place_and_match_order(
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
-- for groups: single best variety by total stock
v_form text;
v_quantity numeric;
v_remaining_needed numeric;
-- how much still to fulfill
v_date_needed date;
v_is_any boolean;
v_item_index integer;
-- covg
v_covg_id uuid;
v_cov_id uuid;
v_cov_k integer;
-- per-offer allocation loop
v_offer record;
-- candidate offer row
v_alloc_qty numeric;
-- qty taken from this offer
v_listing_id uuid;
v_consumer_price numeric;
v_farmer_price numeric;
v_price_lock_fo numeric;
v_farmer_is_price_locked boolean;
-- fo.is_price_locked
v_farmer_lock_credit numeric;
-- fo.remaining_price_lock_credit
v_farmer_lock_deduct numeric;
-- quantity * farmer_to_duruha_price to deduct
v_farmer_fpls_id uuid;
-- fo.fpls_id (only written to foa if locked)
v_used_offer_ids uuid [] := '{}';
-- tracks offers used across both passes
v_foa_id uuid;
v_oom_id uuid;
-- delivery fee
v_delivery_fee numeric;
v_default_carrier text := 'car_000001';
-- default carrier_id from user_carriers
-- per-farmer delivery fee accumulators (keyed by farmer_id in memory)
-- quality fee
v_quality_fee_amt numeric;
v_total_market_val numeric;
-- accumulates total value across allocations (for quality_fee calc only)
-- result
v_result jsonb;
v_success_count integer := 0;
v_failed_count integer := 0;
v_errors jsonb := '[]'::jsonb;
-- loop counters
i integer;
j integer;
k integer;
v_vid_text text;
-- price lock per item
-- price lock per item
v_order_payment_method public.payment_method;
-- per-item from payload
v_item_cpls_id uuid;
-- per-item cpls_id from payload
v_item_price_lock boolean;
v_cpls_id uuid;
-- active subscription id
v_lock_price numeric;
-- unit price snapshot (duruha_to_consumer_price)
v_lock_total_value numeric;
-- lock_price * quantity for this item
v_cpls_remaining numeric;
-- remaining_credits on active subscription
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
-- Resolve payment_method once at the root payload level
-- A consumer has one payment method per entire order
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
-- Support { "p_orders": [...] } or direct array
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
    when 'Saver' then cfg('quality_fee_saver')
    when 'Regular' then cfg('quality_fee_regular')
    when 'Select' then cfg('quality_fee_select')
    else 0
end;
-- INSERT consumer_orders_produce
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
-- 3. LOOP EACH ORDER ITEM (variety slot)
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
-- Parse cpls_id from payload (only relevant for Cash + price lock)
v_item_cpls_id := (v_item_obj->>'cpls_id')::uuid;
-- price_lock applies only when:
--   payment = Cash AND cpls_id provided AND subscription is active
v_item_price_lock := false;
v_cpls_id := null;
v_lock_price := null;
v_lock_total_value := 0;
v_cpls_remaining := 0;
-- price_lock only applies when payment is Cash + cpls_id provided
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
-- No upper cap on date_needed — accept any future date
-- Offers are matched if available_from <= date_needed (any time before it)
-- Detect is_any
v_is_any := false;
if jsonb_array_length(v_variety_ids) = 0 then v_is_any := true;
elsif jsonb_array_length(v_variety_ids) = 1
and (v_variety_ids->>0) = '' then v_is_any := true;
end if;
-- --------------------------------------------------------
-- 4. INSERT copvs
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
        v_cpls_id
    )
returning covg_id into v_covg_id;
-- --------------------------------------------------------
-- 4b. For variety groups (is_any=false), pick the single best variety
--     = highest total available stock across all active offers
--     The offer loop will be restricted to this variety only
-- --------------------------------------------------------
v_winning_variety_id := null;
if not v_is_any then -- Pick the best variety using same priority as offer ordering:
-- 1. Closest farmer distance
-- 2. Earliest available_from  3. Soonest available_to
-- 2. available_from nearest date_needed  3. available_to nearest date_needed
-- 4. Freshest to date_needed  5. Most stock  6. Widest window
select (val.v)::uuid into v_winning_variety_id
from jsonb_array_elements_text(v_variety_ids) as val(v)
where val.v <> ''
    and exists (
        select 1
        from farmer_offers fo2
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
            and (
                fo2.available_from is null
                or fo2.available_from <= v_date_needed
            )
    )
order by -- 1. Closest farmer distance for this variety
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
    -- 2. available_from earliest relative to date_needed
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
    ) asc,
    -- 3. available_to closest to date_needed (including past)
    (
        select min(
                abs(
                    coalesce(fo2.available_to, v_date_needed) - v_date_needed
                )
            )
        from farmer_offers fo2
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
    ) asc,
    -- 4. Freshest harvest closest to date_needed
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
    ) asc,
    -- 5. Most total stock as last resort
    (
        select coalesce(sum(fo2.remaining_quantity), 0)
        from farmer_offers fo2
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
    ) desc,
    -- 6. Widest window from date_needed
    (
        select max(
                coalesce(fo2.available_to, v_date_needed) - v_date_needed
            )
        from farmer_offers fo2
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
    ) desc
limit 1;
end if;
-- --------------------------------------------------------
-- 5. INIT + pre-insert cov rows for specific variety groups
--    is_any=false → insert ALL varieties in the group (is_selected=false)
--                   winning variety listed first (item_index=1)
--                   algorithm flips is_selected=true on the one used
--    is_any=true  → nothing pre-inserted, cov rows created per allocation
-- --------------------------------------------------------
v_cov_k := 0;
if not v_is_any then
declare v_pre_rec record;
begin for v_pre_rec in
select (val.v)::uuid as variety_uuid,
    pvl.listing_id as listing_id,
    pvl.duruha_to_consumer_price as unit_price
from jsonb_array_elements_text(v_variety_ids) as val(v)
    join produce_variety_listing pvl on pvl.variety_id = (val.v)::uuid
    and lower(pvl.produce_form) = lower(v_form)
where val.v <> ''
order by -- winning variety always listed first (item_index = 1)
    case
        when (val.v)::uuid = v_winning_variety_id then 0
        else 1
    end asc,
    -- then by same priority as offer loop: closest distance
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
    -- available_from nearest to date_needed
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
    ) asc,
    -- most stock as tiebreaker
    (
        select coalesce(sum(fo2.remaining_quantity), 0)
        from farmer_offers fo2
        where fo2.variety_id = (val.v)::uuid
            and fo2.is_active = true
            and fo2.remaining_quantity > 0
    ) desc loop v_cov_k := v_cov_k + 1;
insert into consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        is_selected,
        variable_consumer_price,
        price_lock
    )
values (
        v_covg_id,
        v_cov_k,
        v_pre_rec.variety_uuid,
        v_pre_rec.listing_id,
        false,
        -- consumer specified, not auto-assigned
        false,
        -- not yet selected — offer loop will flip to true
        v_pre_rec.unit_price,
        v_pre_rec.unit_price -- savings preview, final_price set on selection
    );
end loop;
end;
end if;
-- --------------------------------------------------------
-- 6. FILL ORDER: iterate offers ranked by remaining_quantity DESC
--    Keep allocating until v_remaining_needed = 0
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
        score_farmer_offer(
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
        ) -- available_to: no restriction — include offers expiring before date_needed
        -- (order by available_to proximity handles freshness preference)
        and (
            v_is_any = true
            or fo.variety_id = v_winning_variety_id
        ) -- local priority for is_any:
        -- pass if specific variety, OR farmer is within radius,
        -- OR either location is null (can't filter, allow through)
        and (
            v_is_any = false
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
                            cfg('local_search_radius_km') * 1000
                        )
                    )
            )
        )
    order by -- 1. Closest farmer to consumer (nearest first)
        case
            when exists (
                select 1
                from user_farmers uf2
                    join users u2 on u2.id = uf2.user_id
                    join user_consumers uc2 on uc2.consumer_id = p_consumer_id
                    join users uc_u2 on uc_u2.id = uc2.user_id
                where uf2.farmer_id = fo.farmer_id
                    and u2.location is not null
                    and uc_u2.location is not null
            ) then (
                select ST_Distance(u2.location, uc_u2.location)
                from user_farmers uf2
                    join users u2 on u2.id = uf2.user_id
                    join user_consumers uc2 on uc2.consumer_id = p_consumer_id
                    join users uc_u2 on uc_u2.id = uc2.user_id
                where uf2.farmer_id = fo.farmer_id
                limit 1
            )
            else 999999999
        end asc,
        -- 2. available_from earliest relative to date_needed
        abs(
            coalesce(fo.available_from, v_date_needed) - v_date_needed
        ) asc,
        -- 3. available_to closest to date_needed (including past — almost expired)
        abs(
            coalesce(fo.available_to, v_date_needed) - v_date_needed
        ) asc,
        -- 4. Freshest harvest closest to date_needed
        abs(
            coalesce(fo.available_from, v_date_needed) - v_date_needed
        ) asc
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
order by -- 1. Closest farmer (distance via match_score)
    match_score desc,
    -- 2. available_from nearest to date_needed
    abs(
        coalesce(available_from, v_date_needed) - v_date_needed
    ) asc,
    -- 3. available_to closest to date_needed
    abs(
        coalesce(available_to, v_date_needed) - v_date_needed
    ) asc,
    -- 4. Most stock
    remaining_quantity desc,
    -- 5. Widest window
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
-- 6a/6b. RESOLVE cov for this allocation
--   is_any=true  → insert new cov now (auto-assigned variety)
--   is_any=false → find pre-inserted cov, mark is_selected=true,
--                  update final_price now that we know it's used
-- ------------------------------------------------
if v_is_any then v_cov_k := v_cov_k + 1;
insert into consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        is_selected,
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
        true,
        v_consumer_price,
        v_consumer_price,
        case
            when v_item_price_lock then v_consumer_price
            else null
        end
    )
returning cov_id into v_cov_id;
else -- Find the pre-inserted cov for this variety, mark it selected
update consumer_orders_variety
set is_selected = true,
    final_price = case
        when v_item_price_lock then v_consumer_price
        else null
    end
where covg_id = v_covg_id
    and variety_id = v_offer.variety_id
returning cov_id into v_cov_id;
end if;
-- ------------------------------------------------
-- 6c. CREATE foa
--     If farmer offer is price locked:
--       - set foa.price_lock, foa.final_price, foa.variable_farmer_price
--         all to farmer_to_duruha_price (locked unit price)
--       - subtract quantity * price from remaining_price_lock_credit
-- ------------------------------------------------
if v_farmer_is_price_locked
and v_farmer_lock_credit >= v_farmer_lock_deduct then
insert into farmer_offers_allocations (
        offer_id,
        quantity,
        variety_id,
        variable_farmer_price,
        price_lock,
        -- locked unit price snapshot
        final_price,
        -- confirmed = locked price
        fpls_id,
        -- farmer subscription that locked this price
        is_paid,
        cov_id
    )
values (
        v_offer.offer_id,
        v_alloc_qty,
        v_offer.variety_id,
        v_farmer_price,
        v_farmer_price,
        v_farmer_price,
        v_farmer_fpls_id,
        false,
        v_cov_id
    )
returning foa_id into v_foa_id;
-- Subtract from farmer's remaining_price_lock_credit
update farmer_offers
set remaining_price_lock_credit = remaining_price_lock_credit - v_farmer_lock_deduct,
    remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = now()
where offer_id = v_offer.offer_id;
else -- No price lock or insufficient credit — normal allocation
insert into farmer_offers_allocations (
        offer_id,
        quantity,
        variety_id,
        variable_farmer_price,
        price_lock,
        -- always set for savings preview
        final_price,
        -- null until settled
        fpls_id,
        -- null — not locked
        is_paid,
        cov_id
    )
values (
        v_offer.offer_id,
        v_alloc_qty,
        v_offer.variety_id,
        v_farmer_price,
        v_farmer_price,
        -- savings preview
        null,
        null,
        false,
        v_cov_id
    )
returning foa_id into v_foa_id;
-- ------------------------------------------------
-- 6d. DEDUCT remaining_quantity from farmer_offers
-- ------------------------------------------------
update farmer_offers
set remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = now()
where offer_id = v_offer.offer_id;
end if;
v_used_offer_ids := array_append(v_used_offer_ids, v_offer.offer_id);
-- ------------------------------------------------
-- 6e. PRICE LOCK budget check + deduct
-- ------------------------------------------------
if v_item_price_lock
and v_cpls_id is not null then v_lock_price := v_consumer_price;
-- unit price snapshot
v_lock_total_value := v_lock_price * v_alloc_qty;
--   remaining_credits - (quantity * duruha_to_consumer_price) = new remaining
if v_lock_total_value > v_cpls_remaining then -- Not enough credits — downgrade to no lock for this item
v_item_price_lock := false;
v_cpls_id := null;
else -- Deduct from consumer subscription remaining_credits
update consumer_price_lock_subscriptions
set remaining_credits = remaining_credits - v_lock_total_value,
    updated_at = now()
where cpls_id = v_cpls_id;
-- Keep local remaining in sync for multi-item orders in same session
v_cpls_remaining := v_cpls_remaining - v_lock_total_value;
end if;
end if;
-- ------------------------------------------------
-- 6f. QUALITY FEE accumulation for this allocation
-- ------------------------------------------------
v_quality_fee_amt := coalesce(v_consumer_price, 0) * v_alloc_qty * v_quality_fee_rate;
v_total_market_val := v_total_market_val + coalesce(v_consumer_price, 0) * v_alloc_qty;
v_cop_quality_fee := v_cop_quality_fee + v_quality_fee_amt;
-- ------------------------------------------------
-- 6f. DELIVERY FEE — each allocation has its own independent fee
--     based solely on this allocation's qty and amount
-- ------------------------------------------------
v_delivery_fee := calculate_delivery_fee(
    p_consumer_id,
    v_offer.farmer_id,
    v_alloc_qty,
    coalesce(v_consumer_price, 0) * v_alloc_qty,
    1
);
-- ------------------------------------------------
-- 6g. CREATE oom
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
-- ------------------------------------------------
-- 6h. RESULT entry for this allocation
-- ------------------------------------------------
v_success_count := v_success_count + 1;
v_remaining_needed := v_remaining_needed - v_alloc_qty;
end loop;
-- offers loop
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
        score_farmer_offer(
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
    order by -- 1. Closest farmer to consumer
        case
            when exists (
                select 1
                from user_farmers uf2
                    join users u2 on u2.id = uf2.user_id
                    join user_consumers uc2 on uc2.consumer_id = p_consumer_id
                    join users uc_u2 on uc_u2.id = uc2.user_id
                where uf2.farmer_id = fo.farmer_id
                    and u2.location is not null
                    and uc_u2.location is not null
            ) then (
                select ST_Distance(u2.location, uc_u2.location)
                from user_farmers uf2
                    join users u2 on u2.id = uf2.user_id
                    join user_consumers uc2 on uc2.consumer_id = p_consumer_id
                    join users uc_u2 on uc_u2.id = uc2.user_id
                where uf2.farmer_id = fo.farmer_id
                limit 1
            )
            else 999999999
        end asc,
        -- 2. available_from earliest relative to date_needed
        abs(
            coalesce(fo.available_from, v_date_needed) - v_date_needed
        ) asc,
        -- 3. available_to closest to date_needed (including past)
        abs(
            coalesce(fo.available_to, v_date_needed) - v_date_needed
        ) asc,
        -- 4. Freshest harvest closest to date_needed
        abs(
            coalesce(fo.available_from, v_date_needed) - v_date_needed
        ) asc
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
v_cov_k := v_cov_k + 1;
-- Fallback is always is_any — insert cov now
v_cov_k := v_cov_k + 1;
insert into consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        is_selected,
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
        true,
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
        variety_id,
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
        v_offer.variety_id,
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
        variety_id,
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
        v_offer.variety_id,
        v_farmer_price,
        v_farmer_price,
        -- savings preview
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
v_delivery_fee := calculate_delivery_fee(
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
end if;
-- --------------------------------------------------------
-- If still not fully fulfilled, record partial/unfulfilled
-- --------------------------------------------------------
if v_remaining_needed > 0 then v_failed_count := v_failed_count + 1;
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
    'Insufficient stock available'
);
end if;
-- Write cpls_id to covg if consumer price lock was applied
-- cpls_id already written at covg insert — no additional write-back needed
end loop;
-- items loop (j)
-- --------------------------------------------------------
-- 7. WRITE FINAL quality_fee to cop (sum of all items in this produce group)
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
-- SECTION 5: USAGE EXAMPLE
-- ============================================================
--
-- select place_and_match_order(
--     '{
--       "p_orders": [
--         {
--           "produce_id": "b1c2d3e4-f5a6-b7c8-d9e0-f1a2b3c4d5e6",
--           "quality": "Regular",
--           "order_items": [
--             {
--               "variety_ids": [""],
--               "form": "Raw",
--               "quantity": 122,
--               "date_needed": "2026-03-05"
--             }
--           ]
--         },
--         {
--           "produce_id": "5984584f-0ded-4958-8ae6-0cebbff83459",
--           "quality": "Regular",
--           "order_items": [
--             {
--               "variety_ids": [
--                 "f424795f-9219-4176-bbe3-1d71f088feb1",
--                 "89c17740-d1d1-4bc7-bf3b-2a73f50305f3",
--                 "915e2bcb-cc47-4cd6-957d-7ee4d6699151"
--               ],
--               "form": "Milled",
--               "quantity": 111,
--               "date_needed": "2026-03-26"
--             },
--             {
--               "variety_ids": ["2e60d3a5-65ad-48c4-90f3-36519a94625a"],
--               "form": "Milled",
--               "quantity": 22,
--               "date_needed": "2026-03-27"
--             }
--           ]
--         }
--       ]
--     }'::jsonb,
--     'Please handle with care'
-- );
--
-- ============================================================
-- ADJUSTING CONSTANTS (no code redeployment needed):
-- ============================================================
--
-- update dirikita_config set value = 0.10 where key = 'quality_fee_regular';
-- update dirikita_config set value = 40   where key = 'local_search_radius_km';
-- update dirikita_config set value = 0.60 where key = 'density_high_discount';