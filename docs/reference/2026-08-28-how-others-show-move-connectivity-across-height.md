# How do shipped games show which tiles CONNECT for movement — not just which tiles a unit may stand on — especially across height, at stairs and ramps?

**Answer in one line.** No shipped case answers "connected" with a uniform always-on standing-pad alone:
every fix found either **computes the reachable set itself** so a tile blocked by height is simply never
lit (XCOM 2, Final Fantasy Tactics), or gives **the connector — the stair, ramp, or cliff edge — its own
distinct geometry** separate from the flat ground (Bad North's own post-launch patch, Baldur's Gate 3's
ladders and jump-circle). Even Bad North, which tries to answer this with terrain art alone and no overlay
at all, still had to ship a dedicated "pathways between levels are more visible" fix four months after
launch.

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Firaxis — XCOM 2** | Movement is a **live, per-unit computed overlay**, not a static pad: a **blue outline** marks the range reachable on a single action point, a **yellow outline** the range reachable by spending both (a "dash"); both are recomputed the instant a soldier is selected, not shown at rest. Separately, tiles reachable only via a special traversal (grapple) get a **different, distinct highlight** from ordinary move tiles — the game tells the player *how* a tile is reachable, not just that it is. Because a fixed camera angle cannot show which floor a highlighted tile belongs to inside a multi-storey building, the shipped fix was not a graphic trick but an explicit control: **F/C (or mouse wheel) cycles the camera through floors** | Shipped 2016. Community threads (below) show the grapple-tile and roof-access case is still a live point of confusion for players even with the distinct highlight and the floor-cycle control, four+ years after launch | [Official XCOM 2 manual, movement section](https://www.feralinteractive.com/en/manuals/xcom2/latest/steam/) (blue/yellow tiles, F/C floor toggle — primary) · [Steam community: "Grapple"](https://steamcommunity.com/app/268500/discussions/0/1485482132158214746/) · [Steam community: "roof's are pain in my ass"](https://steamcommunity.com/app/268500/discussions/0/412446292772129481/) |
| **Square — Final Fantasy Tactics** (1997) | The Move command highlights the **actual reachable set**, computed from two stats together: **Move** (horizontal tile count) and **Jump** (the maximum height step it may cross, along the path, not just at the destination). A tile one square away but taller than the unit's Jump value is simply **never lit** — the highlight itself is the connectivity answer, no separate boundary is drawn. The escape hatch is an equippable ability, **Ignore Elevation**, that removes the height check entirely | Shipped 1997, still cited as the reference point for the whole "grid tactics with real height" subgenre (Tactics Ogre, Triangle Strategy, Fell Seal, etc. all inherit this Move+Jump pairing) | [Final Fantasy Wiki — Jump (stat)](https://finalfantasy.fandom.com/wiki/Jump_(stat)) · [Move (stat)](https://finalfantasy.fandom.com/wiki/Move_(stat)) · [Ignore Elevation (Tactics)](https://finalfantasy.fandom.com/wiki/Ignore_Elevation_(Tactics)) — mechanical documentation, not the developers' own words; see "What this does not settle" |
| **Plausible Concept / Oskar Stålberg — Bad North** | Ships with **no tile-range overlay at all** in normal play. The studio's stated bet was that **terrain geometry itself** should carry the read: "It's much easier to understand and predict the outcome of your positioning if you have a discrete possibility space — the implications of placing your troops on a specific tile vs. the one next to it is clearly understandable in the landscape." That bet needed a fix after shipping: patch **1.0.6** (Jan 2019) lists, under Polish, **"Pathways between levels on islands are more visible"** — a direct admission that the cross-level connector did not read clearly at launch, fixed with terrain-side art, not a UI layer. A screenshot already in this repo (`docs/reference/2026-08-27-bad-north-two-storey-island.png`) shows the shipped result: crisp near-white vertical cliff faces, a darker rock-textured skirt at the cliff base marking it off from the grass above, and a visible ramp of rock physically connecting the two levels — no pad or grid drawn anywhere | Shipped 2018, patched 2019. The "bar" this project is already measuring itself against turns out to have needed a dedicated readability patch for exactly this problem | [Nintendo UK dev interview](https://www.nintendo.com/en-gb/News/2018/April/Interview-Taking-on-hordes-of-invading-Vikings-in-Bad-North-1368315.html) (philosophy quote) · [Perfectly Nintendo's transcription of patch 1.0.6](https://www.perfectly-nintendo.com/bad-north-switch-software-updates/) · [Plausible Concept's own 1.0.6 Steam announcement](https://steamcommunity.com/games/688420/announcements/detail/1718585269129544137) (linked as the primary; page did not render for automated fetch, transcription cross-checked against it by a sibling note) |
| **Larian — Baldur's Gate 3** | The Jump action draws a **live circular range indicator** around the character that changes shape as the cursor moves: it **expands when hovering a lower destination** (falling adds distance) and does **not shrink for a higher one** — so the same shape both bounds the reachable set and encodes the height relationship, recomputed continuously as the cursor moves. This is the clearest shipped example found of "a hover that lights up the reachable set, height included, from the tile under the cursor" | Shipped 2023. Isometric, not a strict tile grid, but the same fixed-angle-camera-plus-height problem | [Gamer Guides: Climbing and Jumping Explained](https://www.gamerguides.com/baldurs-gate-3/guide/gameplay/getting-started/climbing-and-jumping-explained-in-baldurs-gate-3) · [Red Bull: BG3 Jump Ability](https://www.redbull.com/gb-en/baldurs-gate-3-jumping-ability) — describes verified shipped behaviour, not the developers' own words |
| **Subset Games — Into the Breach** | No height on its board, cited here for the **general clarity principle**, in co-designer Justin Ma's own words: *"As a game design principle, we would sacrifice cool ideas for the sake of clarity every time."* And, on choosing to show rather than let players infer: *"You could type out a hundred times, 'Damages a tile and pushes adjacent tiles,' but showing that little animation of them moving is a thousand times more effective."* | Shipped 2018; won the IGF Excellence in Design award | [Game Developer interview with Justin Ma](https://www.gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time-) — primary, developer's own words |

## Who did the opposite

| Who | What they did | Why | Source |
|---|---|---|---|
| **Ubisoft — Mario + Rabbids: Kingdom Battle → Sparks of Hope** | Kingdom Battle shipped a full tile grid with coloured movement-range tiles. The sequel **tore it out**. Producer Xavier Manzanares: *"We felt that we had enough trust from Nintendo to control the characters directly in combat, that we could do stuff that maybe in the past would not have been possible."* What replaced the grid was not nothing — a **highlighted cone/circle shape** still bounds the reachable ground, just without discrete cells | Design trust and directness, not a readability complaint about the original | [Nintendo Everything, quoting Manzanares and director Davide Soliani](https://nintendoeverything.com/mario-rabbids-sparks-of-hopeoriginally-had-the-grid/) |
| **Vanillaware — Unicorn Overlord** | **Never had a tile grid to begin with.** Producer Akiyasu Yamamoto: *"Unicorn Overlord does indeed stray from the 'mainstream' Japanese SRPG tile-based system."* Units get individually-shaped placement ranges on a continuous field map instead | A deliberate genre-differentiation choice, rooted in pre-tile-standardisation '90s tactics RPGs the team grew up on — not a fix for a problem | [Destructoid interview with Yamamoto](https://www.destructoid.com/unicorn-overlord-devs-talk-history-card-games-and-that-delicious-food/) |
| **Firaxis — XCOM: Enemy Unknown**, console build | Already documented by a sibling note in this folder — cited here only because it bears directly on the same question. Jake Solomon, in his own words: *"There was no grid system initially, but the team decided to add it to the PC version during development,"* because on PC "you're not driving anything, you're just moving your mouse there and clicking" — the grid answers **where a click will land**, not what connects to what | See `docs/reference/2026-08-28-per-tile-plate-overlays.md` for the full case | [Engadget interview with Jake Solomon](https://www.engadget.com/2012-09-07-xcom-enemy-unknown-designer-jake-solomon-on-the-importance-of-p.html) |

## Still unresolved, in a shipping game — the angled-camera misread this ticket asked about

**Amplitude Studios — Humankind.** On the game's own official community forum, players report the exact
failure mode this research was asked to check for: elevation changes on the far side of a hex "are
impossible to see" from the default camera angle, players "cannot easily tell whether something is 1
level higher or 2 levels higher," and one reports getting "wrong combat bonuses" because hills read wrong
without zooming in. Proposed fixes named in the thread — exaggerating height 3–4x, a colour-coded
elevation overlay, allowing camera rotation — are unimplemented; **the thread has no developer response**,
and later patch notes (checked through mid-2023) mention line-of-sight feedback improvements but never
name elevation or cliff visibility specifically. This is not an "opposite case" — nobody chose this — it is
a live, still-open instance of the problem, useful as a check on what an unaddressed version of it looks
like from the player's side.
[Official Amplitude Studios forum thread, "Visually overwhelming"](https://community.amplitude-studios.com/amplitude-studios/humankind/forums/208-lucy-opendev/threads/38070-visually-overwhelming)

## Technique checklist against what was asked

| Technique | Found where | Not found where |
|---|---|---|
| **Overlay only while selected, vs. always on** | XCOM 2: strictly per-selection, recomputed live | Bad North: **neither** — no range overlay ever, at any time; the terrain geometry is the only signal |
| **Draw the boundary, not the fill** | Bad North's whole art direction is boundary-first (per the sibling shore-foam note's Konsoll 2018 citation, the same "crisp edge where two materials meet" principle the cliffs use) | FFT does the opposite on purpose: it fills the reachable *set*, and a height-blocked tile is absent from the fill rather than excluded by a drawn line |
| **Mark the stair/ramp with distinct art, not silhouette alone** | Bad North's shipped fix (1.0.6) is exactly this — the connector itself got dedicated art after silhouette-alone failed at launch | No case found that ships a stair/ramp as a *procedural decal or UI marker* rather than authored geometry — every case that solves this does it by modelling or painting the connector itself, not by overlaying a symbol on top of it |
| **Hover lights up the reachable set from the tile under the cursor** | Baldur's Gate 3's Jump circle, live and height-aware | XCOM 2's per-unit overlay is adjacent but keyed to unit selection, not cursor position |
| **Camera/lighting cues for a cliff face (dark band, outline, cast shadow)** | Observed directly in this repo's own Bad North reference screenshot: near-white vertical wall, darker rock skirt at the base, hard silhouette break at the top edge | No developer source found stating numeric values (colour delta, shadow strength) for any of this — see below |
| **Players misreading height on an angled camera, and the fix** | Bad North: misread at launch, terrain-art fix shipped 4 months later (see above) | Humankind: misread, **still unfixed**, sitting in the developers' own forum (see above) |

## What this does not settle

- **No developer's own words were found for *why* Final Fantasy Tactics' Move+Jump highlight works the
  way it does.** A 1997 developer interview (shmuplations.com) and a design-analysis blog
  (designoriented.net, whose page returned an expired-certificate error to every fetch attempt) were
  checked; neither discusses the height/highlight design specifically. The mechanical description above is
  sourced to community wiki documentation of shipped behaviour, not to Square's own statements.
- **No Larian statement was found explaining the Baldur's Gate 3 jump-circle's height-scaling design.**
  The behaviour is well-documented by guide sites as shipped fact, but the "why," in the developers' own
  words, was not located.
- **Into the Breach's own GDC postmortem could not be read directly** — the official GDC Vault PDF
  returned HTTP 403 and the YouTube talk has no transcript found anywhere online — so the Justin Ma quotes
  above come from a separate Game Developer interview, not that postmortem. Into the Breach also has no
  height on its board, so even a full read would only support the general clarity principle, not a
  height-specific technique.
- **No hard numbers were found anywhere** — no colour-delta, no shadow-opacity percentage, no "how many
  pixels wide" — for any of the cliff-face or connector-marking techniques above, from any developer on any
  shipped game. Every case that names a fix names *that a fix shipped*, never the values inside it.
- **Bad North's Konsoll 2018 and EPC 2018 talks were not re-watched for this note** — the sibling note
  `docs/reference/2026-08-28-per-tile-plate-overlays.md` already establishes that neither talk has a
  transcript anywhere online, and that finding is inherited here rather than re-checked.
