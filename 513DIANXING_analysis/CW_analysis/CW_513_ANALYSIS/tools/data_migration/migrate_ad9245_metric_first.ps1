param(
    [string]$DataRoot = 'F:\01_Laser\20260727_513test\02_GS与延迟驱动测试\02_Data_测试数据\513_GS_AD_DATA'
)

$ErrorActionPreference = 'Stop'

$device = 'AD9245'
$channels = @('X1G', 'X2G', 'X3G', 'X4G')
$metrics = @(
    [pscustomobject]@{ Id = 'SFDR'; Folder = '01_SFDR'; ChineseName = '无杂散动态范围'; Requirement = '>65 dB'; Unit = 'dB'; Script = 'adc_sfdr_analysis.m'; Summary = 'ADC_SFDR_summary.csv' },
    [pscustomobject]@{ Id = 'FrequencyResponse'; Folder = '02_FrequencyResponse'; ChineseName = '输入频率响应和3 dB带宽'; Requirement = 'DC-10 MHz；3 dB带宽下限按细则确认'; Unit = 'MHz'; Script = 'adc_bandwidth_analysis.m'; Summary = 'ADC_bandwidth_summary.csv' },
    [pscustomobject]@{ Id = 'InputPowerScale'; Folder = '03_InputPowerScale'; ChineseName = '输入功率响应'; Requirement = '1 MHz；-10-6 dBm；核查5-6 dBm饱和'; Unit = 'dBm/dBFS'; Script = 'adc_power_scale_analysis.m'; Summary = 'ADC_power_scale_summary.csv' },
    [pscustomobject]@{ Id = 'Isolation'; Folder = '04_Isolation'; ChineseName = '通道隔离度'; Requirement = '>40 dB'; Unit = 'dB'; Script = 'adc_isolation_analysis.m'; Summary = 'ADC_isolation_summary.csv' },
    [pscustomobject]@{ Id = 'INL_DNL'; Folder = '05_INL_DNL'; ChineseName = '积分非线性和微分非线性'; Requirement = 'INL<=20 LSB；DNL<=5 LSB'; Unit = 'LSB'; Script = 'adc_inl_dnl_analysis.m'; Summary = 'ADC_inl_dnl_summary.csv' }
)

