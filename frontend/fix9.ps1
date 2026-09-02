$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# Find the exact extra brace
$found = $false
for ($i = 985; $i -lt 1005; $i++) {
    if ($lines[$i] -match '^\s*\}\s*$') {
        if ($lines[$i+1] -match '^\s*\}\s*$') {
            if ($lines[$i+2] -match '^\s*\}\s*$') {
                if ($lines[$i+3] -match '^\s*\}\s*$') {
                    # We found 4 closing braces in a row! The last one is extra.
                    $lines[$i+3] = ""
                    $found = $true
                    Write-Output "Removed extra brace at line $($i+4)"
                    break
                }
            }
        }
    }
}

if ($found) {
    [System.IO.File]::WriteAllLines('index.html', $lines, [System.Text.Encoding]::UTF8)
} else {
    Write-Output "Could not find the 4 consecutive braces."
}
