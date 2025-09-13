# 📊 Tabular Processing Architecture

## 🎯 Overview

Instead of RAG, we'll process each ElGoose API endpoint into clean, structured tabular tables optimized for:
- **Direct SQL queries** for chatbot responses
- **Analytics and reporting** 
- **Scalable data processing**
- **Easy maintenance and debugging**

## 🏗️ Architecture Design

```
ElGoose APIs → Bronze (Raw) → Silver (Tabular) → Gold (Analytics)
     ↓              ↓              ↓              ↓
  Raw JSON      Clean Tables    Aggregated     Chatbot
  Storage       Per Endpoint    Analytics      Queries
```

## 📋 Endpoint-to-Table Mapping

### Current ElGoose Endpoints → Target Tables

| Endpoint | Bronze Table | Silver Table | Gold Table | Purpose |
|----------|--------------|--------------|------------|---------|
| **Songs** | `raw_data.songs` | `silver.songs` | `gold.songs` | Song catalog, metadata |
| **Shows** | `raw_data.shows` | `silver.shows` | `gold.shows` | Concert dates, venues |
| **Setlists** | `raw_data.setlists` | `silver.setlists` | `gold.setlists` | Song performances |
| **Venues** | `raw_data.venues` | `silver.venues` | `gold.venues` | Venue information |
| **Latest** | `raw_data.latest` | `silver.latest` | `gold.latest` | Recent updates |
| **Metadata** | `raw_data.metadata` | `silver.metadata` | `gold.metadata` | System metadata |
| **Links** | `raw_data.links` | `silver.links` | `gold.links` | External links |
| **Uploads** | `raw_data.uploads` | `silver.uploads` | `gold.uploads` | Media files |
| **Appearances** | `raw_data.appearances` | `silver.appearances` | `gold.appearances` | Artist appearances |
| **Jamcharts** | `raw_data.jamcharts` | `silver.jamcharts` | `gold.jamcharts` | Performance notes |

## 🥈 Silver Layer Design (Tabular Processing)

### 1. Songs Table
```sql
CREATE TABLE silver.songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  is_original BOOLEAN NOT NULL DEFAULT false,
  original_artist TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id INTEGER REFERENCES raw_data.songs(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_silver_songs_name ON silver.songs(name);
CREATE INDEX idx_silver_songs_slug ON silver.songs(slug);
CREATE INDEX idx_silver_songs_original ON silver.songs(is_original);
CREATE INDEX idx_silver_songs_artist ON silver.songs(original_artist);
```

### 2. Shows Table
```sql
CREATE TABLE silver.shows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  show_date DATE NOT NULL,
  venue_name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  country TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id INTEGER REFERENCES raw_data.shows(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_silver_shows_date ON silver.shows(show_date);
CREATE INDEX idx_silver_shows_venue ON silver.shows(venue_name);
CREATE INDEX idx_silver_shows_city ON silver.shows(city);
CREATE INDEX idx_silver_shows_state ON silver.shows(state);
```

### 3. Setlists Table
```sql
CREATE TABLE silver.setlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  song_name TEXT NOT NULL,
  show_date DATE NOT NULL,
  venue_name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  song_order INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id INTEGER REFERENCES raw_data.setlists(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_silver_setlists_song ON silver.setlists(song_name);
CREATE INDEX idx_silver_setlists_date ON silver.setlists(show_date);
CREATE INDEX idx_silver_setlists_venue ON silver.setlists(venue_name);
CREATE INDEX idx_silver_setlists_order ON silver.setlists(song_order);
```

### 4. Venues Table
```sql
CREATE TABLE silver.venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  country TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id INTEGER REFERENCES raw_data.venues(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_silver_venues_name ON silver.venues(name);
CREATE INDEX idx_silver_venues_city ON silver.venues(city);
CREATE INDEX idx_silver_venues_state ON silver.venues(state);
```

## 🔄 Orchestrated Processing System

