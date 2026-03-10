create table public.consumer_orders_produce (
    cop_id uuid not null default gen_random_uuid (),
    order_id uuid null default gen_random_uuid (),
    produce_id uuid null,
    item_index integer not null default 0,
    quality text null default '''saver''::text'::text,
    note text null,
    constraint consumer_order_produce_pkey primary key (cop_id),
    constraint consumer_orders_produce_order_id_fkey foreign KEY (order_id) references consumer_orders (order_id) on update CASCADE on delete CASCADE,
    constraint consumer_orders_produce_produce_id_fkey foreign KEY (produce_id) references produce (id)
) TABLESPACE pg_default;