-- Fix Silver ETL mapping for latest to align with raw JSON structure

CREATE OR REPLACE FUNCTION silver.process_latest()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMPTZ := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  INSERT INTO silver.latest (
    external_id, type, data, created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    COALESCE(data->>'type', data->>'settype', 'unknown')                    AS type,
    data                                                                     AS data,
    COALESCE(NULLIF(data->>'created_at','')::timestamptz,
             NULLIF(data->>'showdate','')::date)::timestamptz               AS created_at,
    NULLIF(data->>'updated_at','')::timestamptz                              AS updated_at,
    id                                                                       AS source_raw_id
  FROM raw_data.latest
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    type = EXCLUDED.type,
    data = EXCLUDED.data,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();

  GET DIAGNOSTICS processed_count = ROW_COUNT;

  UPDATE raw_data.latest
  SET is_processed = true
  WHERE id IN (
    SELECT source_raw_id FROM silver.latest 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );

  RETURN QUERY SELECT processed_count,
                       error_count,
                       (EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;


