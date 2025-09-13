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

async function testSilverDirect() {
  console.log('🥈 Testing Silver Layer Direct Access')
  console.log('=====================================')
  
  try {
    // Check if we can access Silver layer directly
    console.log('\n🔍 Testing Silver Layer Access:')
    
    // Try to access silver.songs directly
    const { data: silverSongs, error: silverError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
    
    if (silverError) {
      console.error('❌ Cannot access silver_songs:', silverError.message)
      console.log('💡 This suggests the Silver schema is not exposed to the API')
    } else {
      console.log('✅ Can access silver_songs:', silverSongs.length, 'records')
    }
    
    // Check Bronze layer
    console.log('\n🥉 Bronze Layer Check:')
    const { data: bronzeSongs, error: bronzeError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (bronzeError) {
      console.error('❌ Cannot access bronze songs:', bronzeError.message)
    } else {
      console.log('✅ Bronze songs:', bronzeSongs.length)
      
      // Check unprocessed count
      const { data: unprocessed, error: unprocessedError } = await supabase
        .from('raw_data_songs')
        .select('*', { count: 'exact' })
        .eq('is_processed', false)
      
      if (unprocessedError) {
        console.error('❌ Cannot check unprocessed songs:', unprocessedError.message)
      } else {
        console.log('📊 Unprocessed songs:', unprocessed.length)
      }
    }
    
    // Try to run the ETL function using SQL
    console.log('\n🔄 Running ETL via SQL:')
    const { data: etlResult, error: etlError } = await supabase
      .rpc('exec_sql', { 
        sql: 'SELECT silver.process_songs()' 
      })
    
    if (etlError) {
      console.error('❌ ETL via SQL failed:', etlError.message)
      console.log('💡 Trying alternative approach...')
      
      // Try direct SQL execution
      const { data: directResult, error: directError } = await supabase
        .rpc('exec', { 
          query: 'SELECT silver.process_songs()' 
        })
      
      if (directError) {
        console.error('❌ Direct SQL execution failed:', directError.message)
      } else {
        console.log('✅ Direct SQL execution result:', directResult)
      }
    } else {
      console.log('✅ ETL via SQL result:', etlResult)
    }
    
    // Check if we can manually process some data
    console.log('\n🔧 Manual Processing Test:')
    
    // Get a sample of unprocessed songs
    const { data: sampleSongs, error: sampleError } = await supabase
      .from('raw_data_songs')
      .select('*')
      .eq('is_processed', false)
      .limit(3)
    
    if (sampleError) {
      console.error('❌ Cannot get sample songs:', sampleError.message)
    } else {
      console.log(`📊 Sample unprocessed songs: ${sampleSongs.length}`)
      
      if (sampleSongs.length > 0) {
        const sampleSong = sampleSongs[0]
        console.log('📋 Sample song data:')
        console.log(`  - External ID: ${sampleSong.external_id}`)
        console.log(`  - Name: ${sampleSong.data.name}`)
        console.log(`  - Slug: ${sampleSong.data.slug}`)
        console.log(`  - Is Original: ${sampleSong.data.isoriginal}`)
        console.log(`  - Original Artist: ${sampleSong.data.original_artist}`)
      }
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error)
  }
}

// Run the test
testSilverDirect()
  .then(() => {
    console.log('\n🎯 Silver Direct Test Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Test failed:', error)
    process.exit(1)
  })
