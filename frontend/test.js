window.App = (function(){
  const API = 'http://localhost:3001/api';
  let user = null;
  let cart = { items: [], count: 0, subtotal_cents: 0 };
  let wishlist = JSON.parse(localStorage.getItem('solstice_wishlist') || '[]');
  let serverProducts = [];

  // ── DARK MODE ──────────────────────────────────────────────────────────────
  function initTheme() {
    const saved = localStorage.getItem('solstice_theme') || 'light';
    document.documentElement.setAttribute('data-theme', saved);
    document.querySelectorAll('.dark-toggle').forEach(t => {
      t.setAttribute('aria-label', saved === 'dark' ? 'Switch to light mode' : 'Switch to dark mode');
    });
  }
  window.toggleTheme = function() {
    const curr = document.documentElement.getAttribute('data-theme') || 'light';
    const next = curr === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('solstice_theme', next);
    document.querySelectorAll('.dark-toggle').forEach(t => {
      t.setAttribute('aria-label', next === 'dark' ? 'Switch to light mode' : 'Switch to dark mode');
    });
  };

  // ── FETCH WRAPPER ──────────────────────────────────────────────────────────
  async function apiFetch(path, options = {}) {
    if(!options.headers) options.headers = {};
    options.headers['Content-Type'] = 'application/json';
    const token = localStorage.getItem('solstice_token');
    if(token) options.headers['Authorization'] = `Bearer ${token}`;

    const res  = await fetch(`${API}${path}`, options);
    const data = await res.json().catch(() => ({}));
    if(!res.ok) throw new Error(data.error || `Error ${res.status}`);
    return data;
  }

  // ── AUTH ───────────────────────────────────────────────────────────────────
  async function checkAuth() {
    const token = localStorage.getItem('solstice_token');
    if(!token) { updateAuthUI(); return; }
    try {
      user = await apiFetch('/auth/me');
      updateAuthUI();
      await fetchCart();
    } catch(e) {
      // Token expired or invalid — clear it
      localStorage.removeItem('solstice_token');
      user = null;
      updateAuthUI();
    }
  }

  window.handleLogin = async function handleLogin(e) {
    e.preventDefault();
    clearAuthError();
    const fd   = new FormData(e.target);
    const body = { email: fd.get('email'), password: fd.get('password') };
    try {
      const data = await apiFetch('/auth/login', { method:'POST', body: JSON.stringify(body) });
      localStorage.setItem('solstice_token', data.token);
      user = data.user;
      e.target.reset();
      updateAuthUI();
      await fetchCart();
      closePanels();
      showToast(`Welcome back, ${user.name || 'Friend'} 👋`);
    } catch(err) { showAuthError(err.message); }
  };

  window.handleSignup = async function handleSignup(e) {
    e.preventDefault();
    clearAuthError();
    const fd   = new FormData(e.target);
    const firstName = fd.get('first_name') || '';
    const lastName  = fd.get('last_name')  || '';
    const body = {
      email:    fd.get('email'),
      password: fd.get('password'),
      phone:    fd.get('phone') || undefined,
      name:     [firstName, lastName].filter(Boolean).join(' ') || undefined,
    };
    try {
      const data = await apiFetch('/auth/signup', { method:'POST', body: JSON.stringify(body) });
      localStorage.setItem('solstice_token', data.token);
      user = data.user;
      e.target.reset();
      updateAuthUI();
      await fetchCart();
      closePanels();
      showToast(`Account created! Welcome, ${user.name || 'Friend'} ✨`);
    } catch(err) { showAuthError(err.message); }
  };

  window.logout = function logout() {
    localStorage.removeItem('solstice_token');
    user = null;
    cart = { items: [], count: 0, subtotal_cents: 0 };
    updateAuthUI();
    updateCartUI();
    closePanels();
    showToast('Signed out successfully');
  };

  // Google OAuth — opens Google popup (requires Google Identity Services script in prod)
  window.handleGoogleLogin = function() {
    // In production: initialize google.accounts.oauth2.initTokenClient(...)
    // For now, show a clear message to the user
    showToast('Google Sign-In: Add your Google Client ID to .env to enable', 4000);
    // Stub: if you have a google_id from Google SDK, call:
    // apiFetch('/auth/google', { method:'POST', body: JSON.stringify({ google_id, email, name, avatar_url }) })
  };

  window.saveProfile = async function saveProfile(e) {
    e.preventDefault();
    const fd   = new FormData(e.target);
    const body = {
      phone:   fd.get('phone')   || undefined,
      address: fd.get('address') || undefined,
      city:    fd.get('city')    || undefined,
      country: fd.get('country') || undefined,
    };
    try {
      user = await apiFetch('/auth/profile', { method:'PATCH', body: JSON.stringify(body) });
      showToast('Profile saved ✓');
    } catch(err) { showToast(err.message); }
  };

  // ── CART ───────────────────────────────────────────────────────────────────
  async function fetchCart() {
    if(!user) return;
    try {
      cart = await apiFetch('/cart');
      updateCartUI();
    } catch(e) { console.error('Cart fetch failed:', e); }
  }

  window.addToCart = async function addToCart(slug, name, price) {
    if(!user) { openAuth(); showToast('Please sign in to add to cart'); return; }
    const product = serverProducts.find(p => p.slug === slug);
    if(!product) { showToast('Product not found. Refresh the page.'); return; }
    try {
      cart = await apiFetch('/cart', {
        method: 'POST',
        body:   JSON.stringify({ product_id: product.id, quantity: 1 }),
      });
      updateCartUI();
      showToast(`${name} added to cart 🛍️`);
    } catch(e) { showToast(e.message); }
  };

  window.updateQty = async function updateQty(itemId, qty) {
    try {
      cart = await apiFetch(`/cart/${itemId}`, { method:'PATCH', body: JSON.stringify({ quantity: qty }) });
      updateCartUI();
    } catch(e) { showToast(e.message); }
  };

  window.removeFromCart = async function removeFromCart(itemId) {
    try {
      cart = await apiFetch(`/cart/${itemId}`, { method:'DELETE' });
      updateCartUI();
    } catch(e) { showToast(e.message); }
  };

  window.openCheckout = function openCheckout() {
    if(!user) { openAuth(); showToast('Please sign in to checkout'); return; }
    if(!cart || cart.items.length === 0) { showToast('Your cart is empty'); return; }
    // Pre-fill shipping from profile
    if(user.address) document.getElementById('co-address').value = user.address;
    if(user.city)    document.getElementById('co-city').value    = user.city;
    if(user.country) document.getElementById('co-country').value = user.country;
    // Render order summary
    const summaryEl = document.getElementById('checkout-summary');
    summaryEl.innerHTML = cart.items.map(i => `
      <div class="checkout-summary-item">
        <span>${i.name} × ${i.quantity}</span>
        <span>${((i.price_cents * i.quantity) / 100).toFixed(2)}</span>
      </div>
    `).join('') + `
      <div class="checkout-summary-total">
        <span>Total</span><span>${(cart.subtotal_cents / 100).toFixed(2)}</span>
      </div>
    `;
    document.getElementById('pay-btn').textContent = `Pay ${(cart.subtotal_cents / 100).toFixed(2)}`;
    document.getElementById('checkout-panel').classList.add('open');
    document.getElementById('cart-panel').classList.remove('open');
  };

  window.submitCheckout = async function submitCheckout(e) {
    e.preventDefault();
    const btn = document.getElementById('pay-btn');
    const orig = btn.textContent;
    btn.textContent = 'Processing…';
    btn.disabled = true;

    const fd = new FormData(e.target);
    try {
      await new Promise(r => setTimeout(r, 1200)); // simulate payment
      const orderItems = cart.items.map(i => ({ product_id: i.product_id, quantity: i.quantity }));
      await apiFetch('/orders/checkout', {
        method: 'POST',
        body:   JSON.stringify({
          items:   orderItems,
          address: fd.get('address'),
          city:    fd.get('city'),
        }),
      });
      cart = { items: [], count: 0, subtotal_cents: 0 };
      updateCartUI();
      closePanels();
      e.target.reset();
      showToast('Order placed! Thank you 🎉', 5000);
    } catch(err) {
      showToast(err.message);
    } finally {
      btn.textContent = orig;
      btn.disabled = false;
    }
  };

  // ── UI HELPERS ─────────────────────────────────────────────────────────────
  function openAuth() {
    closePanels();
    document.getElementById('panel-backdrop').classList.add('open');
    document.getElementById('auth-panel').classList.add('open');
    clearAuthError();
    if(user) loadOrders();
  }

  function openCart() {
    if(!user) { openAuth(); return; }
    closePanels();
    document.getElementById('panel-backdrop').classList.add('open');
    document.getElementById('cart-panel').classList.add('open');
  }

  window.closePanels = function closePanels() {
    document.querySelectorAll('.side-panel').forEach(p => p.classList.remove('open'));
    document.getElementById('panel-backdrop').classList.remove('open');
  };

  window.switchAuth = function switchAuth(tab) {
    const isLogin = (tab === 'login');
    document.getElementById('form-login').classList.toggle('active', isLogin);
    document.getElementById('form-signup').classList.toggle('active', !isLogin);
    document.getElementById('tab-login').classList.toggle('active', isLogin);
    document.getElementById('tab-signup').classList.toggle('active', !isLogin);
    clearAuthError();
  };

  function updateAuthUI() {
    const authBtnText = document.getElementById('auth-btn-text');
    const tabsWrap    = document.getElementById('auth-tabs-wrap');
    const loginForm   = document.getElementById('form-login');
    const signupForm  = document.getElementById('form-signup');
    const userView    = document.getElementById('auth-user-view');

    if(user) {
      if(authBtnText) authBtnText.textContent = user.name ? user.name.split(' ')[0] : 'Account';
      if(tabsWrap)    tabsWrap.style.display = 'none';
      if(loginForm)   loginForm.classList.remove('active');
      if(signupForm)  signupForm.classList.remove('active');
      if(userView)    userView.classList.add('active');
      // Fill profile view
      const nameEl = document.getElementById('auth-user-name');
      const emailEl = document.getElementById('auth-user-email');
      const initEl  = document.getElementById('user-avatar-initial');
      if(nameEl)  nameEl.textContent  = user.name || '—';
      if(emailEl) emailEl.textContent = user.email;
      if(initEl)  initEl.textContent  = (user.name || user.email || '?')[0].toUpperCase();
      if(user.avatar_url) {
        const wrap = document.getElementById('user-avatar-wrap');
        if(wrap) wrap.innerHTML = `<img src="${user.avatar_url}" alt="avatar" />`;
      }
      // Pre-fill profile form
      if(user.phone)   { const el = document.getElementById('prof-phone');   if(el) el.value = user.phone; }
      if(user.address) { const el = document.getElementById('prof-address'); if(el) el.value = user.address; }
      if(user.city)    { const el = document.getElementById('prof-city');    if(el) el.value = user.city; }
      if(user.country) { const el = document.getElementById('prof-country'); if(el) el.value = user.country; }
    } else {
      if(authBtnText) authBtnText.textContent = 'Sign In';
      if(tabsWrap)    tabsWrap.style.display = '';
      if(loginForm)   loginForm.classList.add('active');
      if(signupForm)  signupForm.classList.remove('active');
      if(userView)    userView.classList.remove('active');
    }
  }

  function updateCartUI() {
    const countEls = document.querySelectorAll('#header-cart-count, #cart-count');
    const totalEl  = document.getElementById('cart-total');
    const itemsEl  = document.getElementById('cart-items');
    const cbtn     = document.getElementById('checkout-btn');

    countEls.forEach(el => { if(el) el.textContent = cart.count || 0; });
    if(totalEl) totalEl.textContent = `${((cart.subtotal_cents || 0) / 100).toFixed(2)}`;

    if(!itemsEl) return;
    if(!cart.items || cart.items.length === 0) {
      itemsEl.innerHTML = '<div class="cart-empty"><div class="cart-empty-icon">🛍️</div>Your cart is empty</div>';
      if(cbtn) { cbtn.style.opacity = '0.45'; cbtn.style.pointerEvents = 'none'; }
    } else {
      if(cbtn) { cbtn.style.opacity = '1'; cbtn.style.pointerEvents = 'auto'; }
      itemsEl.innerHTML = cart.items.map(i => `
        <div class="cart-item">
          <img src="${i.image_url || ''}" class="cart-img" alt="${i.name}" onerror="this.style.display='none'" />
          <div class="cart-info">
            <div class="cart-name">${i.name}</div>
            <div class="cart-price">${(i.price_cents / 100).toFixed(2)} each</div>
            <div class="cart-qty">
              <button class="qty-btn" onclick="App.updateQty('${i.id}', ${i.quantity - 1})" aria-label="Decrease">−</button>
              <span style="min-width:1.5rem; text-align:center; font-weight:600;">${i.quantity}</span>
              <button class="qty-btn" onclick="App.updateQty('${i.id}', ${i.quantity + 1})" aria-label="Increase">+</button>
              <button class="qty-btn" onclick="App.removeFromCart('${i.id}')" aria-label="Remove" style="margin-left:0.5rem;">🗑</button>
            </div>
          </div>
          <div style="font-weight:700; font-size:0.9375rem;">${((i.price_cents * i.quantity) / 100).toFixed(2)}</div>
        </div>
      `).join('');
    }
  }

  async function loadOrders() {
    const list = document.getElementById('orders-list');
    if(!list) return;
    try {
      const orders = await apiFetch('/orders');
      if(orders.length === 0) {
        list.innerHTML = '<div style="color:var(--muted); font-size:0.875rem;">No orders yet.</div>';
        return;
      }
      list.innerHTML = orders.map(o => `
        <div style="padding:0.875rem 1rem; background:var(--surface); border-radius:0.875rem;">
          <div style="display:flex; justify-content:space-between; font-weight:700; margin-bottom:0.25rem;">
            <span>Order #${o.id.slice(0,8)}</span>
            <span style="color:var(--gold);">${(o.total_cents/100).toFixed(2)}</span>
          </div>
          <div style="font-size:0.8125rem; color:var(--muted); display:flex; gap:1rem;">
            <span>${new Date(o.created_at).toLocaleDateString()}</span>
            <span style="text-transform:uppercase; font-weight:600;">${o.status}</span>
          </div>
        </div>
      `).join('');
    } catch(e) {
      if(list) list.innerHTML = '<div style="color:var(--muted); font-size:0.875rem;">Could not load orders.</div>';
    }
  }

  // ── WISHLIST ───────────────────────────────────────────────────────────────
  function toggleWishlist(btn, id) {
    const idx = wishlist.indexOf(id);
    if(idx > -1) { wishlist.splice(idx, 1); btn.classList.remove('active'); showToast('Removed from wishlist'); }
    else         { wishlist.push(id);       btn.classList.add('active');    showToast('Saved to wishlist ♥'); }
    localStorage.setItem('solstice_wishlist', JSON.stringify(wishlist));
  }

  function initWishlistUI() {
    document.querySelectorAll('.btn-wishlist').forEach(btn => {
      const id = btn.closest('[data-id]')?.dataset?.id;
      if(!id) return;
      if(wishlist.includes(id)) btn.classList.add('active');
      btn.addEventListener('click', e => { e.preventDefault(); e.stopPropagation(); toggleWishlist(btn, id); });
    });
  }

  // ── TOAST ──────────────────────────────────────────────────────────────────
  window.showToast = function showToast(msg, duration = 3500) {
    let c = document.getElementById('toast-container');
    if(!c) { c = document.createElement('div'); c.id = 'toast-container'; c.setAttribute('aria-live','polite'); document.body.appendChild(c); }
    const t = document.createElement('div');
    t.className = 'toast';
    t.textContent = msg;
    c.appendChild(t);
    setTimeout(() => t.remove(), duration);
  };

  function showAuthError(msg) {
    const el = document.getElementById('auth-global-error');
    if(!el) return;
    el.textContent = msg;
    el.style.display = 'block';
  }
  function clearAuthError() {
    const el = document.getElementById('auth-global-error');
    if(el) { el.textContent = ''; el.style.display = 'none'; }
  }

  // ── PRODUCTS ───────────────────────────────────────────────────────────────
  async function fetchProducts() {
    try { serverProducts = await apiFetch('/products'); } catch(e) {}
  }

  // ── INIT ───────────────────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', async () => {
    initTheme();
    await fetchProducts();
    await checkAuth();
    initWishlistUI();

    // Wire header auth buttons
    document.querySelectorAll('.header-btn-auth').forEach(b => b.addEventListener('click', openAuth));
    // Wire header cart buttons
    document.querySelectorAll('.header-btn-cart').forEach(b => b.addEventListener('click', openCart));
    // Wire dark mode toggles
    document.querySelectorAll('.dark-toggle').forEach(b => b.addEventListener('click', toggleTheme));
  });

  // Public API
  return {
    handleLogin, handleSignup, handleGoogleLogin,
    logout, saveProfile,
    switchAuth, closePanels,
    addToCart, updateQty, removeFromCart,
    openCheckout, submitCheckout,
    openCart: () => openCart(),
    openAuth: () => openAuth(),
    showToast: window.showToast,
  };
})();

