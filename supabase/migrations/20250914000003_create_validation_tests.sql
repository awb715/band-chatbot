-- ============================================================================
-- SILVER LAYER VALIDATION TESTS AND QUALITY CHECKS
-- ============================================================================
-- 
-- This migration creates comprehensive validation tests for the Silver layer
-- using both pgTAP testing framework and custom validation functions.
--
-- Test Categories:
-- 1. Schema integrity tests
-- 2. Data completeness tests  
-- 3. Data quality tests
-- 4. Performance tests for chatbot queries
-- 5. Foreign key integrity tests
-- 6. Business rule validation tests
--
-- ============================================================================

-- ============================================================================
-- SECTION 1: INSTALL PGTAP (if not already installed)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgtap;

-- ============================================================================
-- SECTION 2: SCHEMA INTEGRITY TESTS
-- ============================================================================

-- Test function to verify all expected tables exist
CREATE OR REPLACE FUNCTION silver_etl.test_schema_integrity()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  expected_tables TEXT[] := ARRAY[
    'songs', 'venues', 'shows', 'setlists', 'jamcharts', 
    'latest', 'metadata', 'links', 'uploads', 'people', 'appearances'
  ];
  table_name TEXT;
  table_count INT;
  index_count INT;
BEGIN
  -- Test 1: All tables exist
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables 
  WHERE table_schema = 'silver' 
    AND table_name = ANY(expected_tables);
  
  RETURN QUERY SELECT 
    'All Silver tables exist'::TEXT,
    table_count = array_length(expected_tables, 1),
    format('Found %s of %s expected tables', table_count, array_length(expected_tables, 1))::TEXT;
  
  -- Test 2: Critical indexes exist
  SELECT COUNT(*) INTO index_count
  FROM pg_indexes 
  WHERE schemaname = 'silver' 
    AND indexname IN (
      'songs_slug_idx', 'venues_slug_idx', 'shows_date_idx', 
      'setlists_show_idx', 'setlists_song_idx'
    );
  
  RETURN QUERY SELECT 
    'Critical indexes exist'::TEXT,
    index_count >= 5,
    format('Found %s critical indexes', index_count)::TEXT;
  
  -- Test 3: Foreign key constraints exist
  SELECT COUNT(*) INTO table_count
  FROM information_schema.table_constraints
  WHERE constraint_schema = 'silver' 
    AND constraint_type = 'FOREIGN KEY';
  
  RETURN QUERY SELECT 
    'Foreign key constraints exist'::TEXT,
    table_count > 0,
    format('Found %s foreign key constraints', table_count)::TEXT;
END $$;

-- Test function to verify ETL functions exist
CREATE OR REPLACE FUNCTION silver_etl.test_etl_functions_exist()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  expected_functions TEXT[] := ARRAY[
    'process_songs', 'process_venues', 'process_shows', 'process_setlists',
    'process_jamcharts', 'process_people', 'process_appearances',
    'process_links', 'process_uploads', 'process_metadata', 'process_latest',
    'process_all_tables'
  ];
  function_count INT;
BEGIN
  SELECT COUNT(*) INTO function_count
  FROM information_schema.routines 
  WHERE routine_schema = 'silver' 
    AND routine_name = ANY(expected_functions);
  
  RETURN QUERY SELECT 
    'All ETL functions exist'::TEXT,
    function_count = array_length(expected_functions, 1),
    format('Found %s of %s expected functions', function_count, array_length(expected_functions, 1))::TEXT;
END $$;

-- ============================================================================
-- SECTION 3: DATA COMPLETENESS TESTS
-- ============================================================================

-- Test function to verify Bronze→Silver data flow
CREATE OR REPLACE FUNCTION silver_etl.test_data_completeness()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  bronze_songs_count INT;
  silver_songs_count INT;
  bronze_shows_count INT;
  silver_shows_count INT;
  bronze_venues_count INT;
  silver_venues_count INT;
  bronze_setlists_count INT;
  silver_setlists_count INT;
  processed_ratio NUMERIC;
