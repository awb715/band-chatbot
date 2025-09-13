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

async function restoreMissing2Songs() {
  console.log('🔄 Restoring Missing 2 Songs')
  console.log('============================')
  
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
    
    // Get the missing songs from the API
    console.log('\n🌐 Fetching songs data from API...')
    const response = await fetch('https://elgoose.net/api/v2/songs')
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const apiResponse = await response.json()
    const songsData = apiResponse.data
    console.log(`📊 Fetched ${songsData.length} songs from API`)
    
    // Get current external_ids to see what's missing
    const currentExternalIds = new Set(currentSongs.map(song => song.external_id))
    console.log(`📊 Current external_ids: ${currentExternalIds.size}`)
    
    // Find songs that are missing
    const missingSongs = songsData.filter(song => !currentExternalIds.has(song.id.toString()))
    console.log(`📊 Missing songs found: ${missingSongs.length}`)
    
    if (missingSongs.length === 0) {
      console.log('✅ No missing songs found!')
      return
    }
    
    // Insert the missing songs
    console.log('\n💾 Inserting missing songs...')
    const insertData = missingSongs.map(song => ({
      external_id: song.id.toString(),
      data: song,
      version: 1,
      is_processed: false,
      source_url: 'https://elgoose.net/api/v2/songs'
    }))
    
    const { error: insertError } = await supabase
      .from('raw_data_songs')
      .insert(insertData)
    
    if (insertError) {
      console.error('❌ Failed to insert missing songs:', insertError.message)
      return
    }
    
    console.log(`✅ Successfully inserted ${insertData.length} missing songs`)
    
    // Verify final count
    console.log('\n🔍 Verifying restoration...')
    const { data: finalSongs, error: finalError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.error('❌ Failed to get final count:', finalError)
    } else {
      console.log(`📈 Final songs count: ${finalSongs.length}`)
      
      if (finalSongs.length === 576) {
        console.log('✅ Songs data successfully restored to 576!')
      } else {
        console.log(`⚠️ Expected 576 songs, got ${finalSongs.length}`)
      }
    }
    
    // Show some sample data
    console.log('\n📋 Sample restored songs:')
    const { data: sampleSongs, error: sampleError } = await supabase
      .from('raw_data_songs')
      .select('external_id, data')
      .order('external_id', { ascending: true })
      .limit(5)
    
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
restoreMissing2Songs()
  .then(() => {
    console.log('\n🎯 Missing Songs Restoration Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Restoration failed:', error)
    process.exit(1)
  })
