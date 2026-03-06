create table public.consumer_future_plan_configs (
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone null default now(),
    billing_interval text null default 'monthly'::text,
    max_total_value numeric null default '0'::numeric,
    min_total_value numeric null default '0'::numeric,
    is_active boolean null default true,
    fee numeric null default '0'::numeric,
    plan_name text null,
    cfp_id uuid not null default gen_random_uuid (),
    constraint consumer_future_plan_config_pkey primary key (cfp_id),
    constraint consumer_future_plan_config_cfp_id_key unique (cfp_id)
) TABLESPACE pg_default;