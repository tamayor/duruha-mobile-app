-- =============================================================
-- FILE: consumer_order_functions_expanding_radius.sql
-- =============================================================
-- Contains THREE cooperative functions for consumer order creation:
--
--   0. public.create_consumer_delivery_fee  (utility — delivery fee)
--   1. public.create_consumer_order   (inner)
--   2. public.create_consumer_orders  (outer)
--
-- DEPENDENCY ORDER:
--   Deploy in the order listed above.
--
-- ── EXPANDING RADIUS ──────────────────────────────────────────
--   If stock cannot be fulfilled within max_distance_km, the
--   search automatically retries with a doubled radius up to
--   max_expansions times (default 4):
--
--     Step 0  → max_distance_km × 1   (initial)
--     Step 1  → max_distance_km × 2
--     Step 2  → max_distance_km × 4
--     Step 3  → max_distance_km × 8
--     Step 4  → max_distance_km × 16  (final)
--
--   A NOTICE is raised on each expansion. Returns NULL only
--   after the widest radius still cannot fulfil.
--
-- ── IS-ANY VARIETY PRIORITY ───────────────────────────────────
--   Pass C1 — varieties with at least one offer within the BASE
--             max_distance_km. Tried first, sorted by stock DESC.
--   Pass C2 — "far fallback": varieties where EVERY offer exceeds
--             max_distance_km. Used only when remaining > 0 after
--             C1. Each far variety consumed emits a NOTICE.
--             Offers consumed in C2 are flagged is_far = TRUE and
--             propagated to create_consumer_delivery_fee.
--   SPECIFIC mode — single pass, unaffected by this rule.
--
-- ── QUALITY FEE ───────────────────────────────────────────────
--   Stored as the ACTUAL AMOUNT (not the rate) per produce line:
--     produce_subtotal  = SUM(qty × price) all varieties / groups
--     quality_fee_amount = produce_subtotal × canonical_rate
--   Canonical rates: Saver 0 %, Regular 5 %, Select 15 %.
--   The same amount stamps every consumer_orders row for the line.
--
-- ── DELIVERY FEE — PER FARMER, SPLIT ACROSS ITEMS ─────────────
--   create_consumer_delivery_fee() is called ONCE per unique
--   farmer in the outer function Step 6 pre-pass, not once per item.
--   The base_fee is then divided equally across all items from
--   that farmer in the same batch:
--
--     item_delivery_fee = base_fee ÷ items_from_this_farmer
--
--   A consumer ordering 5 varieties from Farmer A and 2 from Farmer B
--   gets 2 delivery charges total. Farmer A's fee is split 5 ways;
--   Farmer B's fee is split 2 ways.
--
--   Distance source: public.farmers.road_distance_m — the real road
--   distance in metres from the Google Maps Directions API, stored
--   externally when the farmer account or address is updated.
--   No Haversine / crow-flies estimation is used.
--
-- ── CARRIER ASSIGNMENT ────────────────────────────────────────
--   The nearest carrier to the FARMER within CARRIER_SEARCH_RADIUS_KM
--   (default 30 km) is assigned. Falls back to DEFAULT_CARRIER_ID
--   when none is found within that radius.
--
-- ── OFFER PRIORITY (within each variety pass) ─────────────────
--   1. Distance ASC                 (closest farmer first)
--   2. available_from <= date_needed (window already open)
--   3. ABS(available_to   - date_needed) ASC  (expires soonest)
--   4. ABS(available_from - date_needed) ASC  (freshest stock)
--   5. remaining_quantity >= remaining        (prefer full-fill)
--
-- ── SCHEMA ADDITIONS REQUIRED ────────────────────────────────
--   public.offer_order_match_items.delivery_fee   numeric  NULL
--   public.farmers.road_distance_m                numeric  NULL
--     ↑ populated externally from Google Maps Directions API.
--   public.consumer_orders.quality                public.quality NOT NULL
--   public.consumer_orders.quality_fee            numeric        NOT NULL
--   public.offer_order_match.consumer_note        text           NULL
--   public.farmer_offers.available_from           date           NULL
--   public.farmer_offers.available_to             date           NULL
-- =============================================================
-- =============================================================
-- FUNCTION 0: public.create_consumer_delivery_fee
-- =============================================================
--
-- PURPOSE
--   Compute the base delivery fee (PHP) for a single farmer →
--   consumer leg. Distance is derived from the stored geography
--   columns on public.users using ST_Distance, which returns the
--   accurate spherical distance in metres between the two points.
--   A ROAD_FACTOR multiplier (default 1.3) adjusts for PH road
--   curves and island routing overhead.
--   All tuneable business constants are in the DECLARE block.
--
-- DISTANCE CALCULATION
--   ST_Distance(geography, geography) returns metres on the WGS-84
--   spheroid — no Haversine approximation, no float extraction.
--   Both p_farmer_location and p_consumer_location are the raw
--   geography column values (EWKB hex) from public.users.location.
--   straight_m   = ST_Distance(p_farmer_location, p_consumer_location)
--   road_est_m   = straight_m × ROAD_FACTOR
--
-- HOW IT WORKS (step by step)
--
--   STEP 1 — FREE SHIPPING GATE
--     If order_amount >= FREE_SHIPPING_MIN return 0.00 immediately.
--
--   STEP 2 — COMPUTE ROAD DISTANCE
--     ST_Distance on both geography values → straight_m.
--     Multiply by ROAD_FACTOR → road_est_m, road_est_km.
--
--   STEP 3 — BATCH EFFICIENCY RATE
--     Count active order-items for this farmer in the current cycle:
--       ≥ BATCH_BULK_MIN items → TRUCK_RATE_PER_KM
--       ≥ BATCH_VAN_MIN  items → VAN_RATE_PER_KM
--       <  BATCH_VAN_MIN items → STANDARD_RATE_PER_KM
--
--   STEP 4 — LOGISTICS TIER (FAR vs LOCAL)
--     FAR (is_far_pass=TRUE OR road_est_m > FAR_THRESHOLD_M):
--       AGGREGATE_BASE + (road_est_km × (batch_rate + FAR_RATE_SURCHARGE))
--     LOCAL:
--       LOCAL_BASE + (road_est_km × batch_rate)
--
--   STEP 5 — COMMUNITY DENSITY DISCOUNT
--     ST_DWithin(u.location, p_consumer_location, DENSITY_RADIUS_M)
--     counts active orders near the consumer:
--       ≥ DENSITY_HIGH_MIN → 0.50  (50 % shared logistics)
--       ≥ DENSITY_MED_MIN  → 0.75  (25 % shared logistics)
--
--   STEP 6 — RETURN
--     ROUND(GREATEST(base_fee × community_discount, 0.00), 2)
--
-- PARAMETERS
--   p_farmer_location    geography column value from public.users.location
--                        for the farmer. Stored as EWKB hex.
--   p_consumer_location  geography column value from public.users.location
--                        for the consumer. Stored as EWKB hex.
--   order_amount         Combined goods subtotal (PHP) for this farmer's
--                        items in the batch. Checked against FREE_SHIPPING_MIN.
--   p_farmer_id          UUID of the farmer (user_id); for batch-density.
--   is_far_pass          TRUE when the offer came from IS-ANY pass C2.
--
-- RETURNS  NUMERIC — base delivery fee in PHP, rounded to 2 decimal places.
-- =============================================================
CREATE OR REPLACE FUNCTION public.create_consumer_delivery_fee(
        p_farmer_location geography,
        p_consumer_location geography,
        order_amount NUMERIC,
        p_farmer_id UUID,
        is_far_pass BOOLEAN DEFAULT FALSE
    ) RETURNS NUMERIC AS $$
DECLARE -- ── Tuneable business constants ───────────────────────────────────
    -- Road-winding multiplier applied to the ST_Distance straight-line
    -- result to estimate actual road distance in the Philippine archipelago.
    ROAD_FACTOR CONSTANT NUMERIC := 1.3;
