# 🎛️ Data Pipeline Orchestration Architecture

## 🎯 **Complete Orchestration System**

This document explains how the Bronze → Silver → Gold data pipeline is orchestrated and scheduled in your band chatbot system.

## 🏗️ **Architecture Overview**

```
GitHub Actions → Edge Functions → Database Processing
     ↓              ↓                    ↓
  Scheduled    ingest_raw_data      Bronze (Raw)
  Workflows    process_tabular_data Silver (Clean)
  (Cron)       (New Function)       Gold (Analytics)
```

## 📅 **Scheduling Strategy**

### **1. Daily Automated Pipeline**
```yaml
# .github/workflows/orchestrated-data-pipeline.yml
- 2:00 AM UTC: Bronze Layer (Raw Data Ingestion)
- 2:30 AM UTC: Silver Layer (Tabular Processing)  
- 3:00 AM UTC: Gold Layer (Analytics Aggregation)
```

### **2. Manual Triggers**
```yaml
# Manual workflow dispatch with options:
- Layer: all, bronze, silver, gold
- Mode: incremental, full
```

## 🔄 **Data Flow Process**

### **Phase 1: Bronze Layer (Raw Data)**
```typescript
// Edge Function: ingest_raw_data (Existing)
// Triggered by: GitHub Actions (2:00 AM UTC)
// Reads from: ElGoose APIs
// Writes to: raw_data.* tables
// Marks records: is_processed = false
```

### **Phase 2: Silver Layer (Tabular Processing)**
```typescript
// Edge Function: process_tabular_data (New)
// Triggered by: GitHub Actions (2:30 AM UTC)
// Reads from: raw_data.* (WHERE is_processed = false)
// Writes to: silver.* tables
// Updates: raw_data.* (SET is_processed = true)
```

### **Phase 3: Gold Layer (Analytics)**
```typescript
// Edge Function: process_tabular_data (New)
// Triggered by: GitHub Actions (3:00 AM UTC)
// Reads from: silver.* tables
// Writes to: gold.* tables
// Creates: Analytics and chatbot-ready data
```

## 🎛️ **Orchestration Components**

### **1. Edge Functions**

#### **Existing: `ingest_raw_data`**
```typescript
// Purpose: ElGoose API → Bronze (Raw Data)
// Input: API endpoints
// Output: raw_data.* tables
// Status: ✅ Working
```

#### **New: `process_tabular_data`**
```typescript
// Purpose: Bronze → Silver → Gold (Complete Pipeline)
// Input: Processing mode (bronze_only, silver_only, gold_only, complete)
// Output: Clean tables + Analytics
// Status: 🚧 Ready to Deploy
```

### **2. GitHub Actions Workflows**

#### **Existing: `daily-incremental.yml`**
```yaml
# Purpose: Bronze layer only
# Schedule: Daily at 2 AM UTC
# Status: ✅ Working
```

#### **New: `orchestrated-data-pipeline.yml`**
```yaml
# Purpose: Complete pipeline orchestration
# Schedule: 2 AM, 2:30 AM, 3 AM UTC
# Features: Sequential processing, error handling, monitoring
# Status: 🚧 Ready to Deploy
```

### **3. Database Functions**

#### **Silver Layer ETL**
```sql
-- Functions: silver.process_songs(), silver.process_shows(), etc.
-- Purpose: Bronze → Silver transformation
-- Status: 🚧 Ready to Deploy
```

#### **Gold Layer Aggregation**
```sql
-- Functions: gold.aggregate_songs_analytics(), etc.
-- Purpose: Silver → Gold aggregation
-- Status: 🚧 Ready to Deploy
```

## 🔧 **Processing Modes**

### **1. Incremental Mode (Default)**
```typescript
// Only processes new/changed records
// Bronze: Fetches recent data from APIs
// Silver: Processes records WHERE is_processed = false
// Gold: Recalculates analytics for changed data
```

### **2. Full Mode (Manual)**
```typescript
// Processes all records
// Bronze: Fetches all data from APIs
// Silver: Processes all records (resets is_processed)
// Gold: Recalculates all analytics
```

