# 🎵 Band Chatbot - Tabular Data Pipeline

A production-focused data pipeline that ingests ElGoose APIs and transforms them into clean Bronze → Silver → Gold tables optimized for chatbot queries, analytics, and dashboards.

## 🎯 What This Does

This system automatically collects and processes music data so you can answer questions about:
- **Songs**: catalog, original artists
- **Shows**: dates, venues
- **Venues**: locations, stats
- **Setlists**: what was played where and when

## 🏗️ High-Level Architecture

```
ElGoose APIs → Edge Functions → Postgres (Bronze/Silver/Gold) → Chat/Analytics
     ↓              ↓                         ↓                      ↓
  Raw JSON     Orchestrated ETL         Clean & Indexed         Fast Queries
```

- **Bronze (raw_data.*)**: raw JSON from APIs
- **Silver (silver.*)**: normalized, typed tables for queries
- **Gold (gold.*)**: analytics-ready aggregates and helpers

## 📁 Project Structure

- `supabase/` – Database schemas, migrations, and Edge Functions
  - `functions/ingest_raw_data/` – Bronze ingestion
  - `functions/process_tabular_data/` – Silver/Gold processing
  - `migrations/` – SQL migrations for schemas, roles, policies
  - `README.md` – Backend details
- `tests/` – Smoke tests and utilities (see `tests/README.md`)
- `scripts/` – Local data utilities

## 🚀 Quick Start

1. Install
```bash
npm install
```

2. Configure environment
```bash
# Supabase
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
# Optional model keys if used elsewhere
OPENAI_API_KEY=...
# GitHub (for MCP GitHub server)
# Create a classic PAT with repo scope or a fine-grained PAT with needed perms
# On Windows PowerShell, set for current session:
#   $env:GITHUB_TOKEN = "<your_token>"
# Or use a .env file loaded by Cursor/your shell
GITHUB_TOKEN=...
```

3. Start local Supabase and serve functions
```bash
npx supabase start
npx supabase functions serve
```

4. Apply migrations
```bash
npx supabase db push
```

5. Run processing (local)
```bash
# Bronze ingestion (Edge Function)
curl -X POST "$SUPABASE_URL/functions/v1/ingest_raw_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" -d '{"mode":"incremental"}'

# Silver/Gold processing (Edge Function)
curl -X POST "$SUPABASE_URL/functions/v1/process_tabular_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" -d '{"mode":"complete"}'
```

## 🔄 How It Works

- GitHub Actions (or manual calls) trigger Edge Functions
- `ingest_raw_data` fetches recent API data into `raw_data.*` and sets `is_processed=false`
- `process_tabular_data` transforms Bronze → Silver and aggregates to Gold
- Idempotent and incremental; safe to re-run

## 📚 Documentation

- Supabase backend: `supabase/README.md`
- Orchestration overview: `supabase/ORCHESTRATION_ARCHITECTURE.md`
- Silver layer summary: `supabase/PRODUCTION_SILVER_LAYER_SUMMARY.md`
- Tabular implementation summary: `supabase/TABULAR_IMPLEMENTATION_SUMMARY.md`
- Tests overview: `tests/README.md`
- Archived plans and older docs: `supabase/_archive/`

## 🔧 GitHub MCP in Cursor

- Ensure `.cursor/mcp.json` contains a `github` server entry. This repo includes:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github@latest"]
    }
  }
}
```

- Set `GITHUB_TOKEN` in your environment before starting Cursor chat tools.
  - PowerShell (session only):
    - `$env:GITHUB_TOKEN = "<your_token>"`
  - Or add to `.env` loaded by your shell.

- In Cursor, the AI will now have GitHub tools available (list issues/PRs, read files, comment, etc.) when you enable tools.

## ✅ Active vs Archived

- **Active**:
  - `supabase/README.md`
  - `supabase/ORCHESTRATION_ARCHITECTURE.md`
  - `supabase/PRODUCTION_SILVER_LAYER_SUMMARY.md`
  - `supabase/TABULAR_IMPLEMENTATION_SUMMARY.md`
  - `supabase/functions/*`, `supabase/migrations/*`
  - `tests/README.md`
- **Archived**:
  - `supabase/_archive/*` (older plans and drafts)
  - `tests/_archive/*` (older test scripts)

## 🔐 Security

- Roles and RLS for Bronze/Silver/Gold
- Service role required for writes; public views for safe reads where applicable

## 📈 Status

- Silver schema: songs, venues, shows, setlists ready
- ETL functions: core functions implemented; orchestration function available
- Designed for <500ms typical chatbot queries with indexes and helpers

---

Built with Supabase Edge Functions and Postgres.