-- Orders at or above this PHP value receive free delivery.
FREE_SHIPPING_MIN CONSTANT NUMERIC := 5000.00;
-- Base handling fee for a local (last-mile / rider) delivery.
LOCAL_BASE CONSTANT NUMERIC := 45.00;
-- Base handling fee for a long-haul (truck / RORO) delivery.
AGGREGATE_BASE CONSTANT NUMERIC := 600.00;
-- Estimated road distance above which the FAR tier applies (metres).
-- 60 km = 60,000 m.
FAR_THRESHOLD_M CONSTANT NUMERIC := 60000.0;
-- Per-km rates by vehicle class.
STANDARD_RATE_PER_KM CONSTANT NUMERIC := 12.00;
VAN_RATE_PER_KM CONSTANT NUMERIC := 8.00;
TRUCK_RATE_PER_KM CONSTANT NUMERIC := 4.00;
-- Extra per-km surcharge for FAR tier line-haul overhead.
FAR_RATE_SURCHARGE CONSTANT NUMERIC := 2.00;
-- Batch-size thresholds for vehicle class selection.
BATCH_BULK_MIN CONSTANT INTEGER := 30;
BATCH_VAN_MIN CONSTANT INTEGER := 10;
-- Neighbour count thresholds for community discount.
DENSITY_HIGH_MIN CONSTANT INTEGER := 10;
DENSITY_MED_MIN CONSTANT INTEGER := 3;
-- Radius (metres) for community density count via ST_DWithin.
DENSITY_RADIUS_M CONSTANT NUMERIC := 1000.0;
-- ── Working variables ─────────────────────────────────────────────
straight_m NUMERIC;
-- ST_Distance result in metres
road_est_m NUMERIC;
-- straight_m × ROAD_FACTOR
road_est_km NUMERIC;
-- road_est_m / 1000
farmer_batch_size INTEGER;
neighbor_count INTEGER;
dynamic_rate_per_km NUMERIC;
base_fee NUMERIC;
community_discount NUMERIC := 1.0;
BEGIN -- ── STEP 1: FREE SHIPPING GATE ────────────────────────────────────
IF order_amount >= FREE_SHIPPING_MIN THEN RETURN 0.00;
END IF;
-- ── STEP 2: COMPUTE ROAD DISTANCE FROM STORED GEOGRAPHY ──────────
-- ST_Distance(geography, geography) returns metres on the WGS-84
-- spheroid. Both values are the raw EWKB hex column reads — no
-- float extraction or point reconstruction required.
straight_m := ST_Distance(p_farmer_location, p_consumer_location);
road_est_m := straight_m * ROAD_FACTOR;
road_est_km := road_est_m / 1000.0;
-- ── STEP 3: BATCH EFFICIENCY RATE ────────────────────────────────
SELECT COUNT(*) INTO farmer_batch_size
FROM public.offer_order_match_items oomi
    JOIN public.consumer_orders co ON co.order_id = oomi.order_id
    JOIN public.user_farmers uf ON uf.farmer_id = oomi.farmer_id
WHERE uf.user_id = p_farmer_id
    AND oomi.delivery_status IN (
        'PENDING',
        'ACCEPTED',
        'PREPARING',
        'READY_FOR_QC'
    );
IF farmer_batch_size >= BATCH_BULK_MIN THEN dynamic_rate_per_km := TRUCK_RATE_PER_KM;
ELSIF farmer_batch_size >= BATCH_VAN_MIN THEN dynamic_rate_per_km := VAN_RATE_PER_KM;
ELSE dynamic_rate_per_km := STANDARD_RATE_PER_KM;
END IF;
-- ── STEP 4: LOGISTICS TIER ────────────────────────────────────────
IF is_far_pass
OR road_est_m > FAR_THRESHOLD_M THEN base_fee := AGGREGATE_BASE + (
    road_est_km * (dynamic_rate_per_km + FAR_RATE_SURCHARGE)
);
ELSE base_fee := LOCAL_BASE + (road_est_km * dynamic_rate_per_km);
END IF;
-- ── STEP 5: COMMUNITY DENSITY DISCOUNT ───────────────────────────
-- Use ST_DWithin on geography — operates in metres, uses spatial index.
SELECT COUNT(*) INTO neighbor_count
FROM public.consumer_orders co
    JOIN public.offer_order_match_items oomi ON oomi.order_id = co.order_id
    JOIN public.users u ON u.id = (
        SELECT uc.user_id
        FROM public.user_consumers uc
        WHERE uc.consumer_id = co.consumer_id
        LIMIT 1
    )
WHERE oomi.delivery_status IN (
        'PENDING',
        'ACCEPTED',
        'PREPARING',
        'READY_FOR_QC'
    )
    AND ST_DWithin(
        u.location,
        p_consumer_location,
        DENSITY_RADIUS_M
    );
