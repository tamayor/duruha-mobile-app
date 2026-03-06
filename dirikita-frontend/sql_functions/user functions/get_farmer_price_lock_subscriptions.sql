-- ─────────────────────────────────────────────────────────────────────────────
-- 1. get_farmer_price_lock_subscriptions
--    Returns all price-lock subscriptions for the calling farmer
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_farmer_price_lock_subscriptions() RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_farmer_id TEXT;
v_result JSON;
BEGIN -- ── Auth guard ───────────────────────────────────────────────────────────
IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized';
END IF;
-- Resolve farmer_id from the calling user
SELECT uf.farmer_id INTO v_farmer_id
FROM user_farmers uf
WHERE uf.user_id = auth.uid();
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'Farmer profile not found';
END IF;
-- ── Build the result ─────────────────────────────────────────────────────
SELECT COALESCE(
        json_agg(
            json_build_object(
                'fpls_id',
                s.fpls_id,
                'plan_name',
                c.plan_name,
                'status',
                s.status,
                'monthly_credit_limit',
                c.monthly_credit_limit,
                'remaining_credits',
                s.remaining_credits,
                'used_credits',
                (c.monthly_credit_limit - s.remaining_credits),
                'starts_at',
                s.starts_at,
                'ends_at',
                s.ends_at
            )
            ORDER BY s.starts_at DESC
        ),
        '[]'::json
    ) INTO v_result
FROM farmer_price_lock_subscriptions s
    JOIN farmer_price_lock_configs c ON c.fpl_id = s.fpl_id
WHERE s.farmer_id = v_farmer_id;
RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_farmer_price_lock_subscriptions()
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_farmer_price_lock_subscriptions() TO authenticated;