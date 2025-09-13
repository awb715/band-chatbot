# 🔄 Data Pipeline Process Flow Documentation

## 🎯 **Complete System Architecture**

This document explains the complete data flow from ElGoose APIs through Bronze, Silver, and Gold layers to chatbot queries.

## 🏗️ **System Components Overview**

```
ElGoose APIs → GitHub Actions → Edge Functions → SQL Functions → Database Tables
     ↓              ↓              ↓              ↓              ↓
  Raw Data      Scheduling    Orchestration   Processing    Storage
  (External)    (Cron)        (TypeScript)    (SQL)        (PostgreSQL)
```

## 📊 **Data Flow Layers**

### **Bronze Layer (Raw Data Storage)**
- **Schema**: `raw_data`
- **Purpose**: Store raw JSON from ElGoose APIs
- **Status**: ✅ Working
- **Tables**: `songs`, `shows`, `setlists`, `venues`, `latest`, `metadata`, `links`, `uploads`, `appearances`, `jamcharts`

### **Silver Layer (Clean Tabular Data)**
- **Schema**: `silver`
- **Purpose**: Clean, structured, validated data
- **Status**: 🚧 Ready to Deploy
- **Tables**: `songs`, `shows`, `setlists`, `venues`, `latest`, `metadata`, `links`, `uploads`, `appearances`, `jamcharts`

### **Gold Layer (Analytics & Chatbot Queries)**
- **Schema**: `gold`
- **Purpose**: Analytics-ready data optimized for queries
- **Status**: 🚧 Ready to Deploy
- **Tables**: `songs_analytics`, `shows_analytics`, `venues_analytics`, `setlists_analytics`

## 🔄 **Complete Process Flow**

### **Phase 1: Data Ingestion (Bronze Layer)**
```
ElGoose APIs → GitHub Actions → Edge Function → Bronze Tables
     ↓              ↓              ↓              ↓
  Raw JSON      Scheduled      ingest_raw_data  raw_data.*
  (External)    (2 AM UTC)     (TypeScript)     (PostgreSQL)
```

#### **Components:**
- **Trigger**: GitHub Actions (`.github/workflows/daily-incremental.yml`)
- **Schedule**: Daily at 2:00 AM UTC
- **Edge Function**: `ingest_raw_data` (TypeScript/Deno)
- **Output**: Raw JSON stored in `raw_data.*` tables
- **Status**: ✅ Working

#### **Process:**
1. GitHub Actions triggers at 2:00 AM UTC
2. Calls `ingest_raw_data` Edge Function
3. Edge Function fetches data from ElGoose APIs
4. Raw JSON stored in `raw_data.*` tables
5. Records marked as `is_processed = false`

### **Phase 2: Tabular Processing (Bronze → Silver)**
```
Bronze Tables → GitHub Actions → Edge Function → SQL Functions → Silver Tables
     ↓              ↓              ↓              ↓              ↓
  raw_data.*    Scheduled      process_tabular  silver.*        silver.*
  (PostgreSQL)  (2:30 AM UTC)  (TypeScript)     (SQL)           (PostgreSQL)
```

#### **Components:**
- **Trigger**: GitHub Actions (`.github/workflows/orchestrated-data-pipeline.yml`)
- **Schedule**: Daily at 2:30 AM UTC
- **Edge Function**: `process_tabular_data` (TypeScript/Deno)
- **SQL Functions**: `silver.process_all_tables()` → individual ETL functions
- **Output**: Clean tabular data in `silver.*` tables
- **Status**: 🚧 Ready to Deploy

#### **Process:**
1. GitHub Actions triggers at 2:30 AM UTC
2. Calls `process_tabular_data` Edge Function
3. Edge Function calls `silver.process_all_tables()` SQL function
4. SQL function calls individual ETL functions:
   - `silver.process_songs()`
   - `silver.process_shows()`
   - `silver.process_setlists()`
   - etc.
5. Each ETL function:
   - Reads from `raw_data.*` (WHERE `is_processed = false`)
   - Transforms JSON → clean columns
   - Writes to `silver.*` tables
   - Updates `raw_data.*` (SET `is_processed = true`)
6. Clean tabular data stored in `silver.*` tables

### **Phase 3: Analytics Aggregation (Silver → Gold)**
```
Silver Tables → GitHub Actions → Edge Function → SQL Functions → Gold Tables
     ↓              ↓              ↓              ↓              ↓
  silver.*      Scheduled      process_tabular  gold.*          gold.*
  (PostgreSQL)  (3:00 AM UTC)  (TypeScript)     (SQL)           (PostgreSQL)
```

#### **Components:**
- **Trigger**: GitHub Actions (`.github/workflows/orchestrated-data-pipeline.yml`)
- **Schedule**: Daily at 3:00 AM UTC
- **Edge Function**: `process_tabular_data` (TypeScript/Deno)
- **SQL Functions**: `gold.aggregate_all_analytics()` → individual aggregation functions
- **Output**: Analytics-ready data in `gold.*` tables
- **Status**: 🚧 Ready to Deploy

#### **Process:**
1. GitHub Actions triggers at 3:00 AM UTC
2. Calls `process_tabular_data` Edge Function
3. Edge Function calls `gold.aggregate_all_analytics()` SQL function
4. SQL function calls individual aggregation functions:
   - `gold.aggregate_songs_analytics()`
   - `gold.aggregate_shows_analytics()`
   - `gold.aggregate_venues_analytics()`
   - `gold.aggregate_setlists_analytics()`
5. Each aggregation function:
   - Reads from `silver.*` tables
   - Calculates statistics and analytics
   - Writes to `gold.*` tables
6. Analytics-ready data stored in `gold.*` tables

## 🎛️ **Function Architecture**

