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
#  2. **The amnesty is confined to its own net.** An amnesty whose lifetime is unlimited is wider than its own
#     breadth, and that is a fake net: in one process the [EXPECT] entries on stdout are **all
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
#  overwrite each other's output.** This repo runs `verify` alongside `builder`, and two sessions have shared
#  `main` at once, so it is bound to happen — and it did.
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
#  ⚠⚠ **「Only the stderr verdict below turns it red」 was true until 2026-09-02 and is not any more.**
#  That shape prints `[net] 0 passed` at exit code 0, so `Get-CheckCount` reddens it as well — measured live
#  this round on a net whose stdout was 97 bytes and whose exit code was 0. **Two verdicts fire on it now.**
#  Either way the round goes red for a reason that reads like broken code and is actually a missing import.
#  **`--script` does not re-import on its own** (a rule file said it did, for two days, and four agents lost a
#  round to it; that wrong line is gone now and this comment is what replaced it). Every plan that adds a class file walks into this, so the guard lives here rather than in
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

# **WHICH FUNCTIONS THE ROUND ABANDONED, read off the same stderr `[침묵사]` already parses.**
#
# **GDScript 4.7 has no try/catch, and a runtime error abandons ONLY the function it lands in.** The
#  caller resumes on its next line and receives `null` — through `await` too — and the process still
#  exits 0. So a death has two completely different costs depending on where it lands, and **the summary
#  cannot tell them apart**:
#   · in `run()` itself, every check below it is abandoned (net_shell lost 17 that way, twice)
#   · in a helper one frame down, `run()` carries on and only that helper's own rows are lost
#  **The runner's `t.done()` sentinel catches the first shape and CANNOT catch the second** — `run()`
#  genuinely finished. This function is the only thing that can see it, and it needs nothing from the nets.
#
# ⚠ **Only `SCRIPT ERROR` blocks.** `push_error` prints `USER ERROR` and does NOT abandon anything — it
#  is a log line, and a net that declared it with `expect_error` is behaving exactly as designed.
# ⚠ **Amnesty is deliberately NOT applied here.** `expect_error` forgives a bark; it cannot forgive a
#  function that stopped running, and a declared runtime error still costs every row underneath it.
#
# ⚠⚠ **THIS MARKS THE COUNT AND DOES NOT TURN THE NET RED, AND THAT IS A CHOICE RATHER THAN AN
#  OVERSIGHT.** Today every net it fires on is already red through `[침묵사]`, because an undeclared
#  bark is itself a failure here — so the two look the same and nothing is lost. **The case where they
#  come apart is a `SCRIPT ERROR` a net DECLARED with `expect_error`**: the bark is forgiven, the net
#  stays green, and it prints 「통과 N (불완전)」 with an exit code of 0. **A net sitting there
#  green-and-incomplete is allowed**, and this comment is the record that somebody looked at it and
#  decided so — reddening it was not asked for and was not invented here. If that ever becomes the
#  wrong answer, the change is one `-or $abandoned.Count -gt 0` on `$bad` below.
function Get-Abandoned([string]$stderr) {
    $out = @()
    $inScript = $false
    foreach ($line in ($stderr -split "`r?`n")) {
        $t = $line.Trim()
        if ($t -eq "") { continue }
        if ($t -match '^(USER )?SCRIPT ERROR:') { $inScript = $true; continue }
        if ($t -match '^(ERROR|WARNING|USER ERROR|USER WARNING):') { $inScript = $false; continue }
        # The first `at:` after the header names the frame the error actually landed in. The backtrace
        # lines below it repeat the same frame and then its callers, which is not what was abandoned.
        if ($inScript -and $t -match '^at:\s+(.+?)\s+\(res://(.+?):(\d+)\)') {
            $fn = $Matches[1]
            $file = Split-Path -Leaf $Matches[2]
            $entry = $fn + " (" + $file + " " + $Matches[3] + ")"
            if ($out -notcontains $entry) { $out += $entry }
            $inScript = $false
        }
    }
    return ,$out
}

