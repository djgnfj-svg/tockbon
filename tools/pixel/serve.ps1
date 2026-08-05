# ComfyUI 서버를 띄운다. 이미 떠 있으면 아무것도 안 한다.
#
# 🔴 서버는 켜 둔 채로 두는 것이 맞다 — 모델 로딩에 30초쯤 걸리고, 그 뒤로는 한 장에 몇 초다.
# ⚠ 이 창을 닫아도 서버는 안 죽는다(별도 프로세스). 끄려면 stop.ps1.

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

# 🔴 로그를 반드시 파일로 받는다. 안 받으면 안 떴을 때 **이유가 어디에도 안 남고**
#  「3분 안에 안 떴다」만 보인다 — 실측으로 그렇게 한 번 막혔다.
# ⚠ ComfyUI 는 진행 로그를 stderr 로 낸다. `.err` 쪽이 실제 내용이다.
$log = Join-Path $PSScriptRoot "out\_comfy.log"
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null

Write-Output "ComfyUI: 시작 (로그: $log.err)"
# --enable-dynamic-vram: VRAM 보다 큰 모델을 동적 오프로딩으로 돌린다 (원본 리포의 run_h3_16gb.bat)
Start-Process -FilePath $py `
    -ArgumentList @("-s", $main, "--windows-standalone-build", "--listen", "127.0.0.1",
                    "--port", "8188", "--enable-dynamic-vram", "--async-offload") `
    -WorkingDirectory $root -WindowStyle Minimized `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err"

# ⚠ **3분으로 잡았다가 실패했다.** 첫 기동은 커스텀 노드 임포트까지 그보다 오래 걸린다.
for ($i = 0; $i -lt 100; $i++) {
    Start-Sleep -Seconds 3
    try {
        Invoke-WebRequest -Uri "$server/system_stats" -TimeoutSec 3 -UseBasicParsing | Out-Null
        Write-Output "ComfyUI: 준비 완료 ($server)"
        exit 0
    } catch {}
}
throw "5분 안에 안 떴다. $log.err 의 마지막 줄을 봐라."
