-- Fix Silver Schema Exposure
-- This migration ensures Silver schema tables are properly exposed to the Supabase API

-- ============================================================================
-- DROP AND RECREATE SILVER TABLES IN PUBLIC SCHEMA
-- ============================================================================

-- First, let's create the Silver tables in the public schema for dashboard access
-- This is a temporary solution to ensure dashboard compatibility

-- 1. Shows Table
CREATE TABLE IF NOT EXISTS public.silver_shows (
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

-- 2. Setlists Table
CREATE TABLE IF NOT EXISTS public.silver_setlists (
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

-- 3. Venues Table
CREATE TABLE IF NOT EXISTS public.silver_venues (
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

-- 4. Latest Table
CREATE TABLE IF NOT EXISTS public.silver_latest (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id UUID REFERENCES raw_data.latest(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Metadata Table
CREATE TABLE IF NOT EXISTS public.silver_metadata (
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

-- 6. Links Table
CREATE TABLE IF NOT EXISTS public.silver_links (
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

-- 7. Uploads Table
CREATE TABLE IF NOT EXISTS public.silver_uploads (
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

-- 8. Appearances Table
CREATE TABLE IF NOT EXISTS public.silver_appearances (
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

-- 9. Jamcharts Table
CREATE TABLE IF NOT EXISTS public.silver_jamcharts (
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

-- ============================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Shows indexes
CREATE INDEX IF NOT EXISTS idx_silver_shows_date ON public.silver_shows(date);
CREATE INDEX IF NOT EXISTS idx_silver_shows_venue ON public.silver_shows(venue_name);
CREATE INDEX IF NOT EXISTS idx_silver_shows_city ON public.silver_shows(city);
CREATE INDEX IF NOT EXISTS idx_silver_shows_external_id ON public.silver_shows(external_id);

-- Setlists indexes
CREATE INDEX IF NOT EXISTS idx_silver_setlists_show_id ON public.silver_setlists(show_id);
CREATE INDEX IF NOT EXISTS idx_silver_setlists_song_name ON public.silver_setlists(song_name);
CREATE INDEX IF NOT EXISTS idx_silver_setlists_position ON public.silver_setlists(position);
CREATE INDEX IF NOT EXISTS idx_silver_setlists_external_id ON public.silver_setlists(external_id);

-- Venues indexes
CREATE INDEX IF NOT EXISTS idx_silver_venues_name ON public.silver_venues(name);
CREATE INDEX IF NOT EXISTS idx_silver_venues_city ON public.silver_venues(city);
CREATE INDEX IF NOT EXISTS idx_silver_venues_state ON public.silver_venues(state);
CREATE INDEX IF NOT EXISTS idx_silver_venues_external_id ON public.silver_venues(external_id);

-- Latest indexes
CREATE INDEX IF NOT EXISTS idx_silver_latest_type ON public.silver_latest(type);
CREATE INDEX IF NOT EXISTS idx_silver_latest_external_id ON public.silver_latest(external_id);

-- Metadata indexes
CREATE INDEX IF NOT EXISTS idx_silver_metadata_key ON public.silver_metadata(key);
CREATE INDEX IF NOT EXISTS idx_silver_metadata_external_id ON public.silver_metadata(external_id);

-- Links indexes
CREATE INDEX IF NOT EXISTS idx_silver_links_url ON public.silver_links(url);
CREATE INDEX IF NOT EXISTS idx_silver_links_type ON public.silver_links(link_type);
CREATE INDEX IF NOT EXISTS idx_silver_links_external_id ON public.silver_links(external_id);

-- Uploads indexes
CREATE INDEX IF NOT EXISTS idx_silver_uploads_filename ON public.silver_uploads(filename);
CREATE INDEX IF NOT EXISTS idx_silver_uploads_type ON public.silver_uploads(file_type);
CREATE INDEX IF NOT EXISTS idx_silver_uploads_external_id ON public.silver_uploads(external_id);

-- Appearances indexes
CREATE INDEX IF NOT EXISTS idx_silver_appearances_show_id ON public.silver_appearances(show_id);
CREATE INDEX IF NOT EXISTS idx_silver_appearances_song_id ON public.silver_appearances(song_id);
CREATE INDEX IF NOT EXISTS idx_silver_appearances_external_id ON public.silver_appearances(external_id);

-- Jamcharts indexes
CREATE INDEX IF NOT EXISTS idx_silver_jamcharts_song_name ON public.silver_jamcharts(song_name);
CREATE INDEX IF NOT EXISTS idx_silver_jamcharts_song_id ON public.silver_jamcharts(song_id);
CREATE INDEX IF NOT EXISTS idx_silver_jamcharts_type ON public.silver_jamcharts(jam_type);
CREATE INDEX IF NOT EXISTS idx_silver_jamcharts_external_id ON public.silver_jamcharts(external_id);

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions on new tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE public.silver_shows IS 'Cleaned show data from Bronze layer';
COMMENT ON TABLE public.silver_setlists IS 'Cleaned setlist data from Bronze layer';
COMMENT ON TABLE public.silver_venues IS 'Cleaned venue data from Bronze layer';
COMMENT ON TABLE public.silver_latest IS 'Cleaned latest data from Bronze layer';
COMMENT ON TABLE public.silver_metadata IS 'Cleaned metadata from Bronze layer';
COMMENT ON TABLE public.silver_links IS 'Cleaned links data from Bronze layer';
COMMENT ON TABLE public.silver_uploads IS 'Cleaned uploads data from Bronze layer';
COMMENT ON TABLE public.silver_appearances IS 'Cleaned appearances data from Bronze layer';
COMMENT ON TABLE public.silver_jamcharts IS 'Cleaned jamcharts data from Bronze layer';

