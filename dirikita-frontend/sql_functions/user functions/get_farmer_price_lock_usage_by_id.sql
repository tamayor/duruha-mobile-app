-- ─────────────────────────────────────────────────────────────────────────────
-- 2. get_farmer_price_lock_usage_by_id(p_fpls_id)
--    Returns full subscription detail + usage breakdown for a given fpls_id
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_farmer_price_lock_usage_by_id(p_fpls_id UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_farmer_id TEXT;
v_user_id UUID;
v_result JSON;
BEGIN -- ── Auth guard ───────────────────────────────────────────────────────────
IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized';
END IF;
-- Resolve the farmer_id that owns this subscription
SELECT s.farmer_id INTO v_farmer_id
FROM farmer_price_lock_subscriptions s
WHERE s.fpls_id = p_fpls_id;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'Subscription not found';
END IF;
-- Make sure the calling user owns this farmer profile
SELECT uf.user_id INTO v_user_id
FROM user_farmers uf
WHERE uf.farmer_id = v_farmer_id;
IF v_user_id IS NULL
OR v_user_id <> auth.uid() THEN RAISE EXCEPTION 'Forbidden: subscription does not belong to the current user';
END IF;
-- ── Build the result ─────────────────────────────────────────────────────
SELECT json_build_object(
        -- Subscription meta
        'fpls_id',
        s.fpls_id,
        'status',
        s.status,
        'starts_at',
        s.starts_at,
        'ends_at',
        s.ends_at,
        'last_reset_date',
        s.last_reset_date,
        -- Plan details from config
        'plan_name',
        c.plan_name,
        'monthly_credit_limit',
        c.monthly_credit_limit,
        'billing_interval',
        c.billing_interval,
        'fee',
        c.fee,
        -- Credit snapshot
        'remaining_credits',
        s.remaining_credits,
        -- used_credits: monthly_credit_limit (config via fpl_id) - remaining_credits
        'used_credits',
        (c.monthly_credit_limit - s.remaining_credits),
        -- ── Usage: farmer_offers tied to this subscription ───────────────────
        'usage',
        COALESCE(
            (
                SELECT json_agg(
                        json_build_object(
                            'offer_id',
                            fo.offer_id,
                            'variety_id',
                            fo.variety_id,
                            'variety_name',
                            pv.variety_name,
                            'produce_id',
                            pv.produce_id,
                            'produce_name',
                            p.english_name,
                            'base_unit',
                            p.base_unit,
                            'listing_id',
                            fo.listing_id,
                            'quantity',
                            fo.quantity,
                            'remaining_quantity',
                            fo.remaining_quantity,
                            'is_active',
                            fo.is_active,
                            'is_price_locked',
                            fo.is_price_locked,
                            'available_from',
                            fo.available_from,
                            'available_to',
                            fo.available_to,
                            'total_price_lock_credit',
                            fo.total_price_lock_credit,
                            'remaining_price_lock_credit',
                            fo.remaining_price_lock_credit,
                            -- credits consumed for this offer
                            'credits_used',
                            COALESCE(
                                fo.total_price_lock_credit - fo.remaining_price_lock_credit,
                                0
                            ),
                            -- count of allocations fulfilled under this offer
                            'allocations_count',
                            (
                                SELECT COUNT(*)
                                FROM farmer_offers_allocations foa
                                WHERE foa.offer_id = fo.offer_id
                                    AND foa.fpls_id = s.fpls_id
                            )
                        )
                        ORDER BY fo.created_at DESC
                    )
                FROM farmer_offers fo
                    LEFT JOIN produce_varieties pv ON pv.variety_id = fo.variety_id
                    LEFT JOIN produce p ON p.id = pv.produce_id
                WHERE fo.fpls_id = s.fpls_id
            ),
            '[]'::json
        )
    ) INTO v_result
FROM farmer_price_lock_subscriptions s
    JOIN farmer_price_lock_configs c ON c.fpl_id = s.fpl_id
WHERE s.fpls_id = p_fpls_id;
RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_farmer_price_lock_usage_by_id(UUID)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_farmer_price_lock_usage_by_id(UUID) TO authenticated;