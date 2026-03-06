-- =============================================================
-- FUNCTION: public.get_specific_produce
-- =============================================================
--
-- PURPOSE:
--   Returns produce items. Supports filtering by ID list, free-text
--   search, and offset-based pagination. The output shape varies by
--   p_mode:
--
--   'for_farmer'   — Produce names + variety listings with farmer price.
--   'for_consumer' — Same + consumer prices + 30-day offer aggregation.
--   'details'      — Full produce + variety + listing fields.
--
-- PARAMETERS:
--   p_produce_ids — UUID[] to filter specific produce. NULL = all produce.
--   p_mode        — 'for_farmer' | 'for_consumer' | 'details' (default).
--   p_user_id     — UUID of requesting user (dialect lookup + auth check).
--   p_limit       — Page size.  0 = no limit.  Default 20.
--   p_offset      — Row offset for the page.    Default 0.
--   p_search      — Free-text filter on english_name / scientific_name.
--
-- RESPONSE ENVELOPE:
--   { "data": [...], "total_count": <int> }
--
-- FLUTTER/SUPABASE RPC CALL:
--   supabase.rpc('get_specific_produce', params: {
--     'p_produce_ids': null,          // or ['uuid1', 'uuid2']
--     'p_mode':        'for_consumer',
--     'p_user_id':     userId,
--     'p_limit':       20,
--     'p_offset':      0,
--     'p_search':      '',
--   });
-- =============================================================
CREATE OR REPLACE FUNCTION public.get_specific_produce(
        p_produce_ids UUID [] DEFAULT NULL,
        p_mode TEXT DEFAULT 'details',
        p_user_id UUID DEFAULT NULL,
        p_limit INTEGER DEFAULT 20,
        p_offset INTEGER DEFAULT 0,
        p_search TEXT DEFAULT ''
    ) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_dialect TEXT;
v_data JSONB;
v_result JSONB;
v_total_count BIGINT;
v_resolved_user_id UUID;
BEGIN -- ── Auth ──────────────────────────────────────────────────────────────
v_resolved_user_id := COALESCE(p_user_id, auth.uid());
IF v_resolved_user_id IS NULL
OR auth.uid() IS NULL THEN RAISE EXCEPTION 'Unauthorized: authentication required';
END IF;
IF p_user_id IS NOT NULL
AND auth.uid() <> p_user_id THEN RAISE EXCEPTION 'Unauthorized: cannot fetch data for another user';
END IF;
-- ── Dialect ───────────────────────────────────────────────────────────
SELECT dialect [1] INTO v_dialect
FROM public.users
WHERE id = v_resolved_user_id;
-- ── Shared WHERE predicate (applied to all modes) ─────────────────────
--   (p_produce_ids IS NULL OR p.id = ANY(p_produce_ids))    ← ID filter
--   AND (p_search = '' OR ... ILIKE ...)                     ← text search
-- =========================================================
-- MODE: for_farmer
-- =========================================================
IF p_mode = 'for_farmer' THEN -- total matching rows (for pagination metadata)
SELECT COUNT(*) INTO v_total_count
FROM public.produce p
WHERE (
        p_produce_ids IS NULL
        OR p.id = ANY(p_produce_ids)
    )
    AND (
        p_search = ''
        OR p.english_name ILIKE '%' || p_search || '%'
        OR p.scientific_name ILIKE '%' || p_search || '%'
    );
-- paged data
SELECT COALESCE(
        jsonb_agg(
            produce_row
            ORDER BY p.english_name ASC
        ),
        '[]'::jsonb
    ) INTO v_data
