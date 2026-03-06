create table public.farmer_offers (
    farmer_id text not null,
    variety_id uuid not null,
    created_at timestamp with time zone not null default now(),
    available_from date null,
    available_to date null,
    quantity numeric null,
    offer_id uuid not null default gen_random_uuid (),
    is_active boolean not null default true,
    remaining_quantity numeric null,
    updated_at timestamp with time zone null default now(),
    listing_id uuid null,
    constraint farmers_offer_pkey primary key (offer_id),
    constraint farmers_offer_id_key unique (offer_id),
    constraint farmer_offers_variety_id_fkey foreign KEY (variety_id) references produce_varieties (variety_id),
    constraint farmers_offer_farmer_id_fkey foreign KEY (farmer_id) references user_farmers (farmer_id) on update CASCADE on delete CASCADE,
    constraint farmer_offers_remaining_quantity_check check (
        (
            (
                (remaining_quantity)::double precision >= (0)::double precision
            )
            and (
                (remaining_quantity)::double precision <= (quantity)::double precision
            )
        )
    ),
    constraint quantity_not_negative check (
        (
            (remaining_quantity)::double precision >= (0)::double precision
        )
    )
) TABLESPACE pg_default;