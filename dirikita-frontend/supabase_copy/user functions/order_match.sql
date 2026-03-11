-- ============================================================
-- ORDER MATCHING — Full SQL Module
--
-- Execution order (run top to bottom):
--   1. dirikita_config table + seed data    (SECTION 1)
--   2. mo_cfg()                             (SECTION 2) config reader
--   3. mo_location_match_score()            (SECTION 3) text-based location scorer
--   4. mo_calculate_delivery_fee()          (SECTION 4) delivery fee calculator
--   5. mo_score_farmer_offer()              (SECTION 5) farmer offer scorer
--   6. mo_best_carrier()                    (SECTION 6) carrier selector
--   7. match_order()                        (SECTION 7) main matching function
--
-- Flutter caller:
--   await supabase.rpc('match_order', params: {
--     'p_orders':     orderEntries,   // required — array of produce groups
--     'p_note':       note,           // optional — free-text order note
--     'p_cps_id':     cpsId,          // optional — plan subscription UUID
--     'p_address_id': addressId,      // optional — users_addresses.address_id
--   });
-- ============================================================
-- ============================================================
-- SECTION 1: CONFIG TABLE
--
-- All tunable constants live here. Edit values directly to tune
-- matching, delivery, and scoring behaviour without code changes.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.dirikita_config (
    key TEXT PRIMARY KEY,
    value NUMERIC NOT NULL,
    description TEXT
);
INSERT INTO public.dirikita_config (key, value, description)
VALUES -- ── Order limits ──────────────────────────────────────────
    (
        'consumer_max_days',
        30,
        'Max days ahead consumer date_needed is accepted'
    ),
    -- ── Quality tier fees (added on top of market price) ──────
    (
        'quality_fee_saver',
        0.00,
        'Saver: 0% quality fee'
    ),
    (
        'quality_fee_regular',
        0.05,
        'Regular: 5% quality fee'
    ),
    (
        'quality_fee_select',
        0.15,
        'Select: 15% quality fee'
    ),
    -- ── Delivery: free-shipping threshold ─────────────────────
    (
        'free_shipping_threshold',
        2222,
        'PHP order total to waive delivery fee entirely'
    ),
    -- ── Delivery: vehicle-type thresholds (by weight) ─────────
    (
        'van_threshold_kg',
        50,
        'Min kg from one farmer to use van rate'
    ),
    (
        'truck_threshold_kg',
        150,
        'Min kg from one farmer to use truck rate'
    ),
    -- ── Delivery: distance calculation ────────────────────────
    (
        'road_factor',
        1.3,
        'Straight-line km → estimated road km (PH roads)'
    ),
    (
        'rate_per_km_standard',
        12,
        'Standard PHP/km (small orders)'
    ),
    (
        'rate_per_km_van',
        8,
        'Van PHP/km (medium batch)'
    ),
    (
        'rate_per_km_truck',
        5,
        'Truck PHP/km (large batch)'
    ),
    -- ── Delivery: distance tiers ──────────────────────────────
    (
        'local_max_km',
        30,
        'Max straight-line km considered local'
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
        'base_delivery_fee',
        20,
        'Flat base fee added to every delivery regardless of distance'
    ),
    -- ── Delivery: Bayanihan density discount ──────────────────
    -- More nearby active orders = cheaper delivery for everyone
    (
        'density_radius_km',
        2,
        'Radius km to count nearby consumer orders'
    ),
    (
        'density_high_min_orders',
        5,
        'Min nearby orders for high density discount'
    ),
    (
        'density_mid_min_orders',
        2,
        'Min nearby orders for mid density discount'
    ),
    (
        'density_high_discount',
        0.50,
        'High density: 50% off delivery fee'
    ),
    (
        'density_mid_discount',
        0.25,
        'Mid density: 25% off delivery fee'
    ),
    (
        'combined_ship_min_items',
        5,
        'Min distinct items from same farmer to split delivery fee'
    ),
    -- ── Matching: geo search ──────────────────────────────────
    (
        'local_search_radius_km',
        30,
        'Initial local search radius km for farmer matching'
    ),
    -- ── Matching: farmer score weights (must sum to 1.0) ──────
    (
        'score_w_proximity',
        0.40,
        'Weight: geo proximity to consumer'
    ),
    (
        'score_w_harvest',
        0.25,
        'Weight: harvest timing / peak season match'
    ),
    (
        'score_w_efficiency',
        0.20,
        'Weight: can fulfil full quantity in one offer'
    ),
    (
        'score_w_location',
        0.15,
        'Weight: text-based address hierarchy match'
    ) ON CONFLICT (key) DO
UPDATE
SET value = EXCLUDED.value,
    description = EXCLUDED.description;
-- ============================================================
-- SECTION 2: CONFIG READER
--
-- Simple helper to avoid repeating SELECT … FROM dirikita_config
-- everywhere. Call as: mo_cfg('key_name')
-- ============================================================
CREATE OR REPLACE FUNCTION mo_cfg(p_key TEXT) RETURNS NUMERIC LANGUAGE SQL STABLE AS $$
SELECT value
FROM dirikita_config
WHERE key = p_key;
$$;
-- ============================================================
-- SECTION 3: LOCATION MATCH SCORE  (text-based address hierarchy)
--
-- Returns a 0–1 score based on how closely a farmer's registered
-- address matches the consumer's address.
--
-- Scoring breakdown:
--   Same region   → +0.40
--   Same province → +0.35
--   Same city     → +0.25
--   Max total     →  1.00
-- ============================================================
CREATE OR REPLACE FUNCTION mo_location_match_score(p_consumer_id TEXT, p_farmer_id TEXT) RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE -- consumer address fields
    v_c_region TEXT;
v_c_province TEXT;
v_c_city TEXT;
-- farmer address fields
v_f_region TEXT;
v_f_province TEXT;
v_f_city TEXT;
-- running score
v_score NUMERIC := 0;
BEGIN -- Fetch consumer's address hierarchy
SELECT ua.region,
    ua.province,
    ua.city INTO v_c_region,
    v_c_province,
    v_c_city
FROM user_consumers uc
    JOIN users u ON u.id = uc.user_id
    LEFT JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE uc.consumer_id = p_consumer_id
LIMIT 1;
-- Fetch farmer's address hierarchy
SELECT ua.region,
    ua.province,
    ua.city INTO v_f_region,
    v_f_province,
    v_f_city
FROM user_farmers uf
    JOIN users u ON u.id = uf.user_id
    LEFT JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE uf.farmer_id = p_farmer_id
