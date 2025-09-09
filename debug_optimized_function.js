/**
 * DEBUG OPTIMIZED EDGE FUNCTION
 * =============================
 * 
 * This script debugs why the optimized Edge Function isn't processing data
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

async function debugEdgeFunction() {
  console.log('🔍 Debugging optimized Edge Function...')
  
  try {
    // Test with detailed logging
    const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        endpoint: 'songs',
        mode: 'incremental'
      })
    })
    
    console.log('📡 Response status:', response.status)
    console.log('📡 Response headers:', Object.fromEntries(response.headers.entries()))
    
    const result = await response.json()
    console.log('📊 Full response:', JSON.stringify(result, null, 2))
    
    // Check if we have any data in the database
    console.log('\n🔍 Checking database for recent data...')
    
    const { data: songs, error: songsError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5)
    
    if (songsError) {
      console.error('❌ Database error:', songsError)
    } else {
      console.log('📊 Recent songs in database:', songs?.length || 0)
      if (songs && songs.length > 0) {
        console.log('📝 Sample song:', {
          external_id: songs[0].external_id,
          created_at: songs[0].created_at,
          data_keys: songs[0].data ? Object.keys(songs[0].data) : 'N/A'
        })
      }
    }
    
  } catch (error) {
    console.error('❌ Debug failed:', error.message)
  }
}

// Run the debug
debugEdgeFunction().catch(console.error)
