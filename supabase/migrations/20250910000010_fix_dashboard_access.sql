-- Fix Dashboard Access
-- This migration ensures the Supabase dashboard can access all data

-- ============================================================================
-- GRANT ADDITIONAL PERMISSIONS FOR DASHBOARD ACCESS
-- ============================================================================

-- Grant usage on all schemas to postgres role (used by dashboard)
GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA raw_data TO postgres;
GRANT USAGE ON SCHEMA silver TO postgres;

-- Grant all permissions on all tables to postgres role
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA raw_data TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA silver TO postgres;

-- Grant usage on all sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw_data TO postgres;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO postgres;

-- Grant execute permissions on all functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw_data TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver TO postgres;

-- ============================================================================
-- TEMPORARILY DISABLE RLS FOR TESTING
-- ============================================================================

-- Disable RLS on all tables temporarily to ensure dashboard access
ALTER TABLE raw_data.songs DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.shows DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.setlists DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.venues DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.latest DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.metadata DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.links DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.uploads DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.appearances DISABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.jamcharts DISABLE ROW LEVEL SECURITY;

ALTER TABLE silver.songs DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.shows DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.setlists DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.venues DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.latest DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.metadata DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.links DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.uploads DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.appearances DISABLE ROW LEVEL SECURITY;
ALTER TABLE silver.jamcharts DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- GRANT PERMISSIONS TO SERVICE_ROLE
-- ============================================================================

-- Grant all permissions to service_role (used by Edge Functions)
GRANT USAGE ON SCHEMA public TO service_role;
GRANT USAGE ON SCHEMA raw_data TO service_role;
GRANT USAGE ON SCHEMA silver TO service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA raw_data TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA silver TO service_role;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw_data TO service_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO service_role;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw_data TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver TO service_role;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON SCHEMA public IS 'Public schema with full dashboard access';
COMMENT ON SCHEMA raw_data IS 'Raw data schema with full dashboard access';
COMMENT ON SCHEMA silver IS 'Silver layer schema with full dashboard access';

