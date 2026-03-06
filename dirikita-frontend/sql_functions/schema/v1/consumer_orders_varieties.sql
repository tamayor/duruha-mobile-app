create table public.consumer_orders_varieties (
    id uuid not null default gen_random_uuid (),
    order_id uuid not null default gen_random_uuid (),
    variety_id uuid null default gen_random_uuid (),
    quantity numeric null,
    group_id integer null,
    listing_id uuid not null default gen_random_uuid (),
    price_locked numeric not null default '0'::numeric,
    constraint consumer_orders_varieties_pkey primary key (id),
    constraint consumer_orders_varieties_order_id_fkey foreign KEY (order_id) references consumer_orders (order_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;