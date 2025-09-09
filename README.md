# Band Chatbot - RAG System

A Retrieval-Augmented Generation (RAG) chatbot system designed specifically for band and music-related interactions using ElGoose API data.

## Project Structure

```
band-chatbot/
├── supabase/
│   ├── functions/
│   │   └── ingest_raw_data/    # Edge Function for data ingestion
│   ├── migrations/             # Database schema migrations
│   └── schema.sql             # Database schema
├── test_data/                 # Test scripts and sample data
├── .env                      # Environment variables
├── README.md                 # Project documentation
└── cursor.yml                # Cursor IDE configuration
```

## Features

- **Incremental Data Ingestion**: Smart record-level updates from ElGoose APIs
- **Raw Data Storage**: Complete JSON data preservation with version tracking
- **Supabase Integration**: PostgreSQL with pgvector for vector operations
- **Edge Functions**: Serverless data processing pipeline
- **RAG Pipeline**: Foundation for retrieval-augmented generation

## Architecture

The system uses a two-step pipeline approach:

1. **Data Ingestion** (`ingest_raw_data`): Fetches and stores raw data from ElGoose APIs
2. **Vectorization** (coming next): Processes raw data into vector embeddings

## Setup

1. Clone the repository
2. Install dependencies: `npm install`
3. Configure your `.env` file with Supabase and OpenAI credentials
4. Deploy the database schema: `npm run db:push`
5. Deploy Edge Functions: `npm run functions:deploy`
6. Test the system: `npm test`

## Environment Variables

Required configuration in `.env`:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for database access
- `OPENAI_API_KEY` - OpenAI API key for embeddings

## Development

This project uses Cursor IDE with custom configuration defined in `cursor.yml` for optimal development experience.

## License

MIT License
