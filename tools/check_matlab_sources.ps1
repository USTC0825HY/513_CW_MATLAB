$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$extensions = @('.m','.mlx','.py','.ipynb','.ps1','.tcl','.yaml','.yml','.json')
$nested = Get-ChildItem -LiteralPath $root -Directory -Force -Recurse -Filter '.git' | Where-Object { $_.FullName -ne (Join-Path $root '.git') }
if ($nested) { $nested | ForEach-Object { Write-Error "Nested Git directory: $($_.FullName)" } }
$candidates = Get-ChildItem -LiteralPath $root -File -Force -Recurse | Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }
$untracked = @()
foreach ($file in $candidates) {
  $rel = $file.FullName.Substring($root.Length + 1).Replace('\','/')
  git -c safe.directory='*' -C $root check-ignore --quiet -- $rel
  if ($LASTEXITCODE -eq 0) { continue }
  $tracked = git -c safe.directory='*' -C $root ls-files --error-unmatch -- $rel 2>$null
  if (-not $tracked) { $untracked += $rel }
}
if ($untracked.Count) { $untracked | ForEach-Object { Write-Output "UNTRACKED_SOURCE: $_" }; exit 2 }
Write-Output "OK: $($candidates.Count) analysis-like files are tracked and no nested Git repositories were found."
