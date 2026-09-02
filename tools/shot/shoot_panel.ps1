# Drives `shoot_panel.gd` once per plate candidate: copies the candidate over `assets/ui/panel.png`,
# re-imports it headless (a `--script` run does not re-import on its own — `tests/run_nets.ps1` carries
# the measurement), then opens the game in a window and lets the shooter save its five shots.
#
# The candidates live in `tools/shot/out/panel/src/panel_<name>.png` (`out/` is .gdignore'd, so they are
# not imported as game assets). **When every plate is done, `assets/ui/panel.png` is put back to
# `-Restore` (default `crimson`) and re-imported**, so the working tree ends wearing a known plate.
#
#   powershell -ExecutionPolicy Bypass -File tools/shot/shoot_panel.ps1
#   powershell -ExecutionPolicy Bypass -File tools/shot/shoot_panel.ps1 -Plates wood
#
# This file must be saved as UTF-8 with BOM — PowerShell 5.1 reads BOM-less UTF-8 as ANSI.

param(
    [string[]]$Plates = @("crimson", "wood", "slate"),
    [string]$Restore = "crimson"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$godot = Get-ChildItem -Path $root -Filter "Godot_v*.exe" | Select-Object -First 1
if ($null -eq $godot) {
    Write-Host "[shot] no engine at $root — the Godot 4.7.x exe lives at the repo root" -ForegroundColor Red
    exit 1
}

$srcDir = Join-Path $root "tools\shot\out\panel\src"
$outDir = Join-Path $root "tools\shot\out\panel"
$target = Join-Path $root "assets\ui\panel.png"
$current = Join-Path $outDir "current.txt"
New-Item -ItemType Directory -Force $outDir | Out-Null

function Wear-Plate([string]$name) {
    $src = Join-Path $srcDir "panel_$name.png"
    if (-not (Test-Path $src)) { throw "[shot] no candidate at $src" }
    Copy-Item $src $target -Force
    # ⚠ Measured 2026-09-02: `Copy-Item` keeps the candidate's own modified time, and the import scan
    # keys on that time — three plates went in and the first run photographed the same plate three
    # times with `--import` exiting 0 each time. A fresh timestamp is what makes the scan look again.
    (Get-Item $target).LastWriteTime = Get-Date
    Set-Content -Path $current -Value $name -Encoding ascii
    $imp = Start-Process -FilePath $godot.FullName -NoNewWindow -Wait -PassThru `
        -ArgumentList @("--headless", "--path", $root, "--import")
    Write-Host "[shot] wearing $name (import exit $($imp.ExitCode))"
}

$tmp = [System.IO.Path]::GetTempPath()
foreach ($p in $Plates) {
    Wear-Plate $p
    # A windowed engine's stdout goes nowhere on its own; it is taken to a file and echoed, because a
    # shooter that pressed nothing prints `hand=0` and that line is the only sign the shot is empty.
    $so = Join-Path $tmp "tockbon_shoot_panel_${p}_$PID.out.txt"
    $se = Join-Path $tmp "tockbon_shoot_panel_${p}_$PID.err.txt"
    $run = Start-Process -FilePath $godot.FullName -Wait -PassThru `
        -RedirectStandardOutput $so -RedirectStandardError $se `
        -ArgumentList @("--path", $root, "-s", "tools/shot/shoot_panel.gd", "--", "--plate=$p")
    Get-Content $so | Where-Object { $_ -match '^\[shot\]' } | ForEach-Object { Write-Host $_ }
    $errs = @(Get-Content $se | Where-Object { $_ -match 'ERROR' })
    if ($errs.Count -gt 0) { Write-Host "[shot] stderr for ${p}:" -ForegroundColor Red; $errs | ForEach-Object { Write-Host "  | $_" } }
    Write-Host "[shot] shooter exit $($run.ExitCode) for $p"
}

Wear-Plate $Restore
Get-ChildItem -Path $outDir -Filter "panel_*.png" | Sort-Object Name | ForEach-Object {
    Write-Host ("[shot] {0}  {1} bytes" -f $_.Name, $_.Length)
}
