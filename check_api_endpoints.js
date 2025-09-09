import https from 'https';

// Helper function to make HTTPS requests with SSL verification disabled
function fetchWithSSLDisabled(url) {
  return new Promise((resolve, reject) => {
    const options = {
      rejectUnauthorized: false // Disable SSL verification for ElGoose API
    };
    
    https.get(url, options, (res) => {
      let data = '';
      
      console.log(`Status: ${res.statusCode}`);
      console.log(`Content-Type: ${res.headers['content-type']}`);
      console.log(`Content-Length: ${res.headers['content-length']}`);
      
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

async function checkAPIEndpoints() {
  console.log('🔍 CHECKING DIFFERENT API ENDPOINTS');
  console.log('===================================\n');

  const endpoints = [
    'https://elgoose.net/api/v2/setlists.json',
    'https://elgoose.net/api/v2/setlists.json?sort=showdate&order=desc',
    'https://elgoose.net/api/v2/setlists.json?limit=5000',
    'https://elgoose.net/api/v2/setlists.json?year=2025',
    'https://elgoose.net/api/v2/setlists.json?showdate=2025',
    'https://elgoose.net/api/setlists.json',
    'https://elgoose.com/api/v2/setlists.json',
    'https://elgoose.com/api/setlists.json'
  ];

  for (const url of endpoints) {
    console.log(`\n🔗 Testing: ${url}`);
    try {
      const data = await fetchWithSSLDisabled(url);
      
      if (data && data.data && Array.isArray(data.data)) {
        const records = data.data;
        console.log(`   ✅ Success! Records: ${records.length}`);
        
        // Check for 2025 dates
        const records2025 = records.filter(record => 
          record.showdate && record.showdate.startsWith('2025')
        );
        
        if (records2025.length > 0) {
          console.log(`   🎉 FOUND 2025 DATA! ${records2025.length} records`);
          console.log(`   📋 Sample 2025 records:`);
          records2025.slice(0, 3).forEach((record, index) => {
            console.log(`     ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
          });
        } else {
          // Check date range
          const dates = records
            .map(record => record.showdate)
            .filter(Boolean)
            .sort();
          
          if (dates.length > 0) {
            console.log(`   📅 Date range: ${dates[0]} to ${dates[dates.length - 1]}`);
          }
        }
      } else {
        console.log(`   ❌ Unexpected data format`);
      }
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
    }
  }
}

checkAPIEndpoints();
