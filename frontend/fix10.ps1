$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# FIX CSS STATS
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '#stats\{padding:5rem 1\.25rem;background:var\(--ink\);color:var\(--bg\);') {
        $lines[$i] = $lines[$i] -replace 'background:var\(--ink\);color:var\(--bg\);', 'background:var(--stats-bg);color:var(--stats-text);'
        Write-Output "Fixed CSS stats at line $($i+1)"
        break
    }
}

[System.IO.File]::WriteAllLines('index.html', $lines, [System.Text.Encoding]::UTF8)
