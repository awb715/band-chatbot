# 🗄️ Supabase Backend

This directory contains the Supabase backend configuration for the band-chatbot tabular pipeline.

## 📁 Structure

```
supabase/
├── functions/                 # Edge Functions
│   ├── ingest_raw_data/       # Bronze ingestion (APIs → raw_data.*)
│   └── process_tabular_data/  # Orchestration (Bronze → Silver → Gold)
├── migrations/                # Database schema migrations
├── schema.sql                 # Full schema export (reference)
└── README.md
```

## 🚀 Edge Functions

### ingest_raw_data
- **Purpose**: Smart incremental ingestion from ElGoose APIs to `raw_data.*`
- **Key features**: incremental window, per-endpoint limits, deduping by external IDs, robust error handling
- **Endpoint**: `POST /functions/v1/ingest_raw_data`

Request example:
```json
{
  "endpoint": "songs",      
  "mode": "incremental"     
}
```

### process_tabular_data
- **Purpose**: Orchestrate Bronze → Silver processing and Gold aggregation
- **Modes**: `bronze_only` | `silver_only` | `gold_only` | `complete`
- **Endpoint**: `POST /functions/v1/process_tabular_data`

Request example:
```json
{
  "mode": "complete"
}
```

## 🧱 Schemas

- **Bronze (`raw_data.*`)**: JSONB rows from APIs, `is_processed` flag for ETL
- **Silver (`silver.*`)**: normalized, typed tables for chatbot queries
- **Gold (`gold.*`)**: analytics tables and helpers

See:
- `PRODUCTION_SILVER_LAYER_SUMMARY.md`
- `TABULAR_IMPLEMENTATION_SUMMARY.md`
- `ORCHESTRATION_ARCHITECTURE.md`

## 🔧 Configuration

Environment variables (Edge Functions):
```bash
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
# Optional models if needed downstream
OPENAI_API_KEY=...
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIMENSIONS=1536
```

API sources are configured via the database (e.g., `api_sources` table) to control which endpoints are active.

## 📈 Processing Limits (guidance)

| Endpoint | Incremental | Manual |
|----------|-------------:|------:|
| Setlists | 100 | 200 |
| Songs | 100 | 200 |
| Shows | 50 | 100 |
| Venues | 50 | 100 |
| Others | 20–100 | 40–200 |

Tune these based on function runtimes and quotas.

## 🧪 Local Development

```bash
# Start local stack
npx supabase start

# Serve functions locally
npx supabase functions serve

# Apply migrations
npx supabase db push
```

Test calls:
```bash
# Bronze
curl -X POST "$SUPABASE_URL/functions/v1/ingest_raw_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mode":"incremental"}'

# Silver/Gold
curl -X POST "$SUPABASE_URL/functions/v1/process_tabular_data" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"mode":"complete"}'
```

## 🔐 Security

- RLS enabled across schemas; roles restrict writes to service functions
- Public access via safe views as needed
- See migrations for roles/policies setup

## 🔍 Monitoring

```bash
# Function logs
npx supabase functions logs ingest_raw_data --since 1h
npx supabase functions logs process_tabular_data --since 1h
```

Key queries:
```sql
-- Recent Bronze inserts
SELECT COUNT(*) FROM raw_data_songs WHERE created_at > NOW() - INTERVAL '1 hour';

-- Processing progress
SELECT table_name, layer, status, records_processed, completed_at
FROM processing_status
ORDER BY completed_at DESC
LIMIT 50;
```

## 🚢 Deployment

```bash
# Deploy functions
npx supabase functions deploy ingest_raw_data
npx supabase functions deploy process_tabular_data

# Apply all migrations
npx supabase db push
```

## 🔗 Related Docs

- `PRODUCTION_SILVER_LAYER_SUMMARY.md` – status and examples
- `TABULAR_IMPLEMENTATION_SUMMARY.md` – end-to-end design
- `ORCHESTRATION_ARCHITECTURE.md` – workflow and scheduling
- `_archive/` – older planning docs (for historical reference)
