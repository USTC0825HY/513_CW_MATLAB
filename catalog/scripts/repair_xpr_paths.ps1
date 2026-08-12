param(
    [string]$CodeRoot = 'F:\01_Laser\code',
    [string]$WorkDirectory = 'F:\01_Laser\.code_reorg_work'
)

$ErrorActionPreference = 'Stop'
$resolvedCodeRoot = (Resolve-Path -LiteralPath $CodeRoot).Path
if ($resolvedCodeRoot -ne 'F:\01_Laser\code') {
    throw "Unexpected code root: $resolvedCodeRoot"
}

function Get-Sha256Hex {
    param([string]$LiteralPath)
    $stream = [System.IO.File]::OpenRead($LiteralPath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '')
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

$rows = [System.Collections.Generic.List[object]]::new()
$projectRoots = @(
    (Join-Path $resolvedCodeRoot 'fpga\projects'),
    (Join-Path $resolvedCodeRoot 'fpga\legacy'),
    (Join-Path $resolvedCodeRoot 'fpga\experiments')
)

foreach ($projectRoot in $projectRoots) {
    foreach ($file in Get-ChildItem -LiteralPath $projectRoot -File -Recurse -Filter '*.xpr' -Force -ErrorAction SilentlyContinue) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $match = [regex]::Match($text, '<Project\s+Version="[^"]+"\s+Minor="[^"]+"\s+Path="([^"]*)">')
        if (-not $match.Success) {
            $rows.Add([pscustomobject]@{
                ProjectFile = $file.FullName
                OldPath = ''
                NewPath = ''
                SHA256Before = Get-Sha256Hex $file.FullName
                SHA256After = ''
                Status = 'REVIEW_REQUIRED'
                Notes = 'Project Path attribute was not found.'
            })
            continue
        }
        $oldPath = $match.Groups[1].Value
        $newPath = $file.FullName.Replace('\', '/')
        $hashBefore = Get-Sha256Hex $file.FullName
        if ($oldPath -ne $newPath) {
            $replacement = $match.Value.Replace('Path="' + $oldPath + '"', 'Path="' + $newPath + '"')
            $updated = $text.Substring(0, $match.Index) + $replacement + $text.Substring($match.Index + $match.Length)
            [System.IO.File]::WriteAllText($file.FullName, $updated, [System.Text.UTF8Encoding]::new($false))
        }
        [xml]([System.IO.File]::ReadAllText($file.FullName)) | Out-Null
        $rows.Add([pscustomobject]@{
            ProjectFile = $file.FullName
            OldPath = $oldPath
            NewPath = $newPath
            SHA256Before = $hashBefore
            SHA256After = Get-Sha256Hex $file.FullName
            Status = if ($oldPath -eq $newPath) { 'UNCHANGED' } else { 'UPDATED' }
            Notes = ''
        })
    }
}

$rows | Export-Csv -LiteralPath (Join-Path $WorkDirectory 'xpr_path_repairs.csv') -NoTypeInformation -Encoding utf8
