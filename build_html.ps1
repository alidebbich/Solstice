# Build script: injects base64 images into templates and organises frontend/backend folders
# Run from: c:\Users\debbi\Desktop\job-agent\glasses\

$root     = "c:\Users\debbi\Desktop\job-agent\glasses"
$frontDir = "$root\frontend"
$backDir  = "$root\backend"

# Create folder structure
New-Item -ItemType Directory -Force -Path $frontDir | Out-Null
New-Item -ItemType Directory -Force -Path $backDir  | Out-Null

Write-Host "==> Loading base64 images..."

function LoadB64($file){
  return [System.IO.File]::ReadAllText("$root\$file").Trim()
}

$bare      = LoadB64 "img_bare.b64"
$glasses   = LoadB64 "img_glasses.b64"
$male      = LoadB64 "male_model.b64"
$meridian  = LoadB64 "shop_meridian.b64"
$horizon   = LoadB64 "shop_horizon.b64"
$solace    = LoadB64 "shop_solace.b64"
$drift     = LoadB64 "shop_drift.b64"

$components = [System.IO.File]::ReadAllText("$root\frontend_components.html")
$logic = [System.IO.File]::ReadAllText("$root\frontend_logic.html")
$injected = $components + "`n" + $logic

Write-Host "==> Building index.html..."
$idx = [System.IO.File]::ReadAllText("$root\index_template.html")
$idx = $idx -replace '##BARE_B64##',    "data:image/jpeg;base64,$bare"
$idx = $idx -replace '##GLASSES_B64##', "data:image/jpeg;base64,$glasses"
$idx = $idx -replace '##MERIDIAN_B64##',"data:image/jpeg;base64,$meridian"
$idx = $idx -replace '##HORIZON_B64##', "data:image/jpeg;base64,$horizon"
$idx = $idx -replace '##SOLACE_B64##',  "data:image/jpeg;base64,$solace"
$idx = $idx -replace '##DRIFT_B64##',   "data:image/jpeg;base64,$drift"
$idx = $idx -replace '##MALE_B64##',    "data:image/jpeg;base64,$male"
$idx = $idx -replace '##FRONTEND_COMPONENTS##', $injected
[System.IO.File]::WriteAllText("$frontDir\index.html",      $idx, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$root\index.html",           $idx, [System.Text.Encoding]::UTF8)

Write-Host "==> Building collection.html..."
$coll = [System.IO.File]::ReadAllText("$root\collection_template.html")
$coll = $coll -replace '##MERIDIAN_B64##',"data:image/jpeg;base64,$meridian"
$coll = $coll -replace '##HORIZON_B64##', "data:image/jpeg;base64,$horizon"
$coll = $coll -replace '##SOLACE_B64##',  "data:image/jpeg;base64,$solace"
$coll = $coll -replace '##DRIFT_B64##',   "data:image/jpeg;base64,$drift"
$coll = $coll -replace '##MALE_B64##',    "data:image/jpeg;base64,$male"
$coll = $coll -replace '##FRONTEND_COMPONENTS##', $injected
[System.IO.File]::WriteAllText("$frontDir\collection.html", $coll, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$root\collection.html",      $coll, [System.Text.Encoding]::UTF8)

Write-Host "==> Building product.html..."
$prod = [System.IO.File]::ReadAllText("$root\product_template.html")
$prod = $prod -replace '##MERIDIAN_B64##',"data:image/jpeg;base64,$meridian"
$prod = $prod -replace '##HORIZON_B64##', "data:image/jpeg;base64,$horizon"
$prod = $prod -replace '##SOLACE_B64##',  "data:image/jpeg;base64,$solace"
$prod = $prod -replace '##DRIFT_B64##',   "data:image/jpeg;base64,$drift"
$prod = $prod -replace '##MALE_B64##',    "data:image/jpeg;base64,$male"
$prod = $prod -replace '##FRONTEND_COMPONENTS##', $injected
[System.IO.File]::WriteAllText("$frontDir\product.html", $prod, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$root\product.html",      $prod, [System.Text.Encoding]::UTF8)

# --- BACKEND SCAFFOLD (FIXED — uses bcryptjs, mounts cart router, all bugs fixed) ---
Write-Host "==> Scaffolding backend..."

$packageJson = @'
{
  "name": "solstice-api",
  "version": "1.0.0",
  "description": "Solstice Eyewear — Express API",
  "main": "src/index.js",
  "scripts": {
    "dev": "nodemon src/index.js",
    "start": "node src/index.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "dotenv": "^16.3.1",
    "nodemon": "^3.0.2"
  }
}
'@

$envExample = @'
PORT=3001
DATABASE_URL=postgresql://postgres:password@localhost:5432/solstice
JWT_SECRET=replace_with_a_long_random_secret
NODE_ENV=development
CORS_ORIGIN=*
'@

$gitignore = @'
node_modules/
.env
dist/
'@

$dbSql = @'
-- Solstice Eyewear — Database Schema v2
-- Run: psql "postgresql://postgres:ali@localhost:5432/solstice" -f src/db/schema.sql

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT,
  name          TEXT,
  phone         TEXT,
  address       TEXT,
  city          TEXT,
  country       TEXT DEFAULT 'UK',
  google_id     TEXT,
  avatar_url    TEXT,
  role          TEXT NOT NULL DEFAULT 'customer',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone       TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS address     TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS city        TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS country     TEXT DEFAULT 'UK';
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id   TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url  TEXT;

CREATE TABLE IF NOT EXISTS products (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug        TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  category    TEXT NOT NULL,
  description TEXT,
  price_cents INTEGER NOT NULL,
  image_url   TEXT,
  stock       INTEGER NOT NULL DEFAULT 0,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE products ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS cart_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity    INTEGER NOT NULL DEFAULT 1,
  added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, product_id)
);

CREATE TABLE IF NOT EXISTS orders (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id),
  status      TEXT NOT NULL DEFAULT 'pending',
  total_cents INTEGER NOT NULL,
  address     TEXT,
  city        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS city    TEXT;

CREATE TABLE IF NOT EXISTS order_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID NOT NULL REFERENCES orders(id),
  product_id  UUID NOT NULL REFERENCES products(id),
  quantity    INTEGER NOT NULL,
  price_cents INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

INSERT INTO products (slug, name, category, description, price_cents, stock, active) VALUES
  ('meridian',    'Meridian',        'sunglasses', 'Amber polarized lenses, hand-polished acetate.',               18900, 50, TRUE),
  ('horizon',     'Horizon',         'sunglasses', 'Mirrored lenses set in a lightweight titanium frame.',         21900, 35, TRUE),
  ('solace',      'Solace',          'optical',    'A featherweight optical frame, blue-light filter available.',  14900, 60, TRUE),
  ('drift',       'Drift',           'sunglasses', 'Gradient smoke lenses in an oversized round frame.',           17900, 40, TRUE),
  ('horizon-mens','Horizon Men''s',  'sunglasses', 'Wider fit mirrored lenses in a matte titanium frame.',         21900, 20, TRUE)
ON CONFLICT (slug) DO UPDATE SET active = TRUE;
'@

$indexJs = @'
require("dotenv").config();
const express   = require("express");
const helmet    = require("helmet");
const cors      = require("cors");
const rateLimit = require("express-rate-limit");

const authRouter      = require("./routes/auth");
const productsRouter  = require("./routes/products");
const ordersRouter    = require("./routes/orders");
const cartRouter      = require("./routes/cart");
const contactRouter   = require("./routes/contact");
const favoritesRouter = require("./routes/favorites");

const app  = express();
const PORT = process.env.PORT || 3001;

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: process.env.CORS_ORIGIN || "*", credentials: true }));
app.use(express.json());

