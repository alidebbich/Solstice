$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

$startLine = 851 # 0-indexed for 852
$endLine = 881   # 0-indexed for 882

$newCode = @(
    '  function buildOffscreens(){',
    '    const W = canvas.width, H = canvas.height;',
    '    ',
    '    // Ensure both images are loaded before building offscreens',
    '    if (!baseImg.complete || !baseImg.naturalWidth || !overImg.complete || !overImg.naturalWidth) {',
    '      // Wait for both to load, then re-trigger buildOffscreens',
    '      if (!window.__imagesWaiting) {',
    '        window.__imagesWaiting = true;',
    '        let loaded = 0;',
    '        const check = () => { loaded++; if(loaded === 2) { window.__imagesWaiting = false; buildOffscreens(); renderBase(); } };',
    '        if (baseImg.complete && baseImg.naturalWidth) loaded++; else baseImg.onload = check;',
    '        if (overImg.complete && overImg.naturalWidth) loaded++; else overImg.onload = check;',
    '      }',
    '      return;',
    '    }',
    '',
    '    // Base offscreen',
    '    offBase = document.createElement(''canvas'');',
    '    offBase.width = W; offBase.height = H;',
    '    const bx = offBase.getContext(''2d'');',
    '    drawCover(bx, baseImg, W, H, true);',
    '',
    '    // Over offscreen (uses identical layout to base)',
    '    offOver = document.createElement(''canvas'');',
    '    offOver.width = W; offOver.height = H;',
    '    const ox = offOver.getContext(''2d'');',
    '    drawCover(ox, overImg, W, H, false);',
    '',
    '    // Generate neon layer from perfectly registered over offscreen',
    '    buildNeonLayer(W, H);',
    '',
    '    // Brush',
    '    radius = BRUSH_R * dpr;',
    '    const bs = Math.ceil(radius * 2);',
    '    brushC = document.createElement(''canvas''); brushC.width = bs; brushC.height = bs;',
    '    brushCtx = brushC.getContext(''2d'');',
    '    makeBrush(); // pre-render brush',
    '  }'
)

$before = $lines[0..($startLine-1)]
$after  = $lines[($endLine+1)..($lines.Count-1)]
$result = $before + $newCode + $after

[System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
Write-Output "Fixed buildOffscreens race condition!"
