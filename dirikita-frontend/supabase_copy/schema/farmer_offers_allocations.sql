create table public.farmer_offers_allocations (
    created_at timestamp with time zone not null default now(),
    offer_id uuid null,
    quantity numeric null,
    is_paid boolean null,
    final_price numeric null,
    ftd_price numeric null,
    price_lock numeric null,
    foa_id uuid not null default gen_random_uuid (),
    cov_id uuid null,
    fps_id uuid null,
    payment_method text null default 'cash'::text,
    farmer_id text null,
    constraint farmer_offers_allocations_pkey primary key (foa_id),
    constraint farmer_offers_allocations_cov_id_fkey foreign KEY (cov_id) references consumer_orders_variety (cov_id) on update CASCADE on delete CASCADE,
    constraint farmer_offers_allocations_farmer_id_fkey foreign KEY (farmer_id) references user_farmers (farmer_id) on update CASCADE on delete CASCADE,
    constraint farmer_offers_allocations_fps_id_fkey foreign KEY (fps_id) references farmer_plan_subscriptions (fps_id),
    constraint farmer_offers_allocations_offer_id_fkey foreign KEY (offer_id) references farmer_offers (offer_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;