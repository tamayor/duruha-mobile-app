CREATE OR REPLACE FUNCTION public.handle_farmer_subscription_expiration() RETURNS TRIGGER AS $$ BEGIN -- Check if the current time is past the end date
    -- and ensure we don't overwrite a 'CANCELLED' status
    IF NOW() > NEW.ends_at
    AND NEW.status != 'CANCELLED' THEN NEW.status := 'EXPIRED';
END IF;
-- Always update the updated_at timestamp
NEW.updated_at := NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER tr_check_subscription_expiration BEFORE
INSERT
    OR
UPDATE ON public.farmer_price_lock_subscriptions FOR EACH ROW EXECUTE FUNCTION public.handle_farmer_subscription_expiration();