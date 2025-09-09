import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import https from 'https';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Helper function to make HTTPS requests with SSL verification disabled
function fetchWithSSLDisabled(url) {
  return new Promise((resolve, reject) => {
    const options = {
      rejectUnauthorized: false // Disable SSL verification for ElGoose API
    };
    
    https.get(url, options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve(jsonData);
        } catch (error) {
          reject(new Error(`Failed to parse JSON: ${error.message}`));
        }
      });
    }).on('error', (error) => {
      reject(error);
    });
  });
}

async function investigateAPIvsStored() {
  console.log('🔍 INVESTIGATING API vs STORED DATA DISCREPANCY');
  console.log('==============================================\n');

  try {
    // Step 1: Check what's currently in our database
    console.log('1️⃣ Current database setlists:');
    const { count: dbCount } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact', head: true });
    
    console.log(`   📊 Total records in database: ${dbCount}`);

    // Get date range from database
    const { data: dbDates } = await supabase
      .from('raw_data_setlists')
      .select('data->showdate')
      .not('external_id', 'like', 'test-%')
      .not('data->showdate', 'is', null)
      .order('data->showdate', { ascending: false })
      .limit(10);

    if (dbDates && dbDates.length > 0) {
      const dates = dbDates.map(r => r.showdate).filter(Boolean);
      console.log(`   📅 Most recent dates in DB: ${dates.slice(0, 5).join(', ')}`);
    }

    // Step 2: Fetch fresh data from API
    console.log('\n2️⃣ Fetching fresh data from API...');
    const apiData = await fetchWithSSLDisabled('https://elgoose.net/api/v2/setlists.json');
    
    if (apiData && apiData.data) {
      const freshData = apiData.data;
      console.log(`   📊 Total records from API: ${freshData.length}`);
      
      // Analyze date range from API
      const apiDates = freshData
        .map(record => record.showdate)
        .filter(Boolean)
        .sort();
      
      if (apiDates.length > 0) {
        console.log(`   📅 API date range: ${apiDates[0]} to ${apiDates[apiDates.length - 1]}`);
        console.log(`   📅 Most recent API dates: ${apiDates.slice(-5).join(', ')}`);
      }

      // Check for 2025 dates in API data
      const records2025 = freshData.filter(record => 
        record.showdate && record.showdate.startsWith('2025')
      );
      console.log(`   📊 Records with 2025 dates in API: ${records2025.length}`);

      if (records2025.length > 0) {
        console.log('\n   📋 Sample 2025 records from API:');
        records2025.slice(0, 3).forEach((record, index) => {
          console.log(`     ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
        });
      }

      // Check for any dates beyond 2022
      const futureRecords = freshData.filter(record => {
        if (!record.showdate) return false;
        const year = parseInt(record.showdate.split('-')[0]);
        return year > 2022;
      });
      
      console.log(`   🔮 Records with dates >2022 in API: ${futureRecords.length}`);
      
      if (futureRecords.length > 0) {
        const futureYears = [...new Set(futureRecords.map(r => r.showdate.split('-')[0]))].sort();
        console.log(`   📅 Future years in API: ${futureYears.join(', ')}`);
      }

      // Step 3: Compare counts
      console.log('\n3️⃣ Data comparison:');
      console.log(`   📊 API records: ${freshData.length}`);
      console.log(`   📊 DB records: ${dbCount}`);
      console.log(`   📊 Difference: ${freshData.length - dbCount}`);

      // Step 4: Check if we missed recent data
      if (freshData.length > dbCount) {
        console.log('\n4️⃣ Missing data analysis:');
        
        // Get the most recent records from API that might be missing
        const recentApiRecords = freshData
          .filter(record => record.showdate && record.showdate >= '2022-01-01')
          .sort((a, b) => new Date(b.showdate) - new Date(a.showdate))
          .slice(0, 10);
        
        console.log('   📋 Recent API records (2022+):');
        recentApiRecords.forEach((record, index) => {
          console.log(`     ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
        });

        // Check if these records exist in our database
        console.log('\n   🔍 Checking if recent records exist in DB...');
        for (const record of recentApiRecords.slice(0, 3)) {
          const { data: existing } = await supabase
            .from('raw_data_setlists')
            .select('external_id')
            .eq('external_id', record.uniqueid)
            .single();
          
          console.log(`     ${record.uniqueid} (${record.showdate}): ${existing ? 'EXISTS' : 'MISSING'}`);
        }
      }

    } else {
      console.log('   ❌ Failed to fetch API data');
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

investigateAPIvsStored();
