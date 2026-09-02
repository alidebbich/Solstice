// src/routes/admin.js — admin-only product & order management
const router       = require('express').Router();
const { z }        = require('zod');
const db           = require('../db');
const auth         = require('../middleware/auth');
const requireAdmin = require('../middleware/requireAdmin');

router.use(auth, requireAdmin);

const productSchema = z.object({
  slug:        z.string().min(1).max(80).regex(/^[a-z0-9-]+$/, 'Slug must be lowercase kebab-case'),
  name:        z.string().min(1).max(200),
  category:    z.enum(['sunglasses','optical','accessories']),
  description: z.string().optional(),
  price_cents: z.number().int().positive(),
  image_url:   z.string().url().optional(),
  stock:       z.number().int().min(0),
});

const updateProductSchema = productSchema.partial().omit({ slug: true });

// ── Products ──────────────────────────────────────────────────────────────

// GET /api/admin/products
router.get('/products', async (req, res, next) => {
  try {
    const { rows } = await db.query('SELECT * FROM products ORDER BY created_at DESC');
    res.json(rows);
  } catch (e) { next(e); }
});

// POST /api/admin/products
router.post('/products', async (req, res, next) => {
  try {
    const data = productSchema.parse(req.body);
    const { rows: [product] } = await db.query(
      `INSERT INTO products (slug,name,category,description,price_cents,image_url,stock)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [data.slug, data.name, data.category, data.description || null,
       data.price_cents, data.image_url || null, data.stock]
    );
    res.status(201).json(product);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'A product with that slug already exists' });
    next(e);
  }
});

// PATCH /api/admin/products/:id
router.patch('/products/:id', async (req, res, next) => {
  try {
    const data = updateProductSchema.parse(req.body);
    const fields = Object.keys(data);
    if (!fields.length) return res.status(400).json({ error: 'No fields to update' });

    const setClauses = fields.map((k, i) => `${k}=$${i + 2}`).join(', ');
    const values = [req.params.id, ...fields.map(k => data[k])];

    const { rows: [product] } = await db.query(
      `UPDATE products SET ${setClauses} WHERE id=$1 RETURNING *`, values
    );
    if (!product) return res.status(404).json({ error: 'Product not found' });
    res.json(product);
  } catch (e) { next(e); }
});

// DELETE /api/admin/products/:id — soft delete
router.delete('/products/:id', async (req, res, next) => {
  try {
    const { rows: [product] } = await db.query(
      'UPDATE products SET active=FALSE WHERE id=$1 RETURNING id,slug,name,active', [req.params.id]
    );
    if (!product) return res.status(404).json({ error: 'Product not found' });
    res.json(product);
  } catch (e) { next(e); }
});

// ── Orders ────────────────────────────────────────────────────────────────

// GET /api/admin/orders?page=1&limit=20
router.get('/orders', async (req, res, next) => {
  try {
    const page  = Math.max(1, parseInt(req.query.page)  || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const offset = (page - 1) * limit;

    const { rows: orders } = await db.query(
      `SELECT o.*, u.email, u.name AS customer_name
       FROM orders o
       JOIN users u ON u.id = o.user_id
       ORDER BY o.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );
    const { rows: [{ count }] } = await db.query('SELECT COUNT(*) FROM orders');
    res.json({ orders, total: parseInt(count), page, limit });
  } catch (e) { next(e); }
});

// PATCH /api/admin/orders/:id — update status
router.patch('/orders/:id', async (req, res, next) => {
  try {
    const { status } = z.object({
      status: z.enum(['pending','processing','shipped','delivered','cancelled'])
    }).parse(req.body);
    const { rows: [order] } = await db.query(
      'UPDATE orders SET status=$2 WHERE id=$1 RETURNING *', [req.params.id, status]
    );
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json(order);
  } catch (e) { next(e); }
});

// GET /api/admin/stats
router.get('/stats', async (req, res, next) => {
  try {
    const [
      { rows: [revenue] },
      { rows: [orders] },
      { rows: [customers] },
      { rows: topProducts },
    ] = await Promise.all([
      db.query("SELECT COALESCE(SUM(total_cents),0) AS total FROM orders WHERE status != 'cancelled'"),
      db.query("SELECT COUNT(*) AS total FROM orders"),
      db.query("SELECT COUNT(*) AS total FROM users WHERE role='customer'"),
      db.query(`
        SELECT p.name, SUM(oi.quantity) AS units_sold
        FROM order_items oi JOIN products p ON p.id=oi.product_id
        GROUP BY p.id ORDER BY units_sold DESC LIMIT 5
      `),
    ]);
    res.json({
      revenue_cents: parseInt(revenue.total),
      total_orders:  parseInt(orders.total),
      total_customers: parseInt(customers.total),
      top_products: topProducts,
    });
  } catch (e) { next(e); }
});

module.exports = router;
