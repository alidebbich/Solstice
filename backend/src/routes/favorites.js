const router = require("express").Router();
const { z }  = require("zod");
const db     = require("../db");
const auth   = require("../middleware/auth");

router.use(auth);

// GET /api/favorites — list all favorited products for the logged-in user
router.get("/", async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT f.product_id, f.created_at,
         p.slug, p.name, p.category, p.price_cents, p.image_url, p.description
       FROM favorites f
       JOIN products p ON p.id = f.product_id
       WHERE f.user_id = $1
       ORDER BY f.created_at DESC`,
      [req.user.sub]
    );
    res.json(rows);
  } catch(e) { next(e); }
});

// POST /api/favorites — add a product to favorites
router.post("/", async (req, res, next) => {
  try {
    const { product_id } = z.object({
      product_id: z.string().uuid(),
    }).parse(req.body);

    const { rows: [product] } = await db.query(
      "SELECT id FROM products WHERE id=$1 AND active=TRUE", [product_id]
    );
    if (!product) return res.status(404).json({ error: "Product not found" });

    await db.query(
      `INSERT INTO favorites (user_id, product_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, product_id) DO NOTHING`,
      [req.user.sub, product_id]
    );

    const { rows } = await db.query(
      `SELECT f.product_id, f.created_at,
         p.slug, p.name, p.category, p.price_cents, p.image_url, p.description
       FROM favorites f
       JOIN products p ON p.id = f.product_id
       WHERE f.user_id = $1
       ORDER BY f.created_at DESC`,
      [req.user.sub]
    );
    res.status(201).json(rows);
  } catch(e) { next(e); }
});

// DELETE /api/favorites/:productId — remove a specific product from favorites
router.delete("/:productId", async (req, res, next) => {
  try {
    await db.query(
      "DELETE FROM favorites WHERE user_id=$1 AND product_id=$2",
      [req.user.sub, req.params.productId]
    );
    const { rows } = await db.query(
      `SELECT f.product_id, f.created_at,
         p.slug, p.name, p.category, p.price_cents, p.image_url, p.description
       FROM favorites f
       JOIN products p ON p.id = f.product_id
       WHERE f.user_id = $1
       ORDER BY f.created_at DESC`,
      [req.user.sub]
    );
    res.json(rows);
  } catch(e) { next(e); }
});

module.exports = router;
