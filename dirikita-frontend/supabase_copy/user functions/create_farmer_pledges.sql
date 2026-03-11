CREATE OR REPLACE FUNCTION create_farmer_pledges(p_order_id UUID, p_pledges JSONB) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_id UUID;
v_farmer_id TEXT;
v_pledge JSONB;
v_variety JSONB;
v_covg_id UUID;
v_date_needed DATE;
v_cov_id UUID;
v_quantity NUMERIC;
-- consumer_orders_variety fields
v_variety_id UUID;
v_selection_type public.selection_type;
v_price_lock NUMERIC;
-- pricing
v_listing_row public.produce_variety_listing %ROWTYPE;
v_ftd_price NUMERIC;
-- farmer_offers_allocations
v_foa_id UUID;
-- offer_order_match
v_oom_exists BOOLEAN;
v_consumer_id TEXT;
v_total_kg NUMERIC := 0;
v_order_amount NUMERIC := 0;
v_item_count INTEGER := 0;
v_delivery_fee NUMERIC;
v_inserted_ooms JSONB := '[]'::JSONB;
v_result_entry JSONB;
v_best_carrier_id TEXT;
-- quantity tracking per pledge
v_covg_quantity NUMERIC;
v_pledged_total NUMERIC;
v_supplied_cov_ids UUID [];
BEGIN -- ----------------------------------------------------------------
-- 1. Resolve caller → farmer_id
-- ----------------------------------------------------------------
v_user_id := auth.uid();
IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: no authenticated user';
END IF;
SELECT farmer_id INTO v_farmer_id
FROM user_farmers
WHERE user_id = v_user_id
LIMIT 1;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'Caller (user_id: %) is not a registered farmer',
v_user_id;
END IF;
-- ----------------------------------------------------------------
-- 2. Validate order exists and resolve consumer_id
-- ----------------------------------------------------------------
SELECT consumer_id INTO v_consumer_id
FROM consumer_orders
WHERE order_id = p_order_id;
IF NOT FOUND THEN RAISE EXCEPTION 'order_id % not found in consumer_orders',
p_order_id;
END IF;
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'order_id % has no consumer_id',
p_order_id;
END IF;
-- ----------------------------------------------------------------
-- 3. Iterate pledges
-- ----------------------------------------------------------------
FOR v_pledge IN
SELECT *
FROM jsonb_array_elements(p_pledges) LOOP v_covg_id := (v_pledge->>'covg_id')::UUID;
v_date_needed := (v_pledge->>'date_needed')::DATE;
-- 3a. Validate covg_id + date_needed exist and belong to order_id
IF NOT EXISTS (
    SELECT 1
    FROM consumer_orders_variety_group covg
        JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
    WHERE covg.covg_id = v_covg_id
        AND covg.date_needed = v_date_needed
        AND cop.order_id = p_order_id
) THEN RAISE EXCEPTION 'covg_id % with date_needed % not found for order_id %',
v_covg_id,
v_date_needed,
p_order_id;
END IF;
-- ----------------------------------------------------------------
-- 3b. Fetch covg required quantity
-- ----------------------------------------------------------------
SELECT quantity INTO v_covg_quantity
FROM consumer_orders_variety_group
WHERE covg_id = v_covg_id;
-- ----------------------------------------------------------------
-- 3c. Sum total pledged quantity across all varieties in this pledge.
--     RAISE EXCEPTION immediately if it overflows covg.quantity.
-- ----------------------------------------------------------------
SELECT COALESCE(SUM((el->>'quantity')::NUMERIC), 0) INTO v_pledged_total
FROM jsonb_array_elements(v_pledge->'varieties') AS el;
IF v_pledged_total > v_covg_quantity THEN RAISE EXCEPTION 'Pledged total quantity (%) exceeds covg required quantity (%) for covg_id %',
v_pledged_total,
v_covg_quantity,
v_covg_id;
END IF;
-- ----------------------------------------------------------------
-- 3d. Collect supplied cov_ids from varieties[]
-- ----------------------------------------------------------------
SELECT ARRAY(
        SELECT (el->>'cov_id')::UUID
        FROM jsonb_array_elements(v_pledge->'varieties') AS el
    ) INTO v_supplied_cov_ids;
-- ----------------------------------------------------------------
-- 3e. DENY all cov rows in this covg_id NOT in the supplied list
-- ----------------------------------------------------------------
UPDATE consumer_orders_variety
SET selection_type = 'DENIED'
WHERE covg_id = v_covg_id
    AND cov_id <> ALL(v_supplied_cov_ids)
    AND selection_type = 'OPEN';
