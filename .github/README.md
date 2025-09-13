# 🚀 GitHub Actions Workflows

This directory contains the automated workflows for the Bronze → Silver → Gold data pipeline.

## 📁 Active Workflows

### `orchestrated-data-pipeline.yml` (Primary)
- **Covers**: Bronze (raw ingestion) → Silver (tabular ETL) → Gold (aggregation)
- **Schedules**: Bronze 02:00 UTC, Silver 02:30 UTC, Gold 03:00 UTC
- **Ad‑hoc inputs (Run workflow)**:
  - **layer**: `all | bronze | silver | gold`
  - **mode**: `incremental | full | songs_only`
  - **endpoint** (Bronze, optional): `all | setlists | songs | shows | venues | latest | metadata | links | uploads | appearances | jamcharts`
  - **table_name** (Silver, optional): free-text (e.g., `songs`, `setlists`)
  - **force_reprocess** (Silver): `true | false`

#### Examples
- Bronze only, incremental all endpoints: `layer=bronze, mode=incremental`
- Bronze only, full setlists: `layer=bronze, mode=full, endpoint=setlists`
- Silver only, process one table: `layer=silver, table_name=songs`
- Silver only, force reprocess all: `layer=silver, force_reprocess=true`
- End‑to‑end: `layer=all, mode=incremental`

### `monitor-data-health.yml`
- **Purpose**: Daily post‑run health checks (data freshness, connectivity)
- **Schedule**: 03:00 UTC

## 🗄️ Archived Workflows
These are retained for reference and are no longer scheduled:
- `.github/workflows/_archive/daily-incremental.yml`
- `.github/workflows/_archive/manual-full-update.yml`
- `.github/workflows/_archive/silver-processing.yml`

## 🔧 Required Secrets
Set these in your repository:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

Optional (only if needed by other tooling):

```
SUPABASE_ANON_KEY=your-anon-key
OPENAI_API_KEY=your-openai-key
```

Notes:
- The orchestrated workflow calls Edge Functions with the **service role key** to ensure writes go to `raw_data.*` and `silver.*` schemas with correct permissions.
- Avoid hardcoding Supabase URLs or using the anon key for server‑side writes.

## 🔍 Quick Troubleshooting
- Check the Actions logs for each job (Bronze/Silver/Gold) within the run.
- For schema issues, verify Supabase exposed schemas include `raw_data` and `silver`.
- If Silver fails, confirm public RPC wrappers (if used) or call schema‑qualified functions directly.

## 📈 Scaling Tips
- Add new endpoints by updating the `api_sources` table and ETL functions.
- Use the ad‑hoc inputs to validate one endpoint/table before widening scope.
- Consider adding per‑endpoint matrix inside the Bronze job if needed for parallelism.
