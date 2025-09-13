# 🏗️ Data Architecture Assessment & Bronze/Silver/Gold Design

## 📊 Current State Analysis

### Current Database Structure
- **Raw Data Layer**: `raw_data` schema with 10 tables (Bronze equivalent)
- **Vector Store**: `documents` table with embeddings (Gold equivalent)
- **API Management**: `api_sources` table for endpoint configuration

### Current User Roles & Permissions
| Role | Permissions | Current Access |
|------|-------------|----------------|
| **anon** | Full access to all tables | ⚠️ Too permissive |
| **authenticated** | Full access to all tables | ⚠️ Too permissive |
| **service_role** | Full database access | ✅ Appropriate |

### Current RLS Policies
- **Status**: Overly permissive (`USING (true)`)
- **Risk**: Any user can read/write all data
- **Impact**: Security vulnerability for production

## 🎯 Bronze/Silver/Gold Architecture Design

### 🥉 Bronze Layer (Raw Data)
**Current State**: ✅ Implemented
- **Purpose**: Store raw, unprocessed data from APIs
- **Schema**: `raw_data.*` tables
- **Data Quality**: Raw JSON, minimal validation
- **Retention**: Long-term storage

### 🥈 Silver Layer (Cleaned & Structured)
**Current State**: ❌ Missing
- **Purpose**: Cleaned, validated, structured data
- **Schema**: `silver.*` tables
- **Data Quality**: Validated, normalized, business-ready
- **Processing**: ETL from Bronze to Silver

### 🥇 Gold Layer (Analytics & ML Ready)
**Current State**: ⚠️ Partial (documents table only)
- **Purpose**: Analytics, ML, and RAG-ready data
- **Schema**: `gold.*` tables + `documents` table
- **Data Quality**: Optimized for queries and embeddings
- **Processing**: Aggregated, enriched, vectorized

## 🔐 Recommended User Roles & Permissions

### 1. Data Ingestion Role (`data_ingestion`)
```sql
-- Create role for automated data ingestion
CREATE ROLE data_ingestion;

-- Grant permissions for Bronze layer writes
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA raw_data TO data_ingestion;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA raw_data TO data_ingestion;

-- Grant permissions for Silver layer writes
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA silver TO data_ingestion;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA silver TO data_ingestion;

-- Grant permissions for Gold layer writes
GRANT INSERT, UPDATE ON ALL TABLES IN SCHEMA gold TO data_ingestion;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA gold TO data_ingestion;
GRANT INSERT, UPDATE ON documents TO data_ingestion;
```

### 2. Data Processing Role (`data_processor`)
```sql
-- Create role for ETL processes
CREATE ROLE data_processor;

-- Grant read access to Bronze layer
GRANT SELECT ON ALL TABLES IN SCHEMA raw_data TO data_processor;

-- Grant write access to Silver and Gold layers
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA silver TO data_processor;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gold TO data_processor;
GRANT INSERT, UPDATE, DELETE ON documents TO data_processor;
```

### 3. Chatbot Role (`chatbot_user`)
```sql
-- Create role for chatbot application
CREATE ROLE chatbot_user;

-- Grant read access to Gold layer only
GRANT SELECT ON ALL TABLES IN SCHEMA gold TO chatbot_user;
GRANT SELECT ON documents TO chatbot_user;
GRANT EXECUTE ON FUNCTION match_documents TO chatbot_user;
```

### 4. Analytics Role (`analytics_user`)
```sql
-- Create role for analytics and reporting
CREATE ROLE analytics_user;

-- Grant read access to Silver and Gold layers
GRANT SELECT ON ALL TABLES IN SCHEMA silver TO analytics_user;
GRANT SELECT ON ALL TABLES IN SCHEMA gold TO analytics_user;
GRANT SELECT ON documents TO analytics_user;
```

## 🏗️ Recommended Schema Structure

### Bronze Layer (Raw Data) - Current
```sql
-- Keep existing raw_data schema
raw_data.setlists
raw_data.songs
raw_data.shows
raw_data.venues
-- ... other tables
```

### Silver Layer (Cleaned Data) - New
```sql
-- Create silver schema
CREATE SCHEMA silver;

-- Cleaned songs table
CREATE TABLE silver.songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  is_original BOOLEAN NOT NULL,
  original_artist TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  source_raw_id INTEGER REFERENCES raw_data.songs(id),
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cleaned shows table
CREATE TABLE silver.shows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL,
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

-- Cleaned setlists table
CREATE TABLE silver.setlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT NOT NULL,
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
```

### Gold Layer (Analytics & ML Ready) - Enhanced
```sql
-- Create gold schema
CREATE SCHEMA gold;

-- Analytics-ready songs table
CREATE TABLE gold.songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  is_original BOOLEAN NOT NULL,
  original_artist TEXT,
  total_performances INTEGER DEFAULT 0,
  first_performance_date DATE,
  last_performance_date DATE,
  performance_frequency FLOAT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Analytics-ready shows table
CREATE TABLE gold.shows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  show_date DATE NOT NULL,
  venue_name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  country TEXT,
  total_songs INTEGER DEFAULT 0,
  unique_songs INTEGER DEFAULT 0,
  show_duration_minutes INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enhanced documents table for RAG
CREATE TABLE gold.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding VECTOR(1536),
  metadata JSONB DEFAULT '{}',
  content_type TEXT NOT NULL, -- 'song', 'show', 'setlist', 'venue'
  content_id UUID NOT NULL,
  content_hash TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 🔄 ETL Pipeline Design

### Bronze → Silver ETL
```sql
-- Example: Process songs from raw to silver
CREATE OR REPLACE FUNCTION silver.process_songs()
RETURNS INTEGER AS $$
DECLARE
  processed_count INTEGER := 0;
