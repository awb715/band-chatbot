# Band Chatbot - RAG System

A Retrieval-Augmented Generation (RAG) chatbot system designed specifically for band and music-related interactions.

## Project Structure

```
rag-chatbot/
├── embeddings/          # Vector embeddings storage and processing
├── retrieval/           # Document retrieval and search logic
├── supabase/           # Supabase database integration
├── test_data/          # Sample data for testing
├── .env                # Environment variables
├── README.md           # Project documentation
└── cursor.yml          # Cursor IDE configuration
```

## Features

- **Vector Embeddings**: Generate and store embeddings for band-related content
- **Document Retrieval**: Intelligent search and retrieval of relevant information
- **Supabase Integration**: Database management and real-time features
- **RAG Pipeline**: Complete retrieval-augmented generation workflow

## Setup

1. Clone the repository
2. Install dependencies: `npm install`
3. Copy `.env.example` to `.env` and configure your environment variables
4. Set up your Supabase project and configure the connection
5. Run the application: `npm start`

## Environment Variables

See `.env` file for required configuration variables including:
- Supabase credentials
- OpenAI API key
- Vector database configuration
- Application settings

## Development

This project uses Cursor IDE with custom configuration defined in `cursor.yml` for optimal development experience.

## License

MIT License
