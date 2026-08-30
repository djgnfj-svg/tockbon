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
