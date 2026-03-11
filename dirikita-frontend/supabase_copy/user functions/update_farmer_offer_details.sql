-- ══════════════════════════════════════════════════════════════════════
-- FUNCTION: update_farmer_offer_details
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_farmer_offer_details(
        p_offer_id UUID,
        p_mode TEXT,
        -- 'delete' | 'activate' | 'update' | 'update_orders'
        p_update JSONB DEFAULT NULL,
        -- 'update' mode shape: { available_from?, available_to?, quantity? }
        -- quantity is a DELTA: negative = reduce, positive = add
        p_order_ids UUID [] DEFAULT NULL,
        -- 'update_orders' mode: list of oom_ids to update
        p_delivery_status TEXT DEFAULT NULL,
        -- 'update_orders' mode: new delivery_status (optional)
        p_dispatch_at TIMESTAMPTZ DEFAULT NULL -- 'update_orders' mode: new dispatch_at (optional)
    ) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_caller_uid UUID;
v_farmer_id TEXT;
v_offer public.farmer_offers %ROWTYPE;
v_variety_name TEXT;
v_can_delete BOOLEAN;
v_has_price_lock BOOLEAN;
v_delta_qty NUMERIC;
v_new_quantity NUMERIC;
v_new_remaining NUMERIC;
v_new_avail_from DATE;
v_new_avail_to DATE;
v_changed_qty BOOLEAN;
v_changed_from BOOLEAN;
v_changed_to BOOLEAN;
v_updates_left SMALLINT;
v_rows_updated INT;
BEGIN -- ── Auth ──────────────────────────────────────────────────────────
v_caller_uid := auth.uid();
IF v_caller_uid IS NULL THEN RAISE EXCEPTION 'Unauthorized: authentication required';
END IF;
SELECT farmer_id INTO v_farmer_id
FROM public.user_farmers
WHERE user_id = v_caller_uid
LIMIT 1;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'Unauthorized: no farmer profile for this user';
END IF;
-- ── Validate mode ─────────────────────────────────────────────────
IF p_mode NOT IN ('delete', 'activate', 'update', 'update_orders') THEN RAISE EXCEPTION 'Invalid mode "%". Use: delete, activate, update, or update_orders.',
p_mode;
END IF;
-- ── Fetch offer ───────────────────────────────────────────────────
SELECT * INTO v_offer
FROM public.farmer_offers
WHERE offer_id = p_offer_id
    AND farmer_id = v_farmer_id;
IF NOT FOUND THEN RAISE EXCEPTION 'Offer not found or does not belong to this farmer';
END IF;
-- ── Variety name ──────────────────────────────────────────────────
SELECT pv.variety_name INTO v_variety_name
FROM public.produce_varieties pv
WHERE pv.variety_id = v_offer.variety_id;
-- ── Block all actions (except update_orders) if available_to has passed ───
IF p_mode <> 'update_orders'
AND v_offer.available_to IS NOT NULL
AND NOW()::DATE > v_offer.available_to THEN RAISE EXCEPTION 'Offer "%s" has expired (available_to: %). No actions are allowed on expired offers.',
v_variety_name,
v_offer.available_to;
END IF;
-- ══════════════════════════════════════════════════════════════════
-- MODE: DELETE
-- ══════════════════════════════════════════════════════════════════
IF p_mode = 'delete' THEN v_can_delete := (
    v_offer.quantity IS NOT DISTINCT
    FROM v_offer.remaining_quantity
        AND (
            v_offer.total_price_lock_credit IS NULL
            OR v_offer.remaining_price_lock_credit IS NOT DISTINCT
            FROM v_offer.total_price_lock_credit
        )
);
v_has_price_lock := (
    v_offer.fpls_id IS NOT NULL
    AND v_offer.total_price_lock_credit IS NOT NULL
    AND v_offer.total_price_lock_credit > 0
);
IF v_can_delete THEN IF v_has_price_lock THEN
UPDATE public.farmer_price_lock_subscriptions
SET remaining_credits = remaining_credits + v_offer.total_price_lock_credit
WHERE fpls_id = v_offer.fpls_id;
END IF;
DELETE FROM public.farmer_offers
WHERE offer_id = p_offer_id;
IF v_has_price_lock THEN RETURN format(
    'Offer "%s" has been deleted and your price lock credit of %s has been returned to your subscription.',
    v_variety_name,
    v_offer.total_price_lock_credit
);
ELSE RETURN format(
    'Offer "%s" has been successfully deleted.',
    v_variety_name
);
END IF;
ELSE
UPDATE public.farmer_offers
SET is_active = FALSE,
    updated_at = NOW()
