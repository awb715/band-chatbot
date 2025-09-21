/**
 * OPTIMIZED RAW DATA INGESTION EDGE FUNCTION
 * ==========================================
 * 
 * CORE FUNCTION: SMART INCREMENTAL UPDATER WITH PERFORMANCE LIMITS
 * 
 * This Edge Function implements an optimized incremental update strategy that:
 * 1. Fetches RECENT data from ElGoose API endpoints (7-day window)
 * 2. Processes records in small batches to avoid timeouts
 * 3. Uses endpoint-specific limits for optimal performance
 * 4. Supports both incremental and manual processing modes
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - Endpoint-specific row limits (setlists: 100, songs: 100, etc.)
 * - 7-day data window for incremental updates
 * - API sorting by updated_at for recent data first
 * - Batch processing to prevent timeouts
 * - Parallel processing support via GitHub Actions
 * 
 * PROCESSING MODES:
 * - INCREMENTAL: Recent data only (7-day window, optimized limits)
 * - MANUAL: Full data processing (higher limits, all data)
 * 
 * Usage:
 * - Daily automated updates via GitHub Actions (incremental mode)
 * - Manual full updates via GitHub Actions (manual mode)
 * - Individual endpoint testing and debugging
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORS headers for web requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// PROCESSING LIMITS PER ENDPOINT
// These limits are optimized for performance and timeout prevention
const PROCESSING_LIMITS = {
  setlists: 1000,   // INCREASED: Setlists can be up to 4k, need higher limit for recent data
  songs: 100,       // 100 songs
  shows: 50,        // 50 shows
  venues: 50,       // 50 venues
  latest: 20,       // 20 latest items
  metadata: 50,     // 50 metadata records
  links: 50,        // 50 links
  uploads: 50,      // 50 uploads
  appearances: 50   // 50 appearances
} as const

// INCREMENTAL UPDATE WINDOW (days)
const INCREMENTAL_WINDOW_DAYS = 7

// Interface for API source configuration from our api_sources table
interface ApiSource {
  id: string;
  name: string;
  url: string;
  description: string;
  is_active: boolean;
  last_updated?: string;
}

// Interface for tracking ingestion results per endpoint
interface IngestionResult {
  endpoint: string;
  total_fetched: number;
  new_records: number;
  updated_records: number;
  errors: string[];
  processing_time_ms: number;
}

/**
 * MAIN EDGE FUNCTION HANDLER
 * ==========================
 * 
 * This is the main entry point for the Edge Function. It handles HTTP requests,
 * initializes the Supabase client, and orchestrates the data ingestion process.
 */
serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client with service role key for full database access
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('🔄 Starting raw data ingestion...')

    // STEP 1: Get all active API sources from our configuration table
    // This tells us which ElGoose endpoints we should fetch data from
    let query = supabaseClient
      .from('api_sources')
      .select('*')
      .eq('is_active', true)
    
    // Parse request body for endpoint and mode
    const body = await req.json().catch(() => ({}))
    const { endpoint, mode = 'incremental', yearData } = body
    
    if (endpoint) {
      query = query.eq('name', endpoint)
      console.log(`🎯 Filtering to specific endpoint: ${endpoint}`)
    }
    
    console.log(`🔄 Processing mode: ${mode}`)
    
    // If yearData is provided, we need setlists endpoint info for processing
    if (yearData && !endpoint) {
      query = query.eq('name', 'Setlists')
      console.log(`📁 Year data provided, defaulting to Setlists endpoint`)
    }
    
    const { data: endpoints, error: endpointsError } = await query

    if (endpointsError) {
      throw new Error(`Failed to fetch API sources: ${endpointsError.message}`)
    }

    console.log(`📡 Found ${endpoints.length} active endpoints`)

    // Initialize tracking variables for overall results
    const results: IngestionResult[] = []
    let totalNewRecords = 0
    let totalUpdatedRecords = 0

    // STEP 2: Process each endpoint sequentially
    // We process them one by one to avoid overwhelming the ElGoose API
    for (const endpoint of endpoints) {
      console.log(`\n🔍 Processing ${endpoint.name}...`)
      
      // Track processing time for performance monitoring
      const startTime = Date.now()
      const result = await processEndpoint(supabaseClient, endpoint, mode, yearData)
      const processingTime = Date.now() - startTime
      
      // Store results with timing information
      result.processing_time_ms = processingTime
      results.push(result)
      
      // Accumulate totals for summary
      totalNewRecords += result.new_records
      totalUpdatedRecords += result.updated_records
      
      console.log(`✅ ${endpoint.name}: ${result.new_records} new, ${result.updated_records} updated records`)
    }

    // STEP 3: Return comprehensive results
    console.log(`\n🎉 Ingestion complete! Total: ${totalNewRecords} new, ${totalUpdatedRecords} updated records`)

    return new Response(
      JSON.stringify({ 
        success: true,
        total_new_records: totalNewRecords,
        total_updated_records: totalUpdatedRecords,
        results
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('❌ Error in ingest_raw_data function:', error)
    
    return new Response(
      JSON.stringify({ 
        error: error.message,
        success: false 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

/**
 * PROCESS ENDPOINT FUNCTION
 * =========================
 * 
 * This function handles the processing of a single ElGoose API endpoint.
 * It fetches data from the API with optimized limits and filtering,
 * processes each record, and stores them in the appropriate raw_data table.
 * 
 * @param supabaseClient - Supabase client instance
 * @param endpoint - API source configuration from api_sources table
 * @param mode - Processing mode ('incremental' or 'manual')
 * @returns IngestionResult with statistics about the processing
 */
async function processEndpoint(
  supabaseClient: any,
  endpoint: ApiSource,
  mode: string = 'incremental',
  yearData?: any
): Promise<IngestionResult> {
  // Initialize result tracking for this endpoint
  const result: IngestionResult = {
    endpoint: endpoint.name,
    total_fetched: 0,
    new_records: 0,
    updated_records: 0,
    errors: [],
    processing_time_ms: 0
  }

  try {
    // STEP 1: Get processing limit for this endpoint (handle case variations)
    const endpointKey = endpoint.name.toLowerCase() as keyof typeof PROCESSING_LIMITS
    const limit = PROCESSING_LIMITS[endpointKey] || 50
    console.log(`📊 Processing limit for ${endpoint.name} (${endpointKey}): ${limit} records`)
    
    // STEP 2: Handle data source - either from yearData or API
    let allData = []
    
    if (yearData) {
      // Use provided year data instead of API call
      console.log(`📁 Using provided year data with ${yearData.length} records`)
      allData = yearData
    } else if (endpoint.name.toLowerCase() === 'setlists') {
      // Setlists needs special pagination handling due to large dataset
      console.log('🎵 Setlists endpoint detected - implementing pagination strategy')
      
      if (mode === 'incremental') {
        // For incremental: Start from the end (most recent data) and work backwards
        // Get the total count first, then fetch recent pages
        console.log('🔄 Incremental mode: fetching recent setlists from end of dataset')
        
        // Estimate total records and start from recent data
        const startOffset = Math.max(0, 8000) // Start from where recent data likely is
        const fetchLimit = 1000
        
        const apiUrl = `${endpoint.url}?offset=${startOffset}&limit=${fetchLimit}`
        console.log(`📥 Fetching recent data from ${apiUrl}`)
        
        const response = await fetch(apiUrl)
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        
        const responseData = await response.json()
        allData = responseData.data || responseData || []
        
      } else {
        // For manual mode: Implement pagination to get ALL data
        console.log('🔄 Manual mode: implementing full pagination for complete dataset')
        
        let offset = 0
        const pageSize = 4000 // Max API limit
        let hasMoreData = true
        
        while (hasMoreData && allData.length < 20000) { // Safety limit
          const apiUrl = `${endpoint.url}?offset=${offset}&limit=${pageSize}`
          console.log(`📥 Fetching page at offset ${offset} from ${apiUrl}`)
          
          const response = await fetch(apiUrl)
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`)
          }
          
          const responseData = await response.json()
          const pageData = responseData.data || responseData || []
          
          if (Array.isArray(pageData) && pageData.length > 0) {
            allData = allData.concat(pageData)
            offset += pageData.length
            hasMoreData = pageData.length === pageSize // Continue if we got a full page
            console.log(`📊 Page complete: ${pageData.length} records, total so far: ${allData.length}`)
          } else {
            hasMoreData = false
            console.log('📊 No more data available')
          }
          
          // Small delay to be respectful to the API
          await new Promise(resolve => setTimeout(resolve, 100))
        }
        
        console.log(`🎉 Pagination complete: ${allData.length} total records fetched`)
      }
      
    } else {
      // For other endpoints, use the original single-request approach
      const apiUrl = endpoint.url
      console.log(`📥 Fetching data from ${apiUrl}`)
      
      const response = await fetch(apiUrl)
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const responseData = await response.json()
      allData = responseData.data || responseData || []
    }
    
    // Set the data for processing
    const data = allData
    result.total_fetched = Array.isArray(data) ? data.length : 1
    console.log(`📊 Total records received: ${result.total_fetched}`)

    // STEP 3: Smart filtering and processing strategy
    let recordsToProcess = Array.isArray(data) ? data : [data]
    
    if (mode === 'incremental') {
      if (endpoint.name.toLowerCase() === 'setlists') {
        // For setlists incremental: we already fetched from offset 8000+ (recent data)
        // Process the most recent records we got
        console.log(`📅 Incremental setlists: processing all ${recordsToProcess.length} recent records from offset 8000+`)
      } else {
        // For other endpoints, use date-based filtering
        const cutoffDate = new Date()
        cutoffDate.setDate(cutoffDate.getDate() - INCREMENTAL_WINDOW_DAYS)
        
        const originalCount = recordsToProcess.length
        recordsToProcess = recordsToProcess.filter(record => {
          const recordDate = record.updated_at || record.created_at || record.showdate
          return recordDate && new Date(recordDate) >= cutoffDate
        })
        
        console.log(`📅 Filtered from ${originalCount} to ${recordsToProcess.length} recent records (last ${INCREMENTAL_WINDOW_DAYS} days)`)
        
        if (recordsToProcess.length === 0 && originalCount > 0) {
          recordsToProcess = Array.isArray(data) ? data.slice(0, Math.min(100, data.length)) : [data]
          console.log(`📅 No recent records by date, processing ${recordsToProcess.length} latest records`)
        }
      }
    } else {
      // Manual mode: process all fetched records (could be 10k+ for setlists)
      // Apply reasonable batch limits to prevent timeouts
      if (recordsToProcess.length > 5000) {
        recordsToProcess = recordsToProcess.slice(0, 5000)
        console.log(`📊 Manual mode: limited to first ${recordsToProcess.length} records to prevent timeouts`)
      } else {
        console.log(`📊 Manual mode: processing all ${recordsToProcess.length} fetched records`)
      }
    }
    
    // STEP 5: Apply final limit to prevent timeouts
    if (recordsToProcess.length > limit) {
      recordsToProcess = recordsToProcess.slice(0, limit)
      console.log(`✂️ Limited to ${recordsToProcess.length} records to prevent timeouts`)
    }

    // STEP 6: Determine the target table name
    const tableName = endpoint.name.toLowerCase()
    console.log(`📊 Processing ${recordsToProcess.length} records from ${endpoint.name}`)
    
    for (const record of recordsToProcess) {
      try {
        // Process the individual record (check for duplicates, insert/update)
        const recordResult = await processRecord(supabaseClient, tableName, record, endpoint.url)
        
        // Track the results
        if (recordResult.isNew) {
          result.new_records++
        } else if (recordResult.isUpdated) {
          result.updated_records++
        }
      } catch (recordError) {
        console.error(`❌ Error processing record:`, recordError)
        result.errors.push(`Record error: ${recordError.message}`)
      }
    }

    // STEP 4: Update the last_updated timestamp for this endpoint
    // This helps us track when we last successfully processed this endpoint
    await supabaseClient
      .from('api_sources')
      .update({ last_updated: new Date().toISOString() })
      .eq('id', endpoint.id)

  } catch (error) {
    console.error(`❌ Error processing ${endpoint.name}:`, error)
    result.errors.push(`Endpoint error: ${error.message}`)
  }

  return result
}

/**
 * PROCESS RECORD FUNCTION
 * =======================
 * 
 * This function handles the incremental update logic for individual records.
 * It checks if a record already exists in the database and either:
 * - Inserts a new record if it doesn't exist
 * - Updates an existing record if the data has changed
 * - Skips the record if it exists and hasn't changed
 * 
 * This prevents duplicates and ensures we only process new/changed data.
 * 
 * @param supabaseClient - Supabase client instance
 * @param tableName - Name of the raw_data table to insert into
 * @param record - The JSON record from the ElGoose API
 * @param sourceUrl - The original API URL for tracking
 * @returns Object indicating if record was new, updated, or skipped
 */
async function processRecord(
  supabaseClient: any, 
  tableName: string, 
  record: any, 
  sourceUrl: string
): Promise<{ isNew: boolean; isUpdated: boolean }> {
  
  // STEP 1: Extract external ID from the record
  // Different ElGoose endpoints use different ID field names
  const externalId = record.id || record.show_id || record.song_id || record.venue_id || record.slug || null
  
  // STEP 2: Check if this record already exists in our database
  // We use the external_id to identify existing records
  const { data: existingRecord } = await supabaseClient
    .from(`raw_data.${tableName}`)
    .select('id, data, version')
    .eq('external_id', externalId)
    .single()

  if (existingRecord) {
    // STEP 3A: Record exists - check if data has changed
    const dataChanged = JSON.stringify(existingRecord.data) !== JSON.stringify(record)
    
    if (dataChanged) {
      // Data has changed - update the existing record
      await supabaseClient
        .from(`raw_data.${tableName}`)
        .update({
          data: record,                    // Update with new data
          version: existingRecord.version + 1,  // Increment version number
          updated_at: new Date().toISOString()  // Update timestamp
        })
        .eq('id', existingRecord.id)
      
      return { isNew: false, isUpdated: true }
    } else {
      // No changes detected - skip this record
      return { isNew: false, isUpdated: false }
    }
  } else {
    // STEP 3B: Record doesn't exist - insert as new record
    await supabaseClient
      .from(`raw_data.${tableName}`)
      .insert({
        external_id: externalId,    // Store the original ID from ElGoose
        data: record,               // Store the complete JSON record
        source_url: sourceUrl,      // Track which API endpoint this came from
        is_processed: false         // Mark as unprocessed (for vectorization later)
      })
    
    return { isNew: true, isUpdated: false }
  }
}

// Helper function to get processing statistics
async function getProcessingStats(supabaseClient: any, tableName: string) {
  const { data } = await supabaseClient.rpc('get_processing_stats', { table_name: tableName })
  return data?.[0] || { total_records: 0, processed_records: 0, unprocessed_records: 0 }
}
