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

async function compareRawVsSilverRows() {
  console.log('📊 Raw vs Silver Row Comparison')
  console.log('================================')
  
  try {
    const tables = [
      { raw: 'raw_data_songs', silver: 'silver_songs', name: 'Songs' },
      { raw: 'raw_data_shows', silver: 'silver_shows', name: 'Shows' },
      { raw: 'raw_data_setlists', silver: 'silver_setlists', name: 'Setlists' },
      { raw: 'raw_data_venues', silver: 'silver_venues', name: 'Venues' },
      { raw: 'raw_data_latest', silver: 'silver_latest', name: 'Latest' },
      { raw: 'raw_data_metadata', silver: 'silver_metadata', name: 'Metadata' },
      { raw: 'raw_data_links', silver: 'silver_links', name: 'Links' },
      { raw: 'raw_data_uploads', silver: 'silver_uploads', name: 'Uploads' },
      { raw: 'raw_data_appearances', silver: 'silver_appearances', name: 'Appearances' },
      { raw: 'raw_data_jamcharts', silver: 'silver_jamcharts', name: 'Jamcharts' }
    ]
    
    let totalRawRows = 0
    let totalSilverRows = 0
    let totalProcessed = 0
    
    console.log('\n📋 Detailed Comparison:')
    console.log('=======================')
    
    for (const table of tables) {
      console.log(`\n🔍 ${table.name}:`)
      console.log('─'.repeat(50))
      
      // Get raw data count
      const { data: rawData, error: rawError, count: rawCount } = await supabase
        .from(table.raw)
        .select('*', { count: 'exact' })
        .limit(1)
      
      if (rawError) {
        console.log(`❌ Raw table error: ${rawError.message}`)
        continue
      }
      
      // Get silver data count
      const { data: silverData, error: silverError, count: silverCount } = await supabase
        .from(table.silver)
        .select('*', { count: 'exact' })
        .limit(1)
      
      if (silverError) {
        console.log(`❌ Silver table error: ${silverError.message}`)
        continue
      }
      
      // Get processed count from raw data
      const { data: processedData, error: processedError, count: processedCount } = await supabase
        .from(table.raw)
        .select('*', { count: 'exact' })
        .eq('is_processed', true)
        .limit(1)
      
      if (processedError) {
        console.log(`❌ Processed count error: ${processedError.message}`)
        continue
      }
      
      const rawRows = rawCount || 0
      const silverRows = silverCount || 0
      const processedRows = processedCount || 0
      
      totalRawRows += rawRows
      totalSilverRows += silverRows
      totalProcessed += processedRows
      
      // Calculate percentages
      const processingRate = rawRows > 0 ? ((processedRows / rawRows) * 100).toFixed(1) : '0.0'
      const conversionRate = rawRows > 0 ? ((silverRows / rawRows) * 100).toFixed(1) : '0.0'
      
      console.log(`📊 Raw rows:        ${rawRows.toLocaleString()}`)
      console.log(`📊 Silver rows:     ${silverRows.toLocaleString()}`)
      console.log(`📊 Processed rows:  ${processedRows.toLocaleString()}`)
      console.log(`📈 Processing rate: ${processingRate}%`)
      console.log(`📈 Conversion rate: ${conversionRate}%`)
      
      // Status indicators
      if (silverRows === 0) {
        console.log(`❌ Status: No data in Silver layer`)
      } else if (silverRows === rawRows) {
        console.log(`✅ Status: Perfect match`)
      } else if (silverRows < rawRows) {
        console.log(`⚠️  Status: Partial processing (${rawRows - silverRows} rows missing)`)
      } else {
        console.log(`⚠️  Status: More Silver rows than Raw (${silverRows - rawRows} extra rows)`)
      }
      
      // Check for data quality issues
      if (silverRows > 0) {
        // Sample a few records to check data quality
        const { data: sampleData, error: sampleError } = await supabase
          .from(table.silver)
          .select('*')
          .limit(3)
        
        if (!sampleError && sampleData.length > 0) {
          console.log(`🔍 Sample data quality:`)
          sampleData.forEach((record, index) => {
            const nullFields = Object.entries(record)
              .filter(([key, value]) => value === null || value === undefined)
              .map(([key]) => key)
            
            if (nullFields.length > 0) {
              console.log(`   Record ${index + 1}: ${nullFields.length} null fields (${nullFields.slice(0, 3).join(', ')}${nullFields.length > 3 ? '...' : ''})`)
            } else {
              console.log(`   Record ${index + 1}: Clean data`)
            }
          })
        }
      }
    }
    
    // Summary
    console.log('\n📊 Overall Summary:')
    console.log('==================')
    console.log(`📊 Total Raw rows:     ${totalRawRows.toLocaleString()}`)
    console.log(`📊 Total Silver rows:  ${totalSilverRows.toLocaleString()}`)
    console.log(`📊 Total Processed:    ${totalProcessed.toLocaleString()}`)
    
    const overallProcessingRate = totalRawRows > 0 ? ((totalProcessed / totalRawRows) * 100).toFixed(1) : '0.0'
    const overallConversionRate = totalRawRows > 0 ? ((totalSilverRows / totalRawRows) * 100).toFixed(1) : '0.0'
    
    console.log(`📈 Overall processing rate: ${overallProcessingRate}%`)
    console.log(`📈 Overall conversion rate: ${overallConversionRate}%`)
    
    // Recommendations
    console.log('\n💡 Recommendations:')
    console.log('==================')
    
    if (totalSilverRows === 0) {
      console.log('❌ No Silver data found - run ETL processing')
    } else if (totalSilverRows < totalRawRows) {
      console.log('⚠️  Incomplete processing - consider running full ETL')
    } else if (totalSilverRows === totalRawRows) {
      console.log('✅ Perfect data conversion - Silver layer is complete')
    } else {
      console.log('⚠️  More Silver rows than Raw - investigate data duplication')
    }
    
    if (overallProcessingRate < 100) {
      console.log('🔄 Some raw data not yet processed - run ETL functions')
    }
    
    console.log('\n✅ Raw vs Silver comparison completed!')
    
  } catch (error) {
    console.error('❌ Comparison failed:', error)
  }
}

// Run the comparison
compareRawVsSilverRows()
  .then(() => {
    console.log('\n🎯 Raw vs Silver Row Comparison Complete!')
    process.exit(0)
  })
  .catch(error => {
    console.error('❌ Comparison failed:', error)
    process.exit(1)
  })