BEGIN
  INSERT INTO silver.songs (
    external_id, name, slug, is_original, original_artist,
    created_at, updated_at, source_raw_id
  )
  SELECT 
    external_id,
    data->>'name' as name,
    data->>'slug' as slug,
    (data->>'isoriginal')::boolean as is_original,
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
  
  RETURN processed_count;
END;
$$ LANGUAGE plpgsql;
```

### Silver → Gold ETL
```sql
-- Example: Aggregate songs for analytics
CREATE OR REPLACE FUNCTION gold.aggregate_songs()
RETURNS INTEGER AS $$
DECLARE
  processed_count INTEGER := 0;
BEGIN
  INSERT INTO gold.songs (
    name, slug, is_original, original_artist,
    total_performances, first_performance_date, last_performance_date
  )
  SELECT 
    s.name,
    s.slug,
    s.is_original,
    s.original_artist,
    COUNT(sl.id) as total_performances,
    MIN(sl.show_date) as first_performance_date,
    MAX(sl.show_date) as last_performance_date
  FROM silver.songs s
  LEFT JOIN silver.setlists sl ON s.external_id = sl.song_name
  GROUP BY s.id, s.name, s.slug, s.is_original, s.original_artist
  ON CONFLICT (slug) DO UPDATE SET
    total_performances = EXCLUDED.total_performances,
    first_performance_date = EXCLUDED.first_performance_date,
    last_performance_date = EXCLUDED.last_performance_date,
    updated_at = NOW();
  
  GET DIAGNOSTICS processed_count = ROW_COUNT;
  RETURN processed_count;
END;
$$ LANGUAGE plpgsql;
```

## 🔐 Security Recommendations

### 1. Implement Proper RLS Policies
```sql
-- Bronze layer: Only data ingestion role can write
CREATE POLICY "data_ingestion_write" ON raw_data.songs 
  FOR INSERT TO data_ingestion USING (true);

CREATE POLICY "data_ingestion_update" ON raw_data.songs 
  FOR UPDATE TO data_ingestion USING (true);

-- Silver layer: Data processor can write, analytics can read
CREATE POLICY "data_processor_write" ON silver.songs 
  FOR ALL TO data_processor USING (true);

CREATE POLICY "analytics_read" ON silver.songs 
  FOR SELECT TO analytics_user USING (true);

-- Gold layer: Chatbot can read, data processor can write
CREATE POLICY "chatbot_read" ON gold.songs 
  FOR SELECT TO chatbot_user USING (true);

CREATE POLICY "data_processor_write" ON gold.songs 
  FOR ALL TO data_processor USING (true);
```

### 2. Remove Overly Permissive Policies
```sql
-- Drop current overly permissive policies
DROP POLICY IF EXISTS "Allow all operations on raw_data tables" ON raw_data.songs;
DROP POLICY IF EXISTS "Allow all operations on raw_data tables" ON raw_data.shows;
-- ... repeat for all tables

-- Implement proper role-based policies
-- (See above examples)
```

## 📈 Scalability Considerations

### 1. Partitioning Strategy
```sql
-- Partition setlists by year for better performance
CREATE TABLE silver.setlists_2024 PARTITION OF silver.setlists
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE silver.setlists_2025 PARTITION OF silver.setlists
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

### 2. Indexing Strategy
```sql
-- Bronze layer indexes
CREATE INDEX idx_raw_data_songs_external_id ON raw_data.songs(external_id);
CREATE INDEX idx_raw_data_songs_processed ON raw_data.songs(is_processed);

-- Silver layer indexes
CREATE INDEX idx_silver_songs_name ON silver.songs(name);
CREATE INDEX idx_silver_songs_slug ON silver.songs(slug);
CREATE INDEX idx_silver_setlists_show_date ON silver.setlists(show_date);

-- Gold layer indexes
CREATE INDEX idx_gold_songs_performance_count ON gold.songs(total_performances);
CREATE INDEX idx_gold_documents_content_type ON gold.documents(content_type);
```

## 🚀 Implementation Plan

### Phase 1: Security Hardening
1. Create new user roles
2. Implement proper RLS policies
3. Remove overly permissive access
4. Test with existing Edge Functions

### Phase 2: Silver Layer
1. Create silver schema and tables
2. Build Bronze → Silver ETL functions
3. Test data processing pipeline
4. Update Edge Functions to use new roles

### Phase 3: Gold Layer Enhancement
1. Create gold schema and tables
2. Build Silver → Gold ETL functions
3. Enhance documents table for RAG
4. Implement analytics aggregations

### Phase 4: Chatbot Integration
1. Update chatbot to use gold layer
2. Implement proper authentication
3. Add monitoring and alerting
4. Performance optimization

## 🎯 Benefits of This Architecture

1. **Security**: Role-based access control
2. **Scalability**: Proper data layering
3. **Performance**: Optimized for different use cases
4. **Maintainability**: Clear separation of concerns
5. **Flexibility**: Easy to add new data sources
6. **Compliance**: Audit trail and data lineage
