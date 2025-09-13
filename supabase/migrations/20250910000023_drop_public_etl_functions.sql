-- Remove public ETL wrappers to keep ETL logic within the silver schema only

DO $$ BEGIN
  -- Drop without parameters only
  PERFORM 1;
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_songs() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_all_tables() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_shows() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_setlists() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_venues() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_latest() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_metadata() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_links() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_uploads() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_appearances() CASCADE';
  EXECUTE 'DROP FUNCTION IF EXISTS public.process_jamcharts() CASCADE';
EXCEPTION WHEN OTHERS THEN
  -- continue on errors to avoid blocking deployment
  NULL;
END $$;


