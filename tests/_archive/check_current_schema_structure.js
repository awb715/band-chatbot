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

async function checkCurrentSchemaStructure() {
  console.log('🔍 Checking Current Schema Structure')
  console.log('====================================')
  
  try {
    // Check what tables exist in public schema
    console.log('\n📊 Public Schema Tables:')
    const publicTables = [
      'silver_songs', 'silver_shows', 'silver_setlists', 'silver_venues', 
      'silver_latest', 'silver_metadata', 'silver_links', 'silver_uploads', 
      'silver_appearances', 'silver_jamcharts'
    ]
    
    for (const table of publicTables) {
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`❌ ${table}: ${error.message}`)
      } else {
        console.log(`✅ ${table}: Exists`)
      }
    }
    
    // Check what tables exist in silver schema
    console.log('\n📊 Silver Schema Tables:')
    const silverTables = [
      'songs', 'shows', 'setlists', 'venues', 
      'latest', 'metadata', 'links', 'uploads', 
      'appearances', 'jamcharts'
    ]
    
    for (const table of silverTables) {
      const { data, error } = await supabase
        .from(`silver_${table}`)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`❌ silver.${table}: ${error.message}`)
      } else {
        console.log(`✅ silver.${table}: Exists`)
      }
    }
    
    // Check raw_data tables
    console.log('\n📊 Raw Data Schema Tables:')
    const rawTables = [
      'songs', 'shows', 'setlists', 'venues', 
      'latest', 'metadata', 'links', 'uploads', 
      'appearances', 'jamcharts'
    ]
    
    for (const table of rawTables) {
      const { data, error } = await supabase
        .from(`raw_data_${table}`)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`❌ raw_data.${table}: ${error.message}`)
      } else {
        console.log(`✅ raw_data.${table}: Exists`)
      }
    }
    
    console.log('\n✅ Schema structure check completed!')
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkCurrentSchemaStructure()
  .then(() => {
    console.log('\n🎯 Schema Structure Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

