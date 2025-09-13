-- Fix public ETL wrappers to target the silver schema and add missing songs wrapper

-- Drop existing public.process_all_tables to avoid return type conflicts
DO $$ BEGIN
  PERFORM 1 FROM pg_proc WHERE proname = 'process_all_tables' AND pg_function_is_visible(oid);
  IF FOUND THEN
    DROP FUNCTION public.process_all_tables();
  END IF;
EXCEPTION WHEN undefined_function THEN
  -- ignore
END $$;

-- Create public wrapper for songs that delegates to silver.process_songs
CREATE OR REPLACE FUNCTION public.process_songs()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER)
LANGUAGE sql AS $$
  SELECT * FROM silver.process_songs();
$$;

-- Create public wrapper for processing all silver tables by delegating to silver.process_all_tables
-- Project only the expected columns for RPC consumers
CREATE OR REPLACE FUNCTION public.process_all_tables()
RETURNS TABLE(
  table_name TEXT,
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER
)
LANGUAGE sql AS $$
  SELECT table_name, processed_count, error_count, processing_time_ms
  FROM silver.process_all_tables();
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.process_songs() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_all_tables() TO anon, authenticated;