FROM (
        SELECT p.*
        FROM public.produce p
        WHERE (
                p_produce_ids IS NULL
                OR p.id = ANY(p_produce_ids)
            )
            AND (
                p_search = ''
                OR p.english_name ILIKE '%' || p_search || '%'
                OR p.scientific_name ILIKE '%' || p_search || '%'
            )
        ORDER BY p.english_name ASC
        LIMIT CASE
                WHEN p_limit > 0 THEN p_limit
            END OFFSET p_offset
    ) p
    CROSS JOIN LATERAL (
        SELECT jsonb_build_object(
                'id',
                p.id,
                'english_name',
                p.english_name,
                'image_url',
                p.image_url,
                'base_unit',
                p.base_unit,
                'local_name',
                COALESCE(
                    (
                        SELECT pd.local_name
                        FROM public.produce_dialects pd
                            JOIN public.dialects d ON d.id = pd.dialect_id
                        WHERE pd.produce_id = p.id
                            AND d.dialect_name = v_dialect
                        LIMIT 1
                    ), p.english_name
                ), 'varieties', COALESCE(
                    (
                        SELECT jsonb_agg(
                                jsonb_build_object(
                                    'variety_id',
                                    v.variety_id,
                                    'variety_name',
                                    v.variety_name,
                                    'image_url',
                                    v.image_url,
                                    'listings',
                                    COALESCE(
                                        (
                                            SELECT jsonb_agg(
                                                    jsonb_build_object(
                                                        'listing_id',
                                                        l.listing_id,
                                                        'produce_form',
                                                        l.produce_form,
                                                        'farmer_to_duruha_price',
                                                        l.farmer_to_duruha_price
                                                    )
                                                    ORDER BY l.produce_form ASC NULLS LAST
                                                )
                                            FROM public.produce_variety_listing l
                                            WHERE l.variety_id = v.variety_id
                                        ),
                                        '[]'::jsonb
                                    )
                                )
                                ORDER BY v.variety_name ASC
                            )
                        FROM public.produce_varieties v
                        WHERE v.produce_id = p.id
                    ),
                    '[]'::jsonb
                )
            ) AS produce_row
    ) sub;
-- =========================================================
-- MODE: for_consumer
-- Returns consumer prices + 30-day active offer aggregation.
--
    -- Offer window: is_active = TRUE
--   AND available_to  >= CURRENT_DATE
--   AND available_from <= CURRENT_DATE + INTERVAL '30 days'
--
    -- Produce-level: avg_30d_offer_qty, total_30d_offer_qty
-- Variety-level: avg_30d_offer_qty, sum_30d_offer_qty
-- =========================================================
ELSIF p_mode = 'for_consumer' THEN
SELECT COUNT(*) INTO v_total_count
FROM public.produce p
WHERE (
        p_produce_ids IS NULL
        OR p.id = ANY(p_produce_ids)
    )
    AND (
        p_search = ''
        OR p.english_name ILIKE '%' || p_search || '%'
        OR p.scientific_name ILIKE '%' || p_search || '%'
    );
SELECT COALESCE(
        jsonb_agg(
            produce_row
            ORDER BY p.english_name ASC
        ),
        '[]'::jsonb
    ) INTO v_data
