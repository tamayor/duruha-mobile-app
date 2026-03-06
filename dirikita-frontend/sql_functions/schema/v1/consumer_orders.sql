create table public.consumer_orders (
    order_id uuid not null default gen_random_uuid (),
    date_needed date null,
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone null default now(),
    consumer_id text null,
    produce_id uuid null default gen_random_uuid (),
    is_any boolean null default false,
    group_id integer null,
    quality public.quality not null default 'Saver'::quality,
    quality_fee numeric not null default '0'::numeric,
    constraint consumer_orders_pkey primary key (order_id),
    constraint consumer_orders_consumer_id_fkey foreign KEY (consumer_id) references user_consumers (consumer_id) on update CASCADE on delete CASCADE,
    constraint consumer_orders_produce_id_fkey foreign KEY (produce_id) references produce (id)
) TABLESPACE pg_default;
create index IF not exists consumer_orders_produce_id_idx on public.consumer_orders using btree (produce_id) TABLESPACE pg_default;
create index IF not exists consumer_orders_consumer_id_idx on public.consumer_orders using btree (consumer_id) TABLESPACE pg_default;