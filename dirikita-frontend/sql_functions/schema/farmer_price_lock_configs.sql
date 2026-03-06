create table public.farmer_price_lock_configs (
    fpl_id uuid not null default gen_random_uuid (),
    plan_name text not null,
    fee numeric not null,
    monthly_credit_limit numeric not null,
    billing_interval text not null,
    is_active boolean null default true,
    created_at timestamp with time zone null default now(),
    constraint farmer_price_lock_configs_pkey primary key (fpl_id),
    constraint price_lock_configs_billing_interval_check check (
        (
            billing_interval = any (array ['month'::text, 'year'::text])
        )
    )
) TABLESPACE pg_default;