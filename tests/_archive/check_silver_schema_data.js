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

async function checkSilverSchemaData() {
  console.log('🔍 Checking Silver Schema Data')
  console.log('==============================')
  
  try {
    const silverTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
    
    console.log('\n📊 Silver Schema Table Counts:')
    console.log('===============================')
    
    for (const table of silverTables) {
      const { data, error, count } = await supabase
        .from(`silver_${table}`)
        .select('*', { count: 'exact' })
        .limit(5)
      
      if (error) {
        console.log(`❌ silver.${table}: ${error.message}`)
      } else {
        console.log(`📊 silver.${table}: ${count} records`)
        
        if (count > 0) {
          console.log(`   Sample data:`, data[0])
        }
      }
    }
    
    // Also check if there are any public.silver_* tables with data
    console.log('\n📊 Public Schema Silver Tables (if they exist):')
    console.log('================================================')
    
    const publicTables = ['silver_songs', 'silver_shows', 'silver_setlists', 'silver_venues', 'silver_latest', 'silver_metadata', 'silver_links', 'silver_uploads', 'silver_appearances', 'silver_jamcharts']
    
    for (const table of publicTables) {
      const { data, error, count } = await supabase
        .from(table)
        .select('*', { count: 'exact' })
        .limit(1)
      
      if (error) {
        console.log(`❌ public.${table}: ${error.message}`)
      } else {
        console.log(`📊 public.${table}: ${count} records`)
      }
    }
    
    console.log('\n✅ Silver schema data check completed!')
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkSilverSchemaData()
  .then(() => {
    console.log('\n🎯 Silver Schema Data Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

