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

async function checkSetlistsDuplicates() {
  console.log('🔍 Checking Setlists for Duplicates')
  console.log('===================================')
  
  try {
    // Get all setlists data
    const { data: setlists, error } = await supabase
      .from('raw_data_setlists')
      .select('id, external_id, data')
      .limit(100)
    
    if (error) {
      console.log(`❌ Error fetching setlists: ${error.message}`)
      return
    }
    
    console.log(`📊 Found ${setlists.length} setlists records`)
    
    // Check for duplicate external_ids
    const externalIds = setlists.map(s => s.external_id)
    const uniqueExternalIds = [...new Set(externalIds)]
    
    console.log(`📊 Unique external_ids: ${uniqueExternalIds.length}`)
    console.log(`📊 Total records: ${externalIds.length}`)
    
    if (uniqueExternalIds.length !== externalIds.length) {
      console.log('⚠️ Found duplicate external_ids!')
      
      // Find duplicates
      const duplicates = externalIds.filter((id, index) => externalIds.indexOf(id) !== index)
      const uniqueDuplicates = [...new Set(duplicates)]
      
      console.log(`📊 Duplicate external_ids: ${uniqueDuplicates.length}`)
      console.log(`📊 Duplicate IDs: ${uniqueDuplicates.slice(0, 10).join(', ')}`)
      
      // Show sample duplicate records
      for (const dupId of uniqueDuplicates.slice(0, 3)) {
        const dupRecords = setlists.filter(s => s.external_id === dupId)
        console.log(`\n📝 Duplicate records for ${dupId}:`)
        dupRecords.forEach((record, index) => {
          console.log(`  ${index + 1}. ID: ${record.id}, Song: ${record.data.songname}`)
        })
      }
    } else {
      console.log('✅ No duplicate external_ids found')
    }
    
    // Check for null or missing required fields
    console.log('\n🔍 Checking for missing required fields...')
    
    const missingFields = setlists.filter(s => 
      !s.data.songname || 
      !s.data.show_id || 
      !s.data.song_id
    )
    
    if (missingFields.length > 0) {
      console.log(`⚠️ Found ${missingFields.length} records with missing required fields`)
      console.log('Sample records with missing fields:')
      missingFields.slice(0, 3).forEach((record, index) => {
        console.log(`  ${index + 1}. ID: ${record.id}`)
        console.log(`     Song: ${record.data.songname}`)
        console.log(`     Show ID: ${record.data.show_id}`)
        console.log(`     Song ID: ${record.data.song_id}`)
      })
    } else {
      console.log('✅ All records have required fields')
    }
    
    console.log('\n✅ Setlists duplicate check completed!')
    
  } catch (error) {
    console.error('❌ Check failed:', error)
  }
}

// Run the check
checkSetlistsDuplicates()
  .then(() => {
    console.log('\n🎯 Setlists Duplicate Check Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Check failed:', error)
    process.exit(1)
  })

