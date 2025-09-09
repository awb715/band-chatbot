# Edge Functions Documentation

## Overview

This project uses Supabase Edge Functions to handle the RAG pipeline for ElGoose API data:

1. **`ingest_raw_data`** - **RECORD-LEVEL INCREMENTAL UPDATER** - Fetches full JSON responses from ElGoose APIs and processes only new/changed individual records

## Core Functionality Summary

### ingest_raw_data: Record-Level Incremental Updater
**What it does:** Fetches complete JSON responses from ElGoose APIs, then processes each individual record to determine if it's new, changed, or unchanged.

**How it works:**
- Fetches FULL JSON response from each endpoint
- Extracts external ID from each record (id, show_id, song_id, etc.)
- Checks if record exists in database by external ID
- **New records:** Inserts complete JSON data
- **Changed records:** Updates existing record with new data
- **Unchanged records:** Skips entirely
- Tracks version numbers and timestamps for all changes

**Key insight:** This is NOT a full replacement strategy - it's a smart incremental updater that preserves data history and only processes what's actually new or different.

## 1. ingest_raw_data Function

### Purpose
**RECORD-LEVEL INCREMENTAL UPDATER** - Fetches complete JSON responses from ElGoose API endpoints and intelligently processes only individual records that are new or have changed, storing them in dedicated `raw_data` tables.

### Core Logic
This function implements a **smart incremental update strategy**:

1. **Fetches FULL JSON response** from each ElGoose endpoint
2. **Processes each record individually** in the response array
3. **For each record:**
   - Extracts external ID (id, show_id, song_id, venue_id, slug)
   - Checks if record exists in database by external ID
   - **If NEW:** Inserts complete JSON record
   - **If EXISTS but CHANGED:** Updates existing record with new data
   - **If EXISTS and UNCHANGED:** Skips entirely
4. **Tracks versions and timestamps** for all changes

### Key Features
- ✅ **Record-level processing** - Not full replacement, individual record updates
- ✅ **Smart deduplication** - Uses external IDs to identify existing records
- ✅ **Change detection** - Compares JSON data to detect actual changes
- ✅ **Version tracking** - Increments version numbers for updated records
- ✅ **Full data preservation** - Stores complete JSON records, not just deltas
- ✅ **Efficient processing** - Only processes what's actually new or changed
- ✅ **Error resilience** - Individual record failures don't stop the entire process

### Architecture
```
ElGoose APIs → ingest_raw_data → Raw Data Tables
     ↓              ↓                    ↓
  setlists.json → Record-Level    → raw_data_setlists
  shows.json    → Processing      → raw_data_shows
  songs.json    → (New/Changed)   → raw_data_songs
  venues.json   → Only            → raw_data_venues
  ...           →                 → ...
```

### Detailed Data Flow
1. **Get Active Endpoints** - Query `api_sources` table for active endpoints
2. **Fetch Full Response** - Make HTTP requests to each ElGoose API endpoint (gets complete JSON)
3. **Process Each Record** - For every record in the response:
   - Extract external ID (id, show_id, song_id, venue_id, slug)
   - Query database for existing record with same external ID
   - **If not found:** Insert new record with complete JSON data
   - **If found but data changed:** Update existing record, increment version
   - **If found and unchanged:** Skip record entirely
4. **Track Results** - Return detailed statistics about new/updated/skipped records

### Example Processing Scenario
**First Run:**
- API returns: `[{id: "123", song: "A"}, {id: "124", song: "B"}]`
- Result: 2 new records inserted

**Second Run (same data):**
- API returns: `[{id: "123", song: "A"}, {id: "124", song: "B"}]`
- Result: 0 new, 0 updated, 2 skipped

**Third Run (one changed):**
- API returns: `[{id: "123", song: "A"}, {id: "124", song: "B Updated"}]`
- Result: 0 new, 1 updated, 1 skipped

### Usage
```bash
# Call the function
curl -X POST https://your-project.supabase.co/functions/v1/ingest_raw_data \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### Response Format
```json
{
  "success": true,
  "total_new_records": 10,
  "total_updated_records": 2,
  "results": [
    {
      "endpoint": "Setlists",
      "total_fetched": 5,
      "new_records": 3,
      "updated_records": 1,
      "errors": [],
      "processing_time_ms": 2500
    }
  ]
}
```

## Next Steps

The next phase will involve building a vectorization pipeline that processes the raw data stored by `ingest_raw_data` into vector embeddings for RAG queries.

## Database Schema

### Raw Data Tables
Each ElGoose endpoint has its own table in the `raw_data` schema:

```sql
-- Example: raw_data.setlists
CREATE TABLE raw_data.setlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id TEXT,                    -- Original ID from ElGoose API
  data JSONB NOT NULL,                 -- Raw JSON response
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,            -- When data was processed
  is_processed BOOLEAN DEFAULT FALSE,  -- Processing status
  source_url TEXT NOT NULL,            -- Original API URL
  version INTEGER DEFAULT 1,           -- For tracking data changes
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Helper Functions
The schema includes several helper functions:

- `raw_data.mark_as_processed(table_name, record_id)` - Mark record as processed
- `raw_data.get_unprocessed_records(table_name, limit)` - Get unprocessed records
- `raw_data.get_processing_stats(table_name)` - Get processing statistics
- `raw_data.cleanup_old_records(table_name, days_old)` - Clean up old records

## Error Handling

Both functions implement comprehensive error handling:

- **Per-record errors** - Individual record failures don't stop the entire process
- **Per-endpoint errors** - Endpoint failures are logged and reported
- **Graceful degradation** - Partial success is still reported
- **Detailed logging** - Console logs for debugging

## Performance Considerations

### ingest_raw_data
- Processes endpoints sequentially to avoid overwhelming ElGoose API
- Implements incremental updates to minimize processing time
- Uses external_id for efficient duplicate detection

### update_json_data (Legacy)
- Processes records in batches to avoid rate limits
- Uses content hashing for duplicate detection
- Generates embeddings in batches for efficiency

## Monitoring

Both functions provide detailed statistics:

- Processing time per endpoint
- Number of new/updated records
- Error counts and messages
- Overall success/failure status

## Next Steps

1. **Set up scheduling** for daily ingestion
2. **Build vectorization pipeline** to process raw data
3. **Create RAG retrieval system** for querying
4. **Add monitoring and alerting** for production use

## Testing

Use the test script to validate the functions:

```bash
node test_data/test_raw_data_ingestion.js
```

This will test both functions and verify data integrity.
