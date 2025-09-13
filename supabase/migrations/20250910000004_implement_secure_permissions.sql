-- Implement Secure User Permissions and Data Protection
-- This migration creates a secure permission system to protect data

-- ============================================================================
-- CREATE SECURE USER ROLES
-- ============================================================================

-- 1. Data Ingestion Role (for Edge Functions - can only INSERT/UPDATE)
DO $$ BEGIN
    CREATE ROLE data_ingestion;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON ROLE data_ingestion IS 'Role for automated data ingestion - can only INSERT/UPDATE, cannot DELETE';

-- 2. Data Processor Role (for ETL processes - can read Bronze, write Silver)
DO $$ BEGIN
    CREATE ROLE data_processor;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON ROLE data_processor IS 'Role for ETL processes - can read Bronze, write Silver, cannot DELETE raw data';

-- 3. Read-Only Role (for analytics and monitoring)
DO $$ BEGIN
    CREATE ROLE read_only_user;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON ROLE read_only_user IS 'Role for read-only access to all data - cannot modify anything';

-- 4. Admin Role (for maintenance - can do everything)
DO $$ BEGIN
    CREATE ROLE admin_user;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON ROLE admin_user IS 'Role for administrative tasks - full access including DELETE';

-- ============================================================================
-- GRANT PERMISSIONS TO ROLES
-- ============================================================================

-- Data Ingestion Role - Can only INSERT/UPDATE Bronze layer
GRANT USAGE ON SCHEMA raw_data TO data_ingestion;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA raw_data TO data_ingestion;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw_data TO data_ingestion;
-- NO DELETE permission on raw_data tables

-- Data Processor Role - Can read Bronze, write Silver
GRANT USAGE ON SCHEMA raw_data TO data_processor;
GRANT USAGE ON SCHEMA silver TO data_processor;
GRANT SELECT ON ALL TABLES IN SCHEMA raw_data TO data_processor;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA silver TO data_processor;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO data_processor;

-- Read-Only Role - Can only read
GRANT USAGE ON SCHEMA raw_data TO read_only_user;
GRANT USAGE ON SCHEMA silver TO read_only_user;
GRANT USAGE ON SCHEMA public TO read_only_user;
GRANT SELECT ON ALL TABLES IN SCHEMA raw_data TO read_only_user;
GRANT SELECT ON ALL TABLES IN SCHEMA silver TO read_only_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only_user;

-- Admin Role - Full access
GRANT USAGE ON SCHEMA raw_data TO admin_user;
GRANT USAGE ON SCHEMA silver TO admin_user;
GRANT USAGE ON SCHEMA public TO admin_user;
GRANT ALL ON ALL TABLES IN SCHEMA raw_data TO admin_user;
GRANT ALL ON ALL TABLES IN SCHEMA silver TO admin_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO admin_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw_data TO admin_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO admin_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO admin_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw_data TO admin_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver TO admin_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO admin_user;

-- ============================================================================
-- IMPLEMENT ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
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

ALTER TABLE silver.songs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- CREATE RLS POLICIES FOR DATA PROTECTION
-- ============================================================================

-- Bronze Layer Policies - Prevent DELETE operations
CREATE POLICY "data_ingestion_bronze_insert" ON raw_data.songs
  FOR INSERT TO data_ingestion WITH CHECK (true);

CREATE POLICY "data_ingestion_bronze_update" ON raw_data.songs
  FOR UPDATE TO data_ingestion USING (true) WITH CHECK (true);

CREATE POLICY "data_processor_bronze_read" ON raw_data.songs
  FOR SELECT TO data_ingestion, data_processor, read_only_user, admin_user USING (true);

-- NO DELETE policy for raw_data.songs - this prevents accidental deletion

-- Apply same pattern to all Bronze tables
CREATE POLICY "data_ingestion_shows_insert" ON raw_data.shows
  FOR INSERT TO data_ingestion WITH CHECK (true);
