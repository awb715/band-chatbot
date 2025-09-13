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

async function checkActualTableNames() {
  console.log('🔍 Checking Actual Table Names')
  console.log('==============================')
  
  try {
    // Try to query the information_schema to see what tables actually exist
    const { data: tables, error } = await supabase
      .rpc('exec_sql', { 
        sql: `
          SELECT table_schema, table_name 
          FROM information_schema.tables 
          WHERE table_name LIKE '%silver%' 
          ORDER BY table_schema, table_name
        ` 
      })
    
    if (error) {
      console.log('❌ Could not query information_schema:', error.message)
      
      // Fallback: try to access tables directly
      console.log('\n🔍 Trying direct table access:')
      
      const testTables = [
        'silver_songs', 'silver_shows', 'silver_setlists', 'silver_venues',
        'silver_latest', 'silver_metadata', 'silver_links', 'silver_uploads',
        'silver_appearances', 'silver_jamcharts'
      ]
      
      for (const table of testTables) {
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
    } else {
      console.log('📊 Tables with "silver" in the name:')
      tables.forEach(table => {
        console.log(`  ${table.table_schema}.${table.table_name}`)
      })
    }
    
    console.log('\n✅ Table name check completed!')
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkActualTableNames()
  .then(() => {
    console.log('\n🎯 Table Name Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

