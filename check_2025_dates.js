import fs from 'fs';

async function check2025Dates() {
  console.log('🔍 CHECKING FOR 2025 DATES IN SETLISTS DATA');
  console.log('==========================================\n');

  try {
    // Read the raw data file
    const rawData = JSON.parse(fs.readFileSync('setlists_raw_data.json', 'utf8'));
    console.log(`📊 Total records: ${rawData.length}`);

    // Get all unique years
    const years = [...new Set(rawData.map(record => record.showdate?.split('-')[0]).filter(Boolean))].sort();
    console.log('📅 Years found in data:', years);

    // Check for 2025 specifically
    const records2025 = rawData.filter(record => record.showdate && record.showdate.startsWith('2025'));
    console.log(`\n📊 Records with 2025 dates: ${records2025.length}`);

    if (records2025.length > 0) {
      console.log('\n📋 Sample 2025 records:');
      records2025.slice(0, 5).forEach((record, index) => {
        console.log(`   ${index + 1}. ${record.showdate} - ${record.venuename} - ${record.artist} - ${record.songname}`);
      });
      
      // Check date range for 2025
      const dates2025 = records2025.map(r => r.showdate).sort();
      console.log(`\n📅 2025 date range: ${dates2025[0]} to ${dates2025[dates2025.length - 1]}`);
    } else {
      console.log('❌ No 2025 dates found in the data');
    }

    // Check the most recent dates
    const allDates = rawData.map(record => record.showdate).filter(Boolean).sort();
    console.log(`\n📅 Overall date range: ${allDates[0]} to ${allDates[allDates.length - 1]}`);
    console.log(`📅 Most recent 10 dates:`, allDates.slice(-10));

    // Check for any future dates (beyond 2022)
    const futureRecords = rawData.filter(record => {
      if (!record.showdate) return false;
      const year = parseInt(record.showdate.split('-')[0]);
      return year > 2022;
    });
    
    console.log(`\n🔮 Records with future dates (>2022): ${futureRecords.length}`);
    if (futureRecords.length > 0) {
      const futureYears = [...new Set(futureRecords.map(r => r.showdate.split('-')[0]))].sort();
      console.log(`📅 Future years found:`, futureYears);
    }

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

check2025Dates();