WHERE offer_id = p_offer_id;
RETURN format(
    'Offer "%s" has been deactivated. Some quantity has already been allocated, so hard deletion is not allowed. ' || 'Price lock credit is not returned as it has already been utilized. ' || 'Reactivate this offer to make unused credit work for you again.',
    v_variety_name
);
END IF;
-- ══════════════════════════════════════════════════════════════════
-- MODE: ACTIVATE
-- ══════════════════════════════════════════════════════════════════
ELSIF p_mode = 'activate' THEN IF v_offer.is_active THEN RETURN format(
    'Offer "%s" is already active. No changes made.',
    v_variety_name
);
END IF;
-- ── Block reactivation if any quantity has been allocated ─────────
IF COALESCE(v_offer.remaining_quantity, 0) <> COALESCE(v_offer.quantity, 0) THEN RAISE EXCEPTION 'Offer "%" cannot be reactivated because % units have already been allocated to orders. Reactivation is only allowed when no quantity has been allocated (remaining = total).',
v_variety_name,
(
    COALESCE(v_offer.quantity, 0) - COALESCE(v_offer.remaining_quantity, 0)
);
END IF;
-- ── Check if price lock subscription has expired ──────────────
IF v_offer.fpls_id IS NOT NULL THEN IF EXISTS (
    SELECT 1
    FROM public.farmer_price_lock_subscriptions
    WHERE fpls_id = v_offer.fpls_id
        AND ends_at IS NOT NULL
        AND NOW() >= ends_at
) THEN RAISE EXCEPTION 'Offer "%" cannot be reactivated. The price lock subscription has expired. Please renew your price lock subscription first.',
v_variety_name;
END IF;
END IF;
-- ── Refund price_lock_used on farmer_plan_subscriptions ──────────
-- Since remaining_quantity == quantity (verified above), no credit was consumed.
-- Return the price_lock_credit used by this offer back to the active fps.
IF v_offer.fpls_id IS NOT NULL
AND v_offer.total_price_lock_credit IS NOT NULL
AND v_offer.total_price_lock_credit > 0 THEN
UPDATE public.farmer_plan_subscriptions fps
SET price_lock_used = GREATEST(
        0,
        fps.price_lock_used - v_offer.total_price_lock_credit
    ),
    updated_at = NOW()
WHERE fps.farmer_id = v_farmer_id
    AND fps.status = 'active'
    AND fps.fps_id IN (
        SELECT fps2.fps_id
        FROM public.farmer_plan_subscriptions fps2
            JOIN public.farmer_plan_configs fpc ON fpc.fpc_id = fps2.plan_config_id
        WHERE fps2.farmer_id = v_farmer_id
            AND fps2.status = 'active'
        LIMIT 1
    );
END IF;
UPDATE public.farmer_offers
SET is_active = TRUE,
    updated_at = NOW()
WHERE offer_id = p_offer_id;
RETURN format(
    'Offer "%s" has been reactivated with %s units remaining. It is now visible to buyers.',
    v_variety_name,
    v_offer.remaining_quantity
);
-- ══════════════════════════════════════════════════════════════════
-- MODE: UPDATE
-- ══════════════════════════════════════════════════════════════════
ELSIF p_mode = 'update' THEN IF p_update IS NULL THEN RAISE EXCEPTION 'p_update payload is required for update mode.';
END IF;
-- ── Check update limit ────────────────────────────────────────
IF v_offer.update_count <= 0 THEN RAISE EXCEPTION 'Offer "%" has reached its update limit. No further updates are allowed.',
v_variety_name;
END IF;
-- ── Quantity delta logic ──────────────────────────────────────
IF p_update ? 'quantity' THEN -- Block quantity update if price lock is active
IF COALESCE(v_offer.is_price_locked, FALSE) THEN RAISE EXCEPTION 'Quantity update is disabled for offer "%" because price lock is active. Delete this offer and create new one with out price lock.',
v_variety_name;
END IF;
v_delta_qty := (p_update->>'quantity')::NUMERIC;
IF v_delta_qty = 0 THEN RAISE EXCEPTION 'Quantity delta cannot be 0. Pass a positive value to add or a negative value to reduce.';
END IF;
v_new_quantity := COALESCE(v_offer.quantity, 0) + v_delta_qty;
v_new_remaining := COALESCE(v_offer.remaining_quantity, 0) + v_delta_qty;
IF v_new_quantity < 0 THEN RAISE EXCEPTION 'Invalid quantity adjustment. Reducing by % would bring total quantity to %, which is not allowed.',
ABS(v_delta_qty),
v_new_quantity;
END IF;
IF v_new_remaining < 0 THEN RAISE EXCEPTION 'Invalid quantity adjustment. Reducing by % would bring remaining quantity to %, which is below 0. Only % units are available to reduce (allocated: %).',
ABS(v_delta_qty),
v_new_remaining,
v_offer.remaining_quantity,
(v_offer.quantity - v_offer.remaining_quantity);
END IF;
ELSE v_new_quantity := v_offer.quantity;
v_new_remaining := v_offer.remaining_quantity;
END IF;
-- ── Block available_from edit if it has already passed ────────────
IF p_update ? 'available_from' THEN IF v_offer.available_from IS NOT NULL
AND NOW()::DATE >= v_offer.available_from THEN RAISE EXCEPTION 'available_from cannot be changed for offer "%" because the availability period has already started (%).',
v_variety_name,
v_offer.available_from;
END IF;
END IF;
-- ── Date validation ───────────────────────────────────────────
v_new_avail_from := COALESCE(
    (p_update->>'available_from')::DATE,
    v_offer.available_from
);
v_new_avail_to := COALESCE(
    (p_update->>'available_to')::DATE,
    v_offer.available_to
);
IF v_new_avail_from IS NOT NULL
AND v_new_avail_to IS NOT NULL
AND v_new_avail_from > v_new_avail_to THEN RAISE EXCEPTION 'available_from (%) cannot be later than available_to (%).',
v_new_avail_from,
v_new_avail_to;
END IF;
-- ── Apply update ──────────────────────────────────────────────
UPDATE public.farmer_offers
SET quantity = v_new_quantity,
    remaining_quantity = v_new_remaining,
    available_from = v_new_avail_from,
    available_to = v_new_avail_to,
    update_count = update_count - 1,
    updated_at = NOW()
