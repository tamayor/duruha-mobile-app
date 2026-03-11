-- Function: create_farmer_offers
-- Accepts an array of offer objects and bulk-inserts into farmer_offers.
-- SECURITY DEFINER ensures it runs with table owner privileges while
-- still enforcing auth.uid() === farmer_id via the users table lookup.
--
-- Price Lock logic (when is_price_lock = true):
--   1. Fetch farmer_to_duruha_price from produce_variety_listing using listing_id
--   2. Compute total_price_lock_credit = farmer_to_duruha_price * quantity
--   3. Validate it matches the payload's total_price_lock_credit (raises error on mismatch)
--   4. Check fpls.remaining_credits >= total_price_lock_credit
--   5. Deduct from fpls.remaining_credits
--   6. Insert offer with is_price_locked, total_price_lock_credit, remaining_price_lock_credit, fpls_id
CREATE OR REPLACE FUNCTION public.create_farmer_offers(
        p_offers JSONB -- array of offer objects
    ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_caller_uid UUID;
v_farmer_id TEXT;
v_offer JSONB;
v_inserted_ids UUID [] := '{}';
v_new_id UUID;
-- price lock vars
v_is_price_lock BOOLEAN;
v_fpls_id UUID;
v_listing_id UUID;
v_quantity NUMERIC;
v_farmer_to_duruha_price NUMERIC;
v_computed_credit NUMERIC;
v_payload_credit NUMERIC;
v_fpls_remaining NUMERIC;
BEGIN -- ── Auth check ──────────────────────────────────────────────────
v_caller_uid := auth.uid();
IF v_caller_uid IS NULL THEN RAISE EXCEPTION 'Unauthorized: authentication required';
END IF;
-- Resolve farmer_id from users table
SELECT farmer_id INTO v_farmer_id
FROM public.user_farmers
WHERE user_id = v_caller_uid
LIMIT 1;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: no farmer profile found for this user';
END IF;
-- ── Validate input ───────────────────────────────────────────────
IF p_offers IS NULL
OR jsonb_array_length(p_offers) = 0 THEN RETURN jsonb_build_object('inserted', 0, 'ids', '[]'::JSONB);
END IF;
-- ── Insert each offer ────────────────────────────────────────────
FOR v_offer IN
SELECT *
FROM jsonb_array_elements(p_offers) LOOP v_quantity := (v_offer->>'quantity')::NUMERIC;
v_is_price_lock := COALESCE((v_offer->>'is_price_lock')::BOOLEAN, FALSE);
v_listing_id := CASE
    WHEN v_offer->>'listing_id' IS NOT NULL
    AND v_offer->>'listing_id' <> '' THEN (v_offer->>'listing_id')::UUID
    ELSE NULL
END;
-- ── Price Lock branch ────────────────────────────────────────
IF v_is_price_lock THEN -- 1. listing_id is required for price lock
IF v_listing_id IS NULL THEN RAISE EXCEPTION 'Price lock requires a valid listing_id';
END IF;
-- 2. fpls_id is required
IF v_offer->>'fpls_id' IS NULL
OR v_offer->>'fpls_id' = '' THEN RAISE EXCEPTION 'Price lock requires a valid fpls_id';
END IF;
v_fpls_id := (v_offer->>'fpls_id')::UUID;
-- 3. Fetch farmer_to_duruha_price from listing
SELECT farmer_to_duruha_price INTO v_farmer_to_duruha_price
FROM public.produce_variety_listing
WHERE listing_id = v_listing_id;
IF v_farmer_to_duruha_price IS NULL THEN RAISE EXCEPTION 'Listing not found or has no farmer_to_duruha_price for listing_id: %',
v_listing_id;
END IF;
-- 4. Compute and validate total_price_lock_credit
v_computed_credit := v_farmer_to_duruha_price * v_quantity;
v_payload_credit := (v_offer->>'total_price_lock_credit')::NUMERIC;
IF v_payload_credit IS NOT NULL
AND round(v_payload_credit, 4) <> round(v_computed_credit, 4) THEN RAISE EXCEPTION 'total_price_lock_credit mismatch: payload=% but expected % (farmer_to_duruha_price=% * quantity=%)',
v_payload_credit,
v_computed_credit,
v_farmer_to_duruha_price,
v_quantity;
END IF;
-- 5. Verify fpls belongs to this farmer and is active, fetch remaining_credits
SELECT remaining_credits INTO v_fpls_remaining
FROM public.farmer_price_lock_subscriptions
WHERE fpls_id = v_fpls_id
    AND farmer_id = v_farmer_id
    AND status = 'ACTIVE';
IF v_fpls_remaining IS NULL THEN RAISE EXCEPTION 'No active price lock subscription found for fpls_id: %',
v_fpls_id;
END IF;
-- 6. Check sufficient credits
IF v_fpls_remaining < v_computed_credit THEN RAISE EXCEPTION 'Insufficient price lock credits: remaining=% but required=%',
v_fpls_remaining,
v_computed_credit;
END IF;
-- 7. Deduct credits from subscription
UPDATE public.farmer_price_lock_subscriptions
SET remaining_credits = remaining_credits - v_computed_credit,
    updated_at = now()
WHERE fpls_id = v_fpls_id;
-- 8. Insert offer WITH price lock fields
INSERT INTO public.farmer_offers (
        farmer_id,
        variety_id,
        listing_id,
        quantity,
        remaining_quantity,
        available_from,
        available_to,
        is_active,
        is_price_locked,
        total_price_lock_credit,
        remaining_price_lock_credit,
        fpls_id
    )
VALUES (
        v_farmer_id,
        (v_offer->>'variety_id')::UUID,
        v_listing_id,
        v_quantity,
        v_quantity,
        (v_offer->>'available_from')::DATE,
        (v_offer->>'available_to')::DATE,
        TRUE,
        TRUE,
        v_computed_credit,
        v_computed_credit,
        -- remaining starts equal to total
        v_fpls_id
    )
RETURNING offer_id INTO v_new_id;
ELSE -- ── Standard (no price lock) insert ─────────────────────
INSERT INTO public.farmer_offers (
        farmer_id,
        variety_id,
        listing_id,
        quantity,
        remaining_quantity,
        available_from,
        available_to,
        is_active,
        is_price_locked
    )
VALUES (
        v_farmer_id,
        (v_offer->>'variety_id')::UUID,
        v_listing_id,
        v_quantity,
        v_quantity,
        (v_offer->>'available_from')::DATE,
        (v_offer->>'available_to')::DATE,
        TRUE,
        FALSE
    )
RETURNING offer_id INTO v_new_id;
END IF;
v_inserted_ids := array_append(v_inserted_ids, v_new_id);
END LOOP;
RETURN jsonb_build_object(
    'inserted',
    array_length(v_inserted_ids, 1),
    'ids',
    to_jsonb(v_inserted_ids)
);
EXCEPTION
WHEN OTHERS THEN RAISE EXCEPTION 'create_farmer_offers failed: %',
SQLERRM;
END;
$$;