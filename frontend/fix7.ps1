$lines = [System.IO.File]::ReadAllLines('index.html', [System.Text.Encoding]::UTF8)

# Find the end of the replaced block
$insertIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'const CARDS=\[') {
        $insertIndex = $i - 1
        break
    }
}

if ($insertIndex -ge 0) {
    $newLines = @(
        '  frameTick();',
        '}'
    )
    $before = $lines[0..($insertIndex-1)]
    $after  = $lines[$insertIndex..($lines.Count-1)]
    $result = $before + $newLines + $after
    [System.IO.File]::WriteAllLines('index.html', $result, [System.Text.Encoding]::UTF8)
    Write-Output "Added frameTick() and closing brace before line $($insertIndex+1)"
}
