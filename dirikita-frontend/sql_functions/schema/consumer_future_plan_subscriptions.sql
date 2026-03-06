create table public.consumer_future_plan_subscriptions (
    consumer_id text not null,
    cfp_id uuid not null,
    starts_at timestamp with time zone not null default now(),
    expires_at timestamp with time zone not null,
    is_active boolean null default true,
    extension_count integer null default 0,
    last_extension_at timestamp with time zone null,
    created_at timestamp with time zone null default now(),
    updated_at timestamp with time zone null default now(),
    cfps_id uuid not null default gen_random_uuid (),
    renew_count integer not null default 0,
    last_renewed_at timestamp with time zone null,
    constraint consumer_future_plan_subscriptions_pkey primary key (cfps_id),
    constraint cfp_subs_config_fkey foreign KEY (cfp_id) references consumer_future_plan_configs (cfp_id),
    constraint cfp_subs_consumer_id_fkey foreign KEY (consumer_id) references user_consumers (consumer_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;
create index IF not exists idx_cfp_subs_consumer on public.consumer_future_plan_subscriptions using btree (consumer_id) TABLESPACE pg_default;