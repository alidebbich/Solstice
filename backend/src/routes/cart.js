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