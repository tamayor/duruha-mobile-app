create table public.farmer_offers_allocations (
    created_at timestamp with time zone not null default now(),
    offer_id uuid null default gen_random_uuid (),
    quantity numeric null,
    is_paid boolean null,
    final_price numeric null,
    variable_farmer_price numeric null,
    price_lock numeric null,
    foa_id uuid not null default gen_random_uuid (),
    cov_id uuid null,
    fpls_id uuid null,
    payment_method public.payment_method not null default 'Cash'::payment_method,
    constraint farmer_offers_allocations_pkey primary key (foa_id),
    constraint farmer_offers_allocations_cov_id_fkey foreign KEY (cov_id) references consumer_orders_variety (cov_id) on update CASCADE on delete CASCADE,
    constraint farmer_offers_allocations_fpls_id_fkey foreign KEY (fpls_id) references farmer_price_lock_subscriptions (fpls_id),
    constraint farmer_offers_allocations_offer_id_fkey foreign KEY (offer_id) references farmer_offers (offer_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;