BEGIN
  -- Count Bronze vs Silver records
  SELECT COUNT(*) INTO bronze_songs_count FROM raw_data.songs WHERE is_processed = TRUE;
  SELECT COUNT(*) INTO silver_songs_count FROM silver.songs;
  
  SELECT COUNT(*) INTO bronze_shows_count FROM raw_data.shows WHERE is_processed = TRUE;
  SELECT COUNT(*) INTO silver_shows_count FROM silver.shows;
  
  SELECT COUNT(*) INTO bronze_venues_count FROM raw_data.venues WHERE is_processed = TRUE;
  SELECT COUNT(*) INTO silver_venues_count FROM silver.venues;
  
  SELECT COUNT(*) INTO bronze_setlists_count FROM raw_data.setlists WHERE is_processed = TRUE;
  SELECT COUNT(*) INTO silver_setlists_count FROM silver.setlists;
  
  -- Test 1: Songs completeness
  RETURN QUERY SELECT 
    'Songs: Bronze→Silver completeness'::TEXT,
    (bronze_songs_count = 0 OR silver_songs_count >= bronze_songs_count * 0.95),
    format('Bronze: %s processed, Silver: %s (%.1f%% coverage)', 
           bronze_songs_count, silver_songs_count,
           CASE WHEN bronze_songs_count > 0 
                THEN (silver_songs_count::NUMERIC / bronze_songs_count * 100)
                ELSE 0 END)::TEXT;
  
  -- Test 2: Shows completeness
  RETURN QUERY SELECT 
    'Shows: Bronze→Silver completeness'::TEXT,
    (bronze_shows_count = 0 OR silver_shows_count >= bronze_shows_count * 0.95),
    format('Bronze: %s processed, Silver: %s (%.1f%% coverage)', 
           bronze_shows_count, silver_shows_count,
           CASE WHEN bronze_shows_count > 0 
                THEN (silver_shows_count::NUMERIC / bronze_shows_count * 100)
                ELSE 0 END)::TEXT;
  
  -- Test 3: Venues completeness
  RETURN QUERY SELECT 
    'Venues: Bronze→Silver completeness'::TEXT,
    (bronze_venues_count = 0 OR silver_venues_count >= bronze_venues_count * 0.95),
    format('Bronze: %s processed, Silver: %s (%.1f%% coverage)', 
           bronze_venues_count, silver_venues_count,
           CASE WHEN bronze_venues_count > 0 
                THEN (silver_venues_count::NUMERIC / bronze_venues_count * 100)
                ELSE 0 END)::TEXT;
  
  -- Test 4: Setlists completeness  
  RETURN QUERY SELECT 
    'Setlists: Bronze→Silver completeness'::TEXT,
    (bronze_setlists_count = 0 OR silver_setlists_count >= bronze_setlists_count * 0.9),
    format('Bronze: %s processed, Silver: %s (%.1f%% coverage)', 
           bronze_setlists_count, silver_setlists_count,
           CASE WHEN bronze_setlists_count > 0 
                THEN (silver_setlists_count::NUMERIC / bronze_setlists_count * 100)
                ELSE 0 END)::TEXT;
END $$;

-- ============================================================================
-- SECTION 4: DATA QUALITY TESTS
-- ============================================================================

-- Test function to verify data quality
CREATE OR REPLACE FUNCTION silver_etl.test_data_quality()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  songs_with_names INT;
  total_songs INT;
  shows_with_dates INT;
  total_shows INT;
  venues_with_names INT;
  total_venues INT;
  setlists_with_shows INT;
  total_setlists INT;
  duplicate_songs INT;
  duplicate_venues INT;
  invalid_dates INT;
