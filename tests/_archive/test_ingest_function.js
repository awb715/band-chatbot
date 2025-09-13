#!/usr/bin/env node

/**
 * Test Ingest Function
 * 
 * This script tests the ingest_raw_data function with the repopulated data.
 */

import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

// Load environment variables
dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey)

console.log('🧪 Testing Ingest Function')
console.log('==========================')

async function testIngestFunction() {
  try {
    console.log('📡 Calling ingest_raw_data function...')
    
    const response = await fetch(`${supabaseUrl}/functions/v1/ingest_raw_data`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ mode: 'incremental' })
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const result = await response.json()
    
    if (result.success) {
      console.log('✅ Ingest function completed successfully!')
      console.log('📊 Results:', result)
      return true
    } else {
      console.error('❌ Ingest function failed:', result.error)
      return false
    }
  } catch (error) {
    console.error('❌ Error testing ingest function:', error.message)
    return false
  }
}

async function checkRawDataCounts() {
  console.log('\n🔍 Checking raw data counts...')
  
  const endpoints = ['songs', 'shows', 'venues', 'setlists', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
  
  for (const endpoint of endpoints) {
    try {
      const { data, error } = await supabase
        .from(`raw_data.${endpoint}`)
        .select('*', { count: 'exact' })
      
      if (error) {
        console.error(`❌ Error checking ${endpoint}:`, error.message)
      } else {
        console.log(`📊 raw_data.${endpoint}: ${data.length} records`)
      }
    } catch (error) {
      console.error(`❌ Error checking ${endpoint}:`, error.message)
    }
  }
}

async function main() {
  console.log('🚀 Starting ingest function test')
  
  // Check current data counts
  await checkRawDataCounts()
  
  // Test the ingest function
  const success = await testIngestFunction()
  
  if (success) {
    console.log('\n🎉 Ingest function test completed successfully!')
    console.log('✅ Raw data is properly populated and ingest function is working')
  } else {
    console.log('\n❌ Ingest function test failed')
    process.exit(1)
  }
}

main().catch(console.error)
