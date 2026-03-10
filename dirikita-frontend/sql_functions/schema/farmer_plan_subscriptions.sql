create table public.farmer_plan_subscriptions (
    fps_id uuid not null default gen_random_uuid (),
    farmer_id uuid not null,
    plan_config_id uuid not null,
    status text not null default 'active'::text,
    started_at timestamp with time zone not null default now(),
    ends_at timestamp with time zone null,
    cancelled_at timestamp with time zone null,
    price_lock_used numeric(10, 2) not null default 0,
    price_lock_reset_at timestamp with time zone null,
    current_month_sales numeric(10, 2) not null default 0,
    current_month_rebate numeric(10, 2) not null default 0,
    rebate_month date null,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint farmer_plan_subscriptions_pkey primary key (fps_id),
    constraint farmer_plan_subscriptions_plan_config_id_fkey foreign KEY (plan_config_id) references farmer_plan_configs (fpc_id),
    constraint farmer_plan_subscriptions_status_check check (
        (
            status = any (
                array [
          'active'::text,
          'cancelled'::text,
          'expired'::text,
          'past_due'::text
        ]
            )
        )
    )
) TABLESPACE pg_default;
create index IF not exists idx_fps_farmer_id on public.farmer_plan_subscriptions using btree (farmer_id) TABLESPACE pg_default;
create index IF not exists idx_fps_status on public.farmer_plan_subscriptions using btree (status) TABLESPACE pg_default;
create index IF not exists idx_fps_rebate_month on public.farmer_plan_subscriptions using btree (rebate_month) TABLESPACE pg_default;
create trigger trg_plan_subscriptions_updated_at BEFORE
update on farmer_plan_subscriptions for EACH row execute FUNCTION update_updated_at ();