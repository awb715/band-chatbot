# 🎵 Band Chatbot - RAG System

A production-ready Retrieval-Augmented Generation (RAG) chatbot system that automatically ingests and processes music data from ElGoose APIs to power intelligent band-related conversations.

## 🎯 What This Does

This system automatically collects and processes music data to create a knowledge base for a chatbot that can answer questions about:
- **Songs**: Track catalog, original artists, creation dates
- **Shows**: Concert dates, venues, setlists
- **Venues**: Location information, venue details
- **Setlists**: What songs were played at which shows
- **And more**: Latest updates, metadata, links, uploads

## 🏗️ High-Level Architecture

```
ElGoose APIs → Edge Functions → Supabase Database → RAG Pipeline → Chatbot
     ↓              ↓              ↓              ↓
  Raw Data    Smart Processing   Vector Store   AI Responses
```

**The system runs automatically** - no manual intervention needed once deployed.

## 📁 Project Structure

- **`.github/`** - Automated workflows that run daily
- **`supabase/`** - Database and serverless functions
- **`tests/`** - Testing and verification scripts

## 🚀 Quick Start

1. **Clone & Install**
   ```bash
   git clone https://github.com/your-username/band-chatbot.git
   cd band-chatbot && npm install
   ```

2. **Configure Environment**
   ```bash
   # Edit .env with your Supabase and OpenAI credentials
   ```

3. **Deploy**
   ```bash
   npm run db:push && npm run functions:deploy
   ```

4. **Verify**
   ```bash
   npm test
   ```

## 📊 Current Status

✅ **9,332+ records** automatically processed  
✅ **9 API endpoints** monitored daily  
✅ **Production-ready** with error handling  
✅ **Zero maintenance** - runs automatically  

## 🔄 How It Works

1. **Daily at 2 AM UTC**: GitHub Actions triggers data collection
2. **Smart Processing**: Only processes recent/new data (incremental updates)
3. **Parallel Processing**: 3 endpoints processed simultaneously for speed
4. **Health Monitoring**: System checks itself and alerts on issues
5. **Ready for RAG**: Data is prepared for AI-powered conversations

## 📚 Detailed Documentation

- **[GitHub Actions](.github/README.md)** - Automated workflow details
- **[Supabase Backend](supabase/README.md)** - Database and functions
- **[Testing](tests/README.md)** - How to test and verify

## 🎯 Next Phase

This system is ready for **Phase 3**: Building the actual RAG chatbot that will use this data to answer questions about the band's music, shows, and history.

---

*Built with Supabase, OpenAI, and GitHub Actions*
