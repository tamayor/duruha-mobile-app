create table public.offer_order_match (
    offer_order_match_id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    consumer_payment_method public.payment_method null,
    consumer_paid boolean null default false,
    consumer_id text not null,
    is_active boolean not null default true,
    consumer_note text null,
    constraint farmer_offer_delivery_pkey primary key (offer_order_match_id)
) TABLESPACE pg_default;