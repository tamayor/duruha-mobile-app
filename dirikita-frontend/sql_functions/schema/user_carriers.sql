create table public.user_carriers (
    user_id uuid not null default gen_random_uuid (),
    name text null,
    created_at timestamp with time zone not null default now(),
    carrier_id text null default ''::text,
    constraint carriers_pkey primary key (user_id)
) TABLESPACE pg_default;