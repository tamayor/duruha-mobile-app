CREATE OR REPLACE FUNCTION public.get_consumer_orders(
        p_limit INT DEFAULT 10,
        p_cursor TIMESTAMPTZ DEFAULT NULL,
        p_is_active BOOL DEFAULT TRUE,
        p_is_order BOOL DEFAULT TRUE,
        -- TRUE = include regular orders, FALSE = exclude
        p_is_plan BOOL DEFAULT TRUE,
        -- TRUE = include plans, FALSE = exclude
        p_has_payment_method BOOL DEFAULT NULL -- NULL = no filter, TRUE = has payment method, FALSE = payment method is null
    ) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_result JSON;
v_consumer_id TEXT;
v_consumer_dialect TEXT;
v_total_count INT;
v_next_cursor TIMESTAMPTZ;
BEGIN -- 1. Resolve consumer_id + dialect
SELECT uc.consumer_id,
    u.dialect [1] INTO v_consumer_id,
    v_consumer_dialect
FROM users u
    JOIN user_consumers uc ON uc.user_id = u.id
WHERE u.id = auth.uid();
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'Not authenticated or consumer profile not found';
END IF;
-- 2. Total count
SELECT COUNT(*) INTO v_total_count
FROM consumer_orders co
WHERE co.consumer_id = v_consumer_id
    AND co.is_active = p_is_active
    AND (
        p_has_payment_method IS NULL
        OR (
            p_has_payment_method = TRUE
            AND co.payment_method IS NOT NULL
        )
        OR (
            p_has_payment_method = FALSE
            AND co.payment_method IS NULL
        )
    )
    AND (
        (
            p_is_plan = TRUE
            AND EXISTS (
                SELECT 1
                FROM consumer_orders_produce cop_pl
                    JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                    JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                WHERE cop_pl.order_id = co.order_id
                    AND covg_pl.cps_id IS NOT NULL
                    AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
            )
        )
        OR (
            p_is_order = TRUE
            AND NOT EXISTS (
                SELECT 1
                FROM consumer_orders_produce cop_pl
                    JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                    JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                WHERE cop_pl.order_id = co.order_id
                    AND covg_pl.cps_id IS NOT NULL
                    AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
            )
        )
    );
-- 3. Resolve next cursor
SELECT co.created_at INTO v_next_cursor
FROM consumer_orders co
WHERE co.consumer_id = v_consumer_id
    AND co.is_active = p_is_active
    AND (
        p_cursor IS NULL
        OR co.created_at < p_cursor
    )
    AND (
        p_has_payment_method IS NULL
        OR (
            p_has_payment_method = TRUE
            AND co.payment_method IS NOT NULL
        )
        OR (
            p_has_payment_method = FALSE
            AND co.payment_method IS NULL
        )
    )
    AND (
        (
            p_is_plan = TRUE
            AND EXISTS (
                SELECT 1
                FROM consumer_orders_produce cop_pl
                    JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                    JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                WHERE cop_pl.order_id = co.order_id
                    AND covg_pl.cps_id IS NOT NULL
                    AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
            )
        )
        OR (
            p_is_order = TRUE
            AND NOT EXISTS (
                SELECT 1
                FROM consumer_orders_produce cop_pl
                    JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                    JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                WHERE cop_pl.order_id = co.order_id
                    AND covg_pl.cps_id IS NOT NULL
                    AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
            )
        )
    )
