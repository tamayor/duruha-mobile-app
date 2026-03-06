-- ════════════════════════════════════════════════════════════════════════════
-- get_consumer_future_plan_usage_by_id(p_cfps_id UUID)
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_consumer_future_plan_usage_by_id(p_cfps_id UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_consumer_id TEXT;
v_result JSON;
BEGIN -- ── Auth guard ────────────────────────────────────────────────────────────
IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized';
END IF;
SELECT uc.consumer_id INTO v_consumer_id
FROM user_consumers uc
WHERE uc.user_id = auth.uid();
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'Consumer profile not found';
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM consumer_future_plan_subscriptions s
    WHERE s.cfps_id = p_cfps_id
        AND s.consumer_id = v_consumer_id
) THEN RAISE EXCEPTION 'Forbidden: subscription does not belong to the current user';
END IF;
-- ── Build result ──────────────────────────────────────────────────────────
SELECT json_build_object(
        -- Subscription meta
        'cfps_id',
        s.cfps_id,
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
        -- Plan config
        'plan_name',
        c.plan_name,
        'billing_interval',
        c.billing_interval,
        'fee',
        c.fee,
        'min_total_value',
        c.min_total_value,
        'max_total_value',
        c.max_total_value,
        -- Total distinct orders linked to this subscription
        'total_orders',
        (
            SELECT COUNT(DISTINCT cop.order_id)
            FROM consumer_orders_produce cop
                JOIN consumer_orders_variety_group covg ON covg.cop_id = cop.cop_id
            WHERE covg.cfps_id = p_cfps_id
        ),
        -- Orders with produce counts
        'orders',
        COALESCE(
            (
                SELECT json_agg(
                        json_build_object(
                            'order_id',
                            co.order_id,
                            'payment_method',
                            co.payment_method,
                            'is_active',
                            co.is_active,
                            'created_at',
                            co.created_at,
                            -- how many distinct produces are in this order under this subscription
                            'total_produces',
                            (
                                SELECT COUNT(DISTINCT cop.cop_id)
                                FROM consumer_orders_produce cop
                                    JOIN consumer_orders_variety_group covg ON covg.cop_id = cop.cop_id
                                WHERE cop.order_id = co.order_id
                                    AND covg.cfps_id = p_cfps_id
                            ),
                            'produces',
                            COALESCE(
                                (
                                    SELECT json_agg(
                                            json_build_object(
                                                'cop_id',
                                                cop.cop_id,
                                                'produce_id',
                                                cop.produce_id,
                                                'produce_name',
                                                p.english_name,
                                                'quality',
                                                cop.quality,
                                                -- how many date_needed entries for this produce in this subscription
                                                'recurrence',
                                                (
                                                    SELECT COUNT(*)
                                                    FROM consumer_orders_variety_group covg_r
                                                    WHERE covg_r.cop_id = cop.cop_id
                                                        AND covg_r.cfps_id = p_cfps_id
                                                )
                                            )
                                            ORDER BY p.english_name ASC
                                        )
                                    FROM consumer_orders_produce cop
                                        JOIN produce p ON p.id = cop.produce_id
                                    WHERE cop.order_id = co.order_id
                                        AND EXISTS (
                                            SELECT 1
                                            FROM consumer_orders_variety_group covg_e
                                            WHERE covg_e.cop_id = cop.cop_id
                                                AND covg_e.cfps_id = p_cfps_id
                                        )
                                ),
                                '[]'::json
                            )
                        )
                        ORDER BY co.created_at DESC
                    )
                FROM consumer_orders co
                WHERE EXISTS (
                        SELECT 1
                        FROM consumer_orders_produce cop2
                            JOIN consumer_orders_variety_group covg2 ON covg2.cop_id = cop2.cop_id
                        WHERE cop2.order_id = co.order_id
                            AND covg2.cfps_id = p_cfps_id
                    )
            ),
            '[]'::json
        )
    ) INTO v_result
FROM consumer_future_plan_subscriptions s
    JOIN consumer_future_plan_configs c ON c.cfp_id = s.cfp_id
WHERE s.cfps_id = p_cfps_id;
RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_consumer_future_plan_usage_by_id(UUID)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_consumer_future_plan_usage_by_id(UUID) TO authenticated;