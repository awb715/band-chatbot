/*
 Read-only audit:
 - Samples 3 rows from each raw_data table and unions JSON keys
 - Parses silver table columns from migration files
 - Prints per-table: raw keys, silver columns, missing columns, external key guess
*/

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import dotenv from 'dotenv'
import { createClient } from '@supabase/supabase-js'

dotenv.config()

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in env')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

const tables = [
  'songs',
  'shows',
  'setlists',
  'venues',
  'latest',
  'metadata',
  'links',
  'uploads',
  'appearances',
  'jamcharts',
]

function unionKeysFromRows(rows) {
  const keys = new Set()
  for (const r of rows || []) {
    if (r && r.data && typeof r.data === 'object') {
      for (const k of Object.keys(r.data)) keys.add(k)
    }
  }
  return Array.from(keys).sort()
}

function parseSilverColumnsFromMigrations() {
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations')
  const files = fs.readdirSync(migrationsDir)
  // Read relevant migration files
  const targetFiles = files.filter((f) =>
    [
      '20250910000007_complete_silver_layer.sql',
      '20250909070000_create_silver_songs_only.sql',
      '20250910000026_widen_silver_latest_table.sql',
    ].includes(f)
  )
  const text = targetFiles
    .map((f) => fs.readFileSync(path.join(migrationsDir, f), 'utf8'))
    .join('\n\n')

  // Parse CREATE TABLE silver.<table> (...) blocks
  const createRegex = /CREATE TABLE\s+silver\.(\w+)\s*\(([^;]*?)\);/gis
  const columnsByTable = {}
  let m
  while ((m = createRegex.exec(text)) !== null) {
    const table = m[1]
    const body = m[2]
    const colLines = body
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith('--'))
    for (const line of colLines) {
      const colMatch = line.match(/^(\w+)\s+[A-Z]+/i)
      if (colMatch) {
        const col = colMatch[1]
        columnsByTable[table] = columnsByTable[table] || new Set()
        columnsByTable[table].add(col)
      }
    }
  }

  // Parse ALTER TABLE silver.latest ADD COLUMN ... from widen migration
  const alterRegex = /ALTER TABLE\s+silver\.(\w+)\s+ADD COLUMN\s+(\w+)\s+/gi
  let a
  while ((a = alterRegex.exec(text)) !== null) {
    const table = a[1]
    const col = a[2]
    columnsByTable[table] = columnsByTable[table] || new Set()
    columnsByTable[table].add(col)
  }

  // Convert sets to sorted arrays
  const result = {}
  for (const [t, set] of Object.entries(columnsByTable)) {
    result[t] = Array.from(set).sort()
  }
  return result
}

function guessExternalKey(table, rawKeys) {
  // Heuristics based on domain knowledge
  if (table === 'setlists') return 'uniqueid'
  if (table === 'latest') return 'uniqueid'
  if (table === 'venues') return 'venue_id'
  if (table === 'shows') return 'show_id'
  if (table === 'songs') return 'song_id'
  if (table === 'links') return rawKeys.includes('link_id') ? 'link_id' : 'url'
  if (table === 'uploads') return rawKeys.includes('upload_id') ? 'upload_id' : 'filename'
  if (table === 'metadata') return rawKeys.includes('id') ? 'id' : 'key'
  if (table === 'appearances') {
    if (rawKeys.includes('uniqueid')) return 'uniqueid'
    return '(show_id, song_id, position)'
  }
  if (table === 'jamcharts') {
    if (rawKeys.includes('id')) return 'id'
    return '(song_id, jam_type)'
  }
  return 'external_id'
}

async function main() {
  const silverCols = parseSilverColumnsFromMigrations()

  const report = {}
  for (const table of tables) {
    const { data, error } = await supabase
      .schema('raw_data')
      .from(table)
      .select('external_id,data')
      .limit(3)

    if (error) {
      report[table] = { error: error.message }
      continue
    }

    const rawKeys = unionKeysFromRows(data)
    const silver = silverCols[table] || []
    const missing = rawKeys.filter((k) => !silver.includes(k))
    const key = guessExternalKey(table, rawKeys)

    report[table] = {
      sample_count: data?.length || 0,
      raw_keys: rawKeys,
      silver_columns: silver,
      missing_in_silver: missing,
      external_key_recommendation: key,
    }
  }

  console.log(JSON.stringify(report, null, 2))
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})