### 1. Processing Pipeline Architecture
```sql
-- Create processing status table
CREATE TABLE processing_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  layer TEXT NOT NULL, -- 'bronze', 'silver', 'gold'
  status TEXT NOT NULL, -- 'pending', 'processing', 'completed', 'failed'
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  records_processed INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create processing queue table
CREATE TABLE processing_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  layer TEXT NOT NULL,
  priority INTEGER DEFAULT 1,
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. ETL Functions for Each Endpoint

#### Songs Processing
```sql
CREATE OR REPLACE FUNCTION silver.process_songs()
RETURNS TABLE (
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER
) AS $$
DECLARE
  start_time TIMESTAMP;
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
  record RECORD;
BEGIN
  start_time := clock_timestamp();
  
  -- Insert/update songs from raw data
  INSERT INTO silver.songs (
    external_id, name, slug, is_original, original_artist,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'name' as name,
    data->>'slug' as slug,
    COALESCE((data->>'isoriginal')::boolean, false) as is_original,
    data->>'original_artist' as original_artist,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.songs
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    is_original = EXCLUDED.is_original,
    original_artist = EXCLUDED.original_artist,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  -- Mark as processed
  UPDATE raw_data.songs 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM silver.songs 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  -- Update processing status
  INSERT INTO processing_status (table_name, layer, status, records_processed, completed_at)
  VALUES ('songs', 'silver', 'completed', processed_count, NOW());
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;
```

#### Shows Processing
```sql
CREATE OR REPLACE FUNCTION silver.process_shows()
RETURNS TABLE (
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER
) AS $$
DECLARE
  start_time TIMESTAMP;
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  start_time := clock_timestamp();
  
  INSERT INTO silver.shows (
    external_id, show_date, venue_name, city, state, country,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    (data->>'showdate')::date as show_date,
    data->>'venuename' as venue_name,
    data->>'city' as city,
    data->>'state' as state,
    data->>'country' as country,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.shows
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    show_date = EXCLUDED.show_date,
    venue_name = EXCLUDED.venue_name,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    country = EXCLUDED.country,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  UPDATE raw_data.shows 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM silver.shows 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  INSERT INTO processing_status (table_name, layer, status, records_processed, completed_at)
  VALUES ('shows', 'silver', 'completed', processed_count, NOW());
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;
```

#### Setlists Processing
```sql
CREATE OR REPLACE FUNCTION silver.process_setlists()
RETURNS TABLE (
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER
) AS $$
DECLARE
  start_time TIMESTAMP;
  processed_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  start_time := clock_timestamp();
  
  INSERT INTO silver.setlists (
    external_id, song_name, show_date, venue_name, city, state, song_order,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'songname' as song_name,
    (data->>'showdate')::date as show_date,
    data->>'venuename' as venue_name,
    data->>'city' as city,
    data->>'state' as state,
    (data->>'song_order')::integer as song_order,
    (data->>'created_at')::timestamp with time zone as created_at,
    (data->>'updated_at')::timestamp with time zone as updated_at,
    id as source_raw_id
  FROM raw_data.setlists
  WHERE is_processed = false
  ON CONFLICT (external_id) DO UPDATE SET
    song_name = EXCLUDED.song_name,
    show_date = EXCLUDED.show_date,
    venue_name = EXCLUDED.venue_name,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    song_order = EXCLUDED.song_order,
    updated_at = EXCLUDED.updated_at,
    processed_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  
  UPDATE raw_data.setlists 
  SET is_processed = true 
  WHERE id IN (
    SELECT source_raw_id FROM silver.setlists 
    WHERE processed_at > NOW() - INTERVAL '1 minute'
  );
  
  INSERT INTO processing_status (table_name, layer, status, records_processed, completed_at)
  VALUES ('setlists', 'silver', 'completed', processed_count, NOW());
  
  RETURN QUERY SELECT 
    processed_count,
    error_count,
    EXTRACT(EPOCH FROM (clock_timestamp() - start_time) * 1000)::INTEGER;
END;
$$ LANGUAGE plpgsql;
```

## 🎛️ Orchestration System

### 1. Master Processing Function
```sql
CREATE OR REPLACE FUNCTION silver.process_all_tables()
RETURNS TABLE (
  table_name TEXT,
  processed_count INTEGER,
  error_count INTEGER,
  processing_time_ms INTEGER,
  status TEXT
) AS $$
DECLARE
  result RECORD;
  total_processed INTEGER := 0;
  total_errors INTEGER := 0;
  total_time INTEGER := 0;
BEGIN
  -- Process each table in sequence
  FOR result IN 
    SELECT * FROM silver.process_songs()
  LOOP
    total_processed := total_processed + result.processed_count;
    total_errors := total_errors + result.error_count;
    total_time := total_time + result.processing_time_ms;
    
    RETURN QUERY SELECT 'songs', result.processed_count, result.error_count, 
                        result.processing_time_ms, 'completed';
  END LOOP;
  
  FOR result IN 
    SELECT * FROM silver.process_shows()
  LOOP
    total_processed := total_processed + result.processed_count;
    total_errors := total_errors + result.error_count;
    total_time := total_time + result.processing_time_ms;
    
    RETURN QUERY SELECT 'shows', result.processed_count, result.error_count, 
                        result.processing_time_ms, 'completed';
  END LOOP;
  
  FOR result IN 
    SELECT * FROM silver.process_setlists()
  LOOP
    total_processed := total_processed + result.processed_count;
    total_errors := total_errors + result.error_count;
    total_time := total_time + result.processing_time_ms;
    
    RETURN QUERY SELECT 'setlists', result.processed_count, result.error_count, 
                        result.processing_time_ms, 'completed';
  END LOOP;
  
  -- Log overall processing status
  INSERT INTO processing_status (table_name, layer, status, records_processed, completed_at)
  VALUES ('all_tables', 'silver', 'completed', total_processed, NOW());
  
END;
$$ LANGUAGE plpgsql;
```

### 2. Edge Function for Orchestration
```typescript
// New Edge Function: process_tabular_data
export default async function handler(req: Request) {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    // Call the master processing function
    const { data, error } = await supabase.rpc('process_all_tables');
    
    if (error) throw error;
    
    return new Response(JSON.stringify({
      success: true,
      results: data,
      total_processed: data.reduce((sum, row) => sum + row.processed_count, 0),
      total_errors: data.reduce((sum, row) => sum + row.error_count, 0),
      total_time_ms: data.reduce((sum, row) => sum + row.processing_time_ms, 0)
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}
```

## 🥇 Gold Layer (Analytics & Chatbot Queries)

### 1. Analytics-Ready Tables
```sql
-- Songs with performance statistics
CREATE TABLE gold.songs_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  song_name TEXT NOT NULL,
  slug TEXT NOT NULL,
  is_original BOOLEAN NOT NULL,
  original_artist TEXT,
  total_performances INTEGER DEFAULT 0,
  first_performance_date DATE,
  last_performance_date DATE,
  performance_frequency FLOAT,
  unique_venues INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shows with song statistics
CREATE TABLE gold.shows_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  show_date DATE NOT NULL,
  venue_name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  total_songs INTEGER DEFAULT 0,
  unique_songs INTEGER DEFAULT 0,
  original_songs INTEGER DEFAULT 0,
  cover_songs INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Venues with performance statistics
CREATE TABLE gold.venues_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  total_shows INTEGER DEFAULT 0,
  first_show_date DATE,
  last_show_date DATE,
  unique_songs INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. Chatbot Query Functions
```sql
-- Get song information for chatbot
CREATE OR REPLACE FUNCTION get_song_info(song_name TEXT)
RETURNS TABLE (
  name TEXT,
  slug TEXT,
  is_original BOOLEAN,
  original_artist TEXT,
  total_performances INTEGER,
  first_performance DATE,
  last_performance DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.name,
    s.slug,
    s.is_original,
    s.original_artist,
    COUNT(sl.id)::INTEGER as total_performances,
    MIN(sl.show_date) as first_performance,
    MAX(sl.show_date) as last_performance
  FROM silver.songs s
  LEFT JOIN silver.setlists sl ON s.name = sl.song_name
  WHERE LOWER(s.name) LIKE LOWER('%' || song_name || '%')
  GROUP BY s.id, s.name, s.slug, s.is_original, s.original_artist;
END;
$$ LANGUAGE plpgsql;

-- Get show information for chatbot
CREATE OR REPLACE FUNCTION get_show_info(show_date DATE)
RETURNS TABLE (
  show_date DATE,
  venue_name TEXT,
  city TEXT,
  state TEXT,
  total_songs INTEGER,
  song_list TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.show_date,
    s.venue_name,
    s.city,
    s.state,
    COUNT(sl.id)::INTEGER as total_songs,
    ARRAY_AGG(sl.song_name ORDER BY sl.song_order) as song_list
  FROM silver.shows s
  LEFT JOIN silver.setlists sl ON s.show_date = sl.show_date AND s.venue_name = sl.venue_name
  WHERE s.show_date = show_date
  GROUP BY s.show_date, s.venue_name, s.city, s.state;
END;
$$ LANGUAGE plpgsql;

-- Get venue information for chatbot
CREATE OR REPLACE FUNCTION get_venue_info(venue_name TEXT)
RETURNS TABLE (
  venue_name TEXT,
  city TEXT,
  state TEXT,
  total_shows INTEGER,
  first_show DATE,
  last_show DATE,
  unique_songs INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.venue_name,
    v.city,
    v.state,
    COUNT(DISTINCT s.id)::INTEGER as total_shows,
    MIN(s.show_date) as first_show,
    MAX(s.show_date) as last_show,
    COUNT(DISTINCT sl.song_name)::INTEGER as unique_songs
  FROM silver.venues v
  LEFT JOIN silver.shows s ON v.venue_name = s.venue_name
  LEFT JOIN silver.setlists sl ON s.show_date = sl.show_date AND s.venue_name = sl.venue_name
  WHERE LOWER(v.venue_name) LIKE LOWER('%' || venue_name || '%')
  GROUP BY v.venue_name, v.city, v.state;
END;
$$ LANGUAGE plpgsql;
```

## 🚀 Implementation Strategy

### Phase 1: Silver Layer (Immediate)
1. **Create silver schema** and tables
2. **Build ETL functions** for each endpoint
3. **Test data processing** with existing data
4. **Deploy orchestration** Edge Function

### Phase 2: Gold Layer (Next)
1. **Create gold schema** and analytics tables
2. **Build aggregation functions** for statistics
3. **Create chatbot query functions**
4. **Test end-to-end** data flow

### Phase 3: Chatbot Integration (Future)
1. **Build chatbot** using tabular queries
2. **Implement query optimization**
3. **Add caching** for performance
4. **Monitor and optimize**

## 📊 Benefits of Tabular Approach

### 1. **Simplicity**
- **Direct SQL queries** - no vector search complexity
- **Easy debugging** - can inspect data directly
- **Familiar patterns** - standard relational database

### 2. **Performance**
- **Fast queries** with proper indexing
- **Predictable performance** - no vector similarity calculations
- **Easy optimization** - standard SQL tuning

### 3. **Maintainability**
- **Clear data structure** - each table has a purpose
- **Easy to modify** - add/remove columns as needed
- **Standard tooling** - works with any SQL client

### 4. **Scalability**
- **Horizontal scaling** - can partition tables
- **Vertical scaling** - standard database optimization
- **Easy monitoring** - standard database metrics

## 🎯 Chatbot Query Examples

```sql
-- "What songs did they play at Red Rocks on 2024-06-15?"
SELECT song_name, song_order 
FROM silver.setlists 
WHERE show_date = '2024-06-15' AND venue_name = 'Red Rocks'
ORDER BY song_order;

-- "How many times have they played 'Echo of a Rose'?"
SELECT COUNT(*) as performance_count
FROM silver.setlists 
WHERE song_name = 'Echo of a Rose';

-- "What's their most played song this year?"
SELECT song_name, COUNT(*) as play_count
FROM silver.setlists 
WHERE show_date >= '2024-01-01'
GROUP BY song_name
ORDER BY play_count DESC
LIMIT 1;

-- "What venues have they played in Colorado?"
SELECT DISTINCT venue_name, city
FROM silver.venues 
WHERE state = 'CO'
ORDER BY venue_name;
```

This tabular approach gives you a solid foundation for building a chatbot that can answer complex questions about the band's music, shows, and venues using standard SQL queries! 🎵
