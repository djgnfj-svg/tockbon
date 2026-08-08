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
#   powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1 -Serial     (한 프로세스로)
#
# 이 파일은 반드시 UTF-8 BOM으로 저장해야 한다.
# PowerShell 5.1은 BOM 없는 UTF-8을 ANSI로 읽어 한글이 깨지고 파서가 죽는다.
#
# 🔴🔴 **그물마다 별도 프로세스로 병렬 실행한다** (2026-08-07). 이유가 둘이고 둘 다 크다:
#
#  1. **속도.** 한 프로세스로 전부 돌면 332초다(실측). 병렬이면 가장 느린 그물 하나의 시간이다.
#  2. 🔴 **사면이 자기 그물 안에 갇힌다.** CLAUDE.md가 「사면의 수명이 무제한이다 — 폭보다 이게 더 넓다」를
#     가짜 그물의 한 형태로 꼽았다: 한 프로세스로 돌면 stdout의 [EXPECT]를 **먼저 다 모은 뒤**
#     stderr를 그 목록 **전부**와 맞대므로 **그물별·시점별 범위가 하나도 없다.**
#     실측으로 **첫 그물에 위조 짖음을 넣고 선언은 세 번째 그물이 했는데 초록**이었다.
#     ⇒ 프로세스를 가르면 그 구멍이 **구조적으로** 막힌다. 3번 그물의 선언이 1번 그물을 못 덮는다.
#
# ⚠ `-Serial`은 옛 동작(한 프로세스)이다. 병렬 결과가 의심스러울 때 대조용으로만 써라.

param([string]$Filter = "", [switch]$Serial)

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
#
# 🔴🔴 파일 이름에 PID와 그물 이름을 붙인다. 고정 이름이면 **두 사람이 동시에 돌릴 때 서로의 출력을 덮어쓴다.**
#  이 리포는 verify-run·verify-read가 병렬로 그물을 돌리는 구조라 반드시 난다 — 실제로 났다.
#  ⚠ 증상이 둘인데 **뒤쪽이 훨씬 위험하다**:
#   · 없는 실패가 뜬다 (남의 실패 줄을 내 출력으로 읽는다)
#   · 🔴 **진짜 실패가 남의 초록에 덮여 사라진다** — 이쪽은 아무도 눈치 못 챈다
#   · `[EXPECT]` 목록이 섞여 **사면 범위가 조용히 넓어진다**
#  ⇒ 「내 변경 때문인가」로 시간을 버리는 대표 경로였다. 두 검증자가 독립적으로 겪고 같은 원인을 짚었다.
$tmp = [System.IO.Path]::GetTempPath()

# stderr 판정. 🔴 **한 그물의 출력만** 받는다 — 그게 사면을 좁히는 장치다.
# 줄이 아니라 블록으로 판정한다. Godot 에러 하나는 헤더 1줄 + 백트레이스 8줄쯤이다.
# 줄 단위로 사면하면 선언이 헤더만 지우고 나머지가 남아 여전히 빨갛다.
function Get-Noise([string]$stdout, [string]$stderr) {
    $expected = @()
    foreach ($line in ($stdout -split "`r?`n")) {
        if ($line -match '^\[EXPECT\]\s+(.+?)\s*$') { $expected += $Matches[1] }
    }

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
    return ,$noise
}

# ── 그물 목록. 🔴 폴더를 스캔한다 — 손으로 관리하는 목록이 아니다(CLAUDE.md).
$netFiles = Get-ChildItem -Path (Join-Path $root "tests\nets") -Filter "net_*.gd" | Sort-Object Name
$nets = @()
foreach ($f in $netFiles) {
    $nm = $f.BaseName -replace '^net_', ''
    if ($Filter -eq "" -or $nm.Contains($Filter)) { $nets += $nm }
}

if ($nets.Count -eq 0) {
    Write-Host "[그물] 필터 '$Filter' 에 맞는 그물이 없다." -ForegroundColor Red
    exit 1
}

