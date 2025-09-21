# 🎵 Band Chatbot — Tabular Data + Edge Functions

Production-focused ingestion and ETL for ElGoose APIs using Supabase Edge Functions and Postgres. Outputs clean Bronze → Silver → (optional) Gold tables optimized for chatbot queries, analytics, and dashboards.

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
  - `functions/ingest_raw_data/` – Bronze ingestion (incremental by default)
  - `functions/process_tabular_data/` – Orchestrates Silver ETL; optional Gold
  - `migrations/` – SQL migrations for schemas, roles, policies
  - `seed.sql` – Minimal seed to satisfy local resets
  - `README.md` – Backend details
- `tests/` – Smoke tests (see `tests/README.md`)
- `scripts/` – Local data utilities and year JSON snapshots
- `archive_offset_attempts/` – Archived API pagination experiments (JSON)

## 🚀 Quick Start

1. Install
```bash
npm install
```

2. Configure environment
```bash
# Supabase (required)
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...

# Optional
OPENAI_API_KEY=...
GITHUB_TOKEN=... # for MCP GitHub server in Cursor
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

# Silver processing (Edge Function)
curl -X POST "$SUPABASE_URL/functions/v1/process_tabular_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" -d '{"mode":"silver_only"}'
```

## 🔄 How It Works

- GitHub Actions (or manual calls) trigger Edge Functions
- `ingest_raw_data` fetches recent API data into `raw_data.*` (incremental window; dedup/update by external ID)
- `process_tabular_data` transforms Bronze → Silver (via PostgREST RPC, idempotent). Gold is optional.
- Idempotent and incremental; safe to re-run

## 📚 Documentation

- Supabase backend: `supabase/README.md`
- Orchestration overview: `supabase/ORCHESTRATION_ARCHITECTURE.md`
- Silver layer summary: `supabase/PRODUCTION_SILVER_LAYER_SUMMARY.md`
- Tabular implementation summary: `supabase/TABULAR_IMPLEMENTATION_SUMMARY.md`
- Tests overview: `tests/README.md`
- Archived plans and older docs: `supabase/_archive/`

GitHub workflows overview moved to `.github/WORKFLOWS.md`.

## 🔧 GitHub MCP in Cursor (optional)

- Ensure `.cursor/mcp.json` contains a `github` server entry. Example:

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

- Roles and RLS enforced across schemas; service role required for writes
- Do not commit secrets. `.cursor/` is ignored; keep tokens in env vars
- If a token is ever committed, rotate it immediately

## 🗂️ Data Files
- Large JSON snapshots live under `scripts/json/` and `archive_offset_attempts/`
- Keep only essential examples in Git; consider Git LFS for very large data

## 📈 Status

- Silver schema: songs, venues, shows, setlists ready
- ETL functions: Bronze ingestion and Silver orchestration implemented
- Designed for fast chatbot queries with proper indexes

---

Built with Supabase Edge Functions and Postgres.
