-- Function: create_farmer_offers
-- Accepts an array of offer objects and bulk-inserts into farmer_offers.
-- SECURITY DEFINER ensures it runs with table owner privileges while
-- still enforcing auth.uid() === farmer_id via the users table lookup.
CREATE OR REPLACE FUNCTION public.create_farmer_offers(
        p_offers JSONB -- array of offer objects
    ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_caller_uid UUID;
v_farmer_id TEXT;
v_offer JSONB;
v_inserted_ids UUID [] := '{}';
v_new_id UUID;
v_is_price_locked BOOLEAN;
v_fpls_id UUID;
v_credit NUMERIC;
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
FROM jsonb_array_elements(p_offers) LOOP

v_is_price_locked := (v_offer->>'is_price_lock')::BOOLEAN;
v_fpls_id := CASE WHEN v_offer->>'fpls_id' IS NOT NULL AND v_offer->>'fpls_id' <> '' THEN (v_offer->>'fpls_id')::UUID ELSE NULL END;
v_credit := (v_offer->>'total_price_lock_credit')::NUMERIC;

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
        fpls_id,
        total_price_lock_credit,
        remaining_price_lock_credit
    )
VALUES (
        v_farmer_id,
        (v_offer->>'variety_id')::UUID,
        CASE
            WHEN v_offer->>'listing_id' IS NOT NULL
            AND v_offer->>'listing_id' <> '' THEN (v_offer->>'listing_id')::UUID
            ELSE NULL
        END,
        (v_offer->>'quantity')::NUMERIC,
        (v_offer->>'quantity')::NUMERIC,
        -- remaining = quantity at creation
        (v_offer->>'available_from')::DATE,
        (v_offer->>'available_to')::DATE,
        TRUE,
        v_is_price_locked,
        v_fpls_id,
        v_credit,
        v_credit
    )
RETURNING offer_id INTO v_new_id;

-- Deduct credits if price locked
IF v_is_price_locked = TRUE AND v_fpls_id IS NOT NULL THEN
    UPDATE public.farmer_price_lock_subscriptions
    SET remaining_credits = remaining_credits - v_credit
    WHERE fpls_id = v_fpls_id AND farmer_id = v_farmer_id;
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