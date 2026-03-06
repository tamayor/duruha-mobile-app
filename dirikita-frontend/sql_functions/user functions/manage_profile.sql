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
--   On GET  → full profile snapshot (base + role-specific fields + location)
--   On UPDATE → { "success": true } or raises an exception
-- ============================================================
CREATE OR REPLACE FUNCTION public.manage_profile(
        p_user_id UUID,
        p_mode TEXT,
        -- 'get' | 'update'
        p_data JSONB DEFAULT NULL
    ) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public,
    extensions AS $$
DECLARE v_caller_id UUID;
v_user_role TEXT;
v_base RECORD;
v_farmer RECORD;
v_consumer RECORD;
v_result JSONB;
v_lat DOUBLE PRECISION;
v_lng DOUBLE PRECISION;
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
    u.barangay,
    u.city,
    u.province,
    u.landmark,
    u.postal_code,
    u.image_url,
    u.dialect,
    u.role,
    u.payment_methods,
    u.operating_days,
    u.delivery_window,
    -- Extract lat/lng from PostGIS geography
    ST_Y(u.location::geometry) AS latitude,
    ST_X(u.location::geometry) AS longitude INTO v_base
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
    'barangay',
    v_base.barangay,
    'city',
    v_base.city,
    'province',
    v_base.province,
    'landmark',
    v_base.landmark,
    'postal_code',
    v_base.postal_code,
    'image_url',
    v_base.image_url,
    'dialect',
    v_base.dialect,
    'role',
    v_base.role,
    'payment_methods',
    v_base.payment_methods,
    'operating_days',
    v_base.operating_days,
    'delivery_window',
    v_base.delivery_window,
    'latitude',
    v_base.latitude,
    'longitude',
    v_base.longitude
);
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
    uc.quality_preferences,
    uc.fav_produce,
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
    'quality_preferences',
    v_consumer.quality_preferences,
    'fav_produce',
    v_consumer.fav_produce,
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
-- ── 2a. Update base user fields (only keys present in p_data) ────
UPDATE public.users
SET name = COALESCE((p_data->>'name'), name),
    email = COALESCE((p_data->>'email'), email),
    phone = COALESCE((p_data->>'phone'), phone),
    barangay = COALESCE((p_data->>'barangay'), barangay),
    city = COALESCE((p_data->>'city'), city),
    province = COALESCE((p_data->>'province'), province),
    landmark = COALESCE((p_data->>'landmark'), landmark),
    postal_code = COALESCE((p_data->>'postal_code'), postal_code),
    image_url = COALESCE((p_data->>'image_url'), image_url),
    delivery_window = COALESCE((p_data->>'delivery_window'), delivery_window),
    dialect = COALESCE(
        (
            SELECT ARRAY(
                    SELECT jsonb_array_elements_text(p_data->'dialect')
                )
            WHERE p_data ? 'dialect'
        ),
        dialect
    ),
    payment_methods = COALESCE(
        (
            SELECT ARRAY(
                    SELECT jsonb_array_elements_text(p_data->'payment_methods')
                )
            WHERE p_data ? 'payment_methods'
        ),
        payment_methods
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
    -- Build geography only when both lat and lng are provided
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
WHERE id = p_user_id;
-- ── 2b. Update role-specific fields ───────────────────────────────
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
        quality_preferences,
        fav_produce
    )
VALUES (
        p_user_id,
        COALESCE((p_data->>'consumer_id'), ''),
        (p_data->>'consumer_segment'),
        (p_data->>'cooking_frequency'),
        CASE
            WHEN p_data ? 'quality_preferences' THEN ARRAY(
                SELECT jsonb_array_elements_text(p_data->'quality_preferences')
            )
            ELSE NULL
        END,
        CASE
            WHEN p_data ? 'fav_produce' THEN ARRAY(
                SELECT jsonb_array_elements_text(p_data->'fav_produce')
            )
            ELSE NULL
        END
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
    quality_preferences = COALESCE(
        EXCLUDED.quality_preferences,
        user_consumers.quality_preferences
    ),
    fav_produce = COALESCE(
        EXCLUDED.fav_produce,
        user_consumers.fav_produce
    );
END IF;
RETURN jsonb_build_object('success', true, 'role', LOWER(v_user_role));
ELSE RAISE EXCEPTION 'Unknown mode: %. Use ''get'' or ''update''.',
p_mode;
END IF;
END;
$$;
-- Grant execution to authenticated users only
REVOKE ALL ON FUNCTION public.manage_profile(UUID, TEXT, JSONB)
FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.manage_profile(UUID, TEXT, JSONB) TO authenticated;