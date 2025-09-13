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

async function cleanupDuplicateSongs() {
  console.log('🧹 Cleaning Up Duplicate Songs')
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
    
    // Get all songs and find duplicates manually
    console.log('\n🔍 Finding duplicates...')
    const { data: allSongs, error: allSongsError } = await supabase
      .from('raw_data_songs')
      .select('id, external_id, created_at')
      .order('created_at', { ascending: true })
    
    if (allSongsError) {
      console.error('❌ Failed to get all songs:', allSongsError)
      return
    }
    
    // Group by external_id to find duplicates
    const groupedSongs = {}
    allSongs.forEach(song => {
      if (!groupedSongs[song.external_id]) {
        groupedSongs[song.external_id] = []
      }
      groupedSongs[song.external_id].push(song)
    })
    
    const duplicates = Object.entries(groupedSongs).filter(([_, songs]) => songs.length > 1)
    console.log(`📊 Found ${duplicates.length} duplicate external_ids`)
    
    // For each duplicate, keep only the first one and delete the rest
    let deletedCount = 0
    for (const [externalId, songs] of duplicates) {
      console.log(`\n🔄 Processing duplicates for external_id: ${externalId} (${songs.length} copies)`)
      
      // Keep the first record, delete the rest
      const recordsToDelete = songs.slice(1)
      console.log(`  - Keeping first record (${songs[0].id}), deleting ${recordsToDelete.length} duplicates`)
      
      for (const record of recordsToDelete) {
        const { error: deleteError } = await supabase
          .from('raw_data_songs')
          .delete()
          .eq('id', record.id)
        
        if (deleteError) {
          console.error(`❌ Failed to delete record ${record.id}:`, deleteError)
        } else {
          deletedCount++
        }
      }
    }
    
    // Verify final count
    console.log('\n🔍 Verifying cleanup...')
    const { data: finalSongs, error: finalError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.error('❌ Failed to get final count:', finalError)
    } else {
      console.log(`📈 Final songs count: ${finalSongs.length}`)
      console.log(`🗑️ Deleted duplicates: ${deletedCount}`)
      
      if (finalSongs.length === 576) {
        console.log('✅ Songs data successfully cleaned up!')
      } else {
        console.log(`⚠️ Expected 576 songs, got ${finalSongs.length}`)
      }
    }
    
    // Show some sample data
    console.log('\n📋 Sample cleaned songs:')
    const { data: sampleSongs, error: sampleError } = await supabase
      .from('raw_data_songs')
      .select('external_id, data')
      .limit(5)
    
    if (sampleError) {
      console.log('❌ Could not get sample songs:', sampleError.message)
    } else {
      sampleSongs.forEach(song => {
        console.log(`  - ${song.external_id}: ${song.data.name}`)
      })
    }
    
  } catch (error) {
    console.error('❌ Cleanup failed:', error)
  }
}

// Run the cleanup
cleanupDuplicateSongs()
  .then(() => {
    console.log('\n🎯 Songs Cleanup Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Cleanup failed:', error)
    process.exit(1)
  })
