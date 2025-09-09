import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkSetlists() {
  console.log('📊 SETLISTS DATA ANALYSIS');
  console.log('=========================\n');

  try {
    // Get total count
    const { count } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact', head: true });
    
    console.log(`📈 Total setlists records: ${count}`);

    // Check date range
    const { data: dateRange } = await supabase
      .from('raw_data_setlists')
      .select('data->showdate')
      .not('external_id', 'like', 'test-%')
      .not('data->showdate', 'is', null)
      .order('data->showdate', { ascending: true });
    
    if (dateRange && dateRange.length > 0) {
      const dates = dateRange.map(r => r.showdate).filter(Boolean);
      console.log(`📅 Date range: ${dates[0]} to ${dates[dates.length - 1]}`);
      console.log(`📅 Shows with dates: ${dates.length}`);
    }

    // Check unique shows
    const { data: uniqueShows } = await supabase
      .from('raw_data_setlists')
      .select('data->show_id')
      .not('external_id', 'like', 'test-%')
      .not('data->show_id', 'is', null);
    
    if (uniqueShows) {
      const showIds = uniqueShows.map(r => r.show_id).filter(Boolean);
      const uniqueShowIds = [...new Set(showIds)];
      console.log(`🎪 Unique shows: ${uniqueShowIds.length}`);
      console.log(`🎵 Total song entries: ${showIds.length}`);
      console.log(`📊 Average songs per show: ${(showIds.length / uniqueShowIds.length).toFixed(1)}`);
    }

    // Check artists
    const { data: artists } = await supabase
      .from('raw_data_setlists')
      .select('data->artist')
      .not('external_id', 'like', 'test-%')
      .not('data->artist', 'is', null);
    
    if (artists) {
      const artistNames = artists.map(r => r.artist).filter(Boolean);
      const uniqueArtists = [...new Set(artistNames)];
      console.log(`🎤 Unique artists: ${uniqueArtists.length}`);
      console.log(`🎤 Artists: ${uniqueArtists.join(', ')}`);
    }

    // Sample recent shows
    console.log('\n📋 Recent shows sample:');
    const { data: recentShows } = await supabase
      .from('raw_data_setlists')
      .select('data->showdate, data->venuename, data->artist, data->songname')
      .not('external_id', 'like', 'test-%')
      .not('data->showdate', 'is', null)
      .order('data->showdate', { ascending: false })
      .limit(10);

    if (recentShows) {
      recentShows.forEach((show, index) => {
        console.log(`   ${index + 1}. ${show.showdate} - ${show.venuename} - ${show.artist} - ${show.songname}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkSetlists();