const limiter     = rateLimit({ windowMs: 15 * 60 * 1000, max: 200 });
const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20 });
app.use(limiter);

// CSRF stub (no cookies used - JWT in header)
app.get("/api/csrf-token", (_req, res) => res.json({ csrfToken: "not-enforced" }));

app.use("/api/auth",      authLimiter, authRouter);
app.use("/api/products",  productsRouter);
app.use("/api/orders",    ordersRouter);
app.use("/api/cart",      cartRouter);
app.use("/api/contact",   contactRouter);
app.use("/api/favorites", favoritesRouter);

app.get("/api/health", (_req, res) => res.json({ ok: true, ts: new Date().toISOString() }));

// Global error handler
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message || "Internal server error" });
});

app.listen(PORT, () => console.log(`Solstice API running on :${PORT}`));
'@

$dbJs = @'
const { Pool } = require("pg");
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
module.exports = { query: (text, params) => pool.query(text, params) };
'@

$authJs = @'
const router  = require("express").Router();
const bcrypt  = require("bcryptjs");
const jwt     = require("jsonwebtoken");
const { z }   = require("zod");
const db      = require("../db");

const signupSchema = z.object({
  email:    z.string().email(),
  password: z.string().min(8),
  name:     z.string().optional(),
  phone:    z.string().optional(),
});

