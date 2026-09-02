$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# Find the start of drawCover
$startLine = -1
$endLine = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'function drawCover\(ctx, img, cw, ch\)\{') {
        $startLine = $i
        break
    }
}

for ($i = $startLine; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'window\.addEventListener\(''resize''') {
        $endLine = $i + 4
        break
    }
}

Write-Output "Replacing from line $($startLine+1) to $($endLine+1)"

if ($startLine -ge 0 -and $endLine -ge 0) {
    $newCode = @"
  // Layout geometry guarantees both images are scaled and positioned identically
  let layout = { scale: 1, sw: 0, sh: 0, dx: 0, dy: 0 };

  function drawCover(ctx, img, cw, ch, isBase){
    if (isBase) {
      const iw = img.naturalWidth, ih = img.naturalHeight;
      if(!iw||!ih) return;
      layout.scale = Math.max(cw/iw, ch/ih);
      layout.sw = iw * layout.scale;
      layout.sh = ih * layout.scale;
      layout.dx = (cw - layout.sw) / 2;
      layout.dy = (ch - layout.sh) / 2;
    }
    // Force both images to use the exact same dimensions to guarantee pixel-perfect registration
    ctx.drawImage(img, layout.dx, layout.dy, layout.sw, layout.sh);
  }

  function buildNeonLayer(W, H){
    if(!offBase || !offOver) return;
    offNeon = document.createElement('canvas');
    offNeon.width = W; offNeon.height = H;
    const nctx = offNeon.getContext('2d');
    nctx.drawImage(offOver, 0, 0);

    try {
      const baseData = offBase.getContext('2d').getImageData(0, 0, W, H);
      const overData = offOver.getContext('2d').getImageData(0, 0, W, H);
      const neonData = nctx.getImageData(0, 0, W, H);

      const bd = baseData.data, od = overData.data, nd = neonData.data;
      const len = bd.length;

      // Find ONLY the glasses frame/lens pixels via strict diff + darkness thresholds
      for (let i = 0; i < len; i += 4) {
        const rDiff = Math.abs(od[i] - bd[i]);
        const gDiff = Math.abs(od[i+1] - bd[i+1]);
        const bDiff = Math.abs(od[i+2] - bd[i+2]);
        const diff = rDiff + gDiff + bDiff;
        const lumBase = 0.299 * bd[i] + 0.587 * bd[i+1] + 0.114 * bd[i+2];
        const lumOver = 0.299 * od[i] + 0.587 * od[i+1] + 0.114 * od[i+2];

        // Strict: only flag as glasses if diff is HIGH (>90) so face skin is excluded
        // AND (pixel is dark lens OR it is a high-contrast edge vs bright background)
        const isGlassLens   = (diff > 90) && (lumOver < 80);
        const isGlassFrame  = (diff > 90) && (Math.abs(lumOver - lumBase) > 60);

        if (isGlassLens || isGlassFrame) {
          if (lumOver < 80) {
            // Tinted lens -> electric cyan-teal glow
            nd[i]   = 0;
            nd[i+1] = Math.min(255, 200 + lumOver * 0.5);
            nd[i+2] = 255;
            nd[i+3] = Math.min(255, od[i+3]);
          } else {
            // Frame rim -> vivid gold / teal highlight
            nd[i]   = Math.min(255, od[i] * 0.5 + 80);
            nd[i+1] = Math.min(255, od[i+1] * 0.6 + 200);
            nd[i+2] = Math.min(255, od[i+2] * 0.6 + 240);
            nd[i+3] = Math.min(255, od[i+3]);
          }
        } else {
          // Not a glasses pixel -> fully transparent in neon layer
          nd[i+3] = 0;
        }
      }
      nctx.putImageData(neonData, 0, 0);
    } catch(e) {
      console.warn("Neon glasses layer fallback:", e);
    }
  }

  function buildOffscreens(){
    const W = canvas.width, H = canvas.height;
    
    // Base offscreen
    offBase = document.createElement('canvas');
    offBase.width = W; offBase.height = H;
    const bx = offBase.getContext('2d');
    if (baseImg.complete && baseImg.naturalWidth) drawCover(bx, baseImg, W, H, true);
    else baseImg.onload = () => { drawCover(bx, baseImg, W, H, true); renderBase(); };

    // Over offscreen (uses identical layout to base)
    offOver = document.createElement('canvas');
    offOver.width = W; offOver.height = H;
    const ox = offOver.getContext('2d');
    if (overImg.complete && overImg.naturalWidth) {
      drawCover(ox, overImg, W, H, false);
      buildNeonLayer(W, H);
    } else {
      overImg.onload = () => {
        drawCover(ox, overImg, W, H, false);
        buildNeonLayer(W, H);
      };
    }

    // Brush
    radius = BRUSH_R * dpr;
    const bs = Math.ceil(radius * 2);
    brushC = document.createElement('canvas'); brushC.width = bs; brushC.height = bs;
    brushCtx = brushC.getContext('2d');
    makeBrush(); // pre-render brush
  }

  function renderBase(){
    if(!offBase) return;
    ctx.globalCompositeOperation = 'source-over';
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(offBase, 0, 0);
  }

  function resize(){
    const rect = container.getBoundingClientRect();
    canvas.width = Math.ceil(rect.width * dpr);
    canvas.height = Math.ceil(rect.height * dpr);
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    buildOffscreens();
    renderBase();
    currX = -1; currY = -1; targetX = -1; targetY = -1;
  }

  function makeBrush(){
    if(!brushCtx) return;
    brushCtx.clearRect(0, 0, brushC.width, brushC.height);
    const r = radius;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const g = brushCtx.createRadialGradient(r, r, 0, r, r, r);
    
    if (isDark) {
      // Dark mode: sharper window for neon glasses
      g.addColorStop(0, 'rgba(0,0,0,1)');
      g.addColorStop(0.35, 'rgba(0,0,0,0.9)');
      g.addColorStop(0.65, 'rgba(0,0,0,0.5)');
      g.addColorStop(1, 'rgba(0,0,0,0)');
    } else {
      // Light mode: soft feathered reveal window
      g.addColorStop(0, 'rgba(0,0,0,1)');
      g.addColorStop(0.55, 'rgba(0,0,0,0.85)');
      g.addColorStop(1, 'rgba(0,0,0,0)');
    }
    brushCtx.fillStyle = g;
    brushCtx.fillRect(0, 0, brushC.width, brushC.height);
  }

  let targetX = -1, targetY = -1;
  let currX = -1, currY = -1;

  function onMove(e){
    const rect = container.getBoundingClientRect();
    targetX = (e.clientX - rect.left) * dpr;
    targetY = (e.clientY - rect.top) * dpr;
    if (currX < 0) { currX = targetX; currY = targetY; }
  }

  function frameTick(){
    requestAnimationFrame(frameTick);
    if(!offBase) return;

    // Smooth lerping of the optical window
    if (targetX >= 0 && currX >= 0) {
      currX += (targetX - currX) * 0.25;
      currY += (targetY - currY) * 0.25;
    }

    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const source = isDark ? offNeon : offOver;
    
    // 1. Draw perfectly registered base layer
    ctx.globalCompositeOperation = 'source-over';
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    if (isDark) {
      ctx.globalAlpha = 0.78;
      ctx.drawImage(offBase, 0, 0);
      ctx.globalAlpha = 1.0;
    } else {
      ctx.drawImage(offBase, 0, 0);
    }

    // 2. Draw precise optical reveal window if active
    if (currX >= 0 && source && brushC) {
      const r = radius;
      
      // Calculate strict bounding box to maximize performance
      const sx = Math.max(0, currX - r);
      const sy = Math.max(0, currY - r);
      const sw = Math.min(canvas.width - sx, r * 2);
      const sh = Math.min(canvas.height - sy, r * 2);
      
      if (sw > 0 && sh > 0) {
        // Create an exact 1:1 masked window
        const tmp = document.createElement('canvas');
        tmp.width = sw; tmp.height = sh;
        const tc = tmp.getContext('2d');
        
        // Grab perfectly registered pixels from the same exact location
        tc.drawImage(source, sx, sy, sw, sh, 0, 0, sw, sh);
        
        // Apply smooth brush mask
        tc.globalCompositeOperation = 'destination-in';
        tc.drawImage(brushC, currX - sx - r, currY - sy - r);

        // Composite seamlessly onto main view
        ctx.globalCompositeOperation = isDark ? 'screen' : 'source-over';
        if(isDark) ctx.globalAlpha = 0.95;
        ctx.drawImage(tmp, sx, sy);
        ctx.globalAlpha = 1.0;
      }
    }
  }

  resize();
  window.addEventListener('resize', () => { resize(); makeBrush(); });
  window.addEventListener('pointermove', onMove);
  window.addEventListener('pointerleave', () => { targetX = -1; currX = -1; });
"@

    $before = $lines[0..($startLine-1)]
    $after  = $lines[($endLine+1)..($lines.Count-1)]
    $result = $before + ($newCode -split "`r`n") + $after

    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "Complete rewrite applied."
} else {
    Write-Output "ERROR: Could not find block bounds."
}
