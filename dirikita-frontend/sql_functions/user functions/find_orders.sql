CREATE OR REPLACE FUNCTION find_orders(
    p_mode TEXT DEFAULT 'near_me',
    p_radius_km NUMERIC DEFAULT 10,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
  ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_user_id UUID;
v_farmer_id TEXT;
v_city TEXT;
v_province TEXT;
v_postal_code TEXT;
v_region TEXT;
v_fav_produce TEXT [];
v_farmer_geog extensions.geography;
v_user_dialect TEXT;
v_page_size INT;
v_offset INT;
v_total_count INT;
v_result JSONB;
BEGIN IF p_mode NOT IN ('near_me', 'discover') THEN RAISE EXCEPTION 'p_mode must be ''near_me'' or ''discover''';
END IF;
v_page_size := LEAST(GREATEST(COALESCE(p_page_size, 10), 1), 10);
v_offset := (GREATEST(COALESCE(p_page, 1), 1) - 1) * v_page_size;
v_user_id := auth.uid();
IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated';
END IF;
-- Farmer location comes from users_addresses (via users.address_id) and dialect from users.dialect
SELECT ua.city,
  ua.province,
  ua.postal_code,
  ua.region,
  ua.location,
  u.dialect [1]
  INTO v_city,
  v_province,
  v_postal_code,
  v_region,
  v_farmer_geog,
  v_user_dialect
FROM users u
  LEFT JOIN users_addresses ua ON ua.address_id = u.address_id
WHERE u.id = v_user_id;
SELECT uf.farmer_id,
  uf.fav_produce INTO v_farmer_id,
  v_fav_produce
FROM user_farmers uf
WHERE uf.user_id = v_user_id
LIMIT 1;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'No farmer profile found for this user';
END IF;
WITH open_covs AS (
  SELECT co.order_id,
    cop.note,
    co.consumer_id,
    cop.cop_id,
    cop.produce_id,
    cop.quality,
    p.english_name AS produce_english_name,
    p.image_url AS produce_image_url,
    -- local name: match dialect[1] of the calling user
    COALESCE(pd.local_name, p.english_name) AS produce_local_name,
    covg.covg_id,
    covg.form AS produce_form,
    covg.date_needed,
    covg.quantity,
    cov.cov_id,
    cov.variety_id,
    cov.listing_id,
    pv.variety_name,
    pvl.farmer_to_duruha_price AS ftd_price
  FROM consumer_orders_variety cov
    JOIN consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
    JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
    JOIN consumer_orders co ON co.order_id = cop.order_id
    JOIN produce p ON p.id = cop.produce_id
    LEFT JOIN produce_varieties pv ON pv.variety_id = cov.variety_id
    LEFT JOIN produce_variety_listing pvl ON pvl.listing_id = cov.listing_id
    LEFT JOIN dialects d ON d.id::TEXT = v_user_dialect
    OR d.dialect_name = v_user_dialect
    LEFT JOIN produce_dialects pd ON pd.produce_id = cop.produce_id
    AND pd.dialect_id = d.id
  WHERE cov.selection_type = 'OPEN'
    AND co.is_active = TRUE
    AND co.payment_method IS NOT NULL
),
ranked_orders AS (
  SELECT DISTINCT ON (oc.cop_id) oc.order_id,
    oc.note,
    oc.consumer_id,
    oc.cop_id,
    oc.produce_id,
    oc.produce_english_name,
    oc.produce_image_url,
    oc.produce_local_name,
    oc.produce_form,
    oc.quality,
    -- Consumer address: look up via user_consumers -> users -> users_addresses
    ua.city AS c_city,
    ua.province AS c_province,
    ua.postal_code AS c_postal_code,
    ua.region AS c_region,
    ua.location AS c_geog,
    CASE
      WHEN ua.city = v_city THEN 1
      WHEN ua.province = v_province THEN 2
      WHEN ua.postal_code = v_postal_code THEN 3
      WHEN ua.region = v_region THEN 4
      ELSE 5
    END AS location_rank,
    CASE
      WHEN v_farmer_geog IS NOT NULL
      AND ua.location IS NOT NULL THEN extensions.ST_Distance(
        v_farmer_geog,
        ua.location
      ) / 1000.0
      ELSE NULL
    END AS distance_km,
    CASE
      WHEN v_fav_produce IS NOT NULL
      AND (
        oc.produce_id::TEXT = ANY(v_fav_produce)
        OR oc.produce_english_name = ANY(v_fav_produce)
      ) THEN 1
      ELSE 2
    END AS produce_rank,
    MIN(oc.date_needed) OVER (PARTITION BY oc.cop_id) AS earliest_date_needed
  FROM open_covs oc
    JOIN user_consumers uc ON uc.consumer_id = oc.consumer_id
    JOIN users u ON u.id = uc.user_id
    LEFT JOIN users_addresses ua ON ua.address_id = u.address_id
  WHERE CASE
      p_mode
      WHEN 'near_me' THEN (
        (
          v_farmer_geog IS NOT NULL
          AND ua.location IS NOT NULL
          AND extensions.ST_Distance(
            v_farmer_geog,
            ua.location
          ) / 1000.0 <= p_radius_km
        )
        OR ua.city = v_city
        OR ua.province = v_province
        OR ua.postal_code = v_postal_code
        OR ua.region = v_region
      )
      WHEN 'discover' THEN NOT (
        (
          v_farmer_geog IS NOT NULL
          AND ua.location IS NOT NULL
          AND extensions.ST_Distance(
            v_farmer_geog,
            ua.location
          ) / 1000.0 <= p_radius_km
        )
        OR ua.city = v_city
        OR ua.province = v_province
        OR ua.postal_code = v_postal_code
        OR ua.region = v_region
      )
    END
),
counted AS (
  SELECT COUNT(*)::INT AS total
  FROM ranked_orders
),
paginated AS (
  SELECT *
  FROM ranked_orders
  ORDER BY location_rank ASC,
    produce_rank ASC,
    earliest_date_needed ASC,
    distance_km ASC NULLS LAST,
    cop_id
  LIMIT v_page_size OFFSET v_offset
),
variety_groups AS (
  SELECT pg.order_id,
    pg.note,
    pg.cop_id,
    pg.produce_id,
    pg.produce_english_name,
    pg.produce_image_url,
    pg.produce_local_name,
    pg.produce_form,
    pg.quality,
    pg.location_rank,
    pg.produce_rank,
    pg.distance_km,
    pg.earliest_date_needed,
    pg.c_city,
    pg.c_province,
    pg.c_postal_code,
    pg.c_region,
    jsonb_agg(
      jsonb_build_object(
        'covg_id',
        date_groups.covg_id,
        'date_needed',
        date_groups.date_needed,
        'quantity',
        date_groups.quantity,
        'varieties',
        date_groups.varieties
      )
      ORDER BY date_groups.date_needed ASC
    ) AS variety_group
  FROM paginated pg
    JOIN LATERAL (
      SELECT oc2.covg_id,
        oc2.date_needed,
        oc2.quantity,
        jsonb_agg(
          jsonb_build_object(
            'variety_name',
            oc2.variety_name,
            'ftd_price',
            oc2.ftd_price,
            'cov_id',
            oc2.cov_id
          )
          ORDER BY oc2.variety_name
        ) AS varieties
      FROM open_covs oc2
      WHERE oc2.cop_id = pg.cop_id -- now filtered by cop_id
      GROUP BY oc2.covg_id,
        oc2.date_needed,
        oc2.quantity
    ) date_groups ON TRUE
  GROUP BY pg.order_id,
    pg.note,
    pg.cop_id,
    pg.produce_id,
    pg.produce_english_name,
    pg.produce_image_url,
    pg.produce_local_name,
    pg.produce_form,
    pg.quality,
    pg.location_rank,
    pg.produce_rank,
    pg.distance_km,
    pg.earliest_date_needed,
    pg.c_city,
    pg.c_province,
    pg.c_postal_code,
    pg.c_region
)
SELECT jsonb_build_object(
    'pagination',
    jsonb_build_object(
      'page',
      p_page,
      'page_size',
      v_page_size,
      'total_count',
      (
        SELECT total
        FROM counted
      ),
      'total_pages',
      CEIL(
        (
          SELECT total
          FROM counted
        )::NUMERIC / v_page_size
      ),
      'mode',
      p_mode,
      'radius_km',
      p_radius_km
    ),
    'orders',
    COALESCE(
      (
        SELECT jsonb_agg(
            jsonb_build_object(
              'order_id',
              vg.order_id,
              'note',
              vg.note,
              'cop_id',
              vg.cop_id,
              'produce_id',
              vg.produce_id,
              'produce_english_name',
              vg.produce_english_name,
              'produce_local_name',
              vg.produce_local_name,
              'produce_image_url',
              vg.produce_image_url,
              'produce_form',
              vg.produce_form,
              'quality',
              vg.quality,
              'distance_km',
              ROUND(vg.distance_km::NUMERIC, 2),
              'is_favourite_produce',
              vg.produce_rank = 1,
              'variety_group',
              vg.variety_group,
              'consumer_location',
              jsonb_build_object(
                'city',
                vg.c_city,
                'province',
                vg.c_province,
                'postal_code',
                vg.c_postal_code,
                'region',
                vg.c_region
              )
            )
            ORDER BY vg.location_rank ASC,
              vg.produce_rank ASC,
              vg.earliest_date_needed ASC,
              vg.distance_km ASC NULLS LAST
          )
        FROM variety_groups vg
      ),
      '[]'::jsonb
    )
  ) INTO v_result;
RETURN v_result;
END;
$$;
REVOKE ALL ON FUNCTION find_orders(TEXT, NUMERIC, INT, INT)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION find_orders(TEXT, NUMERIC, INT, INT) TO authenticated;