router.post("/signup", async (req, res) => {
  try {
    const { email, password, name, phone } = signupSchema.parse(req.body);
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await db.query(
      "INSERT INTO users (email, password_hash, name, phone) VALUES ($1,$2,$3,$4) RETURNING id,email,name,role,phone,address,city,country,avatar_url",
      [email, hash, name || null, phone || null]
    );
    const token = jwt.sign({ sub: rows[0].id, role: rows[0].role }, process.env.JWT_SECRET, { expiresIn: "7d" });
    res.status(201).json({ user: rows[0], token });
  } catch (e) {
    if (e.code === "23505") return res.status(409).json({ error: "Email already in use" });
    res.status(400).json({ error: e.message });
  }
});

router.post("/login", async (req, res) => {
  try {
    const { email, password } = z.object({ email: z.string().email(), password: z.string() }).parse(req.body);
    const { rows } = await db.query("SELECT * FROM users WHERE email=$1", [email]);
    if (!rows[0]) return res.status(401).json({ error: "Invalid credentials" });
    if (!rows[0].password_hash) return res.status(401).json({ error: "Please sign in with Google" });
    const ok = await bcrypt.compare(password, rows[0].password_hash);
    if (!ok) return res.status(401).json({ error: "Invalid credentials" });
    const token = jwt.sign({ sub: rows[0].id, role: rows[0].role }, process.env.JWT_SECRET, { expiresIn: "7d" });
    const { password_hash, ...user } = rows[0];
    res.json({ token, user });
  } catch (e) { res.status(400).json({ error: e.message }); }
});

router.post("/logout", (_req, res) => res.json({ ok: true }));

router.get("/me", require("../middleware/auth"), async (req, res) => {
  try {
    const { rows } = await db.query(
      "SELECT id,email,name,role,phone,address,city,country,avatar_url FROM users WHERE id=$1",
      [req.user.sub]
    );
    if (!rows[0]) return res.status(404).json({ error: "User not found" });
    res.json(rows[0]);
  } catch(e) { res.status(500).json({ error: e.message }); }
});

router.patch("/profile", require("../middleware/auth"), async (req, res) => {
  try {
    const { name, phone, address, city, country } = z.object({
      name:    z.string().optional(),
      phone:   z.string().optional(),
      address: z.string().optional(),
      city:    z.string().optional(),
      country: z.string().optional(),
    }).parse(req.body);
    const { rows } = await db.query(
      `UPDATE users SET
        name    = COALESCE($1, name),
        phone   = COALESCE($2, phone),
        address = COALESCE($3, address),
        city    = COALESCE($4, city),
        country = COALESCE($5, country)
       WHERE id=$6
       RETURNING id,email,name,role,phone,address,city,country,avatar_url`,
      [name, phone, address, city, country, req.user.sub]
    );
    res.json(rows[0]);
  } catch(e) { res.status(400).json({ error: e.message }); }
});

router.post("/google", async (req, res) => {
  try {
    const { google_id, email, name, avatar_url } = z.object({
      google_id:  z.string(),
      email:      z.string().email(),
      name:       z.string().optional(),
      avatar_url: z.string().optional(),
    }).parse(req.body);
    const { rows } = await db.query(
      `INSERT INTO users (email, google_id, name, avatar_url)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO UPDATE SET
         google_id  = COALESCE(EXCLUDED.google_id, users.google_id),
         name       = COALESCE(EXCLUDED.name, users.name),
         avatar_url = COALESCE(EXCLUDED.avatar_url, users.avatar_url)
       RETURNING id,email,name,role,phone,address,city,country,avatar_url`,
      [email, google_id, name || null, avatar_url || null]
    );
    const token = jwt.sign({ sub: rows[0].id, role: rows[0].role }, process.env.JWT_SECRET, { expiresIn: "7d" });
    res.json({ user: rows[0], token });
  } catch(e) { res.status(400).json({ error: e.message }); }
});

module.exports = router;
'@

$cartJs = @'
const router = require("express").Router();
const { z }  = require("zod");
const db     = require("../db");
const auth   = require("../middleware/auth");

router.use(auth);

async function getCart(userId) {
  const { rows } = await db.query(
    `SELECT ci.id, ci.quantity, ci.added_at,
       p.id AS product_id, p.slug, p.name, p.category,
       p.price_cents, p.image_url, p.stock
     FROM cart_items ci
     JOIN products p ON p.id = ci.product_id
     WHERE ci.user_id = $1
     ORDER BY ci.added_at ASC`,
    [userId]
  );
  const subtotal = rows.reduce((sum, r) => sum + r.price_cents * r.quantity, 0);
  return { items: rows, subtotal_cents: subtotal, count: rows.reduce((s, r) => s + r.quantity, 0) };
}