IF neighbor_count >= DENSITY_HIGH_MIN THEN community_discount := 0.50;
ELSIF neighbor_count >= DENSITY_MED_MIN THEN community_discount := 0.75;
END IF;
-- ── STEP 6: RETURN ────────────────────────────────────────────────
RETURN ROUND(GREATEST(base_fee * community_discount, 0.00), 2);
END;
$$ LANGUAGE plpgsql;
-- =============================================================
-- =============================================================
-- FUNCTION 2: public.create_consumer_order
-- =============================================================
--
-- PURPOSE
--   Inner per-produce-line allocation engine. Resolves which farmer
--   offers fulfil each variety-group in the request, updates
--   farmer_offers.remaining_quantity, and stages the results for
--   Pass 2 INSERT. Does NOT write offer_order_match rows (that is
--   the outer function's responsibility).
--
-- EXPANDING RADIUS
--   Each group independently expands its search radius when stock
--   is insufficient. Radius doubles up to max_expansions times
--   before the group is declared unfulfillable (RETURN NULL).
--
-- IS-ANY VARIETY PRIORITY + is_far FLAG
--   The two-pass C1/C2 greedy loop is implemented here. Offers
--   consumed in C2 (far fallback) are tracked in a parallel boolean
--   array (grp_is_far_flags) so the outer function can pass
--   is_far_pass=TRUE to create_consumer_delivery_fee for those items.
--
-- RETURN jsonb
--   {
--     "order_ids":      ["<uuid>", ...],
--     "offer_ids":      ["<uuid>", ...],
--     "farmer_ids":     ["<text>", ...],
--     "offer_order_map":["<uuid>", ...],
--     "is_far_flags":   [true|false, ...]   ← parallel to offer_ids
--   }
--   Returns NULL if any group cannot be fulfilled at any radius.
--
-- PARAMETERS
--   or_consumer_id        Consumer identifier (text).
--   or_user_consumer_id   Consumer user UUID (for location lookup).
--   or_produce_id         UUID of the produce type being ordered.
--   or_variety_groups     jsonb array of variety-group objects.
--   or_date_needed        Requested fulfilment date.
--   or_quality            Quality tier enum (Saver / Regular / Select).
--   or_quality_fee        Client-supplied rate; canonical rate wins on mismatch.
--   max_distance_km       Initial search radius in km (default 50).
--   max_expansions        Maximum radius-doubling attempts (default 4).
-- =============================================================
CREATE OR REPLACE FUNCTION public.create_consumer_order(
        or_consumer_id text,
        or_user_consumer_id uuid,
        or_produce_id uuid,
        or_variety_groups jsonb,
        or_date_needed date,
        or_quality public.quality DEFAULT 'Saver',
        or_quality_fee numeric DEFAULT 0,
        max_distance_km double precision DEFAULT 50,
        max_expansions int DEFAULT 4
    ) RETURNS jsonb AS $$
DECLARE -- ── Expanding radius state ────────────────────────────────────────
    current_distance_km double precision := max_distance_km;
current_distance_m double precision;
expansion_step int := 0;
max_distance_m double precision;
n_groups int;
-- ── Quality fee ───────────────────────────────────────────────────
canonical_rate numeric;
produce_subtotal numeric := 0;
quality_fee_amount numeric := 0;
-- ── Batch output accumulators ─────────────────────────────────────
all_order_ids uuid [] := '{}';
all_offer_ids uuid [] := '{}';
all_farmer_ids text [] := '{}';
all_offer_order_map uuid [] := '{}';
all_is_far_flags boolean [] := '{}';
-- parallel to all_offer_ids
-- ── Per-group allocation state ────────────────────────────────────
grp jsonb;
grp_idx int;
grp_variety_ids uuid [] := '{}';
grp_quantity numeric;
grp_is_any boolean;
remaining numeric;
total_available numeric;
var_rec RECORD;
cur RECORD;
qty_to_take numeric;
-- SPECIFIC mode (reset per group)
v_prices numeric [];
v_qty_taken numeric [];
grp_listing_ids uuid [];
v_variety_idx int;
v_variety_price numeric;
-- IS-ANY mode (reset per group)
any_variety_ids uuid [] := '{}';
any_listing_ids uuid [] := '{}';
any_qty_taken numeric [] := '{}';
any_prices numeric [] := '{}';
any_variety_pos int;
-- Per-group offer staging (flushed into all_* at end of group)
grp_offer_ids uuid [] := '{}';
grp_farmer_ids text [] := '{}';
grp_is_far_flags boolean [] := '{}';
-- TRUE for C2 (far) offers
-- ── Pass 1 staging arrays (1-indexed, one slot per group) ─────────
staged_grp jsonb [] := '{}';
staged_is_any boolean [] := '{}';
staged_variety_ids_j jsonb [] := '{}';
staged_prices_j jsonb [] := '{}';
staged_qty_taken_j jsonb [] := '{}';
staged_listing_ids_j jsonb [] := '{}';
staged_any_var_ids_j jsonb [] := '{}';
staged_any_listing_ids_j jsonb [] := '{}';
staged_any_qty_j jsonb [] := '{}';
staged_any_prices_j jsonb [] := '{}';
staged_offer_ids_j jsonb [] := '{}';
staged_farmer_ids_j jsonb [] := '{}';
staged_is_far_flags_j jsonb [] := '{}';
-- jsonb boolean array per group
-- ── Pass 2 working variables ──────────────────────────────────────
grp_order_id uuid;
v_insert_idx int;
p2_variety_ids uuid [];
p2_listing_ids uuid [];
p2_prices numeric [];
p2_qty_taken numeric [];
p2_any_var_ids uuid [];
p2_any_listing_ids uuid [];
p2_any_qty numeric [];
p2_any_prices numeric [];
p2_offer_ids uuid [];
p2_farmer_ids text [];
p2_is_far_flags boolean [];
p2_grp_subtotal numeric;
-- Helpers
v_jidx int;
v_vid text;
v_lid text;
group_fulfilled boolean;
-- Variety / Listing helpers
grp_form_names text [] := '{}';
v_selected_form_name text;
v_is_price_locked boolean := false;
BEGIN -- ================================================================
-- PRICE LOCK CHECK
-- ================================================================
SELECT is_price_locked INTO v_is_price_locked
FROM public.user_consumers
WHERE user_id = or_user_consumer_id
LIMIT 1;
-- QUALITY RATE ENFORCEMENT
-- ================================================================
canonical_rate := CASE
    or_quality
    WHEN 'Saver' THEN 0.00
    WHEN 'Regular' THEN 0.05
    WHEN 'Select' THEN 0.15
    ELSE 0.00
END;
IF or_quality_fee IS DISTINCT
FROM canonical_rate THEN RAISE NOTICE 'Quality fee rate mismatch for quality "%": client sent %, canonical rate is %. Canonical rate will be used.',
    or_quality,
    or_quality_fee,
    canonical_rate;
END IF;
IF or_variety_groups IS NULL
OR jsonb_typeof(or_variety_groups) <> 'array'
OR jsonb_array_length(or_variety_groups) = 0 THEN RAISE EXCEPTION 'or_variety_groups must be a non-empty JSON array';
END IF;
n_groups := jsonb_array_length(or_variety_groups);
-- ================================================================
-- PASS 1 — ALLOCATE ALL GROUPS; STAGE RESULTS
-- No INSERTs here. Stock is locked and decremented; all results
-- are staged in arrays so produce_subtotal can be computed before
-- any rows are written.
-- ================================================================
FOR grp_idx IN 1..n_groups LOOP grp := or_variety_groups->(grp_idx - 1);
grp_quantity := (grp->>'quantity')::numeric;
IF grp_quantity IS NULL
OR grp_quantity <= 0 THEN RAISE EXCEPTION 'variety_group[%]: quantity must be > 0',
grp_idx;
END IF;
-- Parse variety_ids; skip NULL / blank entries.
grp_variety_ids := ARRAY []::uuid [];
IF jsonb_typeof(grp->'variety_ids') = 'array' THEN FOR v_jidx IN 0..jsonb_array_length(grp->'variety_ids') - 1 LOOP v_vid := grp->'variety_ids'->>v_jidx;
IF v_vid IS NOT NULL
AND v_vid <> '' THEN grp_variety_ids := array_append(grp_variety_ids, v_vid::uuid);
END IF;
END LOOP;
END IF;
-- Parse form_names; skip NULL / blank entries.
grp_form_names := ARRAY []::text [];
IF jsonb_typeof(grp->'form_names') = 'array' THEN FOR v_jidx IN 0..jsonb_array_length(grp->'form_names') - 1 LOOP v_lid := grp->'form_names'->>v_jidx;
IF v_lid IS NOT NULL
AND v_lid <> '' THEN grp_form_names := array_append(grp_form_names, v_lid);
END IF;
END LOOP;
END IF;
grp_is_any := (cardinality(grp_variety_ids) = 0);
-- Reset all per-group accumulators.
IF NOT grp_is_any THEN v_prices := ARRAY(
    SELECT 0.0
    FROM generate_series(1, cardinality(grp_variety_ids))
);
v_qty_taken := ARRAY(
    SELECT 0.0
    FROM generate_series(1, cardinality(grp_variety_ids))
);
grp_listing_ids := ARRAY(
    SELECT NULL::uuid
    FROM generate_series(1, cardinality(grp_variety_ids))
);
ELSE v_prices := ARRAY []::numeric [];
v_qty_taken := ARRAY []::numeric [];
grp_listing_ids := ARRAY []::uuid [];
END IF;
any_variety_ids := ARRAY []::uuid [];
any_listing_ids := ARRAY []::uuid [];
any_qty_taken := ARRAY []::numeric [];
any_prices := ARRAY []::numeric [];
grp_offer_ids := ARRAY []::uuid [];
grp_farmer_ids := ARRAY []::text [];
grp_is_far_flags := ARRAY []::boolean [];
-- ------------------------------------------------------------
-- STEP A — CAPACITY CHECK WITH EXPANDING RADIUS
-- ------------------------------------------------------------
current_distance_km := max_distance_km;
expansion_step := 0;
group_fulfilled := false;
LOOP current_distance_m := current_distance_km * 1000;
SELECT COALESCE(SUM(fo.remaining_quantity), 0) INTO total_available
FROM public.farmer_offers fo
    JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
    JOIN public.user_farmers uf ON uf.farmer_id = fo.farmer_id
    JOIN public.users u ON u.id = uf.user_id
WHERE pv.produce_id = or_produce_id
    AND (
        (
            grp_is_any
            AND (
                cardinality(grp_form_names) = 0
                OR EXISTS (
                    SELECT 1
                    FROM public.produce_variety_listing pvl2
                    WHERE pvl2.listing_id = fo.listing_id
                        AND pvl2.produce_form = ANY(grp_form_names)
                )
            )
        )
        OR (
            NOT grp_is_any
            AND EXISTS (
                SELECT 1
                FROM unnest(grp_variety_ids, grp_form_names) AS t(vid, lid)
                WHERE t.vid = fo.variety_id
                    AND (
                        t.lid IS NULL
                        OR EXISTS (
                            SELECT 1
                            FROM public.produce_variety_listing pvl
                            WHERE pvl.listing_id = fo.listing_id
                                AND pvl.produce_form = t.lid
                        )
                    )
            )
        )
    )
    AND fo.remaining_quantity > 0
    AND ST_DWithin(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        ),
        current_distance_m
    );
IF total_available >= grp_quantity THEN group_fulfilled := true;
EXIT;
END IF;
IF expansion_step >= max_expansions THEN RAISE NOTICE 'Group [%] rejected: stock %.2f < requested %.2f even at maximum expanded radius of %.0f km for consumer %.',
grp_idx,
total_available,
grp_quantity,
current_distance_km,
or_user_consumer_id;
RETURN NULL;
END IF;
RAISE NOTICE 'Group [%]: insufficient stock (%.2f of %.2f) within %.0f km. Expanding to %.0f km (expansion %/%).',
grp_idx,
total_available,
grp_quantity,
current_distance_km,
current_distance_km * 2,
expansion_step + 1,
max_expansions;
current_distance_km := current_distance_km * 2;
expansion_step := expansion_step + 1;
END LOOP;
current_distance_m := current_distance_km * 1000;
IF expansion_step > 0 THEN RAISE NOTICE 'Group [%]: fulfilled using expanded radius %.0f km (%.0f km originally requested).',
grp_idx,
current_distance_km,
max_distance_km;
END IF;
-- ------------------------------------------------------------
-- STEP B — PRICE MAP (SPECIFIC MODE ONLY)
-- ------------------------------------------------------------
IF NOT grp_is_any THEN FOR v_variety_idx IN 1..cardinality(grp_variety_ids) LOOP v_selected_form_name := NULL;
IF v_variety_idx <= cardinality(grp_form_names) THEN v_selected_form_name := grp_form_names [v_variety_idx];
END IF;
IF v_selected_form_name IS NOT NULL THEN
SELECT pvl.duruha_to_consumer_price,
    pvl.listing_id INTO v_variety_price,
    v_lid
