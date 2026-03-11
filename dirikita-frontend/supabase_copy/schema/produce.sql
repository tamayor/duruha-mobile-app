create table public.produce (
    id uuid not null default gen_random_uuid (),
    english_name text null,
    scientific_name text null,
    created_at timestamp with time zone not null default now(),
    base_unit text null,
    image_url text null,
    category text null,
    updated_at timestamp with time zone null default now(),
    cross_contamination_risk integer null,
    crush_weight_tolerance integer null,
    respiration_rate text null,
    storage_group text null,
    is_ethylene_producer boolean null default false,
    is_ethylene_sensitive boolean null default false,
    constraint produce_pkey primary key (id),
    constraint produce_id_key unique (id),
    constraint produce_cross_contamination_risk_check check (
        (
            (cross_contamination_risk >= 1)
            and (cross_contamination_risk <= 5)
        )
    ),
    constraint produce_crush_weight_tolerance_check check (
        (
            (crush_weight_tolerance >= 1)
            and (crush_weight_tolerance <= 5)
        )
    ),
    constraint produce_respiration_rate_check check (
        (
            respiration_rate = any (
                array [
          ('Low'::character varying)::text,
          ('Medium'::character varying)::text,
          ('High'::character varying)::text
        ]
            )
        )
    )
) TABLESPACE pg_default;
create index IF not exists idx_produce_search on public.produce using gin (
    to_tsvector(
        'english'::regconfig,
        (
            (
                (
                    (COALESCE(english_name, ''::text) || ' '::text) || COALESCE(scientific_name, ''::text)
                ) || ' '::text
            ) || COALESCE(category, ''::text)
        )
    )
) TABLESPACE pg_default;