router.get("/", async (req, res, next) => {
  try { res.json(await getCart(req.user.sub)); } catch(e) { next(e); }
});

router.post("/", async (req, res, next) => {
  try {
    const { product_id, quantity } = z.object({
      product_id: z.string().uuid(),
      quantity:   z.number().int().positive().default(1),
    }).parse(req.body);

    const { rows: [product] } = await db.query(
      "SELECT id, stock FROM products WHERE id=$1 AND active=TRUE", [product_id]
    );
    if (!product) return res.status(404).json({ error: "Product not found" });
    if (product.stock < quantity) return res.status(409).json({ error: "Not enough stock", available: product.stock });

    await db.query(
      `INSERT INTO cart_items (user_id, product_id, quantity)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, product_id)
       DO UPDATE SET quantity = cart_items.quantity + EXCLUDED.quantity`,
      [req.user.sub, product_id, quantity]
    );
    res.status(201).json(await getCart(req.user.sub));
  } catch(e) { next(e); }
});

router.patch("/:itemId", async (req, res, next) => {
  try {
    const { quantity } = z.object({ quantity: z.number().int().min(0) }).parse(req.body);
    const { rows: [item] } = await db.query(
      "SELECT id FROM cart_items WHERE id=$1 AND user_id=$2", [req.params.itemId, req.user.sub]
    );
    if (!item) return res.status(404).json({ error: "Cart item not found" });
    if (quantity === 0) {
      await db.query("DELETE FROM cart_items WHERE id=$1", [req.params.itemId]);
    } else {
      await db.query("UPDATE cart_items SET quantity=$1 WHERE id=$2", [quantity, req.params.itemId]);
    }
    res.json(await getCart(req.user.sub));
  } catch(e) { next(e); }
});

router.delete("/:itemId", async (req, res, next) => {
  try {
    const { rowCount } = await db.query(
      "DELETE FROM cart_items WHERE id=$1 AND user_id=$2", [req.params.itemId, req.user.sub]
    );
    if (!rowCount) return res.status(404).json({ error: "Cart item not found" });
    res.json(await getCart(req.user.sub));
  } catch(e) { next(e); }
});

router.delete("/", async (req, res, next) => {
  try {
    await db.query("DELETE FROM cart_items WHERE user_id=$1", [req.user.sub]);
    res.json({ items: [], subtotal_cents: 0, count: 0 });
  } catch(e) { next(e); }
});

module.exports = router;
'@

$productsJs = @'
const router = require("express").Router();
const db     = require("../db");

router.get("/", async (req, res) => {
  const { category } = req.query;
  const q = category
    ? "SELECT * FROM products WHERE category=$1 AND active=TRUE ORDER BY created_at"
    : "SELECT * FROM products WHERE active=TRUE ORDER BY created_at";
  const params = category ? [category] : [];
  const { rows } = await db.query(q, params);
  res.json(rows);
});

router.get("/:slug", async (req, res) => {
  const { rows } = await db.query("SELECT * FROM products WHERE slug=$1 AND active=TRUE", [req.params.slug]);
  if (!rows[0]) return res.status(404).json({ error: "Not found" });
  res.json(rows[0]);
});

module.exports = router;
'@

$ordersJs = @'
const router = require("express").Router();
const { z }  = require("zod");
const db     = require("../db");
const auth   = require("../middleware/auth");
const { Pool } = require("pg");

router.use(auth);

const checkoutSchema = z.object({
  items: z.array(z.object({
    product_id: z.string().uuid(),
    quantity:   z.number().int().positive()
  })).min(1),
  address: z.string().optional(),
  city:    z.string().optional(),
});