LIMIT 1;
-- Award points at each level of the hierarchy
IF v_c_region IS NOT NULL
AND v_c_region = v_f_region THEN v_score := v_score + 0.40;
END IF;
IF v_c_province IS NOT NULL
AND v_c_province = v_f_province THEN v_score := v_score + 0.35;
END IF;
IF v_c_city IS NOT NULL
AND v_c_city = v_f_city THEN v_score := v_score + 0.25;
END IF;
RETURN v_score;
END;
$$;
-- ============================================================
-- SECTION 4: DELIVERY FEE CALCULATOR
--
-- Computes the delivery fee for one farmer→consumer allocation.
-- Uses GPS distance when available; falls back to text-based
-- province/region matching.
--
-- Fee pipeline (applied in order):
--   1. Free-shipping shortcut  (order total ≥ threshold)
--   2. GPS or text-based distance
--   3. Batch rate by shipment weight (standard / van / truck)
--   4. Distance tier base fee + surcharge (local vs. far)
--   5. Gross fee  = base + (road_km × rate_per_km) + surcharge
--   6. Bayanihan density discount  (nearby active orders)
--   7. Cluster discount  (5% when nearby farmers share the same date_needed)
--   8. Combined-shipping split        (many items, same farmer)
--   9. Add flat base_delivery_fee
-- ============================================================
CREATE OR REPLACE FUNCTION mo_calculate_delivery_fee(
        p_consumer_id TEXT,
        p_farmer_id TEXT,
        p_total_kg NUMERIC,
        p_order_amount NUMERIC,
        p_item_count INTEGER
    ) RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE -- geo coordinates
    v_consumer_loc GEOGRAPHY;
v_farmer_loc GEOGRAPHY;
v_straight_km NUMERIC;
v_road_km NUMERIC;
v_rate_per_km NUMERIC;
v_base_fee NUMERIC;
v_surcharge NUMERIC := 0;
v_gross_fee NUMERIC;
-- text-based address fields (consumer)
v_con_address_line_1 TEXT;
v_con_address_line_2 TEXT;
v_con_city TEXT;
v_con_province TEXT;
v_con_landmark TEXT;
v_con_region TEXT;
v_con_postal_code TEXT;
v_con_country TEXT;
-- text-based address fields (farmer)
v_far_address_line_1 TEXT;
v_far_address_line_2 TEXT;
v_far_city TEXT;
v_far_province TEXT;
v_far_landmark TEXT;
v_far_region TEXT;
v_far_postal_code TEXT;
v_far_country TEXT;
-- discount accumulators
v_nearby_count INTEGER;
v_density_disc NUMERIC := 0;
v_cluster_disc NUMERIC := 0;
v_net_fee NUMERIC;
v_per_item_fee NUMERIC;
v_nearby_farmer_count INTEGER := 0;
v_farmer_address_tmp UUID;
v_farmer_loc_tmp GEOGRAPHY;
BEGIN -- ── Step 1: Free-shipping shortcut ────────────────────────
-- Skip all distance logic — just return the flat base fee.
IF p_order_amount >= mo_cfg('free_shipping_threshold') THEN RETURN mo_cfg('base_delivery_fee');
END IF;
-- ── Step 2: Fetch addresses (GPS + text fields) ───────────
SELECT ua.location,
    ua.address_line_1,
    ua.address_line_2,
    ua.city,
    ua.province,
    ua.landmark,
    ua.region,
    ua.postal_code,
    ua.country INTO v_consumer_loc,
    v_con_address_line_1,
    v_con_address_line_2,
    v_con_city,
    v_con_province,
    v_con_landmark,
    v_con_region,
    v_con_postal_code,
    v_con_country
FROM user_consumers uc
    JOIN users u ON u.id = uc.user_id
    JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE uc.consumer_id = p_consumer_id
LIMIT 1;
SELECT ua.location,
    ua.address_line_1,
    ua.address_line_2,
    ua.city,
    ua.province,
    ua.landmark,
    ua.region,
    ua.postal_code,
    ua.country INTO v_farmer_loc,
    v_far_address_line_1,
    v_far_address_line_2,
    v_far_city,
    v_far_province,
    v_far_landmark,
    v_far_region,
    v_far_postal_code,
    v_far_country
FROM user_farmers uf
    JOIN users u ON u.id = uf.user_id
    JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE uf.farmer_id = p_farmer_id
LIMIT 1;
-- ── Step 3: Compute distance ──────────────────────────────
-- Prefer GPS; fall back to text-based province/region match.
IF v_consumer_loc IS NOT NULL
AND v_farmer_loc IS NOT NULL THEN v_straight_km := ST_Distance(v_consumer_loc, v_farmer_loc) / 1000.0;
v_road_km := v_straight_km * mo_cfg('road_factor');
ELSE IF v_con_province IS NOT NULL
AND v_far_province IS NOT NULL
AND LOWER(TRIM(v_con_province)) = LOWER(TRIM(v_far_province)) THEN -- Same province → treat as local midpoint distance
v_straight_km := mo_cfg('local_max_km') * 0.5;
ELSIF v_con_region IS NOT NULL
AND v_far_region IS NOT NULL
AND LOWER(TRIM(v_con_region)) = LOWER(TRIM(v_far_region)) THEN -- Same region, different province → just beyond local threshold
v_straight_km := mo_cfg('local_max_km') * 1.2;
ELSE -- No usable location data → worst-case rate
RETURN ROUND(
    mo_cfg('far_base_fee') + mo_cfg('far_surcharge') + mo_cfg('base_delivery_fee'),
    2
);
END IF;
v_road_km := v_straight_km * mo_cfg('road_factor');
END IF;
-- ── Step 4: Select vehicle rate by batch weight ───────────
IF p_total_kg >= mo_cfg('truck_threshold_kg') THEN v_rate_per_km := mo_cfg('rate_per_km_truck');
ELSIF p_total_kg >= mo_cfg('van_threshold_kg') THEN v_rate_per_km := mo_cfg('rate_per_km_van');
ELSE v_rate_per_km := mo_cfg('rate_per_km_standard');
END IF;
-- ── Step 5: Distance tier (local vs. far) ─────────────────
IF v_straight_km <= mo_cfg('local_max_km') THEN v_base_fee := mo_cfg('local_base_fee');
v_surcharge := 0;
ELSE v_base_fee := mo_cfg('far_base_fee');
v_surcharge := mo_cfg('far_surcharge');
END IF;
-- ── Step 6: Gross fee ─────────────────────────────────────
v_gross_fee := v_base_fee + (v_road_km * v_rate_per_km) + v_surcharge;
-- ── Step 7: Bayanihan density discount ───────────────────
-- More nearby active consumer orders = cheaper for everyone.
IF v_consumer_loc IS NOT NULL THEN -- GPS-based: count distinct consumers within radius
SELECT COUNT(DISTINCT co.consumer_id) INTO v_nearby_count
FROM consumer_orders co
    JOIN user_consumers uc2 ON uc2.consumer_id = co.consumer_id
    JOIN users u2 ON u2.id = uc2.user_id
    JOIN users_addresses ua2 ON ua2.address_id = u2.address_id
WHERE co.consumer_id <> p_consumer_id
    AND co.is_active = TRUE
    AND ST_DWithin(
        ua2.location,
        v_consumer_loc,
        mo_cfg('density_radius_km') * 1000
    );
ELSE -- Text-based fallback: count active orders in same city/province
SELECT COUNT(DISTINCT co.consumer_id) INTO v_nearby_count
FROM consumer_orders co
    JOIN user_consumers uc2 ON uc2.consumer_id = co.consumer_id
    JOIN users u2 ON u2.id = uc2.user_id
    JOIN users_addresses ua2 ON ua2.address_id = u2.address_id