BEGIN
  -- Test 1: Songs have names
  SELECT COUNT(*) INTO total_songs FROM silver.songs;
  SELECT COUNT(*) INTO songs_with_names FROM silver.songs WHERE name IS NOT NULL AND TRIM(name) != '';
  
  RETURN QUERY SELECT 
    'Songs have valid names'::TEXT,
    (total_songs = 0 OR songs_with_names::NUMERIC / total_songs >= 0.99),
    format('%s of %s songs have names (%.1f%%)', 
           songs_with_names, total_songs,
           CASE WHEN total_songs > 0 THEN songs_with_names::NUMERIC / total_songs * 100 ELSE 0 END)::TEXT;
  
  -- Test 2: Shows have valid dates
  SELECT COUNT(*) INTO total_shows FROM silver.shows;
  SELECT COUNT(*) INTO shows_with_dates FROM silver.shows 
  WHERE date IS NOT NULL AND date > '1900-01-01' AND date <= CURRENT_DATE + INTERVAL '1 year';
  
  RETURN QUERY SELECT 
    'Shows have valid dates'::TEXT,
    (total_shows = 0 OR shows_with_dates::NUMERIC / total_shows >= 0.99),
    format('%s of %s shows have valid dates (%.1f%%)', 
           shows_with_dates, total_shows,
           CASE WHEN total_shows > 0 THEN shows_with_dates::NUMERIC / total_shows * 100 ELSE 0 END)::TEXT;
  
  -- Test 3: Venues have names
  SELECT COUNT(*) INTO total_venues FROM silver.venues;
  SELECT COUNT(*) INTO venues_with_names FROM silver.venues WHERE name IS NOT NULL AND TRIM(name) != '';
  
  RETURN QUERY SELECT 
    'Venues have valid names'::TEXT,
    (total_venues = 0 OR venues_with_names::NUMERIC / total_venues >= 0.99),
    format('%s of %s venues have names (%.1f%%)', 
           venues_with_names, total_venues,
           CASE WHEN total_venues > 0 THEN venues_with_names::NUMERIC / total_venues * 100 ELSE 0 END)::TEXT;
  
  -- Test 4: Setlists reference valid shows
  SELECT COUNT(*) INTO total_setlists FROM silver.setlists;
  SELECT COUNT(*) INTO setlists_with_shows FROM silver.setlists WHERE show_id IS NOT NULL;
  
  RETURN QUERY SELECT 
    'Setlists reference valid shows'::TEXT,
    (total_setlists = 0 OR setlists_with_shows::NUMERIC / total_setlists >= 0.95),
    format('%s of %s setlists have show references (%.1f%%)', 
           setlists_with_shows, total_setlists,
           CASE WHEN total_setlists > 0 THEN setlists_with_shows::NUMERIC / total_setlists * 100 ELSE 0 END)::TEXT;
  
  -- Test 5: No duplicate songs by external_id
  SELECT COUNT(*) INTO duplicate_songs 
  FROM (SELECT external_id, COUNT(*) FROM silver.songs WHERE external_id IS NOT NULL GROUP BY external_id HAVING COUNT(*) > 1) dup;
  
  RETURN QUERY SELECT 
    'No duplicate songs by external_id'::TEXT,
    duplicate_songs = 0,
    format('Found %s duplicate song external_ids', duplicate_songs)::TEXT;
  
  -- Test 6: No duplicate venues by external_id
  SELECT COUNT(*) INTO duplicate_venues 
  FROM (SELECT external_id, COUNT(*) FROM silver.venues WHERE external_id IS NOT NULL GROUP BY external_id HAVING COUNT(*) > 1) dup;
  
  RETURN QUERY SELECT 
    'No duplicate venues by external_id'::TEXT,
    duplicate_venues = 0,
    format('Found %s duplicate venue external_ids', duplicate_venues)::TEXT;
  
  -- Test 7: No shows with invalid dates
  SELECT COUNT(*) INTO invalid_dates FROM silver.shows 
  WHERE date IS NULL OR date < '1900-01-01' OR date > CURRENT_DATE + INTERVAL '1 year';
  
  RETURN QUERY SELECT 
    'No shows with invalid dates'::TEXT,
    invalid_dates = 0,
    format('Found %s shows with invalid dates', invalid_dates)::TEXT;
END $$;

-- ============================================================================
-- SECTION 5: FOREIGN KEY INTEGRITY TESTS
-- ============================================================================

-- Test function to verify foreign key integrity
CREATE OR REPLACE FUNCTION silver_etl.test_foreign_key_integrity()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  orphaned_setlists INT;
  orphaned_appearances INT;
  orphaned_jamcharts INT;
  setlists_with_songs INT;
  total_setlists INT;
