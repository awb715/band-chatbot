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

async function implementSilverETL() {
  console.log('🥈 Implementing Silver Layer ETL Processing')
  console.log('==========================================')
  
  try {
    // Get unprocessed songs from Bronze layer
    console.log('\n🥉 Getting unprocessed songs from Bronze layer...')
    const { data: unprocessedSongs, error: unprocessedError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .eq('is_processed', false)
    
    if (unprocessedError) {
      console.error('❌ Failed to get unprocessed songs:', unprocessedError.message)
      return
    }
    
    console.log(`📊 Found ${unprocessedSongs.length} unprocessed songs`)
    
    if (unprocessedSongs.length === 0) {
      console.log('✅ No unprocessed songs found!')
      return
    }
    
    // Process songs in batches
    console.log('\n🔄 Processing songs to Silver layer...')
    const batchSize = 100
    let processedCount = 0
    let errorCount = 0
    
    for (let i = 0; i < unprocessedSongs.length; i += batchSize) {
      const batch = unprocessedSongs.slice(i, i + batchSize)
      console.log(`📦 Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(unprocessedSongs.length/batchSize)} (${batch.length} songs)`)
      
      // Transform Bronze data to Silver format
      const silverData = batch.map(song => ({
        external_id: song.external_id,
        name: song.data.name,
        slug: song.data.slug,
        is_original: song.data.isoriginal === 1 || song.data.isoriginal === true,
        original_artist: song.data.original_artist || null,
        created_at: song.data.created_at ? new Date(song.data.created_at).toISOString() : null,
        updated_at: song.data.updated_at ? new Date(song.data.updated_at).toISOString() : null,
        source_raw_id: song.id,
        processed_at: new Date().toISOString()
      }))
      
      // Insert into Silver layer
      const { error: insertError } = await supabase
        .from('silver_songs')
        .upsert(silverData, { 
          onConflict: 'external_id',
          ignoreDuplicates: false 
        })
      
      if (insertError) {
        console.error(`❌ Failed to insert batch ${Math.floor(i/batchSize) + 1}:`, insertError.message)
        errorCount += batch.length
        continue
      }
      
      processedCount += batch.length
      console.log(`✅ Processed ${batch.length} songs (${processedCount}/${unprocessedSongs.length} total)`)
    }
    
    // Mark Bronze records as processed
    console.log('\n🏷️ Marking Bronze records as processed...')
    const { error: updateError } = await supabase
      .from('raw_data_songs')
      .update({ is_processed: true })
      .eq('is_processed', false)
    
    if (updateError) {
      console.error('❌ Failed to mark records as processed:', updateError.message)
    } else {
      console.log('✅ Bronze records marked as processed')
    }
    
    // Verify results
    console.log('\n🔍 Verifying results...')
    
    // Check Silver layer count
    const { data: silverSongs, error: silverError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
    
    if (silverError) {
      console.error('❌ Failed to get Silver songs count:', silverError.message)
    } else {
      console.log(`📊 Silver songs: ${silverSongs.length}`)
    }
    
    // Check remaining unprocessed Bronze records
    const { data: remainingUnprocessed, error: remainingError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
      .eq('is_processed', false)
    
    if (remainingError) {
      console.error('❌ Failed to get remaining unprocessed count:', remainingError.message)
    } else {
      console.log(`📊 Remaining unprocessed Bronze records: ${remainingUnprocessed.length}`)
    }
    
    // Show sample Silver data
    console.log('\n📋 Sample Silver Songs:')
    const { data: sampleSilverSongs, error: sampleError } = await supabase
      .from('silver_songs')
      .select('*')
      .limit(5)
    
    if (sampleError) {
      console.error('❌ Failed to get sample Silver songs:', sampleError.message)
    } else {
      sampleSilverSongs.forEach(song => {
        console.log(`  - ${song.external_id}: ${song.name} (${song.is_original ? 'Original' : 'Cover'})`)
        if (song.original_artist) {
          console.log(`    Original Artist: ${song.original_artist}`)
        }
      })
    }
    
    // Summary
    console.log('\n📊 ETL Processing Summary:')
    console.log(`✅ Processed: ${processedCount} songs`)
    console.log(`❌ Errors: ${errorCount} songs`)
    console.log(`📈 Success Rate: ${((processedCount / (processedCount + errorCount)) * 100).toFixed(1)}%`)
    
  } catch (error) {
    console.error('❌ ETL processing failed:', error)
  }
}

// Run the ETL
implementSilverETL()
  .then(() => {
    console.log('\n🎯 Silver ETL Implementation Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ ETL failed:', error)
    process.exit(1)
  })
