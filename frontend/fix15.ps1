$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

$jsStart = -1
$jsEnd = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "document\.getElementById\('contact-form'\)\.addEventListener\('submit', async e => \{") {
        $jsStart = $i
    }
    if ($jsStart -ge 0 -and $i -gt $jsStart -and $lines[$i] -match '^\}\);$') {
        $jsEnd = $i
        break
    }
}

if ($jsStart -ge 0 -and $jsEnd -ge 0) {
    $newJs = @(
        'document.getElementById(''contact-form'').addEventListener(''submit'', async e => {',
        '  e.preventDefault();',
        '  const form = e.target;',
        '  const btn = form.querySelector(''button[type="submit"]'');',
        '  const originalText = btn.textContent;',
        '  ',
        '  // Validation',
        '  const name = form.name.value.trim();',
        '  const email = form.email.value.trim();',
        '  const message = form.message.value.trim();',
        '  if (!name || !email || !message) return alert("Please fill in all fields");',
        '',
        '  // Loading state',
        '  btn.textContent = "Sending...";',
        '  btn.disabled = true;',
        '  btn.style.opacity = "0.7";',
        '',
        '  try {',
        '    const res = await fetch("http://localhost:3001/api/contact", {',
        '      method: "POST",',
        '      headers: { "Content-Type": "application/json" },',
        '      body: JSON.stringify({ name, email, message })',
        '    });',
        '    if (!res.ok) throw new Error("Failed to send message");',
        '    ',
        '    // Success transition',
        '    document.getElementById(''modal-form-view'').classList.add(''hidden'');',
        '    document.getElementById(''modal-success-view'').classList.remove(''hidden'');',
        '    setTimeout(closeModal, 3500);',
        '  } catch (err) {',
        '    console.error(err);',
        '    alert("Something went wrong. Please try again.");',
        '  } finally {',
        '    btn.textContent = originalText;',
        '    btn.disabled = false;',
        '    btn.style.opacity = "1";',
        '  }',
        '});'
    )
    $before = $lines[0..($jsStart-1)]
    $after  = $lines[($jsEnd+1)..($lines.Count-1)]
    $result = $before + $newJs + $after
    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "Reverted JS to fetch API!"
} else {
    Write-Output "ERROR: Could not find JS handler."
}
