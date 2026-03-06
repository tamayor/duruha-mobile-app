-- ============================================================
-- oom_delivery_status_history
-- Tracks every delivery_status change on offer_order_match
-- Records: old status, new status, oom_id, and users.name of
-- whoever made the change (resolved from auth.uid())
-- ============================================================
-- ── Trigger function ─────────────────────────────────────────
create or replace function log_oom_delivery_status_change() returns trigger language plpgsql security definer as $$
declare v_updated_by text;
v_role text;
begin -- Only fire when delivery_status actually changed
if OLD.delivery_status is not distinct
from NEW.delivery_status then return NEW;
end if;
-- Resolve users.name and role from auth.uid()
select u.name,
    u.role::text into v_updated_by,
    v_role
from users u
where u.id = auth.uid()
limit 1;
-- Fallback if name is empty or user not found
if v_updated_by is null
or trim(v_updated_by) = '' then v_updated_by := coalesce(auth.uid()::text, 'system');
end if;
if v_role is null then v_role := 'system';
end if;
insert into offer_order_match_delivery_history (
        oom_id,
        old_delivery_status,
        new_delivery_status,
        updated_by,
        role
    )
values (
        NEW.oom_id,
        OLD.delivery_status,
        NEW.delivery_status,
        v_updated_by,
        v_role
    );
return NEW;
end;
$$;
-- ── Trigger ──────────────────────────────────────────────────
drop trigger if exists trg_oom_delivery_status_history on offer_order_match;
create trigger trg_oom_delivery_status_history
after
update of delivery_status on offer_order_match for each row execute function log_oom_delivery_status_change();