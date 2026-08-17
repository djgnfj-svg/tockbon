# What survived two dead games

**This is a distillation of two deleted games.** The originals are intact at the tags `v1-sim` (side-view
magic action plus a pixel water/fire simulation, deleted 2026-08-12) and `v2-openfield` (an open-field cell
game, deleted 2026-08-16).

⚠ **Nothing here is a spec.** Not a rule, not a constant, not a design. Only **numbers that were actually
measured** and **failures whose shape can be repeated** are kept. Something earns a place here only if it is
still true for a game that does not exist yet.

---

## 1. The measured numbers

### 1-1. "It isn't fun" became a number

**Turning a design complaint into an instrument is the most expensive move this repo learned.**

- The user's *"I can't make any progress at all, I can't catch anything"* → a bot that played a whole run
  headless (`probe_run.gd`) measured **83% of the run with nothing killable on screen, and a longest gap
  between kills of 150 seconds**
- After the level curve was rewritten and four new small species were added, dead air was still **61%**
  against a bar of **25%**. **It failed every time it was measured** — and that is why the open field was
  abandoned rather than tuned
- **The opening screen held zero creatures, and not by chance — by construction.** The no-spawn radius of
  900px was larger than the opening camera's half-diagonal (**459px**). Every seed, forever
- Grazing beat hunting **2 to 1**: grass paid ~6 per second at zero risk, a crow paid ~3 per second and
  could kill you. ⇒ The optimal play became "split, scatter, vacuum grass"
- **The instrument itself was wrong twice, in its owner's favour.** It modelled one-shot kills as
  `force >= hp` after a damage cap had made that false, and it never read "fleeing species never attack".
  The honest figure after the fix was **58%**, not 48%

### 1-2. What actually reaches the screen — **the same mistake four times**

**A 1280×720 viewport is stretched into a 1920×1080 window (1.5×), and the camera zoom multiplies on top of
that.** Read a constant, say "N px", and both factors are missing.

| Where | What the doc said | The truth |
|---|---|---|
| A clone's size | radius constant 8, quoted as "8px" | **38px on screen, diameter** (19px once the swarm passed 30) — **4.8× off** |
| Half-diagonal of the fully pulled-back camera | 1377px | **918px** (`hypot(800, 450)`) |
| Guaranteed radius of the opening camera | 700px | **459px** (`hypot(400, 225)`) |
| The probe's own screen constant | 1920×1080 | **800×450 world pixels** — **5.76× too large in area** |

**What came out of it was not a value, it was dead air.** Trusting 1377 set the spawn distance to 1450, 1.6×
further than needed, and the whole difference showed up as time spent walking to the next creature. Two
bodies placed on the strength of 700 landed on camera in **0 of 60 seeds** — and one of them was **the only
body in the opening that could open the card pool.**

⇒ **A constant is not the screen. Count every multiplier between them, or take a screenshot.**

### 1-3. The engine was never the wall (Godot 4.7.1, all measured)

- **300 `Node2D`s cost 0.065ms.** 300 `CharacterBody2D`s cost the same as 60
- Uniform grid: 300 items **0.42ms** against a naive 3.01ms · 600 items **1.03ms** against 12.19ms
- ⇒ **The reason to use flat arrays is correctness, not frame budget.** With `carried[i]` in a packed array,
  "a body that dies far from home loses its cargo" is **structurally true** — no code has to remember it
- **The cap on how many bodies is set by legibility, never by performance**

### 1-4. Where the engine lies quietly (all measured on 4.7.1)

- **`--headless --script` does NOT re-import.** A brand-new `class_name` file is invisible and dies with a
  `Parse Error`; one `--import` pass fixes it (reproduced three times)
- **`--headless` cannot hand back pixels.** No swapchain, so `get_texture()` comes back blank and every PNG
  is a black rectangle **with no error anywhere.** Frames really turn and `_draw()` really runs — pixels are
  the only thing it cannot do
- **Headless frame pacing is pinned at 6.900ms regardless of load** ⇒ timing anything with `pump_frames`
  measures nothing. Performance needs a synchronous loop
