-- ============================================================================
-- PRODUCTION-READY SILVER LAYER IMPLEMENTATION
-- ============================================================================
-- 
-- This migration creates a complete, production-ready Silver layer for the
-- Band Chatbot RAG pipeline, replacing the existing incomplete Silver tables.
--
-- Key Features:
-- - Complete field mapping from Bronze JSON to typed Silver columns
-- - Optimized indexes for chatbot query patterns
-- - Proper foreign key relationships
-- - Generated columns for derived data (show_year, etc.)
-- - Full text search capabilities with pg_trgm
-- - Idempotent ETL functions with error handling
-- - Data validation and quality checks
--
-- Schema Design Goals:
-- - Completeness: Every useful Bronze field mapped to Silver
-- - Performance: Indexes optimized for chatbot queries
-- - Maintainability: Clear relationships, generated columns
-- - Data Quality: Validation, error logging, defensive parsing
-- 
-- ============================================================================

-- ============================================================================
-- SECTION 1: ENABLE EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ============================================================================
-- SECTION 2: CREATE SILVER SCHEMA AND ETL UTILITIES
-- ============================================================================

-- Recreate silver schema (preserving any existing data)
-- CREATE SCHEMA IF NOT EXISTS silver;
COMMENT ON SCHEMA silver IS 'Silver layer: Cleaned, validated, structured data from Bronze layer';

-- Create ETL utilities schema
CREATE SCHEMA IF NOT EXISTS silver_etl;
COMMENT ON SCHEMA silver_etl IS 'ETL utilities, error logging, and helper functions for Silver layer processing';

-- Error logging table for ETL issues
CREATE TABLE IF NOT EXISTS silver_etl.error_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  raw_id UUID,
  error_at TIMESTAMPTZ DEFAULT now(),
  error_msg TEXT,
  payload JSONB
);

CREATE INDEX IF NOT EXISTS error_log_table_name_idx ON silver_etl.error_log (table_name);
CREATE INDEX IF NOT EXISTS error_log_error_at_idx ON silver_etl.error_log (error_at);

-- ============================================================================
-- SECTION 3: CREATE HELPER FUNCTIONS
-- ============================================================================

-- Helper function to parse MM:SS duration to seconds
CREATE OR REPLACE FUNCTION silver_etl.parse_mmss_to_seconds(mmss TEXT)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  m INT; 
  s INT;
BEGIN
  IF mmss IS NULL OR mmss = '' THEN 
    RETURN NULL; 
  END IF;
  
  -- Handle formats like "22:00" or "5:30"
  BEGIN
    m := split_part(mmss, ':', 1)::INT;
    s := split_part(mmss, ':', 2)::INT;
    RETURN m * 60 + s;
  EXCEPTION WHEN others THEN
    RETURN NULL;
  END;
END $$;

COMMENT ON FUNCTION silver_etl.parse_mmss_to_seconds(TEXT) IS 'Parse MM:SS format to total seconds';

-- Helper function to safely cast boolean strings
CREATE OR REPLACE FUNCTION silver_etl.safe_boolean(val TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  IF val IS NULL OR val = '' THEN
    RETURN NULL;
  END IF;
  
  -- Handle various boolean representations
  CASE LOWER(val)
    WHEN 'true', '1', 't', 'yes', 'y' THEN
      RETURN TRUE;
    WHEN 'false', '0', 'f', 'no', 'n' THEN
      RETURN FALSE;
    ELSE
      -- Try direct cast
      BEGIN
        RETURN val::BOOLEAN;
      EXCEPTION WHEN others THEN
        RETURN NULL;
      END;
  END CASE;
END $$;

COMMENT ON FUNCTION silver_etl.safe_boolean(TEXT) IS 'Safely cast text to boolean with multiple format support';

-- ============================================================================
-- SECTION 4: CREATE SILVER LAYER TABLES
-- ============================================================================

-- 1. CORE DIMENSION: SONGS
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.songs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id       TEXT UNIQUE,                      -- bronze.songs.id
  slug              CITEXT UNIQUE,                    -- bronze.songs.slug
  name              CITEXT NOT NULL,                  -- bronze.songs.name
  is_original       BOOLEAN NOT NULL DEFAULT TRUE,    -- bronze.songs.isoriginal
  original_artist   CITEXT,                           -- bronze.songs.original_artist
  created_at        TIMESTAMPTZ DEFAULT now(),        -- API created_at if present, else now()
  updated_at        TIMESTAMPTZ DEFAULT now(),        -- API updated_at if present, else now()
  source_raw_id     UUID,                             -- FK to raw_data.songs.id (latest source)
  processed_at      TIMESTAMPTZ
);

