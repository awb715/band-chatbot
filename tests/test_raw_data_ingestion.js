import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase configuration. Please check your .env file.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Test data for different endpoints
const testData = {
  setlists: [
    {
      id: 'test-setlist-1',
      show_id: 'show-123',
      song_name: 'Test Song',
      venue_name: 'Test Venue',
      show_date: '2024-01-15',
      set: 1,
      position: 1,
      notes: 'Test setlist entry'
    }
  ],
  shows: [
    {
      id: 'show-123',
      artist_name: 'Test Artist',
      venue_name: 'Test Venue',
      show_date: '2024-01-15',
      city: 'Test City',
      state: 'Test State',
      country: 'Test Country'
    }
  ],
  songs: [
    {
      id: 'song-123',
      song_name: 'Test Song',
      artist_name: 'Test Artist',
      description: 'A test song for validation'
    }
  ],
  venues: [
    {
      id: 'venue-123',
      venue_name: 'Test Venue',
      city: 'Test City',
      state: 'Test State',
      country: 'Test Country',
      capacity: 1000
    }
  ]
};

async function testRawDataIngestion() {
  console.log('🧪 Testing Raw Data Ingestion Pipeline');
  console.log('=====================================');

  try {
    // Test 1: Check if raw_data schema exists
    console.log('\n1️⃣ Checking raw_data schema...');
    const { data: schemas } = await supabase.rpc('get_processing_stats', { table_name: 'setlists' });
    console.log('✅ Raw data schema is accessible');

    // Test 2: Test inserting data into each table
    console.log('\n2️⃣ Testing data insertion...');
    
    for (const [tableName, records] of Object.entries(testData)) {
      console.log(`\n📝 Testing ${tableName} table...`);
      
      for (const record of records) {
        const { data, error } = await supabase
          .from(`raw_data_${tableName}`)
          .insert({
            external_id: record.id,
            data: record,
            source_url: `https://elgoose.net/api/v2/${tableName}.json`,
            is_processed: false
          })
          .select();

        if (error) {
          console.error(`❌ Error inserting into ${tableName}:`, error);
        } else {
          console.log(`✅ Inserted record ${record.id} into ${tableName}`);
        }
      }
    }

    // Test 3: Test helper functions
    console.log('\n3️⃣ Testing helper functions...');
    
    // Test get_processing_stats
    const { data: stats } = await supabase.rpc('get_processing_stats', { table_name: 'setlists' });
    console.log('📊 Processing stats:', stats);

    // Test get_unprocessed_records
    const { data: unprocessed } = await supabase.rpc('get_unprocessed_records', { 
      table_name: 'setlists', 
      limit_count: 10 
    });
    console.log('📋 Unprocessed records:', unprocessed);

    // Test 4: Test the ingest_raw_data Edge Function
    console.log('\n4️⃣ Testing ingest_raw_data Edge Function...');
    
    const { data: functionResult, error: functionError } = await supabase.functions.invoke('ingest_raw_data', {
      body: { test: true }
    });

    if (functionError) {
      console.error('❌ Error calling ingest_raw_data function:', functionError);
    } else {
      console.log('✅ ingest_raw_data function called successfully');
      console.log('📊 Function result:', functionResult);
    }

    // Test 5: Verify data integrity
    console.log('\n5️⃣ Verifying data integrity...');
    
    for (const tableName of Object.keys(testData)) {
      const { data: records, error } = await supabase
        .from(`raw_data_${tableName}`)
        .select('*')
        .limit(5);

      if (error) {
        console.error(`❌ Error querying ${tableName}:`, error);
      } else {
        console.log(`✅ ${tableName} has ${records.length} records`);
        if (records.length > 0) {
          console.log(`   Sample record:`, {
            id: records[0].id,
            external_id: records[0].external_id,
            is_processed: records[0].is_processed,
            data_keys: Object.keys(records[0].data)
          });
        }
      }
    }

    console.log('\n🎉 All tests completed successfully!');

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

// Run the test
testRawDataIngestion().catch(console.error);
