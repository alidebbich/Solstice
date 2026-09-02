$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# 1. Update CSS
$cssAdded = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\.form-input:\s*focus') {
        # Replace the focus styling to a premium dark outline instead of green box shadow
        $lines[$i] = '    .form-input:focus,.form-textarea:focus{border-color:var(--ink);outline:none;box-shadow:none}'
    }
    
    # Insert the autofill overrides right after .form-textarea
    if ($lines[$i] -match '\.form-textarea\{resize:vertical;min-height:7rem\}' -and -not $cssAdded) {
        $autofillCss = @(
            '    .form-input:-webkit-autofill,',
            '    .form-textarea:-webkit-autofill {',
            '      -webkit-box-shadow: 0 0 0 1000px var(--modal-bg) inset !important;',
            '      -webkit-text-fill-color: var(--modal-text) !important;',
            '      transition: background-color 5000s ease-in-out 0s;',
            '    }'
        )
        $before = $lines[0..$i]
        $after  = $lines[($i+1)..($lines.Count-1)]
        $lines = $before + $autofillCss + $after
        $cssAdded = $true
        # Continue loop from after the inserted content
        $i = $i + $autofillCss.Count
    }
}

# 2. Update JS Handler
$jsStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "document\.getElementById\('contact-form'\)\.addEventListener\('submit',e=>\{") {
        $jsStart = $i
        break
    }
}

if ($jsStart -ge 0) {
    # It's currently a one-liner on line 1113
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
    $after  = $lines[($jsStart+1)..($lines.Count-1)]
    $result = $before + $newJs + $after
    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "Fixed CSS and JS in index.html!"
} else {
    Write-Output "ERROR: Could not find JS handler."
}
