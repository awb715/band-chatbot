-- Fix Remaining ETL Issues
-- This migration fixes the setlists and appearances ETL functions

-- ============================================================================
-- FIX SETLISTS ETL FUNCTION
-- ============================================================================

-- Fix Process Setlists to handle duplicates properly
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
    SELECT source_raw_id FROM public.silver_setlists 
    WHERE processed_at > NOW() - INTERVAL '1 hour'
  );
  
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

-- ============================================================================
-- FIX APPEARANCES ETL FUNCTION
-- ============================================================================

-- Fix Process Appearances to handle missing song_id
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
    SELECT source_raw_id FROM public.silver_appearances 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UPDATE SILVER APPEARANCES TABLE SCHEMA
-- ============================================================================

-- Make song_id nullable since it's not available in appearances data
ALTER TABLE public.silver_appearances ALTER COLUMN song_id DROP NOT NULL;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.process_setlists() IS 'Process setlists from bronze to silver layer - fixed duplicate handling';
COMMENT ON FUNCTION public.process_appearances() IS 'Process appearances from bronze to silver layer - fixed missing song_id';

