-- Complete Silver Layer Implementation
-- This migration creates all remaining Silver layer tables and ETL functions
-- Building on the existing songs table to complete the full Silver layer

-- ============================================================================
-- CREATE REMAINING SILVER LAYER TABLES
-- ============================================================================

-- 1. Shows Table
CREATE TABLE silver.shows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  date DATE NOT NULL,
  venue_name TEXT,
  venue_id TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  show_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.shows(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.shows IS 'Cleaned show data from Bronze layer';
COMMENT ON COLUMN silver.shows.external_id IS 'Original show ID from ElGoose API';

-- 2. Setlists Table
CREATE TABLE silver.setlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  show_id TEXT NOT NULL,
  song_name TEXT NOT NULL,
  song_id TEXT NOT NULL,
  position INTEGER,
  is_original BOOLEAN NOT NULL DEFAULT false,
  original_artist TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.setlists(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.setlists IS 'Cleaned setlist data from Bronze layer';
COMMENT ON COLUMN silver.setlists.external_id IS 'Original setlist ID from ElGoose API';

-- 3. Venues Table
CREATE TABLE silver.venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  country TEXT,
  capacity INTEGER,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.venues(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.venues IS 'Cleaned venue data from Bronze layer';
COMMENT ON COLUMN silver.venues.external_id IS 'Original venue ID from ElGoose API';

-- 4. Latest Table
CREATE TABLE silver.latest (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.latest(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.latest IS 'Cleaned latest data from Bronze layer';
COMMENT ON COLUMN silver.latest.external_id IS 'Original latest ID from ElGoose API';

-- 5. Metadata Table
CREATE TABLE silver.metadata (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  key TEXT NOT NULL,
  value TEXT,
  data_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.metadata(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.metadata IS 'Cleaned metadata from Bronze layer';
COMMENT ON COLUMN silver.metadata.external_id IS 'Original metadata ID from ElGoose API';

-- 6. Links Table
CREATE TABLE silver.links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  url TEXT NOT NULL,
  title TEXT,
  description TEXT,
  link_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.links(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.links IS 'Cleaned links data from Bronze layer';
COMMENT ON COLUMN silver.links.external_id IS 'Original link ID from ElGoose API';

-- 7. Uploads Table
CREATE TABLE silver.uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  file_type TEXT,
  file_size INTEGER,
  upload_date TIMESTAMP WITH TIME ZONE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.uploads(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.uploads IS 'Cleaned uploads data from Bronze layer';
COMMENT ON COLUMN silver.uploads.external_id IS 'Original upload ID from ElGoose API';

-- 8. Appearances Table
CREATE TABLE silver.appearances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  show_id TEXT NOT NULL,
  song_id TEXT NOT NULL,
  position INTEGER,
  is_original BOOLEAN NOT NULL DEFAULT false,
  original_artist TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.appearances(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.appearances IS 'Cleaned appearances data from Bronze layer';
COMMENT ON COLUMN silver.appearances.external_id IS 'Original appearance ID from ElGoose API';

-- 9. Jamcharts Table
CREATE TABLE silver.jamcharts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  song_name TEXT NOT NULL,
  song_id TEXT NOT NULL,
  jam_type TEXT,
  duration_seconds INTEGER,
  rating DECIMAL(3, 2),
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.jamcharts(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE silver.jamcharts IS 'Cleaned jamcharts data from Bronze layer';
COMMENT ON COLUMN silver.jamcharts.external_id IS 'Original jamchart ID from ElGoose API';

-- ============================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Shows indexes
CREATE INDEX idx_silver_shows_date ON silver.shows(date);
CREATE INDEX idx_silver_shows_venue ON silver.shows(venue_name);
CREATE INDEX idx_silver_shows_city ON silver.shows(city);
CREATE INDEX idx_silver_shows_external_id ON silver.shows(external_id);

-- Setlists indexes
CREATE INDEX idx_silver_setlists_show_id ON silver.setlists(show_id);
CREATE INDEX idx_silver_setlists_song_name ON silver.setlists(song_name);
CREATE INDEX idx_silver_setlists_position ON silver.setlists(position);
CREATE INDEX idx_silver_setlists_external_id ON silver.setlists(external_id);

-- Venues indexes
CREATE INDEX idx_silver_venues_name ON silver.venues(name);
CREATE INDEX idx_silver_venues_city ON silver.venues(city);
CREATE INDEX idx_silver_venues_state ON silver.venues(state);
CREATE INDEX idx_silver_venues_external_id ON silver.venues(external_id);

-- Latest indexes
CREATE INDEX idx_silver_latest_type ON silver.latest(type);
CREATE INDEX idx_silver_latest_external_id ON silver.latest(external_id);

-- Metadata indexes
CREATE INDEX idx_silver_metadata_key ON silver.metadata(key);
CREATE INDEX idx_silver_metadata_external_id ON silver.metadata(external_id);

-- Links indexes
CREATE INDEX idx_silver_links_url ON silver.links(url);
CREATE INDEX idx_silver_links_type ON silver.links(link_type);
CREATE INDEX idx_silver_links_external_id ON silver.links(external_id);

-- Uploads indexes
CREATE INDEX idx_silver_uploads_filename ON silver.uploads(filename);
CREATE INDEX idx_silver_uploads_type ON silver.uploads(file_type);
CREATE INDEX idx_silver_uploads_external_id ON silver.uploads(external_id);

-- Appearances indexes
CREATE INDEX idx_silver_appearances_show_id ON silver.appearances(show_id);
CREATE INDEX idx_silver_appearances_song_id ON silver.appearances(song_id);
CREATE INDEX idx_silver_appearances_external_id ON silver.appearances(external_id);

-- Jamcharts indexes
CREATE INDEX idx_silver_jamcharts_song_name ON silver.jamcharts(song_name);
CREATE INDEX idx_silver_jamcharts_song_id ON silver.jamcharts(song_id);
CREATE INDEX idx_silver_jamcharts_type ON silver.jamcharts(jam_type);
CREATE INDEX idx_silver_jamcharts_external_id ON silver.jamcharts(external_id);

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions on new tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA silver TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA silver TO anon;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO authenticated;

