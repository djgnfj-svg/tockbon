# pixellab — **how to ask for a frame**, and what this repo measured when it asked wrong

> ***"Go find a prompting guide and put it in, and refer to that document every time you pull images
> from now on."*** (2026-09-03, the user, after sixteen 채집 candidates came back unusable)

**Every body in this game comes from ONE pixellab character** — `tockbon swordsman base`,
`8d06bbf3-c757-44b7-850d-fa7cac72e519`, 40x60, low top-down. ⚠⚠ **A frame pulled anywhere else can
never be made to match it**, because texture comes from the generator, not from the prompt
(`tools/pixel/README.md` measured this over two games). ⇒ **The local ComfyUI is not an option for a
human body.** It is for props, UI and the 3D-render beasts.

**The four facings this game installs** are `south` · `south-east` · `south-west` · `north`, which the
game wears as `down` · `right` · `left` · `up`. ⚠ **The generator's compass words are not the game's** —
`.candidates/README.md` holds the mapping and the trap.

---

## ⚠⚠ THE THREE RULES, AND ALL THREE WERE BROKEN ON 2026-09-03

**These come from pixellab's own guidance** (`api.pixellab.ai/mcp/docs`, and the `agent_help` tool
asked directly). **Every one of them is the opposite of what that round did.**

| The rule | What the failed round did |
|---|---|
| ⚠⚠ **3 to 6 words.** `action_description` is a phrase, not a sentence | **50 to 60 words**, three clauses long, one per beat |
| ⚠⚠ **NEVER name the held object.** *"The model struggles to maintain object consistency. Describe the hand and arm pose instead"* | Named the axe, the pickaxe and the rod **in every prompt** |
| **No environment, no location, no setting** | Named the tree and the ground |

**The words that work are movement words**: `walking stealthily` · `running` · `forceful overhead
swing` · `wide sweeping motion`. **Strong active verbs get a big pose; passive or static phrasing gets
a small one.**

⚠ **This flatly contradicts `tools/pixel/README.md`, and both are right**, because they are different
generators. **That page's "shape words, not action verbs" was measured on FLUX.2 klein driving
3D-render beasts locally.** pixellab wants the verb. ⇒ **Read the page for the generator you are
actually about to use.**

## What this repo measured, 2026-09-03 — **sixteen candidates, one usable**

**The subject was 벌목 · 채집 · 낚시**, and every frame is in `.candidates/swordsman/` under that date.
**Nothing was deleted**; the losers are the evidence.

- **A tool named in the prompt materialises out of nothing in frame 2 or 3.** The reference start
  frame is the empty-handed body, so frames 0-1 have bare hands and the object appears mid-strip
- **A tool named in the prompt then dissolves.** The pickaxe was gone by frame 3 in three of three
  attempts; the axe head detached from its handle
- ⚠⚠ **A BIG ARM MOVEMENT DROPS THE TOOL, EVEN WHEN THE PROMPT NEVER NAMES IT.** `mine_strike` put the
  tool in a character state and described only the body — **and the pickaxe still vanished the moment
  the arms went above the head.** ⇒ The tool survives only while the arms stay near where the
  rotation put them
- ⚠ **When a tool comes out, the body does not move.** Across twelve candidates, every one that drew a
  tool had a static torso; the one that moved properly (`mine_crouch`) had no tool at all

⚠⚠ **THE THREE-WORD RULE WAS THEN MEASURED HEAD TO HEAD, SAME BODY, SAME FACING, SAME DAY.**
Both asked the 곡괭이 body for one overhead swing:

| Prompt | Frames the tool survived |
|---|---|
| `forceful overhead swing` — **3 words** | **8 of 8**, and it drew rubble on the ground unasked |
| the 50-word three-beat version | **1 of 8** — dropped at frame 2, bare-handed after |

⚠ **Neither is usable yet**: the short one keeps a bare handle and loses the metal head, and the
swing stays small. **But the length rule is no longer a claim from a doc; it is measured here.**

**The one that worked is `fish_wait`**: the body plants, the feet never move, and the long pole sweeps
a clean arc. ⇒ **What this generator will give is a planted body with a moving tool**, and asking for
the opposite has failed sixteen times.

## ⇒ A held tool is a CHARACTER STATE, never a word in the animation prompt

**`create_character_state` puts the tool in the hand across all eight rotations, consistently, once.**
Then the animation prompt is free to be three words about the body.

**Three states were built this way on 2026-09-03 and all three read clearly** — they are the part of
that round that worked:

