# How do shipped games draw a per-tile "plate" / pad on 3D low-poly terrain?

**Answer in one line: the strongest evidence says Bad North's plates are not an overlay at all — they are the
authored terrain tile meshes themselves, and no developer of any shipped game was found stating that they
draw a per-cell pad as a decal or as a procedural mask.**

⚠ **This note is honest about its holes.** Four of the questions asked could not be settled with a primary
source, and each is named under "What this does not settle". Do not read a silence here as a "no".

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Plausible Concept / Oskar Stålberg — Bad North** | Islands are assembled by Wave Function Collapse from **authored tile modules on a square grid**, using "a heuristic that tries to select such tiles that the resulting observed zone is **navigable at each step**". The walkable region is therefore a property of *which modules got placed*, decided at generation time — not something computed and then painted on afterwards. | Shipped 2018 on Switch/PC/mobile/consoles. | [mxgmn/WaveFunctionCollapse README, quoting and linking Stålberg's own tweet](https://github.com/mxgmn/WaveFunctionCollapse) · [the linked tweet](https://twitter.com/OskSta/status/917405214638006273) |
| **Plausible Concept / Oskar Stålberg — Bad North** | The generator's unit of work is a **piece of island geometry**: patch 1.0.6 shipped "**Added several new island pieces to the island generator**". Patch 2.0.0 shipped "**Less visual clipping between shadows, tiles, longships and land**" — a mesh-intersection symptom, and the word used for the plate is *tile*, listed alongside land as a separate solid thing. | Both shipped. 1.0.6 landed Oct 2018; 2.0.0 is Jotunn Edition. | [Perfectly Nintendo's transcription of the official patch notes](https://www.perfectly-nintendo.com/bad-north-switch-software-updates/) · [the developer's own 1.06 announcement](https://steamcommunity.com/games/688420/announcements/detail/1718585269129544137) · [badnorth.com patch notes index](https://www.badnorth.com/news/category/Patch+Notes) |
| **Plausible Concept / Oskar Stålberg — Bad North** | **The level-change readability problem is real and they shipped a fix for it**: patch 1.0.6, "**Pathways between levels on islands are more visible**". This is the cliff/stair case, named by the developer as something that did not read well at launch. | Shipped in 1.0.6, four months after release. | [Perfectly Nintendo transcription](https://www.perfectly-nintendo.com/bad-north-switch-software-updates/) · [developer's 1.06 announcement](https://steamcommunity.com/games/688420/announcements/detail/1718585269129544137) |
| **Plausible Concept / Oskar Stålberg — Bad North** | Colour of the ground was **tuned after shipping, twice**: 2.0.0 "**Tweaked coloration of the islands**"; 1.0.3 "**Fixed issue where foliage highlights could become extremely bright**". Also 2.0.0 "Updated unit outlines to be much crisper, especially with MSAA" — outline crispness was worth a patch line. | All shipped. | [Perfectly Nintendo transcription](https://www.perfectly-nintendo.com/bad-north-switch-software-updates/) |
| **Oskar Stålberg on the grid** | Bad North is on a **square grid**; he later moved to irregular grids for Townscaper. In his own words on the limits of the technique: "**The wave function collapse is pretty bad for long, thin things. So things like walls, like pipes and things like that.**" | Bad North shipped square-grid; Townscaper shipped irregular. | [Game Developer, "How Townscaper Works: A Story Four Games in the Making"](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making) |
| **WIP Studios — Katharsis** (small studio, in development) | Ran the exact three-way comparison for **spatial ground UI**: a **sprite on a plane** "brought overlapping problems with irregular terrain"; a **decal** implementation was "really flimsy" and needed odd setup conditions to work at all; a **projector** — "a single component that projects a cookie texture as light to a surface" — was "much more flexible", "easy to use and covers all our needs", and became "our definitive choice". | Projector chosen. ⚠ Small studio, not a shipped commercial title — weigh accordingly. | [WIP Studios devlog, "Spatial ground UI: Sprite vs Decal vs Projector"](https://wip-studios.itch.io/katharsis/devlog/64758/programming-marcel-spatial-ground-ui-sprite-vs-decal-vs-projector) |
| **Subset Games — Into the Breach** | Design rule stated by Justin Ma: "**As a game design principle, we would sacrifice cool ideas for the sake of clarity every time.**" And: "Our requirement that the player has to understand what's going on in any situation restricted our game design options considerably." | Shipped 2018; won the IGF Excellence in Design award. | [Game Developer interview with Justin Ma](https://www.gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time-) · [GDC Vault, "Into the Breach Design Postmortem"](https://www.gdcvault.com/play/1025772/-Into-the-Breach-Design) |
| **Godot engine itself** (tool fact, not a game) | `Decal.normal_fade` exists precisely because decals smear onto walls: it "fades the Decal if the angle between the Decal's AABB and the target surface becomes too large. A value of 0.0 projects the decal regardless of angle, while a value of 0.999 limits the decal to surfaces that are nearly perpendicular." Setting it above 0.0 "has a small performance cost". | This is the documented, supported mitigation for a decal running over a cliff edge. | [godot-docs, using_decals.rst](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/using_decals.rst) · [Decal class reference](https://rokojori.com/en/labs/godot/docs/4.4/decal-class) |
| **W3C — WCAG 2.1 Non-text Contrast** (published standard, checkable) | "any visual information necessary to indicate state, such as whether a component is selected or focused must also ensure that the information used to identify the control in that state has a **minimum 3:1 contrast ratio**". | A published, testable number — the only hard number found anywhere in this search. | [W3C Understanding SC 1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html) |

## Who did the opposite

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Firaxis / Jake Solomon — XCOM: Enemy Unknown** | **Shipped the console version with no grid at all.** In his own words: "**There was no grid system initially, but the team decided to add it to the PC version during development.**" His reason was pointing, not tactics: "On the console, you sort of drive the cursor, but on PC you look at the screen and you're sort of like, 'I want to move there to the corner of a truck.' You're not driving anything, you're just moving your mouse there and clicking." He concludes that "adding a grid just made more sense for the platform". | Both versions shipped, same game, one with a visible grid and one without. | [Engadget interview with Jake Solomon, 2012-09-07](https://www.engadget.com/2012-09-07-xcom-enemy-unknown-designer-jake-solomon-on-the-importance-of-p.html) |
| **bryqu — Shardpunk: Verminfall** | Used a **coloured region, not per-tile pads**: "Movement in green area allows the user to perform an action after the move; moving into red area prevents executing any other actions." He flagged the exact risk this note is about: "I will be sure whether such way of presenting stuff is readable after I will have the 'real' floor and wall images — **because only then I will be able to see how they blend in with the colors**." | Shipped 2022. | [Shardpunk devlog, "Movement range display"](https://bryqu.itch.io/shardpunk/devlog/56204/movement-range-display) |

**What the opposite cases say together**: the per-tile pad is a **mouse-pointing aid**, not a tactics aid. Solomon
added the grid for the platform where you point at a place; Shardpunk, where the region matters more than the
cell, drew a region. Neither treated the pad as load-bearing for the game's readability.

## What this does not settle

⚠ **Four of the questions asked could not be answered from a primary source. Do not fill these from memory.**

1. **No developer of any shipped game was found saying how a per-cell pad overlay is produced.** The four
   candidate techniques (instanced mesh per cell / decal projector / walkability-mask shader / distance-field
   erosion) could not be attached to named shipped games by a developer's own statement. The only developer
   who compared them head-to-head is a small studio on a game that has not shipped (Katharsis, above).
2. **Oskar Stålberg's own statement that Bad North's plates are meshes was not found.** The place it would
   live is his Konsoll 2018 talk, ["Developing The Bad North Look"](https://www.youtube.com/watch?v=6JcFbivo8dQ),
   and his EPC 2018 talk, ["Wave Function Collapse in Bad North"](https://www.youtube.com/watch?v=0bcZb-SsnrA).
   **Neither has a transcript or written notes anywhere online** — searched and confirmed absent. The mesh
   conclusion in this note is **inferred from the patch notes' wording and the generator's navigability
   heuristic**, not quoted. ⇒ **If this matters, someone has to watch the talk.**
3. **No concrete numbers were found for how much lighter or less saturated a pad is than the ground under it**,
   from any developer on any game. No HSV delta, no alpha percentage, no rule. Bad North's patch notes prove
   they *tuned* island colouration after shipping but give no value. **The 3:1 figure above is the only hard
   number found, and it is a web accessibility standard, not a games practice.**
4. **No source was found that measured or playtested the readability of a hover state on a ground tile** —
   no eye-tracking, no playtest data, no accessibility audit specific to this element. What shipped games
   change on hover (colour lift vs outline vs vertical offset vs scale) could not be sourced developer-first.
5. **Bad North's own hover/click-target treatment is undocumented.** Nothing was found from the developer
   about how the order target is drawn or what changes under the cursor.

## The tension worth carrying forward

**The "close to the ground colour" requirement and the 3:1 state-contrast requirement pull against each other.**
A pad tinted a slightly lighter version of the ground beneath it cannot, by construction, carry 3:1 against
that ground. The standard's own escape is that **the thing carrying the state does not have to be the fill** —
"non-text indicators such as the check in a checkbox" is the example given. ⇒ **A subtle resting fill plus a
high-contrast edge on hover satisfies both**; a subtle fill that merely gets subtler-lighter on hover satisfies
neither. This is a reading of the standard applied to the case at hand, **not something a game developer was
found saying**.
