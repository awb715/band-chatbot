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

async function checkSilverImplementationStatus() {
  console.log('🔍 Checking Silver Layer Implementation Status')
  console.log('=============================================')
  
  try {
    // Check what Silver tables exist
    console.log('\n🥈 Silver Layer Tables:')
    
    const silverTables = [
      'songs', 'shows', 'setlists', 'venues', 'latest', 
      'metadata', 'links', 'uploads', 'appearances', 'jamcharts'
    ]
    
    const existingTables = []
    const missingTables = []
    
    for (const table of silverTables) {
      const { data, error } = await supabase
        .from(`silver_${table}`)
        .select('*')
        .limit(1)
      
      if (error) {
        if (error.message.includes('Could not find the table')) {
          missingTables.push(table)
        } else {
          console.log(`❌ Error checking ${table}:`, error.message)
        }
      } else {
        existingTables.push(table)
      }
    }
    
    console.log(`✅ Existing tables: ${existingTables.join(', ')}`)
    console.log(`❌ Missing tables: ${missingTables.join(', ')}`)
    
    // Check Gold layer
    console.log('\n🥇 Gold Layer Tables:')
    
    const goldTables = ['songs_analytics', 'shows_analytics', 'venues_analytics', 'setlists_analytics']
    
    const existingGoldTables = []
    const missingGoldTables = []
    
    for (const table of goldTables) {
      const { data, error } = await supabase
        .from(`gold_${table}`)
        .select('*')
        .limit(1)
      
      if (error) {
        if (error.message.includes('Could not find the table')) {
          missingGoldTables.push(table)
        } else {
          console.log(`❌ Error checking gold.${table}:`, error.message)
        }
      } else {
        existingGoldTables.push(table)
      }
    }
    
    console.log(`✅ Existing Gold tables: ${existingGoldTables.join(', ')}`)
    console.log(`❌ Missing Gold tables: ${missingGoldTables.join(', ')}`)
    
    // Check ETL functions
    console.log('\n🔄 ETL Functions:')
    
    const etlFunctions = [
      'silver.process_songs',
      'silver.process_shows', 
      'silver.process_setlists',
      'silver.process_venues',
      'silver.process_all_tables',
      'gold.aggregate_songs_analytics',
      'gold.aggregate_all_analytics'
    ]
    
    for (const func of etlFunctions) {
      const { data, error } = await supabase
        .rpc(func)
      
      if (error) {
        if (error.message.includes('Could not find the function')) {
          console.log(`❌ Missing function: ${func}`)
        } else {
          console.log(`⚠️ Function ${func} exists but has error:`, error.message)
        }
      } else {
        console.log(`✅ Function exists: ${func}`)
      }
    }
    
    // Check GitHub Actions
    console.log('\n🚀 GitHub Actions:')
    
    const fs = await import('fs')
    const path = await import('path')
    
    const githubActionsPath = '.github/workflows'
    
    try {
      const files = fs.readdirSync(githubActionsPath)
      const ymlFiles = files.filter(file => file.endsWith('.yml') || file.endsWith('.yaml'))
      
      console.log(`📁 GitHub Actions files: ${ymlFiles.join(', ')}`)
      
      // Check for specific workflows
      const expectedWorkflows = [
        'data-ingestion.yml',
        'silver-processing.yml', 
        'gold-aggregation.yml'
      ]
      
      const missingWorkflows = expectedWorkflows.filter(workflow => !ymlFiles.includes(workflow))
      const existingWorkflows = expectedWorkflows.filter(workflow => ymlFiles.includes(workflow))
      
      console.log(`✅ Existing workflows: ${existingWorkflows.join(', ')}`)
      console.log(`❌ Missing workflows: ${missingWorkflows.join(', ')}`)
      
    } catch (error) {
      console.log('❌ Could not check GitHub Actions:', error.message)
    }
    
    // Check Bronze layer data
    console.log('\n🥉 Bronze Layer Data:')
    
    const bronzeTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
    
    for (const table of bronzeTables) {
      const { data, error } = await supabase
        .from(`raw_data_${table}`)
        .select('*', { count: 'exact' })
      
      if (error) {
        console.log(`❌ Error checking raw_data.${table}:`, error.message)
      } else {
        console.log(`📊 raw_data.${table}: ${data.length} records`)
      }
    }
    
    // Summary
    console.log('\n📊 Implementation Status Summary:')
    console.log(`🥈 Silver Layer: ${existingTables.length}/${silverTables.length} tables (${((existingTables.length/silverTables.length)*100).toFixed(1)}%)`)
    console.log(`🥇 Gold Layer: ${existingGoldTables.length}/${goldTables.length} tables (${((existingGoldTables.length/goldTables.length)*100).toFixed(1)}%)`)
    console.log(`🔄 ETL Functions: Check individual functions above`)
    console.log(`🚀 GitHub Actions: Check workflows above`)
    
    if (missingTables.length > 0) {
      console.log('\n🎯 Next Steps:')
      console.log('1. Create missing Silver layer tables')
      console.log('2. Deploy Gold layer from backup')
      console.log('3. Create missing ETL functions')
      console.log('4. Set up GitHub Actions workflows')
    }
    
  } catch (error) {
    console.error('❌ Status check failed:', error)
  }
}

// Run the check
checkSilverImplementationStatus()
  .then(() => {
    console.log('\n🎯 Silver Implementation Status Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

