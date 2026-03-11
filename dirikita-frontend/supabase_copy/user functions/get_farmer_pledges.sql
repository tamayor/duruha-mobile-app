CREATE OR REPLACE FUNCTION get_farmer_pledges(
        p_limit INT DEFAULT 20,
        p_offset INT DEFAULT 0
    ) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSONB;
v_farmer_id TEXT;
BEGIN
/*
 Resolve the calling user → farmer_id via user_farmers.
 auth.uid() returns the UUID of the authenticated Supabase user.
 */
SELECT farmer_id INTO v_farmer_id
FROM public.user_farmers
WHERE user_id = auth.uid()
LIMIT 1;
IF v_farmer_id IS NULL THEN RETURN jsonb_build_object(
    'error',
    'farmer_not_found',
    'message',
    'No farmer profile linked to the current user.'
);
END IF;
/*
 Chain:
 farmer_offers_allocations (foa)  – offer_id IS NULL  → pledge rows
 └─ consumer_orders_variety (cov)         via foa.cov_id
 ├─ selection_type = 'PLEDGE'
 └─ consumer_orders_variety_group (covg) via cov.covg_id
 ├─ date_needed, form
 └─ consumer_orders_produce (cop)    via covg.cop_id
 ├─ note
 └─ produce (p)                  via cop.produce_id
 └─ produce_varieties (pv)   via cov.variety_id
 └─ offer_order_match (oom)                  via foa.foa_id  (optional)
 └─ user_carriers (uc)                   via oom.carrier_id
 └─ consumer_address (ca)                via oom.consumer_address → users_addresses
 └─ farmer_address  (fa)                 via oom.farmer_address   → users_addresses
 */
