# The net wrapper. This file is the silent-death detector. Running the runner alone is only half of it.
#
# Almost every failure in this repo is "wrong with no error", and among those the most common kind is
# "the engine does bark but nobody listens".
# push_error does not stop the game. The tests stay green while only the world goes wrong.
# So anything appearing on stderr is a failure. The only exception is what a net declared with expect_error().
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1
#   powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1 tables
#   powershell -ExecutionPolicy Bypass -File tests/run_nets.ps1 -Serial     (in one process)
#
# This file must be saved as UTF-8 with BOM.
# PowerShell 5.1 reads BOM-less UTF-8 as ANSI, mangles the Korean and kills the parser.
#
# **Each net runs in its own process in parallel.** There are two reasons and both are big:
#
#  1. **Speed.** Running everything in one process is 332 seconds (measured). In parallel it is the time of the
#     single slowest net.
#  2. **The amnesty is confined to its own net.** CLAUDE.md lists "an amnesty's lifetime is unlimited — this is
#     wider than its breadth" as a form of fake net: in one process the [EXPECT] entries on stdout are **all
#     collected first** and then stderr is compared against **the entire** list, so **there is no per-net or
#     per-moment scope at all.**
#     Measured: **a forged bark was put in the first net while the third net made the declaration, and it was green.**
#     => Splitting the processes closes that hole **structurally.** Net 3's declaration cannot cover net 1.
#
# `-Serial` is the old behavior (one process). Use it only as a control when the parallel result is suspect.

param([string]$Filter = "", [switch]$Serial)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$godot = Get-ChildItem -Path $root -Filter "Godot_v*.exe" | Select-Object -First 1
if ($null -eq $godot) {
    Write-Host "[그물] 엔진을 못 찾았다. Godot 4.7.x 바이너리를 리포 루트에 두어라." -ForegroundColor Red
    Write-Host "       (.gitignore 대상이라 클론 직후엔 없는 게 정상이다)"
    exit 1
}

# Piping a native exe's stderr makes PowerShell 5.1 wrap each line in an ErrorRecord and read it as a failure
# even with exit code 0. It is taken to a file and read back as text.
#
# The PID and the net name are put into the file name. With a fixed name, **two people running at the same time
#  overwrite each other's output.** This repo has verify-run and verify-read running the nets in parallel, so it
#  is bound to happen — and it did.
#  There are two symptoms and **the latter is far more dangerous**:
#   · failures appear that do not exist (someone else's failure lines are read as mine)
#   · **a real failure is buried under someone else's green** — nobody notices this one
#   · the `[EXPECT]` lists mix and **the amnesty scope quietly widens**
#  => It was the classic path to wasting time on "is this because of my change". Two verifiers hit it
#   independently and pointed at the same cause.
$tmp = [System.IO.Path]::GetTempPath()

# **A brand-new `class_name` file is invisible to `--headless --script`.** Measured twice on 4.7.1: the net
#  that references it dies with `Parse error` and `Nonexistent function 'new' in base 'GDScript'` — and that
#  shape does NOT reach the runner's zero-check detector, because the net never gets as far as `run()`.
#  Only the stderr verdict below turns it red, so the round goes red for a reason that reads like broken code
#  and is actually a missing import.
#  **`--script` does not re-import on its own** (CLAUDE.md said it did, for two days, and four agents lost a
#  round to it). Every plan that adds a class file walks into this, so the guard lives here rather than in
#  someone's memory.
#  A `.gd` with no `.uid` beside it is exactly "the engine has not seen this file yet", so the check is one
#  directory walk and the import only runs on the rounds that would have gone red anyway.
$unimported = 0
foreach ($d in @("src", "tests")) {
    $p = Join-Path $root $d
    if (-not (Test-Path $p)) { continue }
    foreach ($f in (Get-ChildItem -Path $p -Recurse -File -Filter "*.gd")) {
        if (-not (Test-Path ($f.FullName + ".uid"))) { $unimported++ }
    }
}
if ($unimported -gt 0) {
    Write-Host "[그물] 임포트 안 된 .gd 가 ${unimported}개다. --import 를 한 번 먼저 돈다."
    $impOut = Join-Path $tmp "tockbon_import_out_$PID.txt"
    $impErr = Join-Path $tmp "tockbon_import_err_$PID.txt"
    $imp = Start-Process -FilePath $godot.FullName -NoNewWindow -Wait -PassThru `
        -ArgumentList @("--headless", "--path", $root, "--import") `
        -RedirectStandardOutput $impOut -RedirectStandardError $impErr
    if ($imp.ExitCode -ne 0) {
        Write-Host "[그물] --import 가 실패했다 (종료 코드 $($imp.ExitCode)). 전문: $impErr" -ForegroundColor Red
        exit 1
    }
}

