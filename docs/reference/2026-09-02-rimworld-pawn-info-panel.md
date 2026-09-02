# How does RimWorld — and comparable colony games — show a selected body's information on screen?

**A small always-on glance strip (name + 2-3 bars + one line of current action) anchored in a corner,
and everything leveled or listed behind icon tabs that open a second, larger panel.**

Measured 2026-09-02. RimWorld numbers are read out of the decompiled game source (exact, in UI units),
not eyeballed. Going Medieval and Bad North numbers are measured off official 1920x1080 Steam
screenshots — the measuring method is stated per row.

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **RimWorld** (Ludeon) | Bottom-**left** inspect pane, **432 x 165** UI px, sitting **35 px above the screen bottom** (`PaneTopY = screenHeight - 165 - 35`, `MainTabWindow.SetInitialSizeAndPosition` puts `x = 0`). Width is not chosen — it is **72 px per tab, minimum 6 tabs** (`PaneWidthFor`), so a 6-tab pawn is exactly 432 | Shipped and unchanged for years. At 1920x1080 that is **22.5% of width, 15.3% of height**; at 1280x720 the same fixed pixels would eat **33.8% of width** | [InspectPaneUtility.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/InspectPaneUtility.cs) · [MainTabWindow_Inspect.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/MainTabWindow_Inspect.cs) · [MainTabWindow.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/MainTabWindow.cs) |
| **RimWorld — what is in the glance pane** | Name in **Medium** font, truncated to fit. Then one row of **93 x 16 bars, 6 px apart**, starting at y=3 and advancing the cursor **18 px**: health (with a word label, not a number), mood, timetable, allowed area. Below that, free multi-line **inspect string** (current job, etc.) | **No skill, no trait, no stat is in the glance pane at all** | [InspectPaneFiller.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/InspectPaneFiller.cs) |
| **RimWorld — what is behind the tabs** | Tabs are **72 x 30** buttons above the pane: Character (Bio), Health, Needs, Gear, Social, Training. Character opens a card of **480 x 455 + 17 px padding each side = 514 x 489**. Skills live in a right column, **one row 230 x 24 on a 27 px pitch**: label · passion flame icon **24 x 24** (minor/major) · fill bar at `level/20` · the number. Traits are wrapped **chips 22 px tall**, width = text + 10, gaps 4 x / 5 y, in the left column | Twelve skills = 324 px of column. The card is ~3x the area of the glance pane | [SkillUI.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/SkillUI.cs) · [CharacterCardUtility.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/CharacterCardUtility.cs) · [ITab_Pawn_Character.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/RimWorld/ITab_Pawn_Character.cs) |
| **RimWorld — font** | Three fonts only: Tiny, Small, Medium. **Small line height is 22 px** (`Text.SmallFontHeight = 22f`); Small is the default and the skill rows use it; the pawn name uses Medium. Tiny is switched off on Steam Deck and for languages that cannot be tiny | The whole pane is built on a 22 px line and a 24 px row | [Text.cs](https://raw.githubusercontent.com/Chillu1/RimWorldDecompiled/master/Verse/Text.cs) |
| **RimWorld — the player reaction** | **RimHUD** stuffs health, needs, skills and mental state into the glance pane itself, resizable or as a floating window | **1,543,442 subscribers, 79,571 favourites.** The 165 px glance strip left a large appetite for more at a glance — but the mod is opt-in, and vanilla never moved | [RimHUD on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=1508850027) · [RimHUD source](https://github.com/Jaxe-Dev/RimHUD) |
| **Going Medieval** (Foxy Voxel) | Selected-settler panel in the **bottom-right**, **~280 px wide** (measured: solid panel run x=1261→1539 at y=800 in the 1920x1080 shot) and **~380 px tall** (y≈655→1035, eyeballed). Header is a row of **7 small icon tabs**. Body at a glance: name, faction, Background, Age, Height, Weight, a Religious Alignment bar, **Job preferences** (icon + text) and **Perks** (icon row). Separately, a **permanent left column, ~290 px wide**, lists every settler as portrait + name + current task | 14 skills, levels **0-50**, each with a 4-step job preference (resentful 0.2x / unwilling 0.5x / eager 2.5x / passionate 4x) — their equivalent of RimWorld's passion. Perks are the traits, icon-first | [Steam screenshot, 1920x1080](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/1029780/f981c9c208c58770eb05a6b9d6a058de51c2ca90/ss_f981c9c208c58770eb05a6b9d6a058de51c2ca90.1920x1080.jpg) · [Settlers wiki page](https://goingmedieval.fandom.com/wiki/Settlers) |
| **Dwarf Fortress (Steam, v50)** | Two layers, same as RimWorld. The **unit list** row carries portrait, name+profession, **the task they are currently performing**, stress level, work details, and a **button to open the creature's sheet**. The sheet is where everything else lives: **Overview · Personality (facets / values / Needs) · Health (Description holds body attributes) · Labor · Relationships** | The at-a-glance layer is a *list row*, not a panel — the fortress has hundreds of units, so the panel is the exception and the list is the rule | [Unit list](https://dwarffortresswiki.org/index.php/Unit_list) · [Attribute](https://dwarffortresswiki.org/Attribute) · [Need](http://www.dwarffortresswiki.org/index.php/Need) |

## Who did the opposite

**Bad North** (Plausible Concept) — **no selected-unit panel at all.** The official 1920x1080 Steam
screenshot of a live battle carries no panel, no bar, no number anywhere in the frame; a squad's identity
is a coloured banner planted above it, and its health is how many little men are still standing.

The designer's stated reason is scope of control, not screen space — Richard Meredith: *"Your primary
action in the game is to tell a unit to go to a grid space. You don't have many units, maybe four or five
at most, really limiting the amount of micromanagement you need to do."* The article adds that
*"everything is boiled down to the most minimal of components, making everything a visual cue"*, and that
this is what let an RTS work on a controller.

- [Bad North Steam screenshot, 1920x1080](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/688420/ss_8c3675db0a388f3717e530c93d0db27f526a5c0a.1920x1080.jpg)
- [TheSixthAxis interview with Richard Meredith, 2018-04-25](https://www.thesixthaxis.com/2018/04/25/getting-to-grips-with-bad-norths-take-on-real-time-strategy/)

⚠ The trade Bad North made is real: four or five squads, no names, no jobs, nothing to level. A game with
five leveled 적성 per body cannot copy it — but it is the proof that the panel size follows from how many
things the player commands, not from how much data exists.

## What this does not settle

- **Oxygen Not Included was not measured.** No official Steam screenshot shows a selected duplicant with
  the details panel open, and neither wiki documents the panel's position or size. The only checkable
  numbers found were about its full-screen management screens, not the side panel.
- **Dwarf Fortress's sheet was not measured either** — no official screenshot with a unit sheet open, and
  the wiki documents contents, not geometry.
- **No dev has been found stating why 432 x 165.** The number is read out of the code; Tynan Sylvester has
  not been found writing about the inspect pane's size.
- **Font point sizes are not in the RimWorld source** — the fonts are Unity assets (`Calibri_tiny`,
  `Arial_small`, `Arial_medium`). Only the line height (22 px for Small) is a constant in code.
- **1280x720 was not measured anywhere.** Every game here was measured at 1920x1080; the fractions carry
  over, the fixed pixel sizes do not.
