-- ============================================================
-- manage_profile
-- ============================================================
-- Unified RPC for fetching or updating a user profile.
--
-- Parameters:
--   p_user_id   UUID    – the target user's ID
--   p_mode      TEXT    – 'get' or 'update'
--   p_data      JSONB   – payload for update (ignored on get)
--
-- Security:
--   • Only the authenticated user can read/write their own profile.
--   • Role is detected automatically from the users table.
--   • For 'update', only allowed fields are written (role cannot be changed).
--
-- Returns JSONB:
--   On GET    → full profile snapshot (base + role-specific fields + address)
--   On UPDATE → { "success": true, "role": "..." } or raises an exception
--
-- Address fields are stored in public.users_addresses.
-- The user's current address is resolved via users.address_id (FK → users_addresses.address_id).
-- If no address row exists on update, one is inserted and users.address_id is set.
-- ============================================================
CREATE OR REPLACE FUNCTION public.manage_profile(
        p_user_id UUID,
        p_mode TEXT,
        -- 'get' | 'update' | 'delete_address'
        p_data JSONB DEFAULT NULL
    ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public,
    extensions AS $$
DECLARE v_caller_id UUID;
v_user_role TEXT;
v_base RECORD;
v_addr RECORD;
v_farmer RECORD;
v_consumer RECORD;
v_result JSONB;
v_address_id UUID;
v_new_address_id UUID;
v_del_address_id UUID;
v_next_address_id UUID;
BEGIN -- ── 1. Verify caller identity ──────────────────────────────────────────
v_caller_id := auth.uid();
IF v_caller_id IS NULL THEN RAISE EXCEPTION 'Not authenticated';
END IF;
IF v_caller_id <> p_user_id THEN RAISE EXCEPTION 'Access denied: you can only manage your own profile';
END IF;
-- ── 2. Resolve role ────────────────────────────────────────────────────
SELECT UPPER(role::TEXT) INTO v_user_role
FROM public.users
WHERE id = p_user_id;
IF NOT FOUND THEN RAISE EXCEPTION 'User not found: %',
p_user_id;
END IF;
IF v_user_role NOT IN ('FARMER', 'CONSUMER') THEN RAISE EXCEPTION 'Unsupported role: %',
v_user_role;
END IF;
-- ══════════════════════════════════════════════════════════════════════
--  GET
-- ══════════════════════════════════════════════════════════════════════
IF p_mode = 'get' THEN -- Base user fields
SELECT u.id,
    u.joined_at,
    u.name,
    u.email,
    u.phone,
    u.image_url,
    u.dialect,
    u.role,
    u.operating_days,
    u.delivery_window,
    u.address_id INTO v_base
FROM public.users u
WHERE u.id = p_user_id;
v_result := jsonb_build_object(
    'id',
    v_base.id,
    'joined_at',
    v_base.joined_at,
    'name',
    v_base.name,
    'email',
    v_base.email,
    'phone',
    v_base.phone,
    'image_url',
    v_base.image_url,
    'dialect',
    v_base.dialect,
    'role',
    v_base.role,
    'operating_days',
    v_base.operating_days,
    'delivery_window',
    v_base.delivery_window,
    'region',
    v_base.region
);
-- Address fields from users_addresses (joined via users.address_id FK)
SELECT a.address_id,
    a.address_line_1,
    a.address_line_2,
    a.city,
    a.province,
    a.landmark,
    a.region AS addr_region,
    a.postal_code,
    a.country,
    ST_Y(a.location::geometry) AS latitude,
    ST_X(a.location::geometry) AS longitude INTO v_addr
FROM public.users_addresses a
WHERE a.address_id = v_base.address_id;
IF FOUND THEN v_result := v_result || jsonb_build_object(
    'address_id',
    v_addr.address_id,
    'address_line_1',
    v_addr.address_line_1,
    'address_line_2',
    v_addr.address_line_2,
    'city',
    v_addr.city,
    'province',
    v_addr.province,
    'landmark',
    v_addr.landmark,
    'postal_code',
    v_addr.postal_code,
    'country',
    v_addr.country,
    'latitude',
    v_addr.latitude,
    'longitude',
    v_addr.longitude
);
ELSE -- Return null address block so the client always has the keys
v_result := v_result || jsonb_build_object(
    'address_id',
    NULL,
    'address_line_1',
    NULL,
    'address_line_2',
    NULL,
    'city',
    NULL,
    'province',
    NULL,
    'landmark',
    NULL,
    'postal_code',
    NULL,
    'country',
    NULL,
    'latitude',
    NULL,
    'longitude',
    NULL
);
END IF;
-- Role-specific fields
IF v_user_role = 'FARMER' THEN
SELECT uf.farmer_id,
    uf.farmer_alias,
    uf.land_area,
    uf.accessibility_type,
    uf.water_sources,
    uf.fav_produce INTO v_farmer
FROM public.user_farmers uf
WHERE uf.user_id = p_user_id;
v_result := v_result || jsonb_build_object(
    'farmer_id',
    v_farmer.farmer_id,
    'farmer_alias',
    v_farmer.farmer_alias,
    'land_area',
    v_farmer.land_area,
    'accessibility_type',
    v_farmer.accessibility_type,
    'water_sources',
    v_farmer.water_sources,
    'fav_produce',
    v_farmer.fav_produce
);
ELSIF v_user_role = 'CONSUMER' THEN
SELECT uc.consumer_id,
    uc.consumer_segment,
    uc.cooking_frequency,
    uc.fav_produce,
    uc.quality_preferences,
    uc.is_price_locked INTO v_consumer
FROM public.user_consumers uc
WHERE uc.user_id = p_user_id;
v_result := v_result || jsonb_build_object(
    'consumer_id',
    v_consumer.consumer_id,
    'consumer_segment',
    v_consumer.consumer_segment,
    'cooking_frequency',
    v_consumer.cooking_frequency,
    'fav_produce',
    v_consumer.fav_produce,
    'quality_preferences',
    v_consumer.quality_preferences,
    'is_price_locked',
    v_consumer.is_price_locked
);
END IF;
RETURN v_result;
-- ══════════════════════════════════════════════════════════════════════
--  UPDATE
-- ══════════════════════════════════════════════════════════════════════
ELSIF p_mode = 'update' THEN IF p_data IS NULL THEN RAISE EXCEPTION 'p_data is required for update mode';
END IF;
-- ── 2a. Update base user fields ──────────────────────────────────
UPDATE public.users
SET name = COALESCE((p_data->>'name'), name),
    email = COALESCE((p_data->>'email'), email),
    phone = COALESCE((p_data->>'phone'), phone),
    image_url = COALESCE((p_data->>'image_url'), image_url),
    delivery_window = COALESCE((p_data->>'delivery_window'), delivery_window),
    region = COALESCE((p_data->>'region'), region),
    dialect = COALESCE(
        (
            SELECT ARRAY(
                    SELECT jsonb_array_elements_text(p_data->'dialect')
                )
            WHERE p_data ? 'dialect'
        ),
        dialect
    ),
    operating_days = COALESCE(
        (
            SELECT ARRAY(
                    SELECT jsonb_array_elements_text(p_data->'operating_days')
                )
            WHERE p_data ? 'operating_days'
        ),
        operating_days
    ),
    address_id = COALESCE((p_data->>'address_id')::UUID, address_id)
WHERE id = p_user_id;
-- ── 2b. Upsert address in users_addresses ────────────────────────
--   If any address field is present in p_data, write to users_addresses.
IF (
    p_data ? 'address_line_1'
    OR p_data ? 'address_line_2'
    OR p_data ? 'city'
    OR p_data ? 'province'
    OR p_data ? 'landmark'
    OR p_data ? 'postal_code'
    OR p_data ? 'country'
    OR (
        p_data ? 'latitude'
        AND p_data ? 'longitude'
    )
) THEN -- Resolve existing address id (if any) from users.address_id
SELECT address_id INTO v_address_id
FROM public.users
WHERE id = p_user_id;
IF v_address_id IS NOT NULL THEN -- Update existing address row
UPDATE public.users_addresses
SET address_line_1 = COALESCE((p_data->>'address_line_1'), address_line_1),
    address_line_2 = COALESCE((p_data->>'address_line_2'), address_line_2),
    city = COALESCE((p_data->>'city'), city),
    province = COALESCE((p_data->>'province'), province),
    landmark = COALESCE((p_data->>'landmark'), landmark),
    region = COALESCE((p_data->>'region'), region),
    postal_code = COALESCE((p_data->>'postal_code'), postal_code),
    country = COALESCE((p_data->>'country'), country),
    location = CASE
        WHEN (p_data->>'latitude') IS NOT NULL
        AND (p_data->>'longitude') IS NOT NULL THEN ST_SetSRID(
            ST_MakePoint(
                (p_data->>'longitude')::DOUBLE PRECISION,
                (p_data->>'latitude')::DOUBLE PRECISION
            ),
            4326
        )::geography
        ELSE location
    END
WHERE address_id = v_address_id;
ELSE -- Insert a new address row and link it back to users
INSERT INTO public.users_addresses (
        user_id,
        address_line_1,
        address_line_2,
        city,
        province,
        landmark,
        region,
        postal_code,
        country,
        location
    )
VALUES (
        p_user_id,
        (p_data->>'address_line_1'),
        (p_data->>'address_line_2'),
        (p_data->>'city'),
        (p_data->>'province'),
        (p_data->>'landmark'),
        (p_data->>'region'),
        (p_data->>'postal_code'),
        (p_data->>'country'),
        CASE
            WHEN (p_data->>'latitude') IS NOT NULL
            AND (p_data->>'longitude') IS NOT NULL THEN ST_SetSRID(
                ST_MakePoint(
                    (p_data->>'longitude')::DOUBLE PRECISION,
                    (p_data->>'latitude')::DOUBLE PRECISION
                ),
                4326
            )::geography
            ELSE NULL
        END
    )
RETURNING address_id INTO v_new_address_id;
-- Link the new address to the user
UPDATE public.users
SET address_id = v_new_address_id
WHERE id = p_user_id;
END IF;
END IF;
-- ── 2c. Update role-specific fields ───────────────────────────────
IF v_user_role = 'FARMER' THEN
INSERT INTO public.user_farmers (
        user_id,
        farmer_id,
        farmer_alias,
        land_area,
        accessibility_type,
        water_sources,
        fav_produce
    )
VALUES (
        p_user_id,
        COALESCE((p_data->>'farmer_id'), ''),
        (p_data->>'farmer_alias'),
        (p_data->>'land_area')::DOUBLE PRECISION,
        (p_data->>'accessibility_type'),
        CASE
            WHEN p_data ? 'water_sources' THEN ARRAY(
                SELECT jsonb_array_elements_text(p_data->'water_sources')
            )
            ELSE NULL
        END,
        CASE
            WHEN p_data ? 'fav_produce' THEN ARRAY(
                SELECT jsonb_array_elements_text(p_data->'fav_produce')
            )
            ELSE NULL
        END
    ) ON CONFLICT (user_id, farmer_id) DO
UPDATE
SET farmer_alias = COALESCE(
        EXCLUDED.farmer_alias,
        user_farmers.farmer_alias
    ),
    land_area = COALESCE(
        EXCLUDED.land_area,
        user_farmers.land_area
    ),
    accessibility_type = COALESCE(
        EXCLUDED.accessibility_type,
        user_farmers.accessibility_type
    ),
    water_sources = COALESCE(
        EXCLUDED.water_sources,
        user_farmers.water_sources
    ),
    fav_produce = COALESCE(
        EXCLUDED.fav_produce,
        user_farmers.fav_produce
    );
ELSIF v_user_role = 'CONSUMER' THEN
INSERT INTO public.user_consumers (
        user_id,
        consumer_id,
        consumer_segment,
        cooking_frequency,
        fav_produce,
        quality_preferences,
        is_price_locked
    )
VALUES (
        p_user_id,
        COALESCE((p_data->>'consumer_id'), ''),
        (p_data->>'consumer_segment'),
        (p_data->>'cooking_frequency'),
        CASE
            WHEN p_data ? 'fav_produce' THEN ARRAY(
                SELECT jsonb_array_elements_text(p_data->'fav_produce')
            )
            ELSE NULL
        END,
        CASE
            WHEN p_data ? 'quality_preferences' THEN ARRAY(
                SELECT jsonb_array_elements_text(p_data->'quality_preferences')
            )
            ELSE NULL
        END,
        COALESCE((p_data->'is_price_locked')::BOOLEAN, false)
    ) ON CONFLICT (user_id, consumer_id) DO
UPDATE
SET consumer_segment = COALESCE(
        EXCLUDED.consumer_segment,
        user_consumers.consumer_segment
    ),
    cooking_frequency = COALESCE(
        EXCLUDED.cooking_frequency,
        user_consumers.cooking_frequency
    ),
    fav_produce = COALESCE(
        EXCLUDED.fav_produce,
        user_consumers.fav_produce
    ),
    quality_preferences = COALESCE(
        EXCLUDED.quality_preferences,
        user_consumers.quality_preferences
    ),
    is_price_locked = COALESCE(
        EXCLUDED.is_price_locked,
        user_consumers.is_price_locked
    );
END IF;
RETURN jsonb_build_object('success', true, 'role', LOWER(v_user_role));
-- ══════════════════════════════════════════════════════════════════════
--  DELETE_ADDRESS
-- ══════════════════════════════════════════════════════════════════════
ELSIF p_mode = 'delete_address' THEN IF p_data IS NULL
OR (p_data->>'address_id') IS NULL THEN RAISE EXCEPTION 'address_id is required for delete_address mode';
END IF;
v_del_address_id := (p_data->>'address_id')::UUID;
-- Verify the address belongs to this user
IF NOT EXISTS (
    SELECT 1
    FROM public.users_addresses
    WHERE address_id = v_del_address_id
        AND user_id = p_user_id
) THEN RAISE EXCEPTION 'Address not found or does not belong to this user';
END IF;
-- If this is the active address, clear the FK first then pick another
SELECT address_id INTO v_address_id
FROM public.users
WHERE id = p_user_id;
IF v_address_id = v_del_address_id THEN -- Try to find another address for this user
SELECT address_id INTO v_next_address_id
FROM public.users_addresses
WHERE user_id = p_user_id
    AND address_id <> v_del_address_id
ORDER BY created_at DESC
LIMIT 1;
UPDATE public.users
SET address_id = v_next_address_id
WHERE id = p_user_id;
END IF;
-- Delete the address row
DELETE FROM public.users_addresses
WHERE address_id = v_del_address_id
    AND user_id = p_user_id;
RETURN jsonb_build_object(
    'success',
    true,
    'new_active_address_id',
    v_next_address_id
);
ELSE RAISE EXCEPTION 'Unknown mode: %. Use ''get'', ''update'', or ''delete_address''.',
p_mode;
END IF;
END;
$$;
-- Grant execution to authenticated users only
REVOKE ALL ON FUNCTION public.manage_profile(UUID, TEXT, JSONB)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.manage_profile(UUID, TEXT, JSONB) TO authenticated;