WHERE co.consumer_id <> p_consumer_id
    AND co.is_active = TRUE
    AND (
        (
            v_con_city IS NOT NULL
            AND LOWER(TRIM(ua2.city)) = LOWER(TRIM(v_con_city))
        )
        OR (
            v_con_province IS NOT NULL
            AND LOWER(TRIM(ua2.province)) = LOWER(TRIM(v_con_province))
        )
    );
END IF;
IF v_nearby_count >= mo_cfg('density_high_min_orders') THEN v_density_disc := mo_cfg('density_high_discount');
ELSIF v_nearby_count >= mo_cfg('density_mid_min_orders') THEN v_density_disc := mo_cfg('density_mid_discount');
END IF;
-- ── Step 8: Cluster discount ──────────────────────────────
-- 5% off when at least one other active farmer offer exists
-- within local_search_radius_km of this farmer and shares the
-- same produce_id (same-day batch delivery becomes cheaper).
SELECT u.address_id INTO v_farmer_address_tmp
FROM user_farmers uf
    JOIN users u ON u.id = uf.user_id
WHERE uf.farmer_id = p_farmer_id
LIMIT 1;
IF v_farmer_address_tmp IS NOT NULL THEN
SELECT ua_this.location INTO v_farmer_loc_tmp
FROM users_addresses ua_this
WHERE ua_this.address_id = v_farmer_address_tmp
LIMIT 1;
END IF;
IF v_farmer_loc_tmp IS NOT NULL THEN
SELECT COUNT(DISTINCT fo2.farmer_id) INTO v_nearby_farmer_count
FROM farmer_offers fo2
    JOIN user_farmers uf2 ON uf2.farmer_id = fo2.farmer_id
    JOIN users u2 ON u2.id = uf2.user_id
    JOIN users_addresses ua2 ON ua2.address_id = u2.address_id
WHERE fo2.farmer_id <> p_farmer_id
    AND fo2.is_active = TRUE
    AND fo2.remaining_quantity > 0
    AND ST_DWithin(
        ua2.location,
        v_farmer_loc_tmp,
        mo_cfg('local_search_radius_km') * 1000
    );
IF v_nearby_farmer_count >= 1 THEN v_cluster_disc := 0.05;
END IF;
END IF;
v_net_fee := v_gross_fee * (1 - v_density_disc) * (1 - v_cluster_disc);
-- ── Step 9: Combined-shipping split ──────────────────────
-- When many items share a farmer, divide the delivery fee across them.
IF p_item_count >= mo_cfg('combined_ship_min_items')::INTEGER THEN v_per_item_fee := v_net_fee / p_item_count;
ELSE v_per_item_fee := v_net_fee;
END IF;
-- ── Step 10: Add flat base fee and return ─────────────────
RETURN ROUND(v_per_item_fee + mo_cfg('base_delivery_fee'), 2);
END;
$$;
-- ============================================================
-- SECTION 5: FARMER OFFER SCORER
--
-- Returns a 0–1 composite score for a specific farmer offer
-- relative to a consumer's request. Higher = better match.
--
-- Score components (weights from dirikita_config):
--   proximity   (0.40) — how close farmer is to consumer (GPS)
--   harvest     (0.25) — how close available_from is to date_needed
--   efficiency  (0.20) — whether farmer can fully cover quantity
--   location    (0.15) — text-based region/province/city match
-- ============================================================
CREATE OR REPLACE FUNCTION mo_score_farmer_offer(
        p_consumer_id TEXT,
        p_farmer_id TEXT,
        p_offer_id UUID,
        p_needed_qty NUMERIC,
        p_date_needed DATE
    ) RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE -- geo
    v_consumer_loc GEOGRAPHY;
v_farmer_loc GEOGRAPHY;
v_dist_km NUMERIC;
-- component scores (all 0–1)
v_prox_score NUMERIC := 0;
-- proximity
v_harvest_score NUMERIC := 0;
-- harvest timing
v_efficiency_score NUMERIC := 0;
-- quantity fulfilment
v_location_score NUMERIC := 0;
-- text location
-- offer data
v_remaining_qty NUMERIC;
v_available_from DATE;
BEGIN -- ── Component 1: Geo proximity ────────────────────────────
-- Score = 1 at distance 0, decays linearly to 0 at local_search_radius_km.
SELECT ua.location INTO v_consumer_loc
FROM user_consumers uc
    JOIN users u ON u.id = uc.user_id
    LEFT JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE uc.consumer_id = p_consumer_id
LIMIT 1;
SELECT ua.location INTO v_farmer_loc
FROM user_farmers uf
    JOIN users u ON u.id = uf.user_id
    LEFT JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE uf.farmer_id = p_farmer_id
LIMIT 1;
IF v_consumer_loc IS NOT NULL
AND v_farmer_loc IS NOT NULL THEN v_dist_km := ST_Distance(v_consumer_loc, v_farmer_loc) / 1000.0;
v_prox_score := GREATEST(
    0,
    1 - (
        v_dist_km / NULLIF(mo_cfg('local_search_radius_km'), 0)
    )
);
END IF;
-- ── Component 2: Harvest timing ───────────────────────────
-- Score = 1 when available_from == date_needed, decays over 30 days.
-- Defaults to 0.5 when available_from is not set.
SELECT fo.remaining_quantity,
    fo.available_from INTO v_remaining_qty,
    v_available_from
FROM farmer_offers fo
WHERE fo.offer_id = p_offer_id
LIMIT 1;
IF v_available_from IS NOT NULL THEN v_harvest_score := GREATEST(
    0,
    1 - ABS(v_available_from - p_date_needed)::NUMERIC / 30
);
ELSE v_harvest_score := 0.5;
END IF;
-- ── Component 3: Efficiency ───────────────────────────────
-- Score = 1 if offer fully covers requested quantity; pro-rated otherwise.
IF v_remaining_qty >= p_needed_qty THEN v_efficiency_score := 1;
ELSIF v_remaining_qty > 0 THEN v_efficiency_score := v_remaining_qty / p_needed_qty;
END IF;
-- ── Component 4: Text location ────────────────────────────
v_location_score := mo_location_match_score(p_consumer_id, p_farmer_id);
-- ── Weighted total ────────────────────────────────────────
RETURN (
    mo_cfg('score_w_proximity') * v_prox_score + mo_cfg('score_w_harvest') * v_harvest_score + mo_cfg('score_w_efficiency') * v_efficiency_score + mo_cfg('score_w_location') * v_location_score
);
END;
$$;
-- ============================================================
-- SECTION 6: BEST CARRIER SELECTOR
--
-- Returns the carrier_id associated with the consumer's account.
-- Falls back to 'car_000001' if none is found.
-- ============================================================
CREATE OR REPLACE FUNCTION mo_best_carrier(p_consumer_id TEXT) RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE v_carrier TEXT;
BEGIN
SELECT uc2.carrier_id INTO v_carrier
FROM user_consumers uc
    JOIN user_carriers uc2 ON TRUE
