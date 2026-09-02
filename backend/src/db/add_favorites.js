// src/db/add_favorites.js — adds the favorites table
// Usage: node src/db/add_favorites.js
require('dotenv').config();
const { Pool } = require('pg');

async function migrate() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const sql = `
    CREATE TABLE IF NOT EXISTS favorites (
      user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (user_id, product_id)
    );
  `;
  try {
    await pool.query(sql);
    console.log('[favorites migration] Table created (or already exists).');
  } catch (err) {
    console.error('[favorites migration] Error:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

migrate();
