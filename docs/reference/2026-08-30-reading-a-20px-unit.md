# How do shipped games make a human unit readable when it is only ~20 screen pixels tall?

**They do not make the body detailed — they simplify the silhouette, exaggerate the one thing that
identifies it, and let the group carry the reading. Bad North, the bar, solves it by making the units
flat 2D billboard sprites inside its low-poly 3D island, on purpose.**

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Plausible Concept — Bad North** | Units are **2D billboarded planes**, not 3D models, billboarded in the vertex shader. Stålberg: *"a lot of the art in Bad North tries to blur the line between 2D and 3D ... for the units in the game they of course billboard ... they are just billboarding planes"* | Shipped. The mixed-dimension look is the game's signature, and the talk presents it as a solution, not a compromise | [Konsoll 2018, Oskar Stålberg, "Developing The Bad North Look"](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 19:13–19:33 |
| **Bad North — silhouette rule** | *"the design of the units ... they're supposed to be very simple, of just a very simple silhouette, so that when they stand together in a group they blend together as a square"*, and *"it's all about trying to make the units read as a group and not as individual units"* | The unit is designed to be read as part of a block, not alone | [same talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 23:06–23:51 |
| **Bad North — where the identity lives** | Sprite bodies are deliberately **low resolution and "blobby"**; **three animation sets total** serve every unit in the game. The sprite's pixels are **UV coordinates**, used to look up a second, **high-resolution texture holding the helmet** and the unit's specific style | The body carries almost no information; the **helmet** carries the identity, and it is the only high-res part | [same talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 24:48–25:44 |
| **Bad North — two facings only** | Units are animated in one direction and **mirrored**; there is no toward-camera or away-from-camera animation. Stålberg: *"I've had a lot of people playing the game and when I tell them the units are 2D they were like, okay, I didn't notice that"* | At this size players did not detect it. He credits this to them reading as a group | [same talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 26:17–26:37 |
| **Bad North — what stays 3D** | The **shield, bow and arrows are real 3D**, tucked into the flat body, even clipping it. *"it's much more important that the shield is three dimensional"* — because the shield is what expresses **which way the group is facing**. Axes were **cut** from regular units: a flat axe reads as flipping direction | A flat body with 3D held-props is the shipped compromise | [same talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 27:42 onward |
| **Bad North — animation priority order** | Because *"the game is so zoomed out"*, the feel comes from group behaviour, not limb animation. Stålberg states an order: **good movement > good animations > good-looking characters** | He says writing the AI did more animation work than animating the sprites | [same talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 30:46–31:05 |
| **Bad North — outline width** | Outlines are a **one-pixel** double-draw: the mesh drawn inside-out pushed **one pixel out**, then right-side-out pushed one pixel in. Trees get a dark copy one pixel out so a forest forms **one common outline** instead of many. A `ddy`-based contact shadow is also pulled down to one pixel | A stated number: **1 pixel**. Wider than that and he reports spiky triangle artifacts | [same talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 17:05–17:52 |
| **Plausible Concept, in interview** | *"The core value behind the art of Bad North is readability: the strategic elements of the game are driven by a dynamic simulation which, crucially, is hidden away from the player."* And: *"Despite having quite abstract characters, everything that is happening is shown clearly — you can see and hear when arrows strike a shield, or when two soldiers clash swords."* | The stated trade: abstract characters, legible **events** | [Nintendo UK interview, April 2018](https://www.nintendo.com/en-gb/News/2018/April/Interview-Taking-on-hordes-of-invading-Vikings-in-Bad-North-1368315.html) |
| **Valve — Team Fortress 2** | *"The body proportions, weapons and silhouette lines as determined by footwear, hats and clothing folds were explicitly designed to give each character a unique silhouette."* The **black shape test** is named as their validation step: characters viewed *"only in silhouette with no internal shading at all"* had to stay *"readily identifiable"*, and this *"was used to validate the character design during the concept phase"* | Nine classes stayed distinguishable at a distance. Silhouette is step 1 of their six-step character pipeline | [Mitchell, Francke, Eng, "Illustrative Rendering in Team Fortress 2", NPAR 2007 (PDF)](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf) §4.1 |
| **Valve — the read hierarchy** | A stated, ordered hierarchy: **Team → colour. Class → distinctive silhouettes, body proportions, weapons, shoes/hats/clothing folds. Weapon → highest contrast at chest level, gradient from dark feet to light chest.** Also stated: *"Silhouettes are emphasized with rim highlights rather than dark outlines"* and *"High frequency detail is omitted where possible"* | This is the most explicit published ranking of which cue answers which question | [Francke & Lundeen, "How Valve Connects Art Direction to Gameplay", GameFest 2008 (PDF)](https://cdn.akamai.steamstatic.com/apps/valve/2008/GameFest08_ArtInSource.pdf) |
| **Blizzard — Warcraft III** | Samwise Didier: *"The first thing everyone wanted to do was make Warcraft III more realistic. So everything was smaller. Then we saw it in game, and we were like 'Everything looks dumb.' So we started making the colors simpler, decreasing the shading, adding flat colors. **We scaled the characters back up and made them bigger and bulkier so they read from that top-down camera.** That's one of the reasons we started doing that style, because it read better, but also because everything felt huge."* | The realistic attempt was **built, seen in game, and thrown out**. Exaggeration was adopted *for readability first* | [Game Informer, Nov 2018 — Warcraft III concept art gallery](https://gameinformer.com/2018/11/14/explore-warcraft-iiis-origins-in-this-rare-concept-art-gallery) |
| **Riot — League of Legends** | *"Silhouettes are the single most important thing for champion recognition in League."* A champion needs *"a defining primary characteristic that's unique to that champion"*, which **never changes even across skins**, and *"it should be clear which direction a champion is facing from their silhouette alone."* Riot's own art-careers page asks character artists to be *"masters of proportion, likeness, and readability"* so that *"even a tiny in-game model"* still reads | Silhouette + one signature prop is Riot's stated recognition system at gameplay-camera distance | [Riot, "Clarity in League", 12 Mar 2021](https://www.leagueoflegends.com/en-gb/news/dev/clarity-in-league/) · [Riot, Character Art](https://www.riotgames.com/en/artedu/character-art) |
| **Pocketwatch Games — Tooth and Tail** | Art director Adam deGrandis: *"We try to have simple, clean, identifiable silhouettes, so they stand out from crowds"*; *"no two units of the same size hold a gun the same way or have the same posture"*; units use *"much wider value changes (more bright brights and dark darks) ... and are much more saturated"* than the ground. Stated bar: *"Players should have a rough idea of what a unit does five seconds after seeing it for the first time."* | Posture and value separation, not detail, are what separate crowded tiny units | [Pocketwatch devblog, "Pixel Ark: The Look of the Animals In Tooth and Tail"](https://blog.pocketwatchgames.com/post/134808733616/pixel-ark-the-look-of-the-animals-in-tooth-and) |

## Does exaggerated proportion survive the move from pixel art to low-poly 3D?

**Yes — and the strongest evidence is a studio that built the realistic version in 3D, looked at it on a
pulled-back camera, and reversed.** Didier's Warcraft III account above is exactly that experiment,
and the stated reason was *"so they read from that top-down camera"*.

Supporting, in the same direction:

- **Valve** lists *"body proportions"* as one of the four cues that answer "which class is that?" at a
  distance — proportion is treated as a **readability channel**, not as anatomy
  ([NPAR 2007](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf))
- **Riot** exaggerates for the top-down camera, and its stated failure mode is the opposite of detail:
  the silhouette must survive foreshortening
  ([Clarity in League](https://www.leagueoflegends.com/en-gb/news/dev/clarity-in-league/))

⚠ **What no source gave: a number.** No developer statement found states a head-to-body ratio, a
minimum pixel height, or a proportion multiplier. The "8 heads tall = heroic" figure that circulates is
classical figure-drawing convention, not a game studio's stated rule, and no studio was found stating
one. **Treat any specific ratio as unsourced.**

⚠ **Bad North does NOT exaggerate proportion, and says so by omission.** Across the whole talk Stålberg
never once names proportion as a lever. His levers are: simplify the silhouette, make it read as a
group, move all detail into the **helmet**, and keep the held prop 3D. **The bar game solves the 20px
problem without a big head.**

## Silhouette rules practitioners actually state

| Technique | Who states it | Source |
|---|---|---|
| **Silhouette-first modelling** — silhouette is step 1 of the character pipeline, before interior shapes, model sheet, 3D model, skin | Valve, TF2 | [GameFest 2008](https://cdn.akamai.steamstatic.com/apps/valve/2008/GameFest08_ArtInSource.pdf) |
| **The black shape test** — validate the design as a flat black shape with no internal shading | Valve, TF2 (used during the concept phase) | [NPAR 2007](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf) §4.1 |
| **Rim highlights instead of dark outlines** | Valve, TF2 — an explicit stated preference | [NPAR 2007](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf) §3 |
| **One-pixel double-draw outline** (mesh inside-out pushed out 1px, then right-side-out pushed in 1px) | Oskar Stålberg, Bad North | [Konsoll 2018](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 17:52 |
| **A one-pixel contact shadow to anchor a thing to the ground**, done in-shader with `ddy` | Oskar Stålberg, Bad North | [Konsoll 2018](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 17:05 |
| **Group outline over individual outline** — a dark copy pushed 1px out so a cluster forms one common blob | Oskar Stålberg, Bad North (used on trees; the same abstraction principle drives the units) | [Konsoll 2018](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 17:05 |
| **Value + saturation separation from the ground** — units brighter, darker and more saturated than terrain | Adam deGrandis, Tooth and Tail | [devblog](https://blog.pocketwatchgames.com/post/134808733616/pixel-ark-the-look-of-the-animals-in-tooth-and) |
| **Team colour as the first read**, before class or weapon | Valve, TF2 read hierarchy | [GameFest 2008](https://cdn.akamai.steamstatic.com/apps/valve/2008/GameFest08_ArtInSource.pdf) |
| **One unchanging signature prop per character**, kept across every skin | Riot, League of Legends | [Clarity in League](https://www.leagueoflegends.com/en-gb/news/dev/clarity-in-league/) |
| **Facing must be readable from silhouette alone** | Riot (stated as a rule); Bad North (solved by keeping the **shield** 3D) | [Clarity in League](https://www.leagueoflegends.com/en-gb/news/dev/clarity-in-league/) · [Konsoll 2018](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 27:42 |
| **Posture differentiation** — no two similarly-sized units hold a weapon the same way | Adam deGrandis, Tooth and Tail | [devblog](https://blog.pocketwatchgames.com/post/134808733616/pixel-ark-the-look-of-the-animals-in-tooth-and) |
| **Omit high-frequency detail** at the source | Valve, TF2 (stated principle); Bad North (trees deliberately simple so a forest reads as one blob) | [NPAR 2007](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf) · [Konsoll 2018](https://www.youtube.com/watch?v=6JcFbivo8dQ) |

## Who did the opposite

**Three shipped games deliberately put flat 2D characters into a 3D world, and each says why.**

- **Bad North itself.** This is the important one: the game held up as the bar for this project is
  **already a mixed-dimension game** — 2D billboard sprite units standing on a low-poly 3D island.
  Stålberg frames it as intentional: *"a lot of the art in Bad North tries to blur the line between 2D
  and 3D."* The reasons he gives are labour (three animation sets cover the whole game) and texture
  budget, and he reports that players **did not notice** the units were flat.
  [Konsoll 2018](https://www.youtube.com/watch?v=6JcFbivo8dQ) @ 19:13, 24:48, 26:37
- **Worldwalker Games — Wildermyth.** Flat painted characters on a 3D board. Nate Austin: *"My
  contribution was that I wanted to learn 3D graphics… So that's how we ended up with the 2.5D style."*
  Annie Austin: plain 2D art *"looked a little out of place"*, so *"Nate was the one who suggested that
  I play up the paper-cut-out angle in order to really embrace the whole thing"* — papery textures,
  thickness lines, highlights. **The fix for the style clash was to commit harder to the flatness, not
  to convert the characters to 3D.**
  [Turn Based Lovers interview](https://turnbasedlovers.com/10-turns-interview/with-wildermyth-developer/)
- **Square Enix — Octopath Traveler (HD-2D).** Producer Masashi Takahashi: *"we concluded that the game
  will look new and fresh if we combine this 3D art with 2D pixels. So we came up with the concept of
  fusing 2D pixels together with a 3D environment in HD-2D."* They also report the failure mode: early
  on *"sprites looked lonely and simple in the context of a larger screen"*, fixed by **raising the
  density of the 3D surroundings**, not by changing the sprites.
  [Siliconera](https://www.siliconera.com/project-octopath-traveler-developers-answer-project-started-troubles-developing-hd-2d/) ·
  [Unreal Engine developer interview](https://www.unrealengine.com/en-US/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style)

## What this does not settle

- ⚠ **The Bad North quotes come from YouTube's auto-generated captions**, pulled with `yt-dlp`.
  Timestamps are given so every line can be checked against the video, but exact wording may differ by
  a word. Nothing structural depends on the phrasing — the claims are visible in the talk's screen
  recording too.
- **No source states a minimum pixel height** at which a human unit stops reading, and none states a
  head-to-body ratio. The 19px / 40px figures in this project have no published counterpart to compare
  against.
- **No sourced case was found of a pulled-back 3D game that deliberately kept realistic proportion and
  explained why.** Total War is the obvious candidate — at maximum zoom-out it replaces soldiers with
  abstract markers entirely — but no developer statement was found saying so, so it is not listed above.
- **Nothing here measures a pixel-art sprite against a low-poly 3D model of the same unit at the same
  size.** No study or postmortem comparing the two was found. That comparison would have to be made in
  the project's own prototype.
- **Nothing was found on the specific clash of a *chibi* sprite next to realistically-proportioned
  low-poly beasts.** The sources cover mixing 2D with 3D, and they cover exaggeration, but not the two
  together in one scene.
