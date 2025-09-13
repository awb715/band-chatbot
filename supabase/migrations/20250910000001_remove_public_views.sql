-- Remove Public Views - Use Direct Schema Access
-- This migration removes all public views and configures direct schema access

-- ============================================================================
-- REMOVE BRONZE LAYER PUBLIC VIEWS
-- ============================================================================

DROP VIEW IF EXISTS public.raw_data_setlists;
DROP VIEW IF EXISTS public.raw_data_shows;
DROP VIEW IF EXISTS public.raw_data_songs;
DROP VIEW IF EXISTS public.raw_data_venues;
DROP VIEW IF EXISTS public.raw_data_jamcharts;
DROP VIEW IF EXISTS public.raw_data_latest;
DROP VIEW IF EXISTS public.raw_data_metadata;
DROP VIEW IF EXISTS public.raw_data_links;
DROP VIEW IF EXISTS public.raw_data_uploads;
DROP VIEW IF EXISTS public.raw_data_appearances;

-- ============================================================================
-- REMOVE SILVER LAYER PUBLIC VIEWS
-- ============================================================================

DROP VIEW IF EXISTS public.silver_songs;
DROP VIEW IF EXISTS public.silver_processing_status;

-- ============================================================================
-- CONFIGURE DIRECT SCHEMA ACCESS
-- ============================================================================

-- Ensure schemas are accessible to Supabase API
-- Note: This needs to be done manually in Supabase Dashboard:
-- 1. Go to Settings > API
-- 2. Add 'raw_data' and 'silver' to "Exposed schemas" list
-- 3. Save the changes

-- Grant necessary permissions for direct access
GRANT USAGE ON SCHEMA raw_data TO anon, authenticated;
GRANT USAGE ON SCHEMA silver TO anon, authenticated;

-- Grant table access
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw_data TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA silver TO anon, authenticated;

-- Grant sequence access
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw_data TO anon, authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO anon, authenticated;

-- Grant function access
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw_data TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver TO anon, authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON SCHEMA raw_data IS 'Bronze layer: Direct access to raw data tables';
COMMENT ON SCHEMA silver IS 'Silver layer: Direct access to cleaned data tables';
