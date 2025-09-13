# 📊 Data Pipeline Visual Diagram

## 🔄 **Complete System Flow**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ElGoose APIs  │    │  GitHub Actions │    │ Edge Functions  │    │  SQL Functions  │
│                 │    │                 │    │                 │    │                 │
│  Raw JSON Data  │───▶│   Scheduling    │───▶│  Orchestration  │───▶│   Processing    │
│                 │    │   (Cron Jobs)   │    │  (TypeScript)   │    │    (PostgreSQL) │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         ▼                       ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Bronze Layer  │    │   Silver Layer  │    │    Gold Layer   │    │  Chatbot Queries│
│                 │    │                 │    │                 │    │                 │
│  raw_data.*     │───▶│   silver.*      │───▶│    gold.*       │───▶│  Query Functions│
│  (Raw JSON)     │    │  (Clean Tables) │    │  (Analytics)    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📅 **Daily Schedule Timeline**

```
12:00 AM UTC   2:00 AM UTC   2:30 AM UTC   3:00 AM UTC   4:00 AM UTC
     │             │             │             │             │
     │             ▼             ▼             ▼             │
     │        ┌─────────┐   ┌─────────┐   ┌─────────┐        │
     │        │ Bronze  │   │ Silver  │   │  Gold   │        │
     │        │ Layer   │   │ Layer   │   │ Layer   │        │
     │        │         │   │         │   │         │        │
     │        │ Raw     │   │ Clean   │   │Analytics│        │
     │        │ Data    │   │ Tables  │   │ Tables  │        │
     │        └─────────┘   └─────────┘   └─────────┘        │
     │             │             │             │             │
     └─────────────┼─────────────┼─────────────┼─────────────┘
                   │             │             │
                   ▼             ▼             ▼
            ingest_raw_data  process_tabular  process_tabular
            (Edge Function)  (Edge Function)  (Edge Function)
```

## 🏗️ **Layer Architecture**

### **Bronze Layer (Raw Data)**
```
┌─────────────────────────────────────────────────────────────┐
│                    Bronze Layer (raw_data)                  │
├─────────────────────────────────────────────────────────────┤
│  raw_data.songs        │  Raw JSON from ElGoose API        │
│  raw_data.shows        │  Raw JSON from ElGoose API        │
│  raw_data.setlists     │  Raw JSON from ElGoose API        │
│  raw_data.venues       │  Raw JSON from ElGoose API        │
│  raw_data.latest       │  Raw JSON from ElGoose API        │
│  raw_data.metadata     │  Raw JSON from ElGoose API        │
│  raw_data.links        │  Raw JSON from ElGoose API        │
│  raw_data.uploads      │  Raw JSON from ElGoose API        │
│  raw_data.appearances  │  Raw JSON from ElGoose API        │
│  raw_data.jamcharts    │  Raw JSON from ElGoose API        │
└─────────────────────────────────────────────────────────────┘
```

### **Silver Layer (Clean Tables)**
```
┌─────────────────────────────────────────────────────────────┐
│                    Silver Layer (silver)                    │
├─────────────────────────────────────────────────────────────┤
│  silver.songs        │  Clean, structured song data        │
│  silver.shows        │  Clean, structured show data        │
│  silver.setlists     │  Clean, structured setlist data     │
│  silver.venues       │  Clean, structured venue data       │
│  silver.latest       │  Clean, structured latest data      │
│  silver.metadata     │  Clean, structured metadata         │
│  silver.links        │  Clean, structured links data       │
│  silver.uploads      │  Clean, structured uploads data     │
│  silver.appearances  │  Clean, structured appearances data │
│  silver.jamcharts    │  Clean, structured jamcharts data   │
└─────────────────────────────────────────────────────────────┘
```

### **Gold Layer (Analytics)**
```
┌─────────────────────────────────────────────────────────────┐
│                     Gold Layer (gold)                       │
├─────────────────────────────────────────────────────────────┤
│  gold.songs_analytics      │  Song performance statistics  │
│  gold.shows_analytics      │  Show performance statistics  │
│  gold.venues_analytics     │  Venue performance statistics │
│  gold.setlists_analytics   │  Setlist performance stats    │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Function Call Chain**

```
GitHub Actions
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                Edge Functions (Supabase)                    │
├─────────────────────────────────────────────────────────────┤
│  ingest_raw_data      │  ElGoose APIs → Bronze             │
│  process_tabular_data │  Bronze → Silver → Gold            │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│              SQL Functions (PostgreSQL)                     │
├─────────────────────────────────────────────────────────────┤
│  silver.process_all_tables()    │  Master ETL orchestrator │
│  silver.process_songs()         │  Songs ETL               │
│  silver.process_shows()         │  Shows ETL               │
│  silver.process_setlists()      │  Setlists ETL            │
│  gold.aggregate_all_analytics() │  Master aggregator       │
│  gold.aggregate_songs_analytics() │ Songs aggregation      │
│  get_song_info()                │  Chatbot queries         │
│  get_show_info()                │  Chatbot queries         │
│  get_venue_info()               │  Chatbot queries         │
└─────────────────────────────────────────────────────────────┘
```

## 📊 **Data Transformation Flow**

### **Bronze → Silver (ETL)**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Raw JSON      │    │   ETL Function  │    │  Clean Table    │
│                 │    │                 │    │                 │
│ {               │───▶│ silver.process_ │───▶│ id: uuid        │
│   "name": "...",│    │ songs()         │    │ external_id:    │
│   "slug": "...",│    │                 │    │ name: "..."     │
│   "isoriginal": │    │ - Extract JSON  │    │ slug: "..."     │
│   true          │    │ - Validate data │    │ is_original:    │
│ }               │    │ - Clean columns │    │ true            │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Silver → Gold (Aggregation)**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Clean Tables   │    │ Aggregation     │    │ Analytics Table │
│                 │    │ Function        │    │                 │
│ silver.songs    │───▶│ gold.aggregate_ │───▶│ song_name:      │
│ silver.setlists │    │ songs_analytics │    │ total_performances: 45 │
│                 │    │                 │    │ first_performance:     │
│                 │    │ - Count plays   │    │ last_performance:      │
│                 │    │ - Calculate stats│   │ unique_venues: 12      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🎯 **Key Benefits**

### **1. Separation of Concerns**
- **GitHub Actions**: Scheduling
- **Edge Functions**: Orchestration
- **SQL Functions**: Processing
- **Database Tables**: Storage

### **2. Scalability**
- **Auto-scaling** serverless functions
- **Database-optimized** processing
- **Reliable** scheduling

### **3. Maintainability**
- **Modular** design
- **Easy debugging**
- **Clear responsibilities**

### **4. Performance**
- **Incremental** processing
- **Optimized** SQL
- **Fast** queries

## 🚀 **Deployment Status**

### **✅ Working**
- Bronze layer (raw data)
- Edge Function: `ingest_raw_data`
- GitHub Actions: Daily ingestion

### **🚧 Ready to Deploy**
- Silver layer (clean tables)
- Gold layer (analytics)
- Edge Function: `process_tabular_data`
- GitHub Actions: Orchestrated pipeline
- All SQL functions

**This architecture provides a complete, production-ready data pipeline for your band chatbot!** 🎵🤖
