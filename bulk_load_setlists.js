import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import https from 'https';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY; // Use service role for bulk operations

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

// Helper function to process a single setlist record
async function processSetlistRecord(record, sourceUrl) {
  // Extract external ID - setlists use uniqueid as the primary identifier
  const externalId = record.uniqueid || record.show_id || record.song_id || null;
  
  if (!externalId) {
    console.log('⚠️  Skipping record without external ID:', record);
    return { isNew: false, isUpdated: false, error: 'No external ID' };
  }

  // Check if record already exists
  const { data: existingRecord } = await supabase
    .from('raw_data_setlists')
    .select('id, data, version')
    .eq('external_id', externalId)
    .single();

  if (existingRecord) {
    // Check if data has changed
    const dataChanged = JSON.stringify(existingRecord.data) !== JSON.stringify(record);
    
    if (dataChanged) {
      // Update existing record
      await supabase
        .from('raw_data_setlists')
        .update({
          data: record,
          version: existingRecord.version + 1,
          updated_at: new Date().toISOString()
        })
        .eq('id', existingRecord.id);
      
      return { isNew: false, isUpdated: true };
    } else {
      return { isNew: false, isUpdated: false };
    }
  } else {
    // Insert new record
    await supabase
      .from('raw_data_setlists')
      .insert({
        external_id: externalId,
        data: record,
        source_url: sourceUrl,
        is_processed: false
      });
    
    return { isNew: true, isUpdated: false };
  }
}

