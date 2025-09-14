-- ============================================================================
-- SILVER LAYER ETL FUNCTIONS
-- ============================================================================
-- 
-- This migration creates comprehensive ETL functions for transforming Bronze
-- layer JSON data into clean, normalized Silver layer tables.
--
-- Features:
-- - Idempotent operations with conflict resolution
-- - Robust error handling and logging  
-- - Incremental processing (only unprocessed Bronze rows)
-- - Safe type casting with defensive parsing
-- - Foreign key resolution with fallback handling
-- - Comprehensive validation and data quality checks
-- 
-- Processing Order:
-- 1. Venues (dimension)
-- 2. Shows (fact, requires venues)
-- 3. Songs (dimension) 
-- 4. Setlists (fact, requires shows + songs)
-- 5. Jamcharts (fact, requires songs + shows)
-- 6. People (dimension)
-- 7. Appearances (fact, requires people + shows)
-- 8. Links, Uploads, Metadata (supporting facts)
-- 9. Latest (feed table)
--
-- ============================================================================

-- ============================================================================
-- SECTION 1: SONGS ETL
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_songs()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing songs...';
  
  FOR r IN
    SELECT id AS raw_id, external_id, data
    FROM raw_data.songs
    WHERE is_processed = FALSE
    ORDER BY received_at
  LOOP
    BEGIN
      INSERT INTO silver.songs (
        external_id, slug, name, is_original, original_artist,
        created_at, updated_at, source_raw_id, processed_at
      )
      SELECT
        (r.data->>'id'),
        LOWER(COALESCE(r.data->>'slug', '')),
        COALESCE(r.data->>'name', 'Unknown Song'),
        silver.safe_boolean(COALESCE(r.data->>'isoriginal', '1')),
        NULLIF(TRIM(r.data->>'original_artist'), ''),
        COALESCE((r.data->>'created_at')::timestamptz, now()),
        COALESCE((r.data->>'updated_at')::timestamptz, now()),
        r.raw_id,
        now()
      ON CONFLICT (external_id) DO UPDATE SET
        slug            = EXCLUDED.slug,
        name            = EXCLUDED.name,
        is_original     = EXCLUDED.is_original,
        original_artist = EXCLUDED.original_artist,
        updated_at      = EXCLUDED.updated_at,
        source_raw_id   = EXCLUDED.source_raw_id,
        processed_at    = now();

      -- Mark bronze row as processed
      UPDATE raw_data.songs 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('songs', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing song %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Songs processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_songs() IS 'Process raw_data.songs into silver.songs with validation and error handling';

-- ============================================================================
-- SECTION 2: VENUES ETL  
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_venues()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing venues...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.venues 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      INSERT INTO silver.venues (
        external_id, slug, name, city, state, country, zip,
        latitude, longitude, capacity, timezone,
        source_raw_id, processed_at
      )
      SELECT
        (r.data->>'venue_id'),
        LOWER(COALESCE(r.data->>'slug', '')),
        COALESCE(r.data->>'venuename', 'Unknown Venue'),
        NULLIF(TRIM(r.data->>'city'), ''),
        NULLIF(TRIM(r.data->>'state'), ''),
        NULLIF(TRIM(r.data->>'country'), ''),
        NULLIF(TRIM(r.data->>'zip'), ''),
        CASE WHEN r.data->>'latitude' ~ '^-?\d+\.?\d*$' 
             THEN (r.data->>'latitude')::NUMERIC 
             ELSE NULL END,
        CASE WHEN r.data->>'longitude' ~ '^-?\d+\.?\d*$' 
             THEN (r.data->>'longitude')::NUMERIC 
             ELSE NULL END,
        CASE WHEN r.data->>'capacity' ~ '^\d+$' AND (r.data->>'capacity')::INT > 0
             THEN (r.data->>'capacity')::INT 
             ELSE NULL END,
        NULLIF(TRIM(r.data->>'timezone'), ''),
        r.raw_id,
        now()
      ON CONFLICT (external_id) DO UPDATE SET
        slug         = EXCLUDED.slug,
        name         = EXCLUDED.name,
        city         = EXCLUDED.city,
        state        = EXCLUDED.state,
        country      = EXCLUDED.country,
        zip          = EXCLUDED.zip,
        latitude     = EXCLUDED.latitude,
        longitude    = EXCLUDED.longitude,
        capacity     = EXCLUDED.capacity,
        timezone     = EXCLUDED.timezone,
        updated_at   = now(),
        source_raw_id= EXCLUDED.source_raw_id,
        processed_at = now();

      -- Mark bronze row as processed
      UPDATE raw_data.venues 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('venues', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing venue %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Venues processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_venues() IS 'Process raw_data.venues into silver.venues with validation and error handling';

-- ============================================================================
-- SECTION 3: SHOWS ETL
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_shows()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  v_id UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing shows...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.shows 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Resolve venue by external_id or slug
      v_id := NULL;
      IF r.data->>'venue_id' IS NOT NULL THEN
        SELECT id INTO v_id 
        FROM silver.venues
        WHERE external_id = (r.data->>'venue_id');
      END IF;
      
      -- Fallback: try to match by slug if venue_id didn't work
      IF v_id IS NULL AND r.data->>'slug' IS NOT NULL THEN
        SELECT id INTO v_id 
        FROM silver.venues
        WHERE slug = LOWER(r.data->>'slug');
      END IF;

      INSERT INTO silver.shows (
        external_id, date, venue_id, venue_name, city, state, country,
        show_title, tour_id, tour_name, permalink, show_order,
        artist, artist_id, show_notes, source_raw_id, processed_at,
        created_at, updated_at
      )
      SELECT
        (r.data->>'show_id'),
        COALESCE((r.data->>'showdate')::DATE, '1970-01-01'::DATE),
        v_id,
        COALESCE(r.data->>'venuename', 'Unknown Venue'),
        NULLIF(TRIM(r.data->>'city'), ''),
        NULLIF(TRIM(r.data->>'state'), ''),
        NULLIF(TRIM(r.data->>'country'), ''),
        NULLIF(TRIM(r.data->>'showtitle'), ''),
        NULLIF(TRIM(r.data->>'tour_id'), ''),
        NULLIF(TRIM(r.data->>'tourname'), ''),
        NULLIF(TRIM(r.data->>'permalink'), ''),
        CASE WHEN r.data->>'showorder' ~ '^\d+$' 
             THEN (r.data->>'showorder')::INT 
             ELSE NULL END,
        COALESCE(r.data->>'artist', 'Unknown Artist'),
        NULLIF(TRIM(r.data->>'artist_id'), ''),
        NULLIF(TRIM(r.data->>'shownotes'), ''),
        r.raw_id,
        now(),
        COALESCE((r.data->>'created_at')::timestamptz, now()),
        COALESCE((r.data->>'updated_at')::timestamptz, now())
      ON CONFLICT (external_id) DO UPDATE SET
        date         = EXCLUDED.date,
        venue_id     = COALESCE(EXCLUDED.venue_id, silver.shows.venue_id),
        venue_name   = EXCLUDED.venue_name,
        city         = EXCLUDED.city,
        state        = EXCLUDED.state,
        country      = EXCLUDED.country,
        show_title   = EXCLUDED.show_title,
        tour_id      = EXCLUDED.tour_id,
        tour_name    = EXCLUDED.tour_name,
        permalink    = EXCLUDED.permalink,
        show_order   = EXCLUDED.show_order,
        artist       = EXCLUDED.artist,
        artist_id    = EXCLUDED.artist_id,
        show_notes   = EXCLUDED.show_notes,
        updated_at   = EXCLUDED.updated_at,
        source_raw_id= EXCLUDED.source_raw_id,
        processed_at = now();

      -- Mark bronze row as processed
      UPDATE raw_data.shows 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('shows', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing show %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Shows processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_shows() IS 'Process raw_data.shows into silver.shows with venue resolution and validation';

-- ============================================================================
-- SECTION 4: SETLISTS ETL
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_setlists()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  s_id UUID; 
  sh_id UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing setlists...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.setlists 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Resolve show by external_id
      sh_id := NULL;
      IF r.data->>'show_id' IS NOT NULL THEN
        SELECT id INTO sh_id 
        FROM silver.shows 
        WHERE external_id = (r.data->>'show_id');
      END IF;

      -- Resolve song by external_id or name
      s_id := NULL;
      IF r.data->>'song_id' IS NOT NULL THEN
        SELECT id INTO s_id 
        FROM silver.songs
        WHERE external_id = (r.data->>'song_id');
      END IF;
      
      -- Fallback: try to match by song name
      IF s_id IS NULL AND TRIM(COALESCE(r.data->>'songname', '')) != '' THEN
        SELECT id INTO s_id 
        FROM silver.songs
        WHERE LOWER(name) = LOWER(TRIM(r.data->>'songname'));
      END IF;

      INSERT INTO silver.setlists (
        external_id, show_id, song_id, show_uuid, song_uuid, song_name, position, set_number, set_type,
        is_original, original_artist, is_jam, is_reprise, is_verified, 
        is_recommended, is_jamchart, opener, soundcheck, jamchart_notes, 
        footnote, transition, transition_id, permalink,
        city, state, country, artist, venue_id, venuename, showdate, showyear,
        tour_id, tourname, artist_id, slug, css_class, shownotes, showorder,
        showtitle, tracktime,
        source_raw_id, processed_at
      )
      SELECT
        NULLIF(TRIM(r.data->>'uniqueid'), ''),
        r.data->>'show_id',
        r.data->>'song_id',
        sh_id,
        s_id,
        NULLIF(TRIM(r.data->>'songname'), ''),
        CASE WHEN r.data->>'position' ~ '^\d+$' 
             THEN (r.data->>'position')::INT 
             ELSE NULL END,
        CASE WHEN r.data->>'setnumber' ~ '^\d+$' 
             THEN (r.data->>'setnumber')::INT 
             ELSE NULL END,
        CASE LOWER(COALESCE(r.data->>'settype', r.data->>'css_class',''))
          WHEN 'encore' THEN 'encore'::silver.set_type_enum
          WHEN 'soundcheck' THEN 'soundcheck'::silver.set_type_enum
          WHEN 'set' THEN 'set'::silver.set_type_enum
          ELSE 'unknown'::silver.set_type_enum
        END,
        silver.safe_boolean(r.data->>'isoriginal'),
        NULLIF(TRIM(r.data->>'original_artist'), ''),
        silver.safe_boolean(r.data->>'isjam'),
        silver.safe_boolean(r.data->>'isreprise'),
        silver.safe_boolean(r.data->>'isverified'),
        silver.safe_boolean(r.data->>'isrecommended'),
        silver.safe_boolean(r.data->>'isjamchart'),
        silver.safe_boolean(r.data->>'opener'),
        silver.safe_boolean(r.data->>'soundcheck'),
        NULLIF(TRIM(r.data->>'jamchart_notes'), ''),
        NULLIF(TRIM(r.data->>'footnote'), ''),
        NULLIF(TRIM(r.data->>'transition'), ''),
        NULLIF(TRIM(r.data->>'transition_id'), ''),
        NULLIF(TRIM(r.data->>'permalink'), ''),
        NULLIF(TRIM(r.data->>'city'), ''),
        NULLIF(TRIM(r.data->>'state'), ''),
        NULLIF(TRIM(r.data->>'country'), ''),
        NULLIF(TRIM(r.data->>'artist'), ''),
        CASE WHEN r.data->>'venue_id' IS NOT NULL AND r.data->>'venue_id' != '' 
             THEN (r.data->>'venue_id')::INTEGER ELSE NULL END,
        NULLIF(TRIM(r.data->>'venuename'), ''),
        CASE WHEN r.data->>'showdate' IS NOT NULL AND r.data->>'showdate' != '' 
             THEN (r.data->>'showdate')::DATE ELSE NULL END,
        CASE WHEN r.data->>'showyear' IS NOT NULL AND r.data->>'showyear' != '' 
             THEN (r.data->>'showyear')::INTEGER ELSE NULL END,
        CASE WHEN r.data->>'tour_id' IS NOT NULL AND r.data->>'tour_id' != '' 
             THEN (r.data->>'tour_id')::INTEGER ELSE NULL END,
        NULLIF(TRIM(r.data->>'tourname'), ''),
        CASE WHEN r.data->>'artist_id' IS NOT NULL AND r.data->>'artist_id' != '' 
             THEN (r.data->>'artist_id')::INTEGER ELSE NULL END,
        NULLIF(TRIM(r.data->>'slug'), ''),
        NULLIF(TRIM(r.data->>'css_class'), ''),
        NULLIF(TRIM(r.data->>'shownotes'), ''),
        CASE WHEN r.data->>'showorder' IS NOT NULL AND r.data->>'showorder' != '' 
             THEN (r.data->>'showorder')::INTEGER ELSE NULL END,
        NULLIF(TRIM(r.data->>'showtitle'), ''),
        NULLIF(TRIM(r.data->>'tracktime'), ''),
        r.raw_id,
        now()
      WHERE sh_id IS NOT NULL  -- Only process if we have a valid show
      ON CONFLICT (external_id) DO UPDATE SET
        show_id         = EXCLUDED.show_id,
        song_id         = EXCLUDED.song_id,
        show_uuid       = COALESCE(EXCLUDED.show_uuid, silver.setlists.show_uuid),
        song_uuid       = COALESCE(EXCLUDED.song_uuid, silver.setlists.song_uuid),
        song_name       = EXCLUDED.song_name,
        position        = EXCLUDED.position,
        set_number      = EXCLUDED.set_number,
        set_type        = EXCLUDED.set_type,
        is_original     = EXCLUDED.is_original,
        original_artist = EXCLUDED.original_artist,
        is_jam          = EXCLUDED.is_jam,
        is_reprise      = EXCLUDED.is_reprise,
        is_verified     = EXCLUDED.is_verified,
        is_recommended  = EXCLUDED.is_recommended,
        is_jamchart     = EXCLUDED.is_jamchart,
        opener          = EXCLUDED.opener,
        soundcheck      = EXCLUDED.soundcheck,
        jamchart_notes  = EXCLUDED.jamchart_notes,
        footnote        = EXCLUDED.footnote,
        transition      = EXCLUDED.transition,
        transition_id   = EXCLUDED.transition_id,
        permalink       = EXCLUDED.permalink,
        city            = EXCLUDED.city,
        state           = EXCLUDED.state,
        country         = EXCLUDED.country,
        artist          = EXCLUDED.artist,
        venue_id        = EXCLUDED.venue_id,
        venuename       = EXCLUDED.venuename,
        showdate        = EXCLUDED.showdate,
        showyear        = EXCLUDED.showyear,
        tour_id         = EXCLUDED.tour_id,
        tourname        = EXCLUDED.tourname,
        artist_id       = EXCLUDED.artist_id,
        slug            = EXCLUDED.slug,
        css_class       = EXCLUDED.css_class,
        shownotes       = EXCLUDED.shownotes,
        showorder       = EXCLUDED.showorder,
        showtitle       = EXCLUDED.showtitle,
        tracktime       = EXCLUDED.tracktime,
        updated_at      = now(),
        source_raw_id   = EXCLUDED.source_raw_id,
        processed_at    = now();

      -- Mark bronze row as processed only if we successfully processed it
      IF sh_id IS NOT NULL THEN
        UPDATE raw_data.setlists 
        SET is_processed = TRUE, processed_at = now() 
        WHERE id = r.raw_id;
        cnt := cnt + 1;
      ELSE
        -- Log warning but don't mark as processed
        RAISE WARNING 'Setlist row % skipped - no matching show for show_id %', r.raw_id, r.data->>'show_id';
      END IF;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('setlists', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing setlist %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Setlists processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_setlists() IS 'Process raw_data.setlists into silver.setlists with show/song resolution';

-- ============================================================================
-- SECTION 5: JAMCHARTS ETL
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_jamcharts()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  s_id UUID; 
  sh_id UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing jamcharts...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.jamcharts 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Resolve song by external_id or name
      s_id := NULL;
      IF r.data->>'song_id' IS NOT NULL THEN
        SELECT id INTO s_id 
        FROM silver.songs
        WHERE external_id = (r.data->>'song_id');
      END IF;
      
      -- Fallback: try to match by song name
      IF s_id IS NULL AND TRIM(COALESCE(r.data->>'songname', '')) != '' THEN
        SELECT id INTO s_id 
        FROM silver.songs
        WHERE LOWER(name) = LOWER(TRIM(r.data->>'songname'));
      END IF;

      -- Resolve show by external_id or date
      sh_id := NULL;
      IF r.data->>'showid' IS NOT NULL THEN
        SELECT id INTO sh_id 
        FROM silver.shows 
        WHERE external_id = (r.data->>'showid');
      END IF;
      
      -- Fallback: try to match by show date if provided
      IF sh_id IS NULL AND r.data->>'showdate' IS NOT NULL THEN
        SELECT id INTO sh_id 
        FROM silver.shows 
        WHERE date = (r.data->>'showdate')::DATE
        LIMIT 1;  -- There might be multiple shows on same date
      END IF;

      INSERT INTO silver.jamcharts (
        external_id, song_id, song_name, show_id, position, set_number,
        duration_seconds, rating, jam_type, jamchart_note, footnote, 
        permalink, source_raw_id, processed_at
      )
      SELECT
        NULLIF(TRIM(r.data->>'uniqueid'), ''),
        s_id,
        NULLIF(TRIM(r.data->>'songname'), ''),
        sh_id,
        CASE WHEN r.data->>'position' ~ '^\d+$' 
             THEN (r.data->>'position')::INT 
             ELSE NULL END,
        CASE WHEN r.data->>'setnumber' ~ '^\d+$' 
             THEN (r.data->>'setnumber')::INT 
             ELSE NULL END,
        silver_etl.parse_mmss_to_seconds(r.data->>'tracktime'),
        CASE WHEN r.data->>'rating' ~ '^\d+$' 
             THEN (r.data->>'rating')::INT 
             ELSE NULL END,
        NULLIF(TRIM(r.data->>'jam_type'), ''),
        NULLIF(TRIM(r.data->>'jamchartnote'), ''),
        NULLIF(TRIM(r.data->>'footnote'), ''),
        NULLIF(TRIM(r.data->>'permalink'), ''),
        r.raw_id,
        now()
      ON CONFLICT (external_id) DO UPDATE SET
        song_id        = COALESCE(EXCLUDED.song_id, silver.jamcharts.song_id),
        song_name      = EXCLUDED.song_name,
        show_id        = COALESCE(EXCLUDED.show_id, silver.jamcharts.show_id),
        position       = EXCLUDED.position,
        set_number     = EXCLUDED.set_number,
        duration_seconds = EXCLUDED.duration_seconds,
        rating         = EXCLUDED.rating,
        jam_type       = EXCLUDED.jam_type,
        jamchart_note  = EXCLUDED.jamchart_note,
        footnote       = EXCLUDED.footnote,
        permalink      = EXCLUDED.permalink,
        updated_at     = now(),
        source_raw_id  = EXCLUDED.source_raw_id,
        processed_at   = now();

      -- Mark bronze row as processed
      UPDATE raw_data.jamcharts 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('jamcharts', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing jamchart %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Jamcharts processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_jamcharts() IS 'Process raw_data.jamcharts into silver.jamcharts with song/show resolution';

-- ============================================================================
-- SECTION 6: PEOPLE ETL
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_people()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing people...';
  
  -- Extract unique people from appearances data
  FOR r IN 
    SELECT DISTINCT 
      (data->>'person_id') as person_external_id,
      (data->>'personname') as person_name
    FROM raw_data.appearances 
    WHERE is_processed = FALSE 
      AND data->>'person_id' IS NOT NULL
      AND TRIM(COALESCE(data->>'personname', '')) != ''
  LOOP
    BEGIN
      INSERT INTO silver.people (external_id, name)
      VALUES (r.person_external_id, TRIM(r.person_name))
      ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        updated_at = now();
        
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('people', NULL, SQLERRM, jsonb_build_object('person_id', r.person_external_id, 'name', r.person_name));
      RAISE WARNING 'Error processing person %: %', r.person_external_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'People processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_people() IS 'Extract and process people from raw_data.appearances';

-- ============================================================================
-- SECTION 7: APPEARANCES ETL
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_appearances()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  p_id UUID; 
  sh_id UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing appearances...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.appearances 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Resolve person by external_id
      p_id := NULL;
      IF r.data->>'person_id' IS NOT NULL THEN
        SELECT id INTO p_id 
        FROM silver.people
        WHERE external_id = (r.data->>'person_id');
      END IF;

      -- Resolve show by external_id
      sh_id := NULL;
      IF r.data->>'show_id' IS NOT NULL THEN
        SELECT id INTO sh_id 
        FROM silver.shows 
        WHERE external_id = (r.data->>'show_id');
      END IF;

      INSERT INTO silver.appearances (
        external_id, person_id, show_id, role, instrument, notes,
        source_raw_id, processed_at
      )
      SELECT
        NULLIF(TRIM(r.data->>'slug'), ''),
        p_id,
        sh_id,
        NULLIF(TRIM(r.data->>'role'), ''),
        NULLIF(TRIM(r.data->>'instrument'), ''),
        NULLIF(TRIM(r.data->>'notes'), ''),
        r.raw_id,
        now()
      WHERE p_id IS NOT NULL AND sh_id IS NOT NULL  -- Only process if we have valid FK refs
      ON CONFLICT ON CONSTRAINT appearances_dedupe DO UPDATE SET
        role          = EXCLUDED.role,
        instrument    = EXCLUDED.instrument,
        notes         = EXCLUDED.notes,
        updated_at    = now(),
        source_raw_id = EXCLUDED.source_raw_id,
        processed_at  = now();

      -- Mark bronze row as processed only if we successfully processed it
      IF p_id IS NOT NULL AND sh_id IS NOT NULL THEN
        UPDATE raw_data.appearances 
        SET is_processed = TRUE, processed_at = now() 
        WHERE id = r.raw_id;
        cnt := cnt + 1;
      ELSE
        -- Log warning but don't mark as processed
        RAISE WARNING 'Appearance row % skipped - missing person_id or show_id', r.raw_id;
      END IF;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('appearances', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing appearance %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Appearances processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

COMMENT ON FUNCTION silver.process_appearances() IS 'Process raw_data.appearances into silver.appearances with person/show resolution';

-- ============================================================================
-- SECTION 8: SUPPORTING TABLES ETL (LINKS, UPLOADS, METADATA)
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_links()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  sh_uuid UUID; 
  s_uuid UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing links...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.links 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Try to resolve show and song if references exist
      sh_uuid := NULL;
      s_uuid := NULL;
      
      IF r.data->>'show_id' IS NOT NULL THEN
        SELECT id INTO sh_uuid FROM silver.shows WHERE external_id = (r.data->>'show_id');
      END IF;
      
      IF r.data->>'song_id' IS NOT NULL THEN
        SELECT id INTO s_uuid FROM silver.songs WHERE external_id = (r.data->>'song_id');
      END IF;

      INSERT INTO silver.links (
        external_id, url, title, description, link_type, show_uuid, song_uuid,
        source_raw_id, processed_at
      )
      VALUES (
        NULLIF(TRIM(r.data->>'link_id'), ''),
        COALESCE(TRIM(r.data->>'url'), 'unknown'),
        NULLIF(TRIM(r.data->>'title'), ''),
        NULLIF(TRIM(r.data->>'description'), ''),
        NULLIF(TRIM(r.data->>'link_type'), ''),
        sh_uuid,
        s_uuid,
        r.raw_id,
        now()
      )
      ON CONFLICT (external_id) DO UPDATE SET
        title         = EXCLUDED.title,
        description   = EXCLUDED.description,
        link_type     = EXCLUDED.link_type,
        updated_at    = now(),
        source_raw_id = EXCLUDED.source_raw_id,
        processed_at  = now();

      -- Mark bronze row as processed
      UPDATE raw_data.links 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('links', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing link %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Links processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

CREATE OR REPLACE FUNCTION silver.process_uploads()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  sh_id UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing uploads...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.uploads 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Try to resolve show if reference exists
      sh_id := NULL;
      IF r.data->>'show_id' IS NOT NULL THEN
        SELECT id INTO sh_id FROM silver.shows WHERE external_id = (r.data->>'show_id');
      END IF;

      INSERT INTO silver.uploads (
        external_id, url, filename, file_type, file_size, description, 
        attribution, show_id, upload_date, source_raw_id, processed_at
      )
      VALUES (
        NULLIF(TRIM(r.data->>'id'), ''),
        NULLIF(TRIM(r.data->>'URL'), ''),
        NULLIF(TRIM(r.data->>'img_name'), ''),
        NULLIF(TRIM(r.data->>'upload_type'), ''),
        CASE WHEN r.data->>'filesize' ~ '^\d+$' 
             THEN (r.data->>'filesize')::BIGINT 
             ELSE NULL END,
        NULLIF(TRIM(r.data->>'description'), ''),
        NULLIF(TRIM(r.data->>'attribution'), ''),
        sh_id,
        CASE WHEN r.data->>'upload_date' IS NOT NULL 
             THEN (r.data->>'upload_date')::DATE 
             ELSE NULL END,
        r.raw_id,
        now()
      )
      ON CONFLICT (external_id) DO UPDATE SET
        url           = EXCLUDED.url,
        filename      = EXCLUDED.filename,
        file_type     = EXCLUDED.file_type,
        file_size     = EXCLUDED.file_size,
        description   = EXCLUDED.description,
        attribution   = EXCLUDED.attribution,
        show_id       = EXCLUDED.show_id,
        upload_date   = EXCLUDED.upload_date,
        updated_at    = now(),
        source_raw_id = EXCLUDED.source_raw_id,
        processed_at  = now();

      -- Mark bronze row as processed
      UPDATE raw_data.uploads 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('uploads', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing upload %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Uploads processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

CREATE OR REPLACE FUNCTION silver.process_metadata()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  sh_uuid UUID; 
  s_uuid UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing metadata...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.metadata 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Try to resolve show and song if references exist
      sh_uuid := NULL;
      s_uuid := NULL;
      
      IF r.data->>'show_id' IS NOT NULL THEN
        SELECT id INTO sh_uuid FROM silver.shows WHERE external_id = (r.data->>'show_id');
      END IF;
      
      IF r.data->>'song_id' IS NOT NULL THEN
        SELECT id INTO s_uuid FROM silver.songs WHERE external_id = (r.data->>'song_id');
      END IF;

      INSERT INTO silver.metadata (
        external_id, key, value, data_type, show_uuid, song_uuid, permalink,
        city, state, artist, country, showdate, songname, artist_id, 
        song_slug, venuename, metadata_slug,
        source_raw_id, processed_at
      )
      VALUES (
        COALESCE(
          CONCAT(r.data->>'show_id', '-', r.data->>'song_id', '-', r.data->>'metadata_slug'),
          CONCAT(r.data->>'show_id', '-', r.data->>'song_id', '-', r.data->>'meta_name'),
          CONCAT(r.data->>'show_id', '-', r.data->>'song_id', '-', 'unknown')
        ),
        COALESCE(TRIM(r.data->>'meta_name'), TRIM(r.data->>'metadata_slug'), 'unknown'),
        NULLIF(TRIM(r.data->>'value'), ''),
        NULLIF(TRIM(r.data->>'data_type'), ''),
        sh_uuid,
        s_uuid,
        NULLIF(TRIM(r.data->>'permalink'), ''),
        NULLIF(TRIM(r.data->>'city'), ''),
        NULLIF(TRIM(r.data->>'state'), ''),
        NULLIF(TRIM(r.data->>'artist'), ''),
        NULLIF(TRIM(r.data->>'country'), ''),
        CASE WHEN r.data->>'showdate' IS NOT NULL AND r.data->>'showdate' != '' 
             THEN (r.data->>'showdate')::DATE ELSE NULL END,
        NULLIF(TRIM(r.data->>'songname'), ''),
        CASE WHEN r.data->>'artist_id' IS NOT NULL AND r.data->>'artist_id' != '' 
             THEN (r.data->>'artist_id')::INTEGER ELSE NULL END,
        NULLIF(TRIM(r.data->>'song_slug'), ''),
        NULLIF(TRIM(r.data->>'venuename'), ''),
        NULLIF(TRIM(r.data->>'metadata_slug'), ''),
        r.raw_id,
        now()
      )
      ON CONFLICT (external_id) DO UPDATE SET
        key           = EXCLUDED.key,
        value         = EXCLUDED.value,
        data_type     = EXCLUDED.data_type,
        show_uuid     = EXCLUDED.show_uuid,
        song_uuid     = EXCLUDED.song_uuid,
        permalink     = EXCLUDED.permalink,
        city          = EXCLUDED.city,
        state         = EXCLUDED.state,
        artist        = EXCLUDED.artist,
        country       = EXCLUDED.country,
        showdate      = EXCLUDED.showdate,
        songname      = EXCLUDED.songname,
        artist_id     = EXCLUDED.artist_id,
        song_slug     = EXCLUDED.song_slug,
        venuename     = EXCLUDED.venuename,
        metadata_slug = EXCLUDED.metadata_slug,
        updated_at    = now(),
        source_raw_id = EXCLUDED.source_raw_id,
        processed_at  = now();

      -- Mark bronze row as processed
      UPDATE raw_data.metadata 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('metadata', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing metadata %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Metadata processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

-- ============================================================================
-- SECTION 9: LATEST ETL (Feed Table)
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_latest()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE 
  r RECORD; 
  sh_id UUID; 
  s_id UUID; 
  v_id UUID; 
  cnt INT := 0;
  error_cnt INT := 0;
BEGIN
  RAISE NOTICE 'Processing latest...';
  
  FOR r IN 
    SELECT id AS raw_id, external_id, data 
    FROM raw_data.latest 
    WHERE is_processed = FALSE 
    ORDER BY received_at
  LOOP
    BEGIN
      -- Try to resolve show, song, and venue if references exist
      sh_id := NULL;
      s_id := NULL;
      v_id := NULL;
      
      IF r.data->>'show_id' IS NOT NULL THEN
        SELECT id INTO sh_id FROM silver.shows WHERE external_id = (r.data->>'show_id');
      END IF;
      
      IF r.data->>'song_id' IS NOT NULL THEN
        SELECT id INTO s_id FROM silver.songs WHERE external_id = (r.data->>'song_id');
      END IF;
      
      IF r.data->>'venue_id' IS NOT NULL THEN
        SELECT id INTO v_id FROM silver.venues WHERE external_id = (r.data->>'venue_id');
      END IF;

      INSERT INTO silver.latest (
        external_id, type, show_id, song_id, venue_id, artist, artist_id,
        songname, venuename, city, state, country, position, set_number,
        is_original, original_artist, is_jam, is_reprise, is_verified,
        is_recommended, is_jamchart, opener, soundcheck, jamchart_notes,
        footnote, tour_id, tourname, permalink, slug, transition, transition_id,
        data, source_raw_id, processed_at
      )
      VALUES (
        NULLIF(TRIM(r.data->>'uniqueid'), ''),
        CASE LOWER(COALESCE(r.data->>'type', 'other'))
          WHEN 'show' THEN 'show'::silver.latest_type_enum
          WHEN 'setlist' THEN 'setlist'::silver.latest_type_enum
          WHEN 'song' THEN 'song'::silver.latest_type_enum
          WHEN 'venue' THEN 'venue'::silver.latest_type_enum
          WHEN 'jamchart' THEN 'jamchart'::silver.latest_type_enum
          WHEN 'link' THEN 'link'::silver.latest_type_enum
          WHEN 'upload' THEN 'upload'::silver.latest_type_enum
          WHEN 'metadata' THEN 'metadata'::silver.latest_type_enum
          ELSE 'other'::silver.latest_type_enum
        END,
        sh_id,
        s_id,
        v_id,
        NULLIF(TRIM(r.data->>'artist'), ''),
        NULLIF(TRIM(r.data->>'artist_id'), ''),
        NULLIF(TRIM(r.data->>'songname'), ''),
        NULLIF(TRIM(r.data->>'venuename'), ''),
        NULLIF(TRIM(r.data->>'city'), ''),
        NULLIF(TRIM(r.data->>'state'), ''),
        NULLIF(TRIM(r.data->>'country'), ''),
        CASE WHEN r.data->>'position' ~ '^\d+$' 
             THEN (r.data->>'position')::INT 
             ELSE NULL END,
        CASE WHEN r.data->>'setnumber' ~ '^\d+$' 
             THEN (r.data->>'setnumber')::INT 
             ELSE NULL END,
        silver.safe_boolean(r.data->>'isoriginal'),
        NULLIF(TRIM(r.data->>'original_artist'), ''),
        silver.safe_boolean(r.data->>'isjam'),
        silver.safe_boolean(r.data->>'isreprise'),
        silver.safe_boolean(r.data->>'isverified'),
        silver.safe_boolean(r.data->>'isrecommended'),
        silver.safe_boolean(r.data->>'isjamchart'),
        silver.safe_boolean(r.data->>'opener'),
        silver.safe_boolean(r.data->>'soundcheck'),
        NULLIF(TRIM(r.data->>'jamchart_notes'), ''),
        NULLIF(TRIM(r.data->>'footnote'), ''),
        NULLIF(TRIM(r.data->>'tour_id'), ''),
        NULLIF(TRIM(r.data->>'tourname'), ''),
        NULLIF(TRIM(r.data->>'permalink'), ''),
        NULLIF(TRIM(r.data->>'slug'), ''),
        NULLIF(TRIM(r.data->>'transition'), ''),
        NULLIF(TRIM(r.data->>'transition_id'), ''),
        r.data,  -- Keep full JSON payload
        r.raw_id,
        now()
      )
      ON CONFLICT (external_id) DO UPDATE SET
        type            = EXCLUDED.type,
        show_id         = EXCLUDED.show_id,
        song_id         = EXCLUDED.song_id,
        venue_id        = EXCLUDED.venue_id,
        artist          = EXCLUDED.artist,
        artist_id       = EXCLUDED.artist_id,
        songname        = EXCLUDED.songname,
        venuename       = EXCLUDED.venuename,
        city            = EXCLUDED.city,
        state           = EXCLUDED.state,
        country         = EXCLUDED.country,
        position        = EXCLUDED.position,
        set_number      = EXCLUDED.set_number,
        is_original     = EXCLUDED.is_original,
        original_artist = EXCLUDED.original_artist,
        is_jam          = EXCLUDED.is_jam,
        is_reprise      = EXCLUDED.is_reprise,
        is_verified     = EXCLUDED.is_verified,
        is_recommended  = EXCLUDED.is_recommended,
        is_jamchart     = EXCLUDED.is_jamchart,
        opener          = EXCLUDED.opener,
        soundcheck      = EXCLUDED.soundcheck,
        jamchart_notes  = EXCLUDED.jamchart_notes,
        footnote        = EXCLUDED.footnote,
        tour_id         = EXCLUDED.tour_id,
        tourname        = EXCLUDED.tourname,
        permalink       = EXCLUDED.permalink,
        slug            = EXCLUDED.slug,
        transition      = EXCLUDED.transition,
        transition_id   = EXCLUDED.transition_id,
        data            = EXCLUDED.data,
        updated_at      = now(),
        source_raw_id   = EXCLUDED.source_raw_id,
        processed_at    = now();

      -- Mark bronze row as processed
      UPDATE raw_data.latest 
      SET is_processed = TRUE, processed_at = now() 
      WHERE id = r.raw_id;
      
      cnt := cnt + 1;
      
    EXCEPTION WHEN others THEN
      error_cnt := error_cnt + 1;
      INSERT INTO silver_etl.error_log(table_name, raw_id, error_msg, payload)
      VALUES ('latest', r.raw_id, SQLERRM, r.data);
      RAISE WARNING 'Error processing latest %: %', r.raw_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Latest processing complete: % processed, % errors', cnt, error_cnt;
  RETURN cnt;
END $$;

-- ============================================================================
-- SECTION 10: MASTER ETL FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION silver.process_all_tables()
RETURNS JSON LANGUAGE plpgsql AS $$
DECLARE 
  start_time TIMESTAMPTZ := clock_timestamp();
  results JSON;
  venues_count INT;
  shows_count INT;
  songs_count INT;
  setlists_count INT;
  jamcharts_count INT;
  people_count INT;
  appearances_count INT;
  links_count INT;
  uploads_count INT;
  metadata_count INT;
  latest_count INT;
  total_count INT;
  processing_time_ms INT;
BEGIN
  RAISE NOTICE 'Starting Silver ETL processing in dependency order...';
  
  -- Process in dependency order to ensure foreign keys resolve
  venues_count := silver.process_venues();
  shows_count := silver.process_shows();
  songs_count := silver.process_songs();
  setlists_count := silver.process_setlists();
  jamcharts_count := silver.process_jamcharts();
  people_count := silver.process_people();
  appearances_count := silver.process_appearances();
  links_count := silver.process_links();
  uploads_count := silver.process_uploads();
  metadata_count := silver.process_metadata();
  latest_count := silver.process_latest();
  
  total_count := venues_count + shows_count + songs_count + setlists_count + 
                 jamcharts_count + people_count + appearances_count + 
                 links_count + uploads_count + metadata_count + latest_count;
  
  processing_time_ms := EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INT;
  
  SELECT json_build_object(
    'success', true,
    'timestamp', clock_timestamp(),
    'processing_time_ms', processing_time_ms,
    'total_records_processed', total_count,
    'table_results', json_build_object(
      'venues', venues_count,
      'shows', shows_count,
      'songs', songs_count,
      'setlists', setlists_count,
      'jamcharts', jamcharts_count,
      'people', people_count,
      'appearances', appearances_count,
      'links', links_count,
      'uploads', uploads_count,
      'metadata', metadata_count,
      'latest', latest_count
    )
  ) INTO results;
  
  RAISE NOTICE 'Silver ETL processing complete: % records in % ms', total_count, processing_time_ms;
  
  RETURN results;
END $$;

COMMENT ON FUNCTION silver.process_all_tables() IS 'Master ETL function that processes all Bronze→Silver transformations in dependency order';

-- ============================================================================
-- SECTION 11: ERROR REPORTING VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW silver_etl.vw_error_summary AS
SELECT 
  table_name,
  COUNT(*) as error_count,
  MAX(error_at) as last_error_at,
  string_agg(DISTINCT LEFT(error_msg, 100), '; ') as sample_errors
FROM silver_etl.error_log
GROUP BY table_name
ORDER BY error_count DESC;

COMMENT ON VIEW silver_etl.vw_error_summary IS 'Summary of ETL errors by table with sample error messages';

-- Grant permissions for the silver schema and functions
GRANT USAGE ON SCHEMA silver TO authenticated, anon;
GRANT USAGE ON SCHEMA silver_etl TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA silver TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA silver_etl TO authenticated, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver TO authenticated, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver_etl TO authenticated, anon;

-- Grant access to sequence objects
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA silver TO authenticated, anon;
