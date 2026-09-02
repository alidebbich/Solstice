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