CREATE OR REPLACE FUNCTION get_farmer_pledges(
        p_limit INT DEFAULT 20,
        p_offset INT DEFAULT 0
    ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_farmer_id TEXT;
v_dialect_id UUID;
result JSONB;
total_count INT;
BEGIN -- Resolve farmer_id from the authenticated user
SELECT uf.farmer_id INTO v_farmer_id
FROM user_farmers uf
WHERE uf.user_id = auth.uid()
LIMIT 1;
IF v_farmer_id IS NULL THEN RETURN jsonb_build_object(
    'error',
    'No farmer profile found for current user'
);
END IF;
-- Resolve dialect from user profile
SELECT d.id INTO v_dialect_id
FROM users u
    JOIN dialects d ON d.name = ANY(u.dialect)
WHERE u.id = auth.uid()
LIMIT 1;
-- Total covg count for pagination meta
SELECT COUNT(DISTINCT covg.covg_id) INTO total_count
FROM consumer_orders_variety_group covg
WHERE EXISTS (
        SELECT 1
        FROM consumer_orders_variety cov
            JOIN farmer_offers_allocations foa ON foa.cov_id = cov.cov_id
        WHERE cov.covg_id = covg.covg_id
            AND foa.farmer_id = v_farmer_id
            AND cov.selection_type = 'PLEDGED'
    );
-- Main query
SELECT jsonb_build_object(
        'pagination',
        jsonb_build_object(
            'total',
            total_count,
            'limit',
            p_limit,
            'offset',
            p_offset,
            'has_more',
            (p_offset + p_limit) < total_count
        ),
        'pledges',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'produce_english_name',
                    produce_data.english_name,
                    'produce_local_name',
                    produce_data.local_name,
                    'variety_groups',
                    produce_data.groups
                )
                ORDER BY produce_data.earliest_date_needed ASC NULLS LAST
            ),
            '[]'::jsonb
        )
    ) INTO result
FROM (
        SELECT cop.produce_id,
            p.english_name,
            COALESCE(pd.local_name, p.english_name) AS local_name,
            MIN(covg.date_needed) AS earliest_date_needed,
            jsonb_agg(
                jsonb_build_object(
                    'covg_id',
                    covg.covg_id,
                    'date_needed',
                    covg.date_needed,
                    'quantity',
                    covg.quantity,
                    'varieties',
                    covg_varieties.varieties
                )
                ORDER BY covg.date_needed ASC NULLS LAST
            ) AS groups
        FROM (
                -- Paginate at covg level, earliest date_needed first
                SELECT covg_inner.*
                FROM consumer_orders_variety_group covg_inner
                WHERE EXISTS (
                        SELECT 1
                        FROM consumer_orders_variety cov
                            JOIN farmer_offers_allocations foa ON foa.cov_id = cov.cov_id
                        WHERE cov.covg_id = covg_inner.covg_id
                            AND foa.farmer_id = v_farmer_id
                            AND cov.selection_type = 'PLEDGED'
                    )
                ORDER BY covg_inner.date_needed ASC NULLS LAST
                LIMIT p_limit OFFSET p_offset
            ) covg
            JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
            JOIN produce p ON p.id = cop.produce_id -- Local name: prefer user's dialect, fallback to any available
            LEFT JOIN LATERAL (
                SELECT pd2.local_name
                FROM produce_dialects pd2
                WHERE pd2.produce_id = cop.produce_id
                    AND (
                        v_dialect_id IS NULL
                        OR pd2.dialect_id = v_dialect_id
                    )
                LIMIT 1
            ) pd ON true -- Per-covg: only this farmer's PLEDGED varieties
            JOIN LATERAL (
                SELECT jsonb_agg(
                        jsonb_build_object(
                            'cov_id',
                            cov.cov_id,
                            'selection_type',
                            cov.selection_type,
                            'quantity',
                            foa.quantity,
                            'price_lock',
                            foa.price_lock,
                            'ftd_price',
                            foa.ftd_price,
                            'final_price',
                            foa.final_price,
                            'payment_method',
                            foa.payment_method,
                            'is_paid',
                            foa.is_paid,
                            'foa_id',
                            foa.foa_id,
                            'farmer_id',
                            foa.farmer_id,
                            'carrier_name',
                            uc.name,
                            'carrier_id',
                            oom.carrier_id,
                            'delivery_status',
                            oom.delivery_status,
                            'oom_id',
                            oom.oom_id,
                            'dispatch_at',
                            oom.dispatch_at
                        )
                    ) AS varieties
                FROM consumer_orders_variety cov
                    JOIN farmer_offers_allocations foa ON foa.cov_id = cov.cov_id
                    LEFT JOIN offer_order_match oom ON oom.foa_id = foa.foa_id
                    LEFT JOIN user_carriers uc ON uc.carrier_id = oom.carrier_id
                WHERE cov.covg_id = covg.covg_id
                    AND foa.farmer_id = v_farmer_id
                    AND cov.selection_type = 'PLEDGED'
            ) covg_varieties ON true
        GROUP BY cop.produce_id,
            p.english_name,
            pd.local_name
    ) produce_data;
RETURN result;
END;
$$;