FROM (
        SELECT p.*
        FROM public.produce p
        WHERE (
                p_produce_ids IS NULL
                OR p.id = ANY(p_produce_ids)
            )
            AND (
                p_search = ''
                OR p.english_name ILIKE '%' || p_search || '%'
                OR p.scientific_name ILIKE '%' || p_search || '%'
            )
        ORDER BY p.english_name ASC
        LIMIT CASE
                WHEN p_limit > 0 THEN p_limit
            END OFFSET p_offset
    ) p
    CROSS JOIN LATERAL (
        SELECT jsonb_build_object(
                'id',
                p.id,
                'english_name',
                p.english_name,
                'image_url',
                p.image_url,
                'base_unit',
                p.base_unit,
                'local_name',
                COALESCE(
                    (
                        SELECT pd.local_name
                        FROM public.produce_dialects pd
                            JOIN public.dialects d ON d.id = pd.dialect_id
                        WHERE pd.produce_id = p.id
                            AND d.dialect_name = v_dialect
                        LIMIT 1
                    ), p.english_name
                ), -- produce-level 30-day offer aggregation
                'avg_30d_offer_qty', (
                    SELECT AVG(fo.remaining_quantity)
                    FROM public.farmer_offers fo
                        JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
                    WHERE pv.produce_id = p.id
                        AND fo.is_active = TRUE
                        AND fo.available_to >= CURRENT_DATE
                        AND fo.available_from <= CURRENT_DATE + INTERVAL '30 days'
                ),
                'total_30d_offer_qty',
                (
                    SELECT SUM(fo.remaining_quantity)
                    FROM public.farmer_offers fo
                        JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
                    WHERE pv.produce_id = p.id
                        AND fo.is_active = TRUE
                        AND fo.available_to >= CURRENT_DATE
                        AND fo.available_from <= CURRENT_DATE + INTERVAL '30 days'
                ),
                'varieties',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                                jsonb_build_object(
                                    'variety_id',
                                    v.variety_id,
                                    'variety_name',
                                    v.variety_name,
                                    'image_url',
                                    v.image_url,
                                    -- per-variety 30-day offer aggregation
                                    'avg_30d_offer_qty',
                                    (
                                        SELECT AVG(fo.remaining_quantity)
                                        FROM public.farmer_offers fo
                                        WHERE fo.variety_id = v.variety_id
                                            AND fo.is_active = TRUE
                                            AND fo.available_to >= CURRENT_DATE
                                            AND fo.available_from <= CURRENT_DATE + INTERVAL '30 days'
                                    ),
                                    'sum_30d_offer_qty',
                                    (
                                        SELECT SUM(fo.remaining_quantity)
                                        FROM public.farmer_offers fo
                                        WHERE fo.variety_id = v.variety_id
                                            AND fo.is_active = TRUE
                                            AND fo.available_to >= CURRENT_DATE
                                            AND fo.available_from <= CURRENT_DATE + INTERVAL '30 days'
                                    ),
                                    -- consumer-facing listing prices
                                    'listings',
                                    COALESCE(
                                        (
                                            SELECT jsonb_agg(
                                                    jsonb_build_object(
                                                        'listing_id',
                                                        l.listing_id,
                                                        'produce_form',
                                                        l.produce_form,
                                                        'duruha_to_consumer_price',
                                                        l.duruha_to_consumer_price,
                                                        'market_to_consumer_price',
                                                        l.market_to_consumer_price
                                                    )
                                                    ORDER BY l.produce_form ASC NULLS LAST
                                                )
                                            FROM public.produce_variety_listing l
                                            WHERE l.variety_id = v.variety_id
                                        ),
                                        '[]'::jsonb
                                    )
                                )
                                ORDER BY v.variety_name ASC
                            )
                        FROM public.produce_varieties v
                        WHERE v.produce_id = p.id
                    ),
                    '[]'::jsonb
                )
            ) AS produce_row
    ) sub;
-- =========================================================
-- MODE: details
-- Full produce + variety + listing fields.
-- =========================================================
ELSIF p_mode = 'details' THEN
SELECT COUNT(*) INTO v_total_count
FROM public.produce p
WHERE (
        p_produce_ids IS NULL
        OR p.id = ANY(p_produce_ids)
    )
    AND (
        p_search = ''
        OR p.english_name ILIKE '%' || p_search || '%'
        OR p.scientific_name ILIKE '%' || p_search || '%'
    );
SELECT COALESCE(
        jsonb_agg(
            produce_row
            ORDER BY p.english_name ASC
        ),
        '[]'::jsonb
    ) INTO v_data
