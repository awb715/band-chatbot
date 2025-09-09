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

async function showRealData() {
  console.log('🎵 REAL EELGOOSE DATA FROM DATABASE');
  console.log('=====================================\n');

  try {
    // Show Songs data
    console.log('🎵 SONGS DATA:');
    console.log('==============');
    const { data: songs, error: songsError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .limit(5);

    if (songsError) {
      console.error('❌ Error fetching songs:', songsError);
    } else {
      songs.forEach((song, index) => {
        console.log(`\n📀 Song ${index + 1}:`);
        console.log(`   External ID: ${song.external_id}`);
        console.log(`   Data Keys: ${song.data_keys ? song.data_keys.join(', ') : 'N/A'}`);
        console.log(`   Created: ${song.created_at}`);
        console.log(`   Raw Data:`, JSON.stringify(song.data, null, 2));
      });
    }

    console.log('\n\n🎤 SHOWS DATA:');
    console.log('==============');
    const { data: shows, error: showsError } = await supabase
      .from('raw_data_shows')
      .select('*')
      .not('external_id', 'like', 'test-%')
      .limit(3);

    if (showsError) {
      console.error('❌ Error fetching shows:', showsError);
    } else {
      shows.forEach((show, index) => {
        console.log(`\n🎪 Show ${index + 1}:`);
        console.log(`   External ID: ${show.external_id}`);
        console.log(`   Data Keys: ${show.data_keys ? show.data_keys.join(', ') : 'N/A'}`);
        console.log(`   Created: ${show.created_at}`);
        console.log(`   Raw Data:`, JSON.stringify(show.data, null, 2));
      });
    }

    console.log('\n\n🏟️ VENUES DATA:');
    console.log('================');
    const { data: venues, error: venuesError } = await supabase
      .from('raw_data_venues')
      .select('*')
      .not('external_id', 'like', 'test-%')
      .limit(3);

    if (venuesError) {
      console.error('❌ Error fetching venues:', venuesError);
    } else {
      venues.forEach((venue, index) => {
        console.log(`\n🏢 Venue ${index + 1}:`);
        console.log(`   External ID: ${venue.external_id}`);
        console.log(`   Data Keys: ${venue.data_keys ? venue.data_keys.join(', ') : 'N/A'}`);
        console.log(`   Created: ${venue.created_at}`);
        console.log(`   Raw Data:`, JSON.stringify(venue.data, null, 2));
      });
    }

    console.log('\n\n📊 SUMMARY:');
    console.log('============');
    
    // Get counts for all tables
    const tables = ['songs', 'shows', 'venues', 'setlists', 'jamcharts', 'metadata', 'links', 'uploads', 'appearances', 'latest'];
    
    for (const table of tables) {
      const { count, error } = await supabase
        .from(`raw_data_${table}`)
        .select('*', { count: 'exact', head: true });
      
      if (!error) {
        console.log(`   ${table.toUpperCase()}: ${count} records`);
      }
    }

    console.log('\n\n🔍 ALL RECORDS (including test data):');
    console.log('=====================================');
    
    // Show all records to see what's actually in the database
    const { data: allSongs, error: allSongsError } = await supabase
      .from('raw_data_songs')
      .select('external_id, created_at, data_keys')
      .limit(10);

    if (!allSongsError && allSongs) {
      console.log('\n📀 All Songs in Database:');
      allSongs.forEach((song, index) => {
        console.log(`   ${index + 1}. External ID: ${song.external_id}, Created: ${song.created_at}, Keys: ${song.data_keys ? song.data_keys.join(', ') : 'N/A'}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

showRealData();