WITH pledge_rows AS (
    SELECT -- produce identity
        p.id AS produce_id,
        p.english_name AS produce_english_name,
        p.local_name AS produce_local_name,
        pv.variety_name,
        -- group-level fields
        covg.form AS produce_form,
        covg.date_needed,
        -- order note
        cop.note,
        -- allocation fields
        foa.foa_id,
        foa.cov_id,
        foa.is_paid,
        foa.final_price,
        foa.ftd_price,
        foa.price_lock,
        foa.fps_id,
        foa.payment_method,
        foa.quantity,
        -- delivery / carrier (NULL when no oom yet)
        oom.delivery_status,
        oom.dispatch_at,
        oom.carrier_id,
        uc.name AS carrier_name,
        -- address UUIDs to resolve
        oom.consumer_address AS consumer_address_id,
        oom.farmer_address AS farmer_address_id
    FROM public.farmer_offers_allocations foa
        JOIN public.consumer_orders_variety cov ON cov.cov_id = foa.cov_id
        AND cov.selection_type = 'PLEDGE' -- FIX: was 'PLEDGED'
        JOIN public.consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
        JOIN public.consumer_orders_produce cop ON cop.cop_id = covg.cop_id
        JOIN public.produce p ON p.id = cop.produce_id
        LEFT JOIN public.produce_varieties pv ON pv.variety_id = cov.variety_id
        LEFT JOIN public.offer_order_match oom ON oom.foa_id = foa.foa_id
        LEFT JOIN public.user_carriers uc ON uc.carrier_id = oom.carrier_id
    WHERE foa.farmer_id = v_farmer_id
        AND foa.offer_id IS NULL -- FIX: pledges only (was missing)
),
/*  Resolve all address UUIDs in a single pass  */
resolved_addresses AS (
    SELECT a.address_id,
        a.address_line_1,
        a.address_line_2,
        a.city,
        a.province,
        a.landmark,
        a.region,
        a.postal_code,
        a.country
    FROM public.users_addresses a
    WHERE a.address_id IN (
            SELECT consumer_address_id
            FROM pledge_rows
            WHERE consumer_address_id IS NOT NULL
            UNION
            SELECT farmer_address_id
            FROM pledge_rows
            WHERE farmer_address_id IS NOT NULL
        )
),
/*  Build one schedule-entry JSON object per allocation row  */
schedules AS (
    SELECT pr.produce_id,
        pr.produce_english_name,
        pr.produce_local_name,
        pr.variety_name,
        pr.produce_form,
        jsonb_build_object(
            'foa_id',
            pr.foa_id,
            'date_needed',
            pr.date_needed,
            'delivery_status',
            pr.delivery_status,
            'dispatch_at',
            pr.dispatch_at,
            'carrier_id',
            pr.carrier_id,
            'carrier_name',
            pr.carrier_name,
            'is_paid',
            pr.is_paid,
            'final_price',
            pr.final_price,
            'ftd_price',
            pr.ftd_price,
            'price_lock',
            pr.price_lock,
            'fps_id',
            pr.fps_id,
            'payment_method',
            pr.payment_method,
            'quantity',
            pr.quantity,
            'note',
            pr.note,
            'consumer_address',
            CASE
                WHEN ca.address_id IS NOT NULL THEN jsonb_build_object(
                    'address_id',
                    ca.address_id,
                    'address_line_1',
                    ca.address_line_1,
                    'address_line_2',
                    ca.address_line_2,
                    'city',
                    ca.city,
                    'province',
                    ca.province,
                    'landmark',
                    ca.landmark,
                    'region',
                    ca.region,
                    'postal_code',
                    ca.postal_code,
                    'country',
                    ca.country
                )
                ELSE NULL
            END,
            'farmer_address',
            CASE
                WHEN fa.address_id IS NOT NULL THEN jsonb_build_object(
                    'address_id',
                    fa.address_id,
                    'address_line_1',
                    fa.address_line_1,
                    'address_line_2',
                    fa.address_line_2,
                    'city',
                    fa.city,
                    'province',
                    fa.province,
                    'landmark',
                    fa.landmark,
                    'region',
                    fa.region,
                    'postal_code',
                    fa.postal_code,
                    'country',
                    fa.country
                )
                ELSE NULL
            END
        ) AS schedule_entry
    FROM pledge_rows pr
        LEFT JOIN resolved_addresses ca ON ca.address_id = pr.consumer_address_id
        LEFT JOIN resolved_addresses fa ON fa.address_id = pr.farmer_address_id
),
/*  Group schedule entries per produce × variety × form (no pagination yet)  */
grouped_all AS (
    SELECT produce_id,
        produce_english_name,
        produce_local_name,
        variety_name,
        produce_form,
        jsonb_agg(
            schedule_entry
            ORDER BY (schedule_entry->>'date_needed')
        ) AS pledges_schedule
    FROM schedules
    GROUP BY produce_id,
        produce_english_name,
        produce_local_name,
        variety_name,
        produce_form
),
/*  Apply pagination AFTER grouping so total count stays accurate  */
-- FIX: was inside grouped CTE
grouped_page AS (
    SELECT *
    FROM grouped_all
    ORDER BY produce_english_name,
        variety_name,
        produce_form
    LIMIT p_limit OFFSET p_offset
)
SELECT jsonb_build_object(
        'pledges',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'produce_id',
                    g.produce_id,
                    'produce_english_name',
                    g.produce_english_name,
                    'produce_local_name',
                    g.produce_local_name,
                    'variety_name',
                    g.variety_name,
                    'produce_form',
                    g.produce_form,
                    'pledges_schedule',
                    g.pledges_schedule
                )
            ),
            '[]'::jsonb
        ),
        'pagination',
        jsonb_build_object(
            'limit',
            p_limit,
            'offset',
            p_offset,
            'total',
            (
                SELECT COUNT(*)
                FROM grouped_all
            ) -- FIX: total across all pages
        )
    ) INTO v_result
FROM grouped_page g;
RETURN v_result;
END;
$$;
-- ─── Example call ─────────────────────────────────────────────────────────────
-- Must be called as an authenticated Supabase user (auth.uid() is set by JWT).
-- SELECT get_farmer_pledges();        -- page 1, default 20 rows
-- SELECT get_farmer_pledges(20, 20);  -- page 2CREATE OR REPLACE FUNCTION get_farmer_pledges(
p_limit INT DEFAULT 20,
p_offset INT DEFAULT 0
) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_result JSONB;
v_farmer_id TEXT;
v_dialect_id UUID;
BEGIN
/*
 Resolve the calling user → farmer_id and dialect_id.
 auth.uid() returns the UUID of the authenticated Supabase user.
 */
