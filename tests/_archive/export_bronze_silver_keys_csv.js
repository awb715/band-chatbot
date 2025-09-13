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

  const columnsByTable = {}

  // Parse CREATE TABLE silver.<table> (...)
  const createRegex = /CREATE TABLE\s+silver\.(\w+)\s*\(([^;]*?)\);/gis
  let m
  while ((m = createRegex.exec(text)) !== null) {
    const table = m[1]
    const body = m[2]
    const colLines = body
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith('--'))
    for (const line of colLines) {
      const colMatch = line.match(/^(\w+)\s+[A-Z]/i)
      if (colMatch) {
        const col = colMatch[1]
        columnsByTable[table] = columnsByTable[table] || new Set()
        columnsByTable[table].add(col)
      }
    }
  }

  // Parse ALTER TABLE silver.latest ADD COLUMN ...
  const alterRegex = /ALTER TABLE\s+silver\.(\w+)\s+ADD COLUMN\s+(\w+)\s+/gi
  let a
  while ((a = alterRegex.exec(text)) !== null) {
    const table = a[1]
    const col = a[2]
    columnsByTable[table] = columnsByTable[table] || new Set()
    columnsByTable[table].add(col)
  }

  const result = {}
  for (const [t, set] of Object.entries(columnsByTable)) {
    result[t] = Array.from(set).sort()
  }
  return result
}

async function main() {
  const allRows = []
  
  // Get raw JSON keys from samples (bronze layer)
  for (const table of tables) {
    const { data, error } = await supabase
      .schema('raw_data')
      .from(table)
      .select('data')
      .limit(3)
    if (error) {
      console.error(`Error sampling raw_data.${table}:`, error.message)
      continue
    }
    const keys = unionKeysFromRows(data)
    for (const k of keys) {
      allRows.push(`${k},${table},bronze`)
    }
  }

  // Get silver column names from migrations (since tables may be empty)
  const silverCols = parseSilverColumnsFromMigrations()
  for (const table of tables) {
    const cols = silverCols[table] || []
    for (const col of cols) {
      allRows.push(`${col},${table},silver`)
    }
  }

  // Write CSV with 3 columns: field_name, table_name, schema
  const csv = ['field_name,table_name,schema', ...allRows].join('\n')
  fs.writeFileSync(path.resolve(__dirname, '../complete_fields.csv'), csv, 'utf8')

  console.log('Wrote complete_fields.csv with bronze JSON keys and silver columns')
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})


