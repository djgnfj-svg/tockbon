Type: task
Status: open

# 손에 있는 늑대 그림이 게임에 안 붙어 있다

## What is on disk, and what the game actually reads

| Files | Read by the game |
|---|---|
| `wolf_h/{north,south,east,west}.png` — 92x92, four facings, **no frames** | ✅ the deck riders |
| `wolf_h/{north,south,east,west}_n.png` — normal maps, baked 2026-08-30, **free** | ⛔ **nothing** |
| `wolf_walk_{0..3}_{l,r}.png` and `wolf_bite_{0..3}_{l,r}.png` — **16 frames** | ⛔ **nothing** |
| `wolf_{l,r}.png` — the old two-facing still | ⛔ **nothing** |

⚠⚠ **No beast walks in this game yet**, so none of it has anywhere to go — the enemy column was deleted
2026-08-29 and ticket 41 rebuilds it. **This ticket is what happens the moment a beast exists.**

## ⚠ The two sets cannot be mixed as they stand

**`wolf_h` is 92x92 with the animal filling 22–73% of the frame. The walking set is a different canvas
with no empty rows.** Mixing canvases makes a body jump and float — measured 2026-08-25, and measured
again 2026-08-30 when the deck wolves floated **0.161 조각, by a different amount per picture**, so the
whole deck rose and fell as the boat turned.
⇒ **Whichever set survives, every frame in it shares one canvas and one foot line.**

## ⚠ The normal maps may not be worth wiring, and that is a measurement

- Head-on wolf on screen: **5 px wide.** Side-on: **17 px.** **A normal map is a gradient across a shape,
  and 5 px has nowhere to put one.**
- Three things in the drawing code block it anyway: riders are `shaded = false`; `modulate` arrives as an
  already-finished colour; and the sprite is a FULL billboard, so **turning the board makes the sun appear
  to orbit the wolf** — the exact defect `tree.gdshader` guards against with a Y-lock and a rewritten
  normal matrix.
- **Wiring means a rider-only sprite pool with a `ShaderMaterial` override.** The shared pool would need
  the override cleared on reuse, and one day that gets missed.

## Not this ticket

**Which set wins, and whether the swordsman is re-drawn.** Those are the user's — ticket 51.

---

## ⚠⚠ 2026-08-30 에 이 티켓의 절반이 뜻을 잃었다

**판 위의 늑대가 H (92x92) 로 바뀌었다.** 손에 있는 **걷기·물기 46 장은 옛 늑대 74x40** 이라
**이제 붙일 수 있는 몸이 없다.** 붙이면 몸이 뜬다.

⇒ **남은 절반은 노멀맵뿐이다.** 애니메이션은 **티켓 58** 로 넘어갔고, 거기서 H 규격으로 다시 뽑는다.