SELECT uf.farmer_id,
    d.id INTO v_farmer_id,
    v_dialect_id
FROM public.user_farmers uf
    JOIN public.users u ON u.id = uf.user_id
    LEFT JOIN public.dialects d ON d.dialect_name = u.dialect [1]
WHERE uf.user_id = auth.uid()
LIMIT 1;
IF v_farmer_id IS NULL THEN RETURN jsonb_build_object(
    'error',
    'farmer_not_found',
    'message',
    'No farmer profile linked to the current user.'
);
END IF;
/*
 Chain:
 farmer_offers_allocations (foa)  – offer_id IS NULL  → pledge rows
 └─ consumer_orders_variety (cov)         via foa.cov_id
 ├─ selection_type = 'PLEDGED'
 └─ consumer_orders_variety_group (covg) via cov.covg_id
 ├─ date_needed, form
 └─ consumer_orders_produce (cop)    via covg.cop_id
 ├─ note
 └─ produce (p)                  via cop.produce_id
 ├─ produce_dialects (pd)     dialect-aware local_name
 └─ produce_varieties (pv)   via cov.variety_id
 └─ offer_order_match (oom)                  via foa.foa_id  (optional)
 └─ user_carriers (uc)                   via oom.carrier_id
 └─ consumer_address (ca)                via oom.consumer_address → users_addresses
 └─ farmer_address  (fa)                 via oom.farmer_address   → users_addresses
 */
