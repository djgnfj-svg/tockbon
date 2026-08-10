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

W, H = 1720, 1000
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

    def box(x0, y0, x1, y1, title, sub=None, edge=EDGE, width=2):
        d.rounded_rectangle([x0, y0, x1, y1], 10, fill=BOX, outline=edge, width=width)
        cx = (x0 + x1) / 2
        if sub:
            d.text((cx, y0 + (y1 - y0) / 2 - 24), title, font=f_box, fill=INK, anchor="ma")
            d.text((cx, y0 + (y1 - y0) / 2 + 12), sub, font=f_sub, fill=DIM, anchor="ma")
        else:
            d.text((cx, (y0 + y1) / 2), title, font=f_box, fill=INK, anchor="mm")

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
    box(600, 40, 1120, 128, "사람", "설계를 결정하고, 재미를 판정한다")

    arrow((860, 128), (860, 178))

    # ── 저장소에 커밋된 프롬프트 ─────────────────────────────────────────
    band(180, 340, "저장소에 커밋된 프롬프트 — 대화가 아니라 파일이다")
    box(90, 236, 570, 322, "CLAUDE.md", "모든 세션·모든 에이전트에 자동으로 실린다")
    box(600, 236, 1120, 322, ".claude/agents/ — 6개", "각 에이전트의 시스템 프롬프트")
    box(1150, 236, 1630, 322, ".claude/skills/ — 4개", "언제 누구를 부르는지의 절차서")

    arrow((860, 340), (860, 396))

    # ── 한 기능이 도는 길 ───────────────────────────────────────────────
    band(398, 700, "한 기능이 도는 길")
    box(90, 500, 330, 580, "spec", "설계 → 계획")
    box(390, 500, 630, 580, "builder", "계획대로 구현")
    arrow((330, 540), (386, 540))

    vx0, vx1 = 700, 1120
    box(vx0, 452, vx1, 522, "verify-run", "헤드리스로 돌려 값을 잰다")
    box(vx0, 540, vx1, 610, "verify-look", "게임을 띄워 눈으로 대조한다")
    box(vx0, 628, vx1, 698, "verify-read", "코드를 반증하고 넷을 부순다")
    for y in (487, 575, 663):
        arrow((630, 540), (vx0 - 6, y))

    box(1200, 500, 1630, 580, "완료", "셋이 전부 통과해야 한다")
    for y in (487, 575, 663):
        arrow((vx1, y), (1196, 540))

    # 되돌림
    d.line([(1415, 500), (1415, 430), (510, 430), (510, 496)], fill=ACCENT, width=3)
    arrow((510, 470), (510, 498), color=ACCENT)
    d.text((960, 400), "하나라도 실패하면 builder로 되돌린다 · 3회에서 멈추고 사람에게 간다",
           font=f_note, fill=ACCENT, anchor="ma")

    # ── 에이전트가 손에 쥐는 것 ─────────────────────────────────────────
    band(722, 960, "에이전트가 손에 쥐는 것")
    box(90, 800, 500, 900, "MCP · godot", "에디터와 게임을 직접 조작하고 본다")
    box(530, 800, 870, 900, "MCP · aseprite", "스프라이트 편집 자동화")
    box(900, 800, 1240, 900, "MCP · pixellab", "애니메이션 생성")
    box(1270, 800, 1630, 900, "넷 35개 · 검사 8,423", "30초. 병렬 프로세스")

    im.save(DST)
    print("[arch] %s  %dx%d" % (DST.name, im.width, im.height))


if __name__ == "__main__":
    main()
