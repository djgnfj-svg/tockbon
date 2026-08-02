# 그물 래퍼. 이 파일이 침묵사 감지기다. 러너 단독 실행은 반쪽이다.
#
# 이 리포의 실패는 거의 전부 "에러 없이 조용히 틀림"이고,
# 그중 "엔진이 짖긴 하는데 아무도 안 듣는" 종류가 가장 많다.
# push_error는 게임을 안 멈춘다. 테스트가 초록인 채로 세상만 틀어진다.
# 그래서 stderr에 뭐라도 뜨면 실패다. 예외는 그물이 expect_error()로 선언한 것뿐.
#
# 사용:
#   powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
#   powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1 tables
#
# 이 파일은 반드시 UTF-8 BOM으로 저장해야 한다.
# PowerShell 5.1은 BOM 없는 UTF-8을 ANSI로 읽어 한글이 깨지고 파서가 죽는다.

param([string]$Filter = "")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$godot = Get-ChildItem -Path $root -Filter "Godot_v*.exe" | Select-Object -First 1
if ($null -eq $godot) {
    Write-Host "[그물] 엔진을 못 찾았다. Godot 4.7.x 바이너리를 리포 루트에 두어라." -ForegroundColor Red
    Write-Host "       (.gitignore 대상이라 클론 직후엔 없는 게 정상이다)"
    exit 1
}

# 네이티브 exe의 stderr를 파이프로 받으면 PowerShell 5.1이 각 줄을 ErrorRecord로 감싸고
# 종료 코드 0인데도 실패로 읽는다. 파일로 받아서 텍스트로 읽는다.
$tmp = [System.IO.Path]::GetTempPath()
$outFile = Join-Path $tmp "tockbon_nets_out.txt"
$errFile = Join-Path $tmp "tockbon_nets_err.txt"

$godotArgs = @("--headless", "--path", $root, "--script", "res://tests/run_nets.gd")
if ($Filter -ne "") { $godotArgs += @("--", $Filter) }

$proc = Start-Process -FilePath $godot.FullName -ArgumentList $godotArgs -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $outFile -RedirectStandardError $errFile

$stdout = if (Test-Path $outFile) { Get-Content $outFile -Raw -Encoding utf8 } else { "" }
$stderr = if (Test-Path $errFile) { Get-Content $errFile -Raw -Encoding utf8 } else { "" }
if ($null -eq $stdout) { $stdout = "" }
if ($null -eq $stderr) { $stderr = "" }

Write-Host $stdout

# 그물이 선언한 정당한 에러만 사면한다.
$expected = @()
foreach ($line in ($stdout -split "`r?`n")) {
    if ($line -match '^\[EXPECT\]\s+(.+?)\s*$') { $expected += $Matches[1] }
}

# 줄이 아니라 블록으로 판정한다. Godot 에러 하나는 헤더 1줄 + 백트레이스 8줄쯤이다.
# 줄 단위로 사면하면 선언이 헤더만 지우고 나머지가 남아 여전히 빨갛다.
$noise = @()
$blockLines = @()
$blockExpected = $false
$inBlock = $false

foreach ($line in ($stderr -split "`r?`n")) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "") { continue }
    if ($trimmed -match '^x\s') { continue }        # 러너가 이미 집계한 단언 실패
    if ($trimmed -match '^\[그물\]') { continue }

    $isCont = $inBlock -and ($trimmed -match '^(at:|GDScript backtrace|\[\d+\]\s)')
    if ($isCont) {
        if (-not $blockExpected) { $blockLines += $trimmed }
        continue
    }

    if ($blockLines.Count -gt 0) { $noise += $blockLines }
    $blockLines = @()
    $inBlock = $trimmed -match '^(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR|WARNING|USER WARNING):'
    $blockExpected = $false
    foreach ($e in $expected) {
        if ($trimmed.Contains($e)) { $blockExpected = $true; break }
    }
    if (-not $blockExpected) { $blockLines = @($trimmed) }
}
if ($blockLines.Count -gt 0) { $noise += $blockLines }

$exitCode = $proc.ExitCode

if ($noise.Count -gt 0) {
    Write-Host ""
    Write-Host "[침묵사] stderr에 선언되지 않은 출력이 $($noise.Count)줄 있다." -ForegroundColor Red
    Write-Host "         이 리포에서는 이게 곧 실패다. 그물은 초록인데 엔진이 짖었을 수 있다." -ForegroundColor Red
    Write-Host '         정당한 짖음이면 그물에서 t.expect_error("...")로 선언하라.' -ForegroundColor Yellow
    foreach ($n in $noise) { Write-Host "  | $n" -ForegroundColor Red }
    $exitCode = 1
}

if ($exitCode -eq 0) {
    Write-Host "[래퍼] 통과. stderr 깨끗함." -ForegroundColor Green
} else {
    Write-Host "[래퍼] 실패 (종료 코드 $exitCode)" -ForegroundColor Red
}
exit $exitCode
