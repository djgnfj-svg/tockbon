"""Reference-conditioned generation — **the animation frame generator.**

    python genref.py --ref assets_or_out/wolf.png --name bite --seed 7 \
        "the same wolf lunging forward, jaws wide open"

Why this file exists next to `gen.py`: **a walk cycle drawn by text alone does not register.**
Text-to-image at one seed keeps the *texture* (`README.md`, measured) but not the camera distance,
the ground line or the body proportions — so the frames jitter and the animation reads as a glitch.
FLUX.2's `ReferenceLatent` conditions the sample on an actual image, which pins all three.

⚠ **This is the same model and the same presets as `gen.py`.** The only difference is that node 5's
conditioning goes through `ReferenceLatent` before reaching the guider, so the style cannot split.

**`--frames` is the point.** One call, one reference, one seed, N pose prompts => N frames that belong
to each other. Generating them in separate calls works too, but the seed and the reference must match
by hand and that is where a set drifts.
"""

import argparse
import hashlib
import io
import json
import random
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from gen import PRESETS, api_get, api_post, fetch_image, k_centroid  # noqa: E402

ROOT = Path(__file__).parent
CFG = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
SERVER = CFG["server"].rstrip("/")
WORKFLOW = ROOT / "workflows" / "ref_api.json"
OUT = ROOT / "out"
# LoadImage reads from ComfyUI's own input folder, so the reference is copied there under a
#  content-hashed name. Hashed, not the original name — two different references called `wolf.png`
#  would otherwise silently be the same file.
COMFY_INPUT = Path(CFG["comfy_root"]) / "ComfyUI" / "input"


def stage_reference(path: Path) -> str:
    digest = hashlib.sha1(path.read_bytes()).hexdigest()[:8]
    name = f"ref_{digest}.png"
    dest = COMFY_INPUT / name
    if not dest.exists():
        # Flattened onto white: a reference with an alpha channel arrives at VAEEncode as
        #  premultiplied black and the sample comes back dark.
        im = Image.open(path)
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            flat = Image.new("RGB", im.size, (255, 255, 255))
            flat.paste(im, mask=im.split()[-1])
            im = flat
        else:
            im = im.convert("RGB")
        im.save(dest)
    return name


def build(base_wf, text, negative, steps, cfg, seed, w, h, lora, ref_name):
    wf = json.loads(json.dumps(base_wf))
    wf["5"]["inputs"]["text"] = text
    wf["6"]["inputs"]["text"] = negative
    wf["4"]["inputs"]["strength_model"] = lora
    wf["7"]["inputs"]["cfg"] = cfg
    wf["9"]["inputs"].update(steps=steps, width=w, height=h)
    wf["10"]["inputs"].update(width=w, height=h)
    wf["11"]["inputs"]["noise_seed"] = seed
    wf["20"]["inputs"]["image"] = ref_name
    return wf


def run_one(base_wf, args, preset, prompt, seed, index, outdir, ref_name):
    text = prompt if not preset["style"] else f"{prompt}. {preset['style']}"
    wf = build(base_wf, text, args.negative, args.steps, args.cfg,
               seed, args.width, args.height, args.lora, ref_name)

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
        dh = max(1, round(args.down * raw.height / raw.width))
        k_centroid(raw, args.down, dh).save(outdir / f"{stem}_{args.down}px.png")
    print(f"  [{index}] {time.time() - started:.1f}s -> {stem}.png", flush=True)
    return stem


def main():
    p = argparse.ArgumentParser(description="레퍼런스 이미지를 걸고 생성한다 (로컬 ComfyUI)")
    p.add_argument("prompt", nargs="?", default="",
                   help="--frames 를 안 쓸 때의 한 장짜리 프롬프트")
    p.add_argument("--ref", required=True, help="레퍼런스 이미지 경로")
    p.add_argument("--frames", default="",
                   help="'|' 로 나눈 포즈 프롬프트들. 한 레퍼런스 · 한 씨앗으로 연속 프레임을 뽑는다")
    p.add_argument("--name", default="ref_asset")
    p.add_argument("--preset", default="raw", choices=sorted(PRESETS))
    p.add_argument("--batch", type=int, default=1, help="--frames 가 없을 때 후보 몇 장")
    p.add_argument("--seed", type=int, default=-1)
    p.add_argument("--width", type=int, default=0)
    p.add_argument("--height", type=int, default=0)
    p.add_argument("--down", type=int, default=-1)
    p.add_argument("--steps", type=int, default=0)
    p.add_argument("--cfg", type=float, default=0.0)
    p.add_argument("--lora", type=float, default=-1.0)
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

    prompts = [s.strip() for s in args.frames.split("|") if s.strip()] if args.frames else []
    if not prompts:
        if not args.prompt:
            print("프롬프트나 --frames 중 하나는 있어야 한다.")
            return 2
        prompts = [args.prompt] * args.batch

    try:
        api_get("/system_stats")
    except (urllib.error.URLError, OSError):
        print(f"ComfyUI 서버가 {SERVER} 에 없다. tools/pixel/serve.ps1 을 먼저 돌려라.")
        return 1

    ref_path = Path(args.ref)
    if not ref_path.exists():
        print(f"레퍼런스가 없다: {ref_path}")
        return 1
    ref_name = stage_reference(ref_path)

    base_wf = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    outdir = OUT / args.name
    outdir.mkdir(parents=True, exist_ok=True)

    base_seed = random.randint(0, 2**31 - 1) if args.seed < 0 else args.seed
    print(f"ref={ref_path.name} -> {ref_name}")
    print(f"  preset={args.preset} {args.width}x{args.height} steps={args.steps} "
          f"cfg={args.cfg} seed={base_seed} frames={len(prompts)}")

    # ⚠ **Every frame uses the same seed on purpose.** The reference pins the body; the seed pins
    #  the noise, so the only thing left that moves between frames is the pose the prompt asks for.
    for i, prompt in enumerate(prompts, start=1):
        seed = base_seed if args.frames else base_seed + i - 1
        print(f'  "{prompt}"')
        run_one(base_wf, args, preset, prompt, seed, i, outdir, ref_name)

    print(f"\n=> {outdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