WHERE uc.consumer_id = p_consumer_id
ORDER BY uc2.created_at ASC
LIMIT 1;
RETURN v_carrier;
END;
$$;
-- ============================================================
-- SECTION 7: MAIN MATCHING FUNCTION — match_order()
--
-- Places a consumer order and immediately tries to match each
-- item against available farmer offers.
--
-- Parameters:
--   p_orders     JSONB  — array of produce groups (required)
--   p_note       TEXT   — free-text note (optional)
--   p_cps_id     UUID   — plan subscription for price-lock (optional)
--   p_address_id UUID   — delivery address from users_addresses (optional)
--                         Falls back to the user's profile default address.
--
-- Pre-flight validations (all abort before any insert on failure):
--   Address ownership  → p_address_id must belong to auth.uid()
--   Plan subscription  → must exist, belong to consumer, be active, not expired
--
-- Price-lock rules per item:
--   No cps_id                     → price-lock disabled for entire order
--   cps_id valid + is_price_lock  → deduct credits; final_price = dtc_price
--   cps_id valid, no price_lock   → final_price = NULL; no deduction
--   Credits insufficient           → price-lock disabled for rest of that item
--
-- Matching algorithm per item:
--   PASS 1 — Local-radius (ST_DWithin local_search_radius_km)
--             Scores offers and greedily allocates from best to worst.
--   PASS 2 — Global fallback (is_any items only, excludes already-used offers)
--             Same scoring and allocation logic as pass 1.
--   POST   — Fully unfulfilled items stamped OPEN.
--             Partially unfulfilled items log a warning and keep matched rows.
--
-- Returns JSONB:
--   {
--     order_id : UUID,
--     success  : BOOLEAN,
--     message  : TEXT,
--     matched  : INTEGER,   -- count of successfully allocated items
--     failed   : INTEGER,   -- count of items with zero or partial stock
--     errors   : JSONB[]    -- detail for each failed item
--   }
-- ============================================================
CREATE OR REPLACE FUNCTION match_order(
        p_orders JSONB,
        p_note TEXT,
        p_cps_id UUID DEFAULT NULL,
        p_address_id UUID DEFAULT NULL
    ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE -- ── Authentication ────────────────────────────────────────
    v_auth_uid UUID;
p_consumer_id TEXT;
-- ── Order-level variables ─────────────────────────────────
v_note TEXT;
v_order_cps_id UUID;
-- validated plan subscription id
v_order_id UUID;
-- new consumer_orders row
v_address_id UUID;
-- validated delivery address
-- ── Payload iteration ────────────────────────────────────
v_orders_arr JSONB;
v_order_obj JSONB;
-- current produce group
v_items_arr JSONB;
v_item_obj JSONB;
-- current order item
-- ── Plan subscription state ───────────────────────────────
v_cps_remaining_credits NUMERIC;
v_cps_was_used BOOLEAN := FALSE;
-- ── Produce-group level ───────────────────────────────────
v_produce_id UUID;
v_quality TEXT;
v_cop_id UUID;
-- consumer_orders_produce row
-- ── Item level ────────────────────────────────────────────
v_variety_ids JSONB;
v_winning_variety_id UUID;
v_form TEXT;
v_quantity NUMERIC;
v_remaining_needed NUMERIC;
-- decremented as offers are allocated
v_date_needed DATE;
v_is_any BOOLEAN;
-- TRUE when consumer accepts any variety
v_item_index INTEGER;
v_item_price_lock BOOLEAN;
-- ── Variety group / variety rows ──────────────────────────
v_covg_id UUID;
-- consumer_orders_variety_group row
v_cov_id UUID;
-- consumer_orders_variety row
v_cov_k INTEGER;
-- ── Offer allocation ──────────────────────────────────────
v_offer RECORD;
v_alloc_qty NUMERIC;
v_listing_id UUID;
v_consumer_price NUMERIC;
v_farmer_price NUMERIC;
v_farmer_is_price_locked BOOLEAN;
v_farmer_lock_credit NUMERIC;
v_farmer_lock_deduct NUMERIC;
v_farmer_fps_id UUID;
v_used_offer_ids UUID [] := '{}';
-- guard against reusing an offer
v_foa_id UUID;
-- farmer_offers_allocations row
v_oom_id UUID;
-- offer_order_match row
v_alloc_cost NUMERIC;
-- ── Delivery ──────────────────────────────────────────────
v_delivery_fee NUMERIC;
v_default_carrier TEXT;
v_farmer_address UUID;
-- farmer's primary address_id for OOM row
-- ── Result accumulators ───────────────────────────────────
v_success_count INTEGER := 0;
v_failed_count INTEGER := 0;
v_errors JSONB := '[]'::JSONB;
-- ── Loop counters ─────────────────────────────────────────
i INTEGER;
j INTEGER;
BEGIN -- ════════════════════════════════════════════════════════
-- PRE-FLIGHT: Auth, address, payload, plan subscription
-- ════════════════════════════════════════════════════════
-- ── 0a. Resolve consumer from authenticated session ───────
v_auth_uid := auth.uid();
IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated' USING HINT = 'Unauthorized',
ERRCODE = 'P0001';
END IF;
SELECT uc.consumer_id INTO p_consumer_id
FROM user_consumers uc
WHERE uc.user_id = v_auth_uid
LIMIT 1;
IF p_consumer_id IS NULL THEN RAISE EXCEPTION 'No consumer profile found for this user' USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
-- ── 0b. Resolve and validate delivery address ─────────────
-- Priority: supplied p_address_id → users.address_id default
IF p_address_id IS NOT NULL THEN -- Ensure the address belongs to the calling user
IF NOT EXISTS (
    SELECT 1
    FROM public.users_addresses ua
    WHERE ua.address_id = p_address_id
        AND ua.user_id = v_auth_uid
) THEN RAISE EXCEPTION 'Address % does not belong to this user',
p_address_id USING HINT = 'Forbidden',
ERRCODE = 'P0003';
END IF;
v_address_id := p_address_id;
ELSE -- Fall back to the profile-level default address
SELECT u.address_id INTO v_address_id
FROM public.users u
WHERE u.id = v_auth_uid;
END IF;
IF v_address_id IS NULL THEN RAISE EXCEPTION 'No address found. Please set your address in profile.' USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
-- Resolve best carrier now that consumer location is confirmed
v_default_carrier := COALESCE(mo_best_carrier(p_consumer_id), 'car_000001');
-- ── 0c. Extract and validate payload ─────────────────────
v_note := NULLIF(p_note, '');
v_order_cps_id := p_cps_id;
v_orders_arr := p_orders;
IF v_orders_arr IS NULL
OR jsonb_array_length(v_orders_arr) = 0 THEN RAISE EXCEPTION 'p_orders array is missing or empty' USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
-- ── 0d. Validate plan subscription (if provided) ─────────
IF v_order_cps_id IS NOT NULL THEN
DECLARE v_cps_consumer_id TEXT;
v_cps_status TEXT;
v_cps_ends_at TIMESTAMPTZ;
BEGIN
SELECT cps.consumer_id,
    cps.status::TEXT,
    cps.ends_at,
    cps.remaining_credits INTO v_cps_consumer_id,
    v_cps_status,
    v_cps_ends_at,
    v_cps_remaining_credits
FROM consumer_plan_subscriptions cps
WHERE cps.cps_id = v_order_cps_id
LIMIT 1;
IF v_cps_consumer_id IS NULL THEN RAISE EXCEPTION 'Plan subscription not found' USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
IF v_cps_consumer_id <> p_consumer_id THEN RAISE EXCEPTION 'Plan subscription does not belong to this consumer' USING HINT = 'Forbidden',
ERRCODE = 'P0003';
END IF;
IF v_cps_status <> 'active' THEN RAISE EXCEPTION 'Plan subscription is not active (status: %)',
v_cps_status USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
IF v_cps_ends_at <= NOW() THEN RAISE EXCEPTION 'Plan subscription has expired' USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
END;
END IF;
-- ════════════════════════════════════════════════════════
-- STEP 1: Create the parent order record
-- ════════════════════════════════════════════════════════
INSERT INTO consumer_orders (consumer_id, note, is_active)
VALUES (p_consumer_id, v_note, TRUE)
RETURNING order_id INTO v_order_id;
-- ════════════════════════════════════════════════════════
-- STEP 2: Loop each produce group  (outer loop — i)
-- ════════════════════════════════════════════════════════
FOR i IN 0..jsonb_array_length(v_orders_arr) - 1 LOOP v_order_obj := v_orders_arr->i;
v_produce_id := (v_order_obj->>'produce_id')::UUID;
v_quality := v_order_obj->>'quality';
-- Create the produce-level order row
INSERT INTO consumer_orders_produce (order_id, quality, produce_id)
VALUES (v_order_id, v_quality, v_produce_id)
RETURNING cop_id INTO v_cop_id;
-- ════════════════════════════════════════════════════
-- STEP 3: Loop each order item  (inner loop — j)
-- Each item is a variety slot (specific varieties or "any").
-- ════════════════════════════════════════════════════
v_items_arr := v_order_obj->'order_items';
FOR j IN 0..jsonb_array_length(v_items_arr) - 1 LOOP v_item_obj := v_items_arr->j;
v_variety_ids := v_item_obj->'variety_ids';
v_form := v_item_obj->>'form';
v_quantity := (v_item_obj->>'quantity')::NUMERIC;
v_date_needed := (v_item_obj->>'date_needed')::DATE;
v_item_index := j;
-- Reset per-item state
v_remaining_needed := v_quantity;
v_used_offer_ids := '{}';
v_item_price_lock := v_order_cps_id IS NOT NULL
AND COALESCE((v_item_obj->>'is_price_lock')::BOOLEAN, FALSE);
-- Determine if consumer accepts any variety of this produce
v_is_any := FALSE;
IF jsonb_array_length(v_variety_ids) = 0 THEN v_is_any := TRUE;
ELSIF jsonb_array_length(v_variety_ids) = 1
AND (v_variety_ids->>0) = '' THEN v_is_any := TRUE;
END IF;
-- ════════════════════════════════════════════════
-- STEP 4: Create variety group record (covg)
-- ════════════════════════════════════════════════
INSERT INTO consumer_orders_variety_group (
        item_index,
        form,
        quantity,
        is_any,
        cop_id,
        date_needed,
        cps_id -- only set when this item uses price-lock
    )
VALUES (
        v_item_index,
        v_form,
        v_quantity,
        v_is_any,
        v_cop_id,
        v_date_needed,
        CASE
            WHEN v_item_price_lock THEN v_order_cps_id
            ELSE NULL
        END
    )
RETURNING covg_id INTO v_covg_id;
-- ════════════════════════════════════════════════
-- STEP 5: Pre-insert SKIPPED cov rows (specific-variety orders only)
--
            -- For each requested variety, insert a placeholder row ordered by:
--   1. Whether any active stock exists for this variety   (has stock first)
--   2. Distance from nearest available farmer to consumer (closest first)
--   3. Total available stock across all offers            (most stock first)
--   4. Harvest timing proximity to date_needed            (closest date first)
--
            -- These rows will be upgraded to MATCHED in Step 6/7,
-- or remain SKIPPED if no offer was found.
-- ════════════════════════════════════════════════
v_cov_k := -1;
IF NOT v_is_any THEN
DECLARE v_pre_rec RECORD;
BEGIN FOR v_pre_rec IN
SELECT (val.v)::UUID AS variety_uuid,
    pvl.listing_id AS listing_id,
    pvl.duruha_to_consumer_price AS unit_price
FROM jsonb_array_elements_text(v_variety_ids) AS val(v)
    JOIN produce_variety_listing pvl ON pvl.variety_id = (val.v)::UUID
    AND LOWER(pvl.produce_form) = LOWER(v_form)
WHERE val.v <> ''
ORDER BY -- 1. Varieties with active stock come first
    CASE
        WHEN COALESCE(
            (
                SELECT SUM(fo2.remaining_quantity)
                FROM farmer_offers fo2
                WHERE fo2.variety_id = (val.v)::UUID
                    AND fo2.is_active = TRUE
                    AND fo2.remaining_quantity > 0
                    AND (
                        fo2.available_from IS NULL
                        OR fo2.available_from <= v_date_needed
                    )
            ),
            0
        ) > 0 THEN 0
        ELSE 1
    END ASC,
    -- 2. Closest available farmer
    (
        SELECT MIN(
                CASE
                    WHEN ua_f2.location IS NOT NULL
                    AND ua_c2.location IS NOT NULL THEN ST_Distance(ua_f2.location, ua_c2.location)
                    ELSE 999999999
                END
            )
        FROM farmer_offers fo2
            JOIN user_farmers uf2 ON uf2.farmer_id = fo2.farmer_id
            JOIN users u2 ON u2.id = uf2.user_id
            LEFT JOIN users_addresses ua_f2 ON ua_f2.address_id = u2.address_id
            JOIN user_consumers uc2 ON uc2.consumer_id = p_consumer_id
            JOIN users uc_u2 ON uc_u2.id = uc2.user_id
            LEFT JOIN users_addresses ua_c2 ON ua_c2.address_id = uc_u2.address_id
        WHERE fo2.variety_id = (val.v)::UUID
            AND fo2.is_active = TRUE
            AND fo2.remaining_quantity > 0
            AND (
                fo2.available_from IS NULL
                OR fo2.available_from <= v_date_needed
            )
    ) ASC,
    -- 3. Most total available stock
    COALESCE(
        (
            SELECT SUM(fo2.remaining_quantity)
            FROM farmer_offers fo2
            WHERE fo2.variety_id = (val.v)::UUID
                AND fo2.is_active = TRUE
                AND fo2.remaining_quantity > 0
                AND (
                    fo2.available_from IS NULL
                    OR fo2.available_from <= v_date_needed
                )
        ),
        0
    ) DESC,
    -- 4. Harvest date closest to date_needed
    (
        SELECT MIN(
                ABS(
                    COALESCE(fo2.available_from, v_date_needed) - v_date_needed
                )
            )
        FROM farmer_offers fo2
        WHERE fo2.variety_id = (val.v)::UUID
            AND fo2.is_active = TRUE
            AND fo2.remaining_quantity > 0
    ) ASC LOOP v_cov_k := v_cov_k + 1;
INSERT INTO consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        selection_type,
        dtc_price,
        price_lock,
        is_price_lock
    )
