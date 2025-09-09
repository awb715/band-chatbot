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

async function investigateSetlists() {
  console.log('🔍 INVESTIGATING SETLISTS ENDPOINT');
  console.log('==================================\n');

  try {
    // Step 1: Check current setlists in database
    console.log('1️⃣ Current setlists in database:');
    const { data: currentSetlists, count: currentCount } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false });

    console.log(`   Total records: ${currentCount}`);
    
    if (currentSetlists && currentSetlists.length > 0) {
      console.log('\n📋 Sample setlists:');
      currentSetlists.slice(0, 5).forEach((setlist, index) => {
        const data = setlist.data;
        console.log(`   ${index + 1}. ${data.songname || 'Unknown Song'} - ${data.showdate || 'Unknown Date'} (ID: ${setlist.external_id})`);
        console.log(`      Venue: ${data.venuename || 'Unknown'}`);
        console.log(`      Show ID: ${data.show_id || 'N/A'}`);
        console.log(`      Position: ${data.position || 'N/A'}`);
        console.log(`      Artist: ${data.artist || 'Unknown'}`);
      });
    }

    // Step 2: Check what the Edge Function reports for setlists
    console.log('\n2️⃣ Testing setlists endpoint with Edge Function:');
    const startTime = Date.now();
    
    const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ endpoint: 'Setlists' })
    });

    const result = await response.json();
    const endTime = Date.now();
    const duration = endTime - startTime;

    console.log(`⏱️  Processing completed in ${(duration / 1000).toFixed(1)}s`);
    console.log('📊 Function Results:');
    console.log(JSON.stringify(result, null, 2));

    // Step 3: Check setlists count after function call
    console.log('\n3️⃣ Setlists count after function call:');
    const { count: afterCount } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact', head: true });

    console.log(`   Total records after: ${afterCount}`);

    // Step 4: Analyze the data structure
    console.log('\n4️⃣ Analyzing setlists data structure:');
    const { data: sampleSetlists } = await supabase
      .from('raw_data_setlists')
      .select('external_id, data')
      .not('external_id', 'like', 'test-%')
      .limit(10);

    if (sampleSetlists && sampleSetlists.length > 0) {
      console.log('\n📊 Data structure analysis:');
      const firstSetlist = sampleSetlists[0].data;
      console.log('   Available fields:', Object.keys(firstSetlist));
      console.log('   Sample record:', JSON.stringify(firstSetlist, null, 2));
      
      // Check for unique show dates
      const { data: uniqueShows } = await supabase
        .from('raw_data_setlists')
        .select('data->show_date')
        .not('external_id', 'like', 'test-%');
      
      if (uniqueShows) {
        const showDates = uniqueShows.map(s => s.show_date).filter(Boolean);
        const uniqueShowDates = [...new Set(showDates)];
        console.log(`\n📅 Unique show dates found: ${uniqueShowDates.length}`);
        console.log('   Sample dates:', uniqueShowDates.slice(0, 10));
      }
    }

    // Step 5: Compare with shows data
    console.log('\n5️⃣ Comparing with shows data:');
    const { count: showsCount } = await supabase
      .from('raw_data_shows')
      .select('*', { count: 'exact', head: true });

    console.log(`   Shows count: ${showsCount}`);
    console.log(`   Setlists count: ${afterCount}`);
    console.log(`   Ratio: ${(afterCount / showsCount * 100).toFixed(1)}%`);

    // Step 6: Check for potential issues
    console.log('\n6️⃣ Checking for potential issues:');
    
    // Check if there are any errors in the setlists data
    const { data: errorSetlists } = await supabase
      .from('raw_data_setlists')
      .select('external_id, data')
      .not('external_id', 'like', 'test-%')
      .is('data->song_name', null);

    if (errorSetlists && errorSetlists.length > 0) {
      console.log(`   ⚠️  Found ${errorSetlists.length} setlists with null song_name`);
    }

    // Check for duplicate external_ids
    const { data: duplicateCheck } = await supabase
      .from('raw_data_setlists')
      .select('external_id')
      .not('external_id', 'like', 'test-%');

    if (duplicateCheck) {
      const externalIds = duplicateCheck.map(s => s.external_id);
      const uniqueIds = [...new Set(externalIds)];
      console.log(`   📊 Total records: ${externalIds.length}`);
      console.log(`   📊 Unique external_ids: ${uniqueIds.length}`);
      if (externalIds.length !== uniqueIds.length) {
        console.log(`   ⚠️  Found ${externalIds.length - uniqueIds.length} duplicate external_ids`);
      }
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

investigateSetlists();