# **HOW MANY CHECKS THE NET REPORTED, read off the runner's own summary line.**
#
# ⚠⚠ **The predicate this serves is 「it ran no checks」, NOT 「there is no summary line」.**
#  `run_nets.gd` prints its summary on **every** path that reaches its end — the path where the filter
#  selected nothing and the loop body never ran once included. So a net that measured nothing still prints
#  `[net] 0 passed` and exits 0, and a guard written on the line's ABSENCE reads that line and stays grey.
#  The severed `await` this shape was measured on is recorded in `run_nets.gd`'s own header, and
#  `how-nets-lie` holds the rounds where a whole net's count left the total without a red.
# **The two summary shapes carry the total in different places**: `[net] N passed` ran N checks,
#  `[net] N failed / M` ran M.
# ⚠ **Not the pass count.** A net whose every check failed also passes 0, and calling that 「ran no
#  checks」 would put a false label on a net that ran all of them — which is the failure this whole file
#  is built against.
#
# ⚠⚠ **WRITTEN AND NOT RUN, 2026-09-02** (ticket 03-15). This function and the two verdicts that call it
#  were written on a box with no `pwsh` and no `powershell` on it, so **not one line of it has executed.**
#  The round that decided it ran through a stand-in that mirrors this wrapper's two jobs and is not this
#  file. **Whoever next runs a round on Windows is the first person to run this.**
function Get-CheckCount([string]$text) {
    $n = 0
    if ($text -match '\[net\]\s+(\d+)\s+passed') {
        $n = [int]$Matches[1]
    } elseif ($text -match '\[net\]\s+(\d+)\s+failed\s*/\s*(\d+)') {
        $n = [int]$Matches[2]
    }
    return $n
}

# -- The net list. **The folder is scanned — it is never a hand-maintained list**, because a list someone forgets
#    to add to is a net that silently stops running.
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

# **"It is not 0" is confirmed first.** The first line after a folder scan is always this, to block "if the scene cannot be stood up the check does not fail, it disappears" here too.
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
#  every scanned file's path and CONTENT hash, digested, printed every time. Two rounds carrying the same
#  fingerprint measured the same tree; two that differ did not, and that difference has to be explained
#  before either result is believed.
#  ⚠ Deliberately NOT a `git status --porcelain` comparison: an uncommitted working tree is the normal
#  state of every builder round, so reddening the wrapper on it would red every round in the repo.
#  ⚠ **It hashes the CONTENT, and for two rounds it did not.** The digest used to be path|length|mtime, so
#  every apply/revert pair moved it even when the bytes came back identical — three separate repairs in one
#  night reported that the protocol this print exists to serve ("a mutation whose PRE and POST fingerprints
#  differ only by that mutation") could not be executed literally, and each worked around it by doing the
#  edit and the run in one command. A metadata digest answers "was anything touched"; the question is
#  "is this the same tree", and only the bytes answer that.
#  ⚠ **It covers what the round READS, and `docs/` joined that list.** `net_citations` scans `docs/` and
#  `CLAUDE.md` for the line-number citation form, so a doc edited between two rounds changes what the round
#  measured while a `src`+`tests`-only digest prints identically — the exact "two rounds carrying the same
#  fingerprint measured the same tree" claim, quietly false for one net. Measured: a `.gd:NNN` citation put
#  into a doc reddens the round and does not move a digest that stops at `tests/`.
function Get-SrcFingerprint([string]$r) {
    $sb = New-Object System.Text.StringBuilder
    $md5 = [System.Security.Cryptography.MD5]::Create()
    foreach ($d in @("src", "tests", "docs")) {
        $p = Join-Path $r $d
        if (-not (Test-Path $p)) { continue }
        $files = Get-ChildItem -Path $p -Recurse -File -Include "*.gd", "*.tscn", "*.tres", "*.md" | Sort-Object FullName
        foreach ($f in $files) {
            $h = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($f.FullName))) -replace '-', ''
            [void]$sb.Append($f.FullName).Append('|').Append($h).Append("`n")
        }
    }
    $claude = Join-Path $r "CLAUDE.md"
    if (Test-Path $claude) {
        $h = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($claude))) -replace '-', ''
        [void]$sb.Append($claude).Append('|').Append($h).Append("`n")
    }
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
    # **NOT the same guard as `$ranNothing` below, and the difference is the whole of what it can see.**
    #  One process runs every filtered net here and prints ONE summary for the batch, so this count is the
    #  batch's and never a net's. ⇒ **It fires only when the WHOLE batch ran nothing.** A single net
    #  vanishing inside a batch that still reported is invisible to it.
    # ⚠⚠ **Measured, 2026-09-02**: `net_hand` and `net_islands` in one process with `net_hand`'s class
    #  unresolvable printed `[net] 21 passed` at exit code 0 — `net_islands`' whole count, `net_hand`'s 91
    #  checks gone, and this guard silent. **The parallel path catches that one; this path cannot.**
    # ⚠ **Do not go hunting for the fix here.** One summary line carries one number for the batch, so a
    #  per-net loss may not be recoverable from it at all. What is left is still worth having: the narrowed
    #  run somebody actually reaches for to chase a vanished net is `-Serial` on that one net, and there the
    #  batch IS the net.
    # ⚠ A batch of zero cannot reach this at all: a filter matching no net already exited above, and this
    #  side strips `net_` before matching while the engine side does not, so the engine's set is a superset.
    if ((Get-CheckCount $stdout) -eq 0) {
        Write-Host ""
        Write-Host "[빈그물] 검사를 하나도 안 돌렸다 — 이 라운드는 아무것도 재지 않았다." -ForegroundColor Red
        $exitCode = 1
    }
    $sw.Stop()
    Write-Host ("[지문] src·tests·docs {0} — 두 라운드의 지문이 다르면 같은 나무를 잰 것이 아니다" -f $fingerprint)
    if ($exitCode -eq 0) {
        Write-Host ("[래퍼] 통과. stderr 깨끗함. ({0:N1}s, 직렬)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    } else {
        Write-Host "[래퍼] 실패 (종료 코드 $exitCode)" -ForegroundColor Red
    }
    exit $exitCode
}

