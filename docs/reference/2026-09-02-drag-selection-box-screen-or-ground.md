# Do shipped RTS games draw the drag-selection box on the screen, or on the ground?

**Every shipped case found draws the marquee as a flat rectangle on the screen. No shipped game was found that projects the marquee itself onto terrain — the games that broke with the screen rectangle deleted it rather than moving it down.**

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **StarCraft II** (Blizzard's own guide) | "Multiple units can be selected by clicking and dragging." Screen rectangle | The pattern everything else copies. Blizzard's text never describes the box's colour or thickness | https://news.blizzard.com/en-us/article/6640645/game-guide-simplified-controls |
| **Company of Heroes 2** (Relic, official Feral manual) | "Click and drag a selection box around the unit." 3D terrain, screen-space box | One drag-select line in the whole manual; no ground projection anywhere in it | https://www.feralinteractive.com/en/manuals/companyofheroes2/latest/linux/ |
| **Total War** (Creative Assembly, Total War Academy) | Left-drag stays on screen: "select multiple units by left-clicking and dragging a box around them". Right-drag is the one that goes to the ground: "If you right-click and drag on the terrain, you can order selected units into more precise positions" | **Split by hand.** Selecting is on screen, the order preview is on the terrain. A freely rotating camera and they still did not move the marquee down | https://academy.totalwar.com/battle-keyboard-and-mouse-controls/ |
| **Supreme Commander** | "Left Click and drag: Select all units in this box" | ⚠ The guide does not say screen or ground — that half is unverified | https://supcom.standardof.net/supreme-commander/controls/selecting-units/ |

## Who did the opposite

- **Halo Wars (Ensemble)** — deleted the rectangle for a **brush swept over the battlefield**: tap A = one unit, double-tap = all of that type, "holding down 'A' would bring up a paint brush, selecting everything that paint brush touches." The reason was the controller, not the camera. https://waywardstrategy.com/2020/03/23/halo-wars-the-ultimate-design-for-console-rts/ · official manual confirms tap / double-tap / hold: https://dlassets-ssl.xboxlive.com/public/content/26afec28-4c68-4af9-b34a-864b7364cfe7/GameManual/f160bf52-1b30-4f1a-a151-4aadccf464d7/en-US/index.html
- **What it cost, in the designer's own words** — Dave Pottinger on the SelectAll button they added when selection would not carry the game: *"I hated it then and still hate it now... It was so easy to use that it became all anyone ever used. It really un-did a lot of the fine work that went into unit differentiation and special abilities."* https://waywardstrategy.com/2015/05/04/lets-talk-rts-user-interface-part-1-interview-with-dave-pottinger/
- **Bad North** — the nearest neighbour to this repo, and it has **no marquee at all**: left-click one unit, Q cycles, 1–4 are hotkeys, right-click moves. Camera rotates with A/D, "quick press does a 90° turn". https://steamcommunity.com/app/688420/discussions/0/2479690531129571465/
- **Deterrence (indie devlog)** — a rotating camera broke the naive box: *"the camera can rotate 360 degrees and tilt 180 degrees making the drag select programming a real drag."* They kept the screen rectangle and fixed the hit-test with world-space area maths instead of drawing on the ground. https://www.gamedeveloper.com/game-platforms/3d-modeling-programming-rts-units-deterrence---video-devlog-4

## What this does not settle

- **No source documents line thickness, fill, or exact colour** for any marquee. Every text source says "a box" and stops. That needs frame-grabs, not documents.
- **Corner brackets (four L-shapes) as a marquee: not found.** Repeated searches turned up none. Brackets show up as per-unit selection indicators, never as the drag box itself. Absence of evidence, not proof of absence.
- **No shipped RTS found with a ground-projected marquee.** The only world-space selection shape found anywhere is Halo Wars' brush, and that was a gamepad decision.
