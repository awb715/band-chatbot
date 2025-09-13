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

async function testSilverETL() {
  console.log('🥈 Testing Silver Layer ETL Processing')
  console.log('======================================')
  
  try {
    // Check Bronze layer status
    console.log('\n🥉 Bronze Layer Status:')
    const { data: bronzeSongs, error: bronzeError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (bronzeError) {
      console.error('❌ Failed to get bronze songs:', bronzeError.message)
      return
    }
    
    console.log(`📊 Bronze songs: ${bronzeSongs.length}`)
    
    // Check how many are unprocessed
    const { data: unprocessedSongs, error: unprocessedError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
      .eq('is_processed', false)
    
    if (unprocessedError) {
      console.error('❌ Failed to get unprocessed songs:', unprocessedError.message)
      return
    }
    
    console.log(`📊 Unprocessed songs: ${unprocessedSongs.length}`)
    
    // Check Silver layer status
    console.log('\n🥈 Silver Layer Status:')
    const { data: silverSongs, error: silverError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
    
    if (silverError) {
      console.error('❌ Failed to get silver songs:', silverError.message)
      return
    }
    
    console.log(`📊 Silver songs: ${silverSongs.length}`)
    
    // Run the ETL process
    console.log('\n🔄 Running Silver ETL Process...')
    const { data: etlResult, error: etlError } = await supabase
      .rpc('process_songs')
    
    if (etlError) {
      console.error('❌ ETL process failed:', etlError.message)
      return
    }
    
    console.log('✅ ETL process completed!')
    console.log('📊 ETL Results:', etlResult)
    
    // Check Silver layer after processing
    console.log('\n🥈 Silver Layer After Processing:')
    const { data: silverSongsAfter, error: silverAfterError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
    
    if (silverAfterError) {
      console.error('❌ Failed to get silver songs after processing:', silverAfterError.message)
      return
    }
    
    console.log(`📊 Silver songs after processing: ${silverSongsAfter.length}`)
    
    // Show some sample Silver data
    console.log('\n📋 Sample Silver Songs:')
    const { data: sampleSilverSongs, error: sampleError } = await supabase
      .from('silver_songs')
      .select('*')
      .limit(5)
    
    if (sampleError) {
      console.error('❌ Failed to get sample silver songs:', sampleError.message)
    } else {
      sampleSilverSongs.forEach(song => {
        console.log(`  - ${song.external_id}: ${song.name} (${song.is_original ? 'Original' : 'Cover'})`)
      })
    }
    
    // Check processing status
    console.log('\n📊 Processing Status:')
    const { data: processingStatus, error: statusError } = await supabase
      .from('processing_status')
      .select('*')
      .order('completed_at', { ascending: false })
      .limit(5)
    
    if (statusError) {
      console.error('❌ Failed to get processing status:', statusError.message)
    } else {
      processingStatus.forEach(status => {
        console.log(`  - ${status.table_name} (${status.layer}): ${status.status} - ${status.records_processed} records at ${status.completed_at}`)
      })
    }
    
    // Verify data quality
    console.log('\n🔍 Data Quality Check:')
    const { data: qualityCheck, error: qualityError } = await supabase
      .from('silver_songs')
      .select('name, slug, is_original, original_artist')
      .is('name', null)
      .limit(1)
    
    if (qualityError) {
      console.error('❌ Failed to check data quality:', qualityError.message)
    } else {
      if (qualityCheck.length === 0) {
        console.log('✅ No null names found - data quality looks good!')
      } else {
        console.log('⚠️ Found null names - data quality issue!')
      }
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error)
  }
}

// Run the test
testSilverETL()
  .then(() => {
    console.log('\n🎯 Silver ETL Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