# The stderr verdict. It receives **the output of one net only** — that is the device that narrows the amnesty.
# The verdict is per block, not per line. One Godot error is 1 header line plus roughly 8 backtrace lines.
# Amnestying per line lets the declaration erase only the header while the rest remains and it is still red.
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
        if ($trimmed -match '^x\s') { continue }        # an assertion failure the runner already counted
        if ($trimmed -match '^\[net\]') { continue }

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

# -- The net list. The folder is scanned — it is not a hand-maintained list (CLAUDE.md).
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

# **"It is not 0" is confirmed first.** CLAUDE.md: the reason the first line of a folder scan is always this
#  is to block "if the scene cannot be stood up the check does not fail, it disappears" here too.
if ($netFiles.Count -lt 5) {
    Write-Host "[그물] tests/nets/ 에 그물이 $($netFiles.Count)개뿐이다. 스캔이 깨졌다." -ForegroundColor Red
    exit 1
}

# **If someone edits the source while it is running, false failures appear** (measured; it happened twice).
#  A headless process reading a **half-written file** goes red in bunches with things like "jump height 0" ·
#  "landing y does not match".
#  **That is the path that wastes the most time in this repo** — a false failure is taken as real and the cause is chased.
#   It happened twice: the nets ran while the builder was writing `character.gd` and 13 went red, and another
#   time the nets stepped into the builder's **inversion window** (a short stretch with a value deliberately
#   broken) and 38 went red.
#  => **It cannot be prevented** (someone else's edits cannot be blocked). **Instead the runner is made to say
#   "this is suspect".** It compares the newest modification time at the start and at the end, and if anything
#   changed while running it prints that the result should not be trusted.
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

# **The stamp above only sees a change that happens DURING the round, and that is not the dangerous case.**
#  A file another agent broke BEFORE the round started and restored AFTER it ended never moves it, so a
#  contaminated result — red OR green — prints with exactly the same confidence as a clean one. Measured
#  three times in one session: rounds came back red in nets nobody had touched, no [경합] warning, and a
#  re-run 30 seconds later was fully green. Three mutation measurements were lost to it.
#  **A single round cannot detect this from the inside.** What it can do is make two rounds COMPARABLE:
#  every scanned file's path, size and mtime, hashed, printed every time. Two rounds carrying the same
#  fingerprint measured the same tree; two that differ did not, and that difference has to be explained
#  before either result is believed.
#  ⚠ Deliberately NOT a `git status --porcelain` comparison: an uncommitted working tree is the normal
#  state of every builder round, so reddening the wrapper on it would red every round in the repo.
function Get-SrcFingerprint([string]$r) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($d in @("src", "tests")) {
        $p = Join-Path $r $d
        if (-not (Test-Path $p)) { continue }
        $files = Get-ChildItem -Path $p -Recurse -File -Include "*.gd", "*.tscn", "*.tres" | Sort-Object FullName
        foreach ($f in $files) {
            [void]$sb.Append($f.FullName).Append('|').Append($f.Length).Append('|').Append($f.LastWriteTimeUtc.Ticks).Append("`n")
        }
    }
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))
    return ([System.BitConverter]::ToString($bytes) -replace '-', '').Substring(0, 12)
}
$fingerprint = Get-SrcFingerprint $root

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# -- Serial: the old behavior. Everything in one process.
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
    Write-Host ("[지문] src·tests {0} — 두 라운드의 지문이 다르면 같은 나무를 잰 것이 아니다" -f $fingerprint)
    if ($exitCode -eq 0) {
        Write-Host ("[래퍼] 통과. stderr 깨끗함. ({0:N1}s, 직렬)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    } else {
        Write-Host "[래퍼] 실패 (종료 코드 $exitCode)" -ForegroundColor Red
    }
    exit $exitCode
}

