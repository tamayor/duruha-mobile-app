CREATE OR REPLACE FUNCTION public.get_consumer_order_by_id(p_order_id UUID) RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER AS $$ WITH auth_consumer AS (
        SELECT uc.consumer_id
        FROM public.user_consumers uc
        WHERE uc.user_id = auth.uid()
        LIMIT 1
    ), target_order AS (
        SELECT co.order_id,
            co.consumer_id,
            co.created_at,
            co.is_active,
            co.payment_method,
            co.note
        FROM public.consumer_orders co
        WHERE co.order_id = p_order_id
            AND co.consumer_id = (
                SELECT consumer_id
                FROM auth_consumer
            )
    )
SELECT jsonb_build_object(
        'order_id',
        o.order_id,
        'created_at',
        o.created_at,
        'is_active',
        o.is_active,
        'payment_method',
        o.payment_method,
        'note',
        o.note,
        'cps_id',
        (
            SELECT covg_top.cps_id
            FROM public.consumer_orders_produce cop_top
                JOIN public.consumer_orders_variety_group covg_top ON covg_top.cop_id = cop_top.cop_id
            WHERE cop_top.order_id = o.order_id
                AND covg_top.cps_id IS NOT NULL
            LIMIT 1
        ), 'is_plan', EXISTS (
            SELECT 1
            FROM public.consumer_orders_produce cop_pl
                JOIN public.consumer_orders_variety_group covg_pl ON covg_pl.cop_id = cop_pl.cop_id
                JOIN public.consumer_orders_variety cov_pl ON cov_pl.covg_id = covg_pl.covg_id
            WHERE cop_pl.order_id = o.order_id
                AND covg_pl.cps_id IS NOT NULL
                AND cov_pl.selection_type IN ('OPEN', 'DENIED', 'PLEDGED')
        ),
        'produce_items',
        COALESCE(
            (
                SELECT jsonb_agg(
                        jsonb_build_object(
                            'cop_id',
                            cop.cop_id,
                            'note',
                            cop.note,
                            'produce_id',
                            cop.produce_id,
                            'produce_english_name',
                            p.english_name,
                            'produce_img_url',
                            p.image_url,
                            'quality',
                            cop.quality,
                            'item_index',
                            cop.item_index,
                            -- variety_group = one row per covg
                            'variety_group',
                            COALESCE(
                                (
                                    SELECT jsonb_agg(
                                            jsonb_build_object(
                                                'covg_id',
                                                covg.covg_id,
                                                'index',
                                                covg.item_index,
                                                'form',
                                                covg.form,
                                                -- requested quantity (what the consumer asked for)
                                                'quantity',
                                                covg.quantity,
                                                'date_needed',
                                                covg.date_needed,
                                                'is_any',
                                                covg.is_any,
                                                'cps_id',
                                                covg.cps_id,
                                                'is_price_lock',
                                                COALESCE(
                                                    (
                                                        SELECT cov_pl.is_price_lock
                                                        FROM public.consumer_orders_variety cov_pl
                                                        WHERE cov_pl.covg_id = covg.covg_id
                                                            AND cov_pl.is_price_lock = TRUE
                                                        LIMIT 1
                                                    ), FALSE
                                                ), -- allocated_quantity: sum of actually matched/pledged quantities
                                                'allocated_quantity', COALESCE(
                                                    (
                                                        SELECT SUM(COALESCE(foa_q.quantity, 0))
                                                        FROM public.consumer_orders_variety cov_a
                                                            JOIN public.offer_order_match oom_a ON oom_a.cov_id = cov_a.cov_id
                                                            JOIN public.farmer_offers_allocations foa_q ON foa_q.foa_id = oom_a.foa_id
                                                        WHERE cov_a.covg_id = covg.covg_id
                                                            AND cov_a.selection_type IN ('MATCHED', 'PLEDGED')
                                                    ),
                                                    0
                                                ),
                                                -- group-level subtotal computed in SQL
                                                'subtotal',
                                                COALESCE(
                                                    (
                                                        SELECT SUM(
                                                                CASE
                                                                    -- cancelled: 0
                                                                    WHEN oom_st.delivery_status = 'CANCELLED' THEN 0 -- final price set: use it
                                                                    WHEN cov_st.final_price IS NOT NULL
                                                                    AND cov_st.final_price > 0 THEN foa_q2.quantity * cov_st.final_price -- price lock: use locked price
                                                                    WHEN COALESCE(cov_st.is_price_lock, FALSE) = TRUE
                                                                    AND cov_st.price_lock IS NOT NULL THEN foa_q2.quantity * cov_st.price_lock -- tentative: use dtc_price
                                                                    WHEN cov_st.dtc_price IS NOT NULL THEN foa_q2.quantity * cov_st.dtc_price
                                                                    ELSE 0
                                                                END
                                                            )
                                                        FROM public.consumer_orders_variety cov_st
                                                            JOIN public.offer_order_match oom_st ON oom_st.cov_id = cov_st.cov_id
                                                            JOIN public.farmer_offers_allocations foa_q2 ON foa_q2.foa_id = oom_st.foa_id
                                                        WHERE cov_st.covg_id = covg.covg_id
                                                            AND cov_st.selection_type IN ('MATCHED', 'PLEDGED')
                                                    ),
                                                    0
                                                ),
                                                -- delivery_fee for this group (sum across matched allocations)
                                                'delivery_fee',
                                                COALESCE(
                                                    (
                                                        SELECT SUM(COALESCE(oom_df.delivery_fee, 0))
                                                        FROM public.consumer_orders_variety cov_df
                                                            JOIN public.offer_order_match oom_df ON oom_df.cov_id = cov_df.cov_id
                                                        WHERE cov_df.covg_id = covg.covg_id
                                                            AND cov_df.selection_type IN ('MATCHED', 'PLEDGED')
                                                            AND oom_df.delivery_status != 'CANCELLED'
                                                    ),
                                                    0
                                                ),
                                                -- is_price_final: true only when all matched/pledged cov have final_price set
                                                'is_price_final',
                                                NOT EXISTS (
                                                    SELECT 1
                                                    FROM public.consumer_orders_variety cov_pf
                                                    WHERE cov_pf.covg_id = covg.covg_id
                                                        AND cov_pf.selection_type IN ('MATCHED', 'PLEDGED')
                                                        AND (
                                                            cov_pf.final_price IS NULL
                                                            OR cov_pf.final_price = 0
                                                        )
                                                )
                                                AND EXISTS (
                                                    SELECT 1
                                                    FROM public.consumer_orders_variety cov_ex
                                                    WHERE cov_ex.covg_id = covg.covg_id
                                                        AND cov_ex.selection_type IN ('MATCHED', 'PLEDGED')
                                                ),
                                                -- price_label: human-readable pricing state
                                                'price_label',
                                                CASE
                                                    WHEN covg.cps_id IS NOT NULL
                                                    AND EXISTS (
                                                        SELECT 1
                                                        FROM public.consumer_orders_variety cov_lbl
                                                        WHERE cov_lbl.covg_id = covg.covg_id
                                                            AND cov_lbl.selection_type IN ('OPEN')
                                                    ) THEN 'plan'
                                                    WHEN EXISTS (
                                                        SELECT 1
                                                        FROM public.consumer_orders_variety cov_lbl
                                                        WHERE cov_lbl.covg_id = covg.covg_id
                                                            AND cov_lbl.selection_type IN ('MATCHED', 'PLEDGED')
                                                    ) AND NOT EXISTS (
                                                        SELECT 1
                                                        FROM public.consumer_orders_variety cov_lbl
                                                            JOIN public.offer_order_match oom_lbl ON oom_lbl.cov_id = cov_lbl.cov_id
                                                        WHERE cov_lbl.covg_id = covg.covg_id
                                                            AND cov_lbl.selection_type IN ('MATCHED', 'PLEDGED')
                                                            AND oom_lbl.delivery_status != 'CANCELLED'
                                                    ) THEN NULL
                                                    WHEN NOT EXISTS (
                                                        SELECT 1
                                                        FROM public.consumer_orders_variety cov_lbl
                                                        WHERE cov_lbl.covg_id = covg.covg_id
                                                            AND cov_lbl.selection_type IN ('MATCHED', 'PLEDGED')
                                                    ) THEN 'pending'
                                                    WHEN NOT EXISTS (
                                                        SELECT 1
                                                        FROM public.consumer_orders_variety cov_lbl
                                                        WHERE cov_lbl.covg_id = covg.covg_id
                                                            AND cov_lbl.selection_type IN ('MATCHED', 'PLEDGED')
                                                            AND (
                                                                cov_lbl.final_price IS NULL
                                                                OR cov_lbl.final_price = 0
                                                            )
                                                    ) THEN 'final'
                                                    ELSE 'tentative'
                                                END,
                                                -- varieties: only MATCHED/PLEDGED/DENIED/SKIPPED — never raw OPEN
                                                -- OPEN is represented at the group level via quantity/allocated_quantity/price_label
                                                'varieties',
                                                COALESCE(
                                                    (
                                                        SELECT jsonb_agg(
                                                                jsonb_build_object(
                                                                    'cov_id',
                                                                    cov.cov_id,
                                                                    'name',
                                                                    pv.variety_name,
                                                                    'variety_id',
                                                                    cov.variety_id,
                                                                    'listing_id',
                                                                    cov.listing_id,
                                                                    'selection_type',
                                                                    cov.selection_type,
                                                                    'is_price_lock',
                                                                    COALESCE(cov.is_price_lock, FALSE),
                                                                    'price_lock',
                                                                    cov.price_lock,
                                                                    'final_price',
                                                                    cov.final_price,
                                                                    'dtc_price',
                                                                    cov.dtc_price,
                                                                    -- price_label per variety row
                                                                    'price_label',
                                                                    CASE
                                                                        WHEN covg.cps_id IS NOT NULL
                                                                        AND cov.selection_type IN ('OPEN') THEN 'plan'
                                                                        WHEN cov.selection_type IN ('DENIED', 'SKIPPED', 'CANCELLED') THEN cov.selection_type::text
                                                                        WHEN cov.final_price IS NOT NULL
                                                                        AND cov.final_price > 0 THEN 'final'
                                                                        WHEN COALESCE(cov.is_price_lock, FALSE) = TRUE
                                                                        AND cov.price_lock IS NOT NULL THEN 'price_lock'
                                                                        ELSE 'tentative'
                                                                    END,
                                                                    -- effective quantity: 0 for non-allocated, actual allocated qty for matched
                                                                    'quantity',
                                                                    COALESCE(
                                                                        (
                                                                            SELECT foa_q.quantity
                                                                            FROM public.offer_order_match oom_q
                                                                                JOIN public.farmer_offers_allocations foa_q ON foa_q.foa_id = oom_q.foa_id
                                                                            WHERE oom_q.cov_id = cov.cov_id
                                                                            LIMIT 1
                                                                        ), 0
                                                                    ), 'is_paid', COALESCE(
                                                                        (
                                                                            SELECT oom_p.consumer_has_paid
                                                                            FROM public.offer_order_match oom_p
                                                                            WHERE oom_p.cov_id = cov.cov_id
                                                                            LIMIT 1
                                                                        ), FALSE
                                                                    ), 'oom_id', (
                                                                        SELECT oom.oom_id
                                                                        FROM public.offer_order_match oom
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    ), 'delivery_status', (
                                                                        SELECT oom.delivery_status
                                                                        FROM public.offer_order_match oom
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    ), 'dispatch_date', (
                                                                        SELECT oom.dispatch_at
                                                                        FROM public.offer_order_match oom
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    ), 'delivery_fee', (
                                                                        SELECT oom.delivery_fee
                                                                        FROM public.offer_order_match oom
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    ), 'carrier_name', (
                                                                        SELECT ucr.name
                                                                        FROM public.offer_order_match oom
                                                                            LEFT JOIN public.user_carriers ucr ON ucr.carrier_id = oom.carrier_id
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    ), 'farmer_location', (
                                                                        SELECT jsonb_build_object(
                                                                                'address_line_1',
                                                                                ua.address_line_1,
                                                                                'address_line_2',
                                                                                ua.address_line_2,
                                                                                'city',
                                                                                ua.city,
                                                                                'province',
                                                                                ua.province,
                                                                                'region',
                                                                                ua.region,
                                                                                'landmark',
                                                                                ua.landmark,
                                                                                'postal_code',
                                                                                ua.postal_code,
                                                                                'country',
                                                                                ua.country
                                                                            )
                                                                        FROM public.offer_order_match oom
                                                                            JOIN public.users_addresses ua ON ua.address_id = oom.farmer_address
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    ), 'consumer_location', (
                                                                        SELECT jsonb_build_object(
                                                                                'address_line_1',
                                                                                ua.address_line_1,
                                                                                'address_line_2',
                                                                                ua.address_line_2,
                                                                                'city',
                                                                                ua.city,
                                                                                'province',
                                                                                ua.province,
                                                                                'region',
                                                                                ua.region,
                                                                                'landmark',
                                                                                ua.landmark,
                                                                                'postal_code',
                                                                                ua.postal_code,
                                                                                'country',
                                                                                ua.country
                                                                            )
                                                                        FROM public.offer_order_match oom
                                                                            JOIN public.users_addresses ua ON ua.address_id = oom.consumer_address
                                                                        WHERE oom.cov_id = cov.cov_id
                                                                        LIMIT 1
                                                                    )
                                                                )
                                                                ORDER BY pv.variety_name
                                                            )
                                                        FROM public.consumer_orders_variety cov
                                                            JOIN public.produce_varieties pv ON pv.variety_id = cov.variety_id
                                                        WHERE cov.covg_id = covg.covg_id -- exclude raw OPEN rows — they are represented via the group's quantity/price_label
                                                            AND cov.selection_type != 'OPEN'
                                                    ),
                                                    '[]'::jsonb
                                                )
                                            )
                                            ORDER BY covg.item_index,
                                                covg.date_needed
                                        )
                                    FROM public.consumer_orders_variety_group covg
                                    WHERE covg.cop_id = cop.cop_id
                                ),
                                '[]'::jsonb
                            )
                        )
                        ORDER BY cop.item_index
                    )
                FROM public.consumer_orders_produce cop
                    JOIN public.produce p ON p.id = cop.produce_id
                WHERE cop.order_id = o.order_id
            ),
            '[]'::jsonb
        ),
        'stats',
        (
            SELECT jsonb_build_object(
                    'status',
                    COALESCE(
                        (
                            SELECT jsonb_object_agg(status, count)
                            FROM (
                                    SELECT oom.delivery_status::text AS status,
                                        COUNT(DISTINCT cov_s.covg_id) AS count
                                    FROM public.offer_order_match oom
                                        JOIN public.consumer_orders_variety cov_s ON cov_s.cov_id = oom.cov_id
                                        JOIN public.consumer_orders_variety_group covg_s ON covg_s.covg_id = cov_s.covg_id
                                        JOIN public.consumer_orders_produce cop_s ON cop_s.cop_id = covg_s.cop_id
                                    WHERE cop_s.order_id = o.order_id
                                    GROUP BY oom.delivery_status
                                ) s
                        ),
                        '{}'::jsonb
                    ),
                    'paid',
                    (
                        SELECT COUNT(DISTINCT cov_p.covg_id)
                        FROM public.offer_order_match oom_p
                            JOIN public.consumer_orders_variety cov_p ON cov_p.cov_id = oom_p.cov_id
                            JOIN public.consumer_orders_variety_group covg_p ON covg_p.covg_id = cov_p.covg_id
                            JOIN public.consumer_orders_produce cop_p ON cop_p.cop_id = covg_p.cop_id
                        WHERE cop_p.order_id = o.order_id
                            AND oom_p.consumer_has_paid = TRUE
                    ),
                    'unpaid',
                    (
                        SELECT COUNT(DISTINCT cov_p.covg_id)
                        FROM public.offer_order_match oom_p
                            JOIN public.consumer_orders_variety cov_p ON cov_p.cov_id = oom_p.cov_id
                            JOIN public.consumer_orders_variety_group covg_p ON covg_p.covg_id = cov_p.covg_id
                            JOIN public.consumer_orders_produce cop_p ON cop_p.cop_id = covg_p.cop_id
                        WHERE cop_p.order_id = o.order_id
                            AND oom_p.consumer_has_paid = FALSE
                    )
                )
        )
    )
FROM target_order o;
$$;