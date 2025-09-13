import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const supabaseKey = process.env.SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase environment variables')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseKey)

async function testRLSDirectly() {
  console.log('🔍 Testing RLS Directly')
  console.log('=======================')
  
  try {
    // First, let's try to understand what's happening
    console.log('\n📊 Current state:')
    const { data: songs, error: songsError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (songsError) {
      console.log('❌ Could not get songs:', songsError.message)
      return
    }
    
    console.log(`📈 Total songs: ${songs.length}`)
    
    // Test if we can even see the data
    console.log('\n🧪 Test 1: Can we see the data?')
    const { data: sampleSongs, error: sampleError } = await supabase
      .from('raw_data_songs')
      .select('id, external_id')
      .limit(3)
    
    if (sampleError) {
      console.log('❌ Cannot see data:', sampleError.message)
    } else {
      console.log('✅ Can see data:', sampleSongs.length, 'songs')
      sampleSongs.forEach(song => {
        console.log(`  - ${song.id}: ${song.external_id}`)
      })
    }
    
    // Test if RLS is actually enabled by trying to access a non-existent table
    console.log('\n🧪 Test 2: Testing RLS with non-existent table...')
    const { data: fakeData, error: fakeError } = await supabase
      .from('raw_data_nonexistent')
      .select('*')
    
    if (fakeError) {
      console.log('✅ RLS working - cannot access non-existent table:', fakeError.message)
    } else {
      console.log('❌ RLS not working - accessed non-existent table')
    }
    
    // Test if we can insert data (should work)
    console.log('\n🧪 Test 3: Testing INSERT (should work)...')
    const testSong = {
      external_id: 'test-rls-' + Date.now(),
      data: { name: 'Test RLS Song' },
      version: 1,
      is_processed: false,
      source_url: 'https://test.com' // Add required field
    }
    
    const { data: insertData, error: insertError } = await supabase
      .from('raw_data_songs')
      .insert(testSong)
      .select()
    
    if (insertError) {
      console.log('❌ INSERT failed:', insertError.message)
    } else {
      console.log('✅ INSERT succeeded:', insertData.length, 'records')
      
      // Now try to delete the test song
      console.log('\n🧪 Test 4: Testing DELETE on test song...')
      const { error: deleteError } = await supabase
        .from('raw_data_songs')
        .delete()
        .eq('external_id', testSong.external_id)
      
      if (deleteError) {
        console.log('✅ DELETE blocked:', deleteError.message)
      } else {
        console.log('❌ DELETE allowed - this is the problem!')
      }
    }
    
    // Check if there's a way to bypass RLS
    console.log('\n🧪 Test 5: Testing different DELETE approaches...')
    
    // Try with a real song ID
    if (songs.length > 0) {
      const realSongId = songs[0].id
      console.log(`Testing DELETE with real song ID: ${realSongId}`)
      
      const { error: realDeleteError } = await supabase
        .from('raw_data_songs')
        .delete()
        .eq('id', realSongId)
      
      if (realDeleteError) {
        console.log('✅ DELETE blocked:', realDeleteError.message)
      } else {
        console.log('❌ DELETE allowed - RLS is not working!')
      }
    }
    
    // Final count
    const { data: finalSongs, error: finalError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.log('❌ Could not get final count:', finalError.message)
    } else {
      console.log(`📈 Final songs count: ${finalSongs.length}`)
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error)
  }
}

// Run the test
testRLSDirectly()
  .then(() => {
    console.log('\n🎯 RLS Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