- **`const X := PackedInt32Array([1,2,3])` is a parse error** (*"Assigned value for constant isn't a constant
  expression"*). A plain `const` array is fine, nests fine, and folds `deg_to_rad()` inside it — but element
  typing is lost, so every read casts
- **`array[-1]` is not an error, it is the last element** — an empty slot silently borrows someone's name
- **`set_anchors_preset` sets anchors and leaves the offsets alone** ⇒ a `Control`'s `size` stays (0,0), and
  everything laid out from `size` piles into the top-left corner, fully wired and fully `visible`
- **Godot refuses to override `draw_string` / `draw_rect`** — it is a parse error
- **An unregistered InputMap action does not fail quietly** — it barks to stderr every frame
- **`Engine.time_scale = 0` does not freeze the simulation.** Code that corrects per frame keeps correcting
  whatever the delta is
- **`_physics_process` fired 12 times across 30 process frames** (headless), and **`Input.get_vector`
  normalises** — right+up is `(0.707, -0.707)`
- **`scale_mode="integer"` floored a 1.5× scale to 1×** — the game filled **44%** of the window
- Writing `rendering/environment/...` *inside* `project.godot`'s `[rendering]` section makes the real key
  `rendering/rendering/environment/...`. The background colour was read in **zero** places

---

## 2. Failures whose shape repeats

### 2-1. **An advantage with no cost is not a decision, and a mechanic that is not a decision is not fun** ★

**This is the one sentence that killed the second game.** The user's complaint was *"the clones have no
merit"*, and reading the code inverted the diagnosis: it was not that they had no merit, it was that they
had **no cost.**

The split key **conserved** total force, total HP and total damage, and because a single blow was capped at
half the victim's own maximum, a body died in **exactly three hits whatever its size.** So splitting
multiplied the hits an enemy needed — and the merge key undid it **instantly, losslessly, with no cooldown.**

⇒ The optimal play was **"split to the cap and stay bunched"**, which is not something a player re-decides
each moment. It is **a fact you learn once and are done with.**

**One game made a decision out of the same machine**: in Agar.io splitting makes each piece smaller and
edible, and merging **takes time.** Cost and payoff are one pair.
⇒ **Design the cost in the same sentence as the advantage.** Bolted on afterwards it becomes friction, not
cost.

### 2-2. How a conversation fails to close

- **Answering a one-sentence complaint with a new system takes six rounds.** The problem was one sentence
  (*"I don't understand why the clones exist"*) and every answer was a new system — unit types, squad
  assignment, merging, a database of what was eaten. **A new system introduces its own unknowns**, so
  nothing ever closes. ⇒ **Ask first whether a rule can answer it**
- **With no reference point, every question is answered by inventing.** Balatro's LocalThunk had never made
  a deckbuilder, but he had *Luck Be a Landlord*. One fixed point makes "like that, but not this" possible
- **Playing a reference game for a few hours is cheaper than a few hours of talking about it**

### 2-3. Rules that quietly delete themselves

- **A derived value makes the mechanic it belongs to free.** Recompute force every frame and splitting costs
  nothing — and **it fails silently**: every positional check stays green. Stored or computed is not a style
  question
- **Counting a reward at acquisition erases the transit risk.** Bank the cargo the moment it is picked up and
  a body dying 2000px from home costs nothing. **Count it on delivery**
- **If the undo is free, the choice before it is free too**
- **Postponement is not a fix.** Gating the lion to 105 seconds still meets the player at 60 HP against
  force 62 — it one-shots them anyway. Delay cannot extend reach
- **Rescaling a constant does not fix a structural bug.** Dividing the coefficient in `base + force ×
  coefficient` by ten keeps the size-ordering inversion — **it just takes a bigger number to reach it**
- **A default nobody chose reads as a decision.** Nobody ever argued for the boss's 0.75× speed, and every
  later piece of arithmetic stood on it. **Do not backfill a rationale for it**
- **One capping line drifts by one hit under integer division.** "Half your maximum, so two hits" becomes
  three at an odd maximum — and that parity is a property of **what you are wearing**, not of your level

### 2-4. Rewards and progression

- **Put the reward pool behind the commonest thing.** Parts dropped from one hard-to-catch species only, so a
  run that never caught one saw **zero cards**, with nothing on screen to say why
- **A reward you cannot refuse is not a decision.** Growth that arrives on a timer is a notification
- **A fork with one branch marked as the reward is a skill check, not a choice**
- **Purely deterministic acquisition converges every run on the same best build**
- **An automatic effect triggered by mere contact fires without intent** — walking through your own swarm
  must not spend it
- **An empty pool has to be a legal state.** Code assuming "always three offers" divided by zero on the
  first level of every run

### 2-5. Things that were the container's fault

**Switching to a round-based structure made all of these stop being problems** — not fixed, but nonexistent:
time gates · spawn weights · the no-spawn radius · the hand-placed opening pocket · the minimap · the camera
zoom curve · walking 150 seconds to the boss · **61% dead air** (a round starts with the enemy already on it).

⇒ **When a measurement keeps failing at the same place, suspect the container rather than the tuning.**
⚠ But **dead air is a ratio** — shortening the round shrinks numerator and denominator together and the ratio
does not move. A time limit stops **the run dragging**, not **the hands idling.**

### 2-6. And this is what killed both games

- The first: **34 features shipped with 5 acceptance checks still open**, and in eight months **no moment was
  fun**
- The second: **25 nets and 3541 green checks, and the user could not play it**
- **Five minutes of play found four things that three rounds of adversarial verification had missed. Twice.**

⇒ **A feature nobody has looked at is not progress, and a pile of them is not a game.**
⇒ **Planning cannot decide whether something is fun.**

---

## 3. The screen, and legibility

- **If nothing on screen decreases monotonically, there is no way to tell hitting from swinging at air.**
  Thirty-six force-10 bites into a force-120 boss produced an identical frame every time. The only bar on
  screen was **experience, not HP**, and enemy health appeared nowhere at all
- **A flash stops being an event and becomes a state as the numbers grow.** One attacker's share of the
  flash window is `flash time ÷ attack period`. **⚠ This line stood for a long time as 0.09 ÷ 1.2 ≈ 7.5%
  ⇒ "thirteen or fourteen", and that is the number from before the flash was doubled to 0.18.** At the value
  that actually shipped, 0.18 ÷ 1.2 = **15%**, so the ceiling is **six or seven.** Past it the flash never
  turns off and individual hits vanish. **This is the class of defect that gets worse as the swarm gets bigger**
- **Knockback reads against the target's radius, not in absolute pixels.** The same displacement is "it got
  flung" on a small body and "it didn't move" on a large one
- **With no safe place to stand, it is arithmetic rather than difficulty.** The boss's reach was 132px
  against a 118px bite — **it out-ranged you by 14px** — and levels grew damage without growing survival, so
  the gap widened forever
- **A camera that pulls back and a legible melee fight are in direct opposition.** Every close-quarters mark
  was drawn at half its screen size exactly when the swarm was largest — **the picture shrinks when the most
  people are fighting**
- **Three numbers in the same font, the same colour family and the same shape do not separate.** Asking for
  an icon is the same complaint as "the numbers have no label"
- **From above, only what sticks out reads.** A top-down lion is an orange square — a mane is surface, and
  surface does not show from above. **And naming an animal makes the model override the view**
- **"Too much here buries everything else."** Put a large effect on the one event that happens several times
  a second and the other eleven disappear
- **A picture becomes a number headless too** — brightness² centroid (does the sprite sit on its pivot),
  saturation, colour distance. ⚠ **But the four sprites separated well from each other, and the real question
  was whether one separated from the grey of "cannot fire".** **Compare against the wrong reference set and
  the measurement is exact while the answer is wrong**
- **The sources contradict each other.** Riot says separate by silhouette and draw **less**; Vlambeer says
  stack many small effects and put **more** in; Fatshark says distinguish **tiers**, not individuals; Sakurai
  says **deliberately shorten hitstop in a brawl** (Famitsu column Vol. 490-1).
  ⚠ **This line used to read "which is why hit-slip cannot be used on a screen with forty bodies", and that was
  wrong** — his stated reason is not readability but **fairness: while both parties are frozen a third player
  moves in and hits for free.** **An autobattler has no controlling third party, so the reason does not carry
  over.** The real reason to be careful is different — **a global freeze becomes a permanent freeze once there
  are many bodies.** See `combat-juice`. **Citing one side turns a choice into a pitch**

---

## 4. What was learned about verification

### 4-1. The gap between planned checks and needed checks

- A plan named **22** checks where the build needed **293**. Another named **17** where it needed **889**.
  **The code was right every round; the nets were what took the time**
- **Four read-only adversarial passes over an already-green round found ten holes that a mutation confirmed**
  (checks 811 → 889). Green does not mean measured
- **The verifier must not be the builder.** The person who closed exactly that hole in one file left the same
  hole open one file over, and **someone who had not built it found it**

### 4-2. How nets lie

- **Nets do not go red — they vanish.** One parse error left the pass count **identical to a clean round**
  and the exit code at **0**. **Only the final verdict line is the verdict**
- **Invert the instrument, not only the subject.** Twice in one night a check written to catch a defect
  **shipped carrying that same defect**
- **An instrument that grades its own work is wrong in its own favour** (measured twice)
- **A check that greps a file measures its text, never what it computes.** Five scans in one feature were
  **all** evaded — a decoy line, one added term, a moved declaration, the same write from another file, an
  early `return`
- **A check whose bounds come from the thing it checks proves nothing.** Pin literal coordinates
- **A/B comparison catches "diverged", never "vanished"**
- **A loop whose condition is false from the start never runs the check at all** — assert the iteration count
- **A check that reads only final state cannot measure an ordering contract.** Reverse the order, get the
  same final state, stay green
- **Argument capture proves a value was computed and handed on; it never proves the value was used.** Chase
  it to a leaf and pin the leaf by counting draw calls
- **A per-function table scans only the functions it names** ⇒ adding names fixes the day it is done and
  nothing after. Close the class so **any name not in the table is red by default**
- **"`_draw()` ran" is not "anything was drawn"**
- **A truncated search is not a search** — count the hits first, and never conclude absence from a truncated
  result

### 4-3. How documents rot

- **A value written in two places diverges.** And there is a worse case: **the same wrong sentence copied
  into three documents makes the agreement read as corroboration**
- **A refutation only propagates if it is written into the document that makes the claim.** A correction
  filed where it was discovered gets inherited anyway, because the original keeps being cited
- **A correction pass checks only the row under argument.** In one table the loud number was re-measured
  while the quiet one beside it — **off by a factor of twenty-four** — was waved through with a correction
  box blessing it. **Re-measure the whole table**
- **Citing by path and line number dies.** A symbol name survives edits above it
- **A dead paragraph left un-struck gets cited as live reasoning** — especially in a document that something
  else points at as "read this first"

---

## 5. What this document cannot answer

**Which of these is fun.** Both games died on that, and none of the measurements above touches it.
**An instrument proves "this is broken"; only a person answers "this is fun".**
