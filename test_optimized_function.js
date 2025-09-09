/**
 * TEST OPTIMIZED EDGE FUNCTION
 * ============================
 * 
 * This script tests the updated Edge Function with:
 * 1. Incremental mode (recent data only)
 * 2. Manual mode (full data processing)
 * 3. Individual endpoint testing
 */

import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

// Load environment variables
dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const supabaseKey = process.env.SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseKey)

async function testEdgeFunction(endpoint, mode = 'incremental') {
  console.log(`\n🧪 Testing ${endpoint} in ${mode} mode...`)
  
  try {
    const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        endpoint: endpoint,
        mode: mode
      })
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const result = await response.json()
    console.log(`✅ ${endpoint} (${mode}):`, {
      success: result.success,
      total_new: result.total_new_records,
      total_updated: result.total_updated_records,
      results: result.results
    })
    
    return result
  } catch (error) {
    console.error(`❌ ${endpoint} (${mode}) failed:`, error.message)
    return null
  }
}

async function testAllEndpoints() {
  console.log('🚀 Testing optimized Edge Function...')
  console.log('📅 Test run:', new Date().toISOString())
  
  // Test individual endpoints in incremental mode
  const endpoints = ['songs', 'shows', 'venues', 'setlists']
  
  for (const endpoint of endpoints) {
    await testEdgeFunction(endpoint, 'incremental')
    // Small delay between requests
    await new Promise(resolve => setTimeout(resolve, 1000))
  }
  
  // Test one endpoint in manual mode
  console.log('\n🔄 Testing manual mode...')
  await testEdgeFunction('songs', 'manual')
  
  console.log('\n✅ All tests completed!')
}

// Run the tests
testAllEndpoints().catch(console.error)
