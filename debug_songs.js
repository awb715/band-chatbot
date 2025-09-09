import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function debugSongs() {
  console.log('🔍 DEBUGGING SONGS ENDPOINT');
  console.log('============================\n');

  try {
    // Step 1: Check what's currently in the songs table
    console.log('1️⃣ Current songs table contents:');
    const { data: currentSongs, error: currentError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .order('created_at', { ascending: false });

    if (currentError) {
      console.error('❌ Error fetching current songs:', currentError);
    } else {
      console.log(`   Found ${currentSongs.length} records:`);
      currentSongs.forEach((song, index) => {
        console.log(`   ${index + 1}. External ID: ${song.external_id}, Created: ${song.created_at}`);
        console.log(`      Data:`, JSON.stringify(song.data, null, 6));
      });
    }

    // Step 2: Test the ElGoose API directly
    console.log('\n2️⃣ Testing ElGoose Songs API directly:');
    try {
      const response = await fetch('https://elgoose.com/api/songs', {
        // Disable SSL verification for testing
        agent: new (await import('https')).Agent({
          rejectUnauthorized: false
        })
      });
      const apiData = await response.json();
    
      console.log(`   API Response structure:`, {
        hasError: 'error' in apiData,
        errorValue: apiData.error,
        hasData: 'data' in apiData,
        dataType: Array.isArray(apiData.data) ? 'array' : typeof apiData.data,
        dataLength: Array.isArray(apiData.data) ? apiData.data.length : 'N/A'
      });

      if (apiData.data && Array.isArray(apiData.data)) {
        console.log(`   First 3 songs from API:`);
        apiData.data.slice(0, 3).forEach((song, index) => {
          console.log(`   ${index + 1}. ID: ${song.id}, Name: ${song.song_name || song.name || 'N/A'}`);
        });
      }
    } catch (apiError) {
      console.log(`   ❌ API Error: ${apiError.message}`);
      console.log(`   This explains why the Edge Function might be failing!`);
    }

    // Step 3: Call the Edge Function for songs only
    console.log('\n3️⃣ Calling Edge Function for songs only:');
    const functionResponse = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ endpoint: 'songs' })
    });

    const functionResult = await functionResponse.json();
    console.log('   Function result:', JSON.stringify(functionResult, null, 2));

    // Step 4: Check songs table again after function call
    console.log('\n4️⃣ Songs table after function call:');
    const { data: afterSongs, error: afterError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .order('created_at', { ascending: false });

    if (afterError) {
      console.error('❌ Error fetching songs after function call:', afterError);
    } else {
      console.log(`   Found ${afterSongs.length} records:`);
      afterSongs.forEach((song, index) => {
        console.log(`   ${index + 1}. External ID: ${song.external_id}, Created: ${song.created_at}`);
        if (song.external_id !== 'song-123') { // Skip test data
          console.log(`      Real data:`, JSON.stringify(song.data, null, 6));
        }
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

debugSongs();
