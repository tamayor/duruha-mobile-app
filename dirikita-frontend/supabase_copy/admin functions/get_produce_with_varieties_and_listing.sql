CREATE OR REPLACE FUNCTION get_produce_with_varieties_and_listing(
        p_cursor_updated_at timestamptz DEFAULT NULL,
        p_cursor_id uuid DEFAULT NULL,
        p_limit int DEFAULT 10
    ) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_produce_rows jsonb;
v_count int;
v_has_more boolean;
v_next_cursor_updated_at timestamptz;
v_next_cursor_id uuid;
BEGIN -- ── 1. Count produce rows (p_limit + 1) ─────────────────────
SELECT COUNT(*) INTO v_count
FROM (
        SELECT p.id
        FROM produce p
        WHERE p_cursor_updated_at IS NULL
            OR (p.updated_at, p.id) < (p_cursor_updated_at, p_cursor_id)
        ORDER BY p.updated_at DESC,
            p.id DESC
        LIMIT p_limit + 1
    ) sub;
v_has_more := v_count > p_limit;
-- ── 2. Fetch trimmed produce page + varieties + listings ─────
SELECT jsonb_agg(
        jsonb_build_object(
            'id',
            pp.id,
            'english_name',
            pp.english_name,
            'scientific_name',
            pp.scientific_name,
            'created_at',
            pp.created_at,
            'updated_at',
            pp.updated_at,
            'base_unit',
            pp.base_unit,
            'image_url',
            pp.image_url,
            'category',
            pp.category,
            'cross_contamination_risk',
            pp.cross_contamination_risk,
            'crush_weight_tolerance',
            pp.crush_weight_tolerance,
            'respiration_rate',
            pp.respiration_rate,
            'storage_group',
            pp.storage_group,
            'is_ethylene_producer',
            pp.is_ethylene_producer,
            'is_ethylene_sensitive',
            pp.is_ethylene_sensitive,
            'dialects',
            COALESCE(
                (
                    SELECT jsonb_agg(
                            jsonb_build_object(
                                'dialect_name',
                                d.dialect_name,
                                'local_name',
                                pd.local_name
                            )
                            ORDER BY d.dialect_name ASC
                        )
                    FROM produce_dialects pd
                        JOIN dialects d ON d.id = pd.dialect_id
                    WHERE pd.produce_id = pp.id
                ),
                '[]'::jsonb
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
                                'image_url',
                                v.image_url,
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
                                                    'farmer_to_duruha_price',
                                                    l.farmer_to_duruha_price,
                                                    'farmer_to_trader_price',
                                                    l.farmer_to_trader_price,
                                                    'duruha_to_consumer_price',
                                                    l.duruha_to_consumer_price,
                                                    'market_to_consumer_price',
                                                    l.market_to_consumer_price,
                                                    'created_at',
                                                    l.created_at,
                                                    'updated_at',
                                                    l.updated_at
                                                )
                                                ORDER BY l.produce_form ASC NULLS LAST,
                                                    l.listing_id ASC
                                            )
                                        FROM produce_variety_listing l
                                        WHERE l.variety_id = v.variety_id
                                    ),
                                    '[]'::jsonb
                                )
                            )
                            ORDER BY v.variety_name ASC
                        )
                    FROM produce_varieties v
                    WHERE v.produce_id = pp.id
                ),
                '[]'::jsonb
            )
        )
        ORDER BY pp.updated_at DESC,
            pp.id DESC
    ) INTO v_produce_rows
FROM (
        SELECT p.id,
            p.english_name,
            p.scientific_name,
            p.created_at,
            p.updated_at,
            p.base_unit,
            p.image_url,
            p.category,
            p.cross_contamination_risk,
            p.crush_weight_tolerance,
            p.respiration_rate,
            p.storage_group,
            p.is_ethylene_producer,
            p.is_ethylene_sensitive
        FROM produce p
        WHERE p_cursor_updated_at IS NULL
            OR (p.updated_at, p.id) < (p_cursor_updated_at, p_cursor_id)
        ORDER BY p.updated_at DESC,
            p.id DESC
        LIMIT p_limit
    ) pp;
-- ── 3. Build next cursor from last row ───────────────────────
IF v_has_more THEN
SELECT (v_produce_rows->(p_limit - 1)->>'updated_at')::timestamptz,
    (v_produce_rows->(p_limit - 1)->>'id')::uuid INTO v_next_cursor_updated_at,
    v_next_cursor_id;
END IF;
RETURN jsonb_build_object(
    'data',
    COALESCE(v_produce_rows, '[]'::jsonb),
    'count',
    LEAST(v_count, p_limit),
    'has_more',
    v_has_more,
    'next_cursor',
    CASE
        WHEN v_has_more THEN jsonb_build_object(
            'updated_at',
            v_next_cursor_updated_at,
            'id',
            v_next_cursor_id
        )
        ELSE NULL
    END
);
END;
$$;