-- Expose raw_data schema to the API
-- This allows the Supabase client to access the raw_data tables

-- Grant usage on the schema to anon and authenticated roles
GRANT USAGE ON SCHEMA raw_data TO anon, authenticated;

-- Grant all privileges on all tables in the raw_data schema
GRANT ALL ON ALL TABLES IN SCHEMA raw_data TO anon, authenticated;

-- Grant all privileges on all sequences in the raw_data schema
GRANT ALL ON ALL SEQUENCES IN SCHEMA raw_data TO anon, authenticated;

-- Grant all privileges on all functions in the raw_data schema
GRANT ALL ON ALL FUNCTIONS IN SCHEMA raw_data TO anon, authenticated;

-- Update the API settings to include raw_data schema
-- This needs to be done manually in the Supabase Dashboard:
-- 1. Go to Settings > API
-- 2. Add 'raw_data' to the "Exposed schemas" list
-- 3. Save the changes

-- For now, we'll create a view in the public schema to expose the data
CREATE OR REPLACE VIEW public.raw_data_setlists AS
SELECT * FROM raw_data.setlists;

CREATE OR REPLACE VIEW public.raw_data_shows AS
SELECT * FROM raw_data.shows;

CREATE OR REPLACE VIEW public.raw_data_songs AS
SELECT * FROM raw_data.songs;

CREATE OR REPLACE VIEW public.raw_data_venues AS
SELECT * FROM raw_data.venues;

CREATE OR REPLACE VIEW public.raw_data_jamcharts AS
SELECT * FROM raw_data.jamcharts;

CREATE OR REPLACE VIEW public.raw_data_latest AS
SELECT * FROM raw_data.latest;

CREATE OR REPLACE VIEW public.raw_data_metadata AS
SELECT * FROM raw_data.metadata;

CREATE OR REPLACE VIEW public.raw_data_links AS
SELECT * FROM raw_data.links;

CREATE OR REPLACE VIEW public.raw_data_uploads AS
SELECT * FROM raw_data.uploads;

CREATE OR REPLACE VIEW public.raw_data_appearances AS
SELECT * FROM raw_data.appearances;

-- Grant access to the views
GRANT ALL ON public.raw_data_setlists TO anon, authenticated;
GRANT ALL ON public.raw_data_shows TO anon, authenticated;
GRANT ALL ON public.raw_data_songs TO anon, authenticated;
GRANT ALL ON public.raw_data_venues TO anon, authenticated;
GRANT ALL ON public.raw_data_jamcharts TO anon, authenticated;
GRANT ALL ON public.raw_data_latest TO anon, authenticated;
GRANT ALL ON public.raw_data_metadata TO anon, authenticated;
GRANT ALL ON public.raw_data_links TO anon, authenticated;
GRANT ALL ON public.raw_data_uploads TO anon, authenticated;
GRANT ALL ON public.raw_data_appearances TO anon, authenticated;
