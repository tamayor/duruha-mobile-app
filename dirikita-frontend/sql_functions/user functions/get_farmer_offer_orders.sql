CREATE OR REPLACE FUNCTION public.get_farmer_offer_orders(p_offer_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE v_user_id uuid;
v_farmer_id text;
v_offer_farmer_id text;
v_orders jsonb;
v_summary jsonb;
v_offer_meta jsonb;
BEGIN -- 1. Get authenticated user
v_user_id := auth.uid();
IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated';
END IF;
-- 2. Get farmer_id linked to the authenticated user
SELECT uf.farmer_id INTO v_farmer_id
FROM user_farmers uf
WHERE uf.user_id = v_user_id;
IF v_farmer_id IS NULL THEN RAISE EXCEPTION 'No farmer profile found for this user';
END IF;
-- 3. Get farmer_id of the offer + offer meta (including payment_method)
SELECT fo.farmer_id,
    jsonb_build_object(
        'is_price_locked',
        fo.is_price_locked,
        'fpls_id',
        fo.fpls_id,
        'fpls_status',
        fpls.status,
        'remaining_price_lock_credit',
        fo.remaining_price_lock_credit,
        'total_price_lock_credit',
        fo.total_price_lock_credit,
        'quantity',
        fo.quantity,
        'remaining_quantity',
        fo.remaining_quantity,
        'payment_method',
        fo.payment_method -- Moved from allocation to offer meta
    ) INTO v_offer_farmer_id,
    v_offer_meta
FROM farmer_offers fo
    LEFT JOIN farmer_price_lock_subscriptions fpls ON fpls.fpls_id = fo.fpls_id
WHERE fo.offer_id = p_offer_id;
IF v_offer_farmer_id IS NULL THEN RAISE EXCEPTION 'Offer not found';
END IF;
-- 4. Verify ownership
IF v_farmer_id <> v_offer_farmer_id THEN RAISE EXCEPTION 'Access denied: you do not own this offer';
END IF;
-- 5. Build orders array (payment_method removed from foa join)
SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'foa_id',
                foa.foa_id,
                'quantity',
                foa.quantity,
                'is_paid',
                foa.is_paid,
                'price_lock',
                foa.price_lock,
                'final_price',
                foa.final_price,
                'variable_farmer_price',
                foa.variable_farmer_price,
                'order_at',
                foa.created_at,
                'date_needed',
                covg.date_needed,
                'dispatch_at',
                oom.dispatch_at,
                'carrier_id',
                oom.carrier_id,
                'carrier_name',
                c.name,
                'delivery_status',
                oom.delivery_status,
                'updated_at',
                oom.updated_at,
                'quality',
                cop.quality,
                'fpls_id',
                foa.fpls_id
            )
            ORDER BY oom.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_orders
FROM offer_order_match oom
    JOIN farmer_offers_allocations foa ON foa.foa_id = oom.foa_id
    JOIN consumer_orders_variety cov ON cov.cov_id = oom.cov_id
    JOIN consumer_orders_variety_group covg ON covg.covg_id = cov.covg_id
    JOIN consumer_orders_produce cop ON cop.cop_id = covg.cop_id
    LEFT JOIN carriers c ON c.id = oom.carrier_id
WHERE foa.offer_id = p_offer_id;
-- 6. Build summary totals
SELECT jsonb_build_object(
        'active_total',
        COALESCE(
            SUM(
                CASE
                    WHEN oom.delivery_status IN (
                        'PENDING',
                        'ACCEPTED',
                        'PREPARING',
                        'READY_FOR_QC',
                        'QC_PASSED'
                    ) THEN foa.variable_farmer_price
                    ELSE 0
                END
            ),
            0
        ),
        'orders_total_price',
        COALESCE(
            SUM(
                CASE
                    WHEN oom.delivery_status NOT IN (
                        'PENDING',
                        'ACCEPTED',
                        'PREPARING',
                        'READY_FOR_QC',
                        'QC_PASSED'
                    ) THEN foa.final_price
                    ELSE 0
                END
            ),
            0
        ),
        'farmer_total_earnings',
        COALESCE(
            SUM(
                CASE
                    WHEN foa.is_paid = true THEN foa.final_price
                    ELSE 0
                END
            ),
            0
        )
    ) INTO v_summary
FROM offer_order_match oom
    JOIN farmer_offers_allocations foa ON foa.foa_id = oom.foa_id
WHERE foa.offer_id = p_offer_id;
-- 7. Return everything merged
RETURN v_offer_meta || v_summary || jsonb_build_object('orders', v_orders);
END;
$$;