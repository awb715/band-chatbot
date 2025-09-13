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

async function debugRLSPolicies() {
  console.log('🔍 Debugging RLS Policies')
  console.log('=========================')
  
  try {
    // Check current user role
    console.log('\n👤 Current User Role:')
    const { data: roleData, error: roleError } = await supabase
      .rpc('current_user_role')
    
    if (roleError) {
      console.log('❌ Could not get current role:', roleError.message)
    } else {
      console.log('✅ Current role:', roleData)
    }
    
    // Check if RLS is enabled
    console.log('\n🔒 RLS Status:')
    const { data: rlsData, error: rlsError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .limit(1)
    
    if (rlsError) {
      console.log('❌ RLS Error:', rlsError.message)
    } else {
      console.log('✅ RLS allows access:', rlsData.length > 0)
    }
    
    // Check table policies
    console.log('\n📋 Table Policies:')
    const { data: policiesData, error: policiesError } = await supabase
      .rpc('get_table_policies', { table_name: 'raw_data_songs' })
    
    if (policiesError) {
      console.log('❌ Could not get policies:', policiesError.message)
    } else {
      console.log('✅ Policies:', policiesData)
    }
    
    // Try to understand why DELETE works
    console.log('\n🧪 Testing DELETE with different approaches:')
    
    // Test 1: Direct DELETE
    console.log('Test 1: Direct DELETE...')
    const { error: deleteError } = await supabase
      .from('raw_data_songs')
      .delete()
      .eq('id', 'non-existent-id')
    
    if (deleteError) {
      console.log('✅ DELETE blocked:', deleteError.message)
    } else {
      console.log('❌ DELETE allowed (this is the problem!)')
    }
    
    // Test 2: Check if we can see the policies in the database
    console.log('\n🔍 Checking database policies directly...')
    const { data: dbPolicies, error: dbError } = await supabase
      .from('pg_policies')
      .select('*')
      .eq('tablename', 'songs')
      .eq('schemaname', 'raw_data')
    
    if (dbError) {
      console.log('❌ Could not query pg_policies:', dbError.message)
    } else {
      console.log('✅ Database policies found:', dbPolicies.length)
      dbPolicies.forEach(policy => {
        console.log(`  - ${policy.policyname}: ${policy.cmd} for ${policy.roles}`)
      })
    }
    
  } catch (error) {
    console.error('❌ Debug failed:', error)
  }
}

// Run the debug
debugRLSPolicies()
  .then(() => {
    console.log('\n🎯 Debug Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Debug failed:', error)
    process.exit(1)
  })
