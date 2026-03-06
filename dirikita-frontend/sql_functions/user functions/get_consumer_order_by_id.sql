CREATE OR REPLACE FUNCTION public.plan_orders(p_payload jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id uuid;
v_consumer_id text;
v_order_id uuid;
v_payment_method text;
v_is_cash boolean;
p_note text;
-- future plan subscription
v_cfps_id uuid;
v_cfps_expires_at timestamptz;
v_cfp_min numeric;
v_cfp_max numeric;
-- pre-validation accumulators
v_total_min_value numeric := 0;
-- cheapest possible total  (min dtc × qty × dates)
v_total_max_value numeric := 0;
-- priciest possible total  (max dtc × qty × dates)
v_latest_date date;
v_produce jsonb;
v_item jsonb;
v_variety_id uuid;
v_produce_id uuid;
v_form text;
v_dtc_price numeric;
v_date_val date;
v_any_min_price numeric;
-- cheapest listing for produce+form (is_any)
v_any_max_price numeric;
-- priciest listing for produce+form (is_any)
v_date_count integer;
-- insertion variables
v_cop_id uuid;
v_quality public.quality;
v_item_index integer;
v_quantity numeric;
v_is_any boolean;
v_dates jsonb;
v_date_needed date;
v_covg_id uuid;
v_listing_id uuid;
v_final_price numeric;
v_price_lock numeric;
v_var_cons_price numeric;
BEGIN -- ── 1. Resolve consumer ───────────────────────────────────────────────────
v_user_id := auth.uid();
SELECT consumer_id INTO v_consumer_id
FROM public.user_consumers
WHERE user_id = v_user_id
LIMIT 1;
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'No consumer profile found for user %',
v_user_id;
END IF;
-- ── 2. Parse top-level fields ─────────────────────────────────────────────
v_payment_method := p_payload->>'payment_method';
v_is_cash := (v_payment_method = 'Cash');
p_note := p_payload->>'p_note';
-- ── 3. Check for active future plan subscription ──────────────────────────
SELECT cfps.cfps_id,
    cfps.expires_at,
    cfg.min_total_value,
    cfg.max_total_value INTO v_cfps_id,
    v_cfps_expires_at,
    v_cfp_min,
    v_cfp_max
FROM public.consumer_future_plan_subscriptions cfps
    JOIN public.consumer_future_plan_configs cfg ON cfg.cfp_id = cfps.cfp_id
WHERE cfps.consumer_id = v_consumer_id
    AND cfps.is_active = true
ORDER BY cfps.expires_at DESC
LIMIT 1;
-- ── 4. PRE-VALIDATION (only when consumer has an active future plan) ──────
IF v_cfps_id IS NOT NULL THEN FOR v_produce IN
SELECT *
FROM jsonb_array_elements(p_payload->'p_orders') LOOP v_produce_id := (v_produce->>'produce_id')::uuid;
FOR v_item IN
SELECT *
FROM jsonb_array_elements(v_produce->'order_items') LOOP v_form := v_item->>'form';
v_quantity := (v_item->>'quantity')::numeric;
v_dates := v_item->'date_needed';
v_date_count := jsonb_array_length(v_dates);
v_is_any := NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements_text(v_item->'variety_ids') AS v
    WHERE v <> ''
);
-- 4a. Track latest date for expiry check
SELECT MAX((d.value#>>'{}')::date) INTO v_date_val
FROM jsonb_array_elements(v_dates) AS d(value);
IF v_latest_date IS NULL
OR v_date_val > v_latest_date THEN v_latest_date := v_date_val;
END IF;
IF v_is_any THEN -- ── is_any: scan ALL listings for this produce + form ──────
-- Find cheapest and most expensive duruha_to_consumer_price
-- across every variety that belongs to this produce and form.
SELECT MIN(pvl.duruha_to_consumer_price),
    MAX(pvl.duruha_to_consumer_price) INTO v_any_min_price,
    v_any_max_price
FROM public.produce_variety_listing pvl
    JOIN public.produce_varieties pv ON pv.variety_id = pvl.variety_id
WHERE pv.produce_id = v_produce_id
    AND pvl.produce_form = v_form;
-- min total uses cheapest listing, max total uses priciest
v_total_min_value := v_total_min_value + COALESCE(v_any_min_price, 0) * v_quantity * v_date_count;
v_total_max_value := v_total_max_value + COALESCE(v_any_max_price, 0) * v_quantity * v_date_count;
ELSE -- ── specific varieties: use each variety's own listing ─────
FOR v_variety_id IN
SELECT (vid.value#>>'{}')::uuid
FROM jsonb_array_elements(v_item->'variety_ids') AS vid(value)
WHERE (vid.value#>>'{}') <> '' LOOP
SELECT pvl.duruha_to_consumer_price INTO v_dtc_price
FROM public.produce_variety_listing pvl
WHERE pvl.variety_id = v_variety_id
    AND pvl.produce_form = v_form
LIMIT 1;
-- specific varieties: same price for both min and max
v_total_min_value := v_total_min_value + COALESCE(v_dtc_price, 0) * v_quantity * v_date_count;
v_total_max_value := v_total_max_value + COALESCE(v_dtc_price, 0) * v_quantity * v_date_count;
END LOOP;
END IF;
END LOOP;
-- order_items
END LOOP;
-- p_orders
-- 4b. All dates must not exceed the subscription expiry
IF v_latest_date > v_cfps_expires_at::date THEN RAISE EXCEPTION 'Order dates extend beyond your Future Plan subscription expiry (%). Latest date requested: %.',
v_cfps_expires_at::date,
v_latest_date;
END IF;
-- 4c. The possible price RANGE of the order must overlap with the plan range.
--     We abort if even the cheapest scenario exceeds max, or
--     the priciest scenario is below min.
IF v_total_min_value > v_cfp_max
OR v_total_max_value < v_cfp_min THEN RAISE EXCEPTION 'Estimated order value range (% – %) does not fall within your Future Plan range (% – %).',
v_total_min_value,
v_total_max_value,
v_cfp_min,
v_cfp_max;
END IF;
END IF;
-- end future plan pre-validation
-- ── 5. Insert consumer_orders ─────────────────────────────────────────────
INSERT INTO public.consumer_orders (
        consumer_id,
        note,
        payment_method,
        is_active
    )
VALUES (
        v_consumer_id,
        p_note,
        v_payment_method::public.payment_method,
        true
    )
RETURNING order_id INTO v_order_id;
-- ── 6. Loop over each produce order ───────────────────────────────────────
FOR v_produce IN
SELECT *
FROM jsonb_array_elements(p_payload->'p_orders') LOOP v_quality := (v_produce->>'quality')::public.quality;
v_produce_id := (v_produce->>'produce_id')::uuid;
-- 6a. Insert consumer_orders_produce
INSERT INTO public.consumer_orders_produce (
        order_id,
        produce_id,
        quality,
        quality_fee
    )
VALUES (
        v_order_id,
        v_produce_id,
        v_quality,
        NULL
    )
RETURNING cop_id INTO v_cop_id;
-- 6b. Loop over order_items
v_item_index := 0;
FOR v_item IN
SELECT *
FROM jsonb_array_elements(v_produce->'order_items') LOOP v_form := v_item->>'form';
v_quantity := (v_item->>'quantity')::numeric;
v_is_any := NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements_text(v_item->'variety_ids') AS v
    WHERE v <> ''
);
v_dates := v_item->'date_needed';
-- 6c. One consumer_orders_variety_group row per date
FOR v_date_needed IN
SELECT (d.value#>>'{}')::date
FROM jsonb_array_elements(v_dates) AS d(value) LOOP
INSERT INTO public.consumer_orders_variety_group (
        item_index,
        form,
        quantity,
        is_any,
        cop_id,
        date_needed,
        cpls_id,
        cfps_id
    )
VALUES (
        v_item_index,
        v_form,
        v_quantity,
        v_is_any,
        v_cop_id,
        v_date_needed,
        NULL,
        v_cfps_id
    )
RETURNING covg_id INTO v_covg_id;
-- 6d. consumer_orders_variety insertion — three cases:
IF v_is_any
AND v_is_cash THEN -- ── Case 1: is_any + Cash ──────────────────────────────────
-- One empty placeholder row; variety will be assigned later
INSERT INTO public.consumer_orders_variety (
        covg_id,
        selection_type
    )
VALUES (
        v_covg_id,
        'OPEN'::public.selection_type
    );
ELSIF v_is_any
AND NOT v_is_cash THEN -- ── Case 2: is_any + Non-cash ──────────────────────────────
-- Insert ALL varieties of this produce+form with locked pricing
FOR v_variety_id IN
SELECT pv.variety_id
FROM public.produce_varieties pv
    JOIN public.produce_variety_listing pvl ON pvl.variety_id = pv.variety_id
    AND pvl.produce_form = v_form
WHERE pv.produce_id = v_produce_id LOOP
SELECT pvl.listing_id,
    pvl.duruha_to_consumer_price INTO v_listing_id,
    v_dtc_price
FROM public.produce_variety_listing pvl
WHERE pvl.variety_id = v_variety_id
    AND pvl.produce_form = v_form
LIMIT 1;
INSERT INTO public.consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        auto_assign,
        listing_id,
        final_price,
        price_lock,
        variable_consumer_price,
        selection_type
    )
VALUES (
        v_covg_id,
        v_item_index,
        v_variety_id,
        false,
        v_listing_id,
        v_dtc_price,
        -- final_price = dtc
        v_dtc_price,
        -- price_lock  = dtc
        v_dtc_price,
        -- variable    = dtc
        'OPEN'::public.selection_type
    );
END LOOP;
ELSE -- ── Case 3: specific variety_ids ───────────────────────────
FOR v_variety_id IN
SELECT (vid.value#>>'{}')::uuid
FROM jsonb_array_elements(v_item->'variety_ids') AS vid(value)
WHERE (vid.value#>>'{}') <> '' LOOP
SELECT pvl.listing_id,
    pvl.duruha_to_consumer_price INTO v_listing_id,
    v_dtc_price
FROM public.produce_variety_listing pvl
WHERE pvl.variety_id = v_variety_id
    AND pvl.produce_form = v_form
LIMIT 1;
v_var_cons_price := v_dtc_price;
IF v_is_cash THEN v_final_price := NULL;
v_price_lock := NULL;
ELSE v_final_price := v_dtc_price;
v_price_lock := v_dtc_price;
END IF;
INSERT INTO public.consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        auto_assign,
        listing_id,
        final_price,
        price_lock,
        variable_consumer_price,
        selection_type
    )
VALUES (
        v_covg_id,
        v_item_index,
        v_variety_id,
        false,
        v_listing_id,
        v_final_price,
        v_price_lock,
        v_var_cons_price,
        'OPEN'::public.selection_type
    );
END LOOP;
END IF;
-- variety insertion cases
END LOOP;
-- dates
v_item_index := v_item_index + 1;
END LOOP;
-- order_items
END LOOP;
-- p_orders
RETURN v_order_id;
END;
$$;