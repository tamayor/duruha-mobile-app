CREATE OR REPLACE FUNCTION public.plan_orders(p_payload jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id uuid;
v_consumer_id text;
v_order_id uuid;
v_payment_method text;
p_note text;
-- address
v_user_address uuid;
-- validated consumer address UUID
-- active plan subscription (consumer_plan_subscriptions + consumer_plan_configs)
v_cps_id uuid;
v_cps_ends_at timestamptz;
v_cpc_min numeric;
-- consumer_plan_configs.min_order_value
v_cpc_max numeric;
-- consumer_plan_configs.max_order_value
v_cpc_quality text;
-- consumer_plan_configs.quality_level
-- pre-validation accumulators (Flutter-aligned: flat loop, no group/solo split)
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
v_cov_id uuid;
v_cop_id uuid;
v_cop_index integer;
v_quality text;
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
-- ── 1a. Resolve & validate consumer address ───────────────────────────────
--        Priority:
--          1. p_user_address from payload → must exist in
--             users_addresses AND belong to auth.uid()
--          2. Fallback to users.address_id (profile default)
DECLARE v_payload_address uuid := (p_payload->>'p_user_address')::uuid;
BEGIN IF v_payload_address IS NOT NULL THEN IF NOT EXISTS (
    SELECT 1
    FROM public.users_addresses ua
    WHERE ua.address_id = v_payload_address
        AND ua.user_id = v_user_id
) THEN RAISE EXCEPTION 'Address % does not belong to this user',
v_payload_address USING HINT = 'Forbidden',
ERRCODE = 'P0003';
END IF;
v_user_address := v_payload_address;
ELSE
SELECT u.address_id INTO v_user_address
FROM public.users u
WHERE u.id = v_user_id;
END IF;
IF v_user_address IS NULL THEN RAISE EXCEPTION 'No address found. Please set your address in profile.' USING HINT = 'Bad Request',
ERRCODE = 'P0001';
END IF;
END;
-- ── 2. Parse top-level fields ─────────────────────────────────────────────
v_payment_method := NULLIF(
    TRIM(COALESCE(p_payload->>'payment_method', '')),
    ''
);
p_note := p_payload->>'p_note';
-- ── 3. Require an active plan subscription ────────────────────────────────
--      plan_orders is a plan-mode function — no subscription = no order.
SELECT cps.cps_id,
    cps.ends_at,
    cpc.min_order_value,
    cpc.max_order_value,
    cpc.quality_level INTO v_cps_id,
    v_cps_ends_at,
    v_cpc_min,
    v_cpc_max,
    v_cpc_quality
FROM public.consumer_plan_subscriptions cps
    JOIN public.consumer_plan_configs cpc ON cpc.cpc_id = cps.cpc_id
WHERE cps.consumer_id = v_consumer_id
    AND cps.status = 'active'
    AND cps.ends_at > now()
ORDER BY cps.ends_at DESC
LIMIT 1;
IF v_cps_id IS NULL THEN RAISE EXCEPTION 'Plan orders require an active subscription. Consumer % does not have a valid active plan.',
v_consumer_id;
END IF;
-- ── 4. PRE-VALIDATION: order value range vs plan limits ───────────────────
FOR v_produce IN
SELECT *
FROM jsonb_array_elements(p_payload->'p_orders') LOOP v_produce_id := (v_produce->>'produce_id')::uuid;
FOR v_item IN
SELECT *
FROM jsonb_array_elements(v_produce->'order_items') LOOP v_form := v_item->>'form';
v_quantity := (v_item->>'quantity')::numeric;
v_dates := v_item->'date_needed';
v_date_count := jsonb_array_length(v_dates);
-- 4a. Track latest date for subscription expiry check
SELECT MAX((d.value#>>'{}')::date) INTO v_date_val
FROM jsonb_array_elements(v_dates) AS d(value);
IF v_latest_date IS NULL
OR v_date_val > v_latest_date THEN v_latest_date := v_date_val;
END IF;
-- 4b. Get MIN and MAX duruha_to_consumer_price
--     across the provided variety_ids for this form.
--     If variety_ids is empty / all blank → is_any → scan ALL varieties for this produce+form.
v_is_any := NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements_text(v_item->'variety_ids') AS v
    WHERE v <> ''
);
IF v_is_any THEN -- All varieties for this produce + form
SELECT MIN(pvl.duruha_to_consumer_price),
    MAX(pvl.duruha_to_consumer_price) INTO v_any_min_price,
    v_any_max_price
FROM public.produce_variety_listing pvl
    JOIN public.produce_varieties pv ON pv.variety_id = pvl.variety_id
WHERE pv.produce_id = v_produce_id
    AND pvl.produce_form = v_form;
ELSE -- Only the specific variety_ids supplied in the payload
SELECT MIN(pvl.duruha_to_consumer_price),
    MAX(pvl.duruha_to_consumer_price) INTO v_any_min_price,
    v_any_max_price
FROM public.produce_variety_listing pvl
WHERE pvl.variety_id IN (
        SELECT (vid.value#>>'{}')::uuid
        FROM jsonb_array_elements(v_item->'variety_ids') AS vid(value)
        WHERE (vid.value#>>'{}') <> ''
    )
    AND pvl.produce_form = v_form;
END IF;
-- Accumulate: min price × qty × dates  |  max price × qty × dates
v_total_min_value := v_total_min_value + COALESCE(v_any_min_price, 0) * v_quantity * v_date_count;
v_total_max_value := v_total_max_value + COALESCE(v_any_max_price, 0) * v_quantity * v_date_count;
END LOOP;
-- order_items
END LOOP;
-- p_orders
-- 4c. All requested dates must fall within the subscription period
IF v_latest_date IS NOT NULL
AND v_latest_date > v_cps_ends_at::date THEN RAISE EXCEPTION 'Order dates extend beyond your plan subscription expiry (%). Latest date requested: %.',
v_cps_ends_at::date,
v_latest_date;
END IF;
-- 4d. Order value range must overlap with the plan's min/max order value.
IF v_cpc_max IS NOT NULL
AND v_total_min_value > v_cpc_max THEN RAISE EXCEPTION 'Estimated minimum order value (%) exceeds your plan''s maximum allowed order value (%).',
v_total_min_value,
v_cpc_max;
END IF;
IF v_cpc_min IS NOT NULL
AND v_total_max_value < v_cpc_min THEN RAISE EXCEPTION 'Estimated maximum order value (%) is below your plan''s minimum required order value (%).',
v_total_max_value,
v_cpc_min;
END IF;
-- ── 5. Insert consumer_orders ─────────────────────────────────────────────
INSERT INTO public.consumer_orders (consumer_id, note, is_active)
VALUES (v_consumer_id, p_note, true)
RETURNING order_id INTO v_order_id;
-- ── 6. Loop over each produce order ───────────────────────────────────────
FOR v_produce IN
SELECT *
FROM jsonb_array_elements(p_payload->'p_orders') LOOP v_produce_id := (v_produce->>'produce_id')::uuid;
-- Quality: prefer per-produce quality from payload,
-- fall back to the plan's quality_level, then default 'Saver'.
v_quality := COALESCE(
    NULLIF(TRIM(v_produce->>'quality'), ''),
    v_cpc_quality,
    'Saver'
);
v_cop_index := 0;
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
-- One consumer_orders_produce row per order_item
INSERT INTO public.consumer_orders_produce (order_id, produce_id, quality, item_index)
VALUES (v_order_id, v_produce_id, v_quality, v_cop_index)
RETURNING cop_id INTO v_cop_id;
v_cop_index := v_cop_index + 1;
v_item_index := 0;
FOR v_date_needed IN
SELECT (d.value#>>'{}')::date
FROM jsonb_array_elements(v_dates) AS d(value) LOOP -- One covg per date
INSERT INTO public.consumer_orders_variety_group (
        item_index,
        form,
        quantity,
        is_any,
        cop_id,
        date_needed,
        cps_id
    )
VALUES (
        v_item_index,
        v_form,
        v_quantity,
        v_is_any,
        v_cop_id,
        v_date_needed,
        v_cps_id
    )
RETURNING covg_id INTO v_covg_id;
IF v_is_any THEN -- ── Case 1: is_any — insert all varieties for this produce + form ──
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
v_var_cons_price := v_dtc_price;
INSERT INTO public.consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        auto_assign,
        listing_id,
        final_price,
        price_lock,
        dtc_price,
        selection_type,
        is_price_lock
    )
VALUES (
        v_covg_id,
        v_item_index,
        v_variety_id,
        true,
        v_listing_id,
        v_final_price,
        v_price_lock,
        v_var_cons_price,
        'OPEN'::public.selection_type,
        FALSE
    )
RETURNING cov_id INTO v_cov_id;
INSERT INTO public.offer_order_match (
        cov_id,
        delivery_status,
        dispatch_at,
        consumer_has_paid,
        consumer_address,
        farmer_address
    )
VALUES (
        v_cov_id,
        'PENDING'::public.delivery_status,
        '2100-01-01 00:00:00+00'::timestamptz,
        false,
        v_user_address,
        NULL
    );
END LOOP;
ELSE -- ── Case 2: specific variety_ids ──────────────────────────
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
INSERT INTO public.consumer_orders_variety (
        covg_id,
        item_index,
        variety_id,
        auto_assign,
        listing_id,
        final_price,
        price_lock,
        dtc_price,
        selection_type,
        is_price_lock
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
        'OPEN'::public.selection_type,
        FALSE
    )
RETURNING cov_id INTO v_cov_id;
INSERT INTO public.offer_order_match (
        cov_id,
        delivery_status,
        dispatch_at,
        consumer_has_paid,
        consumer_address,
        farmer_address
    )
VALUES (
        v_cov_id,
        'PENDING'::public.delivery_status,
        '2100-01-01 00:00:00+00'::timestamptz,
        false,
        v_user_address,
        NULL
    );
END LOOP;
END IF;
-- is_any vs specific
v_item_index := v_item_index + 1;
END LOOP;
-- dates (covg)
END LOOP;
-- order_items (cop)
END LOOP;
-- p_orders
RETURN v_order_id;
END;
$$;