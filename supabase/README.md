# 🗄️ Supabase Backend

This directory contains the Supabase backend configuration for the band-chatbot RAG system.

## 📁 Structure

```
supabase/
├── functions/           # Edge Functions
│   └── ingest_raw_data/ # Main data ingestion function
├── migrations/          # Database schema migrations
└── README.md           # This file
```

## 🚀 Edge Functions

### `ingest_raw_data`
**Purpose**: Smart incremental data updater for ElGoose API endpoints

#### Features
- **Incremental Updates**: Only processes recent data (7-day window)
- **Performance Limits**: Endpoint-specific row limits to prevent timeouts
- **Processing Modes**: Incremental vs Manual processing
- **Error Handling**: Robust API error handling and fallbacks
- **Deduplication**: Uses external IDs to prevent duplicates

#### API Endpoints
- **URL**: `https://your-project.supabase.co/functions/v1/ingest_raw_data`
- **Method**: POST
- **Authentication**: Bearer token (Supabase anon key)

#### Request Body
```json
{
  "endpoint": "songs",           // Optional: specific endpoint
  "mode": "incremental"          // "incremental" or "manual"
}
```

#### Response
```json
{
  "success": true,
  "total_new_records": 5,
  "total_updated_records": 10,
  "results": [
    {
      "endpoint": "Songs",
      "total_fetched": 100,
      "new_records": 5,
      "updated_records": 10,
      "errors": [],
      "processing_time_ms": 1234
    }
  ]
}
```

## 🗃️ Database Schema

### Raw Data Tables
All ElGoose API data is stored in `raw_data` schema with these tables:

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `raw_data_songs` | Song catalog | `id`, `name`, `slug`, `isoriginal` |
| `raw_data_shows` | Concert shows | `id`, `showdate`, `venuename`, `city` |
| `raw_data_venues` | Venue information | `id`, `name`, `city`, `state` |
| `raw_data_setlists` | Song performances | `id`, `songname`, `showdate`, `venuename` |
| `raw_data_latest` | Latest updates | `id`, `type`, `data` |
| `raw_data_metadata` | System metadata | `id`, `key`, `value` |
| `raw_data_links` | Related links | `id`, `url`, `title`, `type` |
| `raw_data_uploads` | File uploads | `id`, `filename`, `type`, `url` |
| `raw_data_appearances` | Artist appearances | `id`, `artist`, `showdate`, `venue` |

### Schema Structure
```sql
CREATE TABLE raw_data.{table_name} (
  id SERIAL PRIMARY KEY,
  external_id TEXT NOT NULL,        -- Original ID from ElGoose API
  data JSONB NOT NULL,              -- Complete JSON record
  source_url TEXT NOT NULL,         -- API endpoint URL
  is_processed BOOLEAN DEFAULT FALSE, -- For vectorization pipeline
  version INTEGER DEFAULT 1,        -- Version tracking
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Public Views
All `raw_data` tables are exposed via public views:
- `public.raw_data_songs`
- `public.raw_data_shows`
- `public.raw_data_venues`
- `public.raw_data_setlists`
- etc.

## 🔧 Configuration

### Environment Variables
Set these in your Supabase Edge Function environment:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
OPENAI_API_KEY=your-openai-key
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIMENSIONS=1536
CHAT_MODEL=gpt-4
```

### API Sources Configuration
The `api_sources` table controls which endpoints are processed:

```sql
INSERT INTO api_sources (name, url, description, is_active) VALUES
('Songs', 'https://elgoose.net/api/v2/songs.json', 'Song catalog', true),
('Shows', 'https://elgoose.net/api/v2/shows.json', 'Concert shows', true),
('Venues', 'https://elgoose.net/api/v2/venues.json', 'Venue information', true),
('Setlists', 'https://elgoose.net/api/v2/setlists.json', 'Song performances', true);
```

## 📊 Processing Limits

| Endpoint | Incremental Limit | Manual Limit | Processing Time |
|----------|------------------|--------------|-----------------|
| Setlists | 100 rows | 200 rows | 10-20 seconds |
| Songs | 100 rows | 200 rows | 5-15 seconds |
| Shows | 50 rows | 100 rows | 5-10 seconds |
| Venues | 50 rows | 100 rows | 5-10 seconds |
| Latest | 20 rows | 40 rows | 3-8 seconds |
| Metadata | 50 rows | 100 rows | 5-10 seconds |
| Links | 50 rows | 100 rows | 5-10 seconds |
| Uploads | 50 rows | 100 rows | 5-10 seconds |
| Appearances | 50 rows | 100 rows | 5-10 seconds |

## 🚀 Deployment

### Deploy Edge Function
```bash
# Deploy the function
npx supabase functions deploy ingest_raw_data

# Check deployment status
npx supabase functions list
```

### Run Database Migrations
```bash
# Apply all migrations
npx supabase db push

# Check migration status
npx supabase migration list
```

## 🔍 Monitoring

### Edge Function Logs
```bash
# View real-time logs
npx supabase functions logs ingest_raw_data

# View specific time range
npx supabase functions logs ingest_raw_data --since 1h
```

### Database Queries
```sql
-- Check recent data
SELECT COUNT(*) FROM raw_data_songs 
WHERE created_at > NOW() - INTERVAL '1 hour';

-- Check processing status
SELECT 
  endpoint,
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE is_processed = true) as processed_records
FROM raw_data_songs 
GROUP BY endpoint;
```

## 🛠️ Development

### Local Development
```bash
# Start local Supabase
npx supabase start

# Serve functions locally
npx supabase functions serve

# Test function locally
curl -X POST http://localhost:54321/functions/v1/ingest_raw_data \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"endpoint": "songs", "mode": "incremental"}'
```

### Testing
```bash
# Run system verification
node tests/verify_complete_system.js

# Test specific endpoint
node tests/test_github_actions.js
```

## 🔐 Security

### Row Level Security (RLS)
- All `raw_data` tables have RLS enabled
- Public views grant SELECT access to anon/authenticated users
- Service role key required for INSERT/UPDATE operations

### API Security
- Edge Functions use service role key for database access
- API calls use anonymous key for authentication
- No sensitive data exposed in function responses

## 📈 Performance Optimization

### Database Indexes
```sql
-- External ID index for fast lookups
CREATE INDEX idx_raw_data_songs_external_id ON raw_data_songs(external_id);

-- Created at index for recent data queries
CREATE INDEX idx_raw_data_songs_created_at ON raw_data_songs(created_at);

-- Processing status index
CREATE INDEX idx_raw_data_songs_processed ON raw_data_songs(is_processed);
```

### Edge Function Optimization
- Batch processing to reduce API calls
- Smart filtering to process only recent data
- Error handling with graceful fallbacks
- Timeout prevention with row limits

## 🚨 Troubleshooting

### Common Issues

1. **Function Timeout**
   - Reduce processing limits
   - Check API response times
   - Review function logs

2. **Database Connection Errors**
   - Verify service role key
   - Check Supabase project status
   - Review network connectivity

3. **No Data Processing**
   - Check API endpoint availability
   - Verify data filtering logic
   - Review function logs for errors

### Debug Commands
```bash
# Check function status
npx supabase functions list

# View function logs
npx supabase functions logs ingest_raw_data --since 1h

# Test database connection
npx supabase db shell
```
