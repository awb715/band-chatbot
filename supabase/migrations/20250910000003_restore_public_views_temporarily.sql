-- Temporarily restore public views for Bronze layer access
-- This is a workaround until schemas are properly exposed

-- ============================================================================
-- RESTORE BRONZE LAYER PUBLIC VIEWS (TEMPORARY)
-- ============================================================================

CREATE OR REPLACE VIEW public.raw_data_songs AS
SELECT * FROM raw_data.songs;

CREATE OR REPLACE VIEW public.raw_data_shows AS
SELECT * FROM raw_data.shows;

CREATE OR REPLACE VIEW public.raw_data_venues AS
SELECT * FROM raw_data.venues;

CREATE OR REPLACE VIEW public.raw_data_setlists AS
SELECT * FROM raw_data.setlists;

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

-- ============================================================================
-- RESTORE SILVER LAYER PUBLIC VIEWS (TEMPORARY)
-- ============================================================================

CREATE OR REPLACE VIEW public.silver_songs AS
SELECT * FROM silver.songs;

-- ============================================================================
-- GRANT ACCESS TO VIEWS
-- ============================================================================

GRANT ALL ON public.raw_data_songs TO anon, authenticated;
GRANT ALL ON public.raw_data_shows TO anon, authenticated;
GRANT ALL ON public.raw_data_venues TO anon, authenticated;
GRANT ALL ON public.raw_data_setlists TO anon, authenticated;
GRANT ALL ON public.raw_data_jamcharts TO anon, authenticated;
GRANT ALL ON public.raw_data_latest TO anon, authenticated;
GRANT ALL ON public.raw_data_metadata TO anon, authenticated;
GRANT ALL ON public.raw_data_links TO anon, authenticated;
GRANT ALL ON public.raw_data_uploads TO anon, authenticated;
GRANT ALL ON public.raw_data_appearances TO anon, authenticated;
GRANT ALL ON public.silver_songs TO anon, authenticated;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON VIEW public.raw_data_songs IS 'Temporary view for Bronze layer access';
COMMENT ON VIEW public.silver_songs IS 'Temporary view for Silver layer access';
