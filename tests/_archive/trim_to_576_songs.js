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

async function trimTo576Songs() {
  console.log('✂️ Trimming Songs to Exactly 576')
  console.log('=================================')
  
  try {
    // Get all songs ordered by external_id
    console.log('\n📊 Getting all songs...')
    const { data: allSongs, error: allSongsError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .order('external_id', { ascending: true })
    
    if (allSongsError) {
      console.error('❌ Failed to get all songs:', allSongsError)
      return
    }
    
    console.log(`📈 Current songs: ${allSongs.length}`)
    
    // Take only the first 576 songs
    const trimmedSongs = allSongs.slice(0, 576)
    console.log(`✂️ Trimming to: ${trimmedSongs.length} songs`)
    
    // Get the IDs of songs to delete (everything after the first 576)
    const songsToDelete = allSongs.slice(576)
    console.log(`🗑️ Songs to delete: ${songsToDelete.length}`)
    
    if (songsToDelete.length === 0) {
      console.log('✅ Already have exactly 576 songs!')
      return
    }
    
    // Delete the extra songs
    console.log('\n🗑️ Deleting extra songs...')
    let deletedCount = 0
    
    for (const song of songsToDelete) {
      const { error: deleteError } = await supabase
        .from('raw_data_songs')
        .delete()
        .eq('id', song.id)
      
      if (deleteError) {
        console.error(`❌ Failed to delete song ${song.external_id}:`, deleteError.message)
      } else {
        deletedCount++
        if (deletedCount % 50 === 0) {
          console.log(`  - Deleted ${deletedCount}/${songsToDelete.length} songs...`)
        }
      }
    }
    
    console.log(`✅ Deleted ${deletedCount} extra songs`)
    
    // Verify final count
    console.log('\n🔍 Verifying final count...')
    const { data: finalSongs, error: finalError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.error('❌ Failed to get final count:', finalError)
    } else {
      console.log(`📈 Final songs count: ${finalSongs.length}`)
      
      if (finalSongs.length === 576) {
        console.log('✅ Successfully trimmed to exactly 576 songs!')
      } else {
        console.log(`⚠️ Expected 576 songs, got ${finalSongs.length}`)
      }
    }
    
    // Show the range of remaining songs
    if (finalSongs.length > 0) {
      const externalIds = finalSongs.map(song => parseInt(song.external_id)).sort((a, b) => a - b)
      console.log(`📊 External ID range: ${externalIds[0]} to ${externalIds[externalIds.length - 1]}`)
    }
    
    // Show some sample songs
    console.log('\n📋 Sample trimmed songs:')
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
    console.error('❌ Trim failed:', error)
  }
}

// Run the trim
trimTo576Songs()
  .then(() => {
    console.log('\n🎯 Songs Trim Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Trim failed:', error)
    process.exit(1)
  })
