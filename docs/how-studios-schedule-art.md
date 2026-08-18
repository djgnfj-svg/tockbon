# When studios attach the art — actual cases

**Implemented**: n/a (reference)
**Accepted**: unseen

**Why this doc exists**: the user is new to making games and said in as many words that **without data,
whatever this side says just sounds correct.** Whether "do it in code" was convenience or judgement is
theirs to separate. So this collects **cases and sources only.** The conclusion sits after the cases, and
the cases beat the conclusion.

⚠ **Its recommendation section was deleted on 2026-08-19.** It prescribed work on the *second* game — parts,
a host, clones, crows, horses — all of which were deleted with `v2-openfield`. **The sources below are what
outlives that**; a new recommendation has to be written against the game that actually exists.

---

## 0. First: the industry already has a name for the answer — **the vertical slice**

"Art first or art last" is a question the industry has already answered with **neither.**

- **Preproduction** — find the fun with prototypes. Art is temporary
- **Vertical slice** — **one small piece** of the game built to **final quality**, art, sound and UI
  included. The last deliverable of preproduction
- **Production** — mass-produce the rest to that standard

⇒ **Art has two separate stages: settling the style, and producing it.** Style settles early (the slice);
production is late. In AAA the vertical-slice review is the **gate into production**, and it is where a
publisher's money arrives.

Sources: [Ask a Game Dev — The Vertical
Slice](https://askagamedev.tumblr.com/post/77406994278/game-development-glossary-the-vertical-slice) ·
[Vertical Slice: Definition & Examples](https://tonogameconsultants.com/vertical-slice/)

---

## 1. The ones who settled gameplay first

### Valve — *Half-Life*

In September 1997, with the original schedule nearly spent, the verdict came back: **"the game is not fun."**
Much of what had been built was thrown away and a cross-discipline group called **Cabal** redesigned it. The
final levels were pulled closer to the concept art, **but only where it did not break gameplay.** The idea
that came out of it is **experiential density** — how much happens to the player per unit of time and space.

Source: Ken Birdwell, [The Cabal: Valve's Design Process For Creating
Half-Life](https://www.gamedeveloper.com/design/the-cabal-valve-s-design-process-for-creating-i-half-life-i-)
(Gamasutra, 1999)

### Nintendo — *Super Mario 64*

**Before a single level existed**, Miyamoto put Mario in a small **"garden"** and spent months tuning nothing
but running and picking things up. Friction and weight were settled in that garden; the levels were still
**sketches and notes.**

Sources: [Super Mario 64 — 1996 Developer Interviews](https://shmuplations.com/mario64/) ·
[Some Cool Stories About The Making Of Mario 64](https://kotaku.com/some-cool-stories-about-the-making-of-mario-64-1786928623)

### Vampire Survivors — poncle (Luca Galante)

Shipped with sprites straight from a **bought asset pack.** In the developer's own account: whenever he felt
the urge to give something meaning, he **stopped himself, grabbed any sprite from the pack and gave it any
name.** Some of it was replaced later, after it caused problems. The game succeeded in Early Access in that
state.

Sources: [NME interview](https://www.nme.com/features/gaming-features/vampire-survivors-creator-luca-galante-talks-quitting-his-job-to-fulfil-his-promise-3153107) ·
[PC Gamer](https://www.pcgamer.com/vampire-survivors-didnt-rip-off-castlevania-sprites-after-all/)

### Balatro — LocalThunk (solo)

The week-two prototype was **entirely other people's placeholders.** In his words: *"I didn't know how to do
pixel art or shaders at this point so those assets are not mine, they were all placeholder."* He learned
pixel art **later** and drew it himself.

Sources: [LocalThunk, The Balatro Timeline](https://localthunk.com/blog/balatro-timeline-3aarh) ·
[his own X post](https://x.com/LocalThunk/status/1811781611542687859)

---

## 2. The one whose art *is* the identity — and it still started from gameplay

### Cuphead — Studio MDHR

One of the most art-expensive indies ever made. Every frame drawn the 1930s way, **pencil, ink and
watercolour on paper**: **~25 minutes per frame of gameplay animation**, roughly **50,000 frames** at
release, **7 years** of development.

⚠ **And the project still started from gameplay** — the games press notes this specifically. What this game
proves is not "do the art first" but that **the later you learn your art pipeline's unit cost, the more it
costs.** 25 minutes per frame is a number you need before you multiply it by 50,000.

Sources: [The unique development constraints of Cuphead's painstakingly hand-drawn
art](https://www.gamedeveloper.com/design/the-unique-development-constraints-of-i-cuphead-i-s-painstakingly-hand-drawn-art) ·
[The making of Cuphead (GamesRadar)](https://www.gamesradar.com/the-making-of-cuphead/)

---

## 3. The case against — **material supporting the user's own instinct**

Leaving this out would make the doc a pitch rather than a choice.

**Unity's official blog: "The placeholder asset problem: How programmer art kills playtests"**

Its point: **placeholders contaminate playtest feedback.** If the art is going to be replaced anyway, a
question like "does this stretch feel frightening" comes back with **the wrong answer.**

So it prescribes three **"visual minimums"**:

1. **A readable silhouette** — the player knows what the thing is
2. **Colour separation** — enemies separate from the background
3. **Basic material distinction**

And it records **when a placeholder is legitimate**: **testing a pure mechanic in isolation**, and **the
first week of a concept likely to die.**

Source: [The placeholder asset problem: How programmer art kills
playtests](https://unity.com/blog/placeholder-asset-problem) (Unity's official blog)

---

## 4. What the cases say together

| Question | What the cases answer |
|---|---|
| Art all at the end? | **Nobody does that.** Even Cuphead had to learn its unit cost early |
| Art all up front? | Also no. Mario 64 spent months in a garden with no levels at all |
| Then what? | **One piece at final quality first.** That is the vertical slice, and it is the industry's standard gate |
| How long do placeholders last? | **Through isolated mechanic tests and the first week.** After that they contaminate feedback |
| What is the minimum? | **Silhouette · colour separation · material** (Unity) |
