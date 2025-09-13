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

async function checkCurrentRole() {
  console.log('🔍 Checking Current Database Role')
  console.log('=================================')
  
  try {
    // Check what role we're currently using
    console.log('\n👤 Current Role Information:')
    
    // Method 1: Check current_user
    const { data: currentUser, error: userError } = await supabase
      .rpc('current_user')
    
    if (userError) {
      console.log('❌ Could not get current_user:', userError.message)
    } else {
      console.log('✅ Current user:', currentUser)
    }
    
    // Method 2: Check session
    const { data: session, error: sessionError } = await supabase.auth.getSession()
    if (sessionError) {
      console.log('❌ Could not get session:', sessionError.message)
    } else {
      console.log('✅ Session:', session?.session ? 'Authenticated' : 'Anonymous')
      if (session?.session?.user) {
        console.log('   User ID:', session.session.user.id)
        console.log('   Email:', session.session.user.email)
      }
    }
    
    // Method 3: Check what we can see in pg_roles
    const { data: roles, error: rolesError } = await supabase
      .from('pg_roles')
      .select('rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolconnlimit, rolpassword, rolvaliduntil')
      .eq('rolcanlogin', true)
    
    if (rolesError) {
      console.log('❌ Could not get roles:', rolesError.message)
    } else {
      console.log('✅ Available login roles:')
      roles.forEach(role => {
        console.log(`  - ${role.rolname} (super: ${role.rolsuper}, inherit: ${role.rolinherit})`)
      })
    }
    
    // Method 4: Check current role directly
    const { data: currentRole, error: roleError } = await supabase
      .rpc('current_role')
    
    if (roleError) {
      console.log('❌ Could not get current_role:', roleError.message)
    } else {
      console.log('✅ Current role:', currentRole)
    }
    
    // Method 5: Check what permissions we have
    console.log('\n🔐 Permission Check:')
    const { data: permissions, error: permError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .limit(1)
    
    if (permError) {
      console.log('❌ Cannot access raw_data_songs:', permError.message)
    } else {
      console.log('✅ Can access raw_data_songs:', permissions.length, 'records')
    }
    
    // Method 6: Check if we can see RLS policies
    console.log('\n📋 RLS Policy Check:')
    const { data: policies, error: policyError } = await supabase
      .from('pg_policies')
      .select('*')
      .eq('tablename', 'songs')
      .eq('schemaname', 'raw_data')
    
    if (policyError) {
      console.log('❌ Cannot access pg_policies:', policyError.message)
    } else {
      console.log('✅ Can see policies:', policies.length, 'policies')
      policies.forEach(policy => {
        console.log(`  - ${policy.policyname}: ${policy.cmd} for ${policy.roles}`)
      })
    }
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkCurrentRole()
  .then(() => {
    console.log('\n🎯 Role Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })
