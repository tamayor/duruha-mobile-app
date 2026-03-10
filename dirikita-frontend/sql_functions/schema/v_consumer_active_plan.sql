create view public.v_consumer_active_plan as
select s.consumer_id,
    s.cps_id,
    s.cpc_id,
    c.tier,
    c.billing_interval,
    c.plan_name,
    c.fee,
    c.monthly_equivalent,
    c.monthly_credit_limit,
    c.max_order_value,
    c.min_order_value,
    c.quality_level,
    s.status,
    s.starts_at,
    s.ends_at,
    s.trial_ends_at,
    s.remaining_credits,
    s.renew_count,
    s.last_renewed_at,
    c.schedule_window_days
from consumer_plan_subscriptions s
    join consumer_plan_configs c on c.cpc_id = s.cpc_id
where s.status = 'active'::subscription_status
    and s.ends_at > now();