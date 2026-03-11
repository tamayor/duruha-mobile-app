create table public.dialects (
    id uuid not null default gen_random_uuid (),
    dialect_name text not null,
    constraint dialect_pkey primary key (id),
    constraint dialects_dialect_name_key unique (dialect_name)
) TABLESPACE pg_default;