import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  console.error('❌ Missing Supabase environment variables')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function checkSongsAPI() {
  console.log('🔍 Checking Songs API Response')
  console.log('==============================')
  
  try {
    // Check current count
    console.log('\n📊 Current Songs Count:')
    const { data: currentSongs, error: countError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (countError) {
      console.error('❌ Failed to get current songs count:', countError)
      return
    }
    
    console.log(`📈 Current songs: ${currentSongs.length}`)
    
    // Call the songs endpoint to see what it returns
    console.log('\n🌐 Fetching songs data from API...')
    const response = await fetch('https://elgoose.net/api/v2/songs')
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const songsData = await response.json()
    console.log('📊 API Response:')
    console.log('Type:', typeof songsData)
    console.log('Is Array:', Array.isArray(songsData))
    console.log('Keys:', Object.keys(songsData))
    console.log('First few items:', JSON.stringify(songsData, null, 2).substring(0, 500))
    
    // Check if it's an object with a data property
    if (songsData && typeof songsData === 'object' && songsData.data) {
      console.log('\n📋 Found data property:')
      console.log('Data type:', typeof songsData.data)
      console.log('Data is array:', Array.isArray(songsData.data))
      console.log('Data length:', songsData.data?.length)
      
      if (Array.isArray(songsData.data)) {
        console.log('✅ Songs are in data property!')
        console.log('Sample song:', JSON.stringify(songsData.data[0], null, 2).substring(0, 300))
      }
    }
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkSongsAPI()
  .then(() => {
    console.log('\n🎯 API Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })
