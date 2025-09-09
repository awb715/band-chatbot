/**
 * TEST SIMPLE ENDPOINT
 * ====================
 * 
 * Test the Edge Function with a very simple approach to see what's happening
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

async function testSimpleEndpoint() {
  console.log('🔍 Testing simple endpoint call...')
  
  try {
    // Test with no parameters to see if it processes all endpoints
    const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({})
    })
    
    console.log('📡 Response status:', response.status)
    
    const result = await response.json()
    console.log('📊 Full response:', JSON.stringify(result, null, 2))
    
    // Check database for any new data
    console.log('\n🔍 Checking database...')
    
    const { data: songs, error: songsError } = await supabase
      .from('raw_data_songs')
      .select('count', { count: 'exact' })
      .gte('created_at', new Date(Date.now() - 5 * 60 * 1000).toISOString()) // Last 5 minutes
    
    if (songsError) {
      console.error('❌ Database error:', songsError)
    } else {
      console.log('📊 New songs in last 5 minutes:', songs?.[0]?.count || 0)
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message)
  }
}

// Run the test
testSimpleEndpoint().catch(console.error)