| State | id | The words that built it |
|---|---|---|
| **Axe** | `901c5852-44e8-48f5-932c-1a162a471ae4` | `standing and holding a woodcutting axe in both hands, the wooden handle gripped in front of the body and the metal axe head resting down near the ground` |
| **Pickaxe** | `da00817c-d4e2-4b7a-a9f8-1f43f6c3a2a2` | `standing and holding a pickaxe in both hands, the wooden handle gripped in front of the body and the pointed metal head resting down near the ground` |
| **Fishing rod** | `582b1e39-f546-45ab-aae9-0c208b15b479` | `standing and holding a long fishing rod in both hands, the rod a thick wooden pole pointing forward and upward away from the body` |

- **`override_width` / `override_height` 72 x 72**, up from the body's 40 x 60. ⚠ **Without the
  override the tool is clipped by the body's own tight canvas.**
- **20-40 generations per state**, resolved from the canvas at generation time — a call can charge
  more than it reserved. **Leave 40 of headroom.**
- ⚠ **The `north` facing loses a long tool.** The fishing rod is a stub from behind. Undecided whether
  that matters.
- ⚠ **`use_color_palette_from_reference` was left OFF on purpose**, so the handles came out warm brown
  against a body that is one flat grey. **That is why the tools read at 40 px.** Turning it on would
  sink them into the body.

## The prompts already in the game, and they are the bar

**`.candidates/swordsman/README.md` holds every one**, with what won and what lost.
⚠⚠ **The attack's phrasing is the one long shape measured to produce a real wind-up on this
skeleton** — it names three beats, first / middle / last:

> `winding up and then striking: in the first frames the arm and the shoulder are pulled back and away
> from the target and the body leans back, in the middle frames the fist drives forward as far as it
> will reach and the body leans into it, in the last frames the body settles back to standing`

⚠ **That is 50 words and it worked**, against the 3-to-6-word rule above — **and it names no object,
and the hand is empty.** ⇒ **Long is survivable on a bare body; a tool in the hand is not.**

## Cost, and the ladder to climb when a pull is bad

**Check `get_balance` before a big round.** The plan refills monthly.

1. **template** — a named skeleton (`walking-4-frames`, `cross-punch`). **1 generation per direction.**
   ⚠ **Measured dead here**: the walk template came back at 27-68% of the standing pose's silhouette,
   differing per facing, with the head at half size
2. **v3** — custom, from `action_description`. **~1 generation per direction at this body's size.**
   The default, and what everything shipped so far used
3. **pro** — sequential, using finished sides as reference. **20-40 generations PER DIRECTION.**
   ⚠⚠ **Requires `confirm_cost`, and the tool forbids setting it without the user saying yes first.**
   `frame_count` is ignored; the canvas fixes it

## How a pull is actually run

- ⚠⚠ **ONE BATCH, THEN STOP AND SHOW IT.** The 2026-09-03 round ran four rounds off its own diagnosis
  before the user saw a second board, and the answer was 「너무 막뽑는디」 (*"you are just pulling at
  random"*). **Generations are cheap; the judgement between them is the whole point of a 시안.**
- **`directions=["south"]` first.** The other three facings go onto a candidate that has already won.
  ⚠ **Building four facings before that multiplies every loser by four.**
- **`keep_first_frame=false`**, so `frame_count` frames are stored rather than `frame_count + 1`
- **`animation_group_id`** adds a facing to an existing group. ⚠ **Pass `animation_name` again** — it is
  not inherited, and leaving it off makes the group look renamed
- **Downloading**: `https://api.pixellab.ai/mcp/characters/<id>/download` returns a zip of **the whole
  state group**, and answers **423 with an ETA** while anything is still generating. ⇒ **It is the
  cleanest way to poll**, and far smaller than `get_character`, whose output is truncated by its own
  size once a character carries more than a few animations
- **Frames land as `<state>/animations/<name>/<facing>/frame_000.png`**

---

## Sources

- [PixelLab MCP Tools — AI Assistant Guide](https://api.pixellab.ai/mcp/docs)
- [PixelLab — Animation](https://www.pixellab.ai/docs/tools/animation)
- [PixelLab — Animate with text (Pro)](https://www.pixellab.ai/docs/tools/animate-with-text-pro)
- [PixelLab — Character options](https://www.pixellab.ai/docs/options/character)
- The `agent_help` tool on the pixellab MCP server, asked 2026-09-03 about held objects dissolving
