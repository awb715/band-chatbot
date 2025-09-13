-- Widen silver.latest to have explicit columns for common fields from raw JSON

-- Add columns if they do not exist
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='silver' AND table_name='latest' AND column_name='city'
  ) THEN
    ALTER TABLE silver.latest ADD COLUMN city TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='slug') THEN
    ALTER TABLE silver.latest ADD COLUMN slug TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='isjam') THEN
    ALTER TABLE silver.latest ADD COLUMN isjam BOOLEAN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='state') THEN
    ALTER TABLE silver.latest ADD COLUMN state TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='artist') THEN
    ALTER TABLE silver.latest ADD COLUMN artist TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='opener') THEN
    ALTER TABLE silver.latest ADD COLUMN opener TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='country') THEN
    ALTER TABLE silver.latest ADD COLUMN country TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='settype') THEN
    ALTER TABLE silver.latest ADD COLUMN settype TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='show_id') THEN
    ALTER TABLE silver.latest ADD COLUMN show_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='song_id') THEN
    ALTER TABLE silver.latest ADD COLUMN song_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='tour_id') THEN
    ALTER TABLE silver.latest ADD COLUMN tour_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='footnote') THEN
    ALTER TABLE silver.latest ADD COLUMN footnote TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='position') THEN
    ALTER TABLE silver.latest ADD COLUMN position INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='showdate') THEN
    ALTER TABLE silver.latest ADD COLUMN showdate DATE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='showyear') THEN
    ALTER TABLE silver.latest ADD COLUMN showyear INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='songname') THEN
    ALTER TABLE silver.latest ADD COLUMN songname TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='tourname') THEN
    ALTER TABLE silver.latest ADD COLUMN tourname TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='uniqueid') THEN
    ALTER TABLE silver.latest ADD COLUMN uniqueid TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='venue_id') THEN
    ALTER TABLE silver.latest ADD COLUMN venue_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='artist_id') THEN
    ALTER TABLE silver.latest ADD COLUMN artist_id TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='isreprise') THEN
    ALTER TABLE silver.latest ADD COLUMN isreprise BOOLEAN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='permalink') THEN
    ALTER TABLE silver.latest ADD COLUMN permalink TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='setnumber') THEN
    ALTER TABLE silver.latest ADD COLUMN setnumber INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='shownotes') THEN
    ALTER TABLE silver.latest ADD COLUMN shownotes TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='showorder') THEN
    ALTER TABLE silver.latest ADD COLUMN showorder INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='showtitle') THEN
    ALTER TABLE silver.latest ADD COLUMN showtitle TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='venuename') THEN
    ALTER TABLE silver.latest ADD COLUMN venuename TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='isjamchart') THEN
    ALTER TABLE silver.latest ADD COLUMN isjamchart BOOLEAN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='isoriginal') THEN
    ALTER TABLE silver.latest ADD COLUMN isoriginal BOOLEAN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='isverified') THEN
    ALTER TABLE silver.latest ADD COLUMN isverified BOOLEAN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='soundcheck') THEN
    ALTER TABLE silver.latest ADD COLUMN soundcheck TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='transition') THEN
    ALTER TABLE silver.latest ADD COLUMN transition TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='transition_id') THEN
    ALTER TABLE silver.latest ADD COLUMN transition_id INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='jamchart_notes') THEN
    ALTER TABLE silver.latest ADD COLUMN jamchart_notes TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='silver' AND table_name='latest' AND column_name='original_artist') THEN
    ALTER TABLE silver.latest ADD COLUMN original_artist TEXT;
  END IF;
END $$;