VALUES (
        v_covg_id,
        v_cov_k,
        v_pre_rec.variety_uuid,
        v_pre_rec.listing_id,
        FALSE,
        'SKIPPED'::public.selection_type,
        v_pre_rec.unit_price,
        v_pre_rec.unit_price,
        v_item_price_lock
    );
END LOOP;
END;
END IF;
-- ════════════════════════════════════════════════
-- STEP 6: PASS 1 — Local-radius matching
--
            -- Query farmer offers within local_search_radius_km.
-- Score and sort offers; greedily allocate from best
-- to worst until v_remaining_needed reaches zero.
--
            -- Offer ranking:
--   1. match_score DESC       (composite 0–1 score)
--   2. available_from ASC     (harvest timing)
--   3. available_to ASC       (earliest fulfilment)
--   4. remaining_quantity DESC (prefer larger offers)
--   5. available_to tiebreak
-- ════════════════════════════════════════════════
FOR v_offer IN WITH ranked_offers AS (
    SELECT fo.offer_id,
        fo.farmer_id,
        fo.variety_id,
        fo.remaining_quantity,
        fo.listing_id,
        fo.is_price_locked AS farmer_is_price_locked,
        fo.remaining_price_lock_credit AS farmer_lock_credit,
        fo.fps_id AS farmer_fps_id,
        fo.available_from,
        fo.available_to,
        pvl.duruha_to_consumer_price AS dtc_price,
        pvl.farmer_to_duruha_price AS ftd_price,
        pvl.listing_id AS pvl_listing_id,
        mo_score_farmer_offer(
            p_consumer_id,
            fo.farmer_id,
            fo.offer_id,
            v_remaining_needed,
            v_date_needed
        ) AS match_score,
        -- De-duplicate: one row per offer_id, preferring explicit listing match
        ROW_NUMBER() OVER (
            PARTITION BY fo.offer_id
            ORDER BY pvl.listing_id
        ) AS rn
    FROM farmer_offers fo
        JOIN produce_varieties pv ON pv.variety_id = fo.variety_id
        JOIN produce_variety_listing pvl ON pvl.listing_id = fo.listing_id
        OR (
            fo.listing_id IS NULL
            AND pvl.variety_id = fo.variety_id
            AND LOWER(pvl.produce_form) = LOWER(v_form)
        )
    WHERE -- Must match the requested produce and form
        pv.produce_id = v_produce_id
        AND LOWER(pvl.produce_form) = LOWER(v_form) -- Offer must be active and have stock ready by date_needed
        AND fo.is_active = TRUE
        AND fo.remaining_quantity > 0
        AND (
            fo.available_from IS NULL
            OR fo.available_from <= v_date_needed
        ) -- Variety filter:
        --   is_any=TRUE  → accept all varieties, but require farmer is local
        --   is_any=FALSE → must be one of the requested variety_ids
        AND (
            v_is_any = FALSE
            OR fo.variety_id = v_winning_variety_id
            OR EXISTS (
                SELECT 1
                FROM user_farmers uf
                    JOIN users u ON u.id = uf.user_id
                    LEFT JOIN users_addresses ua_f ON ua_f.address_id = u.address_id
                    JOIN user_consumers uc ON uc.consumer_id = p_consumer_id
                    JOIN users uc_u ON uc_u.id = uc.user_id
                    LEFT JOIN users_addresses ua_c ON ua_c.address_id = uc_u.address_id
                WHERE uf.farmer_id = fo.farmer_id
                    AND (
                        ua_f.location IS NULL
                        OR ua_c.location IS NULL
                        OR ST_DWithin(
                            ua_f.location,
                            ua_c.location,
                            mo_cfg('local_search_radius_km') * 1000
                        )
                    )
            )
        )
        AND (
            v_is_any = TRUE
            OR fo.variety_id IN (
                SELECT (val.v)::UUID
                FROM jsonb_array_elements_text(v_variety_ids) AS val(v)
                WHERE val.v <> ''
            )
        )
)
SELECT offer_id,
    farmer_id,
    variety_id,
    remaining_quantity,
    listing_id,
    farmer_is_price_locked,
    farmer_lock_credit,
    farmer_fps_id,
    dtc_price,
    ftd_price,
    pvl_listing_id,
    match_score
