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

async function checkDashboardDataIntegrity() {
  console.log('🔍 Checking Dashboard Data Integrity')
  console.log('====================================')
  
  try {
    // Check all schemas and tables
    const schemas = ['public', 'raw_data', 'silver']
    
    for (const schema of schemas) {
      console.log(`\n📊 Checking ${schema} schema...`)
      
      // Get table names for this schema
      const { data: tables, error: tablesError } = await supabase
        .rpc('get_schema_tables', { schema_name: schema })
      
      if (tablesError) {
        console.log(`❌ Error getting tables for ${schema}: ${tablesError.message}`)
        continue
      }
      
      console.log(`✅ Found ${tables.length} tables in ${schema}`)
      
      // Check each table
      for (const table of tables) {
        try {
          const { data, error, count } = await supabase
            .from(`${schema}_${table}`)
            .select('*', { count: 'exact' })
            .limit(1)
          
          if (error) {
            console.log(`❌ ${schema}.${table}: ${error.message}`)
          } else {
            console.log(`✅ ${schema}.${table}: ${count} records`)
          }
        } catch (err) {
          console.log(`❌ ${schema}.${table}: Exception - ${err.message}`)
        }
      }
    }
    
    // Check for any problematic data structures
    console.log('\n🔍 Checking for problematic data...')
    
    // Check raw_data tables for malformed JSON
    const rawTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
    
    for (const table of rawTables) {
      try {
        const { data, error } = await supabase
          .from(`raw_data_${table}`)
          .select('id, data, created_at')
          .limit(5)
        
        if (error) {
          console.log(`❌ Error checking ${table}: ${error.message}`)
        } else {
          console.log(`✅ ${table}: Sample data looks good`)
          
          // Check for any null or malformed data
          const problematic = data.filter(row => 
            !row.data || 
            typeof row.data !== 'object' ||
            row.data === null ||
            Array.isArray(row.data) // JSONB should be objects, not arrays
          )
          
          if (problematic.length > 0) {
            console.log(`⚠️ ${table}: Found ${problematic.length} potentially problematic records`)
            console.log(`   Sample problematic record:`, problematic[0])
          }
        }
      } catch (err) {
        console.log(`❌ ${table}: Exception - ${err.message}`)
      }
    }
    
    // Check for any tables with unusual column structures
    console.log('\n🔍 Checking table structures...')
    
    const { data: allTables, error: allTablesError } = await supabase
      .rpc('get_all_tables')
    
    if (allTablesError) {
      console.log(`❌ Error getting all tables: ${allTablesError.message}`)
    } else {
      console.log(`✅ Found ${allTables.length} total tables`)
      
      // Check for any tables with unusual names or structures
      const unusualTables = allTables.filter(table => 
        table.table_name.includes('__') ||
        table.table_name.includes('temp_') ||
        table.table_name.includes('_backup') ||
        table.table_name.includes('_old')
      )
      
      if (unusualTables.length > 0) {
        console.log(`⚠️ Found ${unusualTables.length} potentially problematic tables:`)
        unusualTables.forEach(table => {
          console.log(`   - ${table.table_schema}.${table.table_name}`)
        })
      }
    }
    
    console.log('\n✅ Dashboard data integrity check completed!')
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkDashboardDataIntegrity()
  .then(() => {
    console.log('\n🎯 Dashboard Data Integrity Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

