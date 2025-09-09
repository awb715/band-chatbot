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

async function debugSetlistsAPI() {
  console.log('🔍 DEBUGGING SETLISTS API STRUCTURE');
  console.log('===================================\n');

  try {
    // Step 1: Check what we have in the database currently
    console.log('1️⃣ Current setlists in database:');
    const { data: currentSetlists } = await supabase
      .from('raw_data_setlists')
      .select('external_id, data')
      .not('external_id', 'like', 'test-%')
      .limit(5);

    if (currentSetlists && currentSetlists.length > 0) {
      console.log(`   Found ${currentSetlists.length} records`);
      console.log('\n📋 Sample raw data structure:');
      currentSetlists.forEach((setlist, index) => {
        console.log(`\n   Record ${index + 1} (ID: ${setlist.external_id}):`);
        console.log(JSON.stringify(setlist.data, null, 4));
      });
    }

    // Step 2: Check the API source configuration
    console.log('\n2️⃣ API Source configuration:');
    const { data: apiSource } = await supabase
      .from('api_sources')
      .select('*')
      .eq('name', 'Setlists')
      .single();

    if (apiSource) {
      console.log('   API Source:', JSON.stringify(apiSource, null, 2));
    }

    // Step 3: Try to understand the data structure better
    console.log('\n3️⃣ Analyzing data structure patterns:');
    
    // Check what fields are actually present
    const { data: allSetlists } = await supabase
      .from('raw_data_setlists')
      .select('data')
      .not('external_id', 'like', 'test-%')
      .limit(20);

    if (allSetlists && allSetlists.length > 0) {
      // Collect all unique field names
      const allFields = new Set();
      allSetlists.forEach(setlist => {
        Object.keys(setlist.data).forEach(key => allFields.add(key));
      });
      
      console.log('   Available fields:', Array.from(allFields).sort());
      
      // Check for common patterns
      const fieldCounts = {};
      allSetlists.forEach(setlist => {
        Object.keys(setlist.data).forEach(key => {
          fieldCounts[key] = (fieldCounts[key] || 0) + 1;
        });
      });
      
      console.log('\n   Field frequency:');
      Object.entries(fieldCounts)
        .sort(([,a], [,b]) => b - a)
        .forEach(([field, count]) => {
          console.log(`     ${field}: ${count}/${allSetlists.length} records`);
        });
    }

    // Step 4: Check if there are any records with actual song names
    console.log('\n4️⃣ Looking for records with actual song names:');
    const { data: songsWithNames } = await supabase
      .from('raw_data_setlists')
      .select('external_id, data')
      .not('external_id', 'like', 'test-%')
      .not('data->song_name', 'is', null)
      .limit(5);

    if (songsWithNames && songsWithNames.length > 0) {
      console.log(`   Found ${songsWithNames.length} records with song names:`);
      songsWithNames.forEach((setlist, index) => {
        console.log(`   ${index + 1}. ${setlist.data.song_name} (ID: ${setlist.external_id})`);
      });
    } else {
      console.log('   ❌ No records found with song names');
    }

    // Step 5: Check for records with show dates
    console.log('\n5️⃣ Looking for records with show dates:');
    const { data: showsWithDates } = await supabase
      .from('raw_data_setlists')
      .select('external_id, data')
      .not('external_id', 'like', 'test-%')
      .not('data->show_date', 'is', null)
      .limit(5);

    if (showsWithDates && showsWithDates.length > 0) {
      console.log(`   Found ${showsWithDates.length} records with show dates:`);
      showsWithDates.forEach((setlist, index) => {
        console.log(`   ${index + 1}. ${setlist.data.show_date} (ID: ${setlist.external_id})`);
      });
    } else {
      console.log('   ❌ No records found with show dates');
    }

    // Step 6: Check the external_id pattern
    console.log('\n6️⃣ Analyzing external_id patterns:');
    const { data: idSamples } = await supabase
      .from('raw_data_setlists')
      .select('external_id')
      .not('external_id', 'like', 'test-%')
      .limit(10);

    if (idSamples) {
      console.log('   Sample external_ids:');
      idSamples.forEach((setlist, index) => {
        console.log(`   ${index + 1}. ${setlist.external_id}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

debugSetlistsAPI();