FROM public.produce_variety_listing pvl
WHERE pvl.produce_form = v_selected_form_name
    AND pvl.variety_id = grp_variety_ids [v_variety_idx]
LIMIT 1;
ELSE -- No specific listing requested: pick the cheapest listing for this variety
SELECT pvl.duruha_to_consumer_price,
    pvl.listing_id INTO v_variety_price,
    v_lid
FROM public.produce_variety_listing pvl
WHERE pvl.variety_id = grp_variety_ids [v_variety_idx]
ORDER BY pvl.duruha_to_consumer_price ASC
LIMIT 1;
END IF;
v_prices [v_variety_idx] := COALESCE(v_variety_price, 0.0);
v_qty_taken [v_variety_idx] := 0.0;
grp_listing_ids [v_variety_idx] := v_lid;
END LOOP;
END IF;
-- ------------------------------------------------------------
-- STEP C — GREEDY ALLOCATION (two-pass for IS-ANY)
--
        -- SPECIFIC mode: single loop, all offers within current_distance_m.
--   All offers receive is_far = FALSE (caller named the varieties).
--
        -- IS-ANY mode:
--   Pass C1 — varieties with ≥1 offer within BASE max_distance_km.
--             is_far = FALSE for all C1 offers.
--   Pass C2 — runs only when remaining > 0 after C1.
--             Varieties where EVERY offer exceeds max_distance_km.
--             is_far = TRUE for all C2 offers.
--             A NOTICE is raised per far variety consumed.
-- ------------------------------------------------------------
remaining := grp_quantity;
-- ── C1 ────────────────────────────────────────────────────────
FOR var_rec IN
SELECT fo.variety_id,
    fo.listing_id,
    COALESCE(MIN(pvl.duruha_to_consumer_price), 0.0) AS variety_price,
    SUM(fo.remaining_quantity) AS total_remaining
FROM public.farmer_offers fo
    JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
    LEFT JOIN public.produce_variety_listing pvl ON pvl.listing_id = fo.listing_id
    JOIN public.user_farmers uf ON uf.farmer_id = fo.farmer_id
    JOIN public.users u ON u.id = uf.user_id
WHERE pv.produce_id = or_produce_id
    AND (
        (
            grp_is_any
            AND (
                cardinality(grp_form_names) = 0
                OR EXISTS (
                    SELECT 1
                    FROM public.produce_variety_listing pvl2
                    WHERE pvl2.listing_id = fo.listing_id
                        AND pvl2.produce_form = ANY(grp_form_names)
                )
            )
        )
        OR (
            NOT grp_is_any
            AND EXISTS (
                SELECT 1
                FROM unnest(grp_variety_ids, grp_form_names) AS t(vid, lid)
                WHERE t.vid = fo.variety_id
                    AND (
                        t.lid IS NULL
                        OR EXISTS (
                            SELECT 1
                            FROM public.produce_variety_listing pvl2
                            WHERE pvl2.listing_id = fo.listing_id
                                AND pvl2.produce_form = t.lid
                        )
                    )
            )
        )
    )
    AND fo.remaining_quantity > 0
    AND ST_DWithin(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        ),
        CASE
            WHEN grp_is_any THEN max_distance_km * 1000 -- base radius for IS-ANY C1
            ELSE current_distance_m -- effective radius for SPECIFIC
        END
    )
GROUP BY fo.variety_id,
    fo.listing_id
ORDER BY total_remaining DESC LOOP EXIT
    WHEN remaining <= 0;
FOR cur IN
SELECT fo.offer_id,
    fo.remaining_quantity,
    fo.farmer_id,
    fo.available_from,
    fo.available_to
FROM public.farmer_offers fo
    JOIN public.user_farmers uf ON uf.farmer_id = fo.farmer_id
    JOIN public.users u ON u.id = uf.user_id
WHERE fo.variety_id = var_rec.variety_id
    AND fo.listing_id IS NOT DISTINCT
FROM var_rec.listing_id
    AND fo.remaining_quantity > 0
    AND ST_DWithin(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        ),
        current_distance_m
    )
ORDER BY ST_Distance(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        )
    ) ASC,
    CASE
        WHEN fo.available_from <= or_date_needed THEN 0
        ELSE 1
    END ASC,
    ABS(fo.available_to - or_date_needed) ASC,
    ABS(fo.available_from - or_date_needed) ASC,
    CASE
        WHEN fo.remaining_quantity >= remaining THEN 0
        ELSE 1
    END ASC FOR
UPDATE SKIP LOCKED LOOP EXIT
    WHEN remaining <= 0;
qty_to_take := LEAST(cur.remaining_quantity, remaining);
UPDATE public.farmer_offers
SET remaining_quantity = remaining_quantity - qty_to_take,
    is_active = CASE
        WHEN remaining_quantity - qty_to_take <= 0 THEN false
        ELSE is_active
    END
WHERE offer_id = cur.offer_id;
grp_offer_ids := array_append(grp_offer_ids, cur.offer_id);
grp_farmer_ids := array_append(grp_farmer_ids, cur.farmer_id::text);
grp_is_far_flags := array_append(grp_is_far_flags, false);
-- C1 = not far
remaining := remaining - qty_to_take;
IF NOT grp_is_any THEN v_variety_idx := array_position(grp_variety_ids, var_rec.variety_id);
IF v_variety_idx IS NOT NULL THEN v_qty_taken [v_variety_idx] := v_qty_taken [v_variety_idx] + qty_to_take;
-- Capture listing_id and variety price for staging
grp_listing_ids [v_variety_idx] := var_rec.listing_id;
v_prices [v_variety_idx] := COALESCE(var_rec.variety_price, 0.0);
END IF;
ELSE -- In Any mode, find position of this SPECIFIC (variety, listing) combination
any_variety_pos := NULL;
FOR i IN 1..cardinality(any_variety_ids) LOOP IF any_variety_ids [i] = var_rec.variety_id
AND any_listing_ids [i] IS NOT DISTINCT
FROM var_rec.listing_id THEN any_variety_pos := i;
EXIT;
END IF;
END LOOP;
IF any_variety_pos IS NULL THEN any_variety_ids := array_append(any_variety_ids, var_rec.variety_id);
any_listing_ids := array_append(any_listing_ids, var_rec.listing_id);
any_qty_taken := array_append(any_qty_taken, qty_to_take);
any_prices := array_append(
    any_prices,
    COALESCE(var_rec.variety_price, 0.0)
);
ELSE any_qty_taken [any_variety_pos] := any_qty_taken [any_variety_pos] + qty_to_take;
END IF;
END IF;
END LOOP;
-- inner offer loop (C1)
END LOOP;
-- outer variety loop (C1)
-- ── C2: Far fallback — IS-ANY only ────────────────────────────
IF grp_is_any
AND remaining > 0 THEN RAISE NOTICE 'Group [%] IS-ANY: %.2f units still needed after close-variety pass. Falling back to varieties beyond %.0f km (within effective %.0f km).',
grp_idx,
remaining,
max_distance_km,
current_distance_km;
FOR var_rec IN
SELECT fo.variety_id,
    fo.listing_id,
    COALESCE(MIN(pvl.duruha_to_consumer_price), 0.0) AS variety_price,
    SUM(fo.remaining_quantity) AS total_remaining
FROM public.farmer_offers fo
    JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
    LEFT JOIN public.produce_variety_listing pvl ON pvl.listing_id = fo.listing_id
    JOIN public.user_farmers uf ON uf.farmer_id = fo.farmer_id
    JOIN public.users u ON u.id = uf.user_id
