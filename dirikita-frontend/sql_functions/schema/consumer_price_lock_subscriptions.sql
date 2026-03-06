create table public.consumer_price_lock_subscriptions (
    cpls_id uuid not null default gen_random_uuid (),
    cpl_id uuid not null,
    status text null default 'active'::text,
    starts_at timestamp with time zone null default now(),
    ends_at timestamp with time zone not null,
    remaining_credits numeric null default 0.0,
    last_reset_date timestamp with time zone null default now(),
    created_at timestamp with time zone null default now(),
    updated_at timestamp with time zone null default now(),
    consumer_id text null,
    constraint user_price_lock_subscriptions_pkey primary key (cpls_id),
    constraint consumer_price_lock_subscriptions_consumer_id_fkey foreign KEY (consumer_id) references user_consumers (consumer_id) on update CASCADE on delete CASCADE,
    constraint consumer_price_lock_subscriptions_cpl_id_fkey foreign KEY (cpl_id) references consumer_price_lock_configs (cpl_id),
    constraint user_price_lock_subscriptions_status_check check (
        (
            status = any (
                array [
          'active'::text,
          'expired'::text,
          'cancelled'::text
        ]
            )
        )
    )
) TABLESPACE pg_default;