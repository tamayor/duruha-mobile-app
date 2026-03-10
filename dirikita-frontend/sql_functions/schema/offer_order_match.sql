create table public.offer_order_match (
    oom_id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    cov_id uuid null,
    foa_id uuid null,
    delivery_status public.delivery_status not null default 'PENDING'::delivery_status,
    updated_at timestamp with time zone not null default now(),
    dispatch_at timestamp with time zone not null,
    delivery_fee numeric null,
    carrier_id text null,
    consumer_has_paid boolean not null default false,
    consumer_address uuid null,
    farmer_address uuid null,
    constraint farmer_offer_delivery_pkey primary key (oom_id),
    constraint offer_order_match_carrier_id_fkey foreign KEY (carrier_id) references user_carriers (carrier_id),
    constraint offer_order_match_cov_id_fkey foreign KEY (cov_id) references consumer_orders_variety (cov_id) on update CASCADE on delete CASCADE,
    constraint offer_order_match_foa_id_fkey foreign KEY (foa_id) references farmer_offers_allocations (foa_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;
create trigger tr_deactivate_completed_order
after
update OF delivery_status,
    consumer_has_paid on offer_order_match for EACH row execute FUNCTION handle_order_active_status ();
create trigger tr_oom_delivery_status_history
after
update OF delivery_status on offer_order_match for EACH row execute FUNCTION log_oom_delivery_status_change ();