create table public.farmer_price_lock_subscriptions (
    fpls_id uuid not null default gen_random_uuid (),
    fpl_id uuid not null,
    status text null default 'active'::text,
    starts_at timestamp with time zone null default now(),
    ends_at timestamp with time zone not null,
    remaining_credits numeric null default 0.0,
    last_reset_date timestamp with time zone null default now(),
    created_at timestamp with time zone null default now(),
    updated_at timestamp with time zone null default now(),
    farmer_id text null,
    constraint farmer_price_lock_subscriptions_pkey primary key (fpls_id),
    constraint farmer_price_lock_subscriptions_farmer_id_fkey foreign KEY (farmer_id) references user_farmers (farmer_id) on update CASCADE on delete CASCADE,
    constraint farmer_price_lock_subscriptions_fpl_id_fkey foreign KEY (fpl_id) references farmer_price_lock_configs (fpl_id) on update CASCADE on delete CASCADE,
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