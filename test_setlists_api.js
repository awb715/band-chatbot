import dotenv from 'dotenv';
import https from 'https';

dotenv.config();

// Helper function to make HTTPS requests with SSL verification disabled
function fetchWithSSLDisabled(url) {
  return new Promise((resolve, reject) => {
    const options = {
      rejectUnauthorized: false // Disable SSL verification for ElGoose API
    };
    
    https.get(url, options, (res) => {
      let data = '';
      
      console.log(`Status: ${res.statusCode}`);
      console.log(`Headers:`, res.headers);
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        console.log(`Response length: ${data.length}`);
        console.log(`First 500 characters:`, data.substring(0, 500));
        
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

async function testSetlistsAPI() {
  console.log('🔍 TESTING SETLISTS API');
  console.log('========================\n');

  const urls = [
    'https://elgoose.com/api/setlists.json',
    'https://elgoose.com/api/v2/setlists.json',
    'https://elgoose.net/api/setlists.json',
    'https://elgoose.net/api/v2/setlists.json'
  ];

  for (const url of urls) {
    console.log(`Testing: ${url}`);
    try {
      const data = await fetchWithSSLDisabled(url);
      console.log(`✅ Success! Data type: ${typeof data}`);
      if (Array.isArray(data)) {
        console.log(`   Records: ${data.length}`);
      } else if (data && typeof data === 'object') {
        console.log(`   Keys: ${Object.keys(data).join(', ')}`);
        if (data.data && Array.isArray(data.data)) {
          console.log(`   Data records: ${data.data.length}`);
        }
      }
      break; // Stop on first success
    } catch (error) {
      console.log(`❌ Failed: ${error.message}`);
    }
    console.log('');
  }
}

testSetlistsAPI();
