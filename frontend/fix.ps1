$content = Get-Content 'index.html' -Encoding UTF8 -Raw

$search1 = @"
        if (diff > 35) {
          const lum = 0.299 * od[i] + 0.587 * od[i+1] + 0.114 * od[i+2];
          // Neon Cyan / Electric Gold lens & rim tint
          if (lum < 95) {
            // Dark tinted lens area -> electric neon cyan glow with high saturation
            nd[i]   = Math.min(255, od[i] * 0.3 + 0);      // R
            nd[i+1] = Math.min(255, od[i+1] * 0.4 + 235);  // G (electric cyan)
            nd[i+2] = Math.min(255, od[i+2] * 0.4 + 255);  // B
          } else {
            // Frame highlights / edges -> vivid luminous electric gold / teal rim
            nd[i]   = Math.min(255, od[i] * 0.6 + 50);
            nd[i+1] = Math.min(255, od[i+1] * 0.8 + 220);
            nd[i+2] = Math.min(255, od[i+2] * 0.7 + 240);
          }
        }
"@

$replace1 = @"
        if (diff > 35) {
          const lum = 0.299 * od[i] + 0.587 * od[i+1] + 0.114 * od[i+2];
          // Neon Cyan / Electric Gold lens & rim tint
          if (lum < 95) {
            // Dark tinted lens area -> electric neon cyan glow with high saturation
            nd[i]   = Math.min(255, od[i] * 0.3 + 0);      // R
            nd[i+1] = Math.min(255, od[i+1] * 0.4 + 235);  // G (electric cyan)
            nd[i+2] = Math.min(255, od[i+2] * 0.4 + 255);  // B
          } else {
            // Frame highlights / edges -> vivid luminous electric gold / teal rim
            nd[i]   = Math.min(255, od[i] * 0.6 + 50);
            nd[i+1] = Math.min(255, od[i+1] * 0.8 + 220);
            nd[i+2] = Math.min(255, od[i+2] * 0.7 + 240);
          }
        } else {
          // Make non-glasses pixels transparent so only the glasses glow
          nd[i+3] = 0;
        }
"@

