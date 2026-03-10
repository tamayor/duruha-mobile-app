create table public.users_addresses (
    address_id uuid not null default gen_random_uuid (),
    user_id uuid null,
    created_at timestamp with time zone not null default now(),
    address_line_1 text null,
    address_line_2 text null,
    city text null,
    province text null,
    landmark text null,
    region text null,
    postal_code text null,
    location geography null,
    country text null,
    constraint users_location_pkey primary key (address_id),
    constraint users_location_user_id_fkey foreign KEY (user_id) references users (id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;
create index IF not exists idx_users_location_geog on public.users_addresses using gist (location) TABLESPACE pg_default;