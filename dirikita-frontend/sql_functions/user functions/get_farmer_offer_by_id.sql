-- Function: get_farmer_offer_by_id
-- Returns a single farmer_offer by ID in the same format as get_farmer_offers.
CREATE OR REPLACE FUNCTION public.get_farmer_offer_by_id(p_offer_id UUID) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_caller_uid UUID;
v_farmer_id TEXT;
v_result JSONB;
BEGIN -- ── Auth ─────────────────────────────────────────────────────────
v_caller_uid := auth.uid();
IF v_caller_uid IS NULL THEN RAISE EXCEPTION 'Unauthorized: authentication required';
END IF;
SELECT farmer_id INTO v_farmer_id
FROM public.user_farmers
WHERE user_id = v_caller_uid
LIMIT 1;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: no farmer profile for this user';
END IF;
SELECT jsonb_build_object(
        'offer_id',
        fo.offer_id,
        'variety_name',
        pv.variety_name,
        'quantity',
        fo.quantity,
        'remaining_quantity',
        fo.remaining_quantity,
        'is_active',
        fo.is_active,
        'is_price_locked',
        COALESCE(fo.is_price_locked, FALSE),
        'total_price_lock_credit',
        fo.total_price_lock_credit,
        'remaining_price_lock_credit',
        fo.remaining_price_lock_credit,
        'available_from',
        fo.available_from,
        'available_to',
        fo.available_to,
        'created_at',
        fo.created_at,
        'fpls_status',
        fpls.status,
        'orders',
        '[]'::JSONB,
        'orders_total_price',
        0,
        'farmer_total_earnings',
        0
    ) INTO v_result
FROM public.farmer_offers fo
    JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
    JOIN public.produce p ON p.id = pv.produce_id
    LEFT JOIN public.farmer_price_lock_subscriptions fpls ON fo.price_lock_subscription_id = fpls.id
WHERE fo.farmer_id = v_farmer_id
    AND fo.offer_id = p_offer_id;
RETURN v_result;
END;
$$;