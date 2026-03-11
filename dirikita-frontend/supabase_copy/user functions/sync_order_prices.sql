-- Trigger function for offer_order_match: Auto-dispatch and Lock price
CREATE OR REPLACE FUNCTION public.handle_oom_dispatch_price_lock()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Automated status transition: set to DISPATCHED if dispatch_at reached
    IF NEW.dispatch_at <= NOW() AND NEW.delivery_status <> 'DISPATCHED' THEN
        NEW.delivery_status := 'DISPATCHED';
    END IF;

    -- 2. QC Passed Price Lock: Lock farmer allocation price
    IF (NEW.delivery_status = 'QC_PASSED' AND (OLD.delivery_status IS NULL OR OLD.delivery_status <> 'QC_PASSED'))
    THEN
        UPDATE public.farmer_offers_allocations
        SET final_price = ftd_price
        WHERE foa_id = NEW.foa_id;
    END IF;

    -- 3. Price locking logic: when status becomes DISPATCHED
    IF (NEW.delivery_status = 'DISPATCHED' AND (OLD.delivery_status IS NULL OR OLD.delivery_status <> 'DISPATCHED'))
    THEN
        UPDATE public.consumer_orders_variety
        SET final_price = dtc_price
        WHERE cov_id = NEW.cov_id
          AND is_price_lock = false
          -- Handled as case-insensitive or matching your enum casing
          AND UPPER(selection_type::text) IN ('MATCHED', 'SKIPPED');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for offer_order_match (BEFORE UPDATE to allow modifying NEW record)
DROP TRIGGER IF EXISTS tr_oom_dispatch_price_lock ON public.offer_order_match;
CREATE TRIGGER tr_oom_dispatch_price_lock
BEFORE UPDATE OF delivery_status, dispatch_at ON public.offer_order_match
FOR EACH ROW EXECUTE FUNCTION public.handle_oom_dispatch_price_lock();


-- Trigger function for produce_variety_listing: Sync dtc_price and ftd_price to pending orders
CREATE OR REPLACE FUNCTION public.handle_sync_cov_dtc_price_from_listing()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Update consumer prices (dtc_price)
    UPDATE public.consumer_orders_variety cov
    SET dtc_price = NEW.duruha_to_consumer_price
    FROM public.offer_order_match oom
    WHERE cov.listing_id = NEW.listing_id
      AND cov.cov_id = oom.cov_id
      AND oom.delivery_status IN ('PENDING', 'ACCEPTED', 'PREPARING', 'READY_FOR_QC', 'QC_PASSED');

    -- 2. Update farmer prices (ftd_price)
    UPDATE public.farmer_offers_allocations foa
    SET ftd_price = NEW.farmer_to_duruha_price
    FROM public.consumer_orders_variety cov
    JOIN public.offer_order_match oom ON oom.cov_id = cov.cov_id
    WHERE cov.listing_id = NEW.listing_id
      AND foa.foa_id = oom.foa_id
      AND oom.delivery_status IN ('PENDING', 'ACCEPTED', 'PREPARING', 'READY_FOR_QC', 'QC_PASSED');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for produce_variety_listing
DROP TRIGGER IF EXISTS tr_pvl_dtc_price_sync ON public.produce_variety_listing;
CREATE TRIGGER tr_pvl_dtc_price_sync
AFTER UPDATE OF duruha_to_consumer_price, farmer_to_duruha_price ON public.produce_variety_listing
FOR EACH ROW EXECUTE FUNCTION public.handle_sync_cov_dtc_price_from_listing();