# 🚀 GitHub Actions Workflows

This directory contains the automated workflows for the Bronze → Silver → Gold data pipeline.

## 📁 Active Workflows

### `orchestrated-data-pipeline.yml` (Schedule-only)
- **Covers**: Bronze (raw ingestion) → Silver (tabular ETL) → Gold (aggregation)
- **Schedules**: Bronze 02:00 UTC, Silver 02:30 UTC, Gold 03:00 UTC
- **Runs**: Always incremental by default for Bronze and idempotent for Silver/Gold

### `bronze-ad-hoc.yml`
- **Purpose**: Run Bronze ingestion on demand
- **Inputs**: `endpoint` (choice), `mode` (`incremental | full`)

### `silver-ad-hoc.yml`
- **Purpose**: Run Silver processing on demand
- **Inputs**: `table_name` (string, optional), `force_reprocess` (boolean)

### `monitor-data-health.yml`
- **Purpose**: Daily post‑run health checks (data freshness, connectivity)
- **Schedule**: 03:00 UTC

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