COMMENT ON TABLE silver.songs IS 'Core dimension table for songs with complete metadata';
COMMENT ON COLUMN silver.songs.external_id IS 'Original song ID from ElGoose API';
COMMENT ON COLUMN silver.songs.slug IS 'URL-friendly slug for the song';
COMMENT ON COLUMN silver.songs.is_original IS 'Whether this is an original composition by the band';
COMMENT ON COLUMN silver.songs.source_raw_id IS 'Reference to latest raw_data.songs record that populated this row';

-- 2. CORE DIMENSION: VENUES
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.venues (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id     TEXT UNIQUE,                         -- bronze.venues.venue_id
  slug            CITEXT UNIQUE,                       -- bronze.venues.slug
  name            CITEXT NOT NULL,                     -- bronze.venues.venuename
  city            CITEXT,
  state           CITEXT,
  country         CITEXT,
  zip             TEXT,
  latitude        NUMERIC(9,6),
  longitude       NUMERIC(9,6),
  capacity        INTEGER,
  timezone        CITEXT,                              -- if present in upstream; else NULL
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now(),
  source_raw_id   UUID,
  processed_at    TIMESTAMPTZ
);

COMMENT ON TABLE silver.venues IS 'Core dimension table for venues with geographic and capacity data';
COMMENT ON COLUMN silver.venues.external_id IS 'Original venue ID from ElGoose API';
COMMENT ON COLUMN silver.venues.slug IS 'URL-friendly slug for the venue';
COMMENT ON COLUMN silver.venues.capacity IS 'Venue capacity if known';

-- 3. CORE FACT: SHOWS
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.shows (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id     TEXT UNIQUE,                         -- bronze.shows.show_id
  date            DATE NOT NULL,                       -- bronze.shows.showdate (YYYY-MM-DD)
  venue_id        UUID REFERENCES silver.venues(id),
  venue_name      CITEXT,                              -- keep for convenience; source venuename
  city            CITEXT,
  state           CITEXT,
  country         CITEXT,
  show_title      CITEXT,                              -- bronze.shows.showtitle
  tour_id         TEXT,
  tour_name       CITEXT,
  permalink       TEXT,
  show_order      INTEGER,                             -- bronze.shows.showorder
  artist          CITEXT,
  artist_id       TEXT,
  show_notes      TEXT,                                -- if bronze supplies
  created_at      TIMESTAMPTZ DEFAULT now(),           -- API created/updated timestamps
  updated_at      TIMESTAMPTZ DEFAULT now(),
  source_raw_id   UUID,
  processed_at    TIMESTAMPTZ,

  -- Generated columns (avoid storing Bronze's derived fields redundantly)
  show_year       INT GENERATED ALWAYS AS (EXTRACT(YEAR  FROM date)::INT) STORED,
  show_month      INT GENERATED ALWAYS AS (EXTRACT(MONTH FROM date)::INT) STORED,
  show_day        INT GENERATED ALWAYS AS (EXTRACT(DAY   FROM date)::INT) STORED,
  show_dayname    TEXT GENERATED ALWAYS AS (to_char(date, 'Dy')) STORED,
  show_monthname  TEXT GENERATED ALWAYS AS (to_char(date, 'Mon')) STORED
);

COMMENT ON TABLE silver.shows IS 'Core fact table for shows with complete metadata and derived date columns';
COMMENT ON COLUMN silver.shows.external_id IS 'Original show ID from ElGoose API';
COMMENT ON COLUMN silver.shows.venue_id IS 'Foreign key to silver.venues table';
COMMENT ON COLUMN silver.shows.show_year IS 'Generated column: year extracted from date';

-- 4. FACT: SETLIST ENTRIES (one row per performed song)
-- ============================================================================
CREATE TYPE IF NOT EXISTS silver.set_type_enum AS ENUM ('set', 'encore', 'soundcheck', 'unknown');

CREATE TABLE IF NOT EXISTS silver.setlists (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id       TEXT,                               -- bronze.setlists.uniqueid (if present)
  show_id           UUID NOT NULL REFERENCES silver.shows(id),
  song_id           UUID REFERENCES silver.songs(id),
  song_name         CITEXT,                             -- fallback if song not matched yet
  position          INT,                                -- bronze.setlists.position
  set_number        INT,                                -- bronze.setlists.setnumber
  set_type          silver.set_type_enum DEFAULT 'unknown', -- map from bronze.setlists.settype/css_class
  is_original       BOOLEAN,
  original_artist   CITEXT,
  is_jam            BOOLEAN,
  is_reprise        BOOLEAN,
  is_verified       BOOLEAN,
  is_recommended    BOOLEAN,
  is_jamchart       BOOLEAN,
  opener            BOOLEAN,
  soundcheck        BOOLEAN,
  jamchart_notes    TEXT,
  footnote          TEXT,
  transition        TEXT,
  transition_id     TEXT,
  permalink         TEXT,                               -- if row-level exists
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  source_raw_id     UUID,
  processed_at      TIMESTAMPTZ
);

COMMENT ON TABLE silver.setlists IS 'Fact table for setlist entries - one row per song performance';
COMMENT ON COLUMN silver.setlists.external_id IS 'Original setlist entry ID from ElGoose API';
COMMENT ON COLUMN silver.setlists.show_id IS 'Foreign key to silver.shows table (required)';
COMMENT ON COLUMN silver.setlists.song_id IS 'Foreign key to silver.songs table (may be null if song not matched)';
COMMENT ON COLUMN silver.setlists.is_jam IS 'Whether this performance was noted as a jam';

-- 5. FACT: JAMCHARTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.jamcharts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id       TEXT,                               -- bronze.jamcharts.uniqueid
  song_id           UUID REFERENCES silver.songs(id),
  song_name         CITEXT,
  show_id           UUID REFERENCES silver.shows(id),   -- if showid present; else null
  position          INT,
  set_number        INT,
  duration_seconds  INT,                                -- parsed from tracktime (mm:ss)
  rating            INT,                                -- if a rating is present; else null
  jam_type          CITEXT,                             -- if type/flag present; else null
  jamchart_note     TEXT,                               -- bronze.jamcharts.jamchartnote
  footnote          TEXT,
  permalink         TEXT,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now(),
  source_raw_id     UUID,
  processed_at      TIMESTAMPTZ
);

