CREATE OR REPLACE FUNCTION search_produce(p_query text, p_limit int DEFAULT 20) RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE v_rows jsonb;
v_tsq tsquery;
BEGIN IF p_query IS NULL
OR trim(p_query) = '' THEN RETURN jsonb_build_object('data', '[]'::jsonb, 'count', 0);
END IF;
-- Build tsquery: supports partial prefix match + full text
-- e.g. "tom" → 'tom':* which matches "tomato", "tomatoes"
v_tsq := to_tsquery(
    'english',
    array_to_string(
        ARRAY(
            SELECT lexeme || ':*'
            FROM unnest(
                    regexp_split_to_array(trim(p_query), '\s+')
                ) AS lexeme
            WHERE lexeme <> ''
        ),
        ' & '
    )
);
SELECT jsonb_agg(
        result
        ORDER BY result->>'rank' DESC
    ) INTO v_rows
FROM (
        SELECT DISTINCT ON (p.id) jsonb_build_object(
                'id',
                p.id,
                'english_name',
                p.english_name,
                'scientific_name',
                p.scientific_name,
                'created_at',
                p.created_at,
                'updated_at',
                p.updated_at,
                'base_unit',
                p.base_unit,
                'image_url',
                p.image_url,
                'category',
                p.category,
                'cross_contamination_risk',
                p.cross_contamination_risk,
                'crush_weight_tolerance',
                p.crush_weight_tolerance,
                'respiration_rate',
                p.respiration_rate,
                'storage_group',
                p.storage_group,
                'is_ethylene_producer',
                p.is_ethylene_producer,
                'is_ethylene_sensitive',
                p.is_ethylene_sensitive,
                'matched_via',
                CASE
                    WHEN lower(p.english_name) = lower(p_query) THEN 'exact_name'
                    WHEN lower(p.scientific_name) = lower(p_query) THEN 'exact_scientific'
                    WHEN lower(p.english_name) LIKE lower(p_query) || '%' THEN 'prefix_name'
                    WHEN lower(p.scientific_name) LIKE lower(p_query) || '%' THEN 'prefix_scientific'
                    WHEN v.variety_name IS NOT NULL THEN 'variety'
                    ELSE 'fulltext'
                END,
                'rank',
                CAST(
                    ts_rank(
                        to_tsvector(
                            'english',
                            coalesce(p.english_name, '') || ' ' || coalesce(p.scientific_name, '') || ' ' || coalesce(p.category, '')
                        ),
                        v_tsq
                    ) + COALESCE(
                        ts_rank(
                            to_tsvector('english', coalesce(v.variety_name, '')),
                            v_tsq
                        ),
                        0
                    ) + CASE
                        WHEN lower(p.english_name) = lower(p_query) THEN 1.0
                        WHEN lower(p.scientific_name) = lower(p_query) THEN 1.0
                        WHEN lower(p.english_name) LIKE lower(p_query) || '%' THEN 0.5
                        WHEN lower(p.scientific_name) LIKE lower(p_query) || '%' THEN 0.5
                        ELSE 0.0
                    END AS text
                ),
                'varieties',
                COALESCE(
                    (
                        SELECT jsonb_agg(
                                jsonb_build_object(
                                    'variety_id',
                                    vv.variety_id,
                                    'variety_name',
                                    vv.variety_name,
                                    'is_native',
                                    vv.is_native,
                                    'breeding_type',
                                    vv.breeding_type,
                                    'days_to_maturity_min',
                                    vv.days_to_maturity_min,
                                    'days_to_maturity_max',
                                    vv.days_to_maturity_max,
                                    'peak_months',
                                    vv.peak_months,
                                    'philippine_season',
                                    vv.philippine_season,
                                    'flood_tolerance',
                                    vv.flood_tolerance,
                                    'handling_fragility',
                                    vv.handling_fragility,
                                    'shelf_life_days',
                                    vv.shelf_life_days,
                                    'optimal_storage_temp_c',
                                    vv.optimal_storage_temp_c,
                                    'packaging_requirement',
                                    vv.packaging_requirement,
                                    'appearance_desc',
                                    vv.appearance_desc,
                                    'image_url',
                                    vv.image_url,
                                    'created_at',
                                    vv.created_at,
                                    'updated_at',
                                    vv.updated_at,
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
                                                        'market_to_consumer_price',
                                                        l.market_to_consumer_price,
                                                        'duruha_to_consumer_price',
                                                        l.duruha_to_consumer_price,
                                                        'created_at',
                                                        l.created_at,
                                                        'updated_at',
                                                        l.updated_at
                                                    )
                                                    ORDER BY l.produce_form ASC NULLS LAST,
                                                        l.listing_id ASC
                                                )
                                            FROM produce_variety_listing l
                                            WHERE l.variety_id = vv.variety_id
                                        ),
                                        '[]'::jsonb
                                    )
                                )
                                ORDER BY vv.variety_name ASC
                            )
                        FROM produce_varieties vv
                        WHERE vv.produce_id = p.id
                    ),
                    '[]'::jsonb
                )
            ) AS result
        FROM produce p
            LEFT JOIN produce_varieties v ON v.produce_id = p.id
        WHERE to_tsvector(
                'english',
                coalesce(p.english_name, '') || ' ' || coalesce(p.scientific_name, '') || ' ' || coalesce(p.category, '')
            ) @@ v_tsq
            OR to_tsvector('english', coalesce(v.variety_name, '')) @@ v_tsq
            OR p.english_name ILIKE '%' || p_query || '%'
            OR p.scientific_name ILIKE '%' || p_query || '%'
            OR p.category ILIKE '%' || p_query || '%'
            OR v.variety_name ILIKE '%' || p_query || '%'
        LIMIT p_limit
    ) ranked;
RETURN jsonb_build_object(
    'data',
    COALESCE(v_rows, '[]'::jsonb),
    'count',
    COALESCE(jsonb_array_length(v_rows), 0)
);
END;
$$;