BEGIN
  -- Test 1: No orphaned setlists (setlists without valid shows)
  SELECT COUNT(*) INTO orphaned_setlists 
  FROM silver.setlists sl 
  LEFT JOIN silver.shows sh ON sl.show_id = sh.id 
  WHERE sl.show_id IS NOT NULL AND sh.id IS NULL;
  
  RETURN QUERY SELECT 
    'No orphaned setlists'::TEXT,
    orphaned_setlists = 0,
    format('Found %s setlists with invalid show references', orphaned_setlists)::TEXT;
  
  -- Test 2: No orphaned appearances (appearances without valid shows or people)
  SELECT COUNT(*) INTO orphaned_appearances 
  FROM silver.appearances a 
  LEFT JOIN silver.shows sh ON a.show_id = sh.id 
  LEFT JOIN silver.people p ON a.person_id = p.id
  WHERE (a.show_id IS NOT NULL AND sh.id IS NULL) 
     OR (a.person_id IS NOT NULL AND p.id IS NULL);
  
  RETURN QUERY SELECT 
    'No orphaned appearances'::TEXT,
    orphaned_appearances = 0,
    format('Found %s appearances with invalid references', orphaned_appearances)::TEXT;
  
  -- Test 3: No orphaned jamcharts (jamcharts without valid songs or shows)
  SELECT COUNT(*) INTO orphaned_jamcharts 
  FROM silver.jamcharts jc 
  LEFT JOIN silver.songs s ON jc.song_id = s.id 
  LEFT JOIN silver.shows sh ON jc.show_id = sh.id
  WHERE (jc.song_id IS NOT NULL AND s.id IS NULL) 
     OR (jc.show_id IS NOT NULL AND sh.id IS NULL);
  
  RETURN QUERY SELECT 
    'No orphaned jamcharts'::TEXT,
    orphaned_jamcharts = 0,
    format('Found %s jamcharts with invalid references', orphaned_jamcharts)::TEXT;
  
  -- Test 4: Good song resolution rate for setlists
  SELECT COUNT(*) INTO total_setlists FROM silver.setlists;
  SELECT COUNT(*) INTO setlists_with_songs FROM silver.setlists WHERE song_id IS NOT NULL;
  
  RETURN QUERY SELECT 
    'Good song resolution rate for setlists'::TEXT,
    (total_setlists = 0 OR setlists_with_songs::NUMERIC / total_setlists >= 0.8),
    format('%s of %s setlists have song references (%.1f%%)', 
           setlists_with_songs, total_setlists,
           CASE WHEN total_setlists > 0 THEN setlists_with_songs::NUMERIC / total_setlists * 100 ELSE 0 END)::TEXT;
END $$;

-- ============================================================================
-- SECTION 6: PERFORMANCE TESTS FOR CHATBOT QUERIES
-- ============================================================================

-- Test function to verify chatbot query performance
CREATE OR REPLACE FUNCTION silver_etl.test_chatbot_query_performance()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  start_time TIMESTAMPTZ;
  end_time TIMESTAMPTZ;
  query_time_ms INT;
  song_count INT;
  show_count INT;
  setlist_count INT;
BEGIN
  -- Only run performance tests if we have sufficient data
  SELECT COUNT(*) INTO song_count FROM silver.songs;
  SELECT COUNT(*) INTO show_count FROM silver.shows;
  SELECT COUNT(*) INTO setlist_count FROM silver.setlists;
  
  IF song_count < 10 OR show_count < 10 OR setlist_count < 10 THEN
    RETURN QUERY SELECT 
      'Chatbot query performance (skipped)'::TEXT,
      true,
      'Insufficient data for performance testing'::TEXT;
    RETURN;
  END IF;
  
  -- Test 1: "Most played songs this year" query performance
  start_time := clock_timestamp();
  
  PERFORM s.name, COUNT(*) as play_count
  FROM silver.setlists sl
  JOIN silver.songs s ON s.id = sl.song_id
  JOIN silver.shows sh ON sh.id = sl.show_id
  WHERE sh.show_year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
  GROUP BY s.id, s.name
  ORDER BY play_count DESC
  LIMIT 10;
  
  end_time := clock_timestamp();
  query_time_ms := EXTRACT(EPOCH FROM (end_time - start_time) * 1000)::INT;
  
  RETURN QUERY SELECT 
    'Most played songs query performance'::TEXT,
    query_time_ms < 1000,  -- Should complete in under 1 second
    format('Query completed in %s ms', query_time_ms)::TEXT;
  
  -- Test 2: "Songs at venue on date" query performance
  start_time := clock_timestamp();
  
  PERFORM sl.set_number, sl.position, COALESCE(s.name, sl.song_name) AS song
  FROM silver.shows sh
  JOIN silver.venues v ON v.id = sh.venue_id
  JOIN silver.setlists sl ON sl.show_id = sh.id
  LEFT JOIN silver.songs s ON s.id = sl.song_id
  WHERE sh.date > CURRENT_DATE - INTERVAL '1 year'
  ORDER BY sl.set_number, sl.position
  LIMIT 100;
  
  end_time := clock_timestamp();
  query_time_ms := EXTRACT(EPOCH FROM (end_time - start_time) * 1000)::INT;
  
  RETURN QUERY SELECT 
    'Songs at venue query performance'::TEXT,
    query_time_ms < 500,  -- Should complete in under 500ms
    format('Query completed in %s ms', query_time_ms)::TEXT;
  
  -- Test 3: "Venues in state" query performance
  start_time := clock_timestamp();
  
  PERFORM DISTINCT v.name, v.city, v.state
  FROM silver.shows sh
  JOIN silver.venues v ON v.id = sh.venue_id
  WHERE v.state IS NOT NULL
  ORDER BY v.name
  LIMIT 50;
  
  end_time := clock_timestamp();
  query_time_ms := EXTRACT(EPOCH FROM (end_time - start_time) * 1000)::INT;
  
  RETURN QUERY SELECT 
    'Venues in state query performance'::TEXT,
    query_time_ms < 300,  -- Should complete in under 300ms
    format('Query completed in %s ms', query_time_ms)::TEXT;
