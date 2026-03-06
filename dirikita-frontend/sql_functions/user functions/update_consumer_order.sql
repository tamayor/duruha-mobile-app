-- ============================================================
-- update_consumer_order
-- ============================================================
--
-- Modes:
--   p_mode = 'cancel' → mark oom rows as CANCELLED, restore stock + credits, keep history
--   p_mode = 'delete' → hard delete all records, restore stock + credits
--
-- Scope:
--   p_order_id alone      → affects entire order (all cops → covgs → covs → foas → ooms)
--   p_specific_oom_id set → affects only that single oom row (and its linked foa/cov)
--
-- Credit restoration (both modes, only when foa_id is set):
--   farmer_offers.remaining_quantity          += foa.quantity
--   farmer_price_lock_subscriptions.credit    += foa.price_lock × qty   (if fpls_id set)
--   consumer_price_lock_subscriptions.credits += cov.price_lock × qty   (if covg.cpls_id set)
--
-- Returns:
--   { success, mode, order_id, scope, affected, message }
-- ============================================================
CREATE OR REPLACE FUNCTION update_consumer_order(
        p_order_id uuid,
        p_mode text default 'cancel',
        p_specific_oom_id uuid default null
    ) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_auth_uid uuid;
v_consumer_id text;
v_rec record;
v_affected integer := 0;
BEGIN -- ── 1. Auth & Ownership ──────────────────────────────────
v_auth_uid := auth.uid();
SELECT uc.consumer_id INTO v_consumer_id
FROM user_consumers uc
    JOIN users u ON u.id = uc.user_id
WHERE u.id = v_auth_uid
LIMIT 1;
IF v_consumer_id IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING errcode = 'P0001';
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM consumer_orders
    WHERE order_id = p_order_id
        AND consumer_id = v_consumer_id
) THEN RAISE EXCEPTION 'Order not found or access denied' USING errcode = 'P0002';
END IF;
-- ── 2. Guard: Point of No Return ─────────────────────────
IF EXISTS (
    SELECT 1
    FROM offer_order_match oom
        JOIN consumer_orders_variety cov ON cov.cov_id = oom.cov_id
        JOIN consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
        JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
    WHERE cop.order_id = p_order_id
        AND (
            p_specific_oom_id IS NULL
            OR oom.oom_id = p_specific_oom_id
        )
        AND oom.delivery_status IN (
            'QC_PASSED',
            'DISPATCHED',
            'IN_TRANSIT_TO_HUB',
            'ARRIVED_AT_HUB',
            'SORTING',
            'OUT_FOR_DELIVERY',
            'ARRIVED',
            'DELIVERED'
        )
) THEN RAISE EXCEPTION 'Action denied: Items are already processed or in transit.' USING errcode = 'P0004';
END IF;
-- ── 3. Main Update Loop ──────────────────────────────────
-- LEFT JOIN foa so unallocated oom rows (foa_id IS NULL) are included
FOR v_rec IN
SELECT oom.oom_id,
    oom.cov_id,
    oom.foa_id,
    foa.offer_id,
    foa.quantity AS foa_qty,
    foa.fpls_id,
    foa.price_lock AS f_plock,
    cov.price_lock AS c_plock,
    covg.cpls_id
FROM offer_order_match oom
    JOIN consumer_orders_variety cov ON cov.cov_id = oom.cov_id
    JOIN consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
    JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
    LEFT JOIN farmer_offers_allocations foa ON foa.foa_id = oom.foa_id -- LEFT: foa_id may be null
WHERE cop.order_id = p_order_id
    AND (
        p_specific_oom_id IS NULL
        OR oom.oom_id = p_specific_oom_id
    )
    AND oom.delivery_status IN (
        'PENDING',
        'ACCEPTED',
        'PREPARING',
        'READY_FOR_QC'
    ) LOOP -- Only restore stock/credits when actually allocated (foa_id present)
    IF v_rec.foa_id IS NOT NULL THEN -- Restore Farmer Stock
UPDATE farmer_offers
SET remaining_quantity = remaining_quantity + v_rec.foa_qty,
    updated_at = now()
WHERE offer_id = v_rec.offer_id;
-- Restore Farmer Credits
IF v_rec.fpls_id IS NOT NULL THEN
UPDATE farmer_price_lock_subscriptions
SET remaining_price_lock_credit = remaining_price_lock_credit + (v_rec.f_plock * v_rec.foa_qty)
WHERE fpls_id = v_rec.fpls_id;
END IF;
-- Restore Consumer Credits
IF v_rec.cpls_id IS NOT NULL THEN
UPDATE consumer_price_lock_subscriptions
SET remaining_credits = remaining_credits + (v_rec.c_plock * v_rec.foa_qty),
    updated_at = now()
WHERE cpls_id = v_rec.cpls_id;
END IF;
END IF;
-- Mode Selection
IF p_mode = 'cancel' THEN
UPDATE offer_order_match
SET delivery_status = 'CANCELLED',
    updated_at = now()
WHERE oom_id = v_rec.oom_id;
-- Deselect variety if no other non-cancelled oom exists for this cov
UPDATE consumer_orders_variety
SET is_selected = false
WHERE cov_id = v_rec.cov_id
    AND NOT EXISTS (
        SELECT 1
        FROM offer_order_match
        WHERE cov_id = v_rec.cov_id
            AND delivery_status != 'CANCELLED'
    );
ELSE
DELETE FROM offer_order_match
WHERE oom_id = v_rec.oom_id;
-- Only delete foa if it existed
IF v_rec.foa_id IS NOT NULL THEN
DELETE FROM farmer_offers_allocations
WHERE foa_id = v_rec.foa_id;
END IF;
END IF;
v_affected := v_affected + 1;
END LOOP;
-- ── 4. Verify & Finalize ─────────────────────────────────
IF v_affected = 0 THEN RAISE EXCEPTION 'No eligible items found to %.',
p_mode USING errcode = 'P0005';
END IF;
-- Cascade cleanup for Delete Mode (entire order)
IF p_mode = 'delete'
AND p_specific_oom_id IS NULL THEN
DELETE FROM consumer_orders_produce
WHERE order_id = p_order_id;
DELETE FROM consumer_orders
WHERE order_id = p_order_id;
END IF;
-- Auto-deactivate order if no active (non-cancelled) oom rows remain
UPDATE consumer_orders
SET is_active = false,
    updated_at = now()
WHERE order_id = p_order_id
    AND NOT EXISTS (
        SELECT 1
        FROM offer_order_match oom
            JOIN consumer_orders_variety cov ON cov.cov_id = oom.cov_id
            JOIN consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
            JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
        WHERE cop.order_id = p_order_id
            AND oom.delivery_status != 'CANCELLED'
    );
RETURN jsonb_build_object(
    'success',
    true,
    'mode',
    p_mode,
    'affected',
    v_affected,
    'message',
    'Successfully ' || p_mode || 'ed ' || v_affected || ' item(s). Stock and credits restored.'
);
EXCEPTION
WHEN OTHERS THEN RETURN jsonb_build_object(
    'success',
    false,
    'message',
    sqlerrm,
    'code',
    sqlstate
);
END;
$$;