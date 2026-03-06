CREATE OR REPLACE FUNCTION get_user_produce(
        p_is_favorite BOOLEAN DEFAULT FALSE,
        p_search TEXT DEFAULT '',
        p_offset INTEGER DEFAULT 0
    ) RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE v_user_id UUID := auth.uid();
v_user_role TEXT;
v_user_dialect TEXT;
v_dialect_id UUID;
v_fav_ids TEXT [] := ARRAY []::TEXT [];
v_data JSONB;
v_page_limit INTEGER := 10;
v_total_count BIGINT;
BEGIN -- 1. Get user role and first dialect
SELECT role::TEXT,
    dialect [1] INTO v_user_role,
    v_user_dialect
FROM public.users
WHERE id = v_user_id;
-- Resolve dialect UUID
SELECT id INTO v_dialect_id
FROM public.dialects
WHERE dialect_name = v_user_dialect
LIMIT 1;
-- 2. Get favorite IDs
IF v_user_role = 'FARMER' THEN
SELECT fav_produce INTO v_fav_ids
FROM public.user_farmers
WHERE user_id = v_user_id;
ELSIF v_user_role = 'CONSUMER' THEN
SELECT fav_produce INTO v_fav_ids
FROM public.user_consumers
WHERE user_id = v_user_id;
END IF;
v_fav_ids := COALESCE(v_fav_ids, ARRAY []::TEXT []);
-- 3. Main query
WITH filtered_produce AS (
    SELECT p.id,
        p.english_name,
        p.scientific_name,
        p.category,
        p.base_unit,
        p.image_url,
        COALESCE(
            (
                SELECT pd.local_name
                FROM public.produce_dialects pd
                WHERE pd.produce_id = p.id
                    AND pd.dialect_id = v_dialect_id
                LIMIT 1
            ), p.english_name
        ) AS local_name,
        (
            SELECT COUNT(*)::INTEGER
            FROM public.produce_varieties pv
            WHERE pv.produce_id = p.id
        ) AS variety_count
    FROM public.produce p
    WHERE (
            NOT p_is_favorite
            OR p.id::TEXT = ANY(v_fav_ids)
        )
        AND (
            p_search = ''
            OR p.english_name ILIKE '%' || p_search || '%'
            OR p.scientific_name ILIKE '%' || p_search || '%'
            OR EXISTS (
                SELECT 1
                FROM public.produce_dialects pd
                WHERE pd.produce_id = p.id
                    AND pd.local_name ILIKE '%' || p_search || '%'
            )
        )
),
paginated_results AS (
    SELECT *
    FROM filtered_produce
    ORDER BY english_name ASC
    LIMIT v_page_limit OFFSET p_offset
),
total_count AS (
    SELECT COUNT(*) AS full_count
    FROM filtered_produce
)
SELECT (
        SELECT full_count
        FROM total_count
    ),
    jsonb_build_object(
        'data',
        CASE
            v_user_role
            WHEN 'FARMER' THEN COALESCE(
                (
                    SELECT jsonb_agg(
                            jsonb_build_object(
                                'id',
                                r.id,
                                'image_url',
                                r.image_url,
                                'english_name',
                                r.english_name,
                                'local_name',
                                r.local_name,
                                'variety_count',
                                r.variety_count
                            )
                        )
                    FROM paginated_results r
                ),
                '[]'::jsonb
            )
            WHEN 'CONSUMER' THEN COALESCE(
                (
                    SELECT jsonb_agg(
                            jsonb_build_object(
                                'id',
                                r.id,
                                'image_url',
                                r.image_url,
                                'english_name',
                                r.english_name,
                                'scientific_name',
                                r.scientific_name,
                                'local_name',
                                r.local_name,
                                'category',
                                r.category,
                                'base_unit',
                                r.base_unit,
                                'variety_count',
                                r.variety_count,
                                'variety_count_available',
                                (
                                    SELECT COUNT(DISTINCT pv.variety_id)
                                    FROM public.produce_varieties pv
                                        JOIN public.farmer_offers fo ON fo.variety_id = pv.variety_id
                                    WHERE pv.produce_id = r.id
                                        AND fo.remaining_quantity > 0
                                        AND fo.is_active = TRUE
                                        AND fo.available_to >= CURRENT_DATE
                                        AND fo.available_from <= CURRENT_DATE + INTERVAL '30 days'
                                ),
                                '30d_offer_qty',
                                (
                                    SELECT SUM(fo.remaining_quantity)
                                    FROM public.farmer_offers fo
                                        JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
                                    WHERE pv.produce_id = r.id
                                        AND fo.is_active = TRUE
                                        AND fo.available_to >= CURRENT_DATE
                                        AND fo.available_from <= CURRENT_DATE + INTERVAL '30 days'
                                )
                            )
                        )
                    FROM paginated_results r
                ),
                '[]'::jsonb
            )
            ELSE '[]'::jsonb
        END,
        'total_count',
        (
            SELECT full_count
            FROM total_count
        ),
        'has_more',
        (p_offset + v_page_limit) < (
            SELECT full_count
            FROM total_count
        ),
        'next_offset',
        CASE
            WHEN (p_offset + v_page_limit) < (
                SELECT full_count
                FROM total_count
            ) THEN p_offset + v_page_limit
            ELSE NULL
        END
    ) INTO v_total_count,
    v_data;
RETURN v_data;
END;
$$;