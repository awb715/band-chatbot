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

async function testEndpoint(endpointName) {
  console.log(`\n🎯 TESTING ${endpointName.toUpperCase()} ENDPOINT`);
  console.log('='.repeat(50));

  try {
    // Check current count before
    const { count: beforeCount } = await supabase
      .from(`raw_data_${endpointName.toLowerCase()}`)
      .select('*', { count: 'exact', head: true });

    console.log(`📊 Current ${endpointName} in database: ${beforeCount}`);

    // Call the Edge Function for this specific endpoint
    console.log(`🚀 Calling Edge Function for ${endpointName}...`);
    const startTime = Date.now();
    
    const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ endpoint: endpointName })
    });

    const result = await response.json();
    const endTime = Date.now();
    const duration = endTime - startTime;

    console.log(`⏱️  Processing completed in ${(duration / 1000).toFixed(1)}s`);
    
    if (result.success) {
      const endpointResult = result.results[0];
      console.log(`✅ Success!`);
      console.log(`   📥 Total fetched: ${endpointResult.total_fetched}`);
      console.log(`   🆕 New records: ${endpointResult.new_records}`);
      console.log(`   🔄 Updated records: ${endpointResult.updated_records}`);
      console.log(`   ⚠️  Errors: ${endpointResult.errors.length}`);
      console.log(`   ⏱️  Processing time: ${endpointResult.processing_time_ms}ms`);

      // Check count after
      const { count: afterCount } = await supabase
        .from(`raw_data_${endpointName.toLowerCase()}`)
        .select('*', { count: 'exact', head: true });

      console.log(`📈 ${endpointName} count after: ${afterCount}`);
      console.log(`📈 New ${endpointName} added: ${afterCount - beforeCount}`);

      // Show sample data
      const { data: sampleData } = await supabase
        .from(`raw_data_${endpointName.toLowerCase()}`)
        .select('external_id, data')
        .not('external_id', 'like', 'test-%')
        .order('created_at', { ascending: false })
        .limit(3);

      if (sampleData && sampleData.length > 0) {
        console.log(`\n📋 Sample ${endpointName}:`);
        sampleData.forEach((item, index) => {
          const data = item.data;
          if (endpointName === 'Shows') {
            console.log(`   ${index + 1}. ${data.venue_name} - ${data.show_date} (ID: ${item.external_id})`);
          } else if (endpointName === 'Venues') {
            console.log(`   ${index + 1}. ${data.venue_name} - ${data.city}, ${data.state} (ID: ${item.external_id})`);
          } else if (endpointName === 'Setlists') {
            console.log(`   ${index + 1}. ${data.song_name} - ${data.show_date} (ID: ${item.external_id})`);
          } else {
            console.log(`   ${index + 1}. ${data.name || data.title || 'Unknown'} (ID: ${item.external_id})`);
          }
        });
      }
    } else {
      console.log(`❌ Failed: ${result.error || 'Unknown error'}`);
    }

  } catch (error) {
    console.error(`❌ Error testing ${endpointName}:`, error.message);
  }
}

async function testAllEndpoints() {
  console.log('🧪 TESTING ALL EELGOOSE ENDPOINTS');
  console.log('==================================\n');

  const endpoints = ['Shows', 'Venues', 'Setlists', 'Jamcharts', 'Metadata', 'Links', 'Uploads', 'Appearances', 'Latest'];
  
  for (const endpoint of endpoints) {
    await testEndpoint(endpoint);
    
    // Add a small delay between endpoints to be nice to the API
    console.log('\n⏳ Waiting 2 seconds before next endpoint...');
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  console.log('\n🎉 ALL ENDPOINT TESTS COMPLETED!');
  
  // Show final summary
  console.log('\n📊 FINAL DATABASE SUMMARY:');
  console.log('==========================');
  
  const tables = ['songs', 'shows', 'venues', 'setlists', 'jamcharts', 'metadata', 'links', 'uploads', 'appearances', 'latest'];
  
  for (const table of tables) {
    const { count } = await supabase
      .from(`raw_data_${table}`)
      .select('*', { count: 'exact', head: true });
    
    console.log(`   ${table.toUpperCase()}: ${count} records`);
  }
}

testAllEndpoints();
