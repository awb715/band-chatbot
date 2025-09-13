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

async function inspectRawDataStructure() {
  console.log('🔍 Inspecting Raw Data Structure')
  console.log('================================')
  
  try {
    const tables = [
      { name: 'shows', key: 'date' },
      { name: 'setlists', key: 'song' },
      { name: 'venues', key: 'name' },
      { name: 'latest', key: 'type' },
      { name: 'metadata', key: 'key' },
      { name: 'uploads', key: 'filename' },
      { name: 'appearances', key: 'song_id' },
      { name: 'jamcharts', key: 'song' }
    ]
    
    for (const table of tables) {
      console.log(`\n📊 Inspecting ${table.name} data structure...`)
      
      const { data, error } = await supabase
        .from(`raw_data_${table.name}`)
        .select('id, external_id, data')
        .limit(3)
      
      if (error) {
        console.log(`❌ Error: ${error.message}`)
        continue
      }
      
      console.log(`✅ Found ${data.length} sample records`)
      
      data.forEach((record, index) => {
        console.log(`\n📝 Sample ${index + 1}:`)
        console.log(`  ID: ${record.id}`)
        console.log(`  External ID: ${record.external_id}`)
        console.log(`  Data keys: ${Object.keys(record.data).join(', ')}`)
        console.log(`  ${table.key}: ${record.data[table.key]}`)
        
        // Show the full data structure for the first record
        if (index === 0) {
          console.log(`  Full data structure:`)
          console.log(JSON.stringify(record.data, null, 2))
        }
      })
    }
    
    console.log('\n✅ Raw data structure inspection completed!')
    
  } catch (error) {
    console.error('❌ Inspection failed:', error)
  }
}

// Run the inspection
inspectRawDataStructure()
  .then(() => {
    console.log('\n🎯 Raw Data Structure Inspection Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Inspection failed:', error)
    process.exit(1)
  })