$search2 = @"
  // Stamp neon glow ONLY on glasses frame area (dark mode) or reveal over-image (light mode)
  function stamp(x, y){
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    if (isDark) {
      // Dark mode: draw neon glow effect (only glasses frame cadre lights up)
      if (!offNeon || !brushC) return;
      const r = radius;
      const tmp = document.createElement('canvas');
      tmp.width = brushC.width; tmp.height = brushC.height;
      const tc = tmp.getContext('2d');
      // Clip the neon-only layer by brush mask
      tc.drawImage(offNeon, -(x - r), -(y - r));
      tc.globalCompositeOperation = 'destination-in';
      tc.drawImage(brushC, 0, 0);
      // Composite neon onto canvas with screen blend for luminous glow
      ctx.globalCompositeOperation = 'screen';
      ctx.globalAlpha = 0.92;
      ctx.drawImage(tmp, x - r, y - r);
      ctx.globalAlpha = 1;
      // Add extra radial neon glow corona for electric lightning feel
      const gx = ctx.createRadialGradient(x / dpr * dpr, y / dpr * dpr, 0, x / dpr * dpr, y / dpr * dpr, r * 0.55);
      gx.addColorStop(0, 'rgba(0,255,255,0.18)');
      gx.addColorStop(0.45, 'rgba(0,200,255,0.09)');
      gx.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.globalCompositeOperation = 'screen';
      ctx.fillStyle = gx;
      ctx.beginPath();
      ctx.arc(x, y, r * 0.55, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalCompositeOperation = 'source-over';
    } else {
      // Light mode: liquid reveal of over-image
      if (!offOver || !brushC) return;
      const r = radius;
      const tmp = document.createElement('canvas');
      tmp.width = brushC.width; tmp.height = brushC.height;
      const tc = tmp.getContext('2d');
      tc.drawImage(offOver, -(x - r), -(y - r));
      tc.globalCompositeOperation = 'destination-in';
      tc.drawImage(brushC, 0, 0);
      ctx.globalCompositeOperation = 'source-over';
      ctx.drawImage(tmp, x - r, y - r);
    }
  }

  let lastX = -1, lastY = -1, idleF = 0;
  let velX = 0, velY = 0; // velocity for smooth cursor easing
  function frameTick(){
    requestAnimationFrame(frameTick);
    if(!offBase) return;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const fd = idleF > 120 ? Math.min(DECAY + idleF * 0.004, 0.5) : DECAY;
    if (isDark) {
      // Dark mode: clear canvas and draw dimmed base image, then neon trail fades naturally
      ctx.globalCompositeOperation = 'destination-out';
      ctx.fillStyle = `rgba(0,0,0,${Math.min(fd * 1.4, 0.6)})`;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.globalCompositeOperation = 'destination-over';
      // Draw darkened girl image (dark mode dims it for focus)
      ctx.save();
      ctx.globalAlpha = 1;
      ctx.drawImage(offBase, 0, 0);
      // Darken overlay - semi-transparent dark layer on top of base
      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 0.38;
      ctx.fillStyle = '#000';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.restore();
    } else {
      // Light mode: standard liquid reveal fade
      ctx.globalCompositeOperation = 'destination-out';
      ctx.fillStyle = `rgba(0,0,0,${fd})`;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.globalCompositeOperation = 'destination-over';
      if(offBase) ctx.drawImage(offBase, 0, 0);
    }
    idleF++;
  }
"@

$replace2 = @"
  // Stamp neon glow ONLY on glasses frame area (dark mode) or reveal over-image (light mode)
  function stamp(x, y){
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    if (isDark) {
      // Dark mode: draw neon glow effect (only glasses frame cadre lights up)
      if (!offNeon || !brushC) return;
      const r = radius;
      const tmp = document.createElement('canvas');
      tmp.width = brushC.width; tmp.height = brushC.height;
      const tc = tmp.getContext('2d');
      // Clip the neon-only layer by brush mask
      tc.drawImage(offNeon, -(x - r), -(y - r));
      tc.globalCompositeOperation = 'destination-in';
      tc.drawImage(brushC, 0, 0);
      // Composite neon onto canvas with screen blend for luminous glow
      ctx.globalCompositeOperation = 'screen';
      ctx.globalAlpha = 0.92;
      ctx.drawImage(tmp, x - r, y - r);
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = 'source-over';
    } else {
      // Light mode: liquid reveal of over-image
      if (!offOver || !brushC) return;
      const r = radius;
      const tmp = document.createElement('canvas');
      tmp.width = brushC.width; tmp.height = brushC.height;
      const tc = tmp.getContext('2d');
      tc.drawImage(offOver, -(x - r), -(y - r));
      tc.globalCompositeOperation = 'destination-in';
      tc.drawImage(brushC, 0, 0);
      ctx.globalCompositeOperation = 'source-over';
      ctx.drawImage(tmp, x - r, y - r);
    }
  }

  let lastX = -1, lastY = -1, idleF = 0;
  function frameTick(){
    requestAnimationFrame(frameTick);
    if(!offBase) return;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const fd = idleF > 120 ? Math.min(DECAY + idleF * 0.004, 0.5) : DECAY;
    
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = `rgba(0,0,0,${fd})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    ctx.globalCompositeOperation = 'destination-over';
    if(offBase) {
      if (isDark) {
        ctx.globalAlpha = 0.5; // Dim the girl image
        ctx.drawImage(offBase, 0, 0);
        ctx.globalAlpha = 1.0;
      } else {
        ctx.drawImage(offBase, 0, 0);
      }
    }
    idleF++;
  }
"@

$content = $content.Replace($search1, $replace1)
$content = $content.Replace($search2, $replace2)

[System.IO.File]::WriteAllText('index.html', $content, [System.Text.Encoding]::UTF8)
Write-Output "Replacements completed successfully."
