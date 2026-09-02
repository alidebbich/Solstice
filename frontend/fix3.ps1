$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# Find the frameTick function start and replace the dark mode block
$startLine = -1
$endLine = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'function frameTick\(\)\{' -and $startLine -eq -1) {
        $startLine = $i
    }
    if ($startLine -ge 0 -and $i -gt $startLine -and $lines[$i] -match '^\s+idleF\+\+;') {
        $endLine = $i
        break
    }
}

Write-Output "frameTick at lines $($startLine+1) to $($endLine+1)"

if ($startLine -ge 0 -and $endLine -ge 0) {
    $newFrameTick = @(
        '  function frameTick(){',
        '    requestAnimationFrame(frameTick);',
        '    if(!offBase) return;',
        '    const isDark = document.documentElement.getAttribute(''data-theme'') === ''dark'';',
        '    const fd = idleF > 120 ? Math.min(DECAY + idleF * 0.004, 0.5) : DECAY;',
        '',
        '    // Fade out the painted neon/reveal layer',
        '    ctx.globalCompositeOperation = ''destination-out'';',
        '    ctx.fillStyle = `rgba(0,0,0,${fd})`;',
        '    ctx.fillRect(0, 0, canvas.width, canvas.height);',
        '',
        '    // Draw the base image underneath (slightly dimmed in dark mode)',
        '    ctx.globalCompositeOperation = ''destination-over'';',
        '    if (offBase) {',
        '      if (isDark) {',
        '        ctx.globalAlpha = 0.78;',
        '        ctx.drawImage(offBase, 0, 0);',
        '        ctx.globalAlpha = 1;',
        '      } else {',
        '        ctx.drawImage(offBase, 0, 0);',
        '      }',
        '    }',
        '    idleF++;',
        '  }'
    )

    $before = $lines[0..($startLine-1)]
    $after  = $lines[($endLine+1)..($lines.Count-1)]
    $result = $before + $newFrameTick + $after

    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "frameTick replaced successfully."
} else {
    Write-Output "ERROR: Could not find frameTick bounds. Start=$startLine End=$endLine"
}
