# Anything the player LOOKS at is MADE, never typed

> ***"UI and things like it — always build them properly rather than in code ... use pixellab or the
> Blender MCP."*** (2026-08-28, the user)

**A HUD, a button, an icon, a panel, a mark on the ground — build it in a tool and load the result.**

| What it is | What makes it |
|---|---|
| Anything with a shape in the world | **Blender** — read `blender.md` in this folder first |
| Anything flat | **`tools/pixel/`** (local ComfyUI), or **pixellab** when the user says so |

⚠⚠ **A BODY IS ALWAYS pixellab, AND `pixellab.md` IN THIS FOLDER IS READ BEFORE THE PROMPT IS
WRITTEN.** Every human frame in the game came from one character there, and a frame pulled from the
local ComfyUI can never be made to match it. **Sixteen candidates were burned on 2026-09-03 writing
prompts against that page's rules without having read them.**

⚠⚠ **`draw_rect` + `draw_string` chrome is not a placeholder, it is the thing that ships.** That is
exactly how the island wore a grey button and a digit nobody chose, until both were deleted.
**If a screen is worth having, it is worth being designed.**

## What this does NOT forbid

A shader, a line the sim needs to prove something, or a throwaway probe.
**The test is whether the PLAYER is meant to look at it.**

## A mesh has a `.blend` in `blend/`, and that file is the original

> ***"You make a model, and with the original file present you use THAT — leaving it as code makes no
> sense."*** (2026-08-31, the user)

**Open it, change it, export from it. Never rebuild a mesh from a script.**
⇒ Before touching any shape, read `blender.md` in this folder. Its constraints are live rules, and one
of them — **a block's corners are not cut at 45°, they are slightly tilted** — was trampled by a round
that skipped the reading.

## Choosing what it looks like

- **`prototype`** builds one thing three or more genuinely different ways, so a METHOD is chosen by seeing
- **`commission`** pulls candidate pictures (시안), so a PICTURE is chosen by seeing
- Both end at a sheet the user looks at, and a remark on that sheet is a question, not a work order