function Get-RelativePath([string]$Path, [string]$Base) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $baseFull = [System.IO.Path]::GetFullPath($Base).TrimEnd('\') + '\'
    if (-not $full.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside data root: $Path"
    }
    return $full.Substring($baseFull.Length).Replace('/', '\')
}

function Get-Hash([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Copy-VerifiedFile([string]$Source, [string]$Target) {
    $targetParent = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Target) {
        if ((Get-Hash $Source) -ne (Get-Hash $Target)) {
            throw "Target exists but SHA-256 differs: $Target"
        }
        return
    }

    Copy-Item -LiteralPath $Source -Destination $Target
    if ((Get-Hash $Source) -ne (Get-Hash $Target)) {
        throw "SHA-256 verification failed after copy: $Target"
    }
}

function Parse-FrequencyHz([string]$FileName) {
    $m = [regex]::Match($FileName, '(?i)(?<value>\d+(?:\.\d+)?)(?<unit>GHz|MHz|kHz|Hz)')
    if (-not $m.Success) { return '' }
    $value = [double]$m.Groups['value'].Value
    switch ($m.Groups['unit'].Value.ToLowerInvariant()) {
        'ghz' { return [string]($value * 1e9) }
        'mhz' { return [string]($value * 1e6) }
        'khz' { return [string]($value * 1e3) }
        default { return [string]$value }
    }
}

function Parse-PowerDbm([string]$FileName) {
    $m = [regex]::Match($FileName, '(?i)(?<value>-?\d+(?:\.\d+)?)dBm')
    if ($m.Success) { return $m.Groups['value'].Value }
    return ''
}

function Parse-RunId([string]$FileName) {
    $m = [regex]::Match($FileName, '(?i)run(?<value>\d+)')
    if ($m.Success) { return ('run' + $m.Groups['value'].Value) }
    return ''
}

function Parse-IsolationChannels([string]$FileName, [string]$DefaultDriven) {
    $m = [regex]::Match($FileName, '(?i)drive_(?<drive>X[1-4]G)_capture_(?<capture>X[1-4]G)')
    if ($m.Success) {
        return [pscustomobject]@{ Driven = $m.Groups['drive'].Value.ToUpperInvariant(); Capture = $m.Groups['capture'].Value.ToUpperInvariant() }
    }
    return [pscustomobject]@{ Driven = $DefaultDriven; Capture = '' }
}

function New-ManifestRow([string]$MetricId, [string]$Channel, [string]$FileName, [string]$RelativePath, [string]$Sha256) {
    $metric = $metrics | Where-Object { $_.Id -eq $MetricId } | Select-Object -First 1
    $iso = Parse-IsolationChannels $FileName $Channel
    [pscustomobject]@{
        DeviceId = $device
        MetricId = $MetricId
        ChannelId = $Channel
        FileName = $FileName
        RelativePath = $RelativePath
        OriginalFileName = $FileName
        DrivenChannel = $iso.Driven
        CaptureChannel = $iso.Capture
        FrequencyHz = Parse-FrequencyHz $FileName
        InputPowerDbm = Parse-PowerDbm $FileName
        ClockFrequencyHz = '25000000'
        SampleRateHz = '25000000'
        AdcBits = '14'
        CodeFormat = 'signed'
        DataColumn = 'last'
        RunId = Parse-RunId $FileName
        SHA256 = $Sha256
        Status = 'copied'
        Notes = '25 MHz and 14-bit signed are processing configuration values; sample rate requires independent measurement.'
    }
}

$dataRootFull = [System.IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
$deviceRoot = Join-Path $dataRootFull $device
$metadataRoot = Join-Path $dataRootFull '00_Metadata'
$reportRoot = Join-Path $dataRootFull '98_ReportResults'
$archiveRoot = Join-Path $dataRootFull '99_Archive\AD9245_ChannelFirst_20260802'

foreach ($folder in @($metadataRoot, $reportRoot, $archiveRoot)) {
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

$manifestRows = New-Object System.Collections.Generic.List[object]
$resultRows = New-Object System.Collections.Generic.List[object]

foreach ($metric in $metrics) {
    foreach ($channel in $channels) {
        $oldMetricRoot = Join-Path $deviceRoot "$channel\$($metric.Id)"
        $newMetricRoot = Join-Path $deviceRoot "$($metric.Folder)\$channel"
        $oldRaw = Join-Path $oldMetricRoot 'raw'
        $oldResults = Join-Path $oldMetricRoot 'results'
        $newRaw = Join-Path $newMetricRoot 'raw'
        $newResults = Join-Path $newMetricRoot 'results'

        if (-not (Test-Path -LiteralPath $oldRaw)) {
            throw "Missing source raw folder: $oldRaw"
        }
        New-Item -ItemType Directory -Path $newRaw,$newResults -Force | Out-Null

        foreach ($sourceFile in @(Get-ChildItem -LiteralPath $oldRaw -File)) {
            $targetFile = Join-Path $newRaw $sourceFile.Name
            Copy-VerifiedFile $sourceFile.FullName $targetFile
            $manifestRows.Add((New-ManifestRow $metric.Id $channel $sourceFile.Name (Get-RelativePath $targetFile $dataRootFull) (Get-Hash $sourceFile.FullName)))
        }

        if (Test-Path -LiteralPath $oldResults) {
            foreach ($sourceFile in @(Get-ChildItem -LiteralPath $oldResults -File)) {
                $targetFile = Join-Path $newResults $sourceFile.Name
                Copy-VerifiedFile $sourceFile.FullName $targetFile
            }
        }

        $summary = Join-Path $newResults $metric.Summary
        $figures = @(Get-ChildItem -LiteralPath $newResults -File -Filter '*.png' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $logs = @(Get-ChildItem -LiteralPath $newResults -File -Filter '*log*.txt' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $resultRows.Add([pscustomobject]@{
            DeviceId = $device
            MetricId = $metric.Id
            ChannelId = $channel
            SummaryFile = if (Test-Path -LiteralPath $summary) { Get-RelativePath $summary $dataRootFull } else { '' }
            FigureFile = ($figures -join ';')
            LogFile = ($logs -join ';')
            ResultFolder = Get-RelativePath $newResults $dataRootFull
            ProcessingScript = $metric.Script
            ProcessingDate = '2026-08-02'
            Status = if (Test-Path -LiteralPath $summary) { 'Completed' } else { 'RawCopied_ResultMissing' }
            Notes = ''
        })
    }
}

$metricRows = foreach ($metric in $metrics) {
    [pscustomobject]@{
        MetricId = $metric.Id
        FolderName = $metric.Folder
        ChineseName = $metric.ChineseName
        Requirement = $metric.Requirement
        Unit = $metric.Unit
        ScriptName = $metric.Script
        PrimaryOutput = $metric.Summary
    }
}

$metricRows | Export-Csv -LiteralPath (Join-Path $metadataRoot 'metric_registry.csv') -NoTypeInformation -Encoding utf8
$manifestRows | Export-Csv -LiteralPath (Join-Path $metadataRoot 'measurement_manifest.csv') -NoTypeInformation -Encoding utf8
$resultRows | Export-Csv -LiteralPath (Join-Path $metadataRoot 'result_manifest.csv') -NoTypeInformation -Encoding utf8

$readme = @"
# 513_GS_AD_DATA 数据目录

目录层级固定为：器件 -> 指标 -> 接口/通道 -> raw/results。

机器可读目录只使用英文、数字和下划线；通道目录只表示物理接口，
测试频率、输入功率和运行次数写入文件名及清单。

指标目录：

    01_SFDR              无杂散动态范围
    02_FrequencyResponse 输入频率响应和 3 dB 带宽
    03_InputPowerScale   输入功率响应
    04_Isolation         通道隔离度
    05_INL_DNL           积分非线性和微分非线性

AD9245 示例：

    AD9245\01_SFDR\X3G\raw
    AD9245\01_SFDR\X3G\results

raw 只保存原始采集文件；results 只保存 MATLAB 处理结果。
频率、功率和运行次数写入文件名，并同步登记到 00_Metadata\measurement_manifest.csv。

普通文件名建议：

    <Metric>_<Device>_<Channel>_<Frequency>_<Power>_<Run>.csv

例如：

    SFDR_AD9245_X3G_10MHz_6dBm_run01.csv
    InputPowerScale_AD9245_X3G_1MHz_-10dBm_run01.csv

隔离度文件名建议：

    Isolation_AD9245_driveX3G_captureX1G_1MHz_7dBm_run01.csv

说明：`measurement_manifest.csv` 和 `result_manifest.csv` 是当前目录结构的
清单；保留的 `file_manifest.csv` 属于旧目录整理记录，不作为当前结构的主清单。

当前 AD9245 迁移保留原始文件名，旧的通道优先结构已归档到：

    99_Archive\AD9245_ChannelFirst_20260802

脚本调用示例：

    adc_sfdr_analysis(fullfile(dataRoot, 'AD9245', '01_SFDR', 'X3G', 'raw'));
    adc_bandwidth_analysis(fullfile(dataRoot, 'AD9245', '02_FrequencyResponse', 'X3G', 'raw'));
    adc_power_scale_analysis(fullfile(dataRoot, 'AD9245', '03_InputPowerScale', 'X3G', 'raw'));
    adc_isolation_analysis(fullfile(dataRoot, 'AD9245', '04_Isolation', 'X3G', 'raw'));
    adc_inl_dnl_analysis(fullfile(dataRoot, 'AD9245', '05_INL_DNL', 'X3G', 'raw'));
"@
Set-Content -LiteralPath (Join-Path $metadataRoot 'README_Data_Organization.md') -Value $readme -Encoding utf8
Set-Content -LiteralPath (Join-Path $reportRoot 'README_ReportResults.md') -Value "Cross-device report tables and figures only. Raw captures remain under device/metric/channel/raw." -Encoding utf8

# Archive the old channel-first structure only after all copies and hashes pass.
foreach ($channel in $channels) {
    $oldChannel = Join-Path $deviceRoot $channel
    $targetChannel = Join-Path $archiveRoot $channel
    if (Test-Path -LiteralPath $oldChannel) {
        if (Test-Path -LiteralPath $targetChannel) { throw "Archive target already exists: $targetChannel" }
        Move-Item -LiteralPath $oldChannel -Destination $targetChannel
    }
}
$oldIndex = Join-Path $deviceRoot 'AD9245_results_index.csv'
if (Test-Path -LiteralPath $oldIndex) {
    Move-Item -LiteralPath $oldIndex -Destination (Join-Path $archiveRoot 'AD9245_results_index.csv')
}

$log = @(
    "Migration completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Device: $device",
    "Raw files copied and SHA-256 verified: $($manifestRows.Count)",
    "Result folders indexed: $($resultRows.Count)",
    "Legacy structure: 99_Archive\AD9245_ChannelFirst_20260802"
)
Set-Content -LiteralPath (Join-Path $reportRoot 'migration_20260802.log') -Value $log -Encoding utf8
Write-Output ($log -join [Environment]::NewLine)
