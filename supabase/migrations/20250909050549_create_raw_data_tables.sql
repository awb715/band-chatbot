-- Create raw_data schema for storing raw API responses
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Grant permissions to the schema
GRANT USAGE ON SCHEMA raw_data TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA raw_data TO anon, authenticated;

-- Create generic raw data table pattern
-- This will be used as a template for all endpoint tables

-- Setlists data (song-by-song entries for shows)
CREATE TABLE raw_data.setlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,                    -- Original ID from API
  data JSONB NOT NULL,                 -- Raw JSON response
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,            -- When data was processed
  is_processed BOOLEAN DEFAULT FALSE,  -- Processing status
  source_url TEXT NOT NULL,            -- Original API URL
  version INTEGER DEFAULT 1,           -- For tracking data changes
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Shows data (one row per show)
CREATE TABLE raw_data.shows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Songs data (song catalog)
CREATE TABLE raw_data.songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Venues data (venue directory)
CREATE TABLE raw_data.venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Jamcharts data (curated performance notes)
CREATE TABLE raw_data.jamcharts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Latest data (recent setlist lines)
CREATE TABLE raw_data.latest (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Metadata data (extra metadata tied to songs/setlists)
CREATE TABLE raw_data.metadata (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Links data (external links for shows)
CREATE TABLE raw_data.links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Uploads data (show posters/featured media)
CREATE TABLE raw_data.uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Appearances data (which person appeared at which show)
CREATE TABLE raw_data.appearances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,
  data JSONB NOT NULL,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  is_processed BOOLEAN DEFAULT FALSE,
  source_url TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient querying
-- Setlists indexes
CREATE INDEX idx_setlists_external_id ON raw_data.setlists (external_id);
CREATE INDEX idx_setlists_received_at ON raw_data.setlists (received_at);
CREATE INDEX idx_setlists_processed ON raw_data.setlists (is_processed);
CREATE INDEX idx_setlists_data_gin ON raw_data.setlists USING GIN (data);
CREATE INDEX idx_setlists_source_url ON raw_data.setlists (source_url);

-- Shows indexes
CREATE INDEX idx_shows_external_id ON raw_data.shows (external_id);
CREATE INDEX idx_shows_received_at ON raw_data.shows (received_at);
CREATE INDEX idx_shows_processed ON raw_data.shows (is_processed);
CREATE INDEX idx_shows_data_gin ON raw_data.shows USING GIN (data);
CREATE INDEX idx_shows_source_url ON raw_data.shows (source_url);

-- Songs indexes
CREATE INDEX idx_songs_external_id ON raw_data.songs (external_id);
CREATE INDEX idx_songs_received_at ON raw_data.songs (received_at);
CREATE INDEX idx_songs_processed ON raw_data.songs (is_processed);
CREATE INDEX idx_songs_data_gin ON raw_data.songs USING GIN (data);
CREATE INDEX idx_songs_source_url ON raw_data.songs (source_url);

-- Venues indexes
CREATE INDEX idx_venues_external_id ON raw_data.venues (external_id);
CREATE INDEX idx_venues_received_at ON raw_data.venues (received_at);
CREATE INDEX idx_venues_processed ON raw_data.venues (is_processed);
CREATE INDEX idx_venues_data_gin ON raw_data.venues USING GIN (data);
CREATE INDEX idx_venues_source_url ON raw_data.venues (source_url);

-- Jamcharts indexes
CREATE INDEX idx_jamcharts_external_id ON raw_data.jamcharts (external_id);
CREATE INDEX idx_jamcharts_received_at ON raw_data.jamcharts (received_at);
CREATE INDEX idx_jamcharts_processed ON raw_data.jamcharts (is_processed);
CREATE INDEX idx_jamcharts_data_gin ON raw_data.jamcharts USING GIN (data);
CREATE INDEX idx_jamcharts_source_url ON raw_data.jamcharts (source_url);

-- Latest indexes
CREATE INDEX idx_latest_external_id ON raw_data.latest (external_id);
CREATE INDEX idx_latest_received_at ON raw_data.latest (received_at);
CREATE INDEX idx_latest_processed ON raw_data.latest (is_processed);
CREATE INDEX idx_latest_data_gin ON raw_data.latest USING GIN (data);
CREATE INDEX idx_latest_source_url ON raw_data.latest (source_url);

-- Metadata indexes
CREATE INDEX idx_metadata_external_id ON raw_data.metadata (external_id);
CREATE INDEX idx_metadata_received_at ON raw_data.metadata (received_at);
CREATE INDEX idx_metadata_processed ON raw_data.metadata (is_processed);
CREATE INDEX idx_metadata_data_gin ON raw_data.metadata USING GIN (data);
CREATE INDEX idx_metadata_source_url ON raw_data.metadata (source_url);

-- Links indexes
CREATE INDEX idx_links_external_id ON raw_data.links (external_id);
CREATE INDEX idx_links_received_at ON raw_data.links (received_at);
CREATE INDEX idx_links_processed ON raw_data.links (is_processed);
CREATE INDEX idx_links_data_gin ON raw_data.links USING GIN (data);
CREATE INDEX idx_links_source_url ON raw_data.links (source_url);

-- Uploads indexes
CREATE INDEX idx_uploads_external_id ON raw_data.uploads (external_id);
CREATE INDEX idx_uploads_received_at ON raw_data.uploads (received_at);
CREATE INDEX idx_uploads_processed ON raw_data.uploads (is_processed);
CREATE INDEX idx_uploads_data_gin ON raw_data.uploads USING GIN (data);
CREATE INDEX idx_uploads_source_url ON raw_data.uploads (source_url);

-- Appearances indexes
CREATE INDEX idx_appearances_external_id ON raw_data.appearances (external_id);
CREATE INDEX idx_appearances_received_at ON raw_data.appearances (received_at);
CREATE INDEX idx_appearances_processed ON raw_data.appearances (is_processed);
CREATE INDEX idx_appearances_data_gin ON raw_data.appearances USING GIN (data);
CREATE INDEX idx_appearances_source_url ON raw_data.appearances (source_url);

-- Create helper functions
-- Function to update processed status
CREATE OR REPLACE FUNCTION raw_data.mark_as_processed(table_name TEXT, record_id UUID)
RETURNS VOID AS $$
BEGIN
  EXECUTE format('UPDATE raw_data.%I SET is_processed = TRUE, processed_at = NOW() WHERE id = %L', table_name, record_id);
END;
$$ LANGUAGE plpgsql;

-- Function to get unprocessed records
CREATE OR REPLACE FUNCTION raw_data.get_unprocessed_records(table_name TEXT, limit_count INTEGER DEFAULT 100)
RETURNS TABLE (id UUID, data JSONB) AS $$
BEGIN
  RETURN QUERY EXECUTE format('SELECT id, data FROM raw_data.%I WHERE is_processed = FALSE ORDER BY received_at LIMIT %s', table_name, limit_count);
END;
$$ LANGUAGE plpgsql;

-- Function to get record count by processing status
CREATE OR REPLACE FUNCTION raw_data.get_processing_stats(table_name TEXT)
RETURNS TABLE (total_records BIGINT, processed_records BIGINT, unprocessed_records BIGINT) AS $$
BEGIN
  RETURN QUERY EXECUTE format('
    SELECT 
      COUNT(*) as total_records,
      COUNT(*) FILTER (WHERE is_processed = TRUE) as processed_records,
      COUNT(*) FILTER (WHERE is_processed = FALSE) as unprocessed_records
    FROM raw_data.%I', table_name);
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old processed records (optional)
CREATE OR REPLACE FUNCTION raw_data.cleanup_old_records(table_name TEXT, days_old INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  EXECUTE format('
    DELETE FROM raw_data.%I 
    WHERE is_processed = TRUE 
    AND processed_at < NOW() - INTERVAL ''%s days''', table_name, days_old);
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE OR REPLACE FUNCTION raw_data.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to all tables
CREATE TRIGGER update_setlists_updated_at BEFORE UPDATE ON raw_data.setlists FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_shows_updated_at BEFORE UPDATE ON raw_data.shows FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_songs_updated_at BEFORE UPDATE ON raw_data.songs FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_venues_updated_at BEFORE UPDATE ON raw_data.venues FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_jamcharts_updated_at BEFORE UPDATE ON raw_data.jamcharts FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_latest_updated_at BEFORE UPDATE ON raw_data.latest FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_metadata_updated_at BEFORE UPDATE ON raw_data.metadata FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_links_updated_at BEFORE UPDATE ON raw_data.links FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_uploads_updated_at BEFORE UPDATE ON raw_data.uploads FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();
CREATE TRIGGER update_appearances_updated_at BEFORE UPDATE ON raw_data.appearances FOR EACH ROW EXECUTE FUNCTION raw_data.update_updated_at_column();

-- Enable RLS on all tables
ALTER TABLE raw_data.setlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.shows ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.jamcharts ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.latest ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.links ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.appearances ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (allow all for now, can be restricted later)
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.setlists FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.shows FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.songs FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.venues FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.jamcharts FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.latest FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.metadata FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.links FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.uploads FOR ALL USING (true);
CREATE POLICY "Allow all operations on raw_data tables" ON raw_data.appearances FOR ALL USING (true);
