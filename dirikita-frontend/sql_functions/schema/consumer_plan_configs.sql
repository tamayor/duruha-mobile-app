create table public.consumer_plan_configs (
    cpc_id uuid not null default gen_random_uuid (),
    tier public.plan_tier not null,
    billing_interval public.billing_interval not null,
    plan_name text not null,
    description text null,
    fee numeric not null default 0,
    monthly_equivalent numeric GENERATED ALWAYS as (
        case
            billing_interval
            when 'yearly'::billing_interval then (fee / (12)::numeric)
            else fee
        end
    ) STORED null,
    monthly_credit_limit numeric null,
    max_order_value numeric null,
    min_order_value numeric null,
    quality_level text null,
    is_active boolean not null default true,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    schedule_window_days integer null,
    constraint consumer_plan_configs_pkey primary key (cpc_id),
    constraint consumer_plan_configs_tier_billing unique (tier, billing_interval),
    constraint consumer_plan_configs_fee_check check ((fee >= (0)::numeric))
) TABLESPACE pg_default;
create trigger trg_consumer_plan_configs_updated_at BEFORE
update on consumer_plan_configs for EACH row execute FUNCTION set_updated_at ();