-- ----------------------------------------------------------------
-- 3f. Iterate supplied varieties → FULFILL each one
-- ----------------------------------------------------------------
FOR v_variety IN
SELECT *
FROM jsonb_array_elements(v_pledge->'varieties') LOOP v_cov_id := (v_variety->>'cov_id')::UUID;
v_quantity := (v_variety->>'quantity')::NUMERIC;
-- Fetch cov row; must belong to covg_id and be OPEN
SELECT variety_id,
    selection_type,
    price_lock INTO v_variety_id,
    v_selection_type,
    v_price_lock
FROM consumer_orders_variety
WHERE cov_id = v_cov_id
    AND covg_id = v_covg_id;
IF NOT FOUND THEN RAISE EXCEPTION 'cov_id % does not belong to covg_id %',
v_cov_id,
v_covg_id;
END IF;
IF v_selection_type <> 'OPEN' THEN RAISE EXCEPTION 'cov_id % selection_type is %, expected OPEN',
v_cov_id,
v_selection_type;
END IF;
-- Mark as PLEDGED
UPDATE consumer_orders_variety
SET selection_type = 'PLEDGED'
WHERE cov_id = v_cov_id;
-- 3g. Resolve pricing
SELECT * INTO v_listing_row
FROM produce_variety_listing
WHERE variety_id = v_variety_id
ORDER BY updated_at DESC
LIMIT 1;
IF NOT FOUND THEN RAISE EXCEPTION 'No listing found for variety_id %',
v_variety_id;
END IF;
v_ftd_price := v_listing_row.farmer_to_duruha_price;
-- 3i. Insert farmer_offers_allocations
INSERT INTO farmer_offers_allocations (
        quantity,
        cov_id,
        payment_method,
        ftd_price,
        price_lock,
        final_price,
        is_paid,
        farmer_id
    )
VALUES (
        v_quantity,
        v_cov_id,
        'cash',
        v_ftd_price,
        v_price_lock,
        v_ftd_price,
        false,
        v_farmer_id
    )
RETURNING foa_id INTO v_foa_id;
-- 3j. Calculate delivery fee
v_total_kg := v_quantity;
v_order_amount := v_ftd_price * v_quantity;
v_item_count := 1;
v_delivery_fee := mo_calculate_delivery_fee(
    v_consumer_id,
    v_farmer_id,
    v_total_kg,
    v_order_amount,
    v_item_count
);
v_best_carrier_id := mo_best_carrier(v_consumer_id);
-- 3k. Upsert offer_order_match
SELECT EXISTS (
        SELECT 1
        FROM offer_order_match
        WHERE cov_id = v_cov_id
    ) INTO v_oom_exists;
IF v_oom_exists THEN
UPDATE offer_order_match
SET foa_id = v_foa_id,
    delivery_fee = v_delivery_fee,
    delivery_status = 'ACCEPTED',
    carrier_id = v_best_carrier_id,
    updated_at = now()
WHERE cov_id = v_cov_id;
ELSE
INSERT INTO offer_order_match (
        cov_id,
        foa_id,
        dispatch_at,
        delivery_fee,
        delivery_status,
        consumer_has_paid
    )
VALUES (
        v_cov_id,
        v_foa_id,
        '2100-01-01 00:00:00+00',
        v_delivery_fee,
        'PENDING',
        false
    );
END IF;
-- Collect result
v_result_entry := jsonb_build_object(
    'cov_id',
    v_cov_id,
    'foa_id',
    v_foa_id,
    'delivery_fee',
    v_delivery_fee,
    'ftd_price',
    v_ftd_price,
    'oom_updated',
    v_oom_exists
);
v_inserted_ooms := v_inserted_ooms || jsonb_build_array(v_result_entry);
END LOOP;
-- varieties
END LOOP;
-- pledges
RETURN jsonb_build_object(
    'order_id',
    p_order_id,
    'consumer_id',
    v_consumer_id,
    'farmer_id',
    v_farmer_id,
    'results',
    v_inserted_ooms
);
EXCEPTION
WHEN OTHERS THEN RAISE;
END;
$$;
REVOKE ALL ON FUNCTION create_farmer_pledges(UUID, JSONB)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_farmer_pledges(UUID, JSONB) TO authenticated;