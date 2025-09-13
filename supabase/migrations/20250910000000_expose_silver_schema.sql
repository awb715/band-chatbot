-- Expose Silver Schema to Supabase API
-- This migration exposes the silver schema tables to the Supabase API

-- Grant usage on the silver schema to anon and authenticated roles
GRANT USAGE ON SCHEMA silver TO anon, authenticated;

-- Grant all privileges on all tables in the silver schema
GRANT ALL ON ALL TABLES IN SCHEMA silver TO anon, authenticated;

-- Grant all privileges on all sequences in the silver schema
GRANT ALL ON ALL SEQUENCES IN SCHEMA silver TO anon, authenticated;

-- Grant all privileges on all functions in the silver schema
GRANT ALL ON ALL FUNCTIONS IN SCHEMA silver TO anon, authenticated;

-- Create public views to expose silver tables
CREATE OR REPLACE VIEW public.silver_songs AS
SELECT * FROM silver.songs;

CREATE OR REPLACE VIEW public.silver_processing_status AS
SELECT * FROM silver_processing_status;

-- Grant access to the views
GRANT ALL ON public.silver_songs TO anon, authenticated;
GRANT ALL ON public.silver_processing_status TO anon, authenticated;

-- Update the API settings to include silver schema
-- This needs to be done manually in the Supabase Dashboard:
-- 1. Go to Settings > API
-- 2. Add 'silver' to the "Exposed schemas" list
-- 3. Save the changes
