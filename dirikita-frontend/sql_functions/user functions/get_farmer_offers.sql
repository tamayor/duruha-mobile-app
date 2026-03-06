CREATE OR REPLACE FUNCTION public.get_farmer_offers(
        p_active BOOLEAN DEFAULT TRUE,
        p_cursor TIMESTAMPTZ DEFAULT NULL,
        p_limit INT DEFAULT 10
    ) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_caller_uid UUID;
v_farmer_id TEXT;
v_cutoff_day DATE;
v_result JSONB;
v_has_more BOOLEAN;
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
-- ── Find the cutoff day: the day of the p_limit-th offer ─────────
-- We take the first p_limit offers (ordered newest-first) and grab
-- the date of the last one — then include ALL offers on that day.
SELECT fo.created_at::DATE INTO v_cutoff_day
FROM public.farmer_offers fo
WHERE fo.farmer_id = v_farmer_id
    AND fo.is_active = p_active
    AND (
        p_cursor IS NULL
        OR fo.created_at::DATE <= p_cursor::DATE
    )
ORDER BY fo.created_at DESC
LIMIT 1 OFFSET GREATEST(p_limit - 1, 0);
-- ── Aggregate into 3-level grouped JSON: Date -> Produce -> Variety ──
SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'date_created',
                day_data.day_bucket,
                'produce',
                day_data.produces
            )
            ORDER BY day_data.day_bucket DESC
        ),
        '[]'::JSONB
    ) INTO v_result
FROM (
        SELECT sub.day_bucket,
            jsonb_agg(
                jsonb_build_object(
                    'produce_id',
                    sub.produce_id,
                    'produce_english_name',
                    sub.produce_english_name,
                    'produce_local_name',
                    sub.produce_local_name,
                    'produce_varieties',
                    sub.varieties
                )
            ) AS produces
        FROM (
                SELECT fo.created_at::DATE AS day_bucket,
                    p.id AS produce_id,
                    p.english_name AS produce_english_name,
                    COALESCE(
                        (
                            SELECT pd.local_name
                            FROM public.produce_dialects pd
                                JOIN public.dialects d ON d.id = pd.dialect_id
                                JOIN public.users u ON u.dialect [1] = d.dialect_name
                            WHERE pd.produce_id = p.id
                                AND u.id = v_caller_uid
                            LIMIT 1
                        ), p.english_name
                    ) AS produce_local_name,
                    jsonb_agg(
                        jsonb_build_object(
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
                            'orders',
                            '[]'::JSONB,
                            'orders_total_price',
                            0,
                            'farmer_total_earnings',
                            0
                        )
                        ORDER BY fo.created_at DESC
                    ) AS varieties
                FROM public.farmer_offers fo
                    JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
                    JOIN public.produce p ON p.id = pv.produce_id
                WHERE fo.farmer_id = v_farmer_id
                    AND fo.is_active = p_active
                    AND (
                        p_cursor IS NULL
                        OR fo.created_at::DATE <= p_cursor::DATE
                    )
                    AND (
                        v_cutoff_day IS NULL
                        OR fo.created_at::DATE >= v_cutoff_day
                    )
                GROUP BY fo.created_at::DATE,
                    p.id,
                    p.english_name
            ) sub
        GROUP BY sub.day_bucket
    ) day_data;
-- ── has_more: any offers older than our cutoff day? ───────────────
SELECT EXISTS (
        SELECT 1
        FROM public.farmer_offers fo
        WHERE fo.farmer_id = v_farmer_id
            AND fo.is_active = p_active
            AND (
                v_cutoff_day IS NOT NULL
                AND fo.created_at::DATE < v_cutoff_day
            )
            AND (
                p_cursor IS NULL
                OR fo.created_at::DATE <= p_cursor::DATE
            )
    ) INTO v_has_more;
RETURN jsonb_build_object(
    'offers',
    v_result,
    'has_more',
    v_has_more
);
END;
$$;