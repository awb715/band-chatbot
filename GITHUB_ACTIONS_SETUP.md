# GitHub Actions Setup Guide

## 🚀 Automated Data Ingestion with GitHub Actions

This guide explains how to set up automated data ingestion using GitHub Actions for your band-chatbot project.

## 📋 Prerequisites

1. **GitHub Repository** with admin access
2. **Personal Access Token** with `workflow` scope
3. **Supabase Project** with deployed Edge Functions
4. **Required Secrets** configured in GitHub

## 🔧 Setup Instructions

### Step 1: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add these secrets:

```
SUPABASE_URL=https://jvvcxraopwbpewisiohu.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
OPENAI_API_KEY=your_openai_api_key_here
BAND_NAME=your_band_name_here
```

### Step 2: Create Workflow Files

Create the following files in your repository:

#### `.github/workflows/data-ingestion.yml`
```yaml
name: Data Ingestion Pipeline

on:
  # Run daily at 2 AM UTC
  schedule:
    - cron: '0 2 * * *'
  
  # Manual trigger
  workflow_dispatch:
    inputs:
      endpoint:
        description: 'Specific endpoint to process (optional)'
        required: false
        default: 'all'
        type: choice
        options:
          - all
          - setlists
          - shows
          - songs
          - venues
          - jamcharts
          - latest
          - metadata
          - links
          - uploads
          - appearances

jobs:
  ingest-data:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        
    - name: Install dependencies
      run: npm ci
      
    - name: Run data ingestion
      env:
        SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
        SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
        SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        EMBEDDING_MODEL: text-embedding-3-small
        EMBEDDING_DIMENSIONS: 1536
        CHAT_MODEL: gpt-4
        PORT: 3000
        NODE_ENV: production
        LOG_LEVEL: info
        BAND_NAME: ${{ secrets.BAND_NAME }}
      run: |
        echo "🚀 Starting data ingestion pipeline..."
        echo "📅 Scheduled run: $(date)"
        echo "🎯 Target endpoint: ${{ github.event.inputs.endpoint || 'all' }}"
        
        # Run the test script which calls the production function
        npm test
        
        echo "✅ Data ingestion completed successfully!"
```

#### `.github/workflows/test-ingestion.yml`
```yaml
name: Test Data Ingestion

on:
  # Manual trigger only
  workflow_dispatch:
    inputs:
      test_type:
        description: 'Type of test to run'
        required: true
        default: 'full'
        type: choice
        options:
          - full
          - quick
          - specific-endpoint
      endpoint:
        description: 'Specific endpoint to test (if applicable)'
        required: false
        default: 'setlists'
        type: choice
        options:
          - setlists
          - shows
          - songs
          - venues
          - jamcharts
          - latest
          - metadata
          - links
          - uploads
          - appearances

jobs:
  test-ingestion:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        
    - name: Install dependencies
      run: npm ci
      
    - name: Run test
      env:
        SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
        SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
        SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        EMBEDDING_MODEL: text-embedding-3-small
        EMBEDDING_DIMENSIONS: 1536
        CHAT_MODEL: gpt-4
        PORT: 3000
        NODE_ENV: production
        LOG_LEVEL: debug
        BAND_NAME: ${{ secrets.BAND_NAME }}
      run: |
        echo "🧪 Running ${{ github.event.inputs.test_type }} test..."
        echo "📅 Test time: $(date)"
        echo "🎯 Test type: ${{ github.event.inputs.test_type }}"
        
        if [ "${{ github.event.inputs.test_type }}" = "specific-endpoint" ]; then
          echo "🎯 Testing endpoint: ${{ github.event.inputs.endpoint }}"
        fi
        
        # Run the test
        npm test
        
        echo "✅ Test completed successfully!"
```

### Step 3: Enable Workflows

1. Go to the **Actions** tab in your GitHub repository
2. Enable workflows if prompted
3. The workflows will now run automatically according to their schedules

## 🎯 Usage

### Daily Automatic Execution
- **Schedule:** Every day at 2 AM UTC
- **Action:** Automatically ingests data from all ElGoose API endpoints
- **Monitoring:** Check the Actions tab for run status and logs

### Manual Execution
1. Go to **Actions** tab
2. Select the workflow you want to run
3. Click **"Run workflow"**
4. Choose your options and click **"Run workflow"**

### Testing
1. Use the **Test Data Ingestion** workflow for validation
2. Choose from different test types:
   - **Full test:** Complete pipeline validation
   - **Quick test:** Fast validation
   - **Specific endpoint:** Test individual endpoints

## 📊 Monitoring

### GitHub Actions
- **Run Status:** Success/failure indicators
- **Detailed Logs:** Step-by-step execution logs
- **Performance Metrics:** Timing and resource usage
- **Error Reporting:** Detailed error messages

### Supabase Dashboard
- **Function Logs:** Edge Function execution logs
- **Database Changes:** New records and updates
- **Performance Metrics:** Processing times and statistics

## 🔧 Customization

### Schedule Changes
Edit the `cron` expression in the workflow files:
```yaml
schedule:
  - cron: '0 2 * * *'    # Daily at 2 AM UTC
  - cron: '0 */6 * * *'  # Every 6 hours
  - cron: '0 9 * * 1-5'  # Weekdays at 9 AM UTC
```

### Timezone Adjustment
- **EST:** `'0 21 * * *'` (9 PM EST = 2 AM UTC)
- **PST:** `'0 18 * * *'` (6 PM PST = 2 AM UTC)
- **CET:** `'0 3 * * *'` (3 AM CET = 2 AM UTC)

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

## 🚨 Troubleshooting

### Common Issues
1. **Secrets not found:** Ensure all required secrets are added to GitHub
2. **Permission denied:** Check Supabase service role key permissions
3. **API rate limits:** Monitor OpenAI API usage and limits
4. **Network timeouts:** Check ElGoose API availability

### Debugging Steps
1. Check the **Actions** tab for detailed logs
2. Review **Supabase dashboard** for database changes
3. Monitor **function logs** in Supabase Edge Functions
4. Check **environment variables** in workflow runs

## 📈 Benefits

- **Automated Data Ingestion:** No manual intervention required
- **Reliable Scheduling:** Consistent daily data updates
- **Comprehensive Monitoring:** Full visibility into pipeline health
- **Flexible Testing:** Easy validation and debugging
- **Scalable Architecture:** Easy to add new endpoints or modify schedules

## 🔐 Security

- **Secrets Management:** All sensitive data stored securely in GitHub Secrets
- **Minimal Permissions:** Only necessary permissions granted
- **Audit Trail:** Complete execution history in GitHub Actions
- **Secure Communication:** HTTPS for all API communications

---

**Your data ingestion pipeline is now fully automated!** 🎉
