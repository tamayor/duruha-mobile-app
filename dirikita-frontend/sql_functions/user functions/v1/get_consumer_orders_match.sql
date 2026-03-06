CREATE OR REPLACE FUNCTION public.get_consumer_orders_match(
        p_match_id UUID DEFAULT NULL,
        p_limit INT DEFAULT 10,
        p_last_created_at TIMESTAMPTZ DEFAULT NULL
    ) RETURNS JSONB LANGUAGE sql VOLATILE SECURITY DEFINER AS $$ WITH
    /*
     * CTE 0 — resolve the consumer_id for the currently authenticated user.
     * Uses auth.uid() so no consumer_id needs to be passed from the client.
     */
    auth_consumer AS (
        SELECT uc.consumer_id
        FROM public.user_consumers uc
        WHERE uc.user_id = auth.uid()
        LIMIT 1
    ),
    /*
     * CTE 1 — paginated offer_order_match headers for this consumer.
     * Ordered by created_at DESC, limited to p_limit rows.
     * p_last_created_at is used as the pagination cursor (keyset pagination).
     */
    matches AS (
        SELECT oom.offer_order_match_id,
            oom.created_at,
            oom.consumer_paid,
            oom.consumer_payment_method,
            oom.is_active,
            oom.consumer_note
        FROM public.offer_order_match oom
        WHERE oom.consumer_id = (
                SELECT consumer_id
                FROM auth_consumer
            )
            AND (
                (
                    p_match_id IS NOT NULL
                    AND oom.offer_order_match_id = p_match_id
                )
                OR (
                    p_match_id IS NULL
                    AND (
                        p_last_created_at IS NULL
                        OR oom.created_at < p_last_created_at
                    )
                )
            )
        ORDER BY oom.created_at DESC
        LIMIT CASE
                WHEN p_match_id IS NOT NULL THEN 1
                ELSE p_limit
            END
    ),
    /*
     * CTE 2 — offer_order_match_items joined to their parent match.
     * Each row represents one farmer offer consumed.
     * Carrier name is resolved here since carrier_id lives on the item.
     */
    items AS (
        SELECT oomi.offer_order_match_id,
            oomi.id AS item_id,
            oomi.offer_id,
            oomi.order_id,
            oomi.farmer_id,
            oomi.farmer_is_paid,
            oomi.delivery_status,
            oomi.carrier_id,
            oomi.delivery_fee,
            oomi.dispatch_at,
            carr.name AS carrier_name
        FROM public.offer_order_match_items oomi
            JOIN matches m ON m.offer_order_match_id = oomi.offer_order_match_id
            LEFT JOIN public.carriers carr ON carr.id = oomi.carrier_id
    ),
    /*
     * CTE 3 — consumer_orders joined to produce + dialect name.
     * One row per consumer_orders record (one per variety_group).
     * Only pulls orders referenced by items in the matched set.
     * group_id is included so variety groups can be correctly nested
     * under their parent produce in the final output.
     *
     * ADDED: co.quality and co.quality_fee — stored per consumer_orders row
     * (i.e. per variety_group). Since quality and quality_fee are identical
     * across all groups belonging to the same produce line, MIN() in CTE 7
     * safely collapses them to a single value per produce.
     */
    orders AS (
        SELECT co.order_id,
            co.produce_id,
            co.group_id,
            co.is_any,
            co.date_needed,
            co.quality,
            co.quality_fee,
            p.english_name AS produce_english_name,
            COALESCE(pd.local_name, p.english_name) AS produce_dialect_name,
            p.image_url AS produce_img_url,
            uc.is_price_locked
        FROM public.consumer_orders co
            JOIN public.produce p ON p.id = co.produce_id
            JOIN public.user_consumers uc ON uc.consumer_id = (
                SELECT consumer_id
                FROM auth_consumer
            )
            JOIN public.users u ON u.id = uc.user_id
            LEFT JOIN public.dialects d ON d.dialect_name = u.dialect [1]
            LEFT JOIN public.produce_dialects pd ON pd.produce_id = p.id
            AND pd.dialect_id = d.id
        WHERE co.order_id IN (
                SELECT DISTINCT order_id
                FROM items
            )
    ),
    /*
     * CTE 4 — varieties per order_id, branching on is_any.
     *
     *   is_any = TRUE  → only varieties the consumer actually ordered
     *                    (rows in consumer_orders_varieties).
     *   is_any = FALSE → varieties explicitly requested for this group,
     *                    with consumed quantity filled in (0 if not consumed).
     *
     *   variety_group_id comes from cov.group_id, which is the group
     *   index written by create_consumer_order() at insert time.
     */
    varieties AS (
        -- is_any = TRUE: only consumed varieties
        SELECT o.order_id,
            cov.group_id AS variety_group_id,
            pv.variety_id,
            pv.variety_name,
            cov.quantity,
            CASE
                WHEN COALESCE(cov.price_locked, 0) > 0 THEN cov.price_locked
                ELSE COALESCE(pvl.duruha_to_consumer_price, 0)
            END AS price,
            pvl.produce_form,
            (COALESCE(cov.price_locked, 0) > 0) AS is_price_locked
        FROM public.consumer_orders o
            JOIN public.consumer_orders_varieties cov ON cov.order_id = o.order_id
            JOIN public.produce_varieties pv ON pv.variety_id = cov.variety_id
            LEFT JOIN public.produce_variety_listing pvl ON pvl.listing_id = cov.listing_id
        WHERE o.is_any = TRUE
        UNION ALL
        -- is_any = FALSE: varieties explicitly requested for this order's group.
        SELECT o.order_id,
            cov.group_id AS variety_group_id,
            pv.variety_id,
            pv.variety_name,
            COALESCE(cov.quantity, 0) AS quantity,
            CASE
                WHEN COALESCE(cov.price_locked, 0) > 0 THEN cov.price_locked
                ELSE COALESCE(pvl.duruha_to_consumer_price, 0)
            END AS price,
            pvl.produce_form,
            (COALESCE(cov.price_locked, 0) > 0) AS is_price_locked
        FROM public.consumer_orders o
            JOIN public.consumer_orders_varieties cov ON cov.order_id = o.order_id
            JOIN public.produce_varieties pv ON pv.variety_id = cov.variety_id
            LEFT JOIN public.produce_variety_listing pvl ON pvl.listing_id = cov.listing_id
        WHERE o.is_any = FALSE
    ),
    /*
     * CTE 5 — aggregate varieties into variety_groups[] per order_id.
     *
     * Inner subquery: one row per (order_id, variety_group_id) with
     *   the varieties array and group-level totals.
     * Outer query: one row per order_id with all groups as a jsonb array.
     */
    varieties_agg AS (
        SELECT v.order_id,
            jsonb_agg(
                jsonb_build_object(
                    'group_id',
                    v.variety_group_id,
                    'varieties',
                    v.varieties_json,
                    'total_quantity',
                    v.group_total_quantity,
                    'total_price',
                    v.group_total_price
                )
                ORDER BY v.variety_group_id
            ) AS variety_groups
        FROM (
                SELECT variety_group_id,
                    order_id,
                    jsonb_agg(
                        jsonb_build_object(
                            'variety_id',
                            variety_id,
                            'variety_name',
                            variety_name,
                            'variety_price',
                            price,
                            'variety_quantity',
                            quantity,
                            'produce_form',
                            produce_form,
                            'is_price_locked',
                            is_price_locked
                        )
                        ORDER BY variety_name
                    ) AS varieties_json,
                    SUM(quantity) AS group_total_quantity,
                    SUM(COALESCE(quantity * price, 0)) AS group_total_price
                FROM varieties
                GROUP BY order_id,
                    variety_group_id
            ) v
        GROUP BY v.order_id
    ),
    /*
     * CTE 6 — join items → orders → varieties_agg into one wide row per item.
     * Carries both order_id and produce_id so CTE 7 can group correctly.
     *
     * ADDED: quality and quality_fee forwarded from the orders CTE.
     */
    items_enriched AS (
        SELECT i.offer_order_match_id,
            i.item_id,
            i.carrier_id,
            i.carrier_name,
            i.dispatch_at,
            i.delivery_status,
            i.delivery_fee,
            o.order_id,
            o.produce_id,
            o.group_id AS order_group_id,
            o.produce_english_name,
            o.produce_dialect_name,
            o.is_any,
            o.produce_img_url,
            o.date_needed,
            o.quality,
            -- ← NEW
            o.quality_fee,
            -- ← NEW
            COALESCE(va.variety_groups, '[]'::jsonb) AS variety_groups
        FROM items i
            JOIN orders o ON o.order_id = i.order_id
            LEFT JOIN varieties_agg va ON va.order_id = i.order_id
    ),
    /*
     * CTE 7 — de-duplicate items, then group by produce per match.
     *
     * PROBLEM BEING SOLVED:
     *   Each variety_group creates its own consumer_orders row (one per
     *   group_id). A produce with 2 variety groups therefore has 2 order_ids,
     *   which previously produced 2 separate produce entries in the output.
     *
     * FIX:
     *   Step A — deduplicate to one row per (match, order_id).
     *   Step B — collect each order's variety_groups into a flat array,
     *             then aggregate all groups for the same produce together.
     *   Step C — group by (match, produce_id) so one produce entry appears
     *             with ALL its variety_groups nested inside.
     *
     * ADDED: quality and quality_fee collapsed to one value per produce via
     * MIN() — safe because the inner function writes the same quality and
     * quality_fee to every consumer_orders row belonging to the same produce
     * line (all groups share the same values from the payload item).
     */
    orders_per_match AS (
        SELECT ie.offer_order_match_id,
            jsonb_agg(
                jsonb_build_object(
                    'order_id',
                    ie.order_id,
                    'produce_id',
                    ie.produce_id,
                    'produce_english_name',
                    ie.produce_english_name,
                    'produce_dialect_name',
                    ie.produce_dialect_name,
                    'produce_img_url',
                    ie.produce_img_url,
                    'is_any',
                    ie.is_any,
                    'date_needed',
                    ie.date_needed,
                    'quality',
                    ie.quality,
                    -- ← NEW
                    'quality_fee',
                    ie.quality_fee,
                    -- ← NEW
                    'carrier_id',
                    ie.carrier_id,
                    'carrier_name',
                    ie.carrier_name,
                    'dispatch_at',
                    ie.dispatch_at,
                    'delivery_status',
                    ie.delivery_status,
                    'delivery_fee',
                    ie.delivery_fee,
                    'variety_groups',
                    (
                        SELECT jsonb_agg(
                                grp
                                ORDER BY (grp->>'group_id')::int
                            )
                        FROM jsonb_array_elements(ie.all_variety_groups) grp
                    )
                )
                ORDER BY ie.produce_english_name
            ) AS order_items_json
        FROM (
                /*
                 * Step B — one row per (match, produce_id).
                 * Collapse all variety_groups across every order_id that belongs
                 * to this produce into a single jsonb array.
                 * MIN() on quality / quality_fee is safe — same value per produce line.
                 */
                SELECT offer_order_match_id,
                    produce_id,
                    MIN(order_id::text)::uuid AS order_id,
                    MIN(produce_english_name) AS produce_english_name,
                    MIN(produce_dialect_name) AS produce_dialect_name,
                    MIN(produce_img_url) AS produce_img_url,
                    bool_or(is_any) AS is_any,
                    MIN(date_needed) AS date_needed,
                    MIN(quality::text)::public.quality AS quality,
                    -- ← NEW
                    MIN(quality_fee) AS quality_fee,
                    -- ← NEW
                    MIN(carrier_id::text)::uuid AS carrier_id,
                    MIN(carrier_name) AS carrier_name,
                    MIN(dispatch_at) AS dispatch_at,
                    MIN(delivery_status::text)::public.delivery_status AS delivery_status,
                    MIN(delivery_fee) AS delivery_fee,
                    -- Flatten all variety_groups arrays from every order row
                    -- for this produce into one combined jsonb array
                    (
                        SELECT jsonb_agg(grp)
                        FROM (
                                SELECT jsonb_array_elements(variety_groups) AS grp
                                FROM (
                                        /*
                                         * Step A — deduplicate to one row per
                                         * (match, order_id) before aggregating,
                                         * so each group is counted exactly once.
                                         */
                                        SELECT DISTINCT ON (offer_order_match_id, order_id) offer_order_match_id,
                                            order_id,
                                            variety_groups
                                        FROM items_enriched ie2
                                        WHERE ie2.offer_order_match_id = base.offer_order_match_id
                                            AND ie2.produce_id = base.produce_id
                                        ORDER BY offer_order_match_id,
                                            order_id,
                                            item_id
                                    ) deduped
                            ) expanded
                    ) AS all_variety_groups
                FROM (
                        -- Base: deduplicated rows used for grouping context
                        SELECT DISTINCT ON (offer_order_match_id, order_id) offer_order_match_id,
                            order_id,
                            produce_id,
                            produce_english_name,
                            produce_dialect_name,
                            is_any,
                            date_needed,
                            quality,
                            -- ← NEW
                            quality_fee,
                            -- ← NEW
                            carrier_id,
                            carrier_name,
                            dispatch_at,
                            delivery_status,
                            delivery_fee,
                            variety_groups,
                            produce_img_url,
                            item_id
                        FROM items_enriched
                        ORDER BY offer_order_match_id,
                            order_id,
                            item_id
                    ) base
                GROUP BY offer_order_match_id,
                    produce_id,
                    produce_img_url
            ) ie
        GROUP BY ie.offer_order_match_id
    ),
    /*
     * CTE 8 — final assembly.
     * Joins match headers to their order_items arrays and wraps everything
     * in the paginated response envelope.
     *
     * Response shape:
     *   {
     *     "orders": [
     *       {
     *         "offer_order_match_id": "uuid",
     *         "created_at":           "timestamptz",
     *         "is_paid":              bool,
     *         "payment_method":       "...",
     *         "is_active":            bool,
     *         "note":                 "text | null",   ← NEW
     *         "order_items": [
     *           {
     *             "produce_id":           "uuid",
     *             "produce_english_name": "...",
     *             "produce_dialect_name": "...",
     *             "produce_img_url":      "...",
     *             "quality":              "Saver|Regular|Select",   ← NEW
     *             "quality_fee":          0.05,                     ← NEW
     *             "variety_groups": [
     *               {
     *                 "group_id":       1,
     *                 "varieties":      [...],
     *                 "total_quantity": ...,
     *                 "total_price":    ...
     *               }
     *             ],
     *             "carrier_id":      "uuid",
     *             "carrier_name":    "...",
     *             "dispatch_at":     "timestamptz",
     *             "delivery_status": "...",
     *             "delivery_fee",     0.0
     *           }
     *         ]
     *       }
     *     ],
     *     "next_cursor": "timestamptz"
     *   }
     */
    final AS (
        SELECT jsonb_agg(
                jsonb_build_object(
                    'offer_order_match_id',
                    m.offer_order_match_id,
                    'created_at',
                    m.created_at,
                    'is_paid',
                    m.consumer_paid,
                    'payment_method',
                    m.consumer_payment_method,
                    'is_active',
                    m.is_active,
                    'note',
                    m.consumer_note,
                    'order_items',
                    COALESCE(opm.order_items_json, '[]'::jsonb)
                )
                ORDER BY m.created_at DESC
            ) AS data,
            MIN(m.created_at) AS next_cursor
        FROM matches m
            LEFT JOIN orders_per_match opm ON opm.offer_order_match_id = m.offer_order_match_id
    )
SELECT jsonb_build_object(
        'orders',
        COALESCE(data, '[]'::jsonb),
        'next_cursor',
        next_cursor
    )
FROM final;
$$;