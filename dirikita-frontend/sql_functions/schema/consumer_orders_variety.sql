create table public.consumer_orders_variety (
    cov_id uuid not null default gen_random_uuid (),
    covg_id uuid not null default gen_random_uuid (),
    item_index integer null,
    variety_id uuid null,
    auto_assign boolean null default false,
    listing_id uuid null,
    final_price numeric null,
    price_lock numeric null,
    variable_consumer_price numeric null,
    selection_type public.selection_type null,
    constraint consumer_orders_variety_pkey primary key (cov_id),
    constraint consumer_orders_items_varieties_variety_id_fkey foreign KEY (variety_id) references produce_varieties (variety_id) on update CASCADE on delete CASCADE,
    constraint consumer_orders_produce_variety_listing_id_fkey foreign KEY (listing_id) references produce_variety_listing (listing_id),
    constraint consumer_orders_variety_covg_id_fkey foreign KEY (covg_id) references consumer_orders_variety_group (covg_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;