create table public.consumer_quality_subscriptions (
    cqs_id uuid not null default gen_random_uuid (),
    consumer_id text not null,
    cqc_id uuid not null,
    starts_at timestamp with time zone not null default now(),
    ends_at timestamp with time zone null,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    status public.status not null,
    constraint consumer_quality_subscriptions_pkey primary key (cqs_id),
    constraint cqs_consumer_id_fkey foreign KEY (consumer_id) references user_consumers (consumer_id) on update CASCADE on delete CASCADE,
    constraint cqs_cqc_id_fkey foreign KEY (cqc_id) references consumer_quality_configs (cqc_id) on update CASCADE on delete RESTRICT
) TABLESPACE pg_default;