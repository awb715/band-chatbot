import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  console.error('❌ Missing Supabase environment variables')
  process.exit(1)
}

// Use service role key for restoration
const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function restoreSongsData() {
  console.log('🔄 Restoring Songs Data')
  console.log('=======================')
  
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
    console.log(`📉 Missing songs: ${576 - currentSongs.length}`)
    
    if (currentSongs.length >= 576) {
      console.log('✅ Songs data is already complete!')
      return
    }
    
    // Call the songs endpoint to get fresh data
    console.log('\n🌐 Fetching fresh songs data from API...')
    const response = await fetch('https://elgoose.net/api/v2/songs')
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const apiResponse = await response.json()
    const songsData = apiResponse.data
    console.log(`📊 Fetched ${songsData.length} songs from API`)
    
    // Process and insert songs
    console.log('\n💾 Processing and inserting songs...')
    const insertData = songsData.map(song => ({
      external_id: song.id.toString(),
      data: song,
      version: 1,
      is_processed: false,
      source_url: 'https://elgoose.net/api/v2/songs'
    }))
    
    // Insert songs in batches to avoid timeout
    const batchSize = 100
    let insertedCount = 0
    
    for (let i = 0; i < insertData.length; i += batchSize) {
      const batch = insertData.slice(i, i + batchSize)
      
      const { error: insertError } = await supabase
        .from('raw_data_songs')
        .insert(batch)
      
      if (insertError) {
        console.error(`❌ Failed to insert batch ${Math.floor(i/batchSize) + 1}:`, insertError.message)
        continue
      }
      
      insertedCount += batch.length
      console.log(`✅ Inserted batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(insertData.length/batchSize)} (${insertedCount}/${insertData.length} songs)`)
    }
    
    // Verify final count
    console.log('\n🔍 Verifying restoration...')
    const { data: finalSongs, error: finalError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.error('❌ Failed to get final count:', finalError)
    } else {
      console.log(`📈 Final songs count: ${finalSongs.length}`)
      
      if (finalSongs.length >= 576) {
        console.log('✅ Songs data successfully restored!')
      } else {
        console.log(`⚠️ Still missing ${576 - finalSongs.length} songs`)
      }
    }
    
    // Show some sample data
    console.log('\n📋 Sample restored songs:')
    const { data: sampleSongs, error: sampleError } = await supabase
      .from('raw_data_songs')
      .select('external_id, data')
      .limit(3)
    
    if (sampleError) {
      console.log('❌ Could not get sample songs:', sampleError.message)
    } else {
      sampleSongs.forEach(song => {
        console.log(`  - ${song.external_id}: ${song.data.name}`)
      })
    }
    
  } catch (error) {
    console.error('❌ Restoration failed:', error)
  }
}

// Run the restoration
restoreSongsData()
  .then(() => {
    console.log('\n🎯 Songs Restoration Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Restoration failed:', error)
    process.exit(1)
  })
