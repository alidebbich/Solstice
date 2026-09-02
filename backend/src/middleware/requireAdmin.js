// src/middleware/requireAdmin.js
// Chain after auth middleware. Rejects non-admin users with 403.
module.exports = function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};
