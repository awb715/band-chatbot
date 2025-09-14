-- ============================================================================
-- MIGRATE EXISTING SILVER DATA TO NEW SCHEMA
-- ============================================================================
-- 
-- This migration safely upgrades the existing incomplete Silver layer to the 
-- new production-ready schema, preserving existing data where possible.
--
-- Strategy:
-- 1. Create backup tables for existing data
-- 2. Drop old inconsistent tables/views
-- 3. Migrate useful data to new schema
-- 4. Clean up old public.silver_* tables
-- 5. Reset processing flags for complete backfill
--
-- Note: This migration assumes the new Silver schema has already been created
-- by the previous migration (20250914000000_create_production_silver_layer.sql)
--
-- ============================================================================

-- ============================================================================
-- SECTION 1: BACKUP EXISTING DATA
-- ============================================================================

-- Create temporary backup schema
CREATE SCHEMA IF NOT EXISTS silver_backup;

-- Backup existing silver.songs data if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'silver' AND table_name = 'songs') THEN
    EXECUTE 'CREATE TABLE silver_backup.songs_old AS SELECT * FROM silver.songs';
    RAISE NOTICE 'Backed up existing silver.songs data';
  END IF;
END $$;

-- Backup any public.silver_* tables that might exist
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name LIKE 'silver_%'
  LOOP
    EXECUTE format('CREATE TABLE IF NOT EXISTS silver_backup.%I AS SELECT * FROM public.%I', 
                   table_record.table_name, table_record.table_name);
    RAISE NOTICE 'Backed up existing public.% table', table_record.table_name;
  END LOOP;
END $$;

-- ============================================================================
-- SECTION 2: DROP OLD INCONSISTENT STRUCTURES
-- ============================================================================

-- Drop old public.silver_* tables that were causing schema confusion
DROP TABLE IF EXISTS public.silver_songs CASCADE;
DROP TABLE IF EXISTS public.silver_shows CASCADE;
DROP TABLE IF EXISTS public.silver_setlists CASCADE;
DROP TABLE IF EXISTS public.silver_venues CASCADE;
DROP TABLE IF EXISTS public.silver_latest CASCADE;
DROP TABLE IF EXISTS public.silver_metadata CASCADE;
DROP TABLE IF EXISTS public.silver_links CASCADE;
DROP TABLE IF EXISTS public.silver_uploads CASCADE;
DROP TABLE IF EXISTS public.silver_appearances CASCADE;
DROP TABLE IF EXISTS public.silver_jamcharts CASCADE;

-- Drop old ETL functions that may conflict
DROP FUNCTION IF EXISTS public.process_songs() CASCADE;
DROP FUNCTION IF EXISTS public.process_shows() CASCADE;
DROP FUNCTION IF EXISTS public.process_setlists() CASCADE;
DROP FUNCTION IF EXISTS public.process_venues() CASCADE;
DROP FUNCTION IF EXISTS public.process_latest() CASCADE;
DROP FUNCTION IF EXISTS public.process_metadata() CASCADE;
DROP FUNCTION IF EXISTS public.process_links() CASCADE;
DROP FUNCTION IF EXISTS public.process_uploads() CASCADE;
DROP FUNCTION IF EXISTS public.process_appearances() CASCADE;
DROP FUNCTION IF EXISTS public.process_jamcharts() CASCADE;
DROP FUNCTION IF EXISTS public.process_all_tables() CASCADE;

-- Drop old silver schema functions that may conflict with new ones
DROP FUNCTION IF EXISTS silver.process_shows() CASCADE;
DROP FUNCTION IF EXISTS silver.process_setlists() CASCADE;
DROP FUNCTION IF EXISTS silver.process_venues() CASCADE;
DROP FUNCTION IF EXISTS silver.process_latest() CASCADE;
DROP FUNCTION IF EXISTS silver.process_metadata() CASCADE;
DROP FUNCTION IF EXISTS silver.process_links() CASCADE;
DROP FUNCTION IF EXISTS silver.process_uploads() CASCADE;
DROP FUNCTION IF EXISTS silver.process_appearances() CASCADE;
DROP FUNCTION IF EXISTS silver.process_jamcharts() CASCADE;
DROP FUNCTION IF EXISTS silver.process_all_tables() CASCADE;

RAISE NOTICE 'Cleaned up old inconsistent Silver layer structures';

-- ============================================================================
-- SECTION 3: MIGRATE EXISTING SONGS DATA (if any)
-- ============================================================================

-- If we have songs data in the backup, migrate it to the new schema
DO $$
DECLARE
  song_record RECORD;
  migration_count INT := 0;
BEGIN
  -- Check if backup table exists and has data
  IF EXISTS (SELECT 1 FROM information_schema.tables 
             WHERE table_schema = 'silver_backup' AND table_name = 'songs_old') THEN
    
    RAISE NOTICE 'Migrating existing songs data to new schema...';
    
    -- Migrate songs data, mapping old schema to new
    FOR song_record IN 
      SELECT * FROM silver_backup.songs_old
    LOOP
      BEGIN
        INSERT INTO silver.songs (
          id, external_id, slug, name, is_original, original_artist,
          created_at, updated_at, source_raw_id, processed_at
        ) VALUES (
          song_record.id,
          song_record.external_id,
          LOWER(COALESCE(song_record.slug, '')),
          COALESCE(song_record.name, 'Unknown Song'),
          COALESCE(song_record.is_original, TRUE),
          song_record.original_artist,
          COALESCE(song_record.created_at, now()),
          COALESCE(song_record.updated_at, now()),
          song_record.source_raw_id,
          song_record.processed_at
        )
        ON CONFLICT (id) DO NOTHING;  -- Don't overwrite if already exists
        
        migration_count := migration_count + 1;
        
      EXCEPTION WHEN others THEN
        RAISE WARNING 'Failed to migrate song %: %', song_record.id, SQLERRM;
      END;
    END LOOP;
    
    RAISE NOTICE 'Migrated % songs from old schema', migration_count;
  ELSE
    RAISE NOTICE 'No existing songs data found to migrate';
  END IF;