END $$;

-- ============================================================================
-- SECTION 7: BUSINESS RULE VALIDATION TESTS
-- ============================================================================

-- Test function to verify business rules
CREATE OR REPLACE FUNCTION silver_etl.test_business_rules()
RETURNS TABLE(test_name TEXT, result BOOLEAN, details TEXT) 
LANGUAGE plpgsql AS $$
DECLARE
  future_shows INT;
  negative_positions INT;
  invalid_set_numbers INT;
  unrealistic_durations INT;
BEGIN
  -- Test 1: No shows in the far future (more than 2 years)
  SELECT COUNT(*) INTO future_shows 
  FROM silver.shows 
  WHERE date > CURRENT_DATE + INTERVAL '2 years';
  
  RETURN QUERY SELECT 
    'No shows in far future'::TEXT,
    future_shows = 0,
    format('Found %s shows more than 2 years in future', future_shows)::TEXT;
  
  -- Test 2: No negative positions in setlists
  SELECT COUNT(*) INTO negative_positions 
  FROM silver.setlists 
  WHERE position IS NOT NULL AND position < 0;
  
  RETURN QUERY SELECT 
    'No negative setlist positions'::TEXT,
    negative_positions = 0,
    format('Found %s setlist entries with negative positions', negative_positions)::TEXT;
  
  -- Test 3: No invalid set numbers (should be 1, 2, 3, etc.)
  SELECT COUNT(*) INTO invalid_set_numbers 
  FROM silver.setlists 
  WHERE set_number IS NOT NULL AND (set_number < 1 OR set_number > 10);
  
  RETURN QUERY SELECT 
    'Valid set numbers'::TEXT,
    invalid_set_numbers = 0,
    format('Found %s setlist entries with invalid set numbers', invalid_set_numbers)::TEXT;
  
  -- Test 4: No unrealistic jam durations (over 2 hours)
  SELECT COUNT(*) INTO unrealistic_durations 
  FROM silver.jamcharts 
  WHERE duration_seconds IS NOT NULL AND duration_seconds > 7200;  -- 2 hours
  
  RETURN QUERY SELECT 
    'Realistic jam durations'::TEXT,
    unrealistic_durations = 0,
    format('Found %s jams with unrealistic durations (>2 hours)', unrealistic_durations)::TEXT;
END $$;

-- ============================================================================
-- SECTION 8: MASTER TEST RUNNER
-- ============================================================================

