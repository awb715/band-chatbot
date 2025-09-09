/**
 * TEST API DIRECTLY
 * =================
 * 
 * This script tests the ElGoose API directly to understand the data structure
 * and see if our filtering logic is working correctly
 */

async function testElGooseAPI() {
  console.log('🔍 Testing ElGoose API directly...')
  
  try {
    // Test songs endpoint with our optimized parameters
    const url = 'https://elgoose.net/api/v2/songs.json?sort=updated_at&order=desc&limit=100'
    console.log('📡 Fetching from:', url)
    
    const response = await fetch(url)
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const data = await response.json()
    console.log('📊 API Response structure:', {
      hasError: 'error' in data,
      hasData: 'data' in data,
      dataType: Array.isArray(data.data) ? 'array' : typeof data.data,
      dataLength: Array.isArray(data.data) ? data.data.length : 'N/A'
    })
    
    if (data.data && Array.isArray(data.data)) {
      console.log('📝 Sample records:')
      data.data.slice(0, 3).forEach((record, index) => {
        console.log(`  Record ${index + 1}:`, {
          id: record.id,
          name: record.name,
          updated_at: record.updated_at,
          created_at: record.created_at,
          hasUpdatedAt: !!record.updated_at,
          hasCreatedAt: !!record.created_at
        })
      })
      
      // Check date filtering
      const now = new Date()
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
      
      console.log('\n📅 Date filtering analysis:')
      console.log('  Current time:', now.toISOString())
      console.log('  7 days ago:', sevenDaysAgo.toISOString())
      
      const recentRecords = data.data.filter(record => {
        const recordDate = record.updated_at || record.created_at
        return recordDate && new Date(recordDate) >= sevenDaysAgo
      })
      
      console.log(`  Total records: ${data.data.length}`)
      console.log(`  Recent records (last 7 days): ${recentRecords.length}`)
      
      if (recentRecords.length > 0) {
        console.log('  Most recent record:', {
          id: recentRecords[0].id,
          name: recentRecords[0].name,
          updated_at: recentRecords[0].updated_at
        })
      }
    }
    
  } catch (error) {
    console.error('❌ API test failed:', error.message)
  }
}

// Run the test
testElGooseAPI().catch(console.error)
