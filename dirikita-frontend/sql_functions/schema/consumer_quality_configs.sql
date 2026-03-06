create table public.consumer_quality_configs (
    cqc_id uuid not null default gen_random_uuid (),
    tier public.quality not null,
    monthly_fee numeric not null default 0,
    description text null,
    is_active boolean not null default true,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint consumer_quality_configs_pkey primary key (cqc_id)
) TABLESPACE pg_default;