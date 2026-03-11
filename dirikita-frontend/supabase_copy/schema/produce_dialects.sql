create table public.produce_dialects (
    produce_id uuid not null,
    dialect_id uuid not null,
    local_name text not null,
    created_at timestamp with time zone null default now(),
    constraint produce_dialect_pkey primary key (produce_id, dialect_id),
    constraint fk_dialect foreign KEY (dialect_id) references dialects (id) on delete CASCADE,
    constraint fk_produce foreign KEY (produce_id) references produce (id) on delete CASCADE
) TABLESPACE pg_default;
create index IF not exists produce_dialects_dialect_id_idx on public.produce_dialects using btree (dialect_id) TABLESPACE pg_default;