# -- Parallel. The number of processes alive at once is limited.
#  One grid is 4.12M cells x four arrays, so each process eats memory. It is bounded by the core count.
$maxParallel = [Math]::Max(2, [Math]::Min(8, [Environment]::ProcessorCount - 2))
Write-Host "[그물] $($nets.Count)개를 병렬로 돈다 (동시 ${maxParallel}개)"

# **Queue order decides the makespan, not just per-net speed.** The slot-filling loop below starts
#  whatever is next in `$queue` the moment a slot frees — queued alphabetically, the two heaviest nets
#  (`water`, `monster`) don't even start together, so a slot sits idle-of-the-heavy-work while a run of
#  light nets finishes first. harness-manager measured: 21 nets' own Sec summed to 75.9s, the slowest
#  single net was 12.2s, so the best possible makespan at 8-way parallel is max(12.2, 75.9/8) = 12.2s —
#  and the alphabetical queue was landing at 15.2s, ~3s of pure scheduling waste, nothing to do with any
#  net's own speed.
#  **Longest-first (LPT) fixes it**: whatever took longest last time is launched first, so it runs
#  alongside the fill of shorter nets instead of after them. The timing itself is measured, not guessed —
#  read from the previous run's own Sec column, cached here. A net with no prior timing (new, or a
#  filtered-out run) sorts first (treated as unknown-could-be-slow) rather than last (which would silently
#  re-create the alphabetical straggler problem for every new net until its first recorded run).
$timingFile = Join-Path $tmp "tockbon_net_timings.json"
$timings = @{}
if (Test-Path $timingFile) {
    try {
        $raw = Get-Content $timingFile -Raw -Encoding utf8 | ConvertFrom-Json
        foreach ($p in $raw.PSObject.Properties) { $timings[$p.Name] = [double]$p.Value }
    } catch {}
}
$nets = $nets | Sort-Object -Descending { if ($timings.ContainsKey($_)) { $timings[$_] } else { [double]::MaxValue } }

$jobs = @()
$queue = New-Object System.Collections.Queue
foreach ($n in $nets) { $queue.Enqueue($n) | Out-Null }
$running = @()

while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    while ($running.Count -lt $maxParallel -and $queue.Count -gt 0) {
        $n = $queue.Dequeue()
        $o = Join-Path $tmp "tockbon_net_${n}_out_$PID.txt"
        $e = Join-Path $tmp "tockbon_net_${n}_err_$PID.txt"
        # **`^` binds it to exactly this one net** (harness-manager, measured).
        #  With a substring match (passing `$n` as-is), nets whose names contain each other (`net_water` in
        #  `net_water_rain`, `net_sprite` in `net_monster_sprite`) let one process secretly run several nets —
        #  the isolation breaks and the parallelism does not reduce the time (see the comment on the `run_nets.gd` side).
        $a = @("--headless", "--path", $root, "--script", "res://tests/run_nets.gd", "--", "^$n")
        $p = Start-Process -FilePath $godot.FullName -ArgumentList $a -NoNewWindow -PassThru `
            -RedirectStandardOutput $o -RedirectStandardError $e
        # **The handle has to be read once for `ExitCode` to survive after exit.**
        #  Unread, .NET drops the process handle and `HasExited` is true while `ExitCode` is empty
        #  => **every net reads as a failure.** That accident was measured — the pass counts were normal while all 13 read [failure].
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

# -- Aggregation
$totalPass = 0
$totalFail = 0
$exitCode = 0
$lines = @()

foreach ($j in ($jobs | Sort-Object Net)) {
    $stdout = if (Test-Path $j.Out) { Get-Content $j.Out -Raw -Encoding utf8 } else { "" }
    $stderr = if (Test-Path $j.Err) { Get-Content $j.Err -Raw -Encoding utf8 } else { "" }
    if ($null -eq $stdout) { $stdout = "" }
    if ($null -eq $stderr) { $stderr = "" }

    # **The runner prints two different shapes and this used to match only one.** `[net] N passed` on a clean
    #  net, `[net] N failed / M` when anything failed — so a net with ONE failed assertion out of 31 displayed
    #  as `통과 0`, which is the vanish signature CLAUDE.md teaches people to read as "it never loaded".
    #  The round total dropped by that whole net's worth (279 -> 248) for a single bad assert. Measured by
    #  verify-run, 2026-08-14: the per-net output said `[net] 1 failed / 31` while this column said 0.
    #  Both shapes are matched now, and the pass count is M - N on the failing shape.
    $pass = 0
    if ($stdout -match '\[net\]\s+(\d+)\s+passed') {
        $pass = [int]$Matches[1]
    } elseif ($stdout -match '\[net\]\s+(\d+)\s+failed\s*/\s*(\d+)') {
        $pass = [int]$Matches[2] - [int]$Matches[1]
    }
    $fail = 0
    foreach ($l in ($stdout -split "`r?`n")) { if ($l -match '^x\s') { $fail++ } }
    foreach ($l in ($stderr -split "`r?`n")) { if ($l.Trim() -match '^x\s') { $fail++ } }

    $noise = Get-Noise $stdout $stderr
    $bad = ($j.Proc.ExitCode -ne 0) -or ($noise.Count -gt 0)

    $totalPass += $pass
    $totalFail += $fail

    # Only the failure **lines** are pulled out. Dumping the full text explodes the output and the actual
    #  failures scroll off the top.
    #  Measured: the full text of 13 nets went past 6,000 characters and was truncated, and five failure lines
    #  were nearly lost inside it.
    #  The runner writes the same failure to both stdout and stderr => **duplicates are removed.** Otherwise it looks doubled.
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

# **Merge, not overwrite** — a filtered run (`-Filter monster`) only re-times the nets it ran; every other
#  net's cached duration from a prior full run has to survive so the *next* full run still schedules them well.
foreach ($l in $lines) { $timings[$l.Net] = $l.Sec }
try { ($timings | ConvertTo-Json) | Out-File -FilePath $timingFile -Encoding utf8 -Force } catch {}

Write-Host ""
foreach ($l in ($lines | Sort-Object Sec -Descending)) {
    if ($l.Bad) {
        Write-Host ("  {0,-14} 통과 {1,5}   {2,6:N1}s   [실패]" -f $l.Net, $l.Pass, $l.Sec) -ForegroundColor Red
    } else {
        Write-Host ("  {0,-14} 통과 {1,5}   {2,6:N1}s" -f $l.Net, $l.Pass, $l.Sec) -ForegroundColor DarkGray
    }
}

# Only the failing nets, and only their failure lines. If the full text is needed, the output file path is printed.
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
Write-Host ("[지문] src·tests {0} — 두 라운드의 지문이 다르면 같은 나무를 잰 것이 아니다" -f $fingerprint)

# If the source changed while it was running, **do not trust the result.** The why is in the comment on the function above.
$stampAfter = Get-SrcStamp $root
if ($stampAfter -ne $stampBefore) {
    Write-Host ""
    Write-Host "[경합] 그물이 도는 동안 src/ 또는 tests/ 가 바뀌었다." -ForegroundColor Yellow
    Write-Host "       (마지막 수정 $stampBefore UTC -> $stampAfter UTC)" -ForegroundColor Yellow
    Write-Host "       이 결과를 믿지 마라. 절반 쓰인 파일을 읽었을 수 있다." -ForegroundColor Yellow
    Write-Host "       실패가 났다면 편집이 멈춘 뒤 다시 돌리고 나서 판단해라." -ForegroundColor Yellow
    Write-Host "       초록이어도 마찬가지다 - 옛 파일을 읽고 통과했을 수 있다." -ForegroundColor Yellow
}

if ($exitCode -eq 0) {
    Write-Host "[래퍼] 통과. stderr 깨끗함." -ForegroundColor Green
} else {
    Write-Host "[래퍼] 실패 (종료 코드 $exitCode)" -ForegroundColor Red
}
exit $exitCode