# **A hung net is indistinguishable from a slow one, and that disarms mutation testing on the whole net.**
#  Measured: zeroing the `corpse_progress` increment in `World::_step_corpses` made `net_eating` spin
#  forever instead of going red. It was killed by hand at 148.7 seconds with 0 checks reported and the
#  wrapper never printed a verdict at all — not red, not green, nothing. Every check downstream of that
#  point in that net is unverifiable by mutation while this is true, which is the whole point of having them.
#  The loops themselves were bounded afterwards, so nothing hangs *today*; this is the backstop that turns
#  the NEXT runaway into a red instead of a blocked round, and it is the half that was left open.
#
#  **The value is named rather than inline** so raising it is a decision someone makes on purpose. 120s is
#  ~57x the whole round (2.1s) and ~66x the slowest single net (1.8s), so it can only fire on something
#  that is not working — a net that legitimately grows past two minutes is a `net-tuner` problem
#  long before it is a timeout problem.
$NetTimeoutSec = 120.0

# -- Parallel. The number of processes alive at once is limited.
#  **The old ceiling (8, i.e. `ProcessorCount - 2` on this machine) was tuned for a game that is gone** —
#  v2-openfield's grid was 4.12M cells x four arrays per process, and that memory reasoning does not apply
#  to an empty `src/`. net-tuner measured (2026-08-17), 8-core/16-thread machine, throwaway load:
#   · 32 cheap nets (spawn-dominated): cap 8 (4 waves) 2.36s -> cap 16 (2 waves) not retested alone, but
#     the 49-net mixed round below carries it
#   · 16 CPU-heavy nets (~1s of real work each): cap 8 (2 waves) 3.6s -> cap 16 (1 wave, 2x oversubscribed
#     on 8 physical cores) 2.55s — SMT plus skipping a second wave's process-boot tax wins even against
#     doubled per-core contention
#   · full 49-net mixed set (33 cheap + 16 heavy + citations): cap 8 / 120ms poll 6.1s -> cap 16 / 25ms
#     poll (see below) 3.75s
#  ⇒ Raising the cap did not lose on any workload tried. It is bound to `ProcessorCount`, not hardcoded 16,
#  but capped at 16 so an unusually wide machine does not spawn an unbounded pile of processes untested.
#  **Re-measure this the day a net holds real per-process state again** (a big grid, a large asset table) —
#  the memory ceiling that justified the old conservative number will be back, and it was never remeasured
#  here, only removed because nothing exists yet to hit it.
$maxParallel = [Math]::Max(2, [Math]::Min(16, [Environment]::ProcessorCount))
Write-Host "[그물] $($nets.Count)개를 병렬로 돈다 (동시 ${maxParallel}개)"