# 🔴 **0개가 아니다를 먼저 확인한다.** CLAUDE.md: 폴더 스캔의 첫 줄이 늘 이것인 이유는
#  「씬을 못 세우면 검사가 실패가 아니라 없어진다」를 여기서도 막기 위해서다.
if ($netFiles.Count -lt 5) {
    Write-Host "[그물] tests/nets/ 에 그물이 $($netFiles.Count)개뿐이다. 스캔이 깨졌다." -ForegroundColor Red
    exit 1
}

# 🔴🔴 **도는 동안 누가 소스를 고치면 가짜 실패가 난다** (2026-08-07, 실측으로 두 번 났다).
#  헤드리스 프로세스가 **절반 쓰인 파일**을 읽으면 「점프 높이 0」·「착지 y 안 맞음」류로 우수수 빨개진다.
#  ⚠ **그게 이 리포에서 시간을 제일 많이 버리는 경로다** — 가짜 실패를 진짜로 알고 원인을 쫓는다.
#   실제로 두 번 났다: builder가 `character.gd` 를 쓰는 중에 그물이 돌아 13개가 빨개졌고,
#   또 한 번은 builder의 **뒤집기 창**(값을 일부러 깨 둔 짧은 구간)을 그물이 밟아 38개가 빨개졌다.
#  ⇒ **막을 수는 없다**(남의 편집을 못 막는다). **대신 「의심스럽다」를 러너가 말하게 한다.**
#   시작과 끝의 최신 수정 시각을 대 보고, 도는 동안 바뀌었으면 결과를 믿지 말라고 찍는다.
function Get-SrcStamp([string]$r) {
    $newest = [DateTime]::MinValue
    foreach ($d in @("src", "tests")) {
        $p = Join-Path $r $d
        if (-not (Test-Path $p)) { continue }
        foreach ($f in (Get-ChildItem -Path $p -Recurse -File -Include "*.gd", "*.tscn", "*.tres")) {
            if ($f.LastWriteTimeUtc -gt $newest) { $newest = $f.LastWriteTimeUtc }
        }
    }
    return $newest
}
$stampBefore = Get-SrcStamp $root

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# ── Serial: 옛 동작. 한 프로세스로 전부.
if ($Serial) {
    $outFile = Join-Path $tmp "tockbon_nets_out_$PID.txt"
    $errFile = Join-Path $tmp "tockbon_nets_err_$PID.txt"
    $godotArgs = @("--headless", "--path", $root, "--script", "res://tests/run_nets.gd")
    if ($Filter -ne "") { $godotArgs += @("--", $Filter) }
    $proc = Start-Process -FilePath $godot.FullName -ArgumentList $godotArgs -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $stdout = if (Test-Path $outFile) { Get-Content $outFile -Raw -Encoding utf8 } else { "" }
    $stderr = if (Test-Path $errFile) { Get-Content $errFile -Raw -Encoding utf8 } else { "" }
    if ($null -eq $stdout) { $stdout = "" }
    if ($null -eq $stderr) { $stderr = "" }
    Write-Host $stdout
    $noise = Get-Noise $stdout $stderr
    $exitCode = $proc.ExitCode
    if ($noise.Count -gt 0) {
        Write-Host ""
        Write-Host "[침묵사] stderr에 선언되지 않은 출력이 $($noise.Count)줄 있다." -ForegroundColor Red
        foreach ($n in $noise) { Write-Host "  | $n" -ForegroundColor Red }
        $exitCode = 1
    }
    $sw.Stop()
    if ($exitCode -eq 0) {
        Write-Host ("[래퍼] 통과. stderr 깨끗함. ({0:N1}s, 직렬)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    } else {
        Write-Host "[래퍼] 실패 (종료 코드 $exitCode)" -ForegroundColor Red
    }
    exit $exitCode
}

# ── 병렬. 동시에 뜨는 프로세스를 제한한다.
#  ⚠ 격자 하나가 412만 칸 × 배열 넷이라 프로세스마다 메모리를 먹는다. 코어 수로 묶는다.
$maxParallel = [Math]::Max(2, [Math]::Min(8, [Environment]::ProcessorCount - 2))
Write-Host "[그물] $($nets.Count)개를 병렬로 돈다 (동시 ${maxParallel}개)"

$jobs = @()
$queue = New-Object System.Collections.Queue
foreach ($n in $nets) { $queue.Enqueue($n) | Out-Null }
$running = @()

while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($running.Count -lt $maxParallel -and $queue.Count -gt 0) {
        $n = $queue.Dequeue()
        $o = Join-Path $tmp "tockbon_net_${n}_out_$PID.txt"
        $e = Join-Path $tmp "tockbon_net_${n}_err_$PID.txt"
        # 🔴🔴 **`^`로 정확히 이 그물 하나에만 묶는다** (2026-08-08, harness-manager 실측).
        #  부분 일치(`$n`을 그냥 넘기면)로는 이름이 서로를 포함하는 그물(`net_water` ⊂
        #  `net_water_rain`, `net_sprite` ⊂ `net_monster_sprite`)에서 한 프로세스가 여러 그물을
        #  몰래 같이 돌린다 — 격리가 깨지고 병렬화가 시간을 못 줄인다(`run_nets.gd` 쪽 주석 참조).
        $a = @("--headless", "--path", $root, "--script", "res://tests/run_nets.gd", "--", "^$n")
        $p = Start-Process -FilePath $godot.FullName -ArgumentList $a -NoNewWindow -PassThru `
            -RedirectStandardOutput $o -RedirectStandardError $e
        # 🔴🔴 **핸들을 한 번 읽어 둬야 종료 뒤에 `ExitCode` 가 남는다.**
        #  안 읽으면 .NET이 프로세스 핸들을 놓고, `HasExited` 는 참인데 `ExitCode` 가 비어 있다
        #  ⇒ **모든 그물이 실패로 읽힌다.** 실측으로 그 사고가 났다 — 통과 수는 정상인데 13개 전부 [실패]였다.
        $null = $p.Handle
        $running += [PSCustomObject]@{ Net = $n; Proc = $p; Out = $o; Err = $e; Started = $sw.Elapsed.TotalSeconds }
    }
    Start-Sleep -Milliseconds 120
    $still = @()
    foreach ($r in $running) {
        if ($r.Proc.HasExited) {
            $r | Add-Member -NotePropertyName Sec -NotePropertyValue ($sw.Elapsed.TotalSeconds - $r.Started) -Force
            $jobs += $r
        } else { $still += $r }
    }
    $running = $still
}

$sw.Stop()

# ── 집계
$totalPass = 0
$totalFail = 0
$exitCode = 0
$lines = @()

foreach ($j in ($jobs | Sort-Object Net)) {
    $stdout = if (Test-Path $j.Out) { Get-Content $j.Out -Raw -Encoding utf8 } else { "" }
    $stderr = if (Test-Path $j.Err) { Get-Content $j.Err -Raw -Encoding utf8 } else { "" }
    if ($null -eq $stdout) { $stdout = "" }
    if ($null -eq $stderr) { $stderr = "" }

    $pass = 0
    if ($stdout -match '통과\s+(\d+)\s*개') { $pass = [int]$Matches[1] }
    $fail = 0
    foreach ($l in ($stdout -split "`r?`n")) { if ($l -match '^x\s') { $fail++ } }
    foreach ($l in ($stderr -split "`r?`n")) { if ($l.Trim() -match '^x\s') { $fail++ } }

    $noise = Get-Noise $stdout $stderr
    $bad = ($j.Proc.ExitCode -ne 0) -or ($noise.Count -gt 0)

    $totalPass += $pass
    $totalFail += $fail

    # 🔴 실패 **줄만** 뽑는다. 전문을 뿌리면 출력이 폭발해 정작 실패가 스크롤 위로 사라진다.
    #  ⚠ 실측: 13개 그물의 전문이 6천 자를 넘겨 잘렸고, 그 안에서 실패 다섯 줄을 못 찾을 뻔했다.
    #  ⚠ 러너가 같은 실패를 stdout·stderr 양쪽에 쓴다 ⇒ **중복을 지운다.** 안 지우면 두 배로 보인다.
    $failLines = @()
    foreach ($l in (($stdout + "`n" + $stderr) -split "`r?`n")) {
        if ($l.Trim() -match '^x\s') { $failLines += $l.Trim() }
    }
    $failLines = @($failLines | Select-Object -Unique)

    if ($bad) {
        $exitCode = 1
        $lines += [PSCustomObject]@{ Net = $j.Net; Pass = $pass; Bad = $true; Fails = $failLines; Noise = $noise; Code = $j.Proc.ExitCode; Sec = $j.Sec; Out = $j.Out }
    } else {
        $lines += [PSCustomObject]@{ Net = $j.Net; Pass = $pass; Bad = $false; Fails = @(); Noise = @(); Code = 0; Sec = $j.Sec; Out = $j.Out }
    }
}