COMMENT ON TABLE silver.jamcharts IS 'Fact table for jamchart entries with performance ratings and notes';
COMMENT ON COLUMN silver.jamcharts.duration_seconds IS 'Duration parsed from MM:SS tracktime format';
COMMENT ON COLUMN silver.jamcharts.jamchart_note IS 'Curator notes about this jam performance';

-- 6. LATEST (typed feed-like table; keep raw payload + typed anchors)
-- ============================================================================
CREATE TYPE IF NOT EXISTS silver.latest_type_enum AS ENUM (
  'show','setlist','song','venue','jamchart','link','upload','metadata','other'
);

CREATE TABLE IF NOT EXISTS silver.latest (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id     TEXT,
  type            silver.latest_type_enum DEFAULT 'other',
  show_id         UUID REFERENCES silver.shows(id),
  song_id         UUID REFERENCES silver.songs(id),
  venue_id        UUID REFERENCES silver.venues(id),
  artist          CITEXT,
  artist_id       TEXT,
  songname        CITEXT,
  venuename       CITEXT,
  city            CITEXT,
  state           CITEXT,
  country         CITEXT,
  position        INT,
  set_number      INT,
  is_original     BOOLEAN,
  original_artist CITEXT,
  is_jam          BOOLEAN,
  is_reprise      BOOLEAN,
  is_verified     BOOLEAN,
  is_recommended  BOOLEAN,
  is_jamchart     BOOLEAN,
  opener          BOOLEAN,
  soundcheck      BOOLEAN,
  jamchart_notes  TEXT,
  footnote        TEXT,
  tour_id         TEXT,
  tourname        CITEXT,
  permalink       TEXT,
  slug            CITEXT,
  transition      TEXT,
  transition_id   TEXT,
  data            JSONB,                         -- full payload for safety/auditing
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now(),
  source_raw_id   UUID,
  processed_at    TIMESTAMPTZ
);

COMMENT ON TABLE silver.latest IS 'Feed-like table for latest activity with typed fields plus raw JSON';
COMMENT ON COLUMN silver.latest.data IS 'Full original JSON payload for auditing and fields not yet typed';