# **Queue order decides the makespan, not just per-net speed.** The slot-filling loop below starts
#  whatever is next in `$queue` the moment a slot frees — queued alphabetically, the two heaviest nets
#  (`water`, `monster`) don't even start together, so a slot sits idle-of-the-heavy-work while a run of
#  light nets finishes first. net-tuner measured: 21 nets' own Sec summed to 75.9s, the slowest
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
        # **`^` binds it to exactly this one net** (net-tuner, measured).
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
    # **120ms narrowed to 25ms.** Every wave-boundary pays up to one full poll interval before a freed slot
    #  is noticed and the next queued net starts. With many short nets and several waves this compounds —
    #  net-tuner measured (2026-08-17): 32 cheap throwaway nets at 4 waves, 120ms poll averaged 2.36s,
    #  25ms poll averaged 2.23s over 3 runs each, same nets, same cap. The poll body itself is a few cheap
    #  `HasExited` checks, so 5x more of them costs nothing worth naming.
    Start-Sleep -Milliseconds 25
    $still = @()
    foreach ($r in $running) {
        if ($r.Proc.HasExited) {
            $r | Add-Member -NotePropertyName Sec -NotePropertyValue ($sw.Elapsed.TotalSeconds - $r.Started) -Force
            $jobs += $r
        } elseif (($sw.Elapsed.TotalSeconds - $r.Started) -gt $NetTimeoutSec) {
            # **Killed, and carried as its own flag.** The exit code of a killed process is not a reliable
            #  red on its own, and the net's stdout is whatever it managed to flush before the hang — which
            #  can be a perfectly clean `[net] N passed` from a net that then spun in a later loop. So the
            #  verdict does not come from the exit code or the output; it comes from the fact that we killed it.
            try { $r.Proc.Kill() } catch {}
            try { $r.Proc.WaitForExit(5000) | Out-Null } catch {}
            $r | Add-Member -NotePropertyName Sec -NotePropertyValue ($sw.Elapsed.TotalSeconds - $r.Started) -Force
            $r | Add-Member -NotePropertyName TimedOut -NotePropertyValue $true -Force
            Write-Host ("[시간초과] net_{0} 가 {1:N0}초를 넘겨서 죽였다. 멈춘 것은 느린 것이 아니라 실패다." -f $r.Net, $NetTimeoutSec) -ForegroundColor Red
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
    #  as `통과 0`, which is the vanish signature everyone here reads as "it never loaded" — see `docs/how-nets-lie`.
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
    $abandoned = Get-Abandoned $stderr
    # **The round is INCOMPLETE when either detector fires**, and the two see different halves: the
    #  sentinel sees a `run()` that never reached its last line, `Get-Abandoned` sees any function that
    #  stopped early. Neither is a count of failures — it is a statement that the count cannot be read.
    $incomplete = $abandoned.Count -gt 0
    foreach ($l in ($stdout -split "`r?`n")) { if ($l -match '끝까지 못 갔다') { $incomplete = $true } }
    # `$j.TimedOut` is read FIRST and on its own: a killed process's exit code is not dependable, and its
    #  stdout can carry a clean `[net] N passed` flushed before whatever loop it later hung in.
    $timedOut = [bool]$j.PSObject.Properties['TimedOut'] -and $j.TimedOut
    # **A net that reported no checks at all is red, and it is the one shape here with no other door.**
    #  Every neighbour on `$bad` covers something else: this net exits 0, it was not killed, and a boot that
    #  dies before the first check leaves stderr empty so the noise verdict never fires either. What is left
    #  is a grey 「통과 0」 row under a green wrapper, with that whole net's count quietly gone from the total
    #  — and nothing in this round re-derives the total, so the number reads exactly like a whole one.
    # ⚠ **`$timedOut` keeps its own net's verdict.** A killed process flushed whatever it had reached, and
    #  the reason for its red is that we killed it, not what it printed. Stacking a second reason on that row
    #  would name the wrong cause, so it is excluded rather than joined.
    $ranNothing = (-not $timedOut) -and ((Get-CheckCount $stdout) -eq 0)
    $bad = $timedOut -or ($j.Proc.ExitCode -ne 0) -or ($noise.Count -gt 0) -or $ranNothing
    if ($timedOut) {
        # A hung net's own count is meaningless — it reports whatever it reached before it stopped. Counting
        #  it into the round total would let a hang *raise* the number and read as progress.
        $pass = 0
        $fail = 1
    }

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
    if ($timedOut) {
        # Put the reason at the TOP. A hung net that flushed some output first would otherwise print its
        #  partial failures and nothing saying the round never let it finish.
        $failLines = @(("x net_{0}: [시간초과] {1:N0}초 안에 안 끝났다 — 죽여서 빨강으로 만들었다. 멈춘 그물은 느린 그물이 아니다" -f $j.Net, $NetTimeoutSec)) + $failLines
    }
    if ($ranNothing) {
        # Without this the row goes red carrying no reason at all: no `x ` line, no noise, nothing under the
        #  header but the output path. A red whose cause is not printed is read as somebody else's problem.
        $failLines = @(("x net_{0}: [빈그물] 검사를 하나도 안 돌렸다 — 이 그물의 통과 수 전부가 이 라운드 합계에서 조용히 빠졌다" -f $j.Net)) + $failLines
    }

    if ($bad) {
        $exitCode = 1
        $lines += [PSCustomObject]@{ Net = $j.Net; Pass = $pass; Bad = $true; Fails = $failLines; Noise = $noise; Code = $j.Proc.ExitCode; Sec = $j.Sec; Out = $j.Out; Abandoned = $abandoned; Incomplete = $incomplete }
    } else {
        $lines += [PSCustomObject]@{ Net = $j.Net; Pass = $pass; Bad = $false; Fails = @(); Noise = @(); Code = 0; Sec = $j.Sec; Out = $j.Out; Abandoned = $abandoned; Incomplete = $incomplete }
    }
}

# **Merge, not overwrite** — a filtered run (`-Filter monster`) only re-times the nets it ran; every other
#  net's cached duration from a prior full run has to survive so the *next* full run still schedules them well.
foreach ($l in $lines) { $timings[$l.Net] = $l.Sec }
try { ($timings | ConvertTo-Json) | Out-File -FilePath $timingFile -Encoding utf8 -Force } catch {}

Write-Host ""
# **THE MARK GOES ON THE NUMBER AND NOWHERE ELSE.** The whole failure this exists for is that a partial
#  count reads exactly like a whole one — 「통과 56」 from a net that abandoned 17 checks is the same six
#  characters as 「통과 56」 from a net that ran everything. A warning printed further down is read after
#  the number has already been believed.
$incompleteNets = 0
foreach ($l in ($lines | Sort-Object Sec -Descending)) {
    $mark = ""
    if ($l.Incomplete) { $mark = " (불완전)"; $incompleteNets++ }
    if ($l.Bad) {
        Write-Host ("  {0,-14} 통과 {1,5}{2}   {3,6:N1}s   [실패]" -f $l.Net, $l.Pass, $mark, $l.Sec) -ForegroundColor Red
    } elseif ($l.Incomplete) {
        Write-Host ("  {0,-14} 통과 {1,5}{2}   {3,6:N1}s" -f $l.Net, $l.Pass, $mark, $l.Sec) -ForegroundColor Yellow
    } else {
        Write-Host ("  {0,-14} 통과 {1,5}   {2,6:N1}s" -f $l.Net, $l.Pass, $l.Sec) -ForegroundColor DarkGray
    }
}

# Only the failing nets, and only their failure lines. If the full text is needed, the output file path is printed.
foreach ($l in $lines) {
    # ⚠ **An abandoned function prints even on a net the round calls clean.** That is the case the
    #  sentinel cannot reach: `run()` finished, the exit code is 0, and rows inside a helper never ran.
    if (-not $l.Bad -and $l.Abandoned.Count -eq 0) { continue }
    Write-Host ""
    Write-Host "───── net_$($l.Net) (종료 코드 $($l.Code)) ─────" -ForegroundColor Red
    foreach ($f in $l.Fails) { Write-Host "  $f" -ForegroundColor Red }
    if ($l.Abandoned.Count -gt 0) {
        Write-Host ("[중단] 함수 {0}개가 중간에 버려졌다 — 그 아래 검사는 안 돌았고, 위의 통과 수는 잰 것의 일부다." -f $l.Abandoned.Count) -ForegroundColor Yellow
        foreach ($a in $l.Abandoned) { Write-Host "  | $a" -ForegroundColor Yellow }
    }
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
if ($incompleteNets -gt 0) {
    Write-Host ("[불완전] 그물 {0}개가 끝까지 못 갔다 — 이 라운드의 통과 수는 잰 것의 일부다." -f $incompleteNets) -ForegroundColor Yellow
}
Write-Host ("[지문] src·tests·docs {0} — 두 라운드의 지문이 다르면 같은 나무를 잰 것이 아니다" -f $fingerprint)

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
