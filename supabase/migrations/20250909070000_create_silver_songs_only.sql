-- Create Silver Layer - Songs Table Only (Proof of Concept)
-- This migration creates the silver schema with songs table and ETL functions
-- Designed to be scalable for adding more tables later

-- ============================================================================
-- CREATE SILVER SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS silver;
COMMENT ON SCHEMA silver IS 'Silver layer: Cleaned, validated, structured data from Bronze layer';

-- ============================================================================
-- CREATE SILVER SONGS TABLE
-- ============================================================================

CREATE TABLE silver.songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  is_original BOOLEAN NOT NULL DEFAULT false,
  original_artist TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.songs(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.songs IS 'Cleaned song catalog data';
COMMENT ON COLUMN silver.songs.external_id IS 'Original ID from ElGoose API';
COMMENT ON COLUMN silver.songs.source_raw_id IS 'Reference to raw_data.songs record';

-- ============================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_silver_songs_name ON silver.songs(name);
CREATE INDEX idx_silver_songs_slug ON silver.songs(slug);
CREATE INDEX idx_silver_songs_original ON silver.songs(is_original);
CREATE INDEX idx_silver_songs_artist ON silver.songs(original_artist);
CREATE INDEX idx_silver_songs_external_id ON silver.songs(external_id);
CREATE INDEX idx_silver_songs_processed_at ON silver.songs(processed_at);

-- ============================================================================
-- CREATE PROCESSING STATUS TABLES
-- ============================================================================

-- Processing status table (if not exists)
CREATE TABLE IF NOT EXISTS processing_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  layer TEXT NOT NULL, -- 'bronze', 'silver', 'gold'
  status TEXT NOT NULL, -- 'pending', 'processing', 'completed', 'failed'
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  records_processed INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE processing_status IS 'Tracks processing status of each table and layer';

-- ============================================================================
-- CREATE SONGS ETL FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_songs()
RETURNS TABLE (
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER
) AS $$
DECLARE
  start_time TIMESTAMP;
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  start_time := clock_timestamp();
  
  -- Insert/update songs from raw data
  INSERT INTO silver.songs (
    external_id, name, slug, is_original, original_artist,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'name' as name,
    data->>'slug' as slug,
    COALESCE((data->>'isoriginal')::boolean, false) as is_original,
    data->>'original_artist' as original_artist,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.songs
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    is_original = EXCLUDED.is_original,
    original_artist = EXCLUDED.original_artist,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.songs 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM silver.songs 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  -- Update processing status
  INSERT INTO processing_status (table_name, layer, status, records_processed, completed_at)
  VALUES ('songs', 'silver', 'completed', processed_count, NOW());
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION silver.process_songs() IS 'Process songs from bronze to silver layer';

-- ============================================================================
-- CREATE SCALABLE MASTER ETL FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_all_tables()
RETURNS TABLE (
  table_name TEXT,
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER,
  status TEXT
) AS $$
DECLARE
  result RECORD;
BEGIN
  -- Process songs (only table available for now)
  FOR result IN SELECT * FROM silver.process_songs() LOOP
    RETURN QUERY SELECT 'songs', result.processed_count, result.error_count, 
                        result.processing_time_ms, 'completed';
  END LOOP;
  
  -- TODO: Add more tables here as they are implemented
  -- FOR result IN SELECT * FROM silver.process_shows() LOOP
  --   RETURN QUERY SELECT 'shows', result.processed_count, result.error_count, 
  --                       result.processing_time_ms, 'completed';
  -- END LOOP;
  
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION silver.process_all_tables() IS 'Master ETL function - processes all available tables (currently songs only)';

-- ============================================================================
-- CREATE MONITORING VIEW
-- ============================================================================

-- View for monitoring silver layer processing
CREATE OR REPLACE VIEW silver_processing_status AS
SELECT 
  'silver' as layer,
  'songs' as table_name,
  COUNT(*) as total_records,
  MAX(processed_at) as latest_processing,
  COUNT(*) FILTER (WHERE processed_at > NOW() - INTERVAL '1 hour') as recent_records
FROM silver.songs;

COMMENT ON VIEW silver_processing_status IS 'Monitor silver layer processing status';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on silver schema to default roles
GRANT USAGE ON SCHEMA silver TO anon, authenticated;

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA silver TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO authenticated;

-- Grant read permissions to anon users
GRANT SELECT ON ALL TABLES IN SCHEMA silver TO anon;

-- Grant permissions to processing tables
GRANT SELECT, INSERT, UPDATE ON processing_status TO anon, authenticated;

-- Grant access to monitoring views
GRANT SELECT ON silver_processing_status TO anon, authenticated;

-- ============================================================================
-- COMMENTS AND DOCUMENTATION
-- ============================================================================

COMMENT ON SCHEMA silver IS 'Silver layer: Cleaned, validated, structured data from Bronze layer';
COMMENT ON FUNCTION silver.process_songs() IS 'Process songs from bronze to silver layer';
COMMENT ON FUNCTION silver.process_all_tables() IS 'Master ETL function - processes all available tables (currently songs only)';
