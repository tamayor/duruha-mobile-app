create table public.user_consumers (
    user_id uuid not null default gen_random_uuid (),
    consumer_id text not null,
    consumer_segment text null,
    cooking_frequency text null,
    fav_produce text [] null,
    quality_preferences text [] null,
    is_price_locked boolean not null default false,
    constraint user_consumer_pkey primary key (user_id, consumer_id),
    constraint user_consumer_consumer_id_key unique (consumer_id),
    constraint user_consumer_user_id_fkey foreign KEY (user_id) references users (id) on update CASCADE on delete CASCADE
) TABLESPACE pg_default;