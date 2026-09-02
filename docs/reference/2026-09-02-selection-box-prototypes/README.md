# 2026-09-02 — the drag-selection box, five ways

**The question**: the box the hand pulls with the left button to pick several 검사 at once — is it drawn
on the glass (a screen rectangle that does not turn with the board) or laid on the ground (it sits on the
terrain and turns with it)?

**Where it came from** (the user, 2026-09-02): 「이건 프로토 타입 가자」 — *"Let us go prototype on this
one."* Then: 「아 땅에 깔리는 거랑 그냥 사각형이랑 둘다 해야할듯? 그렇게 프로토타입으로 보는거지 해보면서」
— *"Ah — the one laid on the ground and the plain rectangle both have to be tried, I think? That is what a
prototype is for — you see it by trying."*

**Two sheets.** `sheet.png` — the five candidates across, yaw 0 and yaw 90 down, one fixed drag on the real
island under the game's own camera and sun. `sheet-crops.png` — the same, cropped to the box.

| | Where it is drawn | What it is made of | What it CANNOT do |
|---|---|---|---|
| **01-screen-frame-picture** | screen | the pulled `frame_01` picture, its edges stretched to the rect | turn with the board |
| **02-screen-corners** | screen | the pulled ㄴ corner rotated four times, lines between | turn with the board |
| **03-screen-line** | screen | a code-drawn 1 px mint rectangle — **the StarCraft control** | be a picture; the 2026-08-28 rule forbids it shipping |
| **04-ground-decal** | **ground** | a rectangle projected onto the terrain every 8 px, following its height | stay a rectangle once the camera turns; be a pulled picture — it is geometry |
| **05-ground-quad** | ground | a flat textured quad at ground level; turns with the board, ignores height | climb the 2층 tongue — it sinks into it |

**What the scout found first**: every shipped RTS draws the marquee on the screen and none on the ground
(`../2026-09-02-drag-selection-box-screen-or-ground.md`).

## The judging round — the winner is 04, and the FILL is the subject

**The lab had to be given the real gesture before it could be judged** — the user opened it and it did
nothing they could use: 「드래그를 하면 여러명이 선택이 되어야지... 선택이 안되는데 끌헜을때 어떻게
이동하는데? 드래그하면 거기있는애들이 드래그되고 이동하는 판 뜨고 이동하고 이렇게 되야하는데 전혀안됨」 —
*"If I drag, several should get selected... nothing gets selected, so when I have dragged, how do they
move? Drag → the ones there get dragged → the move 판 lights → move. That is how it should go, and none of
it works at all."* The lab was rewired to drive the game's own pick, reach and order under the drag. **That
is where the right-button order was reversed** (ticket 03-11's Reversed section).

03-12 shipped with `01` as the orchestrator's default. **The user then played the game and chose**:

> 「이게 ㅣㅇㄹ단 4번이 적요ㅕㅇ된게 맞음? 이게 아니였는디」
> *"Is this number 4 applied, for now? This was not it."*
> 「선말고 선택된 부분을 약간 드래그 영역 안쪼 생상이 보여야함」
> *"Not the line — the selected part; the colour should show a little inside the drag area."*

⇒ **04-ground-decal, with the fill made the subject** — the prototype's 0.10 fill read as nothing over
yellow ground; the game ships it at 0.28 (`Look.SELECTION_BOX_FILL_ALPHA`) with a thin outline, laid by
`FieldView.set_box`. **The user chose the one shape no shipped RTS was found to use, by seeing it.**

**What stands afterwards**: 04's folder, the lab (`lab.gd`, `common.gd`, `sheet.py`, `README.md`) and 04's
two shots stay in `.prototypes/selection_box/`; **the four losers are deleted** per the `prototype` skill.
The sixteen pulled candidates in `.candidates/selection_box/` are untouched and none is on screen. The
tickets are **03-12** (the gesture, and the three fixes from the user's play) and **03-13** (the picture).