async function bulkLoadSetlists() {
  console.log('🚀 BULK LOADING SETLISTS DATA');
  console.log('==============================\n');

  try {
    // Step 1: Fetch data from ElGoose API
    console.log('1️⃣ Fetching data from ElGoose API...');
    const startTime = Date.now();
    
    const apiData = await fetchWithSSLDisabled('https://elgoose.net/api/v2/setlists.json?limit=10000');
    
    const fetchTime = Date.now() - startTime;
    console.log(`   ✅ Fetched in ${(fetchTime / 1000).toFixed(1)}s`);
    
    // Extract the data array
    const data = apiData.data || apiData;
    console.log(`   📊 Total records available: ${Array.isArray(data) ? data.length : 1}`);

    if (!Array.isArray(data)) {
      throw new Error('Expected array of setlists data');
    }

    // Step 2: Save raw data to local file for analysis
    console.log('\n2️⃣ Saving raw data to local file...');
    const rawDataFile = 'setlists_raw_data.json';
    fs.writeFileSync(rawDataFile, JSON.stringify(data, null, 2));
    console.log(`   ✅ Saved to ${rawDataFile}`);

    // Step 3: Analyze data structure
    console.log('\n3️⃣ Analyzing data structure...');
    const sampleRecord = data[0];
    console.log('   📋 Sample record structure:');
    console.log(JSON.stringify(sampleRecord, null, 2));
    
    // Analyze field patterns
    const fieldCounts = {};
    data.forEach(record => {
      Object.keys(record).forEach(key => {
        fieldCounts[key] = (fieldCounts[key] || 0) + 1;
      });
    });
    
    console.log('\n   📊 Field frequency analysis:');
    Object.entries(fieldCounts)
      .sort(([,a], [,b]) => b - a)
      .forEach(([field, count]) => {
        const percentage = ((count / data.length) * 100).toFixed(1);
        console.log(`     ${field}: ${count}/${data.length} (${percentage}%)`);
      });

    // Step 4: Analyze date patterns
    console.log('\n4️⃣ Analyzing date patterns...');
    const dates = data
      .map(record => record.showdate)
      .filter(Boolean)
      .sort();
    
    if (dates.length > 0) {
      console.log(`   📅 Date range: ${dates[0]} to ${dates[dates.length - 1]}`);
      console.log(`   📅 Total shows with dates: ${dates.length}`);
      
      // Group by year
      const yearCounts = {};
      dates.forEach(date => {
        const year = date.split('-')[0];
        yearCounts[year] = (yearCounts[year] || 0) + 1;
      });
      
      console.log('\n   📊 Shows by year:');
      Object.entries(yearCounts)
        .sort(([a], [b]) => a.localeCompare(b))
        .forEach(([year, count]) => {
          console.log(`     ${year}: ${count} shows`);
        });
    }

    // Step 5: Analyze artist patterns
    console.log('\n5️⃣ Analyzing artist patterns...');
    const artists = data
      .map(record => record.artist)
      .filter(Boolean);
    
    const uniqueArtists = [...new Set(artists)];
    console.log(`   🎤 Unique artists: ${uniqueArtists.length}`);
    console.log(`   🎤 Artists: ${uniqueArtists.join(', ')}`);
    
    // Count songs per artist
    const artistCounts = {};
    artists.forEach(artist => {
      artistCounts[artist] = (artistCounts[artist] || 0) + 1;
    });
    
    console.log('\n   📊 Songs per artist:');
    Object.entries(artistCounts)
      .sort(([,a], [,b]) => b - a)
      .forEach(([artist, count]) => {
        const percentage = ((count / data.length) * 100).toFixed(1);
        console.log(`     ${artist}: ${count} songs (${percentage}%)`);
      });

    // Step 6: Process records in batches
    console.log('\n6️⃣ Processing records in batches...');
    const batchSize = 100;
    let newRecords = 0;
    let updatedRecords = 0;
    let skippedRecords = 0;
    let errorRecords = 0;

    for (let i = 0; i < data.length; i += batchSize) {
      const batch = data.slice(i, i + batchSize);
      const batchNumber = Math.floor(i / batchSize) + 1;
      const totalBatches = Math.ceil(data.length / batchSize);
      
      console.log(`   📦 Processing batch ${batchNumber}/${totalBatches} (${batch.length} records)...`);
      
      for (const record of batch) {
        try {
          const result = await processSetlistRecord(record, 'https://elgoose.net/api/v2/setlists.json');
          
          if (result.isNew) newRecords++;
          else if (result.isUpdated) updatedRecords++;
          else if (result.error) errorRecords++;
          else skippedRecords++;
        } catch (error) {
          console.error(`   ❌ Error processing record:`, error.message);
          errorRecords++;
        }
      }
      
      // Small delay between batches to be nice to the database
      if (i + batchSize < data.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }

    // Step 7: Final summary
    const totalTime = Date.now() - startTime;
    console.log('\n7️⃣ BULK LOAD COMPLETE!');
    console.log('========================');
    console.log(`⏱️  Total time: ${(totalTime / 1000).toFixed(1)}s`);
    console.log(`📊 Records processed: ${data.length}`);
    console.log(`🆕 New records: ${newRecords}`);
    console.log(`🔄 Updated records: ${updatedRecords}`);
    console.log(`⏭️  Skipped records: ${skippedRecords}`);
    console.log(`❌ Error records: ${errorRecords}`);

    // Step 8: Verify final count
    console.log('\n8️⃣ Verifying final database count...');
    const { count: finalCount } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact', head: true });
    
    console.log(`   📊 Final setlists count: ${finalCount}`);

    // Step 9: Generate analysis report
    console.log('\n9️⃣ Generating analysis report...');
    const analysisReport = {
      timestamp: new Date().toISOString(),
      totalRecords: data.length,
      newRecords,
      updatedRecords,
      skippedRecords,
      errorRecords,
      processingTimeMs: totalTime,
      finalDatabaseCount: finalCount,
      dataStructure: {
        fields: Object.keys(sampleRecord),
        fieldCounts,
        dateRange: {
          start: dates[0],
          end: dates[dates.length - 1],
          totalShows: dates.length
        },
        artists: {
          unique: uniqueArtists.length,
          list: uniqueArtists,
          counts: artistCounts
        }
      }
    };

    fs.writeFileSync('setlists_analysis_report.json', JSON.stringify(analysisReport, null, 2));
    console.log('   ✅ Analysis report saved to setlists_analysis_report.json');

  } catch (error) {
    console.error('❌ Error during bulk load:', error);
  }
}

bulkLoadSetlists();
