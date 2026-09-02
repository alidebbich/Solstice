-- Solstice Eyewear â€” Database Schema v2
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