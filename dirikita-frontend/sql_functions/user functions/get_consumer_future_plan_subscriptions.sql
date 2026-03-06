-- ════════════════════════════════════════════════════════════════════════════
-- 1. get_consumer_future_plan_subscriptions()
--    Returns all future plan subscriptions for the currently authenticated user
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_consumer_future_plan_subscriptions() RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_consumer_id TEXT;
v_result JSON;
BEGIN -- ── Auth guard ────────────────────────────────────────────────────────────
IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized';
END IF;
-- Resolve consumer_id from the authenticated user
SELECT uc.consumer_id INTO v_consumer_id
FROM user_consumers uc
WHERE uc.user_id = auth.uid();
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'Consumer profile not found';
END IF;
-- ── Build result ──────────────────────────────────────────────────────────
SELECT COALESCE(
        json_agg(
            json_build_object(
                'cfps_id',
                s.cfps_id,
                'cfp_id',
                s.cfp_id,
                'is_active',
                s.is_active,
                'starts_at',
                s.starts_at,
                'expires_at',
                s.expires_at,
                'extension_count',
                s.extension_count,
                'last_extension_at',
                s.last_extension_at,
                'renew_count',
                s.renew_count,
                'last_renewed_at',
                s.last_renewed_at,
                'created_at',
                s.created_at,
                -- Plan config details
                'plan_name',
                c.plan_name,
                'billing_interval',
                c.billing_interval,
                'fee',
                c.fee,
                'min_total_value',
                c.min_total_value,
                'max_total_value',
                c.max_total_value
            )
            ORDER BY s.starts_at DESC
        ),
        '[]'::json
    ) INTO v_result
FROM consumer_future_plan_subscriptions s
    JOIN consumer_future_plan_configs c ON c.cfp_id = s.cfp_id
WHERE s.consumer_id = v_consumer_id;
RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_consumer_future_plan_subscriptions()
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_consumer_future_plan_subscriptions() TO authenticated;