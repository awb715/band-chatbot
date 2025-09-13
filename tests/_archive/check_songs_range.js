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

async function checkSongsRange() {
  console.log('🔍 Checking Songs Range and Count')
  console.log('=================================')
  
  try {
    // Get all songs and check the range
    console.log('\n📊 Current Songs Analysis:')
    const { data: allSongs, error: allSongsError } = await supabase
      .from('raw_data_songs')
      .select('external_id, data')
      .order('external_id', { ascending: true })
    
    if (allSongsError) {
      console.error('❌ Failed to get all songs:', allSongsError)
      return
    }
    
    console.log(`📈 Total songs: ${allSongs.length}`)
    
    // Check the range of external_ids
    const externalIds = allSongs.map(song => parseInt(song.external_id)).sort((a, b) => a - b)
    console.log(`📊 External ID range: ${externalIds[0]} to ${externalIds[externalIds.length - 1]}`)
    
    // Check for gaps in the sequence
    const expectedRange = []
    for (let i = 400; i <= 576; i++) {
      expectedRange.push(i)
    }
    
    const missingIds = expectedRange.filter(id => !externalIds.includes(id))
    const extraIds = externalIds.filter(id => id < 400 || id > 576)
    
    console.log(`\n🔍 Analysis:`)
    console.log(`📉 Missing IDs (400-576): ${missingIds.length} - ${missingIds.slice(0, 10).join(', ')}${missingIds.length > 10 ? '...' : ''}`)
    console.log(`📈 Extra IDs (outside 400-576): ${extraIds.length} - ${extraIds.slice(0, 10).join(', ')}${extraIds.length > 10 ? '...' : ''}`)
    
    // Show some sample songs
    console.log('\n📋 Sample songs:')
    allSongs.slice(0, 5).forEach(song => {
      console.log(`  - ${song.external_id}: ${song.data.name}`)
    })
    
    // Check if we should trim to exactly 576 songs
    if (allSongs.length > 576) {
      console.log(`\n⚠️ We have ${allSongs.length} songs but should have 576`)
      console.log('🔧 Should we trim to exactly 576 songs?')
      
      // Get the first 576 songs (by external_id order)
      const trimmedSongs = allSongs.slice(0, 576)
      console.log(`📊 If trimmed, we'd have: ${trimmedSongs.length} songs`)
      console.log(`📊 Range would be: ${trimmedSongs[0].external_id} to ${trimmedSongs[trimmedSongs.length - 1].external_id}`)
    }
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkSongsRange()
  .then(() => {
    console.log('\n🎯 Songs Range Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })
