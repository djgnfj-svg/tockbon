# Brings up the ComfyUI server. If it is already up, it does nothing.
#
# Leaving the server running is the right thing — model loading takes about 30 seconds, and after that
# it is a few seconds per image.
# Closing this window does not kill the server (separate process). To stop it, use stop.ps1.

$ErrorActionPreference = "Stop"
$cfg = Get-Content "$PSScriptRoot\config.json" -Raw | ConvertFrom-Json
$server = $cfg.server
$root = $cfg.comfy_root

$alive = $false
try {
    Invoke-WebRequest -Uri "$server/system_stats" -TimeoutSec 3 -UseBasicParsing | Out-Null
    $alive = $true
} catch {}

if ($alive) {
    Write-Output "ComfyUI: 이미 떠 있다 ($server)"
    exit 0
}

$py = Join-Path $root "python_embeded\python.exe"
$main = Join-Path $root "ComfyUI\main.py"
if (-not (Test-Path $py)) { throw "python_embeded 가 없다: $py  (config.json 의 comfy_root 확인)" }

# Always capture the log to a file. Without it, when startup fails **the reason is left nowhere**
#  and all you see is "it didn't come up in 3 minutes" — that actually blocked things once.
# ComfyUI writes its progress log to stderr. The `.err` side is the real content.
$log = Join-Path $PSScriptRoot "out\_comfy.log"
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null

Write-Output "ComfyUI: 시작 (로그: $log.err)"
# --enable-dynamic-vram: runs a model larger than VRAM via dynamic offloading (the original repo's run_h3_16gb.bat)
Start-Process -FilePath $py `
    -ArgumentList @("-s", $main, "--windows-standalone-build", "--listen", "127.0.0.1",
                    "--port", "8188", "--enable-dynamic-vram", "--async-offload") `
    -WorkingDirectory $root -WindowStyle Minimized `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err"

# **This was set to 3 minutes and failed.** The first startup takes longer than that, through custom node imports.
for ($i = 0; $i -lt 100; $i++) {
    Start-Sleep -Seconds 3
    try {
        Invoke-WebRequest -Uri "$server/system_stats" -TimeoutSec 3 -UseBasicParsing | Out-Null
        Write-Output "ComfyUI: 준비 완료 ($server)"
        exit 0
    } catch {}
}
throw "5분 안에 안 떴다. $log.err 의 마지막 줄을 봐라."
