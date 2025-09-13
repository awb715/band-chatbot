import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !serviceRoleKey) {
  console.error('❌ Missing Supabase environment variables')
  process.exit(1)
}

// Create client with service role key (bypasses RLS)
const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function testWithServiceRole() {
  console.log('🔐 Testing with Service Role Key')
  console.log('================================')
  
  try {
    // Check current state
    console.log('\n📊 Current Songs Data Status:')
    const { data: currentSongs, error: countError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (countError) {
      console.error('❌ Failed to get current songs count:', countError)
      return
    }
    
    console.log(`📈 Total songs in database: ${currentSongs.length}`)
    
    // Test 1: Try to delete a single song (should work with service role)
    console.log('\n🧪 Test 1: Attempting to delete a single song with service role...')
    const testSongId = currentSongs[0]?.id
    if (testSongId) {
      const { error: deleteError } = await supabase
        .from('raw_data_songs')
        .delete()
        .eq('id', testSongId)
      
      if (deleteError) {
        console.log('❌ Delete failed:', deleteError.message)
      } else {
        console.log('✅ Delete succeeded - service role has full access')
      }
    } else {
      console.log('⚠️ No songs found to test with')
    }
    
    // Test 2: Try to delete multiple songs (should work with service role)
    console.log('\n🧪 Test 2: Attempting to delete multiple songs with service role...')
    const { error: bulkDeleteError } = await supabase
      .from('raw_data_songs')
      .delete()
      .in('id', currentSongs.slice(0, 2).map(song => song.id))
    
    if (bulkDeleteError) {
      console.log('❌ Bulk delete failed:', bulkDeleteError.message)
    } else {
      console.log('✅ Bulk delete succeeded - service role has full access')
    }
    
    // Test 3: Try to update songs (should work)
    console.log('\n🧪 Test 3: Attempting to update a song (should work)...')
    const { error: updateError } = await supabase
      .from('raw_data_songs')
      .update({ is_processed: true })
      .eq('id', currentSongs[2]?.id)
    
    if (updateError) {
      console.log('❌ Update failed:', updateError.message)
    } else {
      console.log('✅ Update succeeded - this is expected')
    }
    
    // Test 4: Try to insert a new song (should work)
    console.log('\n🧪 Test 4: Attempting to insert a new song (should work)...')
    const testSong = {
      external_id: 'test-service-role-song-' + Date.now(),
      data: {
        name: 'Test Service Role Song',
        slug: 'test-service-role-song',
        is_original: true
      },
      version: 1,
      is_processed: false,
      source_url: 'https://test.com'
    }
    
    const { error: insertError } = await supabase
      .from('raw_data_songs')
      .insert(testSong)
    
    if (insertError) {
      console.log('❌ Insert failed:', insertError.message)
    } else {
      console.log('✅ Insert succeeded - this is expected')
      
      // Clean up the test song
      console.log('🧹 Cleaning up test song...')
      await supabase
        .from('raw_data_songs')
        .delete()
        .eq('external_id', testSong.external_id)
    }
    
    // Final count check
    console.log('\n📊 Final Songs Data Status:')
    const { data: finalSongs, error: finalCountError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (finalCountError) {
      console.error('❌ Failed to get final songs count:', finalCountError)
    } else {
      console.log(`📈 Final songs count: ${finalSongs.length}`)
      console.log(`📉 Songs deleted: ${currentSongs.length - finalSongs.length}`)
    }
    
    // Test 5: Check what role we're using
    console.log('\n👤 Role Information:')
    const { data: roleData, error: roleError } = await supabase
      .rpc('current_user')
    
    if (roleError) {
      console.log('❌ Could not get current user:', roleError.message)
    } else {
      console.log('✅ Current user:', roleData)
    }
    
  } catch (error) {
    console.error('❌ Test failed with error:', error)
  }
}

// Run the test
testWithServiceRole()
  .then(() => {
    console.log('\n🎯 Service Role Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
