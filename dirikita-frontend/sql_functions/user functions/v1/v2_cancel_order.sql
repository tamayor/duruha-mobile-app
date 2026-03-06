-- =============================================================
-- FILE: v2_cancel_order.sql
-- =============================================================
-- PURPOSE:
-- Safely cancels a consumer order and returns committed stock
-- back to the corresponding farmer_offers.
--
-- PARAMETERS:
-- p_offer_order_match_id : UUID of the order group
-- p_consumer_id          : UUID of the consumer to ensure ownership check
--
-- RETURNS: boolean (true if successful)
-- =============================================================
CREATE OR REPLACE FUNCTION public.cancel_consumer_order(
        p_offer_order_match_id UUID,
        p_consumer_id UUID
    ) RETURNS boolean AS $$
DECLARE v_match_exists boolean;
v_order_status text;
item_rec RECORD;
BEGIN -- 1. Ensure the match belongs to the given consumer
SELECT EXISTS (
        SELECT 1
        FROM public.offer_order_match
        WHERE id = p_offer_order_match_id
            AND consumer_id = p_consumer_id
    ) INTO v_match_exists;
IF NOT v_match_exists THEN RAISE EXCEPTION 'Order match % for consumer % not found',
p_offer_order_match_id,
p_consumer_id;
END IF;
-- 2. Validate current status to prevent cancellation of completed/shipped orders
-- For safety, ensure all items in this match are still PENDING or ACCEPTED
-- If any item is in transit, we cannot safely cancel the entire match.
IF EXISTS (
    SELECT 1
    FROM public.offer_order_match_items oomi
    WHERE oomi.offer_order_match_id = p_offer_order_match_id
        AND oomi.delivery_status NOT IN ('PENDING', 'ACCEPTED')
) THEN RAISE EXCEPTION 'Cannot cancel order % because some items are already being processed or shipped',
p_offer_order_match_id;
END IF;
-- 3. Return stock to farmer offers
FOR item_rec IN
SELECT offer_id,
    quantity
FROM public.offer_order_match_items
WHERE offer_order_match_id = p_offer_order_match_id LOOP -- Revert the quantity
UPDATE public.farmer_offers
SET remaining_quantity = remaining_quantity + item_rec.quantity,
    is_active = true -- Reactivate the offer if it was zeroed out
WHERE offer_id = item_rec.offer_id;
END LOOP;
-- 4. Mark match items as CANCELLED
UPDATE public.offer_order_match_items
SET delivery_status = 'CANCELLED',
    updated_at = NOW()
WHERE offer_order_match_id = p_offer_order_match_id;
-- 5. Cascade to consumer_orders or any other high level statuses if needed.
-- (Assuming 'is_active' boolean manages high level active state)
UPDATE public.offer_order_match
SET is_active = false,
    updated_at = NOW()
WHERE id = p_offer_order_match_id;
RETURN true;
EXCEPTION
WHEN OTHERS THEN RAISE;
END;
$$ LANGUAGE plpgsql;