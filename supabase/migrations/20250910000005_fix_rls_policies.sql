-- Fix RLS Policies for anon and authenticated roles
-- This migration fixes the security issue where DELETE operations were allowed

-- ============================================================================
-- DROP EXISTING POLICIES AND RECREATE THEM PROPERLY
-- ============================================================================

-- Drop all existing policies on raw_data tables
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['songs', 'shows', 'venues', 'setlists', 'jamcharts', 'latest', 'metadata', 'links', 'uploads', 'appearances'];
BEGIN
    FOREACH table_name IN ARRAY tables LOOP
        -- Drop all policies on the table
        EXECUTE format('DROP POLICY IF EXISTS "data_ingestion_%s_insert" ON raw_data.%I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "data_ingestion_%s_update" ON raw_data.%I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "data_processor_%s_read" ON raw_data.%I', table_name, table_name);
    END LOOP;
END $$;

-- ============================================================================
-- CREATE PROPER RLS POLICIES FOR ALL ROLES
-- ============================================================================

-- Songs table policies
CREATE POLICY "anon_songs_select" ON raw_data.songs
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_songs_insert" ON raw_data.songs
  FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "anon_songs_update" ON raw_data.songs
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- NO DELETE policy for anon/authenticated - this prevents deletion

-- Admin role can do everything
CREATE POLICY "admin_songs_all" ON raw_data.songs
  FOR ALL TO admin_user USING (true) WITH CHECK (true);

-- Apply same pattern to all other tables
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['shows', 'venues', 'setlists', 'jamcharts', 'latest', 'metadata', 'links', 'uploads', 'appearances'];
BEGIN
    FOREACH table_name IN ARRAY tables LOOP
        -- SELECT policy for anon/authenticated
        EXECUTE format('CREATE POLICY "anon_%s_select" ON raw_data.%I FOR SELECT TO anon, authenticated USING (true)', table_name, table_name);
        
        -- INSERT policy for anon/authenticated
        EXECUTE format('CREATE POLICY "anon_%s_insert" ON raw_data.%I FOR INSERT TO anon, authenticated WITH CHECK (true)', table_name, table_name);
        
        -- UPDATE policy for anon/authenticated
        EXECUTE format('CREATE POLICY "anon_%s_update" ON raw_data.%I FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true)', table_name, table_name);
        
        -- Admin can do everything
        EXECUTE format('CREATE POLICY "admin_%s_all" ON raw_data.%I FOR ALL TO admin_user USING (true) WITH CHECK (true)', table_name, table_name);
        
        -- NO DELETE policy for anon/authenticated - this prevents deletion
    END LOOP;
END $$;

-- ============================================================================
-- CREATE EXPLICIT DENY POLICIES FOR DELETE OPERATIONS
-- ============================================================================

-- Explicitly deny DELETE for anon and authenticated roles
CREATE POLICY "deny_anon_songs_delete" ON raw_data.songs
  FOR DELETE TO anon, authenticated USING (false);

-- Apply to all tables
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['shows', 'venues', 'setlists', 'jamcharts', 'latest', 'metadata', 'links', 'uploads', 'appearances'];
BEGIN
    FOREACH table_name IN ARRAY tables LOOP
        EXECUTE format('CREATE POLICY "deny_anon_%s_delete" ON raw_data.%I FOR DELETE TO anon, authenticated USING (false)', table_name, table_name);
    END LOOP;
END $$;

-- ============================================================================
-- VERIFY RLS IS ENABLED
-- ============================================================================

-- Ensure RLS is enabled on all tables
ALTER TABLE raw_data.songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.shows ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.setlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.jamcharts ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.latest ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.links ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_data.appearances ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON POLICY "deny_anon_songs_delete" ON raw_data.songs IS 'Explicitly denies DELETE operations for anon and authenticated roles';
COMMENT ON POLICY "anon_songs_select" ON raw_data.songs IS 'Allows SELECT operations for anon and authenticated roles';
COMMENT ON POLICY "anon_songs_insert" ON raw_data.songs IS 'Allows INSERT operations for anon and authenticated roles';
COMMENT ON POLICY "anon_songs_update" ON raw_data.songs IS 'Allows UPDATE operations for anon and authenticated roles';
COMMENT ON POLICY "admin_songs_all" ON raw_data.songs IS 'Allows ALL operations for admin_user role';
