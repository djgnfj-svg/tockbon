---
name: commission
description: Pull candidate pictures — 시안 — and put them in front of the user until one is chosen: pinned down in conversation, pulled locally, pulled on pixellab, then stood up IN THE GAME. Use when the user says 시안 / 시안 뽑아줘 / 시안 뽑아서 보자 / 그림 뽑아줘 / 캐릭터 뽑아줘, or when anything the player will look at is about to be drawn.
---

# commission — 시안, and the user picks by seeing

**A 시안 is a candidate picture pulled so the user decides by LOOKING.** Talking about a look does not
settle it — this repo measured that on the water, on the stair and on the shoreline.

⚠⚠ **Ticket 49 is the record that this skill did not exist.** This is it.

## The five stages, and they run in this order

**Each one ends with pictures in front of the user.** ⚠ **Never skip ahead** — a batch pulled against a
question nobody pinned down costs a round and teaches nothing.

## 1. 구체화 — **pin down what is being pulled, and that is all**

**One line: what picture, for what, at what size.** ⚠ **This is a sentence, not an interview** — asking a
table of questions here is what the user cut on 2026-08-30 (*"the five questions are a bit odd"*).

**Ask only what is genuinely missing from that one line.** The rest you find yourself: the pixel height
it will be drawn at, what it stands beside, and which of this game's styles it joins are all readable in
`src/look.gd` and `assets/`.

⚠⚠ **READ `docs/manual/pixellab.md` BEFORE WRITING A PROMPT, EVERY TIME** (2026-09-03, the user:
***"Go find a prompting guide and put it in, and refer to that document every time you pull images
from now on."***). It holds **the three rules that page measured being broken** — 3 to 6 words, never
name the held object, no environment — and **why a tool goes in a character STATE and never in the
animation prompt.** ⚠ **Sixteen candidates were burned in one round writing against those rules.**

⚠⚠ **READ `.candidates/README.md` BEFORE WRITING A PROMPT.** It holds **the four views every body in
this game is pulled in** — 정면우 · 정면좌 · 후면우 · 후면좌, four DIAGONALS and no side view — with the
exact phrase for each and the trap that flips them (the animal's own left is the screen's right).
**Guessing the views instead of reading them is how a set comes back as two pairs of the same picture.**

⚠ **No folder exists until that line does.**

## 2. Pull locally, and show them

**The local ComfyUI is `CompyUI_2DPixel`**, on this PC's GPU, and every beast in this game came from it.
**It costs nothing.**

**`tools/pixel/README.md` is the single source of truth for the pipeline** — presets, the chroma green
ground, generating at 4x, the colour cast and `--desat`, silhouette words instead of action verbs, the
onion-skin check. **Follow it. Do not restate it here and do not invent a phrase.**

## 3. Pull on pixellab, and show them

**Say what it costs before it runs.** ⚠ **Local's one measured limit is a big pose change** — across 22
candidates the model gave *the same body with its mouth open* every time and refused *the body leaves
the ground*. **That is what the paid pull buys.**

## 4. ⚠⚠ Stand the shortlist up IN THE GAME

**This is where it is decided, and a contact sheet is not it.** **Put the candidates into the real
screen, at the real size, on the real ground, beside the real neighbours** — then photograph that.

⚠ **A 512px render that reads beautifully is routinely mush at the size it actually ships at.**
**`prototype` is the skill that builds a board of several and photographs them from one camera** — use its
shape here rather than inventing another.

**Judging: a remark on that screen is a QUESTION, not a work order.** The user writes in fragments —
「둥글게」, 「좀 더 정교하게」, 「이거 말고」. **Collect them, put them back as questions, and change
nothing until they are answered.** ⚠ **Measured 2026-08-29**: four fragments became four edits and the
third contradicted the first. **Then change ONE thing and pull again.**

## 5. Add the facings and the animation — **to the winner only**

**Four facings, walk, attack, flinch — whatever the thing needs — are built once one picture has won.**
⚠ **Building them before that multiplies every loser by the number of frames.**

**The chosen files go to `assets/`; the losers are deleted.** ⚠ **A candidate left in the tree becomes a
file nobody dares remove.**

## Where it lands

**The choice becomes a line in the ticket that asked for it, and the prompt that produced the winner goes
with it** — **a phrase nobody wrote down is a style that cannot be matched next time.**
⚠⚠ **Only `wrap-up` writes it.**
