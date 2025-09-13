# 🚀 GitHub Actions Workflows

This directory contains the automated workflows for the Bronze → Silver data pipeline.

## 📁 Active Workflows

### `orchestrated-data-pipeline.yml` (Schedule-only)
- **Covers**: Bronze (raw ingestion) → Silver (tabular ETL)
- **Schedules**: Bronze 02:00 UTC, Silver 02:30 UTC
- **Runs**: Always incremental by default for Bronze and idempotent for Silver

### `bronze-ad-hoc.yml`
- **Purpose**: Run Bronze ingestion on demand
- **Inputs**: `endpoint` (choice), `mode` (`incremental | full`)

### `silver-ad-hoc.yml`
- **Purpose**: Run Silver processing on demand
- **Inputs**: `table_name` (string, optional), `force_reprocess` (boolean)
- **What does `force_reprocess` do?**
  - Resets Bronze `raw_data.*` records' processed flags for the targeted scope (table or all tables)
  - Triggers ETL to re-read and upsert into `silver.*` even if records were previously processed
  - Use when ETL logic changed or historical corrections are needed

### `monitor-data-health.yml`
- **Purpose**: Daily post‑run health checks (data freshness, connectivity)
- **Schedule**: 03:00 UTC

## 🧩 Workflow → Edge Function mapping
- **orchestrated-data-pipeline.yml**:
  - Bronze step → calls `ingest_raw_data` (`supabase/functions/ingest_raw_data/index.ts`)
  - Silver step → calls `process_tabular_data` (`supabase/functions/process_tabular_data/index.ts`) with `{ mode: "silver_only" }`
- **bronze-ad-hoc.yml**:
  - Calls `ingest_raw_data` with payload `{ endpoint, mode }`
- **silver-ad-hoc.yml**:
  - Calls `process_tabular_data` with payload `{ table_name, force_reprocess }` or `{ mode: "silver_only", force_reprocess }`
- **monitor-data-health.yml**:
  - Does not call an Edge Function; uses `@supabase/supabase-js` to query `raw_data.*` directly via PostgREST

## 🗄️ Archived Workflows
- `.github/workflows/_archive/daily-incremental.yml`
- `.github/workflows/_archive/manual-full-update.yml`
- `.github/workflows/_archive/silver-processing.yml`

## 🔧 Required Secrets
Set these in your repository:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

Optional:
```
SUPABASE_ANON_KEY=your-anon-key
OPENAI_API_KEY=your-openai-key
```

## 🔍 Notes
- Orchestrated workflow uses the service role key and writes to `raw_data.*` and `silver.*`.
- Ad-hoc workflows are separate for clearer UX.
- Avoid hardcoding Supabase URLs in workflows; use `SUPABASE_URL`.