END $$;

-- ============================================================================
-- SECTION 4: RESET PROCESSING FLAGS FOR COMPLETE BACKFILL
-- ============================================================================

-- Reset is_processed flags on all Bronze tables to ensure complete backfill
-- This ensures that all existing Bronze data gets processed through the new ETL
UPDATE raw_data.songs SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.shows SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.venues SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.setlists SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.jamcharts SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.latest SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.metadata SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.links SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.uploads SET is_processed = FALSE WHERE is_processed = TRUE;
UPDATE raw_data.appearances SET is_processed = FALSE WHERE is_processed = TRUE;

RAISE NOTICE 'Reset all Bronze processing flags for complete Silver backfill';

-- ============================================================================
-- SECTION 5: VERIFY NEW SCHEMA INTEGRITY
-- ============================================================================

-- Check that all expected tables exist in the new Silver schema
DO $$
DECLARE
  expected_tables TEXT[] := ARRAY[
    'songs', 'venues', 'shows', 'setlists', 'jamcharts', 
    'latest', 'metadata', 'links', 'uploads', 'people', 'appearances'
  ];
  table_name TEXT;
  missing_tables TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH table_name IN ARRAY expected_tables
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'silver' AND table_name = table_name
    ) THEN
      missing_tables := array_append(missing_tables, table_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_tables, 1) > 0 THEN
    RAISE EXCEPTION 'Missing expected Silver tables: %', array_to_string(missing_tables, ', ');
  ELSE
    RAISE NOTICE 'All expected Silver tables are present';
  END IF;
END $$;

-- Verify that ETL functions exist
DO $$
DECLARE
  expected_functions TEXT[] := ARRAY[
    'process_songs', 'process_venues', 'process_shows', 'process_setlists',
    'process_jamcharts', 'process_people', 'process_appearances',
    'process_links', 'process_uploads', 'process_metadata', 'process_latest',
    'process_all_tables'
  ];
  function_name TEXT;
  missing_functions TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH function_name IN ARRAY expected_functions
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema = 'silver' AND routine_name = function_name
    ) THEN
      missing_functions := array_append(missing_functions, function_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_functions, 1) > 0 THEN
    RAISE EXCEPTION 'Missing expected Silver ETL functions: %', array_to_string(missing_functions, ', ');
  ELSE
    RAISE NOTICE 'All expected Silver ETL functions are present';
  END IF;
END $$;

-- ============================================================================
-- SECTION 6: INFORMATION AND NEXT STEPS
-- ============================================================================

-- Display summary of migration
DO $$
DECLARE
  bronze_songs_count INT;
  bronze_shows_count INT;
  bronze_setlists_count INT;
  bronze_venues_count INT;
  silver_songs_count INT;
BEGIN
  -- Count Bronze records available for processing
  SELECT COUNT(*) INTO bronze_songs_count FROM raw_data.songs WHERE is_processed = FALSE;
  SELECT COUNT(*) INTO bronze_shows_count FROM raw_data.shows WHERE is_processed = FALSE;
  SELECT COUNT(*) INTO bronze_setlists_count FROM raw_data.setlists WHERE is_processed = FALSE;
  SELECT COUNT(*) INTO bronze_venues_count FROM raw_data.venues WHERE is_processed = FALSE;
  
  -- Count existing Silver records
  SELECT COUNT(*) INTO silver_songs_count FROM silver.songs;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'SILVER LAYER MIGRATION COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Bronze data ready for processing:';
  RAISE NOTICE '  - Songs: % unprocessed records', bronze_songs_count;
  RAISE NOTICE '  - Shows: % unprocessed records', bronze_shows_count;
  RAISE NOTICE '  - Setlists: % unprocessed records', bronze_setlists_count;
  RAISE NOTICE '  - Venues: % unprocessed records', bronze_venues_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Silver layer status:';
  RAISE NOTICE '  - Songs migrated: % records', silver_songs_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '  1. Run: SELECT silver.process_all_tables();';
  RAISE NOTICE '  2. Verify data quality with validation queries';
  RAISE NOTICE '  3. Update Edge Functions to use new schema';
  RAISE NOTICE '  4. Test chatbot query performance';
  RAISE NOTICE '========================================';
END $$;

-- Create a migration status table for tracking
CREATE TABLE IF NOT EXISTS silver_etl.migration_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  migration_name TEXT NOT NULL,
  started_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  status TEXT DEFAULT 'in_progress',
  notes TEXT
);

INSERT INTO silver_etl.migration_status (migration_name, completed_at, status, notes)
VALUES (
  'production_silver_migration_20250914', 
  now(), 
  'completed',
  'Migrated from incomplete Silver layer to production-ready schema with comprehensive ETL functions'
);

COMMENT ON TABLE silver_etl.migration_status IS 'Tracks Silver layer migrations and their status';

-- Clean up backup schema (optional - commented out for safety)
-- DROP SCHEMA silver_backup CASCADE;
-- RAISE NOTICE 'Backup schema dropped - migration complete';

RAISE NOTICE 'Silver layer migration completed successfully!';
