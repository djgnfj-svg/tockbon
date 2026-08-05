"""tockbon 에셋 생성기 — 로컬 ComfyUI(FLUX.2 klein base 4B)를 부른다.

    python gen.py "프롬프트" --name glyph_spread --preset glyph --batch 8

🔴 이 리포에서 만드는 것은 캐릭터가 아니라 **마법진 UI · 문양 · 룬 · 진**이다.
  ⇒ 기본이 `--lora 0` 이다. 4-walk LoRA를 켜면 UI 프롬프트에도 **사람 스프라이트시트가 나온다**
   (원본 파이프라인 PROMPTS.md 의 실측이다). 프리셋이 그 값을 들고 있는 이유가 이것 하나다.
"""

import argparse
import io
import json
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from itertools import product
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).parent
CFG = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
SERVER = CFG["server"].rstrip("/")
WORKFLOW = ROOT / "workflows" / "base_api.json"
OUT = ROOT / "out"

# ─── 스타일 프리셋 ────────────────────────────────────────────────
# 🔴🔴 **한 게임 안에서 그림이 갈리는 것을 막는 자리다.** 프롬프트마다 스타일 문구를
#  손으로 적으면 반드시 갈라진다 — 원본 파이프라인의 TODO 두 번째 항목이 그 얘기다.
#
# ⚠ `style` 은 프롬프트 **뒤에** 붙는다. 앞에 붙이면 모델이 스타일만 그리고 내용을 흘린다.
# ⚠ `size` 는 **생성 해상도**고 `down` 은 **최종 픽셀 크기**다. 둘이 다른 축이다 —
#  512로 그려 32px로 내리는 것과 처음부터 32px로 그리는 것은 결과가 완전히 다르다
#  (FLUX 는 512 아래에서 형태가 무너진다). ⇒ **크게 그리고 내린다.**
PRESETS = {
    # 층에 끼우는 기하학 무늬. 화면에서 지름 31px이라 **디테일이 원리적으로 안 들어간다.**
    "glyph": {
        "style": "solid black flat geometric line art on a plain white background, "
                 "bold simple shapes, perfectly symmetrical, centered, "
                 "no shading, no gradient, no color, no text",
        "lora": 0.0, "size": 512, "down": 64, "steps": 28, "cfg": 5.0,
    },
    # 진 — 층이 눈에 갈리는 동심 틀.
    "frame": {
        "style": "solid black line art on a plain white background, "
                 "concentric rings with clear gaps between layers, "
                 "perfectly round and symmetrical, flat top-down view, "
                 "no shading, no color, no text",
        "lora": 0.0, "size": 512, "down": 256, "steps": 28, "cfg": 5.0,
    },
    # 룬 — 🔴 기하학일 필요가 없다(사용자 결정). 속성이 한눈에 읽히는 것이 전부다.
    "rune": {
        "style": "pixel art game icon, bold readable silhouette, centered, "
                 "plain white background, 16-bit shading",
        "lora": 0.0, "size": 512, "down": 96, "steps": 28, "cfg": 5.0,
    },
    # 조립창 — 펼친 마도서. ⚠ 9-slice 로 늘리면 모서리가 어긋난다(원본 PROMPTS.md 실측).
    "ui": {
        "style": "pixel art RPG UI panel, 16-bit game interface, "
                 "clean edges, no text, no characters",
        "lora": 0.0, "size": 512, "down": 0, "steps": 28, "cfg": 5.0,
    },
    # 프리셋 없이 그대로. 스타일 문구도 안 붙는다.
    "raw": {"style": "", "lora": 0.0, "size": 512, "down": 0, "steps": 28, "cfg": 5.0},
}


