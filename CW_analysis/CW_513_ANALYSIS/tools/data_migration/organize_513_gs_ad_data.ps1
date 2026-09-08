param(
    [Parameter(Mandatory = $true)]
    [string]$DataRoot
)

$ErrorActionPreference = 'Stop'

# LEGACY SCRIPT: this script creates the former channel-first tree and is kept
# only for historical reference. For the current device -> metric -> channel
# layout, use migrate_ad9245_metric_first.ps1 instead.
# This legacy script never deletes source files.
$canonicalRoot = Join-Path $DataRoot '513_GS_AD_DATA'
$metadataRoot = Join-Path $canonicalRoot '00_Metadata'
$manifestPath = Join-Path $metadataRoot 'file_manifest.csv'
$rows = New-Object System.Collections.Generic.List[object]

if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    Write-Host ('Manifest already exists. No files were copied: {0}' -f $manifestPath)
    exit 0
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-FrequencyHz([string]$Text) {
    # Remove the channel token first. Otherwise X3G is incorrectly read as 3 GHz.
    $channelMatch = [regex]::Match($Text, '(?i)X[1-4]G[_-]')
    if ($channelMatch.Success) {
        $Text = $Text.Substring($channelMatch.Index + $channelMatch.Length)
    }
    $match = [regex]::Match($Text, '(?i)(\d+(?:\.\d+)?)\s*(GHz|MHz|kHz|Hz|G|M|K)')
    if (-not $match.Success) { return $null }
    $value = [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    switch ($match.Groups[2].Value.ToLowerInvariant()) {
        'ghz' { return $value * 1e9 }
        'mhz' { return $value * 1e6 }
        'khz' { return $value * 1e3 }
        'hz'  { return $value }
        'g'   { return $value * 1e9 }
        'm'   { return $value * 1e6 }
        'k'   { return $value * 1e3 }
    }
    return $null
}

function Get-PowerDbm([string]$Text) {
    $match = [regex]::Match($Text, '(?i)(-?\d+(?:\.\d+)?)\s*dBm')
    if (-not $match.Success) { return $null }
    return [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

function Format-Frequency([Nullable[double]]$FrequencyHz) {
    if ($null -eq $FrequencyHz) { return '' }
    if ($FrequencyHz -ge 1e9) { return ('{0:g}GHz' -f ($FrequencyHz / 1e9)) }
    if ($FrequencyHz -ge 1e6) { return ('{0:g}MHz' -f ($FrequencyHz / 1e6)) }
    if ($FrequencyHz -ge 1e3) { return ('{0:g}kHz' -f ($FrequencyHz / 1e3)) }
    return ('{0:g}Hz' -f $FrequencyHz)
}

function Format-Power([Nullable[double]]$PowerDbm) {
    if ($null -eq $PowerDbm) { return '' }
    return ('{0:g}dBm' -f $PowerDbm)
}

function Get-NextDestination([string]$Folder, [string]$BaseName) {
    $candidate = Join-Path $Folder ($BaseName + '.csv')
    $run = 1
    while (Test-Path -LiteralPath $candidate) {
        $run++
        $candidate = Join-Path $Folder ('{0}_run{1:d2}.csv' -f $BaseName, $run)
    }
    return $candidate
}

function Add-CopiedFile {
    param(
        [System.IO.FileInfo]$SourceFile,
        [string]$Device,
        [string]$Channel,
        [string]$TestItem,
        [Nullable[double]]$FrequencyHz,
        [Nullable[double]]$InputPowerDbm,
        [string]$DrivenChannel = '',
        [string]$CaptureChannel = '',
        [string]$SourceSet = '',
        [string]$BaseName
    )

    $destinationFolder = Join-Path $canonicalRoot (Join-Path $Device (Join-Path $Channel (Join-Path $TestItem 'raw')))
    Ensure-Directory $destinationFolder
    Ensure-Directory (Join-Path (Split-Path -Parent $destinationFolder) 'results')
    $destinationPath = Get-NextDestination $destinationFolder $BaseName
    Copy-Item -LiteralPath $SourceFile.FullName -Destination $destinationPath -Force:$false
    $sourceHash = (Get-FileHash -LiteralPath $SourceFile.FullName -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $destinationHash) {
        throw "SHA-256 校验失败：$($SourceFile.FullName)"
    }

    $relativePath = $destinationPath.Substring($canonicalRoot.Length + 1)
    $rows.Add([pscustomobject]@{
        FileName = [System.IO.Path]::GetFileName($destinationPath)
        RelativePath = $relativePath
        OriginalFileName = $SourceFile.Name
        SourcePath = $SourceFile.FullName
        Device = $Device
        Channel = $Channel
        TestItem = $TestItem
        DrivenChannel = $DrivenChannel
        CaptureChannel = $CaptureChannel
        FrequencyHz = $FrequencyHz
        InputPowerDbm = $InputPowerDbm
        ClockFrequencyHz = 25000000
        SampleRateHz = 25000000
        AdcBits = 14
        CodeFormat = 'signed'
        DataColumn = 0
        RunId = 'run01'
        SourceSet = $SourceSet
        SHA256 = $sourceHash
        Status = 'copied_verified'
        Notes = ''
    })
}

function Get-ChannelFromName([string]$Name) {
    $match = [regex]::Match($Name.ToUpperInvariant(), 'X([1-4])G')
    if ($match.Success) { return 'X' + $match.Groups[1].Value + 'G' }
    return $null
}

function Get-SourceFiles([string]$Folder) {
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Folder -File -Filter '*.csv' |
        Where-Object { $_.Name -notmatch '(?i)(summary|result|log)' })
}

Ensure-Directory $canonicalRoot
Ensure-Directory $metadataRoot
Ensure-Directory (Join-Path $canonicalRoot '99_Archive')
foreach ($device in @('AD2208', 'DA9726', 'AD9245', 'DA766', 'AD677', 'RF_REF')) {
    Ensure-Directory (Join-Path $canonicalRoot $device)
}

# Existing organized data: copy only raw CSV files into the new AD9245 tree.
$existingRoot = Join-Path $canonicalRoot 'AD9245'

foreach ($channel in @('X1G', 'X2G', 'X3G', 'X4G')) {
    $sfdrFolder = Join-Path $canonicalRoot ('AD_SFDR_25MHz_6dBm\' + $channel)
    foreach ($file in (Get-SourceFiles $sfdrFolder)) {
        $frequency = Get-FrequencyHz $file.Name
        $power = Get-PowerDbm $sfdrFolder
        $base = 'SFDR_{0}_{1}_{2}' -f $channel, (Format-Frequency $frequency), (Format-Power $power)
        Add-CopiedFile $file 'AD9245' $channel 'SFDR' $frequency $power '' '' 'existing_AD_SFDR' $base
    }

    $powerFolder = Join-Path $canonicalRoot ('AD_GONGLV_IN\' + $channel)
    foreach ($file in (Get-SourceFiles $powerFolder)) {
        $frequency = Get-FrequencyHz $file.Name
        if ($null -eq $frequency) { $frequency = 1e6 }
        $power = Get-PowerDbm $file.Name
        $base = 'InputPowerScale_{0}_{1}_{2}' -f $channel, (Format-Frequency $frequency), (Format-Power $power)
        Add-CopiedFile $file 'AD9245' $channel 'InputPowerScale' $frequency $power '' '' 'existing_AD_GONGLV_IN' $base
    }

    $inlFolder = Join-Path $canonicalRoot ('AD_INL_DNL\' + $channel)
    $sampleIndex = 0
    foreach ($file in (Get-SourceFiles $inlFolder)) {
        $sampleIndex++
        $base = 'INL_DNL_{0}_sample{1:d3}' -f $channel, $sampleIndex
        Add-CopiedFile $file 'AD9245' $channel 'INL_DNL' $null $null '' '' 'existing_AD_INL_DNL' $base
    }
}

# Frequency response data is currently flat in AD_PINLV_IN.
$frequencyFolder = Join-Path $canonicalRoot 'AD_PINLV_IN'
foreach ($file in (Get-SourceFiles $frequencyFolder)) {
    $channel = Get-ChannelFromName $file.Name
    if ($null -eq $channel) { continue }
    $frequency = Get-FrequencyHz $file.Name
    $power = Get-PowerDbm $file.Name
    $base = 'FrequencyResponse_{0}_{1}_{2}' -f $channel, (Format-Frequency $frequency), (Format-Power $power)
    Add-CopiedFile $file 'AD9245' $channel 'FrequencyResponse' $frequency $power '' '' 'existing_AD_PINLV_IN' $base
}

# Existing isolation captures use the folder name as the driven channel.
$isolationRoot = Join-Path $canonicalRoot 'AD_GELIDU'
if (Test-Path -LiteralPath $isolationRoot -PathType Container) {
    foreach ($scenario in (Get-ChildItem -LiteralPath $isolationRoot -Directory)) {
        $driven = Get-ChannelFromName $scenario.Name
        if ($null -eq $driven) { continue }
        $frequency = Get-FrequencyHz $scenario.Name
        if ($null -eq $frequency) { $frequency = 1e6 }
        # The legacy folder X3G-1M-7dbm uses hyphens as separators; -7 is
        # a positive 7 dBm condition, not a negative power value.
        $power = 7
        foreach ($file in (Get-SourceFiles $scenario.FullName)) {
            $capture = Get-ChannelFromName $file.Name
            if ($null -eq $capture) { continue }
            $base = 'Isolation_drive_{0}_capture_{1}_{2}_{3}' -f $driven, $capture, (Format-Frequency $frequency), (Format-Power $power)
            Add-CopiedFile $file 'AD9245' $driven 'Isolation' $frequency $power $driven $capture 'existing_AD_GELIDU' $base
        }
    }
}

# Legacy X3G source folders are also copied, without deleting the old folders.
$legacyFrequency = Join-Path $DataRoot 'freq_scale\X3G'
foreach ($file in (Get-SourceFiles $legacyFrequency)) {
    $frequency = Get-FrequencyHz $file.Name
    $power = Get-PowerDbm $file.Name
    $base = 'FrequencyResponse_X3G_{0}_{1}' -f (Format-Frequency $frequency), (Format-Power $power)
    Add-CopiedFile $file 'AD9245' 'X3G' 'FrequencyResponse' $frequency $power '' '' 'legacy_freq_scale_X3G' $base
}

$legacyPower = Join-Path $DataRoot 'Power_Scale_1MHz'
foreach ($file in (Get-SourceFiles $legacyPower)) {
    $frequency = Get-FrequencyHz $file.Name
    if ($null -eq $frequency) { $frequency = 1e6 }
    $power = Get-PowerDbm $file.Name
    $base = 'InputPowerScale_X3G_{0}_{1}' -f (Format-Frequency $frequency), (Format-Power $power)
    Add-CopiedFile $file 'AD9245' 'X3G' 'InputPowerScale' $frequency $power '' '' 'legacy_Power_Scale_1MHz' $base
}

$legacyIsolation = Join-Path $DataRoot 'GeLiDu\X3G_1MHz_7dBm'
foreach ($file in (Get-SourceFiles $legacyIsolation)) {
    $capture = Get-ChannelFromName $file.Name
    if ($null -eq $capture) { continue }
    $base = 'Isolation_drive_X3G_capture_{0}_1MHz_7dBm' -f $capture
    Add-CopiedFile $file 'AD9245' 'X3G' 'Isolation' 1e6 7 'X3G' $capture 'legacy_GeLiDu_X3G_1MHz_7dBm' $base
}

$rows | Sort-Object RelativePath | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8

Write-Host ('Copied and verified {0} raw CSV files.' -f $rows.Count)
Write-Host ('Canonical data root: {0}' -f $canonicalRoot)
Write-Host ('Manifest: {0}' -f $manifestPath)