FROM ranked_offers
WHERE rn = 1
ORDER BY match_score DESC,
    ABS(
        COALESCE(available_from, v_date_needed) - v_date_needed
    ) ASC,
    ABS(
        COALESCE(available_to, v_date_needed) - v_date_needed
    ) ASC,
    remaining_quantity DESC,
    COALESCE(available_to, v_date_needed) - v_date_needed DESC LOOP EXIT
    WHEN v_remaining_needed <= 0;
-- How much can we take from this offer?
v_alloc_qty := LEAST(v_remaining_needed, v_offer.remaining_quantity);
v_consumer_price := v_offer.dtc_price;
v_farmer_price := v_offer.ftd_price;
v_listing_id := v_offer.pvl_listing_id;
v_farmer_is_price_locked := COALESCE(v_offer.farmer_is_price_locked, FALSE);
v_farmer_lock_credit := COALESCE(v_offer.farmer_lock_credit, 0);
v_farmer_lock_deduct := v_alloc_qty * v_farmer_price;
v_farmer_fps_id := v_offer.farmer_fps_id;
-- Resolve farmer's primary address for the OOM row
SELECT u.address_id INTO v_farmer_address
FROM user_farmers uf
    JOIN users u ON u.id = uf.user_id
WHERE uf.farmer_id = v_offer.farmer_id
LIMIT 1;
-- ── 6a. Consumer credit deduction ────────────────
-- Disable price-lock for this item if credits are insufficient.
IF v_item_price_lock
AND v_order_cps_id IS NOT NULL THEN v_alloc_cost := v_consumer_price * v_alloc_qty;
IF v_alloc_cost > v_cps_remaining_credits THEN v_item_price_lock := FALSE;
-- not enough credits — unlock
ELSE
UPDATE consumer_plan_subscriptions
SET remaining_credits = remaining_credits - v_alloc_cost,
    updated_at = NOW()
WHERE cps_id = v_order_cps_id;
v_cps_remaining_credits := v_cps_remaining_credits - v_alloc_cost;
v_cps_was_used := TRUE;
END IF;
END IF;
-- ── 6b/6c. Insert or update consumer_orders_variety row ──
-- is_any items: always INSERT (auto-assigned variety)
-- Specific items: UPDATE the pre-inserted SKIPPED row to MATCHED
IF v_is_any THEN v_cov_k := v_cov_k + 1;
INSERT INTO consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        selection_type,
        dtc_price,
        price_lock,
        is_price_lock,
        final_price
    )
