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

async function checkActualPolicies() {
  console.log('🔍 Checking Actual RLS Policies')
  console.log('================================')
  
  try {
    // Get a real song ID first
    const { data: songs, error: songsError } = await supabase
      .from('raw_data_songs')
      .select('id')
      .limit(1)
    
    if (songsError || !songs.length) {
      console.log('❌ Could not get songs:', songsError?.message || 'No songs found')
      return
    }
    
    const realSongId = songs[0].id
    console.log(`📊 Using real song ID: ${realSongId}`)
    
    // Test DELETE with real ID
    console.log('\n🧪 Testing DELETE with real song ID...')
    const { error: deleteError } = await supabase
      .from('raw_data_songs')
      .delete()
      .eq('id', realSongId)
    
    if (deleteError) {
      console.log('✅ DELETE blocked:', deleteError.message)
    } else {
      console.log('❌ DELETE allowed - this is the security issue!')
    }
    
    // Check current count
    const { data: countData, error: countError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (countError) {
      console.log('❌ Could not get count:', countError.message)
    } else {
      console.log(`📈 Current songs count: ${countData.length}`)
    }
    
    // Let's check what policies actually exist by querying the system tables
    console.log('\n🔍 Checking system tables for policies...')
    
    // Try to query pg_policies through a different approach
    const { data: policies, error: policiesError } = await supabase
      .rpc('exec_sql', { 
        sql: `
          SELECT 
            schemaname, 
            tablename, 
            policyname, 
            cmd, 
            roles,
            qual,
            with_check
          FROM pg_policies 
          WHERE schemaname = 'raw_data' 
          AND tablename = 'songs'
        `
      })
    
    if (policiesError) {
      console.log('❌ Could not query policies:', policiesError.message)
    } else {
      console.log('✅ Policies found:', policies.length)
      policies.forEach(policy => {
        console.log(`  - ${policy.policyname}: ${policy.cmd} for ${policy.roles}`)
        console.log(`    Qual: ${policy.qual}`)
        console.log(`    With Check: ${policy.with_check}`)
      })
    }
    
    // Check if RLS is actually enabled
    const { data: rlsStatus, error: rlsError } = await supabase
      .rpc('exec_sql', { 
        sql: `
          SELECT 
            schemaname, 
            tablename, 
            rowsecurity 
          FROM pg_tables 
          WHERE schemaname = 'raw_data' 
          AND tablename = 'songs'
        `
      })
    
    if (rlsError) {
      console.log('❌ Could not check RLS status:', rlsError.message)
    } else {
      console.log('✅ RLS Status:', rlsStatus)
    }
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkActualPolicies()
  .then(() => {
    console.log('\n🎯 Policy Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })
