# 🎛️ Data Pipeline Orchestration Architecture

## 🎯 Purpose

Coordinated processing from ElGoose APIs to analytics-ready tables using Supabase Edge Functions and Postgres.

## 🏗️ Architecture Overview

```
GitHub Actions / Manual → Edge Functions → Database Processing
         ↓                        ↓                 ↓
   Schedules/Triggers     ingest_raw_data     Bronze (raw_data)
                          process_tabular     Silver (silver)
                                              Gold (gold)
```

## 📅 Scheduling & Triggers

- Recommended times (UTC):
  - 02:00 — Bronze ingestion (`ingest_raw_data`)
  - 02:30 — Silver processing (`process_tabular_data` with silver_only)
  - 03:00 — Gold aggregation (`process_tabular_data` with gold_only)
- Triggers:
  - GitHub Actions cron (optional)
  - Manual `curl`/client calls (development and backfills)

## 🔄 Processing Modes (process_tabular_data)

```typescript
// bronze_only: ElGoose → raw_data.* (ingestion only)
// silver_only: raw_data.* (unprocessed) → silver.* (normalize)
// gold_only:   silver.* → gold.* (analytics)
// complete:    runs silver_only then gold_only in sequence
```

## 📚 Data Flow

### Phase 1: Bronze (Raw Ingestion)
```text
Function: ingest_raw_data
Reads: ElGoose APIs
Writes: raw_data.* (JSONB rows, is_processed=false)
```

### Phase 2: Silver (Normalization)
```text
Function: process_tabular_data (silver_only)
Reads: raw_data.* WHERE is_processed=false
Writes: silver.* (typed, indexed tables)
Post: marks corresponding raw_data rows processed
```

### Phase 3: Gold (Analytics)
```text
Function: process_tabular_data (gold_only)
Reads: silver.*
Writes: gold.* (aggregations and helpers)
```

## 🧩 Sequencing & Idempotency

- Silver ETL order: venues → shows → songs → setlists → (people, appearances, links, uploads, metadata, latest, jamcharts)
- Safe to re-run: ETL is idempotent and incremental; conflicts upsert and `is_processed` guards duplicates
- Failure isolation: errors logged; subsequent layers can still proceed if configured

## 🧪 Testing

Manual tests:
```bash
# Silver only
curl -X POST "$SUPABASE_URL/functions/v1/process_tabular_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" -d '{"mode":"silver_only"}'

# Complete pipeline
curl -X POST "$SUPABASE_URL/functions/v1/process_tabular_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" -d '{"mode":"complete"}'
```

## 🔍 Monitoring & Observability

```sql
-- Processing status
SELECT table_name, layer, status, records_processed, completed_at
FROM processing_status
ORDER BY completed_at DESC
LIMIT 100;

-- Recent Bronze inserts
SELECT COUNT(*) FROM raw_data_songs 
WHERE created_at > NOW() - INTERVAL '1 hour';

-- Typical chatbot query (example)
SELECT song_name, COUNT(*) AS play_count
FROM silver.setlists
GROUP BY song_name
ORDER BY play_count DESC
LIMIT 10;
```

## 🚢 Deployment Notes

```bash
# Deploy functions
npx supabase functions deploy ingest_raw_data
npx supabase functions deploy process_tabular_data

# Apply migrations
npx supabase db push
```

The orchestration is production-ready and designed for reliability, incremental updates, and fast chatbot queries.
