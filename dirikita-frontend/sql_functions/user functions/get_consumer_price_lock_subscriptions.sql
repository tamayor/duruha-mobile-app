CREATE OR REPLACE FUNCTION get_consumer_price_lock_usage_by_id(p_cpls_id UUID) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_consumer_id TEXT;
v_user_id UUID;
v_result JSON;
BEGIN -- ── Auth guard ───────────────────────────────────────────────────────────
IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized';
END IF;
-- Resolve the consumer_id that owns this subscription
SELECT s.consumer_id INTO v_consumer_id
FROM consumer_price_lock_subscriptions s
WHERE s.cpls_id = p_cpls_id;
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'Subscription not found';
END IF;
-- Make sure the calling user owns this consumer profile
SELECT uc.user_id INTO v_user_id
FROM user_consumers uc
WHERE uc.consumer_id = v_consumer_id;
IF v_user_id IS NULL
OR v_user_id <> auth.uid() THEN RAISE EXCEPTION 'Forbidden: subscription does not belong to the current user';
END IF;
-- ── Build the result ─────────────────────────────────────────────────────
SELECT json_build_object(
        -- Subscription meta
        'cpls_id',
        s.cpls_id,
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
        -- used_credits: monthly_credit_limit (config via cpl_id) - remaining_credits
        'used_credits',
        (c.monthly_credit_limit - s.remaining_credits),
        -- ── Usage: selection_type = 'MATCHED' variety lines per group ─────────────────
        'usage',
        COALESCE(
            (
                SELECT json_agg(
                        json_build_object(
                            'covg_id',
                            covg.covg_id,
                            'date_needed',
                            covg.date_needed,
                            'form',
                            covg.form,
                            'quantity',
                            covg.quantity,
                            'is_any',
                            covg.is_any,
                            -- group-level credits used from selected allocations only
                            'group_credits_used',
                            COALESCE(
                                (
                                    SELECT SUM(foa.quantity * cov.price_lock)
                                    FROM consumer_orders_variety cov
                                        LEFT JOIN farmer_offers_allocations foa ON foa.cov_id = cov.cov_id
                                        LEFT JOIN produce_varieties pv ON pv.variety_id = cov.variety_id
                                        LEFT JOIN produce p ON p.id = pv.produce_id
                                        LEFT JOIN consumer_orders_variety_group covg2 ON covg2.covg_id = cov.covg_id
                                        LEFT JOIN consumer_orders_produce cop ON cop.cop_id = covg2.cop_id
                                        LEFT JOIN consumer_orders co ON co.order_id = cop.order_id
                                    WHERE cov.covg_id = covg.covg_id
                                        AND cov.selection_type = 'MATCHED'
                                        AND foa.quantity IS NOT NULL
                                        AND cov.price_lock IS NOT NULL
                                ),
                                0
                            ),
                            -- only selection_type = 'MATCHED' lines
                            'selected_varieties',
                            COALESCE(
                                (
                                    SELECT json_agg(
                                            json_build_object(
                                                'cov_id',
                                                cov.cov_id,
                                                'order_id',
                                                co.order_id,
                                                'variety_id',
                                                cov.variety_id,
                                                'variety_name',
                                                pv.variety_name,
                                                'produce_id',
                                                pv.produce_id,
                                                'produce_name',
                                                p.english_name,
                                                'base_unit',
                                                p.base_unit,
                                                'listing_id',
                                                cov.listing_id,
                                                'price_lock',
                                                cov.price_lock,
                                                'variable_consumer_price',
                                                cov.variable_consumer_price,
                                                'final_price',
                                                cov.final_price,
                                                'has_paid',
                                                cov.has_paid,
                                                'payment_method',
                                                cov.payment_method,
                                                'foa_id',
                                                foa.foa_id,
                                                'allocated_quantity',
                                                foa.quantity,
                                                'credits_used',
                                                COALESCE(foa.quantity * cov.price_lock, 0)
                                            )
                                            ORDER BY cov.item_index
                                        )
                                    FROM consumer_orders_variety cov
                                        LEFT JOIN farmer_offers_allocations foa ON foa.cov_id = cov.cov_id
                                        LEFT JOIN produce_varieties pv ON pv.variety_id = cov.variety_id
                                        LEFT JOIN produce p ON p.id = pv.produce_id
                                        LEFT JOIN consumer_orders_variety_group covg2 ON covg2.covg_id = cov.covg_id
                                        LEFT JOIN consumer_orders_produce cop ON cop.cop_id = covg2.cop_id
                                        LEFT JOIN consumer_orders co ON co.order_id = cop.order_id
                                    WHERE cov.covg_id = covg.covg_id
                                        AND cov.selection_type = 'MATCHED'
                                ),
                                '[]'::json
                            )
                        )
                        ORDER BY covg.date_needed DESC
                    )
                FROM consumer_orders_variety_group covg
                WHERE covg.cpls_id = s.cpls_id
            ),
            '[]'::json
        )
    ) INTO v_result
FROM consumer_price_lock_subscriptions s
    JOIN consumer_price_lock_configs c ON c.cpl_id = s.cpl_id
WHERE s.cpls_id = p_cpls_id;
RETURN v_result;
END;
$$;
-- ── Grant execute to authenticated users only ────────────────────────────────
REVOKE EXECUTE ON FUNCTION get_consumer_price_lock_usage_by_id(UUID)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_consumer_price_lock_usage_by_id(UUID) TO authenticated;