CREATE POLICY "data_ingestion_shows_update" ON raw_data.shows
  FOR UPDATE TO data_ingestion USING (true) WITH CHECK (true);
CREATE POLICY "data_processor_shows_read" ON raw_data.shows
  FOR SELECT TO data_ingestion, data_processor, read_only_user, admin_user USING (true);

CREATE POLICY "data_ingestion_venues_insert" ON raw_data.venues
  FOR INSERT TO data_ingestion WITH CHECK (true);
CREATE POLICY "data_ingestion_venues_update" ON raw_data.venues
  FOR UPDATE TO data_ingestion USING (true) WITH CHECK (true);
CREATE POLICY "data_processor_venues_read" ON raw_data.venues
  FOR SELECT TO data_ingestion, data_processor, read_only_user, admin_user USING (true);

CREATE POLICY "data_ingestion_setlists_insert" ON raw_data.setlists
  FOR INSERT TO data_ingestion WITH CHECK (true);
CREATE POLICY "data_ingestion_setlists_update" ON raw_data.setlists
  FOR UPDATE TO data_ingestion USING (true) WITH CHECK (true);
CREATE POLICY "data_processor_setlists_read" ON raw_data.setlists
  FOR SELECT TO data_ingestion, data_processor, read_only_user, admin_user USING (true);

-- Apply to remaining tables
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['jamcharts', 'latest', 'metadata', 'links', 'uploads', 'appearances'];
BEGIN
    FOREACH table_name IN ARRAY tables LOOP
        EXECUTE format('CREATE POLICY "data_ingestion_%s_insert" ON raw_data.%I FOR INSERT TO data_ingestion WITH CHECK (true)', table_name, table_name);
        EXECUTE format('CREATE POLICY "data_ingestion_%s_update" ON raw_data.%I FOR UPDATE TO data_ingestion USING (true) WITH CHECK (true)', table_name, table_name);
        EXECUTE format('CREATE POLICY "data_processor_%s_read" ON raw_data.%I FOR SELECT TO data_ingestion, data_processor, read_only_user, admin_user USING (true)', table_name, table_name);
    END LOOP;
END $$;

-- Silver Layer Policies - Allow full access for processing
CREATE POLICY "data_processor_silver_all" ON silver.songs
  FOR ALL TO data_processor, admin_user USING (true) WITH CHECK (true);

CREATE POLICY "read_only_silver_select" ON silver.songs
  FOR SELECT TO read_only_user USING (true);

-- ============================================================================
-- CREATE AUDIT LOGGING
-- ============================================================================

-- Create audit log table
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL,
  user_role TEXT NOT NULL,
  record_id TEXT,
  old_values JSONB,
  new_values JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Grant permissions for audit logging
GRANT INSERT ON audit_log TO data_ingestion, data_processor, admin_user;

-- Create audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (
    table_name,
    operation,
    user_role,
    record_id,
    old_values,
    new_values
  ) VALUES (
    TG_TABLE_NAME,
    TG_OP,
    current_setting('role'),
    COALESCE(NEW.id::text, OLD.id::text),
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN to_jsonb(NEW) ELSE NULL END
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to critical tables
CREATE TRIGGER audit_raw_data_songs
  AFTER INSERT OR UPDATE OR DELETE ON raw_data.songs
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_raw_data_setlists
  AFTER INSERT OR UPDATE OR DELETE ON raw_data.setlists
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- ============================================================================
-- CREATE MONITORING VIEWS
-- ============================================================================

-- View for monitoring data access
CREATE OR REPLACE VIEW data_access_monitor AS
SELECT 
  table_name,
  operation,
  user_role,
  COUNT(*) as operation_count,
  MAX(created_at) as last_operation
FROM audit_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY table_name, operation, user_role
ORDER BY last_operation DESC;

GRANT SELECT ON data_access_monitor TO read_only_user, admin_user;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE audit_log IS 'Audit trail for all data operations - tracks who did what when';
COMMENT ON VIEW data_access_monitor IS 'Monitor data access patterns and operations';
