-- Drop duplicate Silver tables created in the public schema, if they exist.
-- This migration will NOT touch the canonical tables in the silver schema.

DO $$
DECLARE
    obj RECORD;
BEGIN
    FOR obj IN
        SELECT tablename
        FROM pg_catalog.pg_tables
        WHERE schemaname = 'public'
          AND tablename LIKE 'silver_%'
    LOOP
        EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE', obj.tablename);
    END LOOP;
END $$;

-- Additionally, drop any views in public that look like silver_* and shadow the silver schema
DO $$
DECLARE
    v RECORD;
BEGIN
    FOR v IN
        SELECT table_name AS viewname
        FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name LIKE 'silver_%'
    LOOP
        EXECUTE format('DROP VIEW IF EXISTS public.%I CASCADE', v.viewname);
    END LOOP;
END $$;


