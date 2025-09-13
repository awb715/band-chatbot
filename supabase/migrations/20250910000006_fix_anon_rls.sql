-- Fix RLS Policies for anon role
-- This migration properly restricts DELETE operations for anonymous users

-- ============================================================================
-- DROP ALL EXISTING POLICIES AND START FRESH
-- ============================================================================

-- Drop all existing policies on raw_data tables
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['songs', 'shows', 'venues', 'setlists', 'jamcharts', 'latest', 'metadata', 'links', 'uploads', 'appearances'];
BEGIN
    FOREACH table_name IN ARRAY tables LOOP
        -- Drop all existing policies
        EXECUTE format('DROP POLICY IF EXISTS "anon_%s_select" ON raw_data.%I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "anon_%s_insert" ON raw_data.%I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "anon_%s_update" ON raw_data.%I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "deny_anon_%s_delete" ON raw_data.%I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "admin_%s_all" ON raw_data.%I', table_name, table_name);
    END LOOP;
END $$;

-- ============================================================================
-- CREATE PROPER RLS POLICIES
-- ============================================================================

-- Songs table policies
CREATE POLICY "anon_songs_select" ON raw_data.songs
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "anon_songs_insert" ON raw_data.songs
  FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "anon_songs_update" ON raw_data.songs
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- EXPLICITLY DENY DELETE for anon and authenticated
CREATE POLICY "deny_anon_songs_delete" ON raw_data.songs
  FOR DELETE TO anon, authenticated USING (false);

-- Admin can do everything
CREATE POLICY "admin_songs_all" ON raw_data.songs
  FOR ALL TO admin_user USING (true) WITH CHECK (true);

-- Apply same pattern to all other tables
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['shows', 'venues', 'setlists', 'jamcharts', 'latest', 'metadata', 'links', 'uploads', 'appearances'];
BEGIN
    FOREACH table_name IN ARRAY tables LOOP
        -- SELECT policy
        EXECUTE format('CREATE POLICY "anon_%s_select" ON raw_data.%I FOR SELECT TO anon, authenticated USING (true)', table_name, table_name);
        
        -- INSERT policy
        EXECUTE format('CREATE POLICY "anon_%s_insert" ON raw_data.%I FOR INSERT TO anon, authenticated WITH CHECK (true)', table_name, table_name);
        
        -- UPDATE policy
        EXECUTE format('CREATE POLICY "anon_%s_update" ON raw_data.%I FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true)', table_name, table_name);
        
        -- DENY DELETE policy
        EXECUTE format('CREATE POLICY "deny_anon_%s_delete" ON raw_data.%I FOR DELETE TO anon, authenticated USING (false)', table_name, table_name);
        
        -- Admin can do everything
        EXECUTE format('CREATE POLICY "admin_%s_all" ON raw_data.%I FOR ALL TO admin_user USING (true) WITH CHECK (true)', table_name, table_name);
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