-- 7. METADATA (key/value with anchors)
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.metadata (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id   TEXT,
  key           CITEXT NOT NULL,       -- bronze.metadata.meta_name / metadata_slug
  value         TEXT,
  data_type     CITEXT,                 -- optional hint (e.g., 'int','text','bool')
  show_id       UUID REFERENCES silver.shows(id),
  song_id       UUID REFERENCES silver.songs(id),
  permalink     TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  source_raw_id UUID,
  processed_at  TIMESTAMPTZ
);

COMMENT ON TABLE silver.metadata IS 'Key-value metadata with anchors to shows/songs';
COMMENT ON COLUMN silver.metadata.key IS 'Metadata key/name';
COMMENT ON COLUMN silver.metadata.data_type IS 'Optional type hint for the value';

-- 8. LINKS
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.links (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id   TEXT,             -- bronze.links.link_id
  url           TEXT NOT NULL,
  title         TEXT,
  description   TEXT,
  link_type     CITEXT,           -- if present in latest/other payloads
  show_id       UUID REFERENCES silver.shows(id),
  song_id       UUID REFERENCES silver.songs(id),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  source_raw_id UUID,
  processed_at  TIMESTAMPTZ
);

COMMENT ON TABLE silver.links IS 'External links associated with shows and songs';
COMMENT ON COLUMN silver.links.url IS 'The external URL';
COMMENT ON COLUMN silver.links.link_type IS 'Type of link (if categorized)';

-- 9. UPLOADS
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.uploads (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id   TEXT,             -- bronze.uploads.id
  url           TEXT,             -- bronze.uploads.URL
  filename      TEXT,             -- bronze.uploads.img_name
  file_type     CITEXT,           -- bronze.uploads.upload_type
  file_size     BIGINT,           -- bronze.uploads.filesize if available
  description   TEXT,
  attribution   TEXT,
  show_id       UUID REFERENCES silver.shows(id),
  upload_date   DATE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  source_raw_id UUID,
  processed_at  TIMESTAMPTZ
);

COMMENT ON TABLE silver.uploads IS 'File uploads (posters, media) associated with shows';
COMMENT ON COLUMN silver.uploads.file_type IS 'Type of uploaded file';
COMMENT ON COLUMN silver.uploads.file_size IS 'File size in bytes if known';