-- Update ETL to populate the new columns
CREATE OR REPLACE FUNCTION silver.process_latest()
RETURNS TABLE(processed_count INTEGER, error_count INTEGER, processing_time_ms INTEGER) AS $$
DECLARE
  start_time TIMESTAMPTZ := clock_timestamp();
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  INSERT INTO silver.latest (
    external_id, type, data, created_at, updated_at, source_raw_id,
    city, slug, isjam, state, artist, opener, country, settype,
    show_id, song_id, tour_id, footnote, position, showdate, showyear,
    songname, tourname, uniqueid, venue_id, artist_id, isreprise,
    permalink, setnumber, shownotes, showorder, showtitle, venuename,
    isjamchart, isoriginal, isverified, soundcheck, transition, transition_id,
    jamchart_notes, original_artist
  )
  SELECT 
    external_id,
    COALESCE(data->>'type', data->>'settype', 'unknown')                                   AS type,
    data                                                                                    AS data,
    COALESCE(NULLIF(data->>'created_at','')::timestamptz,
             NULLIF(data->>'showdate','')::date)::timestamptz                              AS created_at,
    NULLIF(data->>'updated_at','')::timestamptz                                             AS updated_at,
    id                                                                                      AS source_raw_id,
    data->>'city'                                                                           AS city,
    data->>'slug'                                                                           AS slug,
    COALESCE((data->>'isjam')::int,0)::boolean                                              AS isjam,
    data->>'state'                                                                          AS state,
    data->>'artist'                                                                         AS artist,
    data->>'opener'                                                                         AS opener,
    data->>'country'                                                                        AS country,
    data->>'settype'                                                                        AS settype,
    (data->>'show_id')                                                                      AS show_id,
    (data->>'song_id')                                                                      AS song_id,
    (data->>'tour_id')                                                                      AS tour_id,
    data->>'footnote'                                                                       AS footnote,
    NULLIF(data->>'position','')::int                                                       AS position,
    NULLIF(data->>'showdate','')::date                                                      AS showdate,
    NULLIF(data->>'showyear','')::int                                                       AS showyear,
    data->>'songname'                                                                       AS songname,
    data->>'tourname'                                                                       AS tourname,
    data->>'uniqueid'                                                                       AS uniqueid,
    (data->>'venue_id')                                                                     AS venue_id,
    (data->>'artist_id')                                                                    AS artist_id,
    COALESCE((data->>'isreprise')::int,0)::boolean                                          AS isreprise,
    data->>'permalink'                                                                      AS permalink,
    NULLIF(data->>'setnumber','')::int                                                      AS setnumber,
    data->>'shownotes'                                                                      AS shownotes,
    NULLIF(data->>'showorder','')::int                                                      AS showorder,
    data->>'showtitle'                                                                      AS showtitle,
    data->>'venuename'                                                                      AS venuename,
    COALESCE((data->>'isjamchart')::int,0)::boolean                                         AS isjamchart,
    COALESCE((data->>'isoriginal')::int,0)::boolean                                         AS isoriginal,
    COALESCE((data->>'isverified')::int,0)::boolean                                         AS isverified,
    data->>'soundcheck'                                                                     AS soundcheck,
    data->>'transition'                                                                     AS transition,
    NULLIF(data->>'transition_id','')::int                                                  AS transition_id,
    data->>'jamchart_notes'                                                                 AS jamchart_notes,
    data->>'original_artist'                                                                AS original_artist
  FROM raw_data.latest
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    type = EXCLUDED.type,
    data = EXCLUDED.data,
    created_at = EXCLUDED.created_at,
    updated_at = EXCLUDED.updated_at,
    city = EXCLUDED.city,
    slug = EXCLUDED.slug,
    isjam = EXCLUDED.isjam,
    state = EXCLUDED.state,
    artist = EXCLUDED.artist,
    opener = EXCLUDED.opener,
    country = EXCLUDED.country,
    settype = EXCLUDED.settype,
    show_id = EXCLUDED.show_id,
    song_id = EXCLUDED.song_id,
    tour_id = EXCLUDED.tour_id,
    footnote = EXCLUDED.footnote,
    position = EXCLUDED.position,
    showdate = EXCLUDED.showdate,
    showyear = EXCLUDED.showyear,
    songname = EXCLUDED.songname,
    tourname = EXCLUDED.tourname,
    uniqueid = EXCLUDED.uniqueid,
    venue_id = EXCLUDED.venue_id,
    artist_id = EXCLUDED.artist_id,
    isreprise = EXCLUDED.isreprise,
    permalink = EXCLUDED.permalink,
    setnumber = EXCLUDED.setnumber,
    shownotes = EXCLUDED.shownotes,
    showorder = EXCLUDED.showorder,
    showtitle = EXCLUDED.showtitle,
    venuename = EXCLUDED.venuename,
    isjamchart = EXCLUDED.isjamchart,
    isoriginal = EXCLUDED.isoriginal,
    isverified = EXCLUDED.isverified,
    soundcheck = EXCLUDED.soundcheck,
    transition = EXCLUDED.transition,
    transition_id = EXCLUDED.transition_id,
    jamchart_notes = EXCLUDED.jamchart_notes,
    original_artist = EXCLUDED.original_artist,
    processed_at = NOW();

  GET DIAGNOSTICS processed_count = ROW_COUNT;

  UPDATE raw_data.latest 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM silver.latest 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );

  RETURN QUERY SELECT processed_count,
                       error_count,
                       (EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;