def api_post(path, payload):
    req = urllib.request.Request(
        f"{SERVER}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def api_get(path):
    with urllib.request.urlopen(f"{SERVER}{path}") as r:
        return json.loads(r.read())


def fetch_image(info):
    q = urllib.parse.urlencode(
        {"filename": info["filename"], "subfolder": info["subfolder"], "type": info["type"]}
    )
    with urllib.request.urlopen(f"{SERVER}/view?{q}") as r:
        return Image.open(io.BytesIO(r.read())).convert("RGB")


def k_centroid(image, width, height, centroids=2):
    """블록마다 k-means 로 지배색을 고른다. 🔴 평균이 아니라 **지배색**인 것이 요점이다 —
    평균을 쓰면 검은 선과 흰 종이가 섞여 회색 테두리가 생기고, 그건 픽셀아트가 아니다."""
    out = Image.new("RGB", (width, height))
    wf = image.width / width
    hf = image.height / height
    for x, y in product(range(width), range(height)):
        tile = image.crop((int(x * wf), int(y * hf), int((x + 1) * wf), int((y + 1) * hf)))
        tile = tile.quantize(colors=centroids, method=1, kmeans=centroids).convert("RGB")
        dominant = max(tile.getcolors(), key=lambda c: c[0])[1]
        out.putpixel((x, y), dominant)
    return out


def build(base_wf, text, negative, steps, cfg, seed, w, h, lora):
    wf = json.loads(json.dumps(base_wf))
    wf["5"]["inputs"]["text"] = text
    wf["6"]["inputs"]["text"] = negative
    wf["4"]["inputs"]["strength_model"] = lora
    wf["7"]["inputs"]["cfg"] = cfg
    wf["9"]["inputs"].update(steps=steps, width=w, height=h)
    wf["10"]["inputs"].update(width=w, height=h)
    wf["11"]["inputs"]["noise_seed"] = seed
    # 🔴 15·16번(엔진 쪽 4배 다운스케일)은 **안 쓴다.** 크기를 여기서 정하므로
    #  워크플로우가 고정 128px 로 내리면 그 값이 두 곳이 되고 갈라진다.
    #  ⇒ 다운스케일은 파이썬이 한다(아래 `down`). 노드는 남겨 두되 결과를 안 읽는다.
    return wf


def run_one(base_wf, args, seed, index, outdir, preset):
    text = args.prompt if not preset["style"] else f"{args.prompt}. {preset['style']}"
    wf = build(base_wf, text, args.negative, args.steps, args.cfg,
               seed, args.width, args.height, args.lora)

    prompt_id = api_post("/prompt", {"prompt": wf})["prompt_id"]
    print(f"  [{index}] seed={seed} ...", flush=True)

    started = time.time()
    while True:
        hist = api_get(f"/history/{prompt_id}")
        if prompt_id in hist:
            entry = hist[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                for msg in status.get("messages", []):
                    if msg[0] == "execution_error":
                        raise RuntimeError(msg[1].get("exception_message", msg[1]))
                raise RuntimeError("execution failed")
            if status.get("completed"):
                break
        if time.time() - started > 900:
            raise TimeoutError("900초 넘게 안 끝났다")
        time.sleep(1.0)

    raw = fetch_image(entry["outputs"]["14"]["images"][0])
    stem = f"{args.name}_{index:02d}_seed{seed}"
    raw.save(outdir / f"{stem}.png")

    if args.down > 0:
        # 🔴 가로세로 비율을 원본에서 가져온다. 정사각을 가정하면 비정사각 UI 에서 찌그러진다.
        dh = max(1, round(args.down * raw.height / raw.width))
        k_centroid(raw, args.down, dh).save(outdir / f"{stem}_{args.down}px.png")

    print(f"  [{index}] {time.time() - started:.1f}s -> {stem}.png", flush=True)
    return stem


def main():
    p = argparse.ArgumentParser(description="tockbon 에셋 생성 (로컬 ComfyUI)")
    p.add_argument("prompt")
    p.add_argument("--name", default="asset", help="출력 폴더/파일 이름")
    p.add_argument("--preset", default="glyph", choices=sorted(PRESETS), help="스타일 프리셋")
    p.add_argument("--batch", type=int, default=4, help="후보 몇 장")
    p.add_argument("--seed", type=int, default=-1, help="-1이면 무작위")
    p.add_argument("--width", type=int, default=0, help="생성 폭 (0이면 프리셋 값)")
    p.add_argument("--height", type=int, default=0, help="생성 높이 (0이면 프리셋 값)")
    p.add_argument("--down", type=int, default=-1, help="최종 픽셀 폭 (0이면 안 내림, -1이면 프리셋 값)")
    p.add_argument("--steps", type=int, default=0)
    p.add_argument("--cfg", type=float, default=0.0)
    p.add_argument("--lora", type=float, default=-1.0, help="4-walk LoRA 강도. 🔴 UI/문양은 0이다")
    p.add_argument("--negative", default="")
    args = p.parse_args()

    preset = PRESETS[args.preset]
    if args.width <= 0:
        args.width = preset["size"]
    if args.height <= 0:
        args.height = args.width
    if args.down < 0:
        args.down = preset["down"]
    if args.steps <= 0:
        args.steps = preset["steps"]
    if args.cfg <= 0:
        args.cfg = preset["cfg"]
    if args.lora < 0:
        args.lora = preset["lora"]

    try:
        api_get("/system_stats")
    except (urllib.error.URLError, OSError):
        print(f"ComfyUI 서버가 {SERVER} 에 없다. tools/pixel/serve.ps1 을 먼저 돌려라.")
        return 1

    base_wf = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    outdir = OUT / args.name
    outdir.mkdir(parents=True, exist_ok=True)

    print(f'"{args.prompt}"')
    print(f"  preset={args.preset} {args.width}x{args.height} steps={args.steps} "
          f"cfg={args.cfg} lora={args.lora} down={args.down or '-'} x{args.batch}")

    for i in range(1, args.batch + 1):
        seed = random.randint(0, 2**31 - 1) if args.seed < 0 else args.seed + i - 1
        run_one(base_wf, args, seed, i, outdir, preset)

    print(f"\n=> {outdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