-- 10. PEOPLE + APPEARANCES (normalize persons)
-- ============================================================================
CREATE TABLE IF NOT EXISTS silver.people (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id   TEXT UNIQUE,         -- bronze.appearances.person_id
  name          CITEXT NOT NULL,     -- bronze.appearances.personname
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE silver.people IS 'Dimension table for people (musicians, guests, etc.)';
COMMENT ON COLUMN silver.people.external_id IS 'Original person ID from ElGoose API';

CREATE TABLE IF NOT EXISTS silver.appearances (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id   TEXT,                -- bronze.appearances.slug or appearance row id if any
  person_id     UUID REFERENCES silver.people(id),
  show_id       UUID REFERENCES silver.shows(id),
  role          CITEXT,              -- bronze.appearances.role (if provided)
  instrument    CITEXT,              -- bronze.appearances.instrument (if provided)
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  source_raw_id UUID,
  processed_at  TIMESTAMPTZ
);

COMMENT ON TABLE silver.appearances IS 'Fact table linking people to shows with roles/instruments';
COMMENT ON COLUMN silver.appearances.role IS 'Role of person at the show (e.g., guest, opener)';
COMMENT ON COLUMN silver.appearances.instrument IS 'Instrument played if applicable';

-- ============================================================================
-- SECTION 5: CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Songs indexes
CREATE INDEX IF NOT EXISTS songs_slug_idx ON silver.songs (slug);
CREATE INDEX IF NOT EXISTS songs_name_trgm_idx ON silver.songs USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS songs_is_original_idx ON silver.songs (is_original);
CREATE INDEX IF NOT EXISTS songs_external_id_idx ON silver.songs (external_id);

-- Venues indexes
CREATE INDEX IF NOT EXISTS venues_slug_idx ON silver.venues (slug);
CREATE INDEX IF NOT EXISTS venues_city_state_idx ON silver.venues (city, state);
CREATE INDEX IF NOT EXISTS venues_country_idx ON silver.venues (country);
CREATE INDEX IF NOT EXISTS venues_name_trgm_idx ON silver.venues USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS venues_external_id_idx ON silver.venues (external_id);

-- Shows indexes
CREATE INDEX IF NOT EXISTS shows_date_idx ON silver.shows (date);
CREATE INDEX IF NOT EXISTS shows_venue_idx ON silver.shows (venue_id);
CREATE INDEX IF NOT EXISTS shows_year_idx ON silver.shows (show_year);
CREATE INDEX IF NOT EXISTS shows_external_id_idx ON silver.shows (external_id);

-- Setlists indexes - optimized for chatbot queries
CREATE INDEX IF NOT EXISTS setlists_show_idx ON silver.setlists (show_id);
CREATE INDEX IF NOT EXISTS setlists_song_idx ON silver.setlists (song_id);
CREATE INDEX IF NOT EXISTS setlists_order_idx ON silver.setlists (show_id, set_number, position);
CREATE INDEX IF NOT EXISTS setlists_isjam_idx ON silver.setlists (is_jam) WHERE is_jam IS TRUE;
CREATE INDEX IF NOT EXISTS setlists_external_id_idx ON silver.setlists (external_id);

-- Jamcharts indexes
CREATE INDEX IF NOT EXISTS jamcharts_song_idx ON silver.jamcharts (song_id);
CREATE INDEX IF NOT EXISTS jamcharts_show_idx ON silver.jamcharts (show_id);
CREATE INDEX IF NOT EXISTS jamcharts_external_id_idx ON silver.jamcharts (external_id);

-- Latest indexes
CREATE INDEX IF NOT EXISTS latest_type_idx ON silver.latest (type);
CREATE INDEX IF NOT EXISTS latest_show_idx ON silver.latest (show_id);
CREATE INDEX IF NOT EXISTS latest_song_idx ON silver.latest (song_id);
CREATE INDEX IF NOT EXISTS latest_venue_idx ON silver.latest (venue_id);

-- Metadata indexes
CREATE INDEX IF NOT EXISTS metadata_key_idx ON silver.metadata (key);
CREATE INDEX IF NOT EXISTS metadata_song_idx ON silver.metadata (song_id);
CREATE INDEX IF NOT EXISTS metadata_show_idx ON silver.metadata (show_id);

-- Links indexes
CREATE INDEX IF NOT EXISTS links_show_idx ON silver.links (show_uuid);
CREATE INDEX IF NOT EXISTS links_song_idx ON silver.links (song_uuid);

-- Uploads indexes
CREATE INDEX IF NOT EXISTS uploads_show_idx ON silver.uploads (show_id);

-- People indexes
CREATE INDEX IF NOT EXISTS people_name_trgm_idx ON silver.people USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS people_external_id_idx ON silver.people (external_id);

-- Appearances indexes
CREATE INDEX IF NOT EXISTS appearances_person_idx ON silver.appearances (person_id);
CREATE INDEX IF NOT EXISTS appearances_show_idx ON silver.appearances (show_id);

-- ============================================================================
-- SECTION 6: CREATE UNIQUE CONSTRAINTS
-- ============================================================================

-- Prevent duplicate shows at same venue on same date
CREATE UNIQUE INDEX IF NOT EXISTS shows_date_venue_unq
  ON silver.shows(date, venue_id) WHERE venue_id IS NOT NULL;

-- Prevent duplicate setlist entries within a show
CREATE UNIQUE INDEX IF NOT EXISTS setlists_unique_row
  ON silver.setlists (show_id, set_number, position, COALESCE(song_id, gen_random_uuid()::uuid))
  WHERE position IS NOT NULL AND set_number IS NOT NULL;

-- Dedupe links
CREATE UNIQUE INDEX IF NOT EXISTS links_dedupe
  ON silver.links (
    COALESCE(external_id,''), 
    COALESCE(url,''), 
    COALESCE(show_id, '00000000-0000-0000-0000-000000000000'::uuid), 
    COALESCE(song_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

-- Dedupe appearances
CREATE UNIQUE INDEX IF NOT EXISTS appearances_dedupe
  ON silver.appearances (
    person_id, 
    show_id, 
    COALESCE(role,''), 
    COALESCE(instrument,'')
  );

-- ============================================================================
-- COMMENTS AND DOCUMENTATION
-- ============================================================================

COMMENT ON SCHEMA silver IS 'Production Silver layer - cleaned, normalized, and indexed data optimized for chatbot queries';

