-- ══════════════════════════════════════════════════════════════════════
-- TRIGGER FUNCTION: expire_price_lock_offers
-- Fires when ends_at is updated on farmer_price_lock_subscriptions
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_expire_price_lock_offers() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN -- Only act if ends_at is being set to a past/current time
    IF NEW.ends_at IS NOT NULL
    AND NOW() >= NEW.ends_at THEN
UPDATE public.farmer_offers
SET is_active = FALSE,
    updated_at = NOW()
WHERE fpls_id = NEW.fpls_id
    AND (
        is_active = TRUE
        OR is_price_locked = TRUE
    );
END IF;
RETURN NEW;
END;
$$;
-- ── Trigger ───────────────────────────────────────────────────────────
CREATE OR REPLACE TRIGGER tr_expire_price_lock_offers
AFTER
UPDATE OF ends_at ON public.farmer_price_lock_subscriptions FOR EACH ROW EXECUTE FUNCTION public.handle_expire_price_lock_offers();