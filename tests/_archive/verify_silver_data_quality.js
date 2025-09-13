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

async function verifySilverDataQuality() {
  console.log('🔍 Verifying Silver Layer Data Quality')
  console.log('=====================================')
  
  try {
    // Get counts from both layers
    console.log('\n📊 Data Counts:')
    
    const { data: bronzeSongs, error: bronzeError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
    
    if (bronzeError) {
      console.error('❌ Failed to get Bronze count:', bronzeError.message)
      return
    }
    
    const { data: silverSongs, error: silverError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
    
    if (silverError) {
      console.error('❌ Failed to get Silver count:', silverError.message)
      return
    }
    
    console.log(`🥉 Bronze songs: ${bronzeSongs.length}`)
    console.log(`🥈 Silver songs: ${silverSongs.length}`)
    console.log(`📊 Processing ratio: ${((silverSongs.length / bronzeSongs.length) * 100).toFixed(1)}%`)
    
    // Check data completeness
    console.log('\n🔍 Data Completeness Check:')
    
    // Check for null names
    const { data: nullNames, error: nullNamesError } = await supabase
      .from('silver_songs')
      .select('external_id')
      .is('name', null)
    
    if (nullNamesError) {
      console.error('❌ Failed to check null names:', nullNamesError.message)
    } else {
      console.log(`✅ Null names: ${nullNames.length} (should be 0)`)
    }
    
    // Check for null slugs
    const { data: nullSlugs, error: nullSlugsError } = await supabase
      .from('silver_songs')
      .select('external_id')
      .is('slug', null)
    
    if (nullSlugsError) {
      console.error('❌ Failed to check null slugs:', nullSlugsError.message)
    } else {
      console.log(`✅ Null slugs: ${nullSlugs.length} (should be 0)`)
    }
    
    // Check for null external_ids
    const { data: nullExternalIds, error: nullExternalIdsError } = await supabase
      .from('silver_songs')
      .select('id')
      .is('external_id', null)
    
    if (nullExternalIdsError) {
      console.error('❌ Failed to check null external_ids:', nullExternalIdsError.message)
    } else {
      console.log(`✅ Null external_ids: ${nullExternalIds.length} (should be 0)`)
    }
    
    // Check data distribution
    console.log('\n📊 Data Distribution:')
    
    // Count originals vs covers
    const { data: originals, error: originalsError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
      .eq('is_original', true)
    
    if (originalsError) {
      console.error('❌ Failed to count originals:', originalsError.message)
    } else {
      console.log(`🎵 Original songs: ${originals.length}`)
    }
    
    const { data: covers, error: coversError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
      .eq('is_original', false)
    
    if (coversError) {
      console.error('❌ Failed to count covers:', coversError.message)
    } else {
      console.log(`🎤 Cover songs: ${covers.length}`)
    }
    
    // Check songs with original artists
    const { data: withOriginalArtist, error: withOriginalArtistError } = await supabase
      .from('silver_songs')
      .select('*', { count: 'exact' })
      .not('original_artist', 'is', null)
    
    if (withOriginalArtistError) {
      console.error('❌ Failed to count songs with original artists:', withOriginalArtistError.message)
    } else {
      console.log(`🎭 Songs with original artist: ${withOriginalArtist.length}`)
    }
    
    // Check data quality
    console.log('\n🔍 Data Quality Check:')
    
    // Check for duplicate external_ids
    const { data: duplicateCheck, error: duplicateError } = await supabase
      .from('silver_songs')
      .select('external_id')
      .order('external_id')
    
    if (duplicateError) {
      console.error('❌ Failed to check duplicates:', duplicateError.message)
    } else {
      const externalIds = duplicateCheck.map(song => song.external_id)
      const uniqueIds = new Set(externalIds)
      console.log(`✅ Duplicate external_ids: ${externalIds.length - uniqueIds.size} (should be 0)`)
    }
    
    // Check for empty strings
    const { data: emptyNames, error: emptyNamesError } = await supabase
      .from('silver_songs')
      .select('external_id')
      .eq('name', '')
    
    if (emptyNamesError) {
      console.error('❌ Failed to check empty names:', emptyNamesError.message)
    } else {
      console.log(`✅ Empty names: ${emptyNames.length} (should be 0)`)
    }
    
    // Check date formatting
    console.log('\n📅 Date Formatting Check:')
    
    const { data: dateCheck, error: dateError } = await supabase
      .from('silver_songs')
      .select('external_id, created_at, updated_at')
      .not('created_at', 'is', null)
      .limit(5)
    
    if (dateError) {
      console.error('❌ Failed to check dates:', dateError.message)
    } else {
      console.log('📅 Sample dates:')
      dateCheck.forEach(song => {
        console.log(`  - ${song.external_id}: created=${song.created_at}, updated=${song.updated_at}`)
      })
    }
    
    // Show sample data
    console.log('\n📋 Sample Silver Data:')
    
    const { data: sampleData, error: sampleError } = await supabase
      .from('silver_songs')
      .select('*')
      .limit(10)
    
    if (sampleError) {
      console.error('❌ Failed to get sample data:', sampleError.message)
    } else {
      sampleData.forEach(song => {
        console.log(`  - ${song.external_id}: ${song.name}`)
        console.log(`    Slug: ${song.slug}`)
        console.log(`    Type: ${song.is_original ? 'Original' : 'Cover'}`)
        if (song.original_artist) {
          console.log(`    Original Artist: ${song.original_artist}`)
        }
        console.log(`    Processed: ${song.processed_at}`)
        console.log('')
      })
    }
    
    // Check Bronze layer processing status
    console.log('\n🥉 Bronze Layer Processing Status:')
    
    const { data: processedBronze, error: processedError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
      .eq('is_processed', true)
    
    if (processedError) {
      console.error('❌ Failed to check processed Bronze records:', processedError.message)
    } else {
      console.log(`✅ Processed Bronze records: ${processedBronze.length}`)
    }
    
    const { data: unprocessedBronze, error: unprocessedError } = await supabase
      .from('raw_data_songs')
      .select('*', { count: 'exact' })
      .eq('is_processed', false)
    
    if (unprocessedError) {
      console.error('❌ Failed to check unprocessed Bronze records:', unprocessedError.message)
    } else {
      console.log(`📊 Unprocessed Bronze records: ${unprocessedBronze.length}`)
    }
    
    // Summary
    console.log('\n📊 Silver Layer Quality Summary:')
    console.log(`✅ Total songs processed: ${silverSongs.length}`)
    console.log(`✅ Data completeness: ${nullNames.length === 0 && nullSlugs.length === 0 ? 'PASS' : 'FAIL'}`)
    console.log(`✅ Data uniqueness: ${externalIds.length - uniqueIds.size === 0 ? 'PASS' : 'FAIL'}`)
    console.log(`✅ Bronze processing: ${unprocessedBronze.length === 0 ? 'COMPLETE' : 'INCOMPLETE'}`)
    
  } catch (error) {
    console.error('❌ Verification failed:', error)
  }
}

// Run the verification
verifySilverDataQuality()
  .then(() => {
    console.log('\n🎯 Silver Data Quality Verification Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Verification failed:', error)
    process.exit(1)
  })
