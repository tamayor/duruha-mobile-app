create table public.farmer_plan_configs (
    fpc_id uuid not null default gen_random_uuid (),
    plan_code text not null,
    plan_name text not null,
    monthly_price numeric(10, 2) not null default 0,
    max_product_listings integer not null default 3,
    pool_priority_weight integer not null default 1,
    price_lock_enabled boolean not null default false,
    price_lock_peso_cap numeric(10, 2) null,
    guild_access_enabled boolean not null default false,
    rebate_enabled boolean not null default false,
    rebate_trigger_amount numeric(10, 2) null,
    rebate_percentage numeric(5, 2) null,
    rebate_peso_cap numeric(10, 2) null,
    is_active boolean not null default true,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint farmer_plan_configs_pkey primary key (fpc_id),
    constraint farmer_plan_configs_plan_code_key unique (plan_code)
) TABLESPACE pg_default;
create trigger trg_plan_configs_updated_at BEFORE
update on farmer_plan_configs for EACH row execute FUNCTION update_updated_at ();