param(
    [string]$WorkspaceRoot = 'F:\01_Laser',
    [string]$WorkDirectory = 'F:\01_Laser\.code_reorg_work'
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
if ($resolvedRoot -ne 'F:\01_Laser') {
    throw "Unexpected workspace root: $resolvedRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $WorkDirectory 'before_code_manifest_sha256.csv'))) {
    throw 'A completed SHA-256 baseline manifest is required.'
}
if (Test-Path -LiteralPath (Join-Path $resolvedRoot 'code')) {
    throw 'Target directory already exists. Refusing to merge or overwrite.'
}

$moveLog = [System.Collections.Generic.List[object]]::new()

function Assert-InWorkspace {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not ($full -eq $script:resolvedRoot -or $full.StartsWith($script:resolvedRoot + '\', [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Path escapes the workspace: $full"
    }
    return $full
}

function Add-Directory {
    param([string]$RelativePath)
    $path = Assert-InWorkspace (Join-Path $script:resolvedRoot $RelativePath)
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Move-CodeItem {
    param(
        [string]$SourceRelative,
        [string]$DestinationRelative
    )
    $source = Assert-InWorkspace (Join-Path $script:resolvedRoot $SourceRelative)
    $destination = Assert-InWorkspace (Join-Path $script:resolvedRoot $DestinationRelative)
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Required source does not exist: $source"
    }
    if (Test-Path -LiteralPath $destination) {
        throw "Destination exists; refusing to overwrite: $destination"
    }
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Move-Item -LiteralPath $source -Destination $destination
    $script:moveLog.Add([pscustomobject]@{
        SourceRelative = $SourceRelative
        DestinationRelative = $DestinationRelative
        MoveTime = (Get-Date).ToString('o')
    })
}

$targetDirectories = @(
    'code\catalog',
    'code\fpga\projects\cwjg',
    'code\fpga\projects',
    'code\fpga\experiments',
    'code\fpga\legacy',
    'code\fpga\releases\20260714_top0726',
    'code\fpga\archives',
    'code\fpga\generated',
    'code\matlab\project_analysis',
    'code\tools\dbm_converter'
)
foreach ($directory in $targetDirectories) {
    Add-Directory $directory
}

# Main MATLAB repository.
Move-CodeItem 'MATLAB' 'code\matlab\laser_analysis'

# Legacy and active FPGA project collections from the Shanghai delivery workspace.
Move-CodeItem '202607_上海_电2\logic\CWJG_VER3.2_20' 'code\fpga\projects\cwjg\cwjg_v3_2_20'
Move-CodeItem '202607_上海_电2\logic\CWJG_VER3.3_11' 'code\fpga\projects\cwjg\cwjg_v3_3_11'
Move-CodeItem '202607_上海_电2\logic\PDH_DLOCK' 'code\fpga\projects\pdh_dlock'
Move-CodeItem '202607_上海_电2\logic\jianding_szsd_old' 'code\fpga\legacy\jianding_szsd_old'
Move-CodeItem '202607_上海_电2\logic\dian2_test' 'code\fpga\experiments\dian2_test'
Move-CodeItem '202607_上海_电2\logic\513_test' 'code\fpga\experiments\test_513'
Move-CodeItem '202607_上海_电2\logic\test3_bit' 'code\fpga\experiments\test3_bit'
Move-CodeItem '202607_上海_电2\logic\dBm_Convertor' 'code\tools\dbm_converter\legacy_logic_copy'
Move-CodeItem '202607_上海_电2\logic\CWJG_VER3.2_20.zip' 'code\fpga\archives\CWJG_VER3.2_20.zip'
Move-CodeItem '202607_上海_电2\logic\CWJG_VER3.3_11.zip' 'code\fpga\archives\CWJG_VER3.3_11.zip'
Move-CodeItem '202607_上海_电2\logic\PDH_DLOCK.zip' 'code\fpga\archives\PDH_DLOCK.zip'
Move-CodeItem '202607_上海_电2\logic\dBm_Convertor.zip' 'code\fpga\archives\dBm_Convertor.zip'
Move-CodeItem '202607_上海_电2\logic\top0726.bit' 'code\fpga\releases\20260714_top0726\top0726.bit'
Move-CodeItem '202607_上海_电2\logic\top0726.ltx' 'code\fpga\releases\20260714_top0726\top0726.ltx'

# Project-specific working sources are centralized; firmware releases remain with test evidence.
Move-CodeItem '20260727_513test\02_GS与延迟驱动测试\03_Analysis_分析脚本与结果' 'code\matlab\project_analysis\gs_delay_20260730'
Move-CodeItem '20260727_513test\02_GS与延迟驱动测试\04_FPGA_工程与固件\01_Source_工程主副本' 'code\fpga\projects\gs_delay_20260730'
Move-CodeItem '20260727_513test\02_GS与延迟驱动测试\04_FPGA_工程与固件\99_Generated_可重建生成物' 'code\fpga\generated\gs_delay_20260730'
Move-CodeItem '20260727_513test\02_GS与延迟驱动测试\99_Review_待确认\疑似重复FPGA工程_LOGIC_jianding_szsd_ver729' 'code\fpga\legacy\gs_delay_duplicate_review'
Move-CodeItem '20260727_513test\03_CW测试\04_FPGA_工程与固件\01_Source_工程主副本' 'code\fpga\projects\cw_test_202608'
Move-CodeItem '20260727_513test\03_CW测试\04_FPGA_工程与固件\99_Generated_可重建生成物' 'code\fpga\generated\cw_test_202608'

# Root-level Vivado scratch data is generated content.
Move-CodeItem '.Xil' 'code\fpga\generated\root_xil'

$legacyLogic = Join-Path $resolvedRoot '202607_上海_电2\logic'
if (Test-Path -LiteralPath $legacyLogic) {
    $remaining = @(Get-ChildItem -LiteralPath $legacyLogic -Force)
    if ($remaining.Count -ne 0) {
        throw "Legacy logic directory is not empty after planned moves: $legacyLogic"
    }
    Remove-Item -LiteralPath $legacyLogic
}

$moveLog | Export-Csv -LiteralPath (Join-Path $WorkDirectory 'code_move_map.csv') -NoTypeInformation -Encoding utf8