WHERE offer_id = p_offer_id;
-- remaining count after decrement
v_updates_left := v_offer.update_count - 1;
-- ── Specific message per what actually changed ────────────────
v_changed_qty := (p_update ? 'quantity');
v_changed_from := (p_update ? 'available_from');
v_changed_to := (p_update ? 'available_to');
IF v_changed_qty
AND NOT v_changed_from
AND NOT v_changed_to THEN RETURN format(
    'Offer "%s" quantity %s by %s. New total: %s, remaining: %s. Updates remaining: %s.',
    v_variety_name,
    CASE
        WHEN v_delta_qty > 0 THEN 'increased'
        ELSE 'reduced'
    END,
    ABS(v_delta_qty),
    v_new_quantity,
    v_new_remaining,
    v_updates_left
);
ELSIF (
    v_changed_from
    OR v_changed_to
)
AND NOT v_changed_qty THEN RETURN format(
    'Offer "%s" schedule updated. Available: %s → %s. Updates remaining: %s.',
    v_variety_name,
    COALESCE(v_new_avail_from::TEXT, 'not set'),
    COALESCE(v_new_avail_to::TEXT, 'not set'),
    v_updates_left
);
ELSE RETURN format(
    'Offer "%s" updated. Quantity %s by %s (total: %s, remaining: %s). Schedule: %s → %s. Updates remaining: %s.',
    v_variety_name,
    CASE
        WHEN v_delta_qty > 0 THEN 'increased'
        ELSE 'reduced'
    END,
    ABS(v_delta_qty),
    v_new_quantity,
    v_new_remaining,
    COALESCE(v_new_avail_from::TEXT, 'not set'),
    COALESCE(v_new_avail_to::TEXT, 'not set'),
    v_updates_left
);
END IF;
-- ══════════════════════════════════════════════════════════════════
-- MODE: UPDATE_ORDERS
-- ══════════════════════════════════════════════════════════════════
ELSIF p_mode = 'update_orders' THEN IF p_order_ids IS NULL
OR array_length(p_order_ids, 1) IS NULL THEN RAISE EXCEPTION 'p_order_ids must be a non-empty array for update_orders mode.';
END IF;
IF p_delivery_status IS NULL
AND p_dispatch_at IS NULL THEN RAISE EXCEPTION 'At least one of p_delivery_status or p_dispatch_at must be provided for update_orders mode.';
END IF;
-- Verify all foa_ids belong to this offer
-- p_order_ids contains foa_id values (the allocation ID carried by the Dart model)
IF EXISTS (
    SELECT 1
    FROM unnest(p_order_ids) AS fid
    WHERE NOT EXISTS (
            SELECT 1
            FROM public.farmer_offers_allocations foa
            WHERE foa.foa_id = fid
                AND foa.offer_id = p_offer_id
        )
) THEN RAISE EXCEPTION 'One or more order IDs do not belong to offer %.',
p_offer_id;
END IF;
-- Apply the update via foa_id
UPDATE public.offer_order_match
SET delivery_status = COALESCE(p_delivery_status::public.delivery_status, delivery_status),
    dispatch_at = COALESCE(p_dispatch_at, dispatch_at),
    updated_at = NOW()
WHERE foa_id = ANY(p_order_ids);
GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
IF p_delivery_status IS NOT NULL
AND p_dispatch_at IS NOT NULL THEN RETURN format(
    '%s order(s) updated: delivery status set to "%s" and dispatch date set to %s.',
    v_rows_updated,
    p_delivery_status,
    p_dispatch_at::DATE
);
ELSIF p_delivery_status IS NOT NULL THEN RETURN format(
    '%s order(s) updated: delivery status set to "%s".',
    v_rows_updated,
    p_delivery_status
);
ELSE RETURN format(
    '%s order(s) updated: dispatch date set to %s.',
    v_rows_updated,
    p_dispatch_at::DATE
);
END IF;
END IF;
END;
$$;