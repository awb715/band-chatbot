# GitHub Actions Workflows

This directory contains automated workflows for the band-chatbot data ingestion pipeline.

## Available Workflows

### 1. `data-ingestion.yml` - Basic Daily Ingestion
- **Schedule:** Daily at 2 AM UTC
- **Manual Trigger:** Yes (with endpoint selection)
- **Purpose:** Basic daily data ingestion from all ElGoose API endpoints

### 2. `advanced-ingestion.yml` - Advanced Daily Ingestion
- **Schedule:** Daily at 2 AM UTC
- **Manual Trigger:** Yes (with endpoint selection and force refresh option)
- **Purpose:** Advanced daily ingestion with detailed reporting and monitoring

### 3. `test-ingestion.yml` - Testing Workflow
- **Schedule:** Manual only
- **Manual Trigger:** Yes (with test type selection)
- **Purpose:** Testing and validation of the ingestion pipeline

## Setup Instructions

### 1. Add Required Secrets
Go to your GitHub repository → Settings → Secrets and variables → Actions, and add:

```
SUPABASE_URL=https://jvvcxraopwbpewisiohu.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
OPENAI_API_KEY=your_openai_api_key_here
BAND_NAME=your_band_name_here
```

### 2. Enable Workflows
- Go to Actions tab in your GitHub repository
- Enable workflows if prompted
- Workflows will run automatically according to their schedules

### 3. Manual Execution
- Go to Actions tab
- Select the workflow you want to run
- Click "Run workflow"
- Choose your options and click "Run workflow"

## Workflow Features

### Daily Ingestion
- **Automatic execution** every day at 2 AM UTC
- **Incremental updates** - only processes new/changed data
- **Comprehensive logging** and error handling
- **Performance monitoring** with timing metrics

### Manual Testing
- **Quick tests** for rapid validation
- **Full tests** for comprehensive validation
- **Endpoint-specific tests** for targeted testing
- **Detailed reporting** with GitHub step summaries

### Monitoring
- **Success/failure notifications** in GitHub Actions
- **Detailed logs** for debugging
- **Performance metrics** in each run
- **Artifact uploads** for failed runs

## Customization

### Schedule Changes
Edit the `cron` expression in the workflow files:
```yaml
schedule:
  - cron: '0 2 * * *'  # Daily at 2 AM UTC
  - cron: '0 */6 * * *'  # Every 6 hours
  - cron: '0 9 * * 1-5'  # Weekdays at 9 AM UTC
```

### Timezone Adjustment
The workflows run in UTC. To adjust for your timezone:
- EST: `'0 21 * * *'` (9 PM EST = 2 AM UTC)
- PST: `'0 18 * * *'` (6 PM PST = 2 AM UTC)

### Notification Setup
Add Slack/Discord notifications by modifying the workflow files:
```yaml
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Troubleshooting

### Common Issues
1. **Secrets not found:** Ensure all required secrets are added to GitHub
2. **Permission denied:** Check Supabase service role key permissions
3. **API rate limits:** Monitor OpenAI API usage and limits
4. **Network timeouts:** Check ElGoose API availability

### Debugging
1. Check the Actions tab for detailed logs
2. Review Supabase dashboard for database changes
3. Monitor function logs in Supabase Edge Functions
4. Check environment variables in workflow runs

## Best Practices

1. **Test first:** Use the test workflow before deploying changes
2. **Monitor regularly:** Check workflow runs and logs
3. **Backup data:** Ensure data is properly backed up
4. **Rate limiting:** Be mindful of API rate limits
5. **Security:** Keep secrets secure and rotate regularly
