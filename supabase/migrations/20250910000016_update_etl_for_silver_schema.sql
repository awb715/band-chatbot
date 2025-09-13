-- Update ETL Functions for Silver Schema
-- This migration updates all ETL functions to work with the silver schema

-- ============================================================================
-- UPDATE ETL FUNCTIONS TO USE SILVER SCHEMA
-- ============================================================================

-- 1. Update Process Shows
CREATE OR REPLACE FUNCTION public.process_shows()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update shows from raw data
  INSERT INTO silver.shows (
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
    SELECT source_raw_id FROM silver.shows 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 2. Update Process Setlists
CREATE OR REPLACE FUNCTION public.process_setlists()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- First, reset is_processed for setlists to avoid conflicts
  UPDATE raw_data.setlists 
  SET is_processed = false 
  WHERE id IN (
    SELECT source_raw_id FROM silver.setlists 
    WHERE processed_at > NOW() - INTERVAL '1 hour'
  );
  
  -- Insert/update setlists from raw data
  INSERT INTO silver.setlists (
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
    SELECT source_raw_id FROM silver.setlists 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 3. Update Process Venues
CREATE OR REPLACE FUNCTION public.process_venues()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update venues from raw data
  INSERT INTO silver.venues (
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
    SELECT source_raw_id FROM silver.venues 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 4. Update Process Latest
CREATE OR REPLACE FUNCTION public.process_latest()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update latest from raw data
  INSERT INTO silver.latest (
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
    SELECT source_raw_id FROM silver.latest 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 5. Update Process Metadata
CREATE OR REPLACE FUNCTION public.process_metadata()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update metadata from raw data
  INSERT INTO silver.metadata (
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
    SELECT source_raw_id FROM silver.metadata 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 6. Update Process Links
CREATE OR REPLACE FUNCTION public.process_links()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update links from raw data
  INSERT INTO silver.links (
    external_id, url, title, description, link_type, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'url' as url,
    data->>'title' as title,
    data->>'description' as description,
    data->>'type' as link_type,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.links
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    url = EXCLUDED.url,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    link_type = EXCLUDED.link_type,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.links 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM silver.links 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 7. Update Process Uploads
CREATE OR REPLACE FUNCTION public.process_uploads()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update uploads from raw data
  INSERT INTO silver.uploads (
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
    SELECT source_raw_id FROM silver.uploads 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 8. Update Process Appearances
CREATE OR REPLACE FUNCTION public.process_appearances()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update appearances from raw data
  INSERT INTO silver.appearances (
    external_id, show_id, song_id, position, is_original, original_artist,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    (data->>'show_id')::text as show_id,
    'N/A' as song_id, -- Use placeholder since not available in appearances data
    NULL as position, -- Not available in appearances data
    false as is_original, -- Not available in appearances data
    data->>'personname' as original_artist, -- Use personname as original_artist
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
    SELECT source_raw_id FROM silver.appearances 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 9. Update Process Jamcharts
CREATE OR REPLACE FUNCTION public.process_jamcharts()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update jamcharts from raw data
  INSERT INTO silver.jamcharts (
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
    SELECT source_raw_id FROM silver.jamcharts 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UPDATE MASTER ETL FUNCTION
-- ============================================================================

-- Master function to process all Silver layer tables
CREATE OR REPLACE FUNCTION public.process_all_tables()
RETURNS TABLE(
  table_name TEXT,
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER
) AS $$
DECLARE
  start_time TIMESTAMP WITH TIME ZONE := clock_timestamp();
  result RECORD;
BEGIN
  -- Process all tables
  FOR result IN
    SELECT 'shows' as table_name, * FROM public.process_shows()
    UNION ALL
    SELECT 'setlists' as table_name, * FROM public.process_setlists()
    UNION ALL
    SELECT 'venues' as table_name, * FROM public.process_venues()
    UNION ALL
    SELECT 'latest' as table_name, * FROM public.process_latest()
    UNION ALL
    SELECT 'metadata' as table_name, * FROM public.process_metadata()
    UNION ALL
    SELECT 'links' as table_name, * FROM public.process_links()
    UNION ALL
    SELECT 'uploads' as table_name, * FROM public.process_uploads()
    UNION ALL
    SELECT 'appearances' as table_name, * FROM public.process_appearances()
    UNION ALL
    SELECT 'jamcharts' as table_name, * FROM public.process_jamcharts()
  LOOP
    RETURN QUERY SELECT result.table_name, result.processed_count, result.error_count, result.processing_time_ms;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.process_shows() IS 'Process shows from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_setlists() IS 'Process setlists from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_venues() IS 'Process venues from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_latest() IS 'Process latest data from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_metadata() IS 'Process metadata from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_links() IS 'Process links from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_uploads() IS 'Process uploads from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_appearances() IS 'Process appearances from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_jamcharts() IS 'Process jamcharts from bronze to silver layer - updated for silver schema';
COMMENT ON FUNCTION public.process_all_tables() IS 'Process all silver layer tables from bronze layer - updated for silver schema';

