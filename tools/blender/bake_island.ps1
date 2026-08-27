# Bakes the island in Blender and makes the GAME actually see it.
#
# ⚠⚠ **THIS EXISTS BECAUSE GODOT SERVED A DAY-OLD ISLAND WITHOUT SAYING SO** (2026-08-27). Blender was
# re-baking `island.glb` correctly, but Godot reads its own converted copy under `.godot/imported/`, and
# a `--script` run does NOT re-convert a changed source. **Three bakes in a row came back looking
# identical and the third was investigated as a modelling bug.** The source file was minutes old and the
# copy the screen was drawing was from the previous evening.
#
# ⚠ **The trap is silent in both directions**: no warning, no error, and the picture is a real picture
# of a real island — just not the one on disk. **Never judge a bake without going through this script.**
#
#   .\tools\blender\bake_island.ps1
#
# Blender must already be open with the MCP add-on listening; `send.py` talks to it.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$godot = Join-Path $root "Godot_v4.7.1-stable_win64.exe"
if (-not (Test-Path $godot)) {
    Write-Error "bake_island: 저장소 루트의 고도를 못 찾았다: $godot"
}

Write-Host "[1/3] 블렌더에서 굽는다"
python tools\blender\send.py tools\blender\island_build.py
if ($LASTEXITCODE -ne 0) { Write-Error "bake_island: 굽기가 실패했다. 블렌더가 켜져 있나?" }

# ⚠ **The `.md5` is what Godot compares against, so removing the pair is what forces the re-convert.**
# Deleting only the `.scn` leaves the md5 saying the copy is current and Godot rebuilds nothing.
Write-Host "[2/3] 고도가 캐시한 옛 섬을 지운다"
Remove-Item (Join-Path $root ".godot\imported\island.glb-*") -Force -ErrorAction SilentlyContinue

Write-Host "[3/3] 고도가 새로 읽게 한다"
# ⚠ **Same trap as the bake step**: Godot writes warnings to stderr (it has a UID clash in the asset
# folder that is nothing to do with the island), and `Stop` would treat that as a failure. **The check
# below is what decides whether this worked**, not the absence of noise.
$ErrorActionPreference = "Continue"
& $godot --headless --path . --import | Out-Null
$ErrorActionPreference = "Stop"

$scn = Get-ChildItem (Join-Path $root ".godot\imported\island.glb-*.scn") -ErrorAction SilentlyContinue
$src = Get-Item (Join-Path $root "assets\terrain\island.glb")
if (-not $scn) {
    Write-Error "bake_island: 고도가 섬을 다시 안 읽었다. 캐시가 비어 있다"
}
# ⚠⚠ **The check is the point of the script.** A bake that quietly did not reach the game is the exact
# failure this file was written for, so it is measured here rather than trusted.
if ($scn.LastWriteTime -lt $src.LastWriteTime) {
    Write-Error ("bake_island: 고도가 읽은 사본이 원본보다 낡았다 — 사본 {0}, 원본 {1}" -f $scn.LastWriteTime, $src.LastWriteTime)
}
Write-Host ("완료 — 원본 {0}, 고도 사본 {1}" -f $src.LastWriteTime.ToString("HH:mm:ss"), $scn.LastWriteTime.ToString("HH:mm:ss"))