WHERE pv.produce_id = or_produce_id
    AND (
        cardinality(grp_form_names) = 0
        OR EXISTS (
            SELECT 1
            FROM public.produce_variety_listing pvl2
            WHERE pvl2.listing_id = fo.listing_id
                AND pvl2.produce_form = ANY(grp_form_names)
        )
    )
    AND fo.remaining_quantity > 0 -- C2 only: variety has NO offers within the base radius.
    AND NOT EXISTS (
        SELECT 1
        FROM public.farmer_offers fo2
            JOIN public.user_farmers uf2 ON uf2.farmer_id = fo2.farmer_id
            JOIN public.users u2b ON u2b.id = uf2.user_id
        WHERE fo2.variety_id = fo.variety_id
            AND fo2.listing_id IS NOT DISTINCT
        FROM fo.listing_id
            AND fo2.remaining_quantity > 0
            AND ST_DWithin(
                u2b.location::geography,
                (
                    SELECT u3.location::geography
                    FROM public.users u3
                    WHERE u3.id = or_user_consumer_id
                ),
                max_distance_km * 1000
            )
    )
    AND ST_DWithin(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        ),
        current_distance_m
    )
GROUP BY fo.variety_id,
    fo.listing_id
ORDER BY total_remaining DESC LOOP EXIT
    WHEN remaining <= 0;
RAISE NOTICE 'Group [%] IS-ANY: using far variety % (all farmers > %.0f km).',
grp_idx,
var_rec.variety_id,
max_distance_km;
FOR cur IN
SELECT fo.offer_id,
    fo.remaining_quantity,
    fo.farmer_id,
    fo.available_from,
    fo.available_to
FROM public.farmer_offers fo
    JOIN public.user_farmers uf ON uf.farmer_id = fo.farmer_id
    JOIN public.users u ON u.id = uf.user_id
WHERE fo.variety_id = var_rec.variety_id
    AND fo.listing_id IS NOT DISTINCT
FROM var_rec.listing_id
    AND fo.remaining_quantity > 0
    AND ST_DWithin(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        ),
        current_distance_m
    )
ORDER BY ST_Distance(
        u.location::geography,
        (
            SELECT u2.location::geography
            FROM public.users u2
            WHERE u2.id = or_user_consumer_id
        )
    ) ASC,
    CASE
        WHEN fo.available_from <= or_date_needed THEN 0
        ELSE 1
    END ASC,
    ABS(fo.available_to - or_date_needed) ASC,
    ABS(fo.available_from - or_date_needed) ASC,
    CASE
        WHEN fo.remaining_quantity >= remaining THEN 0
        ELSE 1
    END ASC FOR
UPDATE SKIP LOCKED LOOP EXIT
    WHEN remaining <= 0;
qty_to_take := LEAST(cur.remaining_quantity, remaining);
UPDATE public.farmer_offers
SET remaining_quantity = remaining_quantity - qty_to_take,
    is_active = CASE
        WHEN remaining_quantity - qty_to_take <= 0 THEN false
        ELSE is_active
    END
WHERE offer_id = cur.offer_id;
grp_offer_ids := array_append(grp_offer_ids, cur.offer_id);
grp_farmer_ids := array_append(grp_farmer_ids, cur.farmer_id::text);
grp_is_far_flags := array_append(grp_is_far_flags, true);
-- C2 = far
remaining := remaining - qty_to_take;
any_variety_pos := NULL;
FOR i IN 1..cardinality(any_variety_ids) LOOP IF any_variety_ids [i] = var_rec.variety_id
AND any_listing_ids [i] IS NOT DISTINCT
FROM var_rec.listing_id THEN any_variety_pos := i;
EXIT;
END IF;
END LOOP;
IF any_variety_pos IS NULL THEN any_variety_ids := array_append(any_variety_ids, var_rec.variety_id);
any_listing_ids := array_append(any_listing_ids, var_rec.listing_id);
any_qty_taken := array_append(any_qty_taken, qty_to_take);
any_prices := array_append(
    any_prices,
    COALESCE(var_rec.variety_price, 0.0)
);
ELSE any_qty_taken [any_variety_pos] := any_qty_taken [any_variety_pos] + qty_to_take;
END IF;
END LOOP;
-- inner offer loop (C2)
END LOOP;
-- outer variety loop (C2)
END IF;
-- IS-ANY far fallback
-- ------------------------------------------------------------
-- STEP D — SAFETY ASSERTION
-- ------------------------------------------------------------
IF remaining > 0 THEN RAISE EXCEPTION 'Unexpected error: group [%] could not be fully fulfilled for consumer % (remaining: %)',
grp_idx,
or_user_consumer_id,
remaining;
END IF;
-- ------------------------------------------------------------
-- STEP E — STAGE THIS GROUP'S RESULTS
-- ------------------------------------------------------------
staged_grp := array_append(staged_grp, grp);
staged_is_any := array_append(staged_is_any, grp_is_any);
IF NOT grp_is_any THEN staged_variety_ids_j := array_append(
    staged_variety_ids_j,
    (
        SELECT jsonb_agg(v::text)
        FROM unnest(grp_variety_ids) v
    )
);
staged_listing_ids_j := array_append(
    staged_listing_ids_j,
    (
        SELECT jsonb_agg(v::text)
        FROM unnest(grp_listing_ids) v
    )
);
staged_prices_j := array_append(
    staged_prices_j,
    (
        SELECT jsonb_agg(v)
        FROM unnest(v_prices) v
    )
);
staged_qty_taken_j := array_append(
    staged_qty_taken_j,
    (
        SELECT jsonb_agg(v)
        FROM unnest(v_qty_taken) v
    )
);
staged_any_var_ids_j := array_append(staged_any_var_ids_j, NULL);
staged_any_listing_ids_j := array_append(staged_any_listing_ids_j, NULL);
staged_any_qty_j := array_append(staged_any_qty_j, NULL);
staged_any_prices_j := array_append(staged_any_prices_j, NULL);
ELSE staged_any_var_ids_j := array_append(
    staged_any_var_ids_j,
    (
        SELECT jsonb_agg(v::text)
        FROM unnest(any_variety_ids) v
    )
);
staged_any_listing_ids_j := array_append(
    staged_any_listing_ids_j,
    (
        SELECT jsonb_agg(v::text)
        FROM unnest(any_listing_ids) v
    )
);
staged_any_qty_j := array_append(
    staged_any_qty_j,
    (
        SELECT jsonb_agg(v)
        FROM unnest(any_qty_taken) v
    )
);
staged_any_prices_j := array_append(
    staged_any_prices_j,
    (
        SELECT jsonb_agg(v)
        FROM unnest(any_prices) v
    )
);
staged_variety_ids_j := array_append(staged_variety_ids_j, NULL);
staged_listing_ids_j := array_append(staged_listing_ids_j, NULL);
staged_prices_j := array_append(staged_prices_j, NULL);
staged_qty_taken_j := array_append(staged_qty_taken_j, NULL);
END IF;
staged_offer_ids_j := array_append(
    staged_offer_ids_j,
    (
        SELECT jsonb_agg(v::text)
        FROM unnest(grp_offer_ids) v
    )
);
staged_farmer_ids_j := array_append(
    staged_farmer_ids_j,
    (
        SELECT jsonb_agg(v)
        FROM unnest(grp_farmer_ids) v
    )
);
-- Stage far-flags as a jsonb boolean array.
staged_is_far_flags_j := array_append(
    staged_is_far_flags_j,
    (
        SELECT jsonb_agg(v)
        FROM unnest(grp_is_far_flags) v
    )
);
END LOOP;
-- pass 1
-- ================================================================
-- COMPUTE PRODUCE SUBTOTAL AND QUALITY FEE AMOUNT
-- ================================================================
FOR grp_idx IN 1..n_groups LOOP IF NOT staged_is_any [grp_idx] THEN
SELECT COALESCE(
        SUM(
            (staged_qty_taken_j [grp_idx]->>(k -1))::numeric * (staged_prices_j [grp_idx]->>(k -1))::numeric
        ),
        0
    ) INTO p2_grp_subtotal
FROM generate_series(
        1,
        jsonb_array_length(staged_qty_taken_j [grp_idx])
    ) k;
ELSE
SELECT COALESCE(
        SUM(
            (staged_any_qty_j [grp_idx]->>(k -1))::numeric * (staged_any_prices_j [grp_idx]->>(k -1))::numeric
        ),
        0
    ) INTO p2_grp_subtotal
FROM generate_series(
        1,
        jsonb_array_length(staged_any_qty_j [grp_idx])
    ) k;