FROM (
        SELECT p.*
        FROM public.produce p
        WHERE (
                p_produce_ids IS NULL
                OR p.id = ANY(p_produce_ids)
            )
            AND (
                p_search = ''
                OR p.english_name ILIKE '%' || p_search || '%'
                OR p.scientific_name ILIKE '%' || p_search || '%'
            )
        ORDER BY p.english_name ASC
        LIMIT CASE
                WHEN p_limit > 0 THEN p_limit
            END OFFSET p_offset
    ) p
    CROSS JOIN LATERAL (
        SELECT jsonb_build_object(
                'id',
                p.id,
                'english_name',
                p.english_name,
                'scientific_name',
                p.scientific_name,
                'image_url',
                p.image_url,
                'category',
                p.category,
                'base_unit',
                p.base_unit,
                'storage_group',
                p.storage_group,
                'respiration_rate',
                p.respiration_rate,
                'cross_contamination_risk',
                p.cross_contamination_risk,
                'crush_weight_tolerance',
                p.crush_weight_tolerance,
                'is_ethylene_producer',
                p.is_ethylene_producer,
                'is_ethylene_sensitive',
                p.is_ethylene_sensitive,
                'local_name',
                COALESCE(
                    (
                        SELECT pd.local_name
                        FROM public.produce_dialects pd
                            JOIN public.dialects d ON d.id = pd.dialect_id
                        WHERE pd.produce_id = p.id
                            AND d.dialect_name = v_dialect
                        LIMIT 1
                    ), p.english_name
                ), 'varieties', COALESCE(
                    (
                        SELECT jsonb_agg(
                                jsonb_build_object(
                                    'variety_id',
                                    v.variety_id,
                                    'variety_name',
                                    v.variety_name,
                                    'image_url',
                                    v.image_url,
                                    'is_native',
                                    v.is_native,
                                    'breeding_type',
                                    v.breeding_type,
                                    'days_to_maturity_min',
                                    v.days_to_maturity_min,
                                    'days_to_maturity_max',
                                    v.days_to_maturity_max,
                                    'peak_months',
                                    v.peak_months,
                                    'philippine_season',
                                    v.philippine_season,
                                    'flood_tolerance',
                                    v.flood_tolerance,
                                    'handling_fragility',
                                    v.handling_fragility,
                                    'shelf_life_days',
                                    v.shelf_life_days,
                                    'optimal_storage_temp_c',
                                    v.optimal_storage_temp_c,
                                    'packaging_requirement',
                                    v.packaging_requirement,
                                    'appearance_desc',
                                    v.appearance_desc,
                                    'created_at',
                                    v.created_at,
                                    'updated_at',
                                    v.updated_at,
                                    'listings',
                                    COALESCE(
                                        (
                                            SELECT jsonb_agg(
                                                    jsonb_build_object(
                                                        'listing_id',
                                                        l.listing_id,
                                                        'produce_form',
                                                        l.produce_form,
                                                        'farmer_to_trader_price',
                                                        l.farmer_to_trader_price,
                                                        'farmer_to_duruha_price',
                                                        l.farmer_to_duruha_price,
                                                        'duruha_to_consumer_price',
                                                        l.duruha_to_consumer_price,
                                                        'market_to_consumer_price',
                                                        l.market_to_consumer_price,
                                                        'created_at',
                                                        l.created_at,
                                                        'updated_at',
                                                        l.updated_at
                                                    )
                                                    ORDER BY l.produce_form ASC NULLS LAST
                                                )
                                            FROM public.produce_variety_listing l
                                            WHERE l.variety_id = v.variety_id
                                        ),
                                        '[]'::jsonb
                                    )
                                )
                                ORDER BY v.variety_name ASC
                            )
                        FROM public.produce_varieties v
                        WHERE v.produce_id = p.id
                    ),
                    '[]'::jsonb
                )
            ) AS produce_row
    ) sub;
ELSE v_data := '[]'::jsonb;
v_total_count := 0;
END IF;
v_result := jsonb_build_object(
    'data',
    v_data,
    'total_count',
    v_total_count
);
RETURN v_result;
END;
$$;