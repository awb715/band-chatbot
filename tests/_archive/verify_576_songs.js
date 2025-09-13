import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config()

const supabaseUrl = process.env.SUPABASE_URL
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

async function verify576Songs() {
  const { data, error } = await supabase
    .from('raw_data_songs')
    .select('*', { count: 'exact' })
  
  if (error) {
    console.error('Error:', error.message)
  } else {
    console.log('✅ Songs count:', data.length)
    if (data.length === 576) {
      console.log('🎉 Perfect! We have exactly 576 songs!')
    } else {
      console.log(`⚠️ Expected 576, got ${data.length}`)
    }
  }
}

verify576Songs()
