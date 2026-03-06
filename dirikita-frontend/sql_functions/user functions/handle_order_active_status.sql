-- ============================================================
-- Function: handle_order_active_status
-- Purpose: Automatically sets consumer_orders.is_active to FALSE
--          when all items are finalized (Delivered & Paid, or Cancelled).
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_order_active_status() RETURNS TRIGGER AS $$
DECLARE v_order_id UUID;
v_still_pending BOOLEAN;
BEGIN -- 1. Identify the root Order ID.
-- Since the trigger runs on offer_order_match, we must join up through 
-- Varieties and Produce to find the parent Order entry.
SELECT cop.order_id INTO v_order_id
FROM public.offer_order_match oom
    JOIN public.consumer_orders_variety cov ON cov.cov_id = oom.cov_id
    JOIN public.consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
    JOIN public.consumer_orders_produce cop ON cop.cop_id = covg.cop_id
WHERE oom.oom_id = NEW.oom_id;
-- 2. Determine if the Order has "Live" items remaining.
-- An item is considered "Live" (pending) if:
--   a) It hasn't reached a terminal state (DELIVERED or CANCELLED).
--   b) It IS delivered, but the consumer hasn't paid yet.
SELECT EXISTS (
        SELECT 1
        FROM public.offer_order_match oom_check
            JOIN public.consumer_orders_variety cov_check ON cov_check.cov_id = oom_check.cov_id
            JOIN public.consumer_orders_variety_group covg_check ON covg_check.covg_id = cov_check.covg_id
            JOIN public.consumer_orders_produce cop_check ON cop_check.cop_id = covg_check.cop_id
        WHERE cop_check.order_id = v_order_id
            AND (
                -- Condition A: Item is still in progress (Pending, Packing, Shipping, etc.)
                (
                    oom_check.delivery_status NOT IN ('DELIVERED', 'CANCELLED')
                )
                OR -- Condition B: Item reached the customer, but the transaction isn't settled.
                (
                    oom_check.delivery_status = 'DELIVERED'
                    AND oom_check.consumer_has_paid = FALSE
                )
            )
    ) INTO v_still_pending;
-- 3. Update the Parent Order.
-- If no items met the "Live" criteria above, the order is complete.
IF NOT v_still_pending THEN
UPDATE public.consumer_orders
SET is_active = FALSE,
    updated_at = NOW()
WHERE order_id = v_order_id;
END IF;
-- Return the updated row to the calling process.
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- ============================================================
-- Trigger: tr_deactivate_completed_order
-- Logic: Fires only when delivery_status or payment status changes.
-- ============================================================
CREATE TRIGGER tr_deactivate_completed_order
AFTER
UPDATE OF delivery_status,
    consumer_has_paid ON public.offer_order_match FOR EACH ROW EXECUTE FUNCTION public.handle_order_active_status();