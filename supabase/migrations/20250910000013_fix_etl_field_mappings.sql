-- Fix ETL Field Mappings
-- This migration fixes the ETL functions to use the correct field names from the raw data

-- ============================================================================
-- FIX ETL FUNCTIONS WITH CORRECT FIELD MAPPINGS
-- ============================================================================

-- 1. Fix Process Shows
CREATE OR REPLACE FUNCTION public.process_shows()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update shows from raw data
  INSERT INTO public.silver_shows (
    external_id, date, venue_name, venue_id, city, state, country,
    show_notes, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    (data->>'showdate')::date as date,
    data->>'venuename' as venue_name,
    (data->>'venue_id')::text as venue_id,
    data->>'city' as city,
    data->>'state' as state,
    data->>'country' as country,
    data->>'shownotes' as show_notes,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.shows
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    date = EXCLUDED.date,
    venue_name = EXCLUDED.venue_name,
    venue_id = EXCLUDED.venue_id,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    country = EXCLUDED.country,
    show_notes = EXCLUDED.show_notes,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.shows 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_shows 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 2. Fix Process Setlists
CREATE OR REPLACE FUNCTION public.process_setlists()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update setlists from raw data
  INSERT INTO public.silver_setlists (
    external_id, show_id, song_name, song_id, position,
    is_original, original_artist, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    (data->>'show_id')::text as show_id,
    data->>'songname' as song_name,
    (data->>'song_id')::text as song_id,
    (data->>'position')::integer as position,
    COALESCE((data->>'isoriginal')::boolean, false) as is_original,
    data->>'original_artist' as original_artist,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.setlists
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    show_id = EXCLUDED.show_id,
    song_name = EXCLUDED.song_name,
    song_id = EXCLUDED.song_id,
    position = EXCLUDED.position,
    is_original = EXCLUDED.is_original,
    original_artist = EXCLUDED.original_artist,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.setlists 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_setlists 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 3. Fix Process Venues
CREATE OR REPLACE FUNCTION public.process_venues()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update venues from raw data
  INSERT INTO public.silver_venues (
    external_id, name, city, state, country, capacity,
    latitude, longitude, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'venuename' as name,
    data->>'city' as city,
    data->>'state' as state,
    data->>'country' as country,
    (data->>'capacity')::integer as capacity,
    (data->>'latitude')::decimal as latitude,
    (data->>'longitude')::decimal as longitude,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.venues
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    name = EXCLUDED.name,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    country = EXCLUDED.country,
    capacity = EXCLUDED.capacity,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.venues 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_venues 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 4. Fix Process Latest
CREATE OR REPLACE FUNCTION public.process_latest()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update latest from raw data
  INSERT INTO public.silver_latest (
    external_id, type, data, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'settype' as type,
    data as data,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.latest
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    type = EXCLUDED.type,
    data = EXCLUDED.data,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.latest 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_latest 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 5. Fix Process Metadata
CREATE OR REPLACE FUNCTION public.process_metadata()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update metadata from raw data
  INSERT INTO public.silver_metadata (
    external_id, key, value, data_type, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'meta_name' as key,
    data->>'value' as value,
    data->>'metadata_slug' as data_type,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.metadata
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    key = EXCLUDED.key,
    value = EXCLUDED.value,
    data_type = EXCLUDED.data_type,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.metadata 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_metadata 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 6. Fix Process Uploads
CREATE OR REPLACE FUNCTION public.process_uploads()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update uploads from raw data
  INSERT INTO public.silver_uploads (
    external_id, filename, file_type, file_size, upload_date,
    description, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'img_name' as filename,
    data->>'upload_type' as file_type,
    NULL as file_size, -- Not available in raw data
    (data->>'created_at')::timestamp with time zone as upload_date,
    data->>'attribution' as description,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'created_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.uploads
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    filename = EXCLUDED.filename,
    file_type = EXCLUDED.file_type,
    file_size = EXCLUDED.file_size,
    upload_date = EXCLUDED.upload_date,
    description = EXCLUDED.description,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.uploads 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_uploads 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 7. Fix Process Appearances
CREATE OR REPLACE FUNCTION public.process_appearances()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update appearances from raw data
  INSERT INTO public.silver_appearances (
    external_id, show_id, song_id, position, is_original, original_artist,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    (data->>'show_id')::text as show_id,
    NULL as song_id, -- Not available in appearances data
    NULL as position, -- Not available in appearances data
    false as is_original, -- Not available in appearances data
    NULL as original_artist, -- Not available in appearances data
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'created_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.appearances
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    show_id = EXCLUDED.show_id,
    song_id = EXCLUDED.song_id,
    position = EXCLUDED.position,
    is_original = EXCLUDED.is_original,
    original_artist = EXCLUDED.original_artist,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.appearances 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_appearances 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 8. Fix Process Jamcharts
CREATE OR REPLACE FUNCTION public.process_jamcharts()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update jamcharts from raw data
  INSERT INTO public.silver_jamcharts (
    external_id, song_name, song_id, jam_type, duration_seconds,
    rating, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'songname' as song_name,
    (data->>'song_id')::text as song_id,
    data->>'jamchartnote' as jam_type,
    NULL as duration_seconds, -- Not available in raw data
    (data->>'isrecommended')::decimal as rating,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'created_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.jamcharts
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    song_name = EXCLUDED.song_name,
    song_id = EXCLUDED.song_id,
    jam_type = EXCLUDED.jam_type,
    duration_seconds = EXCLUDED.duration_seconds,
    rating = EXCLUDED.rating,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.jamcharts 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM public.silver_jamcharts 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.process_shows() IS 'Process shows from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_setlists() IS 'Process setlists from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_venues() IS 'Process venues from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_latest() IS 'Process latest data from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_metadata() IS 'Process metadata from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_uploads() IS 'Process uploads from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_appearances() IS 'Process appearances from bronze to silver layer - fixed field mappings';
COMMENT ON FUNCTION public.process_jamcharts() IS 'Process jamcharts from bronze to silver layer - fixed field mappings';

