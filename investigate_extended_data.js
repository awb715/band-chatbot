import https from 'https';

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

async function investigateExtendedData() {
  console.log('🔍 INVESTIGATING EXTENDED DATA WITH HIGHER LIMIT');
  console.log('================================================\n');

  try {
    // Fetch with higher limit
    console.log('1️⃣ Fetching data with limit=5000...');
    const apiData = await fetchWithSSLDisabled('https://elgoose.net/api/v2/setlists.json?limit=5000');
    
    if (apiData && apiData.data) {
      const records = apiData.data;
      console.log(`   📊 Total records: ${records.length}`);
      
      // Analyze date range
      const dates = records
        .map(record => record.showdate)
        .filter(Boolean)
        .sort();
      
      if (dates.length > 0) {
        console.log(`   📅 Date range: ${dates[0]} to ${dates[dates.length - 1]}`);
      }

      // Check for 2025 dates
      const records2025 = records.filter(record => 
        record.showdate && record.showdate.startsWith('2025')
      );
      console.log(`   📊 Records with 2025 dates: ${records2025.length}`);

      if (records2025.length > 0) {
        console.log('\n   🎉 FOUND 2025 DATA!');
        console.log('   📋 Sample 2025 records:');
        records2025.slice(0, 5).forEach((record, index) => {
          console.log(`     ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
        });
      }

      // Check for any dates beyond 2022
      const futureRecords = records.filter(record => {
        if (!record.showdate) return false;
        const year = parseInt(record.showdate.split('-')[0]);
        return year > 2022;
      });
      
      console.log(`   🔮 Records with dates >2022: ${futureRecords.length}`);
      
      if (futureRecords.length > 0) {
        const futureYears = [...new Set(futureRecords.map(r => r.showdate.split('-')[0]))].sort();
        console.log(`   📅 Future years found: ${futureYears.join(', ')}`);
        
        // Show sample records from each future year
        futureYears.forEach(year => {
          const yearRecords = futureRecords.filter(r => r.showdate.startsWith(year));
          console.log(`\n   📋 Sample ${year} records:`);
          yearRecords.slice(0, 3).forEach((record, index) => {
            console.log(`     ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
          });
        });
      }

      // Check what we missed in our original pull
      const recordsAfter2022 = records.filter(record => 
        record.showdate && record.showdate > '2022-05-21'
      );
      
      console.log(`\n   📊 Records after 2022-05-21: ${recordsAfter2022.length}`);
      
      if (recordsAfter2022.length > 0) {
        console.log('   📋 Sample records after 2022-05-21:');
        recordsAfter2022.slice(0, 5).forEach((record, index) => {
          console.log(`     ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
        });
      }

      // Try even higher limits
      console.log('\n2️⃣ Trying even higher limits...');
      const higherLimits = [10000, 20000, 50000];
      
      for (const limit of higherLimits) {
        try {
          console.log(`   🔗 Testing limit=${limit}...`);
          const highLimitData = await fetchWithSSLDisabled(`https://elgoose.net/api/v2/setlists.json?limit=${limit}`);
          
          if (highLimitData && highLimitData.data) {
            const highLimitRecords = highLimitData.data;
            console.log(`     📊 Records with limit=${limit}: ${highLimitRecords.length}`);
            
            const highLimitDates = highLimitRecords
              .map(record => record.showdate)
              .filter(Boolean)
              .sort();
            
            if (highLimitDates.length > 0) {
              console.log(`     📅 Date range: ${highLimitDates[0]} to ${highLimitDates[highLimitDates.length - 1]}`);
            }
            
            // Check for 2025 in this dataset
            const highLimit2025 = highLimitRecords.filter(record => 
              record.showdate && record.showdate.startsWith('2025')
            );
            
            if (highLimit2025.length > 0) {
              console.log(`     🎉 FOUND 2025 DATA with limit=${limit}! ${highLimit2025.length} records`);
            }
          }
        } catch (error) {
          console.log(`     ❌ Error with limit=${limit}: ${error.message}`);
        }
      }

    } else {
      console.log('   ❌ Failed to fetch extended data');
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

investigateExtendedData();