VALUES (
        v_covg_id,
        v_cov_k,
        v_offer.variety_id,
        v_listing_id,
        TRUE,
        'MATCHED'::public.selection_type,
        v_consumer_price,
        v_consumer_price,
        v_item_price_lock,
        CASE
            WHEN v_item_price_lock THEN v_consumer_price
            ELSE NULL
        END
    )
RETURNING cov_id INTO v_cov_id;
ELSE -- Upgrade the SKIPPED placeholder for this variety to MATCHED
UPDATE consumer_orders_variety
SET selection_type = 'MATCHED'::public.selection_type,
    dtc_price = v_consumer_price,
    price_lock = v_consumer_price,
    is_price_lock = v_item_price_lock,
    final_price = CASE
        WHEN v_item_price_lock THEN v_consumer_price
        ELSE NULL
    END
WHERE covg_id = v_covg_id
    AND variety_id = v_offer.variety_id
    AND selection_type = 'SKIPPED'::public.selection_type
RETURNING cov_id INTO v_cov_id;
-- If already MATCHED (duplicate offer path), fetch the existing id
IF v_cov_id IS NULL THEN
SELECT cov_id INTO v_cov_id
FROM consumer_orders_variety
WHERE covg_id = v_covg_id
    AND variety_id = v_offer.variety_id
    AND selection_type = 'MATCHED'::public.selection_type
LIMIT 1;
END IF;
END IF;
IF v_cov_id IS NULL THEN RAISE WARNING 'Skipping allocation: cov_id is null for variety % in covg %',
v_offer.variety_id,
v_covg_id;
CONTINUE;
END IF;
-- ── 6d. Create farmer offer allocation (foa) ─────
-- If the farmer's own price-lock covers this allocation,
-- use the locked price and deduct from their credit.
-- Otherwise create an unlocked allocation (final_price = NULL).
IF v_farmer_is_price_locked
AND v_farmer_lock_credit >= v_farmer_lock_deduct THEN
INSERT INTO farmer_offers_allocations (
        offer_id,
        quantity,
        ftd_price,
        price_lock,
        final_price,
        fps_id,
        is_paid,
        cov_id
    )
VALUES (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        v_farmer_price,
        v_farmer_fps_id,
        FALSE,
        v_cov_id
    )
RETURNING foa_id INTO v_foa_id;
UPDATE farmer_offers
SET remaining_price_lock_credit = remaining_price_lock_credit - v_farmer_lock_deduct,
    remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = NOW()
WHERE offer_id = v_offer.offer_id;
ELSE
INSERT INTO farmer_offers_allocations (
        offer_id,
        quantity,
        ftd_price,
        price_lock,
        final_price,
        fps_id,
        is_paid,
        cov_id
    )
VALUES (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        NULL,
        NULL,
        FALSE,
        v_cov_id
    )
RETURNING foa_id INTO v_foa_id;
UPDATE farmer_offers
SET remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = NOW()
WHERE offer_id = v_offer.offer_id;
END IF;
v_used_offer_ids := ARRAY_APPEND(v_used_offer_ids, v_offer.offer_id);
-- ── 6e. Calculate delivery fee and create OOM record ─
v_delivery_fee := mo_calculate_delivery_fee(
    p_consumer_id,
    v_offer.farmer_id,
    v_alloc_qty,
    COALESCE(v_consumer_price, 0) * v_alloc_qty,
    1
);
INSERT INTO offer_order_match (
        cov_id,
        foa_id,
        delivery_status,
        dispatch_at,
        delivery_fee,
        carrier_id,
        consumer_has_paid,
        consumer_address,
        farmer_address
    )
VALUES (
        v_cov_id,
        v_foa_id,
        'PENDING',
        '2100-01-01 00:00:00+00'::TIMESTAMPTZ,
        v_delivery_fee,
        v_default_carrier,
        FALSE,
        v_address_id,
        v_farmer_address
    )
RETURNING oom_id INTO v_oom_id;
v_success_count := v_success_count + 1;
v_remaining_needed := v_remaining_needed - v_alloc_qty;
END LOOP;
-- local-pass offer loop
-- ── 6f. Zero out duplicate delivery fees ─────────────
-- When a covg row maps to multiple OOM rows (split allocation),
-- keep only the largest fee and zero the rest to avoid overcharging.
UPDATE offer_order_match oom_zero
SET delivery_fee = 0
FROM consumer_orders_variety cov_m
WHERE cov_m.covg_id = v_covg_id
    AND cov_m.selection_type = 'MATCHED'::public.selection_type
    AND oom_zero.cov_id = cov_m.cov_id
    AND oom_zero.oom_id <> (
        SELECT oom_keep.oom_id
        FROM offer_order_match oom_keep
        WHERE oom_keep.cov_id = cov_m.cov_id
        ORDER BY oom_keep.delivery_fee DESC,
            oom_keep.oom_id ASC
        LIMIT 1
    );
-- ════════════════════════════════════════════════
-- STEP 7: PASS 2 — Global fallback (is_any items only)
--
            -- If the local-radius pass could not fully fulfil an
-- "any variety" item, search globally (no geo filter).
-- Already-used offer IDs are excluded.
-- The allocation, credit, and OOM logic is identical
-- to the local pass above.
-- ════════════════════════════════════════════════
IF v_is_any
AND v_remaining_needed > 0 THEN FOR v_offer IN WITH ranked_offers AS (
    SELECT fo.offer_id,
        fo.farmer_id,
        fo.variety_id,
        fo.remaining_quantity,
        fo.listing_id,
        fo.is_price_locked AS farmer_is_price_locked,
        fo.remaining_price_lock_credit AS farmer_lock_credit,
        fo.fps_id AS farmer_fps_id,
        fo.available_from,
        fo.available_to,
        pvl.duruha_to_consumer_price AS dtc_price,
        pvl.farmer_to_duruha_price AS ftd_price,
        pvl.listing_id AS pvl_listing_id,
        mo_score_farmer_offer(
            p_consumer_id,
            fo.farmer_id,
            fo.offer_id,
            v_remaining_needed,
            v_date_needed
        ) AS match_score,
        ROW_NUMBER() OVER (
            PARTITION BY fo.offer_id
            ORDER BY pvl.listing_id
        ) AS rn
    FROM farmer_offers fo
        JOIN produce_varieties pv ON pv.variety_id = fo.variety_id
        JOIN produce_variety_listing pvl ON pvl.listing_id = fo.listing_id
        OR (
            fo.listing_id IS NULL
            AND pvl.variety_id = fo.variety_id
            AND LOWER(pvl.produce_form) = LOWER(v_form)
        )
    WHERE pv.produce_id = v_produce_id
        AND LOWER(pvl.produce_form) = LOWER(v_form)
        AND fo.is_active = TRUE
        AND fo.remaining_quantity > 0
        AND (
            fo.available_from IS NULL
            OR fo.available_from <= v_date_needed
        ) -- Exclude offers already consumed in the local pass
        AND (
            CARDINALITY(v_used_offer_ids) = 0
            OR fo.offer_id <> ALL(v_used_offer_ids)
        )
)
SELECT offer_id,
    farmer_id,
    variety_id,
    remaining_quantity,
    listing_id,
    farmer_is_price_locked,
    farmer_lock_credit,
    farmer_fps_id,
    dtc_price,
    ftd_price,
    pvl_listing_id,
    match_score
