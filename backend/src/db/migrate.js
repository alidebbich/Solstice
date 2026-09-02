// src/db/migrate.js — run schema against DATABASE_URL
// Usage: node src/db/migrate.js
require('dotenv').config();
const { readFileSync } = require('fs');
const { join } = require('path');
const { Pool } = require('pg');

async function migrate() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const sql = readFileSync(join(__dirname, 'schema.sql'), 'utf8');
  try {
    await pool.query(sql);
    console.log('[migrate] Schema applied successfully.');
  } catch (err) {
    console.error('[migrate] Error:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

migrate();
