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

async function resetAndReprocessSetlists() {
  console.log('🔄 Resetting and Reprocessing Setlists')
  console.log('=====================================')
  
  try {
    // 1. Clear existing setlists data
    console.log('🗑️ Clearing existing setlists data...')
    
    const { error: deleteError } = await supabase
      .from('silver_setlists')
      .delete()
      .neq('id', '00000000-0000-0000-0000-000000000000') // Delete all records
    
    if (deleteError) {
      console.log(`❌ Error clearing setlists: ${deleteError.message}`)
    } else {
      console.log('✅ Cleared existing setlists data')
    }
    
    // 2. Reset is_processed flags
    console.log('🔄 Resetting is_processed flags...')
    
    const { error: resetError } = await supabase
      .from('raw_data_setlists')
      .update({ is_processed: false })
      .neq('id', '00000000-0000-0000-0000-000000000000') // Update all records
    
    if (resetError) {
      console.log(`❌ Error resetting flags: ${resetError.message}`)
    } else {
      console.log('✅ Reset is_processed flags')
    }
    
    // 3. Process setlists
    console.log('🔄 Processing setlists...')
    
    const { data, error } = await supabase.rpc('process_setlists')
    
    if (error) {
      console.log(`❌ Error processing setlists: ${error.message}`)
    } else {
      console.log(`✅ Processed setlists: ${data[0]?.processed_count || 0} records`)
    }
    
    // 4. Check final count
    console.log('📊 Checking final setlists count...')
    
    const { data: finalData, error: finalError } = await supabase
      .from('silver_setlists')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.log(`❌ Error checking final count: ${finalError.message}`)
    } else {
      console.log(`✅ Final setlists count: ${finalData.length} records`)
    }
    
    console.log('\n✅ Setlists reset and reprocessing completed!')
    
  } catch (error) {
    console.error('❌ Reset and reprocess failed:', error)
  }
}

// Run the reset and reprocess
resetAndReprocessSetlists()
  .then(() => {
    console.log('\n🎯 Setlists Reset and Reprocess Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Reset and reprocess failed:', error)
    process.exit(1)
  })

