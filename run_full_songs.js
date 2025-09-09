import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

async function runFullSongs() {
  console.log('🎵 RUNNING FULL SONGS ENDPOINT');
  console.log('==============================\n');

  try {
    // Check current songs count before
    const { count: beforeCount } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact', head: true });

    console.log(`📊 Current songs in database: ${beforeCount}`);

    // Call the Edge Function specifically for songs
    console.log('\n🚀 Calling Edge Function for songs only...');
    const startTime = Date.now();
    
    const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ endpoint: 'Songs' })
    });

    const result = await response.json();
    const endTime = Date.now();
    const duration = endTime - startTime;

    console.log(`⏱️  Processing completed in ${duration}ms`);
    console.log('\n📊 Function Results:');
    console.log(JSON.stringify(result, null, 2));

    // Check songs count after
    const { count: afterCount } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact', head: true });

    console.log(`\n📈 Songs count after processing: ${afterCount}`);
    console.log(`📈 New songs added: ${afterCount - beforeCount}`);

    // Show some sample songs
    console.log('\n🎵 Sample songs from database:');
    const { data: sampleSongs } = await supabase
      .from('raw_data_songs')
      .select('external_id, data')
      .not('external_id', 'like', 'test-%')
      .order('created_at', { ascending: false })
      .limit(5);

    if (sampleSongs) {
      sampleSongs.forEach((song, index) => {
        console.log(`\n${index + 1}. ${song.data.name} (ID: ${song.external_id})`);
        console.log(`   Slug: ${song.data.slug}`);
        console.log(`   Original Artist: ${song.data.original_artist}`);
        console.log(`   Updated: ${song.data.updated_at}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Initialize Supabase client
const supabase = createClient(supabaseUrl, supabaseKey);

runFullSongs();
