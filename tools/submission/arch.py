"""Draws the AI architecture figure that opens `ai-tech.md`.

    python tools/submission/arch.py

Drawn in code rather than generated: an image model cannot render Korean, and an
architecture diagram is exactly the picture where a wrong label is worse than no picture.

Output: `docs/submission/img/ai-arch.png`.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DST = ROOT / "docs" / "submission" / "img" / "ai-arch.png"
FONT = ROOT / "assets" / "font" / "NotoSansKR-Regular.otf"

W, H = 1740, 1040
BG = (250, 250, 251)
BAND = (241, 244, 248)
BAND_EDGE = (219, 224, 232)
BOX = (255, 255, 255)
EDGE = (150, 158, 170)
INK = (24, 27, 33)
DIM = (96, 104, 116)
ARROW = (120, 128, 140)
ACCENT = (196, 64, 48)


def main() -> None:
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    f_band = ImageFont.truetype(str(FONT), 25)
    f_box = ImageFont.truetype(str(FONT), 30)
    f_sub = ImageFont.truetype(str(FONT), 22)
    f_note = ImageFont.truetype(str(FONT), 22)

    def band(y0, y1, title):
        d.rounded_rectangle([40, y0, W - 40, y1], 14, fill=BAND, outline=BAND_EDGE, width=2)
        d.text((62, y0 + 16), title, font=f_band, fill=DIM)

    # **Every string is measured against its box before it is drawn.** Hand-picked sizes
    #  overflowed in three boxes at once, and an architecture figure with a label running
    #  past its own frame reads as carelessness about the thing it is describing.
    def fit(text, max_w, base):
        size = base
        while size > 13:
            f = ImageFont.truetype(str(FONT), size)
            if d.textlength(text, font=f) <= max_w:
                return f
            size -= 1
        return ImageFont.truetype(str(FONT), 13)

    PAD = 28

    def box(x0, y0, x1, y1, title, sub=None, edge=EDGE, width=2):
        d.rounded_rectangle([x0, y0, x1, y1], 10, fill=BOX, outline=edge, width=width)
        cx = (x0 + x1) / 2
        inner = (x1 - x0) - PAD * 2
        if sub:
            d.text((cx, y0 + (y1 - y0) / 2 - 26), title,
                   font=fit(title, inner, 30), fill=INK, anchor="ma")
            d.text((cx, y0 + (y1 - y0) / 2 + 12), sub,
                   font=fit(sub, inner, 22), fill=DIM, anchor="ma")
        else:
            d.text((cx, (y0 + y1) / 2), title,
                   font=fit(title, inner, 30), fill=INK, anchor="mm")

    def arrow(p0, p1, color=ARROW, width=3, head=13):
        d.line([p0, p1], fill=color, width=width)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        n = max((dx * dx + dy * dy) ** 0.5, 1e-6)
        ux, uy = dx / n, dy / n
        px, py = -uy, ux
        d.polygon([p1,
                   (p1[0] - ux * head + px * head * 0.55, p1[1] - uy * head + py * head * 0.55),
                   (p1[0] - ux * head - px * head * 0.55, p1[1] - uy * head - py * head * 0.55)],
                  fill=color)

    # ── 사람 ────────────────────────────────────────────────────────────
    box(560, 36, 1160, 136, "사람", "설계를 결정하고, 재미를 판정한다")

    arrow((860, 136), (860, 182))

    # ── 저장소에 커밋된 프롬프트 ─────────────────────────────────────────
    band(180, 340, "저장소에 커밋된 프롬프트 — 대화가 아니라 파일이다")
    box(70, 232, 570, 330, "CLAUDE.md", "모든 세션·모든 에이전트에 자동으로 실린다")
    box(600, 232, 1120, 330, ".claude/agents/ — 6개", "각 에이전트의 시스템 프롬프트")
    box(1150, 232, 1650, 330, ".claude/skills/ — 4개", "언제 누구를 부르는지의 절차서")

    arrow((860, 330), (860, 390))

    # ── 한 기능이 도는 길 ───────────────────────────────────────────────
    band(392, 748, "한 기능이 도는 길")
    box(70, 494, 340, 586, "spec", "설계 → 계획")
    box(390, 494, 660, 586, "builder", "계획대로 구현")
    arrow((340, 540), (386, 540))

    vx0, vx1 = 720, 1160
    box(vx0, 444, vx1, 528, "verify-run", "헤드리스로 돌려 값을 잰다")
    box(vx0, 540, vx1, 624, "verify-look", "게임을 띄워 눈으로 대조한다")
    box(vx0, 636, vx1, 720, "verify-read", "코드를 반증하고 넷을 부순다")
    for y in (486, 582, 678):
        arrow((660, 540), (vx0 - 6, y))

    box(1230, 494, 1650, 586, "완료", "셋이 전부 통과해야 한다")
    for y in (486, 582, 678):
        arrow((vx1, y), (1226, 540))

    # 되돌림
    d.line([(1440, 494), (1440, 428), (525, 428), (525, 490)], fill=ACCENT, width=3)
    arrow((525, 462), (525, 492), color=ACCENT)
    d.text((980, 398), "하나라도 실패하면 builder로 되돌린다 · 3회에서 멈추고 사람에게 간다",
           font=f_note, fill=ACCENT, anchor="ma")

    # ── 에이전트가 손에 쥐는 것 ─────────────────────────────────────────
    band(772, 1000, "에이전트가 손에 쥐는 것")
    box(70, 846, 500, 952, "MCP · godot", "에디터와 게임을 직접 조작하고 본다")
    box(530, 846, 900, 952, "MCP · aseprite", "스프라이트 편집 자동화")
    box(930, 846, 1250, 952, "MCP · pixellab", "애니메이션 생성")
    box(1280, 846, 1650, 952, "넷 35개 · 검사 8,423", "30초. 병렬 프로세스")

    im.save(DST)
    print("[arch] %s  %dx%d" % (DST.name, im.width, im.height))


if __name__ == "__main__":
    main()
