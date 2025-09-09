-- Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create the api_sources table to track data sources
CREATE TABLE IF NOT EXISTS api_sources (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  url TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create the documents table for storing embedded content
CREATE TABLE IF NOT EXISTS documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  content TEXT NOT NULL,
  embedding VECTOR(1536), -- text-embedding-3-small has 1536 dimensions
  metadata JSONB DEFAULT '{}',
  content_hash TEXT,
  source_method TEXT,
  source_key TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON documents 
USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX IF NOT EXISTS documents_metadata_idx ON documents USING GIN (metadata);
CREATE INDEX IF NOT EXISTS documents_created_at_idx ON documents (created_at);
CREATE INDEX IF NOT EXISTS documents_source_method_idx ON documents (source_method);
CREATE INDEX IF NOT EXISTS documents_source_key_idx ON documents (source_key);
CREATE INDEX IF NOT EXISTS documents_content_hash_idx ON documents (content_hash);
CREATE INDEX IF NOT EXISTS api_sources_url_idx ON api_sources (url);
CREATE INDEX IF NOT EXISTS api_sources_active_idx ON api_sources (is_active);

-- Create a function to update the updated_at timestamp for api_sources
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for api_sources updated_at
CREATE TRIGGER update_api_sources_updated_at 
  BEFORE UPDATE ON api_sources 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Create function for similarity search
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(1536),
  match_threshold FLOAT DEFAULT 0.7,
  match_count INT DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  metadata JSONB,
  similarity FLOAT
)
LANGUAGE SQL
AS $$
  SELECT
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE 1 - (documents.embedding <=> query_embedding) > match_threshold
  ORDER BY documents.embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Insert initial API sources from elgoose.net
INSERT INTO api_sources (name, url, description, is_active) VALUES
  ('Setlists', 'https://elgoose.net/api/v2/setlists.json', 'Song-by-song entries for shows', true),
  ('Latest', 'https://elgoose.net/api/v2/latest.json', 'Recent setlist lines in recency order', true),
  ('Shows', 'https://elgoose.net/api/v2/shows.json', 'One row per show (date, artist, venue, location)', true),
  ('Songs', 'https://elgoose.net/api/v2/songs.json', 'Song catalog (name, slug, attributes)', true),
  ('Venues', 'https://elgoose.net/api/v2/venues.json', 'Venue directory', true),
  ('Jamcharts', 'https://elgoose.net/api/v2/jamcharts.json', 'Curated performance notes', true),
  ('Metadata', 'https://elgoose.net/api/v2/metadata.json', 'Extra metadata tied to songs/setlists', true),
  ('Links', 'https://elgoose.net/api/v2/links.json', 'External links for shows', true),
  ('Uploads', 'https://elgoose.net/api/v2/uploads.json', 'Show posters/featured media', true),
  ('Appearances', 'https://elgoose.net/api/v2/appearances.json', 'Which person appeared at which show', true)
ON CONFLICT (url) DO NOTHING;