-- Master function to run all validation tests
CREATE OR REPLACE FUNCTION silver_etl.run_all_validation_tests()
RETURNS TABLE(
  test_category TEXT,
  test_name TEXT, 
  result BOOLEAN, 
  details TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RAISE NOTICE 'Running comprehensive Silver layer validation tests...';
  
  -- Schema integrity tests
  RETURN QUERY 
  SELECT 'Schema Integrity'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_schema_integrity() t;
  
  RETURN QUERY 
  SELECT 'Schema Integrity'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_etl_functions_exist() t;
  
  -- Data completeness tests
  RETURN QUERY 
  SELECT 'Data Completeness'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_data_completeness() t;
  
  -- Data quality tests
  RETURN QUERY 
  SELECT 'Data Quality'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_data_quality() t;
  
  -- Foreign key integrity tests
  RETURN QUERY 
  SELECT 'Foreign Key Integrity'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_foreign_key_integrity() t;
  
  -- Performance tests
  RETURN QUERY 
  SELECT 'Performance'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_chatbot_query_performance() t;
  
  -- Business rule tests
  RETURN QUERY 
  SELECT 'Business Rules'::TEXT, t.test_name, t.result, t.details 
  FROM silver_etl.test_business_rules() t;
  
  RAISE NOTICE 'All validation tests completed';
END $$;

-- ============================================================================
-- SECTION 9: EXAMPLE CHATBOT QUERIES FOR MANUAL TESTING
-- ============================================================================

-- Create a view with example chatbot queries for testing
CREATE OR REPLACE VIEW silver_etl.vw_example_chatbot_queries AS
WITH query_examples AS (
  SELECT 1 as query_id, 'Most played songs this year' as description,
  $$
  SELECT s.name, COUNT(*) as play_count
  FROM silver.setlists sl
  JOIN silver.songs s ON s.id = sl.song_id
  JOIN silver.shows sh ON sh.id = sl.show_id
  WHERE sh.show_year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
  GROUP BY s.id, s.name
  ORDER BY play_count DESC
  LIMIT 10;
  $$ as sql_query
  
  UNION ALL
  
  SELECT 2, 'Songs played at venue on specific date',
  $$
  SELECT sl.set_number, sl.position, COALESCE(s.name, sl.song_name) AS song
  FROM silver.shows sh
  JOIN silver.venues v ON v.id = sh.venue_id
  JOIN silver.setlists sl ON sl.show_id = sh.id
  LEFT JOIN silver.songs s ON s.id = sl.song_id
  WHERE v.slug = 'red-rocks-amphitheatre-morrison-co-usa' 
    AND sh.date = '2024-07-01'
  ORDER BY sl.set_number, sl.position;
  $$
  
  UNION ALL
  
  SELECT 3, 'Venues played in Colorado',
  $$
  SELECT DISTINCT v.name, v.city, COUNT(sh.id) as show_count
  FROM silver.shows sh
  JOIN silver.venues v ON v.id = sh.venue_id
  WHERE v.state ILIKE 'CO'
  GROUP BY v.id, v.name, v.city
  ORDER BY show_count DESC;
  $$
  
  UNION ALL
  
  SELECT 4, 'All jams of specific song',
  $$
  SELECT sh.date, v.name AS venue, s.name AS song, jc.duration_seconds, jc.jamchart_note
  FROM silver.jamcharts jc
  LEFT JOIN silver.songs s ON s.id = jc.song_id
  LEFT JOIN silver.shows sh ON sh.id = jc.show_id
  LEFT JOIN silver.venues v ON v.id = sh.venue_id
  WHERE s.slug = 'hot-tea' OR jc.song_name ILIKE 'Hot Tea%'
  ORDER BY sh.date DESC;
  $$
  
  UNION ALL
  
  SELECT 5, 'Last time they played specific song',
  $$
  SELECT MAX(sh.date) AS last_played, s.name
  FROM silver.setlists sl
  JOIN silver.songs s ON s.id = sl.song_id
  JOIN silver.shows sh ON sh.id = sl.show_id
  WHERE s.slug = 'arise'
  GROUP BY s.id, s.name;
  $$
  
  UNION ALL
  
  SELECT 6, 'Cover songs (not originals)',
  $$
  SELECT s.name, s.original_artist, COUNT(sl.id) as times_played
  FROM silver.songs s
  JOIN silver.setlists sl ON sl.song_id = s.id
  WHERE s.is_original = FALSE
  GROUP BY s.id, s.name, s.original_artist
  ORDER BY times_played DESC
  LIMIT 20;
  $$
)
SELECT * FROM query_examples;

COMMENT ON VIEW silver_etl.vw_example_chatbot_queries IS 'Example queries that the chatbot should be able to execute efficiently';

-- ============================================================================
-- SECTION 10: GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions for validation functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA silver_etl TO authenticated, anon;

-- ============================================================================
-- SUMMARY INFORMATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'SILVER LAYER VALIDATION TESTS CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Available test functions:';
  RAISE NOTICE '  - silver_etl.run_all_validation_tests()';
  RAISE NOTICE '  - silver_etl.test_schema_integrity()';
  RAISE NOTICE '  - silver_etl.test_data_completeness()';
  RAISE NOTICE '  - silver_etl.test_data_quality()';
  RAISE NOTICE '  - silver_etl.test_foreign_key_integrity()';
  RAISE NOTICE '  - silver_etl.test_chatbot_query_performance()';
  RAISE NOTICE '  - silver_etl.test_business_rules()';
  RAISE NOTICE '';
  RAISE NOTICE 'Example usage:';
  RAISE NOTICE '  SELECT * FROM silver_etl.run_all_validation_tests();';
  RAISE NOTICE '';
  RAISE NOTICE 'Chatbot query examples:';
  RAISE NOTICE '  SELECT * FROM silver_etl.vw_example_chatbot_queries;';
  RAISE NOTICE '========================================';
END $$;
