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

async function dropDuplicateTablesDirectly() {
  console.log('🗑️ Dropping Duplicate Tables Directly')
  console.log('=====================================')
  
  try {
    const tables = [
      'silver_songs', 'silver_shows', 'silver_setlists', 'silver_venues',
      'silver_latest', 'silver_metadata', 'silver_links', 'silver_uploads',
      'silver_appearances', 'silver_jamcharts'
    ]
    
    console.log('🔍 Attempting to drop duplicate tables...')
    
    for (const table of tables) {
      try {
        // Try to drop the table directly
        const { error } = await supabase
          .rpc('exec_sql', { 
            sql: `DROP TABLE IF EXISTS public.${table} CASCADE;` 
          })
        
        if (error) {
          console.log(`❌ Could not drop public.${table}: ${error.message}`)
        } else {
          console.log(`✅ Dropped public.${table}`)
        }
      } catch (err) {
        console.log(`❌ Exception dropping public.${table}: ${err.message}`)
      }
    }
    
    // Verify cleanup
    console.log('\n🔍 Verifying cleanup...')
    
    for (const table of tables) {
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .limit(1)
      
      if (error) {
        console.log(`✅ public.${table}: Successfully removed`)
      } else {
        console.log(`❌ public.${table}: Still exists`)
      }
    }
    
    console.log('\n✅ Duplicate table cleanup completed!')
    
  } catch (error) {
    console.error('❌ Cleanup failed:', error)
  }
}

// Run the cleanup
dropDuplicateTablesDirectly()
  .then(() => {
    console.log('\n🎯 Duplicate Table Cleanup Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Cleanup failed:', error)
    process.exit(1)
  })
