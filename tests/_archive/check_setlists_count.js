#!/usr/bin/env node

/**
 * Check Setlists Count
 * 
 * This script checks the actual number of setlists records available
 * and handles proper pagination for the 4k limit.
 */

import dotenv from 'dotenv'

// Load environment variables
dotenv.config()

console.log('🔍 Checking Setlists Count')
console.log('==========================')

async function checkSetlistsCount() {
  try {
    // First, get a small sample to check total count
    console.log('📡 Fetching setlists count...')
    const response = await fetch('https://elgoose.net/api/v2/setlists.json?limit=1')
    const data = await response.json()
    
    console.log('📊 API Response:', data)
    
    if (data.total) {
      console.log(`📈 Total setlists available: ${data.total}`)
      return data.total
    } else {
      console.log('⚠️ No total count in response, checking with larger limit...')
      
      // Try with a larger limit to see how many we get
      const largeResponse = await fetch('https://elgoose.net/api/v2/setlists.json?limit=10000')
      const largeData = await largeResponse.json()
      
      if (largeData.data && Array.isArray(largeData.data)) {
        console.log(`📈 Records returned with limit=10000: ${largeData.data.length}`)
        return largeData.data.length
      } else {
        console.log('❌ Could not determine total count')
        return 0
      }
    }
  } catch (error) {
    console.error('❌ Error checking setlists count:', error.message)
    return 0
  }
}

async function main() {
  const totalCount = await checkSetlistsCount()
  
  if (totalCount > 4000) {
    console.log(`\n⚠️ WARNING: There are ${totalCount} setlists records available!`)
    console.log('📋 We need to handle pagination to get all records.')
    console.log('🔢 Batches needed:', Math.ceil(totalCount / 4000))
  } else {
    console.log(`\n✅ All ${totalCount} setlists records can be fetched in one request.`)
  }
}

main().catch(console.error)
