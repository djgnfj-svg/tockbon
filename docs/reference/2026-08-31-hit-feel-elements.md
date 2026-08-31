# 타격감 요소 — what makes a blow land, element by element

**The user named six on 2026-08-31 and asked for this page**: 넉백 · 데미지 넘버 · 히트 스파크 ·
히트 플래시 · 히트스톱 · 슬래시 트레일. This page says what each one **is**, what it is **not**, a
number somebody actually shipped it at, and **what it would cost in this repo specifically**.

⚠⚠ **This is a reference, not a plan.** Nothing here is a ticket and nothing here is agreed. The
roadmap decides what gets built; `docs/roadmap/README.md` is the only map.

⚠ **One word was mistyped and is corrected here**: the user wrote **히트스톰**; the technique is
**히트스톱** (hit stop). A 스톰 is a storm.

---

## The two words that were confusing, settled first

**These are the words the user asked about on 2026-08-31**:
*"I need the words sorted out, I don't really know them — particle and impact."*

| Word | What it is | ⚠ What it is NOT |
|---|---|---|
| **임팩트 · 타격감** | **A FEELING.** "That blow landed." It is the sum of everything on this page | **Not an object.** There is nothing on screen you can point at and call the impact |
| **파티클** | **OBJECTS.** Small pictures that are spawned, fly, and die. Countable, usually many at once | **Not the feeling.** It is one of about eight ways to produce it, and the cheapest to overuse |

⇒ **파티클 is a tool; 임팩트 is the result.** The six the user named are six different tools, and
**three of them do not put anything on screen at all** (hitstop, knockback, hit flash).

---

## The six, one section each

Every section carries the same four lines: **what it is · what it is not · a shipped number · what it
costs here.**

### 1. 히트스톱 — hit stop

**What it is.** Both bodies freeze for a few frames at the instant of contact, then resume. The
attacker's swing stops mid-arc; the victim stops mid-flinch.

**⚠ What it is not.** **Not slow motion**, and not a pause of the whole game — the rest of the island
keeps moving. **Not a delay before the damage**; the damage has already happened.

**A shipped number.** ~0.2 s is quoted as a starting point for a 60 fps fighting game (≈12 frames);
Street Fighter II's froze both characters "for like 10 frames", and that freeze is *why* the 2-in-1
cancel exists at all. Dark Souls II is named as the counter-example — thin hitstop, and it becomes
**hard to tell a hit occurred**.

**What it costs here.** ⚠⚠ **This one touches `src/sim/`, and it is the only one on this page that
does.** A freeze is the simulation not advancing for two bodies, and `battle` steps everything from
one `dt`. **Faking it in the view — holding the picture while the sim walks on — makes the body
teleport when the hold ends.** Cheapest honest version: the view holds the *frame index* of both
strips while the sim runs, which is a lie the moment either body moves.

### 2. 히트 플래시 — hit flash

**What it is.** The body that was hit turns solid white (or near-white) for a fraction of a second and
comes back.

**⚠ What it is not.** **Not a particle** — nothing is spawned. It is the same sprite drawn with a
different colour. **Not a health bar**; it says *something landed*, never *how much is left*.

**A shipped number.** **0.1 s** is the value repeated across engine write-ups, with 0.1–0.3 s given as
the usable band; past that the sprite reads as a different colour rather than as a hit.

**What it costs here.** ⚠ **Nearly free, and half of it is already built.** `Look.beast_tint` already
mixes a body's colour toward white — its own header says so: *"a hit pulls the tint toward white and
the animal brightens back to its own fur. A flat white modulate could not have done that — multiply
can only darken."* **What is missing is a clock**, not a technique.

### 3. 히트 스파크 — hit spark

**What it is.** A few small shards thrown out of the contact point, living a few frames and dying.
**This is the 파티클 of the six.**

**⚠ What it is not.** **Not the death burst** — the burst is bigger, is the body's own colour, and
plays once at the end of a life. A spark plays on **every** blow.

**A shipped number.** Vlambeer's Nuclear Throne is the reference: an explosion "shakes the screen a
little, spawns a ring of dust, and a bunch of smoke", with **dust short-lived to communicate movement**
and **smoke lingering**. Their explosion art is famously **two coloured circles**.

**⚠⚠ What this repo already measured, and it cost a round.** Hit spark was **effect 2 of the twelve**
before the fight was deleted, and two rules were paid for:

- **Six shards leave along the TANGENT of the two touching bodies**, fanning both ways. **A fan opened
  along the facing direction lands every shard back inside the striker's own outline**, because the
  contact point sits deep inside the attacker.
