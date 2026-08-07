# 배경 후보 위에 **실제 게임 색**의 지형과 스프라이트를 얹는다.
#
# 🔴 배경만 보면 판정이 거짓이 된다 — 이 게임의 배경은 「보는 그림」이 아니라
#  **캐릭터·몬스터·불이 그 위에 서는 바닥**이다. 대비가 죽으면 실루엣이 죽는다.
#  ⚠ 색은 전부 `src/sim/cell_materials.gd` 의 `DEFS.rgb` 에서 그대로 가져왔다.
import sys, glob, os
from PIL import Image, ImageDraw

STONE = (0x5C, 0x57, 0x4F)
WOOD = (0x6B, 0x45, 0x24)
BEDROCK = (0x23, 0x22, 0x28)
EMPTY = (0x0E, 0x0E, 0x13)
TXT = (220, 215, 210)

W, H = 960, 540
CELL = 4                       # sim_tuning.CELL_PX

# 🔴 스프라이트는 **리포의 `assets/`** 에서 읽는다. 한 번 스크래치패드를 가리켰다가
#  다음 세션에 그 폴더가 사라져 목업을 못 만들 뻔했다.
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "pixel", "out", "_bgmock")


def terrain(im):
    """대충의 지형 한 조각. 셀 4px 격자에 맞춰 그린다."""
    d = ImageDraw.Draw(im)
    ground = 400
    d.rectangle([0, ground, W, H], fill=WOOD)                 # 흙
    d.rectangle([0, ground + 60, W, H], fill=BEDROCK)         # 기반암
    d.rectangle([120, ground - 48, 300, ground], fill=STONE)  # 돌 기둥
    d.rectangle([640, ground - 96, 700, ground], fill=STONE)
    d.rectangle([700, ground - 32, 900, ground], fill=WOOD)
    # 구덩이 — 플레이어가 판 자리
    d.rectangle([400, ground, 500, ground + 60], fill=EMPTY)
    return ground


def mock(bg_path, out, label):
    bg = Image.open(bg_path).convert("RGBA").resize((W, H), Image.NEAREST)
    im = Image.new("RGBA", (W, H), EMPTY)
    im.alpha_composite(bg)
    g = terrain(im)
    for p, x in [("character/wizard_body.png", 240), ("monster/pig_body.png", 470),
                 ("monster/chicken_body.png", 740)]:
        s = Image.open(os.path.join(ROOT, "assets", p)).convert("RGBA")
        im.alpha_composite(s, (x, g - s.height))
    d = ImageDraw.Draw(im)
    d.text((6, 4), label, fill=TXT)
    im.save(out)
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for folder in ("bgA_sky", "bgB_farm", "bgC_forest", "bgD_moon"):
        fs = sorted(glob.glob(os.path.join(ROOT, "tools", "pixel", "out", folder, "*960px.png")))
        for i, f in enumerate(fs):
            rows.append(mock(f, f"{OUT}/bgmock_{folder}_{i}.png", f"{folder}  #{i}"))
    cols = 2
    n = len(rows)
    sheet = Image.new("RGBA", (cols * (W + 8) + 8, ((n + cols - 1) // cols) * (H + 8) + 8), (0, 0, 0, 255))
    for i, r in enumerate(rows):
        sheet.alpha_composite(r, (8 + (i % cols) * (W + 8), 8 + (i // cols) * (H + 8)))
    sheet.save(f"{OUT}/bg_compare.png")
    print("bg_compare.png", sheet.size, n, OUT)
