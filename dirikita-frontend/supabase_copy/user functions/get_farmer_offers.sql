CREATE OR REPLACE FUNCTION public.get_farmer_offers(
        p_active        BOOLEAN     DEFAULT TRUE,
        -- Keyset cursor: the sort-key value of the last seen row (as text) + its offer_id
        p_cursor_val    TEXT        DEFAULT NULL,
        p_cursor_id     UUID        DEFAULT NULL,
        p_limit         INT         DEFAULT 20,
        p_search        TEXT        DEFAULT NULL,
        -- Sort: 'date_desc' | 'date_asc'
        --       'reserved_desc' | 'reserved_asc'
        --       'avail_from_asc' | 'avail_from_desc'
        --       'avail_to_asc'   | 'avail_to_desc'
        p_sort          TEXT        DEFAULT 'date_desc',
        -- Filter by created_at date range
        p_date_from     DATE        DEFAULT NULL,
        p_date_to       DATE        DEFAULT NULL
    ) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
    v_caller_uid  UUID;
    v_farmer_id   TEXT;
    v_search      TEXT;
    v_rows        JSONB[];
    v_has_more    BOOLEAN;
    v_count       INT;
    -- Cursor values decoded from p_cursor_val
    v_cursor_ts   TIMESTAMPTZ;
    v_cursor_num  NUMERIC;
