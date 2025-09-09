# 🚀 GitHub Actions Workflows

This directory contains automated workflows for the band-chatbot RAG system data ingestion pipeline.

## 📁 Workflows

### `daily-incremental.yml`
**Purpose**: Automated daily data updates
- **Schedule**: Daily at 2 AM UTC
- **Mode**: Incremental (recent data only)
- **Processing**: Parallel (3 endpoints simultaneously)
- **Endpoints**: All 9 ElGoose API endpoints
- **Timeout Safety**: Individual endpoint failures don't stop others

### `manual-full-update.yml`
**Purpose**: On-demand full data processing
- **Trigger**: Manual workflow dispatch
- **Mode**: Manual (full data processing)
- **Processing**: Single endpoint at a time
- **Use Case**: Initial data load, data recovery, testing

### `monitor-data-health.yml`
**Purpose**: System health monitoring
- **Schedule**: Daily at 3 AM UTC (1 hour after data updates)
- **Checks**: Recent data availability, database connectivity
- **Alerts**: Warns if no recent data found
- **Action**: Fails workflow if health checks fail

## 🔧 Configuration

### Required Secrets
Set these in your GitHub repository settings:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
OPENAI_API_KEY=your-openai-key
BAND_NAME=your-band-name
```

### Workflow Triggers

#### Daily Incremental
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:
    inputs:
      endpoint: [all, setlists, songs, shows, venues, latest, metadata, links, uploads, appearances]
```

#### Manual Full Update
```yaml
on:
  workflow_dispatch:
    inputs:
      endpoint: [setlists, songs, shows, venues, latest, metadata, links, uploads, appearances]
```

## 📊 Performance Metrics

| Workflow | Execution Time | Endpoints | Parallel Processing |
|----------|----------------|-----------|-------------------|
| Daily Incremental | ~2-3 minutes | 9 | 3 simultaneously |
| Manual Full Update | ~5-10 minutes | 1 | Sequential |
| Health Monitor | ~30 seconds | N/A | N/A |

## 🎯 Processing Limits

| Endpoint | Daily Limit | Manual Limit | Expected Daily Updates |
|----------|-------------|--------------|----------------------|
| Setlists | 100 rows | 200 rows | 0-40 rows |
| Songs | 100 rows | 200 rows | 0-20 rows |
| Shows | 50 rows | 100 rows | 0-10 rows |
| Venues | 50 rows | 100 rows | 0-5 rows |
| Latest | 20 rows | 40 rows | 0-10 rows |
| Metadata | 50 rows | 100 rows | 0-10 rows |
| Links | 50 rows | 100 rows | 0-10 rows |
| Uploads | 50 rows | 100 rows | 0-10 rows |
| Appearances | 50 rows | 100 rows | 0-10 rows |

## 🔍 Monitoring

### Success Indicators
- ✅ All workflows complete without errors
- ✅ Data appears in database within 1 hour
- ✅ Health checks pass daily
- ✅ Response times < 60 seconds per endpoint

### Failure Indicators
- ❌ Workflow timeouts (> 6 hours)
- ❌ API errors (HTTP 4xx/5xx)
- ❌ Database connection failures
- ❌ No recent data in health checks

## 🛠️ Troubleshooting

### Common Issues

1. **Workflow Timeout**
   - Check Edge Function logs
   - Verify API endpoint availability
   - Reduce processing limits if needed

2. **Authentication Errors**
   - Verify Supabase credentials
   - Check key permissions
   - Ensure keys are not expired

3. **No Data Processing**
   - Check API endpoint responses
   - Verify data filtering logic
   - Review Edge Function logs

### Debug Commands

```bash
# Test individual endpoint
curl -X POST https://your-project.supabase.co/functions/v1/ingest_raw_data \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"endpoint": "songs", "mode": "incremental"}'

# Check recent data
node tests/verify_complete_system.js
```

## 📈 Scaling

### Adding New Endpoints
1. Add endpoint to `api_sources` table
2. Update workflow endpoint lists
3. Adjust processing limits
4. Test with manual workflow

### Performance Optimization
- Adjust `max-parallel` for more/fewer concurrent endpoints
- Modify processing limits based on data volume
- Add retry logic for failed endpoints
- Implement exponential backoff

## 🔐 Security

- All secrets stored in GitHub repository secrets
- No sensitive data in workflow files
- Edge Functions use service role key for database access
- API calls use anonymous key for authentication
