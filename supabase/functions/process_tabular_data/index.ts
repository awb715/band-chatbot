import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { mode = 'incremental', table_name, force_reprocess = false } = await req.json()

    const pstTimestamp = new Date().toLocaleString('en-US', { timeZone: 'America/Los_Angeles' })
    console.log(`🔄 Starting tabular data processing in ${mode} mode... [PST ${pstTimestamp}]`)
    if (table_name) {
      console.log(`🎯 Target table: ${table_name}`)
    }
    if (force_reprocess) {
      console.log(`🔄 Force reprocess: ${force_reprocess}`)
    }

    // ============================================================================
    // STEP 1: PROCESS BRONZE → SILVER
    // ============================================================================
    console.log('🥈 Processing Bronze → Silver layer...')
    
    let silverResults;
    let silverError;
    
    if (mode === 'songs_only') {
      // Process only songs table for testing
      console.log('🎵 Processing songs table only...')
      
      // For now, just verify we can access both layers
      const { error: bronzeError } = await supabase
        .schema('raw_data')
        .from('songs')
        .select('id', { count: 'exact', head: true })
      
      const { error: silverCountError } = await supabase
        .schema('silver')
        .from('songs')
        .select('id', { count: 'exact', head: true })
      
      if (bronzeError || silverCountError) {
        silverError = bronzeError || silverCountError
      } else {
        silverResults = [{ 
          table_name: 'songs', 
          processed_count: 0, 
          error_count: 0, 
          processing_time_ms: 0,
          status: 'verified'
        }]
      }
    } else if (mode === 'silver_only') {
      // Process all Silver layer tables
      console.log('🥈 Processing all Silver layer tables...')
      
      if (force_reprocess) {
        console.log('🔄 Force reprocessing - resetting is_processed flags (all tables via schema client)...')
        const bronzeTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
        for (const table of bronzeTables) {
          const { error: resetErr } = await supabase
            .schema('raw_data')
            .from(table)
            .update({ is_processed: false })
            .eq('is_processed', true)
          if (resetErr) {
            console.log(`⚠️ Reset failed for raw_data.${table}: ${resetErr.message}`)
          }
        }
      }
      
      // Call the new production Silver ETL function via PostgREST
      const rpcResp = await fetch(`${Deno.env.get('SUPABASE_URL')}/rest/v1/rpc/process_all_tables`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          apikey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
          'Content-Type': 'application/json',
          'Content-Profile': 'silver'
        },
        body: JSON.stringify({})
      })
      if (!rpcResp.ok) {
        const errText = await rpcResp.text()
        throw new Error(`Silver RPC failed: ${rpcResp.status} ${errText}`)
      }
      silverResults = await rpcResp.json()
    } else if (table_name) {
      // Process specific table
      console.log(`🎯 Processing specific table: ${table_name}`)
      
      // Diagnostics holders
      let diag_before_total: number | null = null
      let diag_before_unprocessed: number | null = null
      let diag_after_unprocessed: number | null = null
      let diag_silver_after: number | null = null

      if (force_reprocess) {
        console.log('🔄 Force reprocessing - resetting is_processed flags...')
        // Diagnostics before reset via schema client
        const beforeAll = await supabase
          .schema('raw_data')
          .from(table_name)
          .select('id', { count: 'exact', head: true })
        const beforeUnproc = await supabase
          .schema('raw_data')
          .from(table_name)
          .select('id', { count: 'exact', head: true })
          .eq('is_processed', false)
        diag_before_total = beforeAll.count ?? null
        diag_before_unprocessed = beforeUnproc.count ?? null
        console.log(`📊 raw_data.${table_name} before reset: total=${diag_before_total} unprocessed=${diag_before_unprocessed}`)

        const reset = await supabase
          .schema('raw_data')
          .from(table_name)
          .update({ is_processed: false })
          .eq('is_processed', true)
        if (reset.error) {
          console.log(`⚠️ Reset failed for raw_data.${table_name}: ${reset.error.message}`)
        }

        const afterUnproc = await supabase
          .schema('raw_data')
          .from(table_name)
          .select('id', { count: 'exact', head: true })
          .eq('is_processed', false)
        diag_after_unprocessed = afterUnproc.count ?? null
        console.log(`📊 raw_data.${table_name} after reset: unprocessed=${diag_after_unprocessed}`)
      }
      
      // Call specific table function in silver schema via PostgREST
      const rpcResp = await fetch(`${Deno.env.get('SUPABASE_URL')}/rest/v1/rpc/process_${table_name}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          apikey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
          'Content-Type': 'application/json',
          'Content-Profile': 'silver'
        },
        body: JSON.stringify({})
      })
      if (!rpcResp.ok) {
        const errText = await rpcResp.text()
        throw new Error(`Silver RPC failed: ${rpcResp.status} ${errText}`)
      }
      
      // Individual table functions return INT, convert to our expected JSON format
      const recordCount = await rpcResp.json()
      silverResults = {
        success: true,
        total_records_processed: recordCount,
        table_results: {
          [table_name]: recordCount
        },
        processing_time_ms: 0 // Individual calls don't track timing
      }

      // Diagnostics after ETL
      const silverCountRes = await supabase
        .schema('silver')
        .from(table_name)
        .select('id', { count: 'exact', head: true })
      diag_silver_after = silverCountRes.count ?? null
      console.log(`📊 silver.${table_name} count after ETL: ${diag_silver_after}`)

      // Attach diagnostics to results
      if (Array.isArray(silverResults)) {
        silverResults = silverResults.map((r: any) => ({
          ...r,
          debug: {
            raw_before_total: diag_before_total,
            raw_before_unprocessed: diag_before_unprocessed,
            raw_after_unprocessed: diag_after_unprocessed,
            silver_after_count: diag_silver_after
          }
        }))
      }
    } else {
      // Process all tables (default) via PostgREST - using new production Silver ETL
      const rpcResp = await fetch(`${Deno.env.get('SUPABASE_URL')}/rest/v1/rpc/process_all_tables`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          apikey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
          'Content-Type': 'application/json',
          'Content-Profile': 'silver'
        },
        body: JSON.stringify({})
      })
      if (!rpcResp.ok) {
        const errText = await rpcResp.text()
        throw new Error(`Silver RPC failed: ${rpcResp.status} ${errText}`)
      }
      silverResults = await rpcResp.json()
    }
    
    if (silverError) {
      console.error('❌ Silver processing failed:', silverError)
      throw new Error(`Silver processing failed: ${silverError.message}`)
    }

    console.log('✅ Silver processing completed:', silverResults)
    
    // Log detailed results if available
    if (silverResults && typeof silverResults === 'object') {
      if (silverResults.total_records_processed) {
        console.log(`📊 Total Silver records processed: ${silverResults.total_records_processed}`)
      }
      if (silverResults.table_results) {
        console.log('📋 Silver processing breakdown by table:', silverResults.table_results)
      }
      if (silverResults.processing_time_ms) {
        console.log(`⏱️ Silver processing time: ${silverResults.processing_time_ms}ms`)
      }
    }

    // ============================================================================
    // STEP 2: PROCESS SILVER → GOLD (disabled unless explicitly requested)
    // ============================================================================
    let goldResults = null;
    
    if (mode === 'gold_only') {
      console.log('🥇 Processing Silver → Gold layer...')
      const { data, error: goldError } = await supabase.rpc('aggregate_all_analytics')
      if (goldError) {
        console.error('❌ Gold processing failed:', goldError)
        throw new Error(`Gold processing failed: ${goldError.message}`)
      }
      goldResults = data;
      console.log('✅ Gold processing completed:', goldResults)
    } else {
      console.log('⏭️ Skipping Gold layer processing (mode != gold_only)')
    }

    // ============================================================================
    // STEP 3: CALCULATE TOTALS (handle new JSON format from Silver ETL)
    // ============================================================================
    let totalSilverProcessed = 0;
    let totalErrors = 0;
    
    if (silverResults) {
      if (Array.isArray(silverResults)) {
        // Legacy format (array of results)
        totalSilverProcessed = silverResults.reduce((sum, row) => sum + (row.processed_count || 0), 0);
        totalErrors = silverResults.reduce((sum, row) => sum + (row.error_count || 0), 0);
      } else if (typeof silverResults === 'object') {
        // New format (JSON object)
        totalSilverProcessed = silverResults.total_records_processed || 0;
        totalErrors = 0; // New ETL logs errors separately
      }
    }
    
    const totalGoldProcessed = goldResults?.reduce((sum, row) => sum + (row.processed_count || 0), 0) || 0

    // ============================================================================
    // STEP 4: LOG PROCESSING STATUS
    // ============================================================================
    const processingStatus = {
      layer: 'silver',
      table_name: table_name || 'all',
      status: 'completed',
      records_processed: totalSilverProcessed,
      errors: totalErrors,
      completed_at: new Date().toISOString(),
      processing_time_ms: (silverResults?.processing_time_ms) || 
                       (Array.isArray(silverResults) ? silverResults.reduce((sum, row) => sum + (row.processing_time_ms || 0), 0) : 0)
    }

    // Insert processing status
    await supabase
      .from('processing_status')
      .insert(processingStatus)

    // ============================================================================
    // STEP 5: RETURN RESULTS
    // ============================================================================
    const response = {
      success: true,
      mode,
      table_name: table_name || 'all',
      force_reprocess,
      silver_layer: {
        processed_tables: silverResults?.length || 0,
        total_records_processed: totalSilverProcessed,
        total_errors: totalErrors,
        results: silverResults,
        processing_time_ms: (silverResults?.processing_time_ms) || 0
      },
      gold_layer: goldResults ? {
        processed_tables: goldResults.length,
        total_records_processed: totalGoldProcessed,
        results: goldResults
      } : null,
      processing_status: processingStatus,
      timestamp: new Date().toISOString()
    }

    return new Response(
      JSON.stringify(response),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('❌ Processing failed:', error)
    
    // Log error status
    try {
      await supabase
        .from('processing_status')
        .insert({
          layer: 'silver',
          table_name: table_name || 'all',
          status: 'failed',
          records_processed: 0,
          errors: 1,
          completed_at: new Date().toISOString(),
          error_message: (error as any)?.message
        })
    } catch (logError) {
      console.error('❌ Failed to log error status:', logError)
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: (error as any)?.message,
        timestamp: new Date().toISOString()
      }),
      { 
        status: 500,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )
  }
})