- **They start half a lunge late, and there is deliberately no constant for the delay.** That instant
  is when the lunge peaks and the two bodies actually meet. **Fired on the hit frame, the shards appear
  in the empty gap between two bodies that have not moved yet, and read as a telegraph rather than as
  a collision.**

**What it costs here.** ⚠⚠ **The air layer they were drawn into is deleted** (2026-08-29). The ground
buffer survived only because a body's shadow goes in it. **A spark is the first thing that needs the
air layer rebuilt**, and that is the real price — not the shards.

### 4. 넉백 — knockback

**What it is.** The struck body is pushed away from the striker and eases back.

**⚠ What it is not.** **Not the lunge.** The lunge moves the ATTACKER forward; knockback moves the
VICTIM backward. **⚠⚠ And it is not what was built on 2026-08-31 and rejected** — the user, at the
screen: *"there is this thing going back and forth now — not this."* That was the attacker's lunge,
and it reads as sliding rather than as a blow.

**A shipped number.** None found worth quoting; every game scales it to its own body size. **The
number that matters in this game is the body: 20.9 px for a wolf and 26.8 px tall for a 검사.** Any
displacement is judged against those.

**What it costs here.** ⚠ **The recipe survives in the code as prose.** `_body_offset_of` carries the
deleted knock's shape, and a hard rule went with it: **a body must not flinch away from a blow that has
not arrived** — the knock and the flash both open on the frame the hit LANDS, never on the frame it is
fired.

### 5. 슬래시 트레일 — slash trail

**What it is.** A bright arc left behind the weapon's path for a few frames, so a fast swing leaves a
readable shape instead of a blur.

**⚠ What it is not.** **Not an afterimage of the whole body** (that is a different technique — a
ghosted copy of the sprite). A trail is only the weapon's edge.

**A shipped number.** No standard exists. The common 2D route is **a hand-drawn sprite sheet of the arc
laid over the attack animation**, generic and not tied to one character, rather than a runtime mesh.

**⚠⚠ What it costs here, and this is the honest problem.** **The 검사 has no weapon.** The body the
user chose from sixteen candidates carries **no sword, no clothes and no face** — `look.gd` says so in
those words. **A slash trail is an arc drawn by a blade that does not exist**, so it is either a
punch-arc (a different thing) or it waits for a body that holds something.

### 6. 데미지 넘버 — damage numbers

**What it is.** The damage amount printed over the struck body, floating up and fading.

**⚠ What it is not.** **Not a health bar.** A number says what one blow did; a bar says what is left.

**A shipped number.** Convention is consistent across write-ups: **white with a thin outline** for
readability over any background, **float up** so several can be read at once, a **bounce or scale-pop**
on arrival, **crits at 150–200% size**, and colour coding by damage band. The universal warning:
**normal hits must stay plain**, because in fast combat hundreds of them flood the screen.

**⚠⚠ What this repo has already decided, twice, against this one.**

- **The HP bar was deleted 2026-08-28** at the user's word: *"no health bar — keep the shadow
  simple too, just a circle underneath."*
- **Bad North, this repo's stated bar, ships no numbers at all**: *"no real numbers or stats obscure
  combat, so watching the action becomes the primary source of intel and feedback."*

⇒ **Damage numbers are the one of the six that pulls against the game's own look**, and that is a
finding, not an objection. **The user decides.**

**What it costs here.** ⚠ **The only font in the repo is `NotoSansKR-Regular.otf`** — a smooth outline
font, over pixel-art bodies 27 px tall. **A number drawn with it will not match the art.** `CLAUDE.md`
is explicit that anything the player looks at is made in a tool; pixellab has a font generator, so
**this element starts with drawing a pixel font**, not with code.

---

## What this repo has already ruled out — read before proposing either

| Element | When | The user's own words |
|---|---|---|
| **화면 흔들림 (screen shake)** | 2026-08-25 | *"I don't think the screen needs to shake."* **Every constant and every field was deleted**, and `net_camera` carries a check that they stay deleted |
| **체력바 (health bar)** | 2026-08-28 | *"without a health bar."* |

⚠⚠ **A deleted effect left wired is worse than a missing one.** Screen shake was first switched off at
its gain rather than removed, and **every check about it stayed green while describing something the
game no longer did.**

---

## The twelve this repo already built, and then deleted

**2026-08-29 deleted the whole fight and all twelve of its effects.** They are listed here because
**each one was measured**, and rebuilding one without its rule pays for it twice.

