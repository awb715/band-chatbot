#!/usr/bin/env node

/**
 * Repopulate Raw Data Tables
 * 
 * This script repopulates all raw data tables after the database reset.
 * Handles the setlists 4k limit by making multiple requests.
 */

import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

// Load environment variables
dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables')
  console.error('Please ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in .env')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseServiceKey)

console.log('🔄 Repopulating Raw Data Tables')
console.log('================================')

// ElGoose API endpoints
const endpoints = [
  { name: 'songs', url: 'https://elgoose.net/api/v2/songs.json' },
  { name: 'shows', url: 'https://elgoose.net/api/v2/shows.json' },
  { name: 'venues', url: 'https://elgoose.net/api/v2/venues.json' },
  { name: 'latest', url: 'https://elgoose.net/api/v2/latest.json' },
  { name: 'metadata', url: 'https://elgoose.net/api/v2/metadata.json' },
  { name: 'links', url: 'https://elgoose.net/api/v2/links.json' },
  { name: 'uploads', url: 'https://elgoose.net/api/v2/uploads.json' },
  { name: 'appearances', url: 'https://elgoose.net/api/v2/appearances.json' },
  { name: 'jamcharts', url: 'https://elgoose.net/api/v2/jamcharts.json' }
]

// Special handling for setlists (4k limit)
const setlistsEndpoint = { 
  name: 'setlists', 
  url: 'https://elgoose.net/api/v2/setlists.json',
  hasLimit: true,
  limit: 4000
}

async function fetchApiData(url, limit = null) {
  try {
    const fullUrl = limit ? `${url}?limit=${limit}` : url
    console.log(`📡 Fetching: ${fullUrl}`)
    
    const response = await fetch(fullUrl, {
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
    console.error(`❌ Error fetching ${url}:`, error.message)
    throw error
  }
}

async function insertRawData(tableName, records, sourceUrl) {
  try {
    console.log(`💾 Inserting ${records.length} records into raw_data.${tableName}`)
    
    const insertData = records.map(record => ({
      external_id: record.id?.toString() || `temp_${Date.now()}_${Math.random()}`,
      data: record,
      source_url: sourceUrl,
      is_processed: false
    }))
    
      const { data, error } = await supabase
        .from(`raw_data.${tableName}`)
        .insert(insertData)
    
    if (error) {
      throw new Error(`Database error: ${error.message}`)
    }
    
    console.log(`✅ Successfully inserted ${records.length} records into raw_data.${tableName}`)
    return records.length
  } catch (error) {
    console.error(`❌ Error inserting into raw_data.${tableName}:`, error.message)
    throw error
  }
}

async function handleSetlistsData() {
  console.log('\n🎵 Handling Setlists Data (4k limit)')
  console.log('====================================')
  
  try {
    // First, get the total count
    const countResponse = await fetch('https://elgoose.net/api/v2/setlists.json?limit=1')
    const countData = await countResponse.json()
    const totalRecords = countData.total || 0
    
    console.log(`📊 Total setlists records available: ${totalRecords}`)
    
    if (totalRecords <= 4000) {
      // If under 4k, fetch all at once
      console.log('📡 Fetching all setlists data in one request...')
      const data = await fetchApiData(setlistsEndpoint.url, 4000)
      return await insertRawData('setlists', data, setlistsEndpoint.url)
    } else {
      // If over 4k, we need to handle pagination
      console.log('📡 Fetching setlists data with pagination...')
      
      let totalInserted = 0
      let offset = 0
      const limit = 4000
      
      while (offset < totalRecords) {
        console.log(`📡 Fetching batch: offset=${offset}, limit=${limit}`)
        
        const batchUrl = `${setlistsEndpoint.url}?limit=${limit}&offset=${offset}`
        const data = await fetchApiData(batchUrl)
        
        if (data.length === 0) {
          console.log('📊 No more data, stopping pagination')
          break
        }
        
        const inserted = await insertRawData('setlists', data, batchUrl)
        totalInserted += inserted
        
        offset += limit
        
        // Add a small delay to be respectful to the API
        if (offset < totalRecords) {
          console.log('⏳ Waiting 1 second before next batch...')
          await new Promise(resolve => setTimeout(resolve, 1000))
        }
      }
      
      console.log(`✅ Setlists data complete: ${totalInserted} total records inserted`)
      return totalInserted
    }
  } catch (error) {
    console.error('❌ Error handling setlists data:', error.message)
    throw error
  }
}

async function handleRegularEndpoint(endpoint) {
  console.log(`\n📡 Processing ${endpoint.name.toUpperCase()}`)
  console.log('='.repeat(20))
  
  try {
    const data = await fetchApiData(endpoint.url)
    const inserted = await insertRawData(endpoint.name, data, endpoint.url)
    return inserted
  } catch (error) {
    console.error(`❌ Error processing ${endpoint.name}:`, error.message)
    return 0
  }
}

async function main() {
  console.log('🚀 Starting Raw Data Repopulation')
  console.log('==================================')
  
  let totalRecords = 0
  const results = {}
  
  try {
    // Process regular endpoints
    for (const endpoint of endpoints) {
      const count = await handleRegularEndpoint(endpoint)
      results[endpoint.name] = count
      totalRecords += count
    }
    
    // Process setlists with special handling
    const setlistsCount = await handleSetlistsData()
    results.setlists = setlistsCount
    totalRecords += setlistsCount
    
    // Summary
    console.log('\n🎉 Repopulation Complete!')
    console.log('========================')
    console.log('📊 Results by endpoint:')
    
    Object.entries(results).forEach(([endpoint, count]) => {
      console.log(`  ${endpoint}: ${count} records`)
    })
    
    console.log(`\n📈 Total records inserted: ${totalRecords}`)
    
    // Verify data
    console.log('\n🔍 Verifying data...')
    for (const endpoint of [...endpoints, setlistsEndpoint]) {
      const { data, error } = await supabase
        .from(`raw_data_${endpoint.name}`)
        .select('*', { count: 'exact' })
      
      if (error) {
        console.error(`❌ Error verifying ${endpoint.name}:`, error.message)
      } else {
        console.log(`✅ raw_data.${endpoint.name}: ${data.length} records`)
      }
    }
    
  } catch (error) {
    console.error('❌ Repopulation failed:', error.message)
    process.exit(1)
  }
}

// Run the repopulation
main().catch(console.error)
