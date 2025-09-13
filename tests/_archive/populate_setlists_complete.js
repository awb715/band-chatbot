#!/usr/bin/env node

/**
 * Populate Setlists Complete
 * 
 * This script properly handles pagination to get ALL setlists records
 * (8,486 total) by making multiple requests with the 4k limit.
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

console.log('🎵 Populating ALL Setlists Records')
console.log('==================================')

async function fetchSetlistsBatch(offset, limit) {
  try {
    const url = `https://elgoose.net/api/v2/setlists.json?limit=${limit}&offset=${offset}`
    console.log(`📡 Fetching batch: offset=${offset}, limit=${limit}`)
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'Band-Chatbot/1.0'
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    const data = await response.json()
    
    if (data.error) {
      throw new Error(`API Error: ${data.error}`)
    }
    
    return data.data || data
  } catch (error) {
    console.error(`❌ Error fetching batch offset=${offset}:`, error.message)
    throw error
  }
}

async function insertSetlistsBatch(records, batchNumber) {
  try {
    console.log(`💾 Inserting batch ${batchNumber}: ${records.length} records`)
    
    const insertData = records.map(record => ({
      external_id: record.uniqueid?.toString() || `temp_${Date.now()}_${Math.random()}`,
      data: record,
      source_url: `https://elgoose.net/api/v2/setlists.json?offset=${(batchNumber - 1) * 4000}&limit=4000`,
      is_processed: false
    }))
    
    const { data, error } = await supabase
      .from('raw_data_setlists')
      .insert(insertData)
    
    if (error) {
      throw new Error(`Database error: ${error.message}`)
    }
    
    console.log(`✅ Successfully inserted batch ${batchNumber}: ${records.length} records`)
    return records.length
  } catch (error) {
    console.error(`❌ Error inserting batch ${batchNumber}:`, error.message)
    throw error
  }
}

async function clearExistingSetlists() {
  console.log('🗑️ Clearing existing setlists data...')
  
  try {
    const { error } = await supabase
      .from('raw_data_setlists')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000') // Delete all records
    
    if (error) {
      console.error('❌ Error clearing existing data:', error.message)
    } else {
      console.log('✅ Existing setlists data cleared')
    }
  } catch (error) {
    console.error('❌ Error clearing existing data:', error.message)
  }
}

async function populateAllSetlists() {
  const totalRecords = 8486
  const batchSize = 4000
  const totalBatches = Math.ceil(totalRecords / batchSize)
  
  console.log(`📊 Total records to fetch: ${totalRecords}`)
  console.log(`📦 Batch size: ${batchSize}`)
  console.log(`🔢 Total batches needed: ${totalBatches}`)
  
  let totalInserted = 0
  
  try {
    // Clear existing data first
    await clearExistingSetlists()
    
    // Process each batch
    for (let batch = 1; batch <= totalBatches; batch++) {
      const offset = (batch - 1) * batchSize
      const limit = Math.min(batchSize, totalRecords - offset)
      
      console.log(`\n📦 Processing batch ${batch}/${totalBatches}`)
      console.log(`📍 Offset: ${offset}, Limit: ${limit}`)
      
      // Fetch batch data
      const records = await fetchSetlistsBatch(offset, limit)
      
      if (records.length === 0) {
        console.log('📊 No more data, stopping pagination')
        break
      }
      
      // Insert batch data
      const inserted = await insertSetlistsBatch(records, batch)
      totalInserted += inserted
      
      // Add delay between batches to be respectful to the API
      if (batch < totalBatches) {
        console.log('⏳ Waiting 2 seconds before next batch...')
        await new Promise(resolve => setTimeout(resolve, 2000))
      }
    }
    
    console.log(`\n🎉 Setlists population complete!`)
    console.log(`📈 Total records inserted: ${totalInserted}`)
    
    // Verify final count
    const { data: finalData, error: finalError } = await supabase
      .from('raw_data_setlists')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.error('❌ Error verifying final count:', finalError.message)
    } else {
      console.log(`✅ Final verification: ${finalData.length} records in database`)
    }
    
    return totalInserted
    
  } catch (error) {
    console.error('❌ Error populating setlists:', error.message)
    throw error
  }
}

async function main() {
  console.log('🚀 Starting complete setlists population')
  
  try {
    const totalInserted = await populateAllSetlists()
    
    if (totalInserted > 0) {
      console.log('\n✅ Setlists population completed successfully!')
      console.log(`📊 Total records: ${totalInserted}`)
    } else {
      console.log('\n❌ No records were inserted')
      process.exit(1)
    }
  } catch (error) {
    console.error('\n❌ Setlists population failed:', error.message)
    process.exit(1)
  }
}

main().catch(console.error)
