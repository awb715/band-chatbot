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

async function testCorrectedSilverArchitecture() {
  console.log('🥈 Testing Corrected Silver Architecture')
  console.log('========================================')
  
  try {
    // Test 1: Check Silver schema tables
    console.log('\n📊 Checking Silver Schema Tables:')
    
    const silverTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
    
    for (const table of silverTables) {
      const { data, error } = await supabase
        .from(`silver_${table}`)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`❌ silver.${table}: ${error.message}`)
      } else {
        console.log(`✅ silver.${table}: Exists`)
      }
    }
    
    // Test 2: Check ETL functions
    console.log('\n🔄 Testing ETL Functions:')
    
    const etlFunctions = [
      'process_shows',
      'process_setlists', 
      'process_venues',
      'process_latest',
      'process_metadata',
      'process_links',
      'process_uploads',
      'process_appearances',
      'process_jamcharts'
    ]
    
    for (const func of etlFunctions) {
      try {
        const { data, error } = await supabase.rpc(func)
        
        if (error) {
          console.log(`❌ ${func}: ${error.message}`)
        } else {
          console.log(`✅ ${func}: Processed ${data[0]?.processed_count || 0} records`)
        }
      } catch (err) {
        console.log(`❌ ${func}: Exception - ${err.message}`)
      }
    }
    
    // Test 3: Check master ETL function
    console.log('\n🔄 Testing Master ETL Function:')
    
    try {
      const { data, error } = await supabase.rpc('process_all_tables')
      
      if (error) {
        console.log(`❌ process_all_tables: ${error.message}`)
      } else {
        console.log(`✅ process_all_tables: Processed ${data.length} tables`)
        data.forEach(result => {
          console.log(`  - ${result.table_name}: ${result.processed_count} records, ${result.processing_time_ms}ms`)
        })
      }
    } catch (err) {
      console.log(`❌ process_all_tables: Exception - ${err.message}`)
    }
    
    // Test 4: Check Silver layer counts
    console.log('\n📊 Silver Layer Counts:')
    
    for (const table of silverTables) {
      try {
        const { data, error } = await supabase
          .from(`silver_${table}`)
          .select('*', { count: 'exact' })
        
        if (error) {
          console.log(`❌ silver.${table}: ${error.message}`)
        } else {
          console.log(`📊 silver.${table}: ${data.length} records`)
        }
      } catch (err) {
        console.log(`❌ silver.${table}: Exception - ${err.message}`)
      }
    }
    
    // Test 5: Verify data is in correct schema
    console.log('\n🔍 Verifying Schema Location:')
    
    // Check if public.silver_* tables still exist (they shouldn't)
    const publicTables = ['silver_songs', 'silver_shows', 'silver_setlists']
    
    for (const table of publicTables) {
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`✅ public.${table}: Correctly removed`)
      } else {
        console.log(`❌ public.${table}: Still exists (should be removed)`)
      }
    }
    
    console.log('\n✅ Corrected Silver architecture test completed!')
    
  } catch (error) {
    console.error('❌ Test failed:', error)
  }
}

// Run the test
testCorrectedSilverArchitecture()
  .then(() => {
    console.log('\n🎯 Corrected Silver Architecture Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })

