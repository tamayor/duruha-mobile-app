create table public.consumer_orders (
    order_id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone null default now(),
    consumer_id text null,
    note text null,
    is_active boolean null,
    payment_method public.payment_method not null default 'Cash'::payment_method,
    constraint consumer_orders_pkey primary key (order_id),
    constraint consumer_orders_consumer_id_fkey foreign KEY (consumer_id) references user_consumers (consumer_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;
create index IF not exists consumer_orders_consumer_id_idx on public.consumer_orders using btree (consumer_id) TABLESPACE pg_default;