WITH pledge_rows AS (
    SELECT -- produce identity
        p.id AS produce_id,
        p.english_name AS produce_english_name,
        -- dialect-aware local name:
        --   priority 1 → user's own dialect
        --   priority 2 → any other dialect (first alphabetically)
        --   priority 3 → NULL (no dialect entry at all)
        (
            SELECT pd.local_name
            FROM public.produce_dialects pd
            WHERE pd.produce_id = p.id
            ORDER BY (pd.dialect_id = v_dialect_id) DESC,
                pd.local_name ASC
            LIMIT 1
        ) AS produce_local_name,
        pv.variety_name,
        -- group-level fields
        covg.form AS produce_form,
        covg.date_needed,
        -- order note
        cop.note,
        -- allocation fields
        foa.foa_id,
        foa.cov_id,
        foa.is_paid,
        foa.final_price,
        foa.ftd_price,
        foa.price_lock,
        foa.fps_id,
        foa.payment_method,
        foa.quantity,
        -- delivery / carrier (NULL when no oom yet)
        oom.delivery_status,
        oom.dispatch_at,
        oom.carrier_id,
        uc.name AS carrier_name,
        -- address UUIDs to resolve
        oom.consumer_address AS consumer_address_id,
        oom.farmer_address AS farmer_address_id
    FROM public.farmer_offers_allocations foa
        JOIN public.consumer_orders_variety cov ON cov.cov_id = foa.cov_id
        AND cov.selection_type = 'PLEDGED'
        JOIN public.consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
        JOIN public.consumer_orders_produce cop ON cop.cop_id = covg.cop_id
        JOIN public.produce p ON p.id = cop.produce_id
        LEFT JOIN public.produce_varieties pv ON pv.variety_id = cov.variety_id
        LEFT JOIN public.offer_order_match oom ON oom.foa_id = foa.foa_id
        LEFT JOIN public.user_carriers uc ON uc.carrier_id = oom.carrier_id
    WHERE foa.farmer_id = v_farmer_id
        AND foa.offer_id IS NULL -- FIX: pledges only (was missing)
),
/*  Resolve all address UUIDs in a single pass  */
resolved_addresses AS (
    SELECT a.address_id,
        a.address_line_1,
        a.address_line_2,
        a.city,
        a.province,
        a.landmark,
        a.region,
        a.postal_code,
        a.country
    FROM public.users_addresses a
    WHERE a.address_id IN (
            SELECT consumer_address_id
            FROM pledge_rows
            WHERE consumer_address_id IS NOT NULL
            UNION
            SELECT farmer_address_id
            FROM pledge_rows
            WHERE farmer_address_id IS NOT NULL
        )
),
/*  Build one schedule-entry JSON object per allocation row  */
schedules AS (
    SELECT pr.produce_id,
        pr.produce_english_name,
        pr.produce_local_name,
        pr.variety_name,
        pr.produce_form,
        jsonb_build_object(
            'foa_id',
            pr.foa_id,
            'date_needed',
            pr.date_needed,
            'delivery_status',
            pr.delivery_status,
            'dispatch_at',
            pr.dispatch_at,
            'carrier_id',
            pr.carrier_id,
            'carrier_name',
            pr.carrier_name,
            'is_paid',
            pr.is_paid,
            'final_price',
            pr.final_price,
            'ftd_price',
            pr.ftd_price,
            'price_lock',
            pr.price_lock,
            'fps_id',
            pr.fps_id,
            'payment_method',
            pr.payment_method,
            'quantity',
            pr.quantity,
            'note',
            pr.note,
            'consumer_address',
            CASE
                WHEN ca.address_id IS NOT NULL THEN jsonb_build_object(
                    'address_id',
                    ca.address_id,
                    'address_line_1',
                    ca.address_line_1,
                    'address_line_2',
                    ca.address_line_2,
                    'city',
                    ca.city,
                    'province',
                    ca.province,
                    'landmark',
                    ca.landmark,
                    'region',
                    ca.region,
                    'postal_code',
                    ca.postal_code,
                    'country',
                    ca.country
                )
                ELSE NULL
            END,
            'farmer_address',
            CASE
                WHEN fa.address_id IS NOT NULL THEN jsonb_build_object(
                    'address_id',
                    fa.address_id,
                    'address_line_1',
                    fa.address_line_1,
                    'address_line_2',
                    fa.address_line_2,
                    'city',
                    fa.city,
                    'province',
                    fa.province,
                    'landmark',
                    fa.landmark,
                    'region',
                    fa.region,
                    'postal_code',
                    fa.postal_code,
                    'country',
                    fa.country
                )
                ELSE NULL
            END
        ) AS schedule_entry
    FROM pledge_rows pr
        LEFT JOIN resolved_addresses ca ON ca.address_id = pr.consumer_address_id
        LEFT JOIN resolved_addresses fa ON fa.address_id = pr.farmer_address_id
),
/*  Group schedule entries per produce × variety × form (no pagination yet)  */
grouped_all AS (
    SELECT produce_id,
        produce_english_name,
        produce_local_name,
        variety_name,
        produce_form,
        jsonb_agg(
            schedule_entry
            ORDER BY (schedule_entry->>'date_needed')
        ) AS pledges_schedule
    FROM schedules
    GROUP BY produce_id,
        produce_english_name,
        produce_local_name,
        variety_name,
        produce_form
),
/*  Apply pagination AFTER grouping so total count stays accurate  */
-- FIX: was inside grouped CTE
grouped_page AS (
    SELECT *
    FROM grouped_all
    ORDER BY produce_english_name,
        variety_name,
        produce_form
    LIMIT p_limit OFFSET p_offset
)
SELECT jsonb_build_object(
        'pledges',
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'produce_id',
                    g.produce_id,
                    'produce_english_name',
                    g.produce_english_name,
                    'produce_local_name',
                    g.produce_local_name,
                    'variety_name',
                    g.variety_name,
                    'produce_form',
                    g.produce_form,
                    'pledges_schedule',
                    g.pledges_schedule
                )
            ),
            '[]'::jsonb
        ),
        'pagination',
        jsonb_build_object(
            'limit',
            p_limit,
            'offset',
            p_offset,
            'total',
            (
                SELECT COUNT(*)
                FROM grouped_all
            ) -- FIX: total across all pages
        )
    ) INTO v_result
FROM grouped_page g;
RETURN v_result;
END;
$$;
-- ─── Example call ─────────────────────────────────────────────────────────────
-- Must be called as an authenticated Supabase user (auth.uid() is set by JWT).
-- SELECT get_farmer_pledges();        -- page 1, default 20 rows
-- SELECT get_farmer_pledges(20, 20);  -- page 2