Write-Host ""
foreach ($l in ($lines | Sort-Object Sec -Descending)) {
    if ($l.Bad) {
        Write-Host ("  {0,-14} 통과 {1,5}   {2,6:N1}s   [실패]" -f $l.Net, $l.Pass, $l.Sec) -ForegroundColor Red
    } else {
        Write-Host ("  {0,-14} 통과 {1,5}   {2,6:N1}s" -f $l.Net, $l.Pass, $l.Sec) -ForegroundColor DarkGray
    }
}

# 🔴 실패한 그물만, 그것도 실패 줄만. 전문이 필요하면 출력 파일 경로를 찍어 준다.
foreach ($l in $lines) {
    if (-not $l.Bad) { continue }
    Write-Host ""
    Write-Host "───── net_$($l.Net) (종료 코드 $($l.Code)) ─────" -ForegroundColor Red
    foreach ($f in $l.Fails) { Write-Host "  $f" -ForegroundColor Red }
    Write-Host "  전문: $($l.Out)" -ForegroundColor DarkGray
    if ($l.Noise.Count -gt 0) {
        Write-Host "[침묵사] stderr에 선언되지 않은 출력이 $($l.Noise.Count)줄 있다." -ForegroundColor Red
        Write-Host "         이 리포에서는 이게 곧 실패다. 그물은 초록인데 엔진이 짖었을 수 있다." -ForegroundColor Red
        Write-Host '         정당한 짖음이면 그물에서 t.expect_error("...")로 선언하라.' -ForegroundColor Yellow
        foreach ($n in $l.Noise) { Write-Host "  | $n" -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host ("[그물] 통과 {0}개 · 실패 {1}개 · {2}개 그물 · {3:N1}s" -f $totalPass, $totalFail, $nets.Count, $sw.Elapsed.TotalSeconds)

# 🔴 도는 동안 소스가 바뀌었으면 **결과를 믿지 마라.** 위 함수 주석에 왜인지 적어 뒀다.
$stampAfter = Get-SrcStamp $root
if ($stampAfter -ne $stampBefore) {
    Write-Host ""
    Write-Host "[경합] 그물이 도는 동안 src/ 또는 tests/ 가 바뀌었다." -ForegroundColor Yellow
    Write-Host "       (마지막 수정 $stampBefore UTC -> $stampAfter UTC)" -ForegroundColor Yellow
    Write-Host "       🔴 이 결과를 믿지 마라. 절반 쓰인 파일을 읽었을 수 있다." -ForegroundColor Yellow
    Write-Host "       실패가 났다면 편집이 멈춘 뒤 다시 돌리고 나서 판단해라." -ForegroundColor Yellow
    Write-Host "       ⚠ 초록이어도 마찬가지다 - 옛 파일을 읽고 통과했을 수 있다." -ForegroundColor Yellow
}

if ($exitCode -eq 0) {
    Write-Host "[래퍼] 통과. stderr 깨끗함." -ForegroundColor Green
} else {
    Write-Host "[래퍼] 실패 (종료 코드 $exitCode)" -ForegroundColor Red
}
exit $exitCode
