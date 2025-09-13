-- Fix Silver ETL mapping for venues to use correct raw JSON keys

CREATE OR REPLACE FUNCTION silver.process_venues()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMPTZ := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  -- Insert/update venues from raw data
  INSERT INTO silver.venues (
    external_id, name, city, state, country, capacity,
    latitude, longitude, created_at, updated_at, source_raw_id
  )
  SELECT 
    -- Keep external_id from Bronze row (already normalized during ingestion)
    external_id,
    -- Name can appear under different keys in the raw payload
    COALESCE(data->>'venuename', data->>'name', data->>'venue', data->>'venue_name') AS name,
    COALESCE(data->>'city', data->>'venue_city')                                     AS city,
    COALESCE(data->>'state', data->>'venue_state', data->>'region')                  AS state,
    COALESCE(data->>'country', data->>'venue_country')                               AS country,
    NULLIF(data->>'capacity','')::integer                                            AS capacity,
    NULLIF(data->>'latitude','')::decimal                                            AS latitude,
    NULLIF(data->>'longitude','')::decimal                                           AS longitude,
    NULLIF(data->>'created_at','')::timestamptz                                      AS created_at,
    NULLIF(data->>'updated_at','')::timestamptz                                      AS updated_at,
    id                                                                               AS source_raw_id
  FROM raw_data.venues
  WHERE is_processed = false
    AND COALESCE(data->>'venuename', data->>'name', data->>'venue', data->>'venue_name') IS NOT NULL
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
    (EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;


