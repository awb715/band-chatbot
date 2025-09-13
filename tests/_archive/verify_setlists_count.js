#!/usr/bin/env node

/**
 * Verify Setlists Count
 * 
 * This script verifies the actual count of setlists records in the database.
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

console.log('🔍 Verifying Setlists Count')
console.log('===========================')

async function verifySetlistsCount() {
  try {
    // Get the actual count using count query
    const { count, error } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact', head: true })
    
    if (error) {
      console.error('❌ Error getting count:', error.message)
      return 0
    }
    
    console.log(`📊 Total setlists records in database: ${count}`)
    return count
  } catch (error) {
    console.error('❌ Error verifying count:', error.message)
    return 0
  }
}

async function checkSampleData() {
  try {
    // Get a sample of records to verify data quality
    const { data, error } = await supabase
      .from('raw_data_setlists')
      .select('external_id, data->songname, data->venuename, data->showdate')
      .limit(5)
    
    if (error) {
      console.error('❌ Error getting sample data:', error.message)
      return
    }
    
    console.log('\n🎵 Sample setlists data:')
    console.log('========================')
    data.forEach((record, index) => {
      console.log(`${index + 1}. ${record.data?.songname || 'Unknown Song'}`)
      console.log(`   Venue: ${record.data?.venuename || 'Unknown Venue'}`)
      console.log(`   Date: ${record.data?.showdate || 'Unknown Date'}`)
      console.log(`   External ID: ${record.external_id}`)
      console.log('')
    })
  } catch (error) {
    console.error('❌ Error checking sample data:', error.message)
  }
}

async function main() {
  console.log('🚀 Starting setlists verification')
  
  const count = await verifySetlistsCount()
  
  if (count >= 8000) {
    console.log('✅ Setlists data looks complete!')
  } else if (count >= 4000) {
    console.log('⚠️ Setlists data is partially complete')
  } else {
    console.log('❌ Setlists data appears incomplete')
  }
  
  await checkSampleData()
  
  console.log('\n🎉 Setlists verification complete!')
}

main().catch(console.error)
