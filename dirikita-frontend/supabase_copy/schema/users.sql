create table public.users (
    id uuid not null default gen_random_uuid (),
    joined_at timestamp with time zone null default now(),
    name text null default ''::text,
    email text null,
    phone text null,
    image_url text null,
    dialect text [] null,
    role public.user_role null,
    operating_days text [] null,
    delivery_window text null,
    region text null,
    address_id uuid null,
    constraint profiles_pkey primary key (id)
) TABLESPACE pg_default;