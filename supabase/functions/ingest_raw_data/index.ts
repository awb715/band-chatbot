/**
 * RAW DATA INGESTION EDGE FUNCTION
 * ================================
 * 
 * CORE FUNCTION: RECORD-LEVEL INCREMENTAL UPDATER
 * 
 * This Edge Function implements a smart incremental update strategy that:
 * 1. Fetches COMPLETE JSON responses from all ElGoose API endpoints
 * 2. Processes each individual record to determine if it's NEW, CHANGED, or UNCHANGED
 * 3. Only processes records that are actually new or have changed
 * 4. Stores complete JSON data in raw_data tables with version tracking
 * 
 * KEY INSIGHT: This is NOT a full replacement strategy - it's a record-level
 * incremental updater that preserves data history and only processes what's
 * actually new or different.
 * 
 * Deduplication Strategy:
 * - Uses external IDs (id, show_id, song_id, venue_id, slug) to identify records
 * - Compares JSON data to detect actual changes
 * - Tracks version numbers and timestamps for all updates
 * 
 * Processing Logic:
 * - NEW records: Insert complete JSON data
 * - CHANGED records: Update existing record, increment version
 * - UNCHANGED records: Skip entirely (no processing)
 * 
 * Usage:
 * - Can be triggered manually via API call
 * - Can be scheduled to run daily via cron job
 * - Returns detailed statistics about new/updated/skipped records
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// CORS headers for web requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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
    
    // Check if request specifies a particular endpoint
    const body = await req.json().catch(() => ({}))
    if (body.endpoint) {
      query = query.eq('name', body.endpoint)
      console.log(`🎯 Filtering to specific endpoint: ${body.endpoint}`)
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
      const result = await processEndpoint(supabaseClient, endpoint)
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
 * It fetches data from the API, processes each record, and stores them in
 * the appropriate raw_data table with incremental update logic.
 * 
 * @param supabaseClient - Supabase client instance
 * @param endpoint - API source configuration from api_sources table
 * @returns IngestionResult with statistics about the processing
 */
async function processEndpoint(supabaseClient: any, endpoint: ApiSource): Promise<IngestionResult> {
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
    // STEP 1: Fetch data from the ElGoose API endpoint
    console.log(`📥 Fetching data from ${endpoint.url}`)
    const response = await fetch(endpoint.url)
    
    // Check if the API request was successful
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }

    // Parse the JSON response
    const responseData = await response.json()
    
    // ElGoose API returns data in format: {"error": false, "data": [...]}
    // Extract the actual data array from the response
    const data = responseData.data || responseData
    result.total_fetched = Array.isArray(data) ? data.length : 1

    console.log(`📊 Received ${result.total_fetched} records`)

    // STEP 2: Determine the target table name
    // Convert endpoint name to lowercase to match our table naming convention
    const tableName = endpoint.name.toLowerCase()
    
    // STEP 3: Process all records from the API
    const recordsToProcess = Array.isArray(data) ? data : [data]
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
    .from(`raw_data_${tableName}`)
    .select('id, data, version')
    .eq('external_id', externalId)
    .single()

  if (existingRecord) {
    // STEP 3A: Record exists - check if data has changed
    const dataChanged = JSON.stringify(existingRecord.data) !== JSON.stringify(record)
    
    if (dataChanged) {
      // Data has changed - update the existing record
      await supabaseClient
        .from(`raw_data_${tableName}`)
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
      .from(`raw_data_${tableName}`)
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
