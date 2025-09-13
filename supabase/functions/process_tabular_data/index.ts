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

    console.log(`🔄 Starting tabular data processing in ${mode} mode...`)
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
      const { data: bronzeData, error: bronzeError } = await supabase
        .from('raw_data.songs')
        .select('count', { count: 'exact' })
        .limit(1)
      
      const { data: silverData, error: silverCountError } = await supabase
        .from('silver.songs')
        .select('count', { count: 'exact' })
        .limit(1)
      
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
        console.log('🔄 Force reprocessing - resetting is_processed flags...')
        // Reset is_processed flags for all Bronze tables
        const bronzeTables = ['songs', 'shows', 'setlists', 'venues', 'latest', 'metadata', 'links', 'uploads', 'appearances', 'jamcharts']
        for (const table of bronzeTables) {
          await supabase
            .from(`raw_data.${table}`)
            .update({ is_processed: false })
        }
      }
      
      // Call the master ETL function in silver schema via PostgREST
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
      
      if (force_reprocess) {
        console.log('🔄 Force reprocessing - resetting is_processed flags...')
        // Diagnostics before reset
        const { count: beforeTotal } = await supabase
          .from(`raw_data.${table_name}`)
          .select('*', { count: 'exact', head: true })
        const { count: beforeUnprocessed } = await supabase
          .from(`raw_data.${table_name}`)
          .select('*', { count: 'exact', head: true })
          .eq('is_processed', false)
        console.log(`📊 raw_data.${table_name} before reset: total=${beforeTotal} unprocessed=${beforeUnprocessed}`)

        await supabase.from(`raw_data.${table_name}`).update({ is_processed: false })

        const { count: afterUnprocessed } = await supabase
          .from(`raw_data.${table_name}`)
          .select('*', { count: 'exact', head: true })
          .eq('is_processed', false)
        console.log(`📊 raw_data.${table_name} after reset: unprocessed=${afterUnprocessed}`)
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
      silverResults = await rpcResp.json()

      // Diagnostics after ETL
      const { count: silverCount } = await supabase
        .from(`silver.${table_name}`)
        .select('*', { count: 'exact', head: true })
      console.log(`📊 silver.${table_name} count after ETL: ${silverCount}`)
    } else {
      // Process all tables (default) via PostgREST
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
    // STEP 3: CALCULATE TOTALS
    // ============================================================================
    const totalSilverProcessed = silverResults?.reduce((sum, row) => sum + (row.processed_count || 0), 0) || 0
    const totalGoldProcessed = goldResults?.reduce((sum, row) => sum + (row.processed_count || 0), 0) || 0
    const totalErrors = silverResults?.reduce((sum, row) => sum + (row.error_count || 0), 0) || 0

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
      processing_time_ms: silverResults?.reduce((sum, row) => sum + (row.processing_time_ms || 0), 0) || 0
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
        results: silverResults
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