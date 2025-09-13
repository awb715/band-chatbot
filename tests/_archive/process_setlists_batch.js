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

async function processSetlistsBatch() {
  console.log('🔄 Processing Setlists in Batches')
  console.log('=================================')
  
  try {
    // Get unprocessed setlists
    const { data: unprocessed, error: fetchError } = await supabase
      .from('raw_data_setlists')
      .select('id, external_id, data')
      .eq('is_processed', false)
      .limit(100)
    
    if (fetchError) {
      console.log(`❌ Error fetching unprocessed setlists: ${fetchError.message}`)
      return
    }
    
    console.log(`📊 Found ${unprocessed.length} unprocessed setlists`)
    
    if (unprocessed.length === 0) {
      console.log('✅ No unprocessed setlists found')
      return
    }
    
    // Process in batches
    const batchSize = 50
    let processed = 0
    
    for (let i = 0; i < unprocessed.length; i += batchSize) {
      const batch = unprocessed.slice(i, i + batchSize)
      console.log(`\n🔄 Processing batch ${Math.floor(i / batchSize) + 1} (${batch.length} records)...`)
      
      // Insert batch
      const { error: insertError } = await supabase
        .from('silver_setlists')
        .insert(batch.map(record => ({
          external_id: record.external_id,
          show_id: record.data.show_id?.toString(),
          song_name: record.data.songname,
          song_id: record.data.song_id?.toString(),
          position: record.data.position,
          is_original: record.data.isoriginal || false,
          original_artist: record.data.original_artist,
          created_at: record.data.created_at,
          updated_at: record.data.updated_at,
          source_raw_id: record.id
        })))
      
      if (insertError) {
        console.log(`❌ Error inserting batch: ${insertError.message}`)
        continue
      }
      
      // Mark as processed
      const { error: updateError } = await supabase
        .from('raw_data_setlists')
        .update({ is_processed: true })
        .in('id', batch.map(r => r.id))
      
      if (updateError) {
        console.log(`❌ Error updating batch: ${updateError.message}`)
      } else {
        processed += batch.length
        console.log(`✅ Processed ${batch.length} records`)
      }
    }
    
    console.log(`\n✅ Total processed: ${processed} records`)
    
    // Check final count
    const { data: finalData, error: finalError } = await supabase
      .from('silver_setlists')
      .select('*', { count: 'exact' })
    
    if (finalError) {
      console.log(`❌ Error checking final count: ${finalError.message}`)
    } else {
      console.log(`📊 Final setlists count: ${finalData.length} records`)
    }
    
    console.log('\n✅ Setlists batch processing completed!')
    
  } catch (error) {
    console.error('❌ Batch processing failed:', error)
  }
}

// Run the batch processing
processSetlistsBatch()
  .then(() => {
    console.log('\n🎯 Setlists Batch Processing Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Batch processing failed:', error)
    process.exit(1)
  })

