$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# Fix 1: Remove duplicate closing brace on line 985 (0-indexed: 984)
# and remove unused velX/velY on line 960 (0-indexed: 959)
$fixed = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    # Skip the duplicate extra closing brace after frameTick (line 985 = index 984)
    if ($i -eq 984 -and $line -match '^\s+\}\s*$') {
        # Check previous line ends the frameTick properly
        Write-Output "Skipping duplicate brace at line $($i+1): '$line'"
        continue
    }
    # Remove unused velX/velY declaration
    if ($line -match 'let velX = 0, velY = 0') {
        Write-Output "Removing velX/velY at line $($i+1)"
        continue
    }
    $fixed.Add($line)
}

[System.IO.File]::WriteAllLines('index.html', $fixed.ToArray(), [System.Text.Encoding]::UTF8)
Write-Output "Cleanup done. Total lines: $($fixed.Count)"