ORDER BY co.created_at DESC OFFSET p_limit
LIMIT 1;
-- 4. Build paginated orders
SELECT json_build_object(
        'pagination',
        json_build_object(
            'limit',
            p_limit,
            'next_cursor',
            v_next_cursor,
            'total',
            v_total_count,
            'has_more',
            (v_next_cursor IS NOT NULL)
        ),
        'orders',
        COALESCE(
            (
                SELECT json_agg(rows)
                FROM (
                        SELECT json_build_object(
                                'order_id',
                                co.order_id,
                                'note',
                                co.note,
                                'is_active',
                                co.is_active,
                                'created_at',
                                co.created_at,
                                'payment_method',
                                co.payment_method,
                                'is_plan',
                                EXISTS (
                                    SELECT 1
                                    FROM consumer_orders_produce cop_pl
                                        JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                                        JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                                    WHERE cop_pl.order_id = co.order_id
                                        AND covg_pl.cps_id IS NOT NULL
                                        AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
                                ),
                                'stats',
                                (
                                    SELECT json_build_object(
                                            'status',
                                            COALESCE(
                                                (
                                                    SELECT jsonb_object_agg(status, count)
                                                    FROM (
                                                            SELECT oom.delivery_status::TEXT AS status,
                                                                COUNT(DISTINCT covg_s.covg_id) AS count
                                                            FROM consumer_orders_produce cop_s
                                                                JOIN consumer_orders_variety_group covg_s ON covg_s.cop_id = cop_s.cop_id
                                                                JOIN consumer_orders_variety cov_s ON cov_s.covg_id = covg_s.covg_id
                                                                JOIN offer_order_match oom ON oom.cov_id = cov_s.cov_id
                                                            WHERE cop_s.order_id = co.order_id
                                                            GROUP BY oom.delivery_status
                                                        ) s
                                                ),
                                                '{}'::jsonb
                                            ),
                                            'paid',
                                            (
                                                SELECT COUNT(DISTINCT covg_p.covg_id)
                                                FROM consumer_orders_produce cop_p
                                                    JOIN consumer_orders_variety_group covg_p ON covg_p.cop_id = cop_p.cop_id
                                                    JOIN consumer_orders_variety cov_p ON cov_p.covg_id = covg_p.covg_id
                                                    JOIN offer_order_match oom_p ON oom_p.cov_id = cov_p.cov_id
                                                WHERE cop_p.order_id = co.order_id
                                                    AND oom_p.consumer_has_paid = TRUE
                                            ),
                                            'unpaid',
                                            (
                                                SELECT COUNT(DISTINCT covg_u.covg_id)
                                                FROM consumer_orders_produce cop_u
                                                    JOIN consumer_orders_variety_group covg_u ON covg_u.cop_id = cop_u.cop_id
                                                    JOIN consumer_orders_variety cov_u ON cov_u.covg_id = covg_u.covg_id
                                                    JOIN offer_order_match oom_u ON oom_u.cov_id = cov_u.cov_id
                                                WHERE cop_u.order_id = co.order_id
                                                    AND oom_u.consumer_has_paid = FALSE
                                            )
                                        )
                                ),
                                'produce',
                                (
                                    SELECT json_agg(
                                            COALESCE(
                                                (
                                                    SELECT pd.local_name
                                                    FROM produce_dialects pd
                                                        JOIN dialects d ON d.id = pd.dialect_id
                                                    WHERE pd.produce_id = p.id
                                                        AND d.dialect_name = v_consumer_dialect
                                                    LIMIT 1
                                                ), p.english_name
                                            )
                                        )
                                    FROM consumer_orders_produce cop
                                        JOIN produce p ON p.id = cop.produce_id
                                    WHERE cop.order_id = co.order_id
                                )
                            ) AS rows
                        FROM consumer_orders co
                        WHERE co.consumer_id = v_consumer_id
                            AND co.is_active = p_is_active
                            AND (
                                p_cursor IS NULL
                                OR co.created_at < p_cursor
                            )
                            AND (
                                p_has_payment_method IS NULL
                                OR (
                                    p_has_payment_method = TRUE
                                    AND co.payment_method IS NOT NULL
                                )
                                OR (
                                    p_has_payment_method = FALSE
                                    AND co.payment_method IS NULL
                                )
                            )
                            AND (
                                (
                                    p_is_plan = TRUE
                                    AND EXISTS (
                                        SELECT 1
                                        FROM consumer_orders_produce cop_pl
                                            JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                                            JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                                        WHERE cop_pl.order_id = co.order_id
                                            AND covg_pl.cps_id IS NOT NULL
                                            AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
                                    )
                                )
                                OR (
                                    p_is_order = TRUE
                                    AND NOT EXISTS (
                                        SELECT 1
                                        FROM consumer_orders_produce cop_pl
                                            JOIN consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                                            JOIN consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
                                        WHERE cop_pl.order_id = co.order_id
                                            AND covg_pl.cps_id IS NOT NULL
                                            AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
                                    )
                                )
                            )
                        ORDER BY co.created_at DESC
                        LIMIT p_limit
                    ) sub
            ), '[]'::json
        )
    ) INTO v_result;
RETURN v_result;
END;
$$;
