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

async function simpleDashboardCheck() {
  console.log('🔍 Simple Dashboard Check')
  console.log('========================')
  
  try {
    // Test basic connectivity
    console.log('📡 Testing basic connectivity...')
    
    const { data: testData, error: testError } = await supabase
      .from('raw_data_songs')
      .select('count', { count: 'exact' })
      .limit(1)
    
    if (testError) {
      console.log(`❌ Basic connectivity failed: ${testError.message}`)
      return
    }
    
    console.log(`✅ Basic connectivity works - found ${testData.length} songs`)
    
    // Check each table individually
    console.log('\n📊 Checking individual tables...')
    
    const tables = [
      { schema: 'raw_data', name: 'songs' },
      { schema: 'raw_data', name: 'shows' },
      { schema: 'raw_data', name: 'setlists' },
      { schema: 'raw_data', name: 'venues' },
      { schema: 'raw_data', name: 'latest' },
      { schema: 'raw_data', name: 'metadata' },
      { schema: 'raw_data', name: 'links' },
      { schema: 'raw_data', name: 'uploads' },
      { schema: 'raw_data', name: 'appearances' },
      { schema: 'raw_data', name: 'jamcharts' },
      { schema: 'silver', name: 'songs' },
      { schema: 'silver', name: 'shows' },
      { schema: 'silver', name: 'setlists' },
      { schema: 'silver', name: 'venues' },
      { schema: 'silver', name: 'latest' },
      { schema: 'silver', name: 'metadata' },
      { schema: 'silver', name: 'links' },
      { schema: 'silver', name: 'uploads' },
      { schema: 'silver', name: 'appearances' },
      { schema: 'silver', name: 'jamcharts' }
    ]
    
    for (const table of tables) {
      try {
        const { data, error, count } = await supabase
          .from(`${table.schema}_${table.name}`)
          .select('*', { count: 'exact' })
          .limit(1)
        
        if (error) {
          console.log(`❌ ${table.schema}.${table.name}: ${error.message}`)
        } else {
          console.log(`✅ ${table.schema}.${table.name}: ${count} records`)
        }
      } catch (err) {
        console.log(`❌ ${table.schema}.${table.name}: Exception - ${err.message}`)
      }
    }
    
    // Check for any malformed JSON data
    console.log('\n🔍 Checking for malformed JSON data...')
    
    const { data: songsData, error: songsError } = await supabase
      .from('raw_data_songs')
      .select('id, data, created_at')
      .limit(10)
    
    if (songsError) {
      console.log(`❌ Error checking songs data: ${songsError.message}`)
    } else {
      console.log(`✅ Songs data structure looks good`)
      
      // Check for any problematic records
      const problematic = songsData.filter(row => 
        !row.data || 
        typeof row.data !== 'object' ||
        row.data === null
      )
      
      if (problematic.length > 0) {
        console.log(`⚠️ Found ${problematic.length} problematic song records`)
        console.log(`   Sample:`, problematic[0])
      } else {
        console.log(`✅ All song records have valid JSON data`)
      }
    }
    
    // Test a simple query that might be causing the dashboard issue
    console.log('\n🔍 Testing dashboard-like queries...')
    
    try {
      const { data: recentSongs, error: recentError } = await supabase
        .from('raw_data_songs')
        .select('id, external_id, data, created_at')
        .order('created_at', { ascending: false })
        .limit(20)
      
      if (recentError) {
        console.log(`❌ Recent songs query failed: ${recentError.message}`)
      } else {
        console.log(`✅ Recent songs query works - found ${recentSongs.length} records`)
      }
    } catch (err) {
      console.log(`❌ Recent songs query exception: ${err.message}`)
    }
    
    console.log('\n✅ Simple dashboard check completed!')
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
simpleDashboardCheck()
  .then(() => {
    console.log('\n🎯 Simple Dashboard Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