router.post("/checkout", async (req, res) => {
  const pool   = new Pool({ connectionString: process.env.DATABASE_URL });
  const client = await pool.connect();
  try {
    const { items, address, city } = checkoutSchema.parse(req.body);
    await client.query("BEGIN");
    let total = 0;
    const priced = [];
    for (const item of items) {
      const { rows } = await client.query(
        "SELECT id, price_cents, stock FROM products WHERE id=$1 AND active=TRUE FOR UPDATE",
        [item.product_id]
      );
      if (!rows[0]) { await client.query("ROLLBACK"); return res.status(409).json({ error: `Product not found: ${item.product_id}` }); }
      if (rows[0].stock < item.quantity) { await client.query("ROLLBACK"); return res.status(409).json({ error: "Not enough stock" }); }
      await client.query("UPDATE products SET stock=stock-$1 WHERE id=$2", [item.quantity, item.product_id]);
      total += rows[0].price_cents * item.quantity;
      priced.push({ ...item, price_cents: rows[0].price_cents });
    }
    const { rows: [order] } = await client.query(
      "INSERT INTO orders (user_id, total_cents, address, city) VALUES ($1,$2,$3,$4) RETURNING *",
      [req.user.sub, total, address || null, city || null]
    );
    for (const item of priced) {
      await client.query(
        "INSERT INTO order_items (order_id, product_id, quantity, price_cents) VALUES ($1,$2,$3,$4)",
        [order.id, item.product_id, item.quantity, item.price_cents]
      );
    }
    await client.query("DELETE FROM cart_items WHERE user_id=$1", [req.user.sub]);
    await client.query("COMMIT");
    res.status(201).json(order);
  } catch (e) {
    await client.query("ROLLBACK");
    res.status(400).json({ error: e.message });
  } finally { client.release(); pool.end(); }
});

router.get("/", async (req, res) => {
  const { rows } = await db.query(
    "SELECT * FROM orders WHERE user_id=$1 ORDER BY created_at DESC", [req.user.sub]
  );
  res.json(rows);
});

router.get("/:id", async (req, res) => {
  const { rows } = await db.query(
    "SELECT * FROM orders WHERE id=$1 AND user_id=$2", [req.params.id, req.user.sub]
  );
  if (!rows[0]) return res.status(404).json({ error: "Not found" });
  res.json(rows[0]);
});

module.exports = router;
'@

$authMiddleware = @'
const jwt = require("jsonwebtoken");
module.exports = function auth(req, res, next) {
  const header = req.headers.authorization || "";
  const token  = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "Unauthorized" });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch { res.status(401).json({ error: "Invalid or expired token" }); }
};
'@

# Write backend files
New-Item -ItemType Directory -Force -Path "$backDir\src\routes"    | Out-Null
New-Item -ItemType Directory -Force -Path "$backDir\src\db"        | Out-Null
New-Item -ItemType Directory -Force -Path "$backDir\src\middleware" | Out-Null

[System.IO.File]::WriteAllText("$backDir\package.json",                $packageJson,    [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\.env.example",                $envExample,     [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\.gitignore",                  $gitignore,      [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\index.js",                $indexJs,        [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\db\index.js",             $dbJs,           [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\db\schema.sql",           $dbSql,          [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\routes\auth.js",          $authJs,         [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\routes\products.js",      $productsJs,     [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\routes\orders.js",        $ordersJs,       [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\routes\cart.js",          $cartJs,         [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText("$backDir\src\middleware\auth.js",      $authMiddleware, [System.Text.Encoding]::UTF8)
# Preserve favorites.js and contact.js (managed separately, not overwritten)
if (-not (Test-Path "$backDir\src\routes\favorites.js")) {
  Copy-Item "$root\backend\src\routes\favorites.js" "$backDir\src\routes\favorites.js" -ErrorAction SilentlyContinue
}

# Preserve the real .env (don't overwrite it)
if (-not (Test-Path "$backDir\.env")) {
  @'
PORT=3001
DATABASE_URL=postgresql://postgres:ali@localhost:5432/solstice
JWT_SECRET=44d8b67efc464b199d945a05b331008630cf82a170889c25608b49e1a967520448154687d60e7eef090d8ed96bc38c35
COOKIE_SECURE=false
NODE_ENV=development
CORS_ORIGIN=*
'@ | Set-Content "$backDir\.env"
}

$frontSizes = @(
  (Get-Item "$frontDir\index.html").Length,
  (Get-Item "$frontDir\collection.html").Length
)
Write-Host ""
Write-Host "=== DONE ==="
Write-Host "frontend/index.html      $([Math]::Round($frontSizes[0]/1024))KB"
Write-Host "frontend/collection.html $([Math]::Round($frontSizes[1]/1024))KB"
Write-Host "backend/ scaffolded with Express + Postgres (bcryptjs, cart, all routes fixed)"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. cd backend && npm install"
Write-Host "  2. psql ""postgresql://postgres:ali@localhost:5432/solstice"" -f src/db/schema.sql"
Write-Host "  3. npm run dev"
Write-Host "  4. (new terminal) cd frontend && python -m http.server 7823"
