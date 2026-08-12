param(
    [string]$WorkspaceRoot = 'F:\01_Laser',
    [string]$OutputDirectory = 'F:\01_Laser\.code_reorg_work'
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
if ($resolvedRoot -ne 'F:\01_Laser') {
    throw "Unexpected workspace root: $resolvedRoot"
}

$sourcePaths = @(
    'MATLAB',
    '202607_上海_电2\logic',
    '.Xil',
    '20260727_513test\02_GS与延迟驱动测试\03_Analysis_分析脚本与结果',
    '20260727_513test\02_GS与延迟驱动测试\04_FPGA_工程与固件\01_Source_工程主副本',
    '20260727_513test\02_GS与延迟驱动测试\04_FPGA_工程与固件\99_Generated_可重建生成物',
    '20260727_513test\02_GS与延迟驱动测试\99_Review_待确认\疑似重复FPGA工程_LOGIC_jianding_szsd_ver729',
    '20260727_513test\03_CW测试\04_FPGA_工程与固件\01_Source_工程主副本',
    '20260727_513test\03_CW测试\04_FPGA_工程与固件\99_Generated_可重建生成物'
)

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

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$files = [System.Collections.Generic.List[object]]::new()
foreach ($relativeSource in $sourcePaths) {
    $source = Join-Path $resolvedRoot $relativeSource
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Required source does not exist: $source"
    }
    foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force) {
        $files.Add($file)
    }
}

$started = Get-Date
$totalBytes = [int64](($files | Measure-Object Length -Sum).Sum)
[ordered]@{
    WorkspaceRoot = $resolvedRoot
    SnapshotTime = $started.ToString('o')
    SourcePaths = $sourcePaths
    FileCount = $files.Count
    TotalBytes = $totalBytes
} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $OutputDirectory 'before_code_summary.json') -Encoding utf8

$progressPath = Join-Path $OutputDirectory 'inventory_progress.log'
"Started: $($started.ToString('o'))`r`nFiles: $($files.Count)`r`nBytes: $totalBytes" |
    Set-Content -LiteralPath $progressPath -Encoding utf8

$manifest = [System.Collections.Generic.List[object]]::new()
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
    $manifest.Add([pscustomobject]@{
        OriginalRelativePath = $relativePath
        SizeBytes = $file.Length
        LastWriteTime = $file.LastWriteTime.ToString('o')
        SHA256 = $hash
        Status = $status
    })
    if ((($index + 1) % 250) -eq 0 -or ($index + 1) -eq $files.Count) {
        "Hashed $($index + 1)/$($files.Count): $relativePath" |
            Add-Content -LiteralPath $progressPath -Encoding utf8
    }
}

$manifest | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'before_code_manifest_sha256.csv') -NoTypeInformation -Encoding utf8

$sourceExtensions = @(
    '.v', '.sv', '.vh', '.vhd', '.vhdl', '.xdc', '.xci', '.xcix',
    '.xpr', '.tcl', '.m', '.mlx', '.slx', '.mdl', '.mem', '.coe',
    '.py', '.ps1', '.bat', '.sh', '.md'
)
$manifest |
    Where-Object { $sourceExtensions -contains [System.IO.Path]::GetExtension($_.OriginalRelativePath).ToLowerInvariant() } |
    Export-Csv -LiteralPath (Join-Path $OutputDirectory 'before_source_code_manifest_sha256.csv') -NoTypeInformation -Encoding utf8

$finished = Get-Date
"Finished: $($finished.ToString('o'))`r`nElapsed: $($finished - $started)" |
    Add-Content -LiteralPath $progressPath -Encoding utf8