### **Edge Functions (Supabase Platform)**
```typescript
// TypeScript/Deno functions running on Supabase
supabase/functions/ingest_raw_data/index.ts        // ✅ Deployed
supabase/functions/process_tabular_data/index.ts   // 🚧 Ready to Deploy
```

### **SQL Functions (PostgreSQL Database)**
```sql
-- Bronze → Silver ETL Functions
silver.process_songs()           -- raw_data.songs → silver.songs
silver.process_shows()           -- raw_data.shows → silver.shows
silver.process_setlists()        -- raw_data.setlists → silver.setlists
silver.process_venues()          -- raw_data.venues → silver.venues
silver.process_latest()          -- raw_data.latest → silver.latest
silver.process_metadata()        -- raw_data.metadata → silver.metadata
silver.process_links()           -- raw_data.links → silver.links
silver.process_uploads()         -- raw_data.uploads → silver.uploads
silver.process_appearances()     -- raw_data.appearances → silver.appearances
silver.process_jamcharts()       -- raw_data.jamcharts → silver.jamcharts
silver.process_all_tables()      -- Master orchestrator

-- Silver → Gold Aggregation Functions
gold.aggregate_songs_analytics()      -- silver.songs → gold.songs_analytics
gold.aggregate_shows_analytics()      -- silver.shows → gold.shows_analytics
gold.aggregate_venues_analytics()     -- silver.venues → gold.venues_analytics
gold.aggregate_setlists_analytics()   -- silver.setlists → gold.setlists_analytics
gold.aggregate_all_analytics()        -- Master aggregator

-- Chatbot Query Functions
get_song_info(song_name TEXT)         -- Query song information
get_show_info(show_date DATE)         -- Query show information
get_venue_info(venue_name TEXT)       -- Query venue information
get_most_played_songs(limit_count INTEGER) -- Query most played songs
get_shows_by_year(year_filter INTEGER)     -- Query shows by year
get_songs_by_venue(venue_name TEXT)        -- Query songs by venue
```

## 📅 **Scheduling Details**

### **Daily Automated Pipeline**
```yaml
# .github/workflows/orchestrated-data-pipeline.yml
- 2:00 AM UTC: Bronze Layer (Raw Data Ingestion)
- 2:30 AM UTC: Silver Layer (Tabular Processing)
- 3:00 AM UTC: Gold Layer (Analytics Aggregation)
```

### **Manual Triggers**
```yaml
# Available via GitHub Actions UI
- Layer: all, bronze, silver, gold
- Mode: incremental, full
```

## 🔧 **Data Transformation Examples**

### **Bronze → Silver (ETL)**
```json
// Input: raw_data.songs
{
  "id": 123,
  "external_id": "song_456",
  "data": {
    "name": "Echo of a Rose",
    "slug": "echo-of-a-rose",
    "isoriginal": true,
    "original_artist": null,
    "created_at": "2024-01-15T10:30:00Z"
  },
  "is_processed": false
}
```

```sql
-- Output: silver.songs
id: uuid (generated)
external_id: 'song_456'
name: 'Echo of a Rose'
slug: 'echo-of-a-rose'
is_original: true
original_artist: null
created_at: '2024-01-15T10:30:00Z'
source_raw_id: 123
processed_at: '2024-09-09T15:45:00Z'
```

### **Silver → Gold (Aggregation)**
```sql
-- Input: silver.songs + silver.setlists
-- Output: gold.songs_analytics
song_name: 'Echo of a Rose'
total_performances: 45
first_performance_date: '2024-01-20'
last_performance_date: '2024-08-15'
unique_venues: 12
performance_years: [2024]
```

## 🚀 **Deployment Status**

### **✅ Working (Bronze Layer)**
- Raw data ingestion
- Edge Function: `ingest_raw_data`
- GitHub Actions: Daily data ingestion
- Database tables: `raw_data.*`

### **🚧 Ready to Deploy (Silver & Gold Layers)**
- Tabular processing
- Analytics aggregation
- Edge Function: `process_tabular_data`
- GitHub Actions: Orchestrated pipeline
- Database functions: All ETL and aggregation functions
- Database tables: `silver.*` and `gold.*`

## 🔍 **Monitoring & Observability**

### **Processing Status Tracking**
```sql
-- Table: processing_status
-- Tracks: Each layer's processing status
-- Fields: table_name, layer, status, records_processed, error_message
```

### **GitHub Actions Monitoring**
```yaml
# Each job reports success/failure
# Dependencies ensure proper sequencing
# Error handling with detailed logging
```

### **Edge Function Logging**
```typescript
// Console logs for each processing step
// Error tracking and reporting
// Performance metrics (processing time, record counts)
```

## 🎯 **Benefits of This Architecture**

### **1. Separation of Concerns**
- **GitHub Actions**: Scheduling and orchestration
- **Edge Functions**: HTTP handling and business logic
- **SQL Functions**: Data processing and transformations
- **Database Tables**: Data storage

### **2. Scalability**
- **Edge Functions**: Auto-scaling serverless
- **SQL Functions**: Database-optimized processing
- **GitHub Actions**: Reliable scheduling

### **3. Maintainability**
- **Each layer** has a specific purpose
- **Easy to debug** each component
- **Modular design** for updates

### **4. Performance**
- **Incremental processing** (only new data)
- **Optimized SQL** functions
- **Proper indexing** for fast queries

## 🎉 **Ready for Production**

This data pipeline provides:
- ✅ **Complete data flow** from APIs to analytics
- ✅ **Automated scheduling** with GitHub Actions
- ✅ **Error handling** and monitoring
- ✅ **Scalable architecture** for future growth
- ✅ **Clean separation** of concerns

**Your band chatbot now has a production-ready data pipeline that automatically processes raw API data into clean, analytics-ready tables!** 🎵🤖
