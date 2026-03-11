create table public.consumer_plan_subscriptions (
    cps_id uuid not null default gen_random_uuid (),
    consumer_id text not null,
    cpc_id uuid not null,
    status public.subscription_status not null default 'active'::subscription_status,
    starts_at timestamp with time zone not null default now(),
    ends_at timestamp with time zone not null,
    cancelled_at timestamp with time zone null,
    trial_ends_at timestamp with time zone null,
    renew_count integer not null default 0,
    last_renewed_at timestamp with time zone null,
    extension_count integer not null default 0,
    last_extension_at timestamp with time zone null,
    remaining_credits numeric not null default 0,
    last_credit_reset timestamp with time zone null default now(),
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint consumer_plan_subscriptions_pkey primary key (cps_id),
    constraint cpls_config_fkey foreign KEY (cpc_id) references consumer_plan_configs (cpc_id) on update CASCADE on delete RESTRICT,
    constraint cpls_consumer_fkey foreign KEY (consumer_id) references user_consumers (consumer_id) on update CASCADE on delete CASCADE,
    constraint consumer_plan_subscriptions_remaining_credits_check check ((remaining_credits >= (0)::numeric)),
    constraint cpls_ends_after_starts check ((ends_at > starts_at))
) TABLESPACE pg_default;
create index IF not exists idx_cpls_consumer_id on public.consumer_plan_subscriptions using btree (consumer_id) TABLESPACE pg_default;
create index IF not exists idx_cpls_status on public.consumer_plan_subscriptions using btree (status) TABLESPACE pg_default;
create index IF not exists idx_cpls_ends_at on public.consumer_plan_subscriptions using btree (ends_at) TABLESPACE pg_default
where (status = 'active'::subscription_status);
create trigger trg_consumer_plan_subscriptions_updated_at BEFORE
update on consumer_plan_subscriptions for EACH row execute FUNCTION set_updated_at ();