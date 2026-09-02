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
        '  ',
        '  // Validation',
        '  const name = form.name.value.trim();',
        '  const email = form.email.value.trim();',
        '  const message = form.message.value.trim();',
        '  if (!name || !email || !message) return alert("Please fill in all fields");',
        '',
        '  // Trigger mailto link for temporary direct email contact',
        '  const subject = encodeURIComponent(`Solstice Eyewear Inquiry from ${name}`);',
        '  const body = encodeURIComponent(`${message}\n\n---\nReply to: ${name} (${email})`);',
        '  window.location.href = `mailto:debbicheali04@gmail.com?subject=${subject}&body=${body}`;',
        '',
        '  // Success transition',
        '  document.getElementById(''modal-form-view'').classList.add(''hidden'');',
        '  document.getElementById(''modal-success-view'').classList.remove(''hidden'');',
        '  setTimeout(closeModal, 3500);',
        '});'
    )
    $before = $lines[0..($jsStart-1)]
    $after  = $lines[($jsEnd+1)..($lines.Count-1)]
    $result = $before + $newJs + $after
    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "Fixed JS in index.html to use mailto!"
} else {
    Write-Output "ERROR: Could not find JS handler."
}