END IF;
produce_subtotal := produce_subtotal + COALESCE(p2_grp_subtotal, 0);
END LOOP;
-- quality_fee_amount holds the TOTAL fee for all groups (used for reference)
-- but each group row stores its own proportional fee computed in Pass 2.
quality_fee_amount := produce_subtotal * canonical_rate;
-- ================================================================
-- PASS 2 — INSERT consumer_orders AND consumer_orders_varieties
-- ================================================================
FOR grp_idx IN 1..n_groups LOOP IF NOT staged_is_any [grp_idx] THEN
SELECT array_agg(
        e::text::uuid
        ORDER BY ordinality
    ) INTO p2_variety_ids
FROM jsonb_array_elements_text(staged_variety_ids_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::text::uuid
        ORDER BY ordinality
    ) INTO p2_listing_ids
FROM jsonb_array_elements_text(staged_listing_ids_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::numeric
        ORDER BY ordinality
    ) INTO p2_prices
FROM jsonb_array_elements_text(staged_prices_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::numeric
        ORDER BY ordinality
    ) INTO p2_qty_taken
FROM jsonb_array_elements_text(staged_qty_taken_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
ELSE
SELECT array_agg(
        e::text::uuid
        ORDER BY ordinality
    ) INTO p2_any_var_ids
FROM jsonb_array_elements_text(staged_any_var_ids_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::text::uuid
        ORDER BY ordinality
    ) INTO p2_any_listing_ids
FROM jsonb_array_elements_text(staged_any_listing_ids_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::numeric
        ORDER BY ordinality
    ) INTO p2_any_qty
FROM jsonb_array_elements_text(staged_any_qty_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::numeric
        ORDER BY ordinality
    ) INTO p2_any_prices
FROM jsonb_array_elements_text(staged_any_prices_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
END IF;
SELECT array_agg(
        e::text::uuid
        ORDER BY ordinality
    ) INTO p2_offer_ids
FROM jsonb_array_elements_text(staged_offer_ids_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::text
        ORDER BY ordinality
    ) INTO p2_farmer_ids
FROM jsonb_array_elements_text(staged_farmer_ids_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
SELECT array_agg(
        e::boolean
        ORDER BY ordinality
    ) INTO p2_is_far_flags
FROM jsonb_array_elements(staged_is_far_flags_j [grp_idx]) WITH ORDINALITY t(e, ordinality);
-- INSERT consumer_orders (quality_fee = per-group computed amount, not rate).
-- Recompute p2_grp_subtotal for this group so we can store the proportional fee.
IF NOT staged_is_any [grp_idx] THEN
SELECT COALESCE(
        SUM(
            (staged_qty_taken_j [grp_idx]->>(k -1))::numeric * (staged_prices_j [grp_idx]->>(k -1))::numeric
        ),
        0
    ) INTO p2_grp_subtotal
FROM generate_series(
        1,
        jsonb_array_length(staged_qty_taken_j [grp_idx])
    ) k;
ELSE
SELECT COALESCE(
        SUM(
            (staged_any_qty_j [grp_idx]->>(k -1))::numeric * (staged_any_prices_j [grp_idx]->>(k -1))::numeric
        ),
        0
    ) INTO p2_grp_subtotal
FROM generate_series(
        1,
        jsonb_array_length(staged_any_qty_j [grp_idx])
    ) k;
END IF;
INSERT INTO public.consumer_orders (
        order_id,
        consumer_id,
        produce_id,
        is_any,
        group_id,
        date_needed,
        quality,
        quality_fee,
        created_at,
        updated_at
    )
VALUES (
        gen_random_uuid(),
        or_consumer_id,
        or_produce_id,
        staged_is_any [grp_idx],
        COALESCE(
            (staged_grp [grp_idx]->>'group_id')::int,
            grp_idx
        ),
        or_date_needed,
        or_quality,
        COALESCE(p2_grp_subtotal, 0) * canonical_rate,
        now(),
        now()
    )
RETURNING order_id INTO grp_order_id;
all_order_ids := array_append(all_order_ids, grp_order_id);
-- Flush offers into batch accumulators (including is_far flags).
FOR v_insert_idx IN 1..COALESCE(cardinality(p2_offer_ids), 0) LOOP all_offer_ids := array_append(all_offer_ids, p2_offer_ids [v_insert_idx]);
all_farmer_ids := array_append(all_farmer_ids, p2_farmer_ids [v_insert_idx]);
all_offer_order_map := array_append(all_offer_order_map, grp_order_id);
all_is_far_flags := array_append(
    all_is_far_flags,
    p2_is_far_flags [v_insert_idx]
);
END LOOP;
-- INSERT consumer_orders_varieties.
IF NOT staged_is_any [grp_idx] THEN FOR v_insert_idx IN 1..COALESCE(cardinality(p2_variety_ids), 0) LOOP
INSERT INTO public.consumer_orders_varieties (
        order_id,
        variety_id,
        quantity,
        price,
        group_id,
        listing_id,
        price_locked
    )
VALUES (
        grp_order_id,
        p2_variety_ids [v_insert_idx],
        p2_qty_taken [v_insert_idx],
        p2_prices [v_insert_idx],
        COALESCE(
            (staged_grp [grp_idx]->>'group_id')::int,
            grp_idx
        ),
        COALESCE(p2_listing_ids [v_insert_idx], gen_random_uuid()),
        CASE
            WHEN v_is_price_locked THEN p2_prices [v_insert_idx]
            ELSE 0
        END
    );
END LOOP;
ELSE FOR v_insert_idx IN 1..COALESCE(cardinality(p2_any_var_ids), 0) LOOP
INSERT INTO public.consumer_orders_varieties (
        order_id,
        variety_id,
        quantity,
        price,
        group_id,
        listing_id,
        price_locked
    )
VALUES (
        grp_order_id,
        p2_any_var_ids [v_insert_idx],
        p2_any_qty [v_insert_idx],
        p2_any_prices [v_insert_idx],
        grp_idx,
        COALESCE(
            p2_any_listing_ids [v_insert_idx],
            gen_random_uuid()
        ),
        CASE
            WHEN v_is_price_locked THEN p2_any_prices [v_insert_idx]
            ELSE 0
        END
    );
END LOOP;
END IF;
END LOOP;
-- pass 2
-- ================================================================
-- RETURN — is_far_flags is parallel to offer_ids so the outer
-- function can route each offer to the correct delivery tier.
-- ================================================================
RETURN jsonb_build_object(
    'order_ids',
    COALESCE(
        (
            SELECT jsonb_agg(x)
            FROM unnest(all_order_ids) x
        ),
        '[]'::jsonb
    ),
    'offer_ids',
    COALESCE(
        (
            SELECT jsonb_agg(x)
            FROM unnest(all_offer_ids) x
        ),
        '[]'::jsonb
    ),
    'farmer_ids',
    COALESCE(
        (
            SELECT jsonb_agg(x)
            FROM unnest(all_farmer_ids) x
        ),
        '[]'::jsonb
    ),
    'offer_order_map',
    COALESCE(
        (
            SELECT jsonb_agg(x)
            FROM unnest(all_offer_order_map) x
        ),
        '[]'::jsonb
    ),
    'is_far_flags',
    COALESCE(
        (
            SELECT jsonb_agg(x)
            FROM unnest(all_is_far_flags) x
        ),
        '[]'::jsonb
    )
);
END;
$$ LANGUAGE plpgsql;
-- =============================================================
-- FUNCTION 2: public.create_consumer_orders
-- =============================================================
--
-- PURPOSE
--   Outer batch entry point. Receives the full application payload,
--   validates each produce line, delegates allocation to the inner
--   function, then writes:
--     • One offer_order_match header row for the entire basket.
--     • One offer_order_match_items row per farmer offer consumed,
--       including delivery_fee computed by create_consumer_delivery_fee().
--
-- DELIVERY FEE INTEGRATION (Step 6)
--   For each offer_order_match_items row the outer function:
--     1. Reads the farmer's location geography column from public.users via
--        public.user_farmers. No float extraction — the EWKB value is
--        used directly in ST_DWithin / ST_Distance.
--        public.user_farmers.
--     2. Consumer GPS is resolved once in Step 3 and reused.
--     3. Fetches the subtotal of the linked consumer_orders row
--        (SUM of quantity × price from consumer_orders_varieties).
--        quality_fee is excluded — it is a platform fee, not goods value.
--     4. Reads the is_far flag from the inner function's return JSON.
--        TRUE when the offer came from the IS-ANY far-fallback pass C2.
--     5. Calls create_consumer_delivery_fee() and stores the result in
--        offer_order_match_items.delivery_fee.
--
-- PAYLOAD SHAPE
--   [
--     {
--       "consumer_id":    "text",
--       "produce_id":     "uuid",
--       "date_needed":    "YYYY-MM-DD",
--       "quality":        "Saver" | "Regular" | "Select",
--       "quality_fee":    0.0,
--       "variety_groups": [
--         { "variety_ids": ["uuid",...], "quantity": 100 },
--         { "variety_ids": [],           "quantity": 60  }
--       ]
--     }, ...
--   ]
--
-- PARAMETERS
--   payload         jsonb array described above.
--   p_note          Optional free-text consumer note.
--   max_distance_km Initial farmer search radius in km (default 50).
--   max_expansions  Maximum radius doublings before giving up (default 4).
--
-- RETURNS
--   uuid — offer_order_match_id of the created match header.
-- =============================================================
CREATE OR REPLACE FUNCTION public.create_consumer_orders(
        payload jsonb,
        p_note text DEFAULT NULL,
        max_distance_km double precision DEFAULT 50,
        max_expansions int DEFAULT 4
    ) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE orders jsonb;
ord jsonb;
idx int := 0;
or_produce_id uuid;
or_user_id uuid;
or_consumer_in text;
or_consumer_user_id uuid;
or_date_needed date;
or_variety_groups jsonb;
or_quality public.quality;
or_quality_fee numeric;
batch_user_id uuid;
batch_consumer_id text;
alloc_result jsonb;
batch_order_ids uuid [] := ARRAY []::uuid [];
batch_offer_ids uuid [] := ARRAY []::uuid [];
batch_farmer_ids text [] := ARRAY []::text [];
batch_offer_order_ids uuid [] := ARRAY []::uuid [];
batch_is_far_flags boolean [] := ARRAY []::boolean [];
-- parallel to batch_offer_ids
line_offer_ids uuid [];
line_farmer_ids text [];
line_is_far_flags boolean [];
var_idx int;
use_postgis boolean := false;
n_offers int;
v_dispatch_at timestamptz;
-- Farmer and consumer locations as geography (EWKB hex column values).
-- Passed directly to ST_DWithin / ST_Distance — no float extraction needed.
v_farmer_user_id uuid;
v_farmer_location geography;
v_consumer_location geography;
-- Payment methods
v_consumer_payment_method public.payment_method;
-- ── Carrier assignment constants ──────────────────────────────────
CARRIER_SEARCH_RADIUS_KM CONSTANT double precision := 30.0;
DEFAULT_CARRIER_ID CONSTANT uuid := 'f1e11e69-e9b4-433c-b1bd-cc9b4ffa81dd'::uuid;
v_carrier_id uuid;
-- ── Per-farmer delivery fee split ─────────────────────────────────
-- Delivery is charged once per unique farmer-consumer leg.
-- When a farmer fulfils multiple items for the same consumer the
-- base fee is computed once and divided equally across those items.
--
    -- farmer_fee_map   : hstore-style parallel arrays tracking
--                    unique farmer_id → (base_fee, item_count)
-- These are populated in a pre-pass over batch_offer_ids before
-- the INSERT loop so each item can receive its pro-rated share.
unique_farmer_ids text [] := ARRAY []::text [];
farmer_base_fees numeric [] := ARRAY []::numeric [];
farmer_item_counts int [] := ARRAY []::int [];
v_farmer_pos int;
v_base_fee numeric;
v_item_count int;
v_delivery_fee numeric;
-- pro-rated share for this specific item
v_order_subtotal numeric;
v_match_id uuid;
BEGIN -- STEP 1 — VALIDATE PAYLOAD
IF payload IS NULL
OR jsonb_typeof(payload) <> 'array' THEN RAISE EXCEPTION 'payload must be a JSON array';
END IF;
IF jsonb_array_length(payload) = 0 THEN RAISE EXCEPTION 'payload array must not be empty';
END IF;
-- STEP 2 — CONFIRM POSTGIS
BEGIN PERFORM 1
FROM pg_extension
WHERE extname = 'postgis';
use_postgis := found;
EXCEPTION
WHEN OTHERS THEN use_postgis := false;
END;
IF NOT use_postgis THEN RAISE EXCEPTION 'PostGIS extension not found';
END IF;
-- Read the geography column value directly from public.users using user_id.
SELECT u.location::geography INTO v_consumer_location
FROM public.users u
WHERE u.id = (payload->0->>'user_id')::uuid
LIMIT 1;
orders := payload;
-- STEP 4 — LOOP EACH PRODUCE LINE AND ALLOCATE STOCK
FOR idx IN 0..jsonb_array_length(orders) - 1 LOOP ord := orders->idx;
alloc_result := NULL;
or_variety_groups := NULL;
or_produce_id := (ord->>'produce_id')::uuid;
or_user_id := (ord->>'user_id')::uuid;
or_date_needed := (ord->>'date_needed')::date;
or_variety_groups := ord->'variety_groups';
or_quality := COALESCE(
    (ord->>'quality')::public.quality,
    'Saver'::public.quality
);
or_quality_fee := COALESCE((ord->>'quality_fee')::numeric, 0);
IF or_produce_id IS NULL THEN RAISE EXCEPTION 'order[%]: produce_id is required',
idx;
END IF;
IF or_user_id IS NULL THEN RAISE EXCEPTION 'order[%]: user_id is required',
idx;
END IF;
IF or_date_needed IS NULL THEN RAISE EXCEPTION 'order[%]: date_needed is required',
idx;
END IF;
IF or_variety_groups IS NULL
OR jsonb_typeof(or_variety_groups) <> 'array'
OR jsonb_array_length(or_variety_groups) = 0 THEN RAISE EXCEPTION 'order[%]: variety_groups must be a non-empty array',
idx;
END IF;
-- Enforce single-user constraint.
IF batch_user_id IS NULL THEN batch_user_id := or_user_id;
ELSIF batch_user_id <> or_user_id THEN RAISE EXCEPTION 'order[%]: all orders must belong to the same user (expected %, got %)',
idx,
batch_user_id,
or_user_id;
END IF;
-- Resolve consumer_id and user_id (for internal consistency)
SELECT uc.consumer_id::text,
    uc.user_id::uuid INTO or_consumer_in,
    or_consumer_user_id
FROM public.user_consumers uc
WHERE uc.user_id = or_user_id;
IF or_consumer_in IS NULL THEN RAISE EXCEPTION 'order[%]: consumer role not found for user_id %',
idx,
or_user_id;
END IF;
IF batch_consumer_id IS NULL THEN batch_consumer_id := or_consumer_in;
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = or_consumer_user_id
        AND location IS NOT NULL
) THEN RAISE EXCEPTION 'order[%]: location not set for user_id %',
idx,
or_consumer_user_id;
END IF;
-- Delegate to the inner function.
alloc_result := public.create_consumer_order(
    or_consumer_id => or_consumer_in,
    or_user_consumer_id => or_consumer_user_id,
    or_produce_id => or_produce_id,
    or_variety_groups => or_variety_groups,
    or_date_needed => or_date_needed,
    or_quality => or_quality,
    or_quality_fee => or_quality_fee,
    max_distance_km => max_distance_km,
    max_expansions => max_expansions
);
IF alloc_result IS NULL THEN RAISE EXCEPTION 'order[%]: could not fulfill within maximum expanded radius (base % km, up to %× expansion) for produce_id %',
idx,
max_distance_km,
max_expansions,
or_produce_id;
END IF;
-- Merge this line's results into batch accumulators.
SELECT batch_order_ids || array_agg(
        v::uuid
        ORDER BY ordinality
    ) INTO batch_order_ids
FROM jsonb_array_elements_text(alloc_result->'order_ids') WITH ORDINALITY t(v, ordinality);
SELECT array_agg(
        v::uuid
        ORDER BY ordinality
    ) INTO line_offer_ids
FROM jsonb_array_elements_text(alloc_result->'offer_ids') WITH ORDINALITY t(v, ordinality);
SELECT array_agg(
        v::text
        ORDER BY ordinality
    ) INTO line_farmer_ids
FROM jsonb_array_elements_text(alloc_result->'farmer_ids') WITH ORDINALITY t(v, ordinality);
SELECT array_agg(
        v::boolean
        ORDER BY ordinality
    ) INTO line_is_far_flags
FROM jsonb_array_elements(alloc_result->'is_far_flags') WITH ORDINALITY t(v, ordinality);
batch_offer_ids := batch_offer_ids || COALESCE(line_offer_ids, ARRAY []::uuid []);
batch_farmer_ids := batch_farmer_ids || COALESCE(line_farmer_ids, ARRAY []::text []);
batch_is_far_flags := batch_is_far_flags || COALESCE(line_is_far_flags, ARRAY []::boolean []);
SELECT batch_offer_order_ids || array_agg(
        v::uuid
        ORDER BY ordinality
    ) INTO batch_offer_order_ids
FROM jsonb_array_elements_text(alloc_result->'offer_order_map') WITH ORDINALITY t(v, ordinality);
END LOOP;
IF array_length(batch_order_ids, 1) IS NULL THEN RAISE EXCEPTION 'No orders fulfilled; offer_order_match not created.';
END IF;
n_offers := COALESCE(array_length(batch_offer_ids, 1), 0);
-- STEP 5 — INSERT offer_order_match HEADER ROW
SELECT u.payment_methods [1] INTO v_consumer_payment_method
FROM public.user_consumers uc
    JOIN public.users u ON u.id = uc.user_id
WHERE uc.consumer_id = batch_consumer_id
LIMIT 1;
INSERT INTO public.offer_order_match (
        consumer_id,
        consumer_paid,
        consumer_payment_method,
        consumer_note
    )
VALUES (
        batch_consumer_id,
        false,
        v_consumer_payment_method,
        p_note
    )
RETURNING offer_order_match_id INTO v_match_id;
-- STEP 6 — INSERT offer_order_match_items WITH PRO-RATED DELIVERY FEE
--
    -- DELIVERY FEE POLICY: charge once per unique farmer → consumer leg.
-- If a farmer supplies multiple varieties or produce lines to the
-- same consumer (multiple items in batch_offer_ids sharing the same
-- farmer_id), the base delivery fee is computed once for that farmer
-- and then divided equally across all items from that farmer.
-- Multiple distinct farmers each incur their own full fee.
--
    -- Pre-pass A — for every unique farmer in the batch:
--   1. Read the farmer's geography from public.users (EWKB hex).
--   2. Count how many items in this batch belong to that farmer.
--   3. Call create_consumer_delivery_fee() once — distance is
--      computed inside the function via ST_Distance(farmer, consumer).
--   Store (farmer_id → base_fee, item_count) in parallel arrays.
--
    -- Insert loop B — iterate batch_offer_ids:
--   4. Look up this item's farmer in the parallel arrays.
--   5. pro_rated_fee = base_fee / item_count  (rounded to 2 dp).
--   6. INSERT with pro_rated_fee as delivery_fee.
v_dispatch_at := make_timestamptz(2100, 1, 1, 6, 0, 0, 'Asia/Manila');
-- ── Pre-pass A: compute one base_fee per unique farmer ───────────
FOR var_idx IN 1..n_offers LOOP v_farmer_pos := array_position(unique_farmer_ids, batch_farmer_ids [var_idx]);
IF v_farmer_pos IS NULL THEN -- New farmer encountered — fetch geography and order subtotal.
-- Read the farmer's location as geography directly from users.
-- The EWKB hex value is used as-is for ST_DWithin / ST_Distance.
SELECT uf.user_id,
    u.location::geography INTO v_farmer_user_id,
    v_farmer_location
FROM public.user_farmers uf
    JOIN public.users u ON u.id = uf.user_id
WHERE uf.farmer_id = batch_farmer_ids [var_idx]
LIMIT 1;
-- Goods subtotal across ALL items for this farmer in this batch
-- (used for the free-shipping gate inside create_consumer_delivery_fee).
SELECT COALESCE(SUM(cov.quantity * cov.price), 0) INTO v_order_subtotal
FROM public.consumer_orders_varieties cov
    JOIN public.consumer_orders co ON co.order_id = cov.order_id
WHERE co.order_id = ANY(
        ARRAY(
            SELECT batch_offer_order_ids [i]
            FROM generate_series(1, n_offers) i
            WHERE batch_farmer_ids [i] = batch_farmer_ids [var_idx]
        )
    );
-- Count how many items in this batch come from this farmer.
SELECT COUNT(*) INTO v_item_count
FROM generate_series(1, n_offers) i
WHERE batch_farmer_ids [i] = batch_farmer_ids [var_idx];
-- Call the delivery fee function once for this farmer.
-- Distance is computed inside via ST_Distance(farmer, consumer)
-- on the two geography column values — no separate distance lookup.
v_base_fee := public.create_consumer_delivery_fee(
    p_farmer_location => v_farmer_location,
    p_consumer_location => v_consumer_location,
    order_amount => v_order_subtotal,
    p_farmer_id => v_farmer_user_id,
    is_far_pass => COALESCE(batch_is_far_flags [var_idx], false)
);
-- Register in parallel tracking arrays.
unique_farmer_ids := array_append(unique_farmer_ids, batch_farmer_ids [var_idx]);
farmer_base_fees := array_append(farmer_base_fees, v_base_fee);
farmer_item_counts := array_append(farmer_item_counts, v_item_count);
END IF;
END LOOP;
-- pre-pass A
-- ── Insert loop B: write rows with pro-rated delivery fee ─────────
FOR var_idx IN 1..n_offers LOOP -- a. Farmer location (geography) and payment method.
-- Read the EWKB hex geography column directly — no float extraction.
SELECT uf.user_id,
    u.location::geography,
    u.payment_methods [1] INTO v_farmer_user_id,
    v_farmer_location
FROM public.user_farmers uf
    JOIN public.users u ON u.id = uf.user_id
WHERE uf.farmer_id = batch_farmer_ids [var_idx]
LIMIT 1;
-- b. Nearest carrier to the farmer.
-- v_farmer_location is the stored geography value; pass it directly
-- to ST_DWithin and ST_Distance — no reconstruction needed.
SELECT uc.id INTO v_carrier_id
FROM public.carriers uc
WHERE ST_DWithin(
        uc.location::geography,
        v_farmer_location,
        CARRIER_SEARCH_RADIUS_KM * 1000
    )
ORDER BY ST_Distance(
        uc.location::geography,
        v_farmer_location
    ) ASC
LIMIT 1;
IF v_carrier_id IS NULL THEN RAISE NOTICE 'No carrier found within %.0f km of farmer %. Assigning default carrier %.',
CARRIER_SEARCH_RADIUS_KM,
batch_farmer_ids [var_idx],
DEFAULT_CARRIER_ID;
v_carrier_id := DEFAULT_CARRIER_ID;
END IF;
-- c. Look up this farmer's pre-computed base fee and split it.
v_farmer_pos := array_position(unique_farmer_ids, batch_farmer_ids [var_idx]);
v_base_fee := farmer_base_fees [v_farmer_pos];
v_item_count := farmer_item_counts [v_farmer_pos];
-- Pro-rate: if farmer sends 3 items, each item pays 1/3 of the fee.
-- GREATEST guards against any rounding producing a tiny negative.
v_delivery_fee := ROUND(
    GREATEST(v_base_fee / NULLIF(v_item_count, 1), 0.00),
    2
);
-- Single-item case: item gets the full fee (no division needed).
IF v_item_count = 1 THEN v_delivery_fee := ROUND(GREATEST(v_base_fee, 0.00), 2);
END IF;
-- d. Insert with pro-rated delivery fee.
INSERT INTO public.offer_order_match_items (
        offer_order_match_id,
        offer_id,
        order_id,
        farmer_id,
        farmer_is_paid,
        delivery_status,
        carrier_id,
        dispatch_at,
        delivery_fee -- pro-rated share: base_fee ÷ items_from_this_farmer
    )
VALUES (
        v_match_id,
        batch_offer_ids [var_idx],
        batch_offer_order_ids [var_idx],
        batch_farmer_ids [var_idx],
        false,
        'PENDING'::public.delivery_status,
        v_carrier_id,
        v_dispatch_at,
        v_delivery_fee
    );
END LOOP;
-- insert loop B
-- STEP 7 — RETURN MATCH ID TO CALLER
RETURN v_match_id;
EXCEPTION
WHEN OTHERS THEN RAISE;
END;
$$;