FROM ranked_offers
WHERE rn = 1
ORDER BY match_score DESC,
    ABS(
        COALESCE(available_from, v_date_needed) - v_date_needed
    ) ASC,
    ABS(
        COALESCE(available_to, v_date_needed) - v_date_needed
    ) ASC,
    remaining_quantity DESC,
    COALESCE(available_to, v_date_needed) - v_date_needed DESC LOOP EXIT
    WHEN v_remaining_needed <= 0;
v_alloc_qty := LEAST(v_remaining_needed, v_offer.remaining_quantity);
v_consumer_price := v_offer.dtc_price;
v_farmer_price := v_offer.ftd_price;
v_listing_id := v_offer.pvl_listing_id;
v_farmer_is_price_locked := COALESCE(v_offer.farmer_is_price_locked, FALSE);
v_farmer_lock_credit := COALESCE(v_offer.farmer_lock_credit, 0);
v_farmer_lock_deduct := v_alloc_qty * v_farmer_price;
v_farmer_fps_id := v_offer.farmer_fps_id;
SELECT u.address_id INTO v_farmer_address
FROM user_farmers uf
    JOIN users u ON u.id = uf.user_id
WHERE uf.farmer_id = v_offer.farmer_id
LIMIT 1;
-- Credit deduction (same rules as local pass)
IF v_item_price_lock
AND v_order_cps_id IS NOT NULL THEN v_alloc_cost := v_consumer_price * v_alloc_qty;
IF v_alloc_cost > v_cps_remaining_credits THEN v_item_price_lock := FALSE;
ELSE
UPDATE consumer_plan_subscriptions
SET remaining_credits = remaining_credits - v_alloc_cost,
    updated_at = NOW()
WHERE cps_id = v_order_cps_id;
v_cps_remaining_credits := v_cps_remaining_credits - v_alloc_cost;
v_cps_was_used := TRUE;
END IF;
END IF;
v_cov_k := v_cov_k + 1;
INSERT INTO consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        listing_id,
        auto_assign,
        selection_type,
        dtc_price,
        price_lock,
        is_price_lock,
        final_price
    )
VALUES (
        v_covg_id,
        v_cov_k,
        v_offer.variety_id,
        v_listing_id,
        TRUE,
        'MATCHED'::public.selection_type,
        v_consumer_price,
        v_consumer_price,
        v_item_price_lock,
        CASE
            WHEN v_item_price_lock THEN v_consumer_price
            ELSE NULL
        END
    )
RETURNING cov_id INTO v_cov_id;
IF v_farmer_is_price_locked
AND v_farmer_lock_credit >= v_farmer_lock_deduct THEN
INSERT INTO farmer_offers_allocations (
        offer_id,
        quantity,
        ftd_price,
        price_lock,
        final_price,
        fps_id,
        is_paid,
        cov_id
    )
VALUES (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        v_farmer_price,
        v_farmer_fps_id,
        FALSE,
        v_cov_id
    )
RETURNING foa_id INTO v_foa_id;
UPDATE farmer_offers
SET remaining_price_lock_credit = remaining_price_lock_credit - v_farmer_lock_deduct,
    remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = NOW()
WHERE offer_id = v_offer.offer_id;
ELSE
INSERT INTO farmer_offers_allocations (
        offer_id,
        quantity,
        ftd_price,
        price_lock,
        final_price,
        fps_id,
        is_paid,
        cov_id
    )
VALUES (
        v_offer.offer_id,
        v_alloc_qty,
        v_farmer_price,
        v_farmer_price,
        NULL,
        NULL,
        FALSE,
        v_cov_id
    )
RETURNING foa_id INTO v_foa_id;
UPDATE farmer_offers
SET remaining_quantity = remaining_quantity - v_alloc_qty,
    updated_at = NOW()
WHERE offer_id = v_offer.offer_id;
END IF;
v_used_offer_ids := ARRAY_APPEND(v_used_offer_ids, v_offer.offer_id);
v_delivery_fee := mo_calculate_delivery_fee(
    p_consumer_id,
    v_offer.farmer_id,
    v_alloc_qty,
    COALESCE(v_consumer_price, 0) * v_alloc_qty,
    1
);
INSERT INTO offer_order_match (
        cov_id,
        foa_id,
        delivery_status,
        dispatch_at,
        delivery_fee,
        carrier_id,
        consumer_has_paid,
        consumer_address,
        farmer_address
    )
VALUES (
        v_cov_id,
        v_foa_id,
        'PENDING',
        '2100-01-01 00:00:00+00'::TIMESTAMPTZ,
        v_delivery_fee,
        v_default_carrier,
        FALSE,
        v_address_id,
        v_farmer_address
    )
RETURNING oom_id INTO v_oom_id;
v_success_count := v_success_count + 1;
v_remaining_needed := v_remaining_needed - v_alloc_qty;
END LOOP;
-- fallback-pass offer loop
-- Zero out duplicate delivery fees after fallback pass
UPDATE offer_order_match oom_zero
SET delivery_fee = 0
FROM consumer_orders_variety cov_m
WHERE cov_m.covg_id = v_covg_id
    AND cov_m.selection_type = 'MATCHED'::public.selection_type
    AND oom_zero.cov_id = cov_m.cov_id
    AND oom_zero.oom_id <> (
        SELECT oom_keep.oom_id
        FROM offer_order_match oom_keep
        WHERE oom_keep.cov_id = cov_m.cov_id
        ORDER BY oom_keep.delivery_fee DESC,
            oom_keep.oom_id ASC
        LIMIT 1
    );
END IF;
-- fallback pass
-- ════════════════════════════════════════════════
-- STEP 8: Post-match status — stamp unfulfilled items
--
            --   Fully unfulfilled  → all cov rows → OPEN
--   Partially unfulfilled → matched rows kept; error logged
-- ════════════════════════════════════════════════
IF v_remaining_needed >= v_quantity THEN -- Zero quantity matched — mark the whole group OPEN so it can be re-matched later
UPDATE consumer_orders_variety
SET selection_type = 'OPEN'::public.selection_type
WHERE covg_id = v_covg_id;
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
ELSIF v_remaining_needed > 0 THEN -- Some quantity matched but not all — partial fulfilment
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
END IF;
END LOOP;
-- items loop (j)
END LOOP;
-- orders loop (i)
-- ════════════════════════════════════════════════════════
-- RETURN: Summary result
-- ════════════════════════════════════════════════════════
RETURN jsonb_build_object(
    'order_id',
    v_order_id,
    'success',
    v_failed_count = 0,
    'message',
    CASE
        WHEN v_failed_count = 0 THEN 'Order placed successfully'
        WHEN v_success_count = 0 THEN 'Order failed — no stock available'
        ELSE 'Order partially placed — some items could not be fulfilled'
    END,
    'matched',
    v_success_count,
    'failed',
    v_failed_count,
    'errors',
    CASE
        WHEN v_failed_count > 0 THEN v_errors
        ELSE '[]'::JSONB
    END
);
END;
$$;