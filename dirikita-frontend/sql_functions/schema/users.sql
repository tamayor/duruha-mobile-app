create table public.users (
    id uuid not null default gen_random_uuid (),
    joined_at timestamp with time zone null default now(),
    name text null default ''::text,
    email text null,
    phone text null,
    barangay text null,
    city text null,
    province text null,
    landmark text null,
    postal_code text null,
    image_url text null,
    dialect text [] null,
    role public.user_role null,
    operating_days text [] null,
    delivery_window text null,
    location geography null,
    constraint profiles_pkey primary key (id)
) TABLESPACE pg_default;
create index IF not exists idx_users_location_geog on public.users using gist (location) TABLESPACE pg_default;