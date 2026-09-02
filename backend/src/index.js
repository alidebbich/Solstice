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

// CSRF stub (no cookies used — JWT in header)
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
