/**
 * TEST API SIMPLE
 * ===============
 * 
 * Test the ElGoose API without sorting parameters to see if that's causing issues
 */

async function testElGooseAPISimple() {
  console.log('🔍 Testing ElGoose API (simple)...')
  
  try {
    // Test songs endpoint without sorting
    const url = 'https://elgoose.net/api/v2/songs.json?limit=10'
    console.log('📡 Fetching from:', url)
    
    const response = await fetch(url)
    
    console.log('📡 Response status:', response.status)
    console.log('📡 Response headers:', Object.fromEntries(response.headers.entries()))
    
    const text = await response.text()
    console.log('📊 Response text (first 200 chars):', text.substring(0, 200))
    
    if (response.ok) {
      try {
        const data = JSON.parse(text)
        console.log('✅ JSON parsed successfully')
        console.log('📊 Data structure:', {
          hasError: 'error' in data,
          hasData: 'data' in data,
          dataType: Array.isArray(data.data) ? 'array' : typeof data.data,
          dataLength: Array.isArray(data.data) ? data.data.length : 'N/A'
        })
        
        if (data.data && Array.isArray(data.data)) {
          console.log('📝 Sample record:', {
            id: data.data[0].id,
            name: data.data[0].name,
            updated_at: data.data[0].updated_at,
            created_at: data.data[0].created_at
          })
        }
      } catch (parseError) {
        console.error('❌ JSON parse error:', parseError.message)
      }
    }
    
  } catch (error) {
    console.error('❌ API test failed:', error.message)
  }
}

// Run the test
testElGooseAPISimple().catch(console.error)