BEGIN
    -- ── Auth ──────────────────────────────────────────────────────────────────
    v_caller_uid := auth.uid();
    IF v_caller_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authentication required';
    END IF;

    SELECT farmer_id INTO v_farmer_id
    FROM public.user_farmers
    WHERE user_id = v_caller_uid
    LIMIT 1;

    IF v_farmer_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: no farmer profile for this user';
    END IF;

    v_search := NULLIF(TRIM(p_search), '');

    -- Decode cursor value based on sort type
    IF p_cursor_val IS NOT NULL THEN
        IF p_sort IN ('date_desc', 'date_asc', 'avail_from_asc', 'avail_from_desc', 'avail_to_asc', 'avail_to_desc') THEN
            v_cursor_ts := p_cursor_val::TIMESTAMPTZ;
        ELSIF p_sort IN ('reserved_desc', 'reserved_asc') THEN
            v_cursor_num := p_cursor_val::NUMERIC;
        END IF;
    END IF;

    -- ── Main query ────────────────────────────────────────────────────────────
    SELECT ARRAY(
        SELECT jsonb_build_object(
            'offer_id',                    fo.offer_id,
            'variety_name',                pv.variety_name,
            'produce_id',                  p.id,
            'produce_english_name',        p.english_name,
            'produce_local_name',          COALESCE(
                                               (SELECT pd.local_name
                                                FROM   public.produce_dialects pd
                                                JOIN   public.dialects d ON d.id = pd.dialect_id
                                                JOIN   public.users    u ON u.dialect[1] = d.dialect_name
                                                WHERE  pd.produce_id = p.id
                                                  AND  u.id = v_caller_uid
                                                LIMIT  1),
                                               p.english_name
                                           ),
            'quantity',                    fo.quantity,
            'remaining_quantity',          fo.remaining_quantity,
            'is_active',                   fo.is_active,
            'is_price_locked',             COALESCE(fo.is_price_locked, FALSE),
            'total_price_lock_credit',     fo.total_price_lock_credit,
            'remaining_price_lock_credit', fo.remaining_price_lock_credit,
            'available_from',              fo.available_from,
            'available_to',                fo.available_to,
            'created_at',                  fo.created_at,
            'orders',                      '[]'::JSONB,
            'orders_total_price',          0,
            'farmer_total_earnings',       0
        )
        FROM public.farmer_offers fo
        JOIN public.produce_varieties pv ON pv.variety_id = fo.variety_id
        JOIN public.produce           p  ON p.id = pv.produce_id
        WHERE fo.farmer_id = v_farmer_id
          AND fo.is_active  = p_active
          -- Date range filter (always on created_at)
          AND (p_date_from IS NULL OR fo.created_at::DATE >= p_date_from)
          AND (p_date_to   IS NULL OR fo.created_at::DATE <= p_date_to)
          -- Search
          AND (
              v_search IS NULL
              OR p.english_name ILIKE '%' || v_search || '%'
              OR pv.variety_name ILIKE '%' || v_search || '%'
              OR COALESCE(
                    (SELECT pd2.local_name
                     FROM   public.produce_dialects pd2
                     JOIN   public.dialects d2 ON d2.id = pd2.dialect_id
                     JOIN   public.users    u2 ON u2.dialect[1] = d2.dialect_name
                     WHERE  pd2.produce_id = p.id
                       AND  u2.id = v_caller_uid
                     LIMIT  1),
                    ''
                 ) ILIKE '%' || v_search || '%'
          )
          -- Keyset cursor
          AND CASE p_sort
              WHEN 'date_asc' THEN
                  v_cursor_ts IS NULL
                  OR fo.created_at > v_cursor_ts
                  OR (fo.created_at = v_cursor_ts AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              WHEN 'reserved_desc' THEN
                  v_cursor_num IS NULL
                  OR (fo.quantity - fo.remaining_quantity) < v_cursor_num
                  OR ((fo.quantity - fo.remaining_quantity) = v_cursor_num AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              WHEN 'reserved_asc' THEN
                  v_cursor_num IS NULL
                  OR (fo.quantity - fo.remaining_quantity) > v_cursor_num
                  OR ((fo.quantity - fo.remaining_quantity) = v_cursor_num AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              WHEN 'avail_from_asc' THEN
                  v_cursor_ts IS NULL
                  OR fo.available_from > v_cursor_ts
                  OR (fo.available_from = v_cursor_ts AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              WHEN 'avail_from_desc' THEN
                  v_cursor_ts IS NULL
                  OR fo.available_from < v_cursor_ts
                  OR (fo.available_from = v_cursor_ts AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              WHEN 'avail_to_asc' THEN
                  v_cursor_ts IS NULL
                  OR fo.available_to > v_cursor_ts
                  OR (fo.available_to = v_cursor_ts AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              WHEN 'avail_to_desc' THEN
                  v_cursor_ts IS NULL
                  OR fo.available_to < v_cursor_ts
                  OR (fo.available_to = v_cursor_ts AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              ELSE -- date_desc
                  v_cursor_ts IS NULL
                  OR fo.created_at < v_cursor_ts
                  OR (fo.created_at = v_cursor_ts AND fo.offer_id::TEXT > p_cursor_id::TEXT)
              END
        ORDER BY
            CASE WHEN p_sort = 'date_asc'       THEN fo.created_at      END ASC,
            CASE WHEN p_sort = 'date_asc'       THEN fo.offer_id::TEXT  END ASC,
            CASE WHEN p_sort = 'reserved_desc'  THEN fo.quantity - fo.remaining_quantity END DESC,
            CASE WHEN p_sort = 'reserved_desc'  THEN fo.offer_id::TEXT  END ASC,
            CASE WHEN p_sort = 'reserved_asc'   THEN fo.quantity - fo.remaining_quantity END ASC,
            CASE WHEN p_sort = 'reserved_asc'   THEN fo.offer_id::TEXT  END ASC,
            CASE WHEN p_sort = 'avail_from_asc' THEN fo.available_from  END ASC,
            CASE WHEN p_sort = 'avail_from_asc' THEN fo.offer_id::TEXT  END ASC,
            CASE WHEN p_sort = 'avail_from_desc' THEN fo.available_from END DESC,
            CASE WHEN p_sort = 'avail_from_desc' THEN fo.offer_id::TEXT END ASC,
            CASE WHEN p_sort = 'avail_to_asc'   THEN fo.available_to    END ASC,
            CASE WHEN p_sort = 'avail_to_asc'   THEN fo.offer_id::TEXT  END ASC,
            CASE WHEN p_sort = 'avail_to_desc'  THEN fo.available_to    END DESC,
            CASE WHEN p_sort = 'avail_to_desc'  THEN fo.offer_id::TEXT  END ASC,
            -- default: date_desc
            CASE WHEN p_sort NOT IN ('date_asc','reserved_desc','reserved_asc',
                                     'avail_from_asc','avail_from_desc',
                                     'avail_to_asc','avail_to_desc')
                 THEN fo.created_at                                      END DESC,
            CASE WHEN p_sort NOT IN ('date_asc','reserved_desc','reserved_asc',
                                     'avail_from_asc','avail_from_desc',
                                     'avail_to_asc','avail_to_desc')
                 THEN fo.offer_id::TEXT                                  END ASC
        LIMIT p_limit + 1
    ) INTO v_rows;

    v_count    := COALESCE(array_length(v_rows, 1), 0);
    v_has_more := v_count > p_limit;

    IF v_has_more THEN
        v_rows := v_rows[1:p_limit];
    END IF;

    RETURN jsonb_build_object(
        'offers',   COALESCE(array_to_json(v_rows)::JSONB, '[]'::JSONB),
        'has_more', v_has_more
    );
END;
$$;
