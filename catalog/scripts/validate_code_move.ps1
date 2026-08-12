param(
    [string]$WorkspaceRoot = 'F:\01_Laser',
    [string]$WorkDirectory = 'F:\01_Laser\.code_reorg_work'
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
if ($resolvedRoot -ne 'F:\01_Laser') {
    throw "Unexpected workspace root: $resolvedRoot"
}

$before = @(Import-Csv -LiteralPath (Join-Path $WorkDirectory 'before_code_manifest_sha256.csv'))
$moves = @(Import-Csv -LiteralPath (Join-Path $WorkDirectory 'code_move_map.csv'))

function Get-Sha256Hex {
    param([string]$LiteralPath)
    $stream = $null
    $sha = $null
    try {
        $stream = [System.IO.File]::Open(
            $LiteralPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        $sha = [System.Security.Cryptography.SHA256]::Create()
        return [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '')
    }
    finally {
        if ($sha) { $sha.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function Get-CurrentRelativePath {
    param([string]$OriginalRelativePath)
    $current = $OriginalRelativePath
    foreach ($move in $moves) {
        if ($current -eq $move.SourceRelative) {
            $current = $move.DestinationRelative
        }
        elseif ($current.StartsWith($move.SourceRelative + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            $suffix = $current.Substring($move.SourceRelative.Length).TrimStart('\')
            $current = Join-Path $move.DestinationRelative $suffix
        }
    }
    return $current
}

$files = @(Get-ChildItem -LiteralPath (Join-Path $resolvedRoot 'code') -File -Recurse -Force)
$progressPath = Join-Path $WorkDirectory 'validation_progress.log'
"Started: $((Get-Date).ToString('o'))`r`nFiles: $($files.Count)" |
    Set-Content -LiteralPath $progressPath -Encoding utf8

$after = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $files.Count; $index++) {
    $file = $files[$index]
    $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\')
    $hash = ''
    $status = 'OK'
    try {
        $hash = Get-Sha256Hex -LiteralPath $file.FullName
    }
    catch {
        $status = 'HASH_ERROR: ' + $_.Exception.Message
    }
    $after.Add([pscustomobject]@{
        CurrentRelativePath = $relativePath
        SizeBytes = $file.Length
        SHA256 = $hash
        Status = $status
    })
    if ((($index + 1) % 250) -eq 0 -or ($index + 1) -eq $files.Count) {
        "Hashed $($index + 1)/$($files.Count): $relativePath" |
            Add-Content -LiteralPath $progressPath -Encoding utf8
    }
}
$after | Export-Csv -LiteralPath (Join-Path $WorkDirectory 'after_move_code_manifest_sha256.csv') -NoTypeInformation -Encoding utf8

$afterByPath = @{}
foreach ($entry in $after) {
    $afterByPath[$entry.CurrentRelativePath.ToLowerInvariant()] = $entry
}

$integrity = foreach ($entry in $before) {
    $expected = Get-CurrentRelativePath $entry.OriginalRelativePath
    $key = $expected.ToLowerInvariant()
    if (-not $afterByPath.ContainsKey($key)) {
        [pscustomobject]@{
            OriginalRelativePath = $entry.OriginalRelativePath
            CurrentRelativePath = $expected
            SizeBefore = $entry.SizeBytes
            SizeAfter = ''
            SHA256Before = $entry.SHA256
            SHA256After = ''
            Status = 'MISSING'
        }
        continue
    }
    $current = $afterByPath[$key]
    $status = if ($entry.SizeBytes -ne $current.SizeBytes) {
        'SIZE_MISMATCH'
    }
    elseif ($entry.SHA256 -ne $current.SHA256) {
        'HASH_MISMATCH'
    }
    else {
        'VERIFIED'
    }
    [pscustomobject]@{
        OriginalRelativePath = $entry.OriginalRelativePath
        CurrentRelativePath = $current.CurrentRelativePath
        SizeBefore = $entry.SizeBytes
        SizeAfter = $current.SizeBytes
        SHA256Before = $entry.SHA256
        SHA256After = $current.SHA256
        Status = $status
    }
}
$integrity | Export-Csv -LiteralPath (Join-Path $WorkDirectory 'code_move_integrity.csv') -NoTypeInformation -Encoding utf8

[ordered]@{
    ValidationTime = (Get-Date).ToString('o')
    BeforeFileCount = $before.Count
    AfterFileCount = $after.Count
    BeforeTotalBytes = [int64](($before | Measure-Object SizeBytes -Sum).Sum)
    AfterTotalBytes = [int64](($after | Measure-Object SizeBytes -Sum).Sum)
    VerifiedFiles = @($integrity | Where-Object Status -eq 'VERIFIED').Count
    MissingFiles = @($integrity | Where-Object Status -eq 'MISSING').Count
    SizeMismatchFiles = @($integrity | Where-Object Status -eq 'SIZE_MISMATCH').Count
    HashMismatchFiles = @($integrity | Where-Object Status -eq 'HASH_MISMATCH').Count
    HashErrors = @($after | Where-Object Status -ne 'OK').Count
} | ConvertTo-Json |
    Set-Content -LiteralPath (Join-Path $WorkDirectory 'code_move_validation_summary.json') -Encoding utf8

"Finished: $((Get-Date).ToString('o'))" |
    Add-Content -LiteralPath $progressPath -Encoding utf8
