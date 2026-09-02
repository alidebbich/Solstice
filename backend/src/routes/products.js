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