$content = Get-Content 'index.html' -Encoding UTF8 -Raw

# FIX 1: Better glasses-only pixel detection in buildNeonLayer
# Raise threshold from 35 to 90, and require the pixel is DARK (lens) or BRIGHT-edge (frame)
# Also remove the "else nd[i+3]=0" that was partially applied, and do it properly here
$old1 = '      // Find glasses mask and apply vibrant neon cyber colors ONLY to the glasses
      for (let i = 0; i < len; i += 4) {
        const rDiff = Math.abs(od[i] - bd[i]);
        const gDiff = Math.abs(od[i+1] - bd[i+1]);
        const bDiff = Math.abs(od[i+2] - bd[i+2]);
        const diff = rDiff + gDiff + bDiff;

        // If difference is significant, this pixel belongs to the glasses / sunglasses
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
      }'

$new1 = '      // Find ONLY the glasses frame/lens pixels via strict diff + darkness thresholds
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
      }'

# FIX 2: Fix frameTick dark mode - remove the broken save/restore + dark overlay
# Replace the whole dark-mode branch with a simpler, less dark approach
$old2 = '    if (isDark) {
      // Dark mode: clear canvas and draw dimmed base image, then neon trail fades naturally
      ctx.globalCompositeOperation = ''destination-out'';
      ctx.fillStyle = `rgba(0,0,0,${Math.min(fd * 1.4, 0.6)})`;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.globalCompositeOperation = ''destination-over'';
      // Draw darkened girl image (dark mode dims it for focus)
      ctx.save();
      ctx.globalAlpha = 1;
      ctx.drawImage(offBase, 0, 0);
      // Darken overlay - semi-transparent dark layer on top of base
      ctx.globalCompositeOperation = ''source-over'';
      ctx.globalAlpha = 0.38;
      ctx.fillStyle = ''#000'';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.restore();
    } else {
      // Light mode: standard liquid reveal fade
      ctx.globalCompositeOperation = ''destination-out'';
      ctx.fillStyle = `rgba(0,0,0,${fd})`;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.globalCompositeOperation = ''destination-over'';
      if(offBase) ctx.drawImage(offBase, 0, 0);
    }'

$new2 = '    // Both modes: fade out the painted layer
    ctx.globalCompositeOperation = ''destination-out'';
    ctx.fillStyle = `rgba(0,0,0,${fd})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.globalCompositeOperation = ''destination-over'';
    if (offBase) {
      if (isDark) {
        // Dark mode: draw base image at 80% opacity - slightly dimmed but still visible
        ctx.globalAlpha = 0.80;
        ctx.drawImage(offBase, 0, 0);
        ctx.globalAlpha = 1;
      } else {
        ctx.drawImage(offBase, 0, 0);
      }
    }'

$content = $content.Replace($old1, $new1)
$content = $content.Replace($old2, $new2)

[System.IO.File]::WriteAllText('index.html', $content, [System.Text.Encoding]::UTF8)
Write-Output "Done. Replaced: diff-threshold fixed + dark mode brightness fixed."
