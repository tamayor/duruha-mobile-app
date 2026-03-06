create table public.produce_variety_listing (
    listing_id uuid not null default gen_random_uuid (),
    variety_id uuid not null,
    produce_form text null,
    farmer_to_duruha_price numeric not null default 0,
    duruha_to_consumer_price numeric not null default 0,
    market_to_consumer_price numeric not null default 0,
    farmer_to_trader_price numeric not null default 0,
    created_at timestamp with time zone null default CURRENT_TIMESTAMP,
    updated_at timestamp with time zone null default CURRENT_TIMESTAMP,
    constraint produce_variety_sku_pkey primary key (listing_id),
    constraint produce_variety_sku_variety_id_fkey foreign KEY (variety_id) references produce_varieties (variety_id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;
create index IF not exists idx_sku_variety_id on public.produce_variety_listing using btree (variety_id) TABLESPACE pg_default;
create trigger trg_sku_price_change
after
update on produce_variety_listing for EACH row execute FUNCTION log_sku_price_change ();