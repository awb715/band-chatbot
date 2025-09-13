import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase environment variables')
  process.exit(1)
}

// Use service role key for Cursor operations (bypasses RLS)
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function testSecurityProtection() {
  console.log('🔐 Testing Security Protection on Songs Data')
  console.log('============================================')
  
  try {
    // First, let's see what we have
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
        console.log('✅ Delete succeeded - service role has full access (this is expected)')
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
      console.log('✅ Bulk delete succeeded - service role has full access (this is expected)')
    }
    
    // Test 3: Try to truncate table (should fail)
    console.log('\n🧪 Test 3: Attempting to truncate songs table...')
    const { error: truncateError } = await supabase
      .rpc('truncate_table', { table_name: 'raw_data_songs' })
    
    if (truncateError) {
      console.log('✅ Security working! Truncate blocked:', truncateError.message)
    } else {
      console.log('❌ SECURITY FAILURE! Truncate succeeded - this should not happen!')
    }
    
    // Test 4: Try to update songs (should work)
    console.log('\n🧪 Test 4: Attempting to update a song (should work)...')
    const { error: updateError } = await supabase
      .from('raw_data_songs')
      .update({ is_processed: true })
      .eq('id', currentSongs[0]?.id)
    
    if (updateError) {
      console.log('❌ Update failed:', updateError.message)
    } else {
      console.log('✅ Update succeeded - this is expected for data ingestion')
    }
    
    // Test 5: Try to insert a new song (should work)
    console.log('\n🧪 Test 5: Attempting to insert a new song (should work)...')
    const testSong = {
      external_id: 'test-security-song-' + Date.now(),
      data: {
        name: 'Test Security Song',
        slug: 'test-security-song',
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
      console.log('✅ Insert succeeded - this is expected for data ingestion')
      
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
      if (finalSongs.length === currentSongs.length) {
        console.log('✅ Data integrity maintained - no songs were deleted!')
      } else {
        console.log('❌ Data integrity compromised - songs were deleted!')
      }
    }
    
    // Test 6: Check audit log
    console.log('\n📋 Checking Audit Log...')
    const { data: auditLog, error: auditError } = await supabase
      .from('audit_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5)
    
    if (auditError) {
      console.log('⚠️ Could not access audit log:', auditError.message)
    } else {
      console.log('📊 Recent audit entries:')
      auditLog.forEach(entry => {
        console.log(`  - ${entry.operation} on ${entry.table_name} by ${entry.user_role} at ${entry.created_at}`)
      })
    }
    
  } catch (error) {
    console.error('❌ Test failed with error:', error)
  }
}

// Run the test
testSecurityProtection()
  .then(() => {
    console.log('\n🎯 Security Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
