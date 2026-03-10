create table public.consumer_orders_variety_group (
    covg_id uuid not null default gen_random_uuid (),
    item_index integer not null,
    form text null,
    quantity numeric null,
    is_any boolean null,
    cop_id uuid null,
    date_needed date null,
    cps_id uuid null,
    constraint consumer_orders_produce_varieties_pkey primary key (covg_id),
    constraint consumer_orders_produce_varieties_cop_id_fkey foreign KEY (cop_id) references consumer_orders_produce (cop_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;