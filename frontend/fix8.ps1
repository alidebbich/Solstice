$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# 1. FIX CSS FOOTER
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '#footer\{background:var\(--ink\);color:var\(--bg\);') {
        $lines[$i] = $lines[$i] -replace 'background:var\(--ink\);color:var\(--bg\);', 'background:var(--footer-bg);color:var(--footer-text);'
        Write-Output "Fixed CSS footer at line $($i+1)"
        break
    }
}

# 2. FIX JS REVEAL (frameTick)
$startTick = -1
$endTick = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'function frameTick\(\)\{') {
        $startTick = $i
    }
    if ($startTick -ge 0 -and $i -gt $startTick -and $lines[$i] -match '^\s+\}\s*$') {
        # find the end of frameTick by looking for the resize() call that follows it
        if ($lines[$i+1] -match '^\s*resize\(\);' -or $lines[$i+2] -match '^\s*resize\(\);' -or $lines[$i+3] -match '^\s*resize\(\);') {
            $endTick = $i
            break
        }
    }
}

if ($startTick -ge 0 -and $endTick -ge 0) {
    $newTick = @(
        '  function frameTick(){',
        '    requestAnimationFrame(frameTick);',
        '    if(!offBase) return;',
        '',
        '    // Smooth lerping of the optical window',
        '    if (targetX >= 0 && currX >= 0) {',
        '      currX += (targetX - currX) * 0.25;',
        '      currY += (targetY - currY) * 0.25;',
        '    }',
        '',
        '    const isDark = document.documentElement.getAttribute(''data-theme'') === ''dark'';',
        '    ',
        '    // 1. Draw perfectly registered base layer',
        '    ctx.globalCompositeOperation = ''source-over'';',
        '    ctx.clearRect(0, 0, canvas.width, canvas.height);',
        '    ',
        '    if (isDark) {',
        '      ctx.globalAlpha = 0.78;',
        '      ctx.drawImage(offBase, 0, 0);',
        '      ctx.globalAlpha = 1.0;',
        '    } else {',
        '      ctx.drawImage(offBase, 0, 0);',
        '    }',
        '',
        '    // 2. Draw precise optical reveal window if active',
        '    if (currX >= 0 && offOver && brushC) {',
        '      const r = radius;',
        '      ',
        '      // Calculate strict bounding box to maximize performance',
        '      const sx = Math.max(0, currX - r);',
        '      const sy = Math.max(0, currY - r);',
        '      const sw = Math.min(canvas.width - sx, r * 2);',
        '      const sh = Math.min(canvas.height - sy, r * 2);',
        '      ',
        '      if (sw > 0 && sh > 0) {',
        '        // Create an exact 1:1 masked window',
        '        const tmp = document.createElement(''canvas'');',
        '        tmp.width = sw; tmp.height = sh;',
        '        const tc = tmp.getContext(''2d'');',
        '        ',
        '        // Grab perfectly registered pixels from the same exact location from offOver (the second girl''s face)',
        '        tc.drawImage(offOver, sx, sy, sw, sh, 0, 0, sw, sh);',
        '        ',
        '        // In dark mode, add the neon glasses frame ON TOP of the face',
        '        if (isDark && offNeon) {',
        '          tc.globalCompositeOperation = ''screen'';',
        '          tc.drawImage(offNeon, sx, sy, sw, sh, 0, 0, sw, sh);',
        '        }',
        '        ',
        '        // Apply smooth brush mask',
        '        tc.globalCompositeOperation = ''destination-in'';',
        '        tc.drawImage(brushC, currX - sx - r, currY - sy - r);',
        '',
        '        // Composite seamlessly onto main view',
        '        ctx.globalCompositeOperation = ''source-over'';',
        '        ctx.drawImage(tmp, sx, sy);',
        '      }',
        '    }',
        '  }'
    )

    $before = $lines[0..($startTick-1)]
    $after  = $lines[($endTick+1)..($lines.Count-1)]
    $result = $before + $newTick + $after

    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "Fixed frameTick logic!"
} else {
    Write-Output "ERROR: Could not find frameTick. Start=$startTick End=$endTick"
}
