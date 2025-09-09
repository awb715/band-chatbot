# 🧪 Test Files

This directory contains test scripts for the band-chatbot RAG system.

## 📁 Files

### `test_github_actions.js`
- **Purpose**: Simulates GitHub Actions workflow behavior
- **Usage**: `node test_github_actions.js`
- **What it tests**: Parallel processing, endpoint handling, response times

### `verify_complete_system.js`
- **Purpose**: Comprehensive system verification
- **Usage**: `node verify_complete_system.js`
- **What it tests**: Database connectivity, Edge Function performance, data processing limits

### `run_full_songs.js`
- **Purpose**: Test full songs endpoint processing
- **Usage**: `node run_full_songs.js`
- **What it tests**: Complete songs data ingestion and processing

## 🚀 Running Tests

```bash
# Test GitHub Actions workflow simulation
node test_github_actions.js

# Verify complete system functionality
node verify_complete_system.js

# Test full songs endpoint processing
node run_full_songs.js
```

## 📊 Expected Results

- **Response times**: < 1 second per endpoint
- **Database connectivity**: All tables accessible
- **Data processing**: Limits respected
- **Error handling**: Graceful failures

## 🔧 Prerequisites

- Node.js 18+
- `.env` file with Supabase credentials
- Active Supabase project
- Deployed Edge Functions
