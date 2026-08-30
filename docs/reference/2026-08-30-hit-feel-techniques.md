# What do shipped games actually put on screen in the instant one body hits another, and what does each thing cost?

**Answer in one line.** Practitioners do not have one technique called "hit feel" — they have a
**stack of about twenty named, separately-tunable mechanisms**, and the two that every source
independently puts first are **hitstop** (both bodies freeze for a measured number of frames:
**11–15 frames at 60 fps in Guilty Gear, by attack level**) and **a colour flash on the struck body**;
screen shake is the third and the one every accessibility source says must be optional.

⚠ **This note is vocabulary and numbers, not a recommendation.** Nothing here says which to build.

---

## The named list

**Names are as practitioners say them.** Where two names exist for the same thing, both are given.
A row whose source is weak says so **on that row**.

### Time

| Name | What it does | Who ships it · what they call it | Source |
|---|---|---|---|
| **Hitstop** (= **hitlag**, **hit freeze**, **hit pause**, **hit stop**) | Both attacker and target stop advancing for a fixed number of frames at the moment of contact. The frames sit *outside* startup/active/recovery | Guilty Gear (Arc System Works) — **Attack Level 0→4 gives 11, 12, 13, 14, 15 frames of hitstop**. Same table in *Strive* and in *Accent Core Plus R* | [Dustloop GGST/Frame Data](https://www.dustloop.com/w/GGST/Frame_Data) · [Dustloop GGACR/Attack Attributes](https://www.dustloop.com/w/GGACR/Attack_Attributes) · [Fighting Game Glossary: Hitstop](https://glossary.infil.net/?t=Hitstop) |
| **Blockstop** | The same freeze, but on a blocked hit. Usually a separate, shorter number | Guilty Gear — the GGACR table is literally headed **"Blockstop/Hitstop"**, one row for both | [Dustloop GGACR/Attack Attributes](https://www.dustloop.com/w/GGACR/Attack_Attributes) |
| **Superfreeze** | A much longer, whole-screen freeze reserved for a special move firing | Guilty Gear *Strive* — Roman Cancel "effect starts super freeze 20F / 25F" | [Dustloop GGST/Mechanics](https://www.dustloop.com/w/GGST/Mechanics) |
| **Sleep** | Vlambeer's own word for hitstop in a shooter: "momentary pause when hitting an enemy" | Vlambeer, *The Art of Screenshake* — listed as its own tweak, separate from screenshake | [Talk (INDIGO 2013)](https://www.youtube.com/watch?v=AJdEqssNZ-U) · [effect-by-effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Freeze fade-in / fade-out** | Instead of a hard stop, ramp the time multiplier down into the freeze and back out of it. Three separate knobs: fade-in ms, hold ms, fade-out ms | *Juice it or lose it* demo — `Freezer.as` lerps a speed multiplier through **fade-in → hold → fade-out**; the on-stage sliders top out at **320 ms hold, 160 ms fade-in, 160 ms fade-out** | [`Freezer.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/Freezer.as) · [`Settings.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/Settings.as) |
| **Slowdown** (= **time dilation**, **slow-mo**) | Not a stop — one or both parties run at a fraction of speed for a stretch | Guilty Gear *Strive* Roman Cancels: **Blue 59F, Red 39F, Purple 20F, Yellow 10F** of half-speed on the opponent only. "Affecting everything: movement, attacks, recovery, launches, hitstop, and even invulnerability" | [Dustloop GGST/Mechanics](https://www.dustloop.com/w/GGST/Mechanics) · [Dustloop GGST/Damage](https://www.dustloop.com/w/GGST/Damage) |
| **Engine time scale** | The blunt global implementation of both of the above | Godot — `Engine.time_scale`, "the speed multiplier at which the in-game clock updates", affects `Timer`, `SceneTreeTimer` and everything using delta | [Godot: Engine.time_scale](https://docs.godotengine.org/en/stable/classes/class_engine.html) |

⚠ **Hitstop is not hitstun.** **Hitstun** is how long the *victim* cannot act after the freeze ends —
a gameplay quantity, on a different axis. Guilty Gear *Strive*: Level 0→4 gives **12, 14, 16, 19, 21
frames of standing hitstun**, alongside the 11–15 of hitstop.
[Dustloop GGST/Frame Data](https://www.dustloop.com/w/GGST/Frame_Data) ·
[Fighting Game Glossary: Hitstop](https://glossary.infil.net/?t=Hitstop)

### Colour on the struck body

| Name | What it does | Who ships it | Source |
|---|---|---|---|
| **Hit flash** (= **damage flash**, **white flash**) | Every pixel of the struck sprite goes one flat colour for a frame or two | Two documented implementations in Godot: **`modulate`** (a `Color` that *multiplies*, tweened) and **a replacement shader** that mixes the sampled colour toward a flash colour by a `uniform` | [Godot: SpriteBase3D.modulate](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html) · [Godot Shaders: Flash Shader](https://godotshaders.com/shader/flash-shader/) · [Godot Shaders: Hit Flash Effect](https://godotshaders.com/shader/hit-flash-effect/) |
| **Darken** | Tint the struck thing *down* instead of up | *Juice it or lose it* demo — on collision: `transform.colorTransform = new ColorTransform(.7, .7, .8)` | [`Block.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/gameobjects/Block.as) |
| **Impact frames** | A hand-drawn frame of high-contrast white or inverted colour that replaces the whole picture at the moment of collision — a **shockwave drawn as a frame, not as a particle** | An animation/sakuga technique. ⚠ **Sourced only to animation writing, not to a named shipped game's code** | [Wikipedia: Smear frame](https://en.wikipedia.org/wiki/Smear_frame) (contrasts the two) · [canmom, Motion blur & smears](https://canmom.art/animation/smears) |
| **Screen flash · vignette pulse · chromatic aberration · radial blur** | Full-screen post effects fired on impact | ⚠ **No shipped, developer-authored source found naming any of these as a hit effect.** The name is real; the case is not. Do not cite this row as a case | — |

### Shape and motion of the bodies

| Name | What it does | Who ships it | Source |
|---|---|---|---|
| **Squash and stretch** (= **jelly**) | Scale the struck thing non-uniformly and let it spring back | *Juice it or lose it* demo, `jellyEffect`: **0.05 s** ease to `scale × 1.2`, then **0.6 s** `Elastic.easeOut` back to 1 — X first, Y offset by 0.05 s | [`Block.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/gameobjects/Block.as) |
| **Anticipation** and **follow-through** | Wind up before the blow, overshoot after it | The first and the ninth of the twelve principles (Thomas & Johnston, *The Illusion of Life*) | [Twelve basic principles of animation](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation) |
| **Pose-to-pose** | Ship the attack as a few strong poses with **no in-betweens**, and let VFX carry the force | Motion Twin, *Dead Cells* — Thomas Vasseur: *"our attacking animations are essentially pose-to-pose animations, and we utilize VFX to give a sense of movement, impact and strength"*; interpolation frames are added **"before or after the key frames. Never in-between."** Target **30 fps** | [Art Design Deep Dive: Using a 3D pipeline for 2D animation in Dead Cells](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) |
| **Smear frame** | One frame where the body is stretched far beyond its shape to fake motion blur | Animation technique; distinct from an impact frame — a smear *bridges* motion, an impact frame *interrupts* it | [Wikipedia: Smear frame](https://en.wikipedia.org/wiki/Smear_frame) · [sakugabooru: smears](https://sakugabooru.com/wiki/show?title=smears) |
| **Knockback** (= **pushback** on the ground) | The struck body is displaced along the hit's angle | Named as its own tweak in *The Art of Screenshake* — **enemy knockback and player knockback are two separate entries in the list.** Every move carries "its own base knockback value and angle" | [Fighting Game Glossary: Knockback](https://glossary.infil.net/?t=Knockback) · [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Hit reaction** | A distinct animation on the struck body, not just displacement | Its own entry in the *Art of Screenshake* list, separate from knockback | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Recoil / kickback** | The **attacker** is pushed back by their own blow | *The Art of Screenshake* lists "weapon recoil" / "gun kickback" as its own tweak, and "player knockback" as another | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Animation cancelling** | Cutting an attack's recovery so the next action starts immediately — the *input-side* half of impact | "Removing the recovery of an attack, usually so that you can transition immediately into another move" | [Fighting Game Glossary: Cancel](https://glossary.infil.net/?t=Cancel) |

### The camera

| Name | What it does | Who ships it | Source |
|---|---|---|---|
| **Screen shake, trauma model** | Keep a `trauma` in [0,1]; a hit **adds** (`+= 0.2` or `0.5`); trauma decays linearly; **shake = trauma² (or trauma³)**. Eiserloh's own illustration: *"Trauma .30, .60, .90 means 3%, 22%, 73% shake"* | Squirrel Eiserloh, GDC 2016. Implementation given verbatim: `angle = maxAngle * shake * GetRandomFloatNegOneToOne();` and the same for `offsetX`/`offsetY`, **added to a preserved base camera** | [Slides (PDF)](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf) · [talk](https://www.youtube.com/watch?v=tu-Qe66AvtY) |
| — **its shipped constants** | | **Bevy's official 2D screen-shake example implements exactly this talk** and names its numbers: `TRAUMA_DECAY_PER_SECOND 0.5` (full trauma gone in 2 s), `TRAUMA_EXPONENT 2.0`, `MAX_ANGLE 10°`, `MAX_TRANSLATION 20 px`, `NOISE_SPEED 20`, `TRAUMA_PER_PRESS 0.4` | [bevy/examples/camera/2d_screen_shake.rs](https://github.com/bevyengine/bevy/blob/main/examples/camera/2d_screen_shake.rs) |
| **Translational vs rotational shake** | Which axis the shake rides on | Eiserloh: **in 2D**, "Rotational feels okay, but kinda lame · Translational feels nice · Translational + Rotational = Awesome". **In 3D**, "Translational: super lame! · Rotational: nice!" | [Slides (PDF)](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf) |
| **Perlin (smoothed fractal) noise shake** | Drive the offsets from noise instead of `random()` | Eiserloh: *"Smoothed fractal (e.g. Perlin) noise is WAY better than random for screen shake"* — it "automagically works with pause and slow-motion", has adjustable frequency, and is reproducible on replay. ⚠ **The pause point matters directly if hitstop is also in play** | [Slides (PDF)](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf) |
| **Spring shake** | Shake as an impulse into a damped spring rather than an offset per frame | *Juice it or lose it* demo, `Shaker.as`: velocity gets the impulse, then `drag = .1` and `elasticity = .1` pull it home each frame | [`Shaker.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/Shaker.as) |
| **Camera kick** | A directional shove of the camera *away from* the blow — not a random shake | Its own, separate entry in the *Art of Screenshake* list, listed after screenshake | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Camera lerp** (= **asymptotic averaging**) | `x += (target - x) * w` each frame. Eiserloh's own ballpark at 60 fps: **`0.01` nice and slow, `0.1` reasonably fast, `0.5` incredibly fast** | Eiserloh, GDC 2016 | [Slides (PDF)](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf) |

### Things spawned by the hit

| Name | What it does | Who ships it | Source |
|---|---|---|---|
| **Impact effect** | A short-lived sprite/particle at the contact point. ⚠ The fighting-game name **"hit spark"** is in wide use but **no wiki or developer source for it was found** — only TV Tropes. Vlambeer's own word is **"impact effect"** | *The Art of Screenshake* lists it as its own tweak, separate from muzzle flash and from the hit reaction | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Muzzle flash** | The flash at the *attacker's* end. The melee analogue is a slash flash at the blade | Its own tweak in the same list | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Trail** (= **ribbon trail**, **slash trail**) | A streak following the moving thing | *Juice it or lose it* demo: `EFFECT_BALL_TRAIL_LENGTH = 30` samples, optionally tapered by scale | [`Settings.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/Settings.as) |
| **Shatter / debris / slicing** | The struck thing breaks into pieces that carry velocity and rotation | *Juice it or lose it* demo: `SliceEffect` cuts the block along the ball's path; `EFFECT_BLOCK_SHATTER_ROTATION 5`, `EFFECT_BLOCK_SHATTER_FORCE 2`, destruction tween `2 s`, optional gravity `+.4/frame` | [`Block.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/gameobjects/Block.as) · [`Settings.as`](https://github.com/grapefrukt/juicy-breakout/blob/master/src/com/grapefrukt/games/juicy/Settings.as) |
| **Permanence** | The evidence of the hit **stays on the ground** — corpses, shells, smoke, decals | *The Art of Screenshake* names it twice: "permanence", then later "even more permanence" | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Damage numbers** (= **floating combat text**) | The amount printed over the struck body | Blizzard, *Diablo III* → *Diablo IV*. See the opposite-case section: they cut them back on purpose | [PCGamesN, quoting the Diablo IV dev livestream](https://www.pcgamesn.com/diablo-4/damage-numbers) |

### Sound

| Name | What it does | Who ships it | Source |
|---|---|---|---|
| **More bass** | Weight in the low end of the impact sound | Vlambeer names it as its own tweak in the list, on the same footing as the visual ones | [effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) |
| **Audio layering · transient design · rumble/haptics** | — | ⚠ **No developer-authored source found.** The names are real; no case is offered here | — |

### Umbrella term

**Juice** — the name for the whole stack, from Jonasson & Purho's GDC Europe 2012 talk: the argument that
the juicier a game is, the more satisfying it is to play, demonstrated by cranking a plain game up live
on stage.
[Talk](https://www.youtube.com/watch?v=Fy0aCDmgnxg) · [GDC Vault](https://www.gdcvault.com/play/1016487/Juice-It-or-Lose)

---

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Vlambeer (Jan Willem Nijman)** — *The Art of Screenshake* | Took a deliberately dull side-scrolling shooter and applied **~30 tweaks live, one at a time**, in this order: animation · lower time-to-kill · higher rate of fire · bigger bullets · **muzzle flash** · faster bullets · lower accuracy · **impact effect** · **hit reaction** · **enemy knockback** · **permanence** · **camera lerp** · **screenshake** · **player knockback** · **sleep (hit pause)** · **weapon recoil** · shells · **more bass** · random explosions · **camera kick** · bigger explosions · smoke · death animation · balancing | The canonical list. **Each item is a separate switch**, which is the actual lesson: hit feel is not one feature | [Talk (INDIGO 2013)](https://www.youtube.com/watch?v=AJdEqssNZ-U) · [GDC version](https://www.youtube.com/watch?v=SkgkIXZ_13Y) · [ordered effect breakdown](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog/451576/quick-breakdown-of-all-the-effects) · [Game Developer coverage](https://www.gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games) |
| **Martin Jonasson & Petri Purho** — *Juice it or lose it* | Same method on a Breakout, GDC Europe 2012 — **and released the source.** Every effect is a named boolean plus tuned constants: freeze (fade-in/hold/fade-out, sliders to 160/320/160 ms), spring screenshake (`drag .1`, `elasticity .1`), jelly squash (`0.05 s` out, `0.6 s` elastic back, `×1.2`), darken `(.7,.7,.8)`, trail 30 samples, shatter force 2 / rotation 5 | Shipped as a talk **and** a readable reference implementation. **The parameter ranges are the most transferable numbers found anywhere in this search** | [Talk](https://www.youtube.com/watch?v=Fy0aCDmgnxg) · [GDC Vault](https://www.gdcvault.com/play/1016487/Juice-It-or-Lose) · [source: grapefrukt/juicy-breakout](https://github.com/grapefrukt/juicy-breakout) |
| **Squirrel Eiserloh** — GDC 2016, *Juicing Your Cameras With Math* | Gave screen shake a model instead of a hack: trauma in [0,1], added per event, decaying linearly, **shake = trauma²**, driven by Perlin noise, applied to a **copy** of the camera | **Adopted as an engine example**: Bevy's official `2d_screen_shake.rs` cites this talk by name and ships the constants (decay 0.5/s, exponent 2.0, max 10° / 20 px, noise speed 20, +0.4 trauma per event) | [Slides](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf) · [talk](https://www.youtube.com/watch?v=tu-Qe66AvtY) · [Bevy example](https://github.com/bevyengine/bevy/blob/main/examples/camera/2d_screen_shake.rs) |
| **Arc System Works** — Guilty Gear | Made hitstop a **data column on every attack**, not a per-move hack: Attack Level 0→4 ⇒ **11 / 12 / 13 / 14 / 15 frames**, with the matching hitstun 12 / 14 / 16 / 19 / 21. Heavier hit = more frozen frames, in a straight line | Same table across *Accent Core Plus R* and *Strive*. Named special cases where it goes higher: Floating Crumple is **16F of hitstop**, Gold Burst 16F, Blue Burst 15F | [Dustloop GGST/Frame Data](https://www.dustloop.com/w/GGST/Frame_Data) · [Dustloop GGACR/Attack Attributes](https://www.dustloop.com/w/GGACR/Attack_Attributes) · [Dustloop GGST/Damage](https://www.dustloop.com/w/GGST/Damage) |
| **Motion Twin** — *Dead Cells* | Sprites are **3D models rendered small with no antialiasing**. Attacks are **pose-to-pose with no in-betweens**, at **30 fps**; interpolation frames are added *before or after* the keys, never between them; **impact is carried by VFX layered over the pose**, not by more animation frames | Shipped. This is the closest published pipeline to "pixel-art sprite that has to read as a heavy hit" | [Art Design Deep Dive (Thomas Vasseur)](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) |

---

## Who did the opposite

**Folmer Kelly — *"Don't Juice It Or Lose It"*, GDC Europe Independent Games Summit 2014.** A talk given
in direct answer to Jonasson & Purho's. The argument: **polish makes a game feel more alive and at the
same time reduces immersion**, and the fixation on eye candy means "the context doesn't get enough
consideration".
[Game Developer](https://www.gamedeveloper.com/design/video-indies-resist-the-urge-to-juice-it-or-lose-it-)

**Celeste shipped screen shake, then shipped a switch to turn it off.** A no-screen-shake option was
added after release, alongside a photosensitive mode, in response to accessibility concerns —
motion sickness, vestibular disorders, photosensitive epilepsy.
[Steam discussion: Photosensitive Mode and Screen Shake Effects](https://steamcommunity.com/app/504230/discussions/0/1779388938816968149/) ·
[Family Gaming Database accessibility report](https://www.familygamingdatabase.com/accessibility/Celeste)
⚠ **Sourced to an accessibility database and the game's own settings discussion, not to a Maddy Thorson
statement** — the developer's own words on the change were not found.

**Microsoft's own guidelines treat flash and shake as a hazard, not a feature.** Xbox Accessibility
Guideline 118 exists to prevent players experiencing harmful side effects during gameplay, including
photosensitive seizures and migraine episodes; the community guidelines put the hard number at
**no more than about three flashes per second**, and name
**"reduce the amount of flashing when an attack connects"** as the setting to provide.
⚠ **High-frequency screen shake counts too** — it can mimic the visual frequency of a flash.
[Xbox Accessibility Guideline 118](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/118) ·
[Game Accessibility Guidelines: avoid flickering images](https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/)

**Blizzard cut damage numbers back between Diablo III and Diablo IV.** Game director Joe Shely: the huge
numbers are "hard to understand" and "we want to keep the numbers down"; principal designer Meng Song
described monster HP scaling producing "billions, or even trillions" on screen. They changed the
*combat maths* (monster armour absorbing damage) specifically so the printed numbers would stay small.
[PCGamesN, from the Diablo IV dev livestream](https://www.pcgamesn.com/diablo-4/damage-numbers)

---

## What survives a far-back orthographic camera with pixel-art billboard sprites

⚠ **The engine facts below are sourced. The consequences drawn from them are reasoning, and are marked.**

**The two facts everything follows from:**

- Godot `Camera3D`, `PROJECTION_ORTHOGONAL`: *"Objects remain the same size on the screen no matter how
  far away they are."* Zoom is not distance — it is `Camera3D.size`, "the camera's size in meters
  measured as the diameter of the width or height".
  [Godot: Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
- `SpriteBase3D.modulate` is a `Color` defaulting to `Color(1,1,1,1)`, and modulation is a **multiply**.
  [Godot: SpriteBase3D](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html)

### Cheap here — same implementation as anywhere

- **Hitstop / sleep.** It is a time value, not a picture. `Engine.time_scale`, or a per-body freeze timer.
  Nothing about the camera or the sprite touches it. ⚠ **The one interaction**: Eiserloh's reason for
  preferring Perlin noise over `random()` is that noise "automagically works with pause and slow-motion" —
  which is exactly the case when hitstop and shake fire on the same frame.
- **Knockback, hit reaction, recoil.** World-space displacement. Under an orthographic projection, a
  world-space offset maps to a **constant** screen offset regardless of where on the island the bodies
  are — *(reasoning from the projection definition above)*, which makes tuning easier here than under a
  perspective camera, not harder.
- **Permanence.** Corpses and marks on the ground are the same cost at any camera.
- **Trails, impact effects, debris.** Ordinary billboards or particles.
- **Camera lerp / asymptotic averaging.** Pure 2D-equivalent under ortho.

### Needs a different implementation here

- **Hit flash to white.** `modulate` multiplies, so it can **darken and tint but not brighten a sprite to
  a flat white silhouette** *(reasoning from the multiply semantics above)*. The documented way to get a
  full white flash is a **replacement shader** that mixes the sampled texel toward a flash colour by a
  `uniform`, keeping alpha — that is exactly what the Godot Shaders flash/hit-flash shaders do.
  ⚠ The "1 to 2 frames" figure circulating for flash length is **blog advice, not a measured shipped
  value** — no shipped game's flash duration was found in this search.
- **Screen shake magnitude.** Bevy's `MAX_TRANSLATION = 20 px` is a **screen-pixel** number tuned for
  ordinary 2D sprites. ⚠ **A body one tile tall on a far-back camera is a small number of pixels**, so
  20 px is not a starting point here — the number has to be expressed as a **fraction of body height**,
  not copied. The trauma model itself (add on hit, decay, square it) transfers unchanged.
- **Shake axis.** Eiserloh's verdict is split by projection: **2D wants translational + rotational; 3D
  wants rotational only** because translational is "super lame" (and in a head-mounted display, harmful).
  ⚠ **His 3D verdict is about a camera inside the scene.** A far-back orthographic camera looking at a
  board behaves like his 2D case — translating it slides the whole picture uniformly, with no parallax —
  *(reasoning, not a sourced claim; it should be tried both ways before being believed)*.
- **Zoom punch.** There is no "push the camera in" here; the equivalent is animating `Camera3D.size`.
- **Squash and stretch.** A billboard is a quad, so it can be scaled — but there is **no mesh to deform**,
  so the jelly numbers from *Juice it or lose it* (`×1.2` over 0.05 s, elastic back over 0.6 s) would be
  applied as **node scale on the Sprite3D**, and the interaction between non-uniform scale and
  `billboard` mode was **not verified in this search**. ⚠ Treat as unproven.
- **Impact frames and smear frames.** These are **extra drawn frames**, not code. On pixel-art sprites
  they are the *native* form of this effect — but they must be **authored** in the pixel tool, exactly as
  *Dead Cells* authors its pose-to-pose attacks and layers VFX for the force.

### Cannot work here as written

- **Anything keyed to distance from the camera.** Under `PROJECTION_ORTHOGONAL` there is no perspective
  divide — a "scale the effect by distance" rule and a dolly-in are both **no-ops**. *(Direct consequence
  of the Godot definition quoted above.)*
- **Depth of field / focus pull on the struck body.** Same reason: the effect it is trying to buy is
  perspective separation, and there is none.
- **Vertex-deforming the sprite.** No mesh. Any deformation is either a scale of the quad or a shader
  that moves UVs.
- **Sub-pixel camera shake on pixel art.** ⚠ **Not settled.** Pixel-art sprites shimmer when sampled at
  non-integer offsets, which is what a smooth shake produces; no authoritative source for the Godot 3D
  `Sprite3D` case was found, so this is flagged rather than asserted.

---

## What this does not settle

- **Bad North's own hit feedback.** Oskar Stålberg's [Konsoll 2018 talk](https://www.youtube.com/watch?v=6JcFbivo8dQ)
  and his [collected tech tweets](https://steamcommunity.com/app/688420/discussions/0/1741100729960180741/)
  exist, but **nothing in them about hit effects, flash, shake or hitstop could be read** — the Steam
  page only links a Twitter moment whose content is not reachable. **The bar for this project is
  unmeasured on this axis.**
- **Nobody who cut hitstop for a real-time-strategy feel.** Searched for; not found. The opposite cases
  above are about *screen shake, flashing, and damage numbers*, not about hitstop.
- **"Hit spark" as a citable term.** In wide use, but absent from Dustloop's mechanics, damage and frame
  data pages and from the Fighting Game Glossary. Vlambeer's **"impact effect"** is the sourceable name.
- **Street Fighter 6's hitstop values.** SuperCombo Wiki states heavier attacks have longer hitstop and
  that hitstop is what gives the hit-confirm window, but **the wiki is behind a WAF that returns 403**
  and the per-move numbers could not be read. Only the Guilty Gear tables are sourced here.
- **Chromatic aberration, radial blur, screen flash, vignette pulse, audio layering, transient design,
  rumble.** Real names, no developer-authored case found. Do not present them as sourced.
- **Any shipped pixel-art game's shake amplitude in pixels.** Not found. Bevy's 20 px is an engine
  example's default, not a shipped game's tuning.
