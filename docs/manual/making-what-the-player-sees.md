# Anything the player LOOKS at is MADE, never typed

> ***"UI and things like it — always build them properly rather than in code ... use pixellab or the
> Blender MCP."*** (the user)

**A HUD, a button, an icon, a panel, a mark on the ground — build it in a tool and load the result.**

| What it is | What makes it |
|---|---|
| Anything with a shape in the world | **Blender** — read `blender.md` in this folder first |
| Anything flat | **`tools/pixel/`** (local ComfyUI), or **pixellab** when the user says so |

⚠⚠ **`draw_rect` + `draw_string` chrome is not a placeholder, it is the thing that ships.** That is
exactly how the island wore a grey button and a digit nobody chose, until both were deleted.
**If a screen is worth having, it is worth being designed.**

## What this does NOT forbid

A shader, a line the sim needs to prove something, or a throwaway probe.
**The test is whether the PLAYER is meant to look at it.**

## A mesh has a `.blend` in `blend/`, and that file is the original

> ***"You make a model, and with the original file present you use THAT — leaving it as code makes no
> sense."*** (the user)

**Open it, change it, export from it. Never rebuild a mesh from a script.**
⇒ Before touching any shape, read `blender.md` in this folder. Its constraints are live rules, and one
of them — **a block's corners are not cut at 45°, they are slightly tilted** — was trampled by a round
that skipped the reading.

## Choosing what it looks like

- **`prototype`** builds one thing three or more genuinely different ways, so a METHOD is chosen by seeing
- **`commission`** pulls candidate pictures (시안), so a PICTURE is chosen by seeing
- Both end at a sheet the user looks at, and a remark on that sheet is a question, not a work order

## A pixel font has to be imported with every smoothing off

**Godot's default import blurs a pixel font.** The Hangul font in this repo is **Galmuri14 (OFL 1.1),
native 15 px**, and it is imported with `antialiasing=0` · `hinting=0` · `subpixel_positioning=0` ·
`multichannel_signed_distance_field=false` · **`oversampling=0.0`** — that last field is the one that
decides pixel-font blur under a `canvas_items` stretch, and there is no 「filter」 field on a dynamic font.

⚠⚠ **Do not copy another font's `.import` file.** The digits font in `assets/` carries antialiasing 1 ·
hinting 3 · subpixel 4 — copying it ships blurred Hangul. **Type the numbers.**
⚠ **`draw_string`'s default size is 16.** Omit the size and Galmuri leaves its own grid.
