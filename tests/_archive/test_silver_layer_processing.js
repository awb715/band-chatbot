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

async function testSilverLayerProcessing() {
  console.log('🥈 Testing Silver Layer Processing')
  console.log('=================================')
  
  try {
    // Test 1: Check if all Silver tables exist
    console.log('\n📊 Checking Silver layer tables...')
    
    const silverTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
    
    for (const table of silverTables) {
      const { data, error } = await supabase
        .from(`silver_${table}`)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`❌ ${table}: ${error.message}`)
      } else {
        console.log(`✅ ${table}: Table exists`)
      }
    }
    
    // Test 2: Test individual ETL functions
    console.log('\n🔄 Testing individual ETL functions...')
    
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
    
    // Test 3: Test master ETL function
    console.log('\n🔄 Testing master ETL function...')
    
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
    
    // Test 4: Test Edge Function
    console.log('\n🚀 Testing Edge Function...')
    
    try {
      const response = await fetch(`${supabaseUrl}/functions/v1/process_tabular_data`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${serviceRoleKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          mode: 'silver_only',
          force_reprocess: false
        })
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const result = await response.json()
      
      if (result.success) {
        console.log(`✅ Edge Function: Success`)
        console.log(`  - Silver layer: ${result.silver_layer.total_records_processed} records processed`)
        console.log(`  - Tables processed: ${result.silver_layer.processed_tables}`)
        console.log(`  - Errors: ${result.silver_layer.total_errors}`)
      } else {
        console.log(`❌ Edge Function: ${result.error}`)
      }
    } catch (err) {
      console.log(`❌ Edge Function: Exception - ${err.message}`)
    }
    
    // Test 5: Check final Silver layer counts
    console.log('\n📊 Final Silver layer counts...')
    
    for (const table of silverTables) {
      try {
        const { data, error } = await supabase
          .from(`silver_${table}`)
          .select('*', { count: 'exact' })
        
        if (error) {
          console.log(`❌ ${table}: ${error.message}`)
        } else {
          console.log(`📊 ${table}: ${data.length} records`)
        }
      } catch (err) {
        console.log(`❌ ${table}: Exception - ${err.message}`)
      }
    }
    
    console.log('\n✅ Silver layer processing test completed!')
    
  } catch (error) {
    console.error('❌ Test failed:', error)
  }
}

// Run the test
testSilverLayerProcessing()
  .then(() => {
    console.log('\n🎯 Silver Layer Processing Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })

