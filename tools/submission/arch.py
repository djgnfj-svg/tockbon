"""Draws the AI architecture figure that opens `ai-tech.md`.

    python tools/submission/arch.py

Drawn in code rather than generated: an image model cannot render Korean, and an
architecture diagram is exactly the picture where a wrong label is worse than no picture.

Output: `docs/archive/nan2026/img/ai-arch.png`.

**The preliminary round is over and `docs/archive/nan2026/` is sealed** (its README).
Running this overwrites the record of what was submitted. **Re-point the output before
running it for the final round** — the drawing itself is round-agnostic, which is why it is kept.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DST = ROOT / "docs" / "archive" / "nan2026" / "img" / "ai-arch.png"
FONT = ROOT / "assets" / "font" / "NotoSansKR-Regular.otf"

W, H = 1740, 1190
# **Everything below the brainstorming box moved down by this much.** The figure used to run
#  사람 → prompts → spec, which skips the step the whole pipeline actually starts with: the
#  user and `game-planning` talking until a design doc exists. Written as an offset rather
#  than re-typed coordinates so the rest of the layout stays the one that was tuned.
OFF = 150
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

    # **Two arrows, both ways** — this step is a conversation, not a handoff. Everything else
    #  in the figure is one-directional on purpose; this is the only place the user is inside
    #  the loop rather than at its ends.
    arrow((830, 136), (830, 186))
    arrow((890, 186), (890, 136))

    box(420, 190, 1300, 290, "game-planning — 브레인스토밍",
        "사람과 대화하며 기획하고, 합의된 것만 설계 문서로 떨군다 (docs/plans/1.ready/)")

    arrow((860, 290), (860, 336))

    # ── 저장소에 커밋된 프롬프트 ─────────────────────────────────────────
    band(180 + OFF, 340 + OFF, "저장소에 커밋된 프롬프트 — 대화가 아니라 파일이다")
    box(70, 232 + OFF, 570, 330 + OFF, "CLAUDE.md", "모든 세션·모든 에이전트에 자동으로 실린다")
    box(600, 232 + OFF, 1120, 330 + OFF, ".claude/agents/ — 6개", "각 에이전트의 시스템 프롬프트")
    box(1150, 232 + OFF, 1650, 330 + OFF, ".claude/skills/ — 4개", "언제 누구를 부르는지의 절차서")

    arrow((860, 330 + OFF), (860, 390 + OFF))

    # ── 한 기능이 도는 길 ───────────────────────────────────────────────
    # **The title stays short.** Spelled out ("그 설계 문서 하나를 build-feature 가 팀으로 만든다")
    #  it runs under the red note above `builder` — measured, on the first draw.
    band(392 + OFF, 748 + OFF, "한 기능이 도는 길 — build-feature")
    box(70, 494 + OFF, 340, 586 + OFF, "spec", "설계 문서 → 구현 계획")
    box(390, 494 + OFF, 660, 586 + OFF, "builder", "계획대로 구현")
    arrow((340, 540 + OFF), (386, 540 + OFF))

    vx0, vx1 = 720, 1160
    box(vx0, 444 + OFF, vx1, 528 + OFF, "verify-run", "헤드리스로 돌려 값을 잰다")
    box(vx0, 540 + OFF, vx1, 624 + OFF, "verify-look", "게임을 띄워 눈으로 대조한다")
    box(vx0, 636 + OFF, vx1, 720 + OFF, "verify-read", "코드를 반증하고 넷을 부순다")
    for y in (486, 582, 678):
        arrow((660, 540 + OFF), (vx0 - 6, y + OFF))

    box(1230, 494 + OFF, 1650, 586 + OFF, "완료", "셋이 전부 통과해야 한다")
    for y in (486, 582, 678):
        arrow((vx1, y + OFF), (1226, 540 + OFF))

    # 되돌림
    d.line([(1440, 494 + OFF), (1440, 428 + OFF), (525, 428 + OFF), (525, 490 + OFF)],
           fill=ACCENT, width=3)
    arrow((525, 462 + OFF), (525, 492 + OFF), color=ACCENT)
    d.text((980, 398 + OFF), "하나라도 실패하면 builder로 되돌린다 · 3회에서 멈추고 사람에게 간다",
           font=f_note, fill=ACCENT, anchor="ma")

    # ── 에이전트가 손에 쥐는 것 ─────────────────────────────────────────
    band(772 + OFF, 1000 + OFF, "에이전트가 손에 쥐는 것")
    box(70, 846 + OFF, 500, 952 + OFF, "MCP · godot", "에디터와 게임을 직접 조작하고 본다")
    box(530, 846 + OFF, 900, 952 + OFF, "MCP · aseprite", "스프라이트 편집 자동화")
    box(930, 846 + OFF, 1250, 952 + OFF, "MCP · pixellab", "애니메이션 생성")
    box(1280, 846 + OFF, 1650, 952 + OFF, "넷 38개 · 검사 8,485", "24초. 병렬 프로세스")

    im.save(DST)
    print("[arch] %s  %dx%d" % (DST.name, im.width, im.height))


if __name__ == "__main__":
    main()
