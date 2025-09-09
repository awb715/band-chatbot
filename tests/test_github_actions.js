/**
 * TEST GITHUB ACTIONS
 * ===================
 * 
 * This script tests the GitHub Actions workflows by simulating their behavior
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

async function testGitHubActionsWorkflow() {
  console.log('🚀 Testing GitHub Actions workflow simulation...')
  console.log('📅 Test run:', new Date().toISOString())
  
  // Simulate the daily incremental workflow
  const endpoints = ['setlists', 'songs', 'shows', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances']
  
  console.log(`\n🔄 Simulating parallel processing of ${endpoints.length} endpoints...`)
  console.log('📊 Max parallel: 3 endpoints simultaneously')
  
  // Process endpoints in batches of 3 (simulating max-parallel: 3)
  const batchSize = 3
  for (let i = 0; i < endpoints.length; i += batchSize) {
    const batch = endpoints.slice(i, i + batchSize)
    console.log(`\n📦 Processing batch ${Math.floor(i / batchSize) + 1}: ${batch.join(', ')}`)
    
    // Process each endpoint in the batch
    for (const endpoint of batch) {
      try {
        console.log(`  🔄 Processing ${endpoint}...`)
        
        const response = await fetch('https://jvvcxraopwbpewisiohu.supabase.co/functions/v1/ingest_raw_data', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            endpoint: endpoint,
            mode: 'incremental'
          })
        })
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        
        const result = await response.json()
        console.log(`    ✅ ${endpoint}: ${result.total_new_records} new, ${result.total_updated_records} updated`)
        
        // Small delay between requests
        await new Promise(resolve => setTimeout(resolve, 500))
        
      } catch (error) {
        console.error(`    ❌ ${endpoint} failed:`, error.message)
      }
    }
    
    // Delay between batches
    if (i + batchSize < endpoints.length) {
      console.log('  ⏳ Waiting before next batch...')
      await new Promise(resolve => setTimeout(resolve, 2000))
    }
  }
  
  console.log('\n✅ GitHub Actions workflow simulation completed!')
  
  // Check final database state
  console.log('\n🔍 Checking final database state...')
  
  const { data: recentData, error: recentError } = await supabase
    .from('raw_data_songs')
    .select('count', { count: 'exact' })
    .gte('updated_at', new Date(Date.now() - 10 * 60 * 1000).toISOString()) // Last 10 minutes
  
  if (recentError) {
    console.error('❌ Database error:', recentError)
  } else {
    console.log('📊 Songs updated in last 10 minutes:', recentData?.[0]?.count || 0)
  }
}

// Run the test
testGitHubActionsWorkflow().catch(console.error)