| # | What it was |
|---|---|
| 1 | **The tracer** — a stub sweeping muzzle to target, never the whole line |
| 2 | **The hit spark** — six shards along the tangent, half a lunge late |
| 3 | **The body being hit** — white mixed in, a filled halo UNDER it, and a flinch toward the striker |
| 4 | **The death burst**, in that body's own side colour, drawn above everything |
| 5 | **The area ring**, grown to the real splash radius |
| 6 | **Target lines**, enemies only — *"the one item of the twelve that can be a net loss"* |
| 7 | **A landing ring** under each body stepping off a boat |
| 8 | **Summon feedback inside 100 ms** — Swink's bound on input-to-response |
| 9, 10 | **The holds**, and a panel rising rather than snapping to full alpha |
| 11 | **Screen shake** — ⚠ deleted separately, 2026-08-25, and it stays deleted |
| 12 | **The gait** — phase turns on DISTANCE, never on time |

### ⚠⚠ The five rules the deleted set paid for, and any rebuild owes them

1. **Age before draining, every frame.** An effect born this frame is at full amplitude on the frame it
   was born — otherwise the flinch never actually reaches its full flinch.
2. **Freeze the geometry on the frame the fact happened.** Every effect outlives the frame that made
   it; **a ring that re-reads a position follows a corpse.**
3. **Size anything that surrounds a body off the DRAWN half-width, never the sim radius.** The hit halo
   at 1.35× the sim radius was drawn 18.9 px out — **inside a 49 px body.** The mark saying *this one
   was just hit* was underneath the thing it marked.
4. **Cap the transient list and drop the OLDEST.** The per-body drawers are bounded by the number of
   bodies instead, which is why that cap cannot reach a flash or a knock.
5. **Nothing reacts to a blow that has not arrived.** The knock and the flash open when the hit LANDS,
   never when it is fired.

---

## The size everything on this page has to survive

⚠⚠ **This is the constraint that decides which of the six is worth building.**

| Thing | Drawn at |
|---|---|
| **늑대** | **20.9 px** across |
| **검사** | **26.8 px** tall |
| One 조각 | 40 px |

**Measured 2026-08-31**: the wolf's attack strip — jaws opening and shutting — changes the animal's
outline by **0 px across four frames** in the rear view. The user saw it and said so:
*"the bite does not show at all from a distance — the death does"* (2026-08-31). **The death reads at the same
size, because the whole silhouette changes.**

⇒ **At 21 px, an element that moves only part of a body does not exist.** Of the six: hit flash,
hitstop and hit spark change the whole picture and will read; a slash trail on a 21 px animal is a
few pixels of arc; damage numbers read *because* they are drawn at text size and not at body size.

⚠⚠ **And the art will not carry the pose.** Three attack sets were pulled for the wolf — jaws, rearing,
pouncing — and **all three came back as "the same wolf with its mouth open."** The local ComfyUI route
measured the identical refusal across 22 candidates. **A beast that leaves the ground is not available
from a prompt**, so anything that has to read at 21 px has to be produced by the ENGINE, not by the
generator.

---

## Sources

- [Hitstop/Hitfreeze/Hitlag/Hitpause — Celia Wagar, CritPoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/) — Street Fighter II's ~10 frames, and Dark Souls II as the counter-example
- [Hitstop in Unreal Engine — Cobra Code](https://medium.com/@cobracode/hitstop-in-unreal-engine-cbe85a907728) — the ~0.2 s starting value
- [Jan Willem Nijman (Vlambeer), "The Art of Screenshake", INDIGO Classes 2013](https://www.youtube.com/watch?v=AJdEqssNZ-U) — the ~30-trick list this whole subject comes from
- [Explosions in Vlambeer's Nuclear Throne — CONTROL500](https://ctrl500.com/game-design/explosions-in-vlambeers-nuclear-throne/) — dust short, smoke lingering, two circles
- [7 Game Feel Tricks — Dawnosaur](https://dawnosaur.substack.com/p/7-game-feel-tricks-to-improve-your) — ⚠ names the seven and gives **no numbers at all**; its one warning is against overuse
- [Damage Numbers: Turning Abstract Stats into Satisfying Feedback — GameJuice](https://www.gamejuice.co.uk/articles/damage-numbers-satisfying-feedback) — crits at 150–200%, keep normal hits plain
- [Implementing Floating Combat Text — Wayline](https://www.wayline.io/blog/unity-floating-combat-text) — white with a thin outline, float up
- [Adding hit flash effects using shaders or modulate](https://app.studyraid.com/en/read/33915/1505407/adding-hit-flash-effects-using-shaders-or-modulate) — the 0.1–0.3 s band
- [Bad North review — Pocket Tactics](https://www.pockettactics.com/bad-north/review) and [TheSixthAxis](https://www.thesixthaxis.com/2018/08/23/bad-north-review/) — **no numbers or stats in combat**, and the readability cost of tiny units

**Inside this repo, and worth more than any of the above**: `how-nets-lie` for why a green round about
an effect can mean nothing, and `src/look.gd`'s own tombstones for the twelve — they are where the
measured numbers actually live.
