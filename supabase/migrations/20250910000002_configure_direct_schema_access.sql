-- Configure Direct Schema Access
-- This migration ensures raw_data and silver schemas are accessible via Supabase API

-- ============================================================================
-- GRANT SCHEMA ACCESS
-- ============================================================================

-- Grant usage on schemas to anon and authenticated roles
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

-- ============================================================================
-- NOTE: SCHEMA EXPOSURE
-- ============================================================================
-- 
-- For direct schema access to work, you need to expose the schemas in Supabase Dashboard:
-- 1. Go to Settings > API
-- 2. Add 'raw_data' and 'silver' to "Exposed schemas" list
-- 3. Save the changes
-- 
-- This allows Supabase client to access tables like:
-- - raw_data.songs
-- - raw_data.setlists
-- - silver.songs
-- etc.
