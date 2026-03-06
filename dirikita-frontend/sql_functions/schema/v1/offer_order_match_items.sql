create table public.offer_order_match_items (
    offer_id uuid null default gen_random_uuid (),
    order_id uuid null default gen_random_uuid (),
    farmer_is_paid boolean null,
    delivery_status public.delivery_status null,
    carrier_id uuid null default gen_random_uuid (),
    farmer_id text null,
    dispatch_at timestamp with time zone null,
    offer_order_match_id uuid not null,
    id uuid not null default gen_random_uuid (),
    farmer_payout numeric not null default '0'::numeric,
    created_at timestamp with time zone not null default now(),
    delivery_fee numeric not null default 0.0,
    constraint offer_order_match_items_pkey primary key (id),
    constraint offer_order_match_items_carrier_id_fkey foreign KEY (carrier_id) references carriers (id),
    constraint offer_order_match_items_farmer_id_fkey foreign KEY (farmer_id) references user_farmers (farmer_id) on update CASCADE on delete CASCADE,
    constraint offer_order_match_items_offer_id_fkey foreign KEY (offer_id) references farmer_offers (offer_id) on update CASCADE on delete CASCADE,
    constraint offer_order_match_items_offer_order_match_id_fkey foreign KEY (offer_order_match_id) references offer_order_match (offer_order_match_id) on update CASCADE on delete CASCADE,
    constraint offer_order_match_items_order_id_fkey foreign KEY (order_id) references consumer_orders (order_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;
create trigger trigger_record_delivery_status
after
INSERT
    or
update on offer_order_match_items for EACH row execute FUNCTION log_delivery_status_change ();