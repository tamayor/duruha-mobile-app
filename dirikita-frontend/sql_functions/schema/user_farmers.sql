create table public.user_farmers (
    user_id uuid not null default gen_random_uuid (),
    farmer_id text not null,
    farmer_alias text null,
    land_area double precision null,
    accessibility_type text null,
    water_sources text [] null,
    fav_produce text [] null,
    constraint user_farmers_pkey primary key (user_id, farmer_id),
    constraint user_farmers_farmer_id_key unique (farmer_id),
    constraint user_farmers_user_id_fkey foreign KEY (user_id) references users (id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;