create table public.consumer_orders_variety_group (
    covg_id uuid not null default gen_random_uuid (),
    item_index integer not null,
    form text null,
    quantity numeric null,
    is_any boolean null,
    cop_id uuid null,
    date_needed date null,
    cpls_id uuid null,
    cfps_id uuid null,
    constraint consumer_orders_produce_varieties_pkey primary key (covg_id),
    constraint consumer_orders_produce_varieties_cop_id_fkey foreign KEY (cop_id) references consumer_orders_produce (cop_id) on update CASCADE on delete CASCADE,
    constraint consumer_orders_produce_varieties_cpls_id_fkey foreign KEY (cpls_id) references consumer_price_lock_subscriptions (cpls_id),
    constraint consumer_orders_variety_group_cfps_id_fkey foreign KEY (cfps_id) references consumer_future_plan_subscriptions (cfps_id)
) TABLESPACE pg_default;