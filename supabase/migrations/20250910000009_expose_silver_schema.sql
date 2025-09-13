-- Expose Silver Schema to Supabase API
-- This migration exposes the silver schema and its tables to the Supabase API

-- ============================================================================
-- EXPOSE SILVER SCHEMA
-- ============================================================================

-- Grant usage on silver schema to authenticated and anon roles
GRANT USAGE ON SCHEMA silver TO authenticated;
GRANT USAGE ON SCHEMA silver TO anon;

-- Grant select on all silver tables to authenticated and anon roles
GRANT SELECT ON ALL TABLES IN SCHEMA silver TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA silver TO anon;

-- Grant usage on all sequences in silver schema
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO anon;

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on all silver tables
ALTER TABLE silver.songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.shows ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.setlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.latest ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.links ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.appearances ENABLE ROW LEVEL SECURITY;
ALTER TABLE silver.jamcharts ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- CREATE RLS POLICIES
-- ============================================================================

-- Allow read access to all users for silver tables
CREATE POLICY "Allow read access to silver.songs" ON silver.songs FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.shows" ON silver.shows FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.setlists" ON silver.setlists FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.venues" ON silver.venues FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.latest" ON silver.latest FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.metadata" ON silver.metadata FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.links" ON silver.links FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.uploads" ON silver.uploads FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.appearances" ON silver.appearances FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Allow read access to silver.jamcharts" ON silver.jamcharts FOR SELECT TO authenticated, anon USING (true);

-- ============================================================================
-- GRANT FUNCTION PERMISSIONS
-- ============================================================================

-- Grant execute permissions on silver ETL functions
GRANT EXECUTE ON FUNCTION silver.process_shows() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_setlists() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_venues() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_latest() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_metadata() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_links() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_uploads() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_appearances() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_jamcharts() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION silver.process_all_tables() TO authenticated, anon;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON SCHEMA silver IS 'Silver layer: Clean, tabular data optimized for queries and analytics';

