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