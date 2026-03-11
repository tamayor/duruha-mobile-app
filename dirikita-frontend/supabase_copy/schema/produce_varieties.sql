create table public.produce_varieties (
    variety_name text not null,
    is_native boolean null default false,
    breeding_type public.breeding_category null,
    days_to_maturity_min integer null,
    days_to_maturity_max integer null,
    peak_months text [] null,
    philippine_season public.ph_season_type null,
    flood_tolerance integer null,
    handling_fragility integer null,
    shelf_life_days integer null,
    optimal_storage_temp_c real null,
    packaging_requirement text null,
    appearance_desc text null,
    created_at timestamp with time zone null default CURRENT_TIMESTAMP,
    updated_at timestamp with time zone null default CURRENT_TIMESTAMP,
    produce_id uuid not null,
    image_url text null,
    variety_id uuid not null default gen_random_uuid (),
    constraint produce_varieties_pkey primary key (variety_id),
    constraint produce_varieties_variety_id_key unique (variety_id),
    constraint produce_varieties_produce_id_fkey foreign KEY (produce_id) references produce (id) on update CASCADE on delete CASCADE,
    constraint produce_varieties_flood_tolerance_check check (
        (
            (flood_tolerance >= 1)
            and (flood_tolerance <= 5)
        )
    ),
    constraint produce_varieties_handling_fragility_check check (
        (
            (handling_fragility >= 1)
            and (handling_fragility <= 5)
        )
    ),
    constraint produce_varieties_shelf_life_days_check check ((shelf_life_days >= 0))
) TABLESPACE pg_default;
create index IF not exists idx_variety_search on public.produce_varieties using gin (
    to_tsvector(
        'english'::regconfig,
        COALESCE(variety_name, ''::text)
    )
) TABLESPACE pg_default;