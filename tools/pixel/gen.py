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
# 🔴🔴 **그런데 프리셋을 여러 개 두면 같은 일이 난다**(2026-08-05 실측).
#  조립창에 **같이 얹히는** 것들을 서로 다른 프리셋으로 뽑고 있었다:
#   · `frame`(진) = concentric rings · `glyph`(문양) = bold simple shapes
#   · `rune`(룬)  = 🔴 **pixel art game icon, 16-bit shading** ← 룬만 픽셀아트였다
#  ⇒ 프롬프트를 아무리 손봐도 안 맞는 게 맞았다. 사용자 판정이 「전혀 원하는 대로 안 나옴」이었다.
#
# 🔴 **한 화면에 같이 나오는 것은 한 프리셋으로 뽑는다** — 진·룬·문양은 전부 `sigil` 이다.
#  ⚠ **시드는 이 축이 아니다.** 시드 6개로 같은 프롬프트를 뽑았더니 구도만 여섯 가지고
#   결은 여섯이 다 같았다 ⇒ 시드는 **구도**를, 프리셋은 **결**을 정한다.
#  세부는 `docs/design/마법진-그림.md` 의 「결을 맞추는 것은 시드다 — 통짜가 아니었다」.
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
    # 🔴🔴 진 통짜 — **세 진(일반·융합·삼각)이 한 벌로 보이게 하는 자리다.**
    #
    # ⚠ `frame` 과 갈라 둔 이유는 하나다: frame 의 style 에 `perfectly round` 가 있어
    #  **삼각진이 원으로 나온다.** 🔴 실루엣을 프리셋이 말하면 진마다 프리셋이 필요해진다 ⇒
    #  **실루엣은 프롬프트가 말하고, 프리셋은 결(선 굵기 · 바탕 · 장식의 성격)만** 든다.
    #
    # ⚠ **`down` 이 0인 것이 일부러다.** 채용안(`docs/mockups/fusion-circle-ref.png`)이
    #  1024 **원본 그대로**고 `_560px` 다운스케일판이 아니다 — 선화라 k_centroid 를 거치면
    #  가는 선이 끊긴다. 🔴 크기의 기준은 `docs/design/마법진-그림.md` 의 **진 1024** 다.
    #
    # ⚠ **`size` 가 1024라 한 장이 512짜리보다 4배 무겁다.** 배치를 크게 걸기 전에 한 장을 재라.
    "sigil": {
        # ⚠ **`thin even line weight` 로 시작했다가 바꿨다**(2026-08-05 실측). 선이 가늘게
        #  나와 채용안과 대비가 안 맞았다. 🔴 그리고 `no border` 를 style 에 안 넣는다 —
        #  negative 로 뺀다(style 에 넣으면 「border」라는 낱말이 그림을 오히려 부른다).
        # 🔴🔴 **프리셋은 결만 든다. 밀도는 프롬프트가 정한다**(2026-08-05, 사용자 판정).
        #  ⚠ 한때 여기 `ornate intricate geometric ornament, bands of repeating diamond and
        #   chevron pattern` 이 들어 있었고, 그러자 **진까지 무늬로 꽉 찼다.**
        #  🔴 진이 화려하면 **문양을 얹을 자리가 없다** — 얹어도 진의 무늬에 묻혀
        #   GDD의 「순서가 화면에 안 보이면 플레이어는 규칙을 영영 못 배운다」가 죽는다.
        #   ⇒ **화려함은 문양이 진다. 진은 빈 띠를 내준다**(`docs/design/마법진-그림.md`).
        #  ⚠ 그러니 이 문자열에 밀도를 말하는 낱말을 다시 넣지 마라 — 프리셋은 진·룬·문양
        #   **셋 다에 걸려서**, 여기 한 낱말이 셋을 동시에 화려하게 만든다.
        # ⚠ **`bold` 는 굵기지 밀도가 아니다.** 밀도 낱말(`ornate` · `repeating pattern`)을 빼면서
        #  `bold` 까지 같이 뺐더니 선이 실처럼 가늘어졌다 — 되살린 것은 굵기 하나뿐이다.
        "style": "bold black line art on a cream white paper background, "
                 "strong contrast, clean confident thick lines, "
                 "flat top-down view, perfectly symmetrical, centered, "
                 "no shading, no gradient, no color, no text",
        "lora": 0.0, "size": 1024, "down": 0, "steps": 28, "cfg": 5.0,
    },
    # 룬 — 🔴 기하학일 필요가 없다(사용자 결정). 속성이 한눈에 읽히는 것이 전부다.
    "rune": {
        "style": "pixel art game icon, bold readable silhouette, centered, "
                 "plain white background, 16-bit shading",
        "lora": 0.0, "size": 512, "down": 96, "steps": 28, "cfg": 5.0,
    },
    # 🔴🔴 탄 머리 — **날아가는 것**. 위 넷과 배경색이 갈리는 유일한 프리셋이다.
    #  ⚠ 문양·룬·진은 **조립창(밝은 종이) 위**에 얹지만 탄은 **어두운 무대 위**를 난다.
    #   흰 배경으로 뽑으면 밝은 코어가 배경과 안 갈려 알파를 뺄 수가 없다 —
    #   sheet.py 주석의 「배경색이 판정을 바꾼다」가 뽑는 단계에도 걸린다.
    #
    # 🔴 **오른쪽으로 나는 모습 하나만 뽑는다.** 탄은 360도로 날아가므로 코드가 돌린다
    #  (`spell_view` 가 속도 벡터를 안다). 방향마다 뽑으면 룬 10개 × 방향 N 이 된다.
    #
    # ⚠ **글로우를 그림에 안 넣는다.** `fx_tuning.BOLT_GLOW_RATIO` 가 이미 무리를 그린다 —
    #  그림에도 넣으면 두 곳이 되고, 세대가 작아질 때 무리만 안 따라 줄어든다.
    #  ⇒ 프롬프트가 요구하는 것은 **코어 실루엣**이다.
    #
    # ⚠ `down` 16 의 근거: `fx_tuning.FX_SIZES.bolt_px` 가 세대0에서 **반경 8px** = 지름 16px.
    #  🔴 이 값을 고치면 그림도 다시 뽑아야 한다 — 축소로 맞추면 픽셀이 깨진다.
    # 🔴🔴 **가산 합성이 이 프리셋의 전부다.** `spell_view._ready()` 가 BLEND_MODE_ADD 다 ⇒
    #  검은 픽셀은 저절로 투명이지만 **어두운 색은 화면에 아예 안 나온다.**
    #  ⇒ 외곽선도 음영도 원리적으로 못 쓴다. 그림이 「덩어리」가 아니라 **「빛」**이라야 한다.
    #  ⚠ 이걸 모르고 뽑은 첫 판(18장)은 전부 음영이 들어가 규격 밖이었다.
    #
    # ⚠ **`centered` 가 없는 것이 일부러다.** 코어가 칸 중심이 아니라 **오른쪽 8px 지점**에 있다 —
    #  회전 피벗이 코어라, 중심에 두면 꼬리 자리가 없고 왼쪽에 두면 머리가 원을 그리며 돈다.
    #  ⇒ 배치는 프롬프트가 말한다.
    #
    # ⚠ `down` 32 · 생성 512×256 (2:1) ⇒ 최종 **32×16**. 근거는 `fx_tuning.FX_SIZES.bolt_px` 8
    #  (반경 8 = 머리 지름 16)이고, 머리만으로 16×16을 꽉 채워 **꼬리 자리가 0이라** 왼쪽을 16px 늘렸다.
    "bolt": {
        "style": "pixel art projectile, only bright glowing hot colors, "
                 "on a pure solid black background, "
                 "no dark outline, no shading, no gradient background, "
                 "no text, no character, no frame, no border",
        "lora": 0.0, "size": 512, "down": 32, "steps": 28, "cfg": 5.0,
    },
    # 🔴🔴 몬스터 — **플레이어와 한 화면에 서는 것.** 위 다섯과 갈라 둔 이유가 그 하나다.
    #  진·룬·문양은 조립창(밝은 종이) 위에 얹고 탄은 빛이지만, 몬스터는 **무대에서 플레이어 옆에 선다.**
    #  ⇒ 맞춰야 할 기준이 「조립창과 어울리나」가 아니라 **「`assets/character/wizard_body.png` 와 같은
    #   세계에 사나」**다. 그 그림을 실제로 재 봤다(2026-08-07):
    #   가장 어두운 색이 **`(79,52,76)` — 순검정이 아니라 어두운 자주색**이고, 색은 35개다.
    #  🔴 style 에 `dark desaturated outline` 을 넣고 `black outline` 을 안 넣는 이유가 이것이다 —
    #   순검정 외곽선은 하늘 `#0e0e13`(합 41) 위에서 **사라져서** 실루엣을 칠이 혼자 지게 된다.
    #
    # ⚠ **`lora` 가 0인 것이 여기서는 다른 이유다.** 위 다섯은 「사람이 나와서」 0인데,
    #  이쪽은 짐승이라 그 걱정이 없다 — 그런데도 0인 것은 4-walk LoRA 가 **4방향 걷기 시트**를
    #  내놓기 때문이다. 🔴 지금 필요한 것은 **정지 한 칸**이고(기획 단계 1~4), 좌우는 코드가 뒤집는다.
    #  ⇒ 걷기 애니메이션을 뽑는 날 이 값을 올려라. **그날은 `down` 도 시트 폭이 된다.**
    #
    # 🔴🔴 **`size` 와 `down` 을 프리셋이 안 든다.** 위 다섯과 다른 점이고, 일부러다 —
    #  몬스터마다 상자가 다르다(`docs/design/몬스터.md`: 돼지 44×32 · 닭 24×28).
    #  ⇒ **부르는 쪽이 `--width/--height/--down` 을 준다.** 비율을 생성 크기에 그대로 맞춰야
    #   `run_one` 의 `dh = down * h / w` 가 기획의 높이를 내놓는다.
    #
    # 🔴🔴 **생성 크기는 목표의 4배다.** 위 프리셋들의 「크게 그리고 내린다」와 정반대이고,
    #  이유가 있다 — 2026-08-07에 같은 프롬프트를 **704×512(16배) · 352×256(8배) · 176×128(4배)**로
    #  뽑아 비교했다. 16배·8배는 **상자를 안 채우고**(44×32 자리에 41×24가 나온다) 형태가 뭉갠다.
    #  **4배만 44×32를 꽉 채웠다.** ⚠ k_centroid 가 블록의 지배색을 고르므로 배율이 클수록
    #  가는 것(다리 · 외곽선)이 통째로 사라진다.
    #  실측: 돼지 `--width 176 --height 128 --down 44` → 44×32. 닭 `--width 96 --height 112 --down 24` → 24×28.
    #  ⚠ 아래 `size` 640 은 그 둘 다 안 맞는 자리표시다. 새 몬스터를 뽑을 때 비율을 다시 계산해라.
    #
    # 🔴🔴 **배경이 크로마 그린인 것이 이 프리셋의 유일한 함정이다.** 흰 배경으로 뽑았더니
    #  **흰 닭의 몸이 통째로 뚫렸다**(실측 2026-08-07) — 테두리에서 번지는 채움이 흰 몸을
    #  배경으로 알고 지나간다. ⚠ 색으로 자르는 것도 같은 이유로 안 된다.
    #  ⇒ **짐승에 없는 색**을 배경으로 쓰고 색상환으로 자른다. 검은 멧돼지와 흰 닭이 둘 다 산다.
    #  ⚠ `bolt` 가 검은 배경인 것과는 다른 문제다 — 저쪽은 가산 합성이라 검정이 저절로 투명이다.
    #
    # ⚠ **외곽선은 포기했다.** style 에 `thick black outline` 을 넣고 cfg 를 7.5까지 올려도
    #  44px 로 내리면 남지 않는다(네 번 다 실측). 🔴 플레이어(`wizard_body.png`)는 가장 어두운 색이
    #  **`(79,52,76)` — 어두운 자주색 외곽선**을 두르고 있어서 **이 프리셋의 결과는 플레이어와 다르다.**
    #  ⇒ 붙여 놓고 티가 나면 그때 여기를 다시 열어라. **모르고 지나가지 말라고 적어 둔다.**
    "monster": {
        "style": "pixel art game sprite of a single animal, side view, full body, "
                 "standing on the ground, facing right, "
                 "bold readable silhouette, flat cel shading, "
                 "muted low-saturation dusty colors, "
                 "on a plain solid bright chroma green background, "
                 "no text, no frame, no border, no shadow",
        "lora": 0.0, "size": 640, "down": 0, "steps": 28, "cfg": 5.0,
    },
    # 🔴🔴 배경 — **무대 뒤. 지금 게임에는 이것을 붙일 자리가 아예 없다**(2026-08-07 조사).
    #  하늘로 보이는 `#0E0E13` 은 배경 레이어가 아니라 **`cell_materials.DEFS[EMPTY].rgb`** 이고,
    #  `cell_renderer` 가 격자 전체를 **불투명하게** 칠한다(`_rgb_to_color` 가 `Color8` 라 알파 255).
    #  ⇒ **CellRenderer 뒤에 무엇을 두든 100% 가린다.** 배경을 넣으려면 셰이더에서 빈칸을
    #   투명으로 빼는 코드 변경이 먼저다. **그림은 그 결정을 기다린다.**
    #
    # ⚠ **`monster` 프리셋을 그대로 쓰면 안 된다.** 저쪽은 「짐승 하나를 상자에 앉힌다」라
    #  `no_background`·`facing right`·크로마 그린이 전부 들어 있다. 여기는 **장면**이다.
    #
    # 🔴 **생성 2배 → 내림.** `monster` 의 4배와도 다르다 — 배경은 가는 것(다리·엄니)이 없어서
    #  배율을 키워도 잃을 것이 없고, 2배면 색이 뭉쳐 픽셀아트 결이 나오면서 형태가 안 무너진다.
    #  ⚠ 한 화면이 **960×540**(`project.godot` 의 viewport)이므로 1920×1088 로 그려 960×544 로 내린다.
    #
    # 🔴 **어두워야 한다.** 무대의 빈칸이 `#0E0E13` 이고 캐릭터·몬스터가 그 위에 선다 —
    #  배경이 밝으면 **실루엣이 전부 죽는다.** style 이 밤 팔레트를 부르는 이유가 그것이다.
    #
    # ⚠ **가로로 반복되는 타일이 아니다.** FLUX 는 이음매를 안 맞춰 준다 ⇒ 방향이 정해지면
    #  **좌우 대칭 복사로 이음매를 없애거나** 층을 갈라야 한다. 지금은 **한 화면 통짜**로 방향만 고른다.
    "backdrop": {
        "style": "pixel art side-scroller game background, distant scenery only, "
                 "dark night palette, muted low-saturation dusty colors, "
                 "simple flat shapes with a clear horizon line, "
                 "no characters, no animals, no text, no frame, no border, no ui",
        "lora": 0.0, "size": 1920, "down": 960, "steps": 28, "cfg": 5.0,
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