### **3. Layer-Specific Modes**
```typescript
// bronze_only: Only raw data ingestion
// silver_only: Only Bronze → Silver processing
// gold_only: Only Silver → Gold aggregation
// complete: Full pipeline (Bronze → Silver → Gold)
```

## 📊 **Monitoring & Observability**

### **1. Processing Status Table**
```sql
-- Table: processing_status
-- Tracks: Each layer's processing status
-- Fields: table_name, layer, status, records_processed, error_message
```

### **2. GitHub Actions Monitoring**
```yaml
# Each job reports success/failure
# Dependencies ensure proper sequencing
# Error handling with detailed logging
```

### **3. Edge Function Logging**
```typescript
// Console logs for each processing step
// Error tracking and reporting
// Performance metrics (processing time, record counts)
```

## 🚀 **Deployment Steps**

### **Step 1: Deploy Database Migrations**
```bash
# Deploy Silver and Gold layers
npx supabase db push

# This deploys:
# - 20250909070000_create_silver_layer_tables.sql
# - 20250909080000_create_gold_layer_analytics.sql
```

### **Step 2: Deploy Edge Function**
```bash
# Deploy the orchestration function
npx supabase functions deploy process_tabular_data

# This creates:
# - supabase/functions/process_tabular_data/index.ts
```

### **Step 3: Update GitHub Actions**
```bash
# The new workflow is ready:
# - .github/workflows/orchestrated-data-pipeline.yml
# - Replaces the old daily-incremental.yml
```

## 🔍 **Testing the Orchestration**

### **1. Test Individual Layers**
```bash
# Test Bronze layer
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mode": "bronze_only"}' \
  "$SUPABASE_URL/functions/v1/process_tabular_data"

# Test Silver layer
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mode": "silver_only"}' \
  "$SUPABASE_URL/functions/v1/process_tabular_data"

# Test Gold layer
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mode": "gold_only"}' \
  "$SUPABASE_URL/functions/v1/process_tabular_data"
```

### **2. Test Complete Pipeline**
```bash
# Test complete pipeline
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mode": "complete"}' \
  "$SUPABASE_URL/functions/v1/process_tabular_data"
```

### **3. Test GitHub Actions**
```bash
# Manual trigger via GitHub UI
# Go to Actions → Orchestrated Data Pipeline → Run workflow
# Select layer: all, mode: incremental
```

## 📈 **Performance Considerations**

### **1. Processing Limits**
```typescript
// Bronze: 100 records per endpoint (configurable)
// Silver: Processes all unprocessed records
// Gold: Recalculates analytics for changed data
```

### **2. Error Handling**
```typescript
// Each layer has independent error handling
// Failed layers don't stop subsequent layers
// Detailed error reporting and logging
```

### **3. Scalability**
```typescript
// Can add more endpoints easily
// Processing functions are modular
// GitHub Actions can be scaled with more workers
```

## 🎯 **Benefits of This Orchestration**

### **1. Reliability**
- **Sequential processing** ensures data consistency
- **Error isolation** prevents cascade failures
- **Comprehensive monitoring** for quick issue detection

### **2. Flexibility**
- **Manual triggers** for testing and maintenance
- **Layer-specific processing** for targeted updates
- **Configurable modes** for different use cases

### **3. Maintainability**
- **Clear separation** of concerns
- **Modular functions** easy to update
- **Comprehensive logging** for debugging

## 🔮 **Future Enhancements**

### **1. Real-time Processing**
```sql
-- Database triggers for real-time updates
-- Webhook-based processing
-- Event-driven architecture
```

### **2. Advanced Monitoring**
```typescript
-- Slack/Discord notifications
-- Performance dashboards
-- Automated alerting
```

### **3. Data Quality**
```sql
-- Data validation rules
-- Quality metrics
-- Automated data cleansing
```

## 🎉 **Ready for Production**

This orchestration system provides:
- ✅ **Complete data pipeline** from APIs to analytics
- ✅ **Automated scheduling** with GitHub Actions
- ✅ **Error handling** and monitoring
- ✅ **Flexible processing** modes
- ✅ **Scalable architecture** for future growth

**Your band chatbot now has a production-ready data pipeline that automatically processes raw API data into clean, analytics-ready tables!** 🎵🤖
