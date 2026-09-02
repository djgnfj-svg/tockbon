# When does a unit break off its move order to fight, and when does it walk past?

**Every shipped case answers this by ORDER TYPE, decided before the unit meets anything — the unit is
told in advance whether it is allowed to leave its path — and the chase that follows is bounded by a
LEASH anchored to the post the unit left, never to the enemy. Only two families of rule need no second
button: the context-sensitive click (click the enemy = fight it, click the ground = walk past it), and
full automation with no player input at all, which is what Bad North ships.**

⚠ **This note was gathered with web search only.** `WebFetch` was blocked at the egress proxy for every
domain tried, so with one exception the pages below were read through search rather than opened
directly. **The exception is the StarCraft II game data**, which was read as raw file fragments through
GitHub's code search API and is quoted verbatim.

---

## Cases

| Who | What the rule actually is | How it turned out | Source |
|---|---|---|---|
| **StarCraft II** (Blizzard) — Move | "Orders selected units to move to the targeted area **without engaging enemies along the way**." Auto-targeting is explicitly not applied to units carrying out Move | Shipped in every Blizzard RTS since 1998. Named as the beginner trap: "your armies will march right past enemy units without stopping or retaliating to damage, a potentially disastrous maneuver" | [Blizzard Game Guide: Basic Unit Controls](https://news.blizzard.com/en-us/article/4552956/game-guide-basic-unit-controls) · [Liquipedia: Automatic Targeting](https://liquipedia.net/starcraft2/Automatic_Targeting) · [StarCraft Wiki: Attack move](https://starcraft.fandom.com/wiki/Attack_move) |
| **StarCraft II** — Attack-Move (A) | "Orders selected units to move to the target point, **fighting nearby enemies along the way**." Auto-targeting applies | The default competitive habit. Also the source of the classic failure: units get baited out of position | [Blizzard Game Guide](https://news.blizzard.com/en-us/article/4552956/game-guide-basic-unit-controls) · [Liquipedia: Automatic Targeting](https://liquipedia.net/starcraft2/Automatic_Targeting) |
| **StarCraft II** — Attack Target | Clicking a specific enemy issues an **Attack Target** order. The unit follows that target **until it dies or a new order is given — no leash** | Deliberate: it is how a player commits to a kill. Auto-targeting is explicitly NOT applied here, because the player already chose | [Liquipedia: Basic Unit Commands](https://liquipedia.net/starcraft/Basic_Unit_Commands) · [Liquipedia: Automatic Targeting](https://liquipedia.net/starcraft2/Automatic_Targeting) |
| **StarCraft II** — Hold Position (H) | "Orders selected units to stay where they are and **attack enemies that are within range**." The unit never moves to engage | Shipped as the standard answer to a unit chasing off a chokepoint or a watchtower | [Blizzard Game Guide](https://news.blizzard.com/en-us/article/4552956/game-guide-basic-unit-controls) · [SC2 Mechanics Wiki: Hold Position Command](https://starcraft-ii-mechanics.fandom.com/wiki/Hold_Position_Command) |
| **StarCraft II** — the actual numbers | Blizzard's `core.sc2mod` game-wide defaults, quoted verbatim: `AcquireMovementLimit value="21"`, `AcquireLeashRadius value="21"`, `AcquireLeashResetRadius value="5"`, `CallForHelpPeriod value="2"`, `CallForHelpRadius value="4"`. The Legacy of the Void multiplayer mod tightens individual units — the Infestor is set to `AcquireMovementLimit value="5.5"` | Shipped. The leash is a **global constant with per-unit overrides**, not a per-order setting | [core.sc2mod GameData.xml](https://github.com/SC2Mapster/SC2GameData/blob/master/mods/core.sc2mod/base.sc2data/GameData/GameData.xml) · [voidmulti.sc2mod UnitData.xml](https://github.com/SC2Mapster/SC2GameData/blob/master/mods/voidmulti.sc2mod/base.sc2data/GameData/UnitData.xml) |
| **StarCraft II** — the two-radius kite guard | The leash has **two** radii. `Acquire Leash Radius` is how far an **idle** unit chases an auto-acquired target before giving up and returning to "the original point". `Acquire Leash Reset Radius` is a **smaller** circle the unit must get back inside before it may acquire again. Stated purpose: "to prevent attackers from being able to kite defenders by jumping in and out of the leash radius" | Shipped. The wiki also names the cost: the gap "can create a down time where units are vulnerable" | [SC2Mapster Wiki: Data/Units](https://sc2mapster.wiki.gg/wiki/Data/Units) |
| **Age of Empires II** (Ensemble / Forgotten Empires) | Four **stances**, set per unit and persistent. **Aggressive**: move without limitation, follow enemies in line of sight and range until they are killed — the default for all military units. **Defensive**: attack anything in range, follow **a certain number of tiles**, then return to the original position. **Stand Ground**: never move to attack, but attack anything in range. **No Attack**: never attack unless ordered | Shipped since 1999 and copied across the genre. The Definitive Edition added an option to make new units start Defensive | [AoE Wiki: Unit stance](https://ageofempires.fandom.com/wiki/Unit_stance) · [Steam: default stance option](https://steamcommunity.com/app/813780/discussions/0/2626094636167593324/) |
| **Age of Empires IV** (Relic) | Only **Stand Ground** exists. Everything else is one blended behaviour: units pursue automatically while the enemy is in reach and return to the original position if they lose it | Shipped, and disliked. Standing complaint threads on the official forum and Steam ask for the Defensive stance back | [AoE Wiki: Unit stance](https://ageofempires.fandom.com/wiki/Unit_stance) · [Official forum: "Where is the Defensive stance?"](https://forums.ageofempires.com/t/where-is-the-defensive-stance/180406) · [Steam: "Why AoE4 does not have unit stances?"](https://steamcommunity.com/app/1466860/discussions/0/3371530631543111333/) |
| **Warcraft III** (Blizzard) | Two separate ranges. **Acquisition Range** is where the unit notices; **Attack Range** is where it can hit. A unit "cannot auto-attack other units until they have come within their acquisition range" — and if attack range exceeds acquisition range, the effective range is clamped down to the acquisition range. Losing the target sends the unit back to its **guard position** | Shipped. The "return to guard position" is strong enough that map makers routinely strip it with `AI - Ignore (unit)'s guard position` | [Hive: Acquisition Range changing Attack Range?](https://www.hiveworkshop.com/threads/acquisition-range-changing-attack-range.302177/) · [Hive: Acquisition range](https://www.hiveworkshop.com/threads/acquisition-range.181333/) · [Hive: Unit Guard Position](https://www.hiveworkshop.com/threads/unit-guard-position.267649/) |
| **Warcraft III** — the numbers | World Editor Gameplay Constants (Advanced > Gameplay Constants): **Creeps - Guard Distance 600**, **Guard Return Distance (MaxGuardDistance) 1000**, **Guard Return Time 5.00 s** | Shipped defaults | [Hive: Changing Gameplay Constants](https://www.hiveworkshop.com/threads/changing-gameplay-constants-for-roc-maps.149065/) · [Hive: How to change Creep Aggro range?](https://www.hiveworkshop.com/threads/how-to-change-creep-aggro-range.269202/) · [TheHelper: Creep Return Distance/Time](https://www.thehelper.net/threads/creep-return-distance-time.149394/) |
| **Dota 2** (Valve) — neutral creeps | A neutral creep that gets more than **400 range** from its camp spot (its "guard distance") **loses aggro 5 seconds later** and walks back. **It stays aggressive on the way back**, attacking anything within 500 range as it returns. After losing aggro it can be re-aggroed only after **3 seconds** | Shipped, and the pull/stack timing economy is built on exactly these numbers | [Liquipedia: Neutral Creeps](https://liquipedia.net/dota2/Neutral_Creeps) · [Dota 2 Wiki: Neutral creeps](https://dota2.fandom.com/wiki/Neutral_creeps) |
| **Dota 2** — lane creeps | Acquisition range is per unit type: **500 melee, 600 ranged, 800 siege** | Shipped | [Liquipedia: Lane Creeps](https://liquipedia.net/dota2/Lane_Creeps) · [Dota 2 Wiki: Lane Creeps](https://dota2.fandom.com/wiki/Lane_Creeps) |
| **League of Legends** (Riot) | The trigger is a **player action**, not proximity. Attacking an allied champion near enemy minions raises a **Call for Help** — the in-game formal name — shown as a three-line icon over the minion's health bar. Priority order: enemy champions attacking an allied champion > enemy minions attacking an allied champion > enemy minions attacking an allied minion. Re-evaluated every few seconds, and **aggro drops instantly when vision of the target is lost** | Shipped and actively tuned: patch 26.10 changed it so last-hitting no longer draws minion aggro | [LoL Wiki: Minion](https://wiki.leagueoflegends.com/en-us/Minion) · [esports.gg on patch 26.10](https://esports.gg/guides/league-of-legends/lol-minions-aggro-patch-26-10/) |
| **RimWorld** (Ludeon) | Two modes, not four stances. **Undrafted** = the pawn works and does not fight. **Drafted** = the pawn "stands where you tell them and attacks what you point at". A drafted pawn with a weapon auto-attacks anything in range while **Fire at Will** is on, and **still defends itself** with Fire at Will off. A drafted pawn **never moves to engage** — it sits where placed unless it panics | Shipped, and the no-chase rule is load-bearing: leaving cover to close range is described by players as suicide. Mods exist purely to add chasing (RunAndGun, Drafted Auto-Combat, Drafted AI) | [RimWorld Wiki: Drafting](https://rimworldwiki.com/wiki/Drafting) · [RimWorld Wiki: Combat](https://rimworldwiki.com/wiki/Combat) · [Steam: Drafted Auto-Combat](https://steamcommunity.com/sharedfiles/filedetails/?id=3546270076) · [Steam: RunAndGun](https://steamcommunity.com/sharedfiles/filedetails/?id=1204108550) |
| **Total War** (Creative Assembly) | **Guard Mode**: the unit engages anything that comes into range but **will not pursue when the enemy breaks and runs**, and ranged units will not chase a target that walked out of range. **Skirmish Mode** is the mirror image for ranged units — they automatically run away when enemies get close | Shipped across the series. Guard Mode is described as the button that keeps front-line units holding the line instead of breaking formation | [TWCenter: Guard Mode](https://www.twcenter.net/threads/guard-mode.675883/) · [Total War Org: What does enabling guard mode do?](https://forums.totalwar.org/vb/showthread.php/50097-What-does-enabling-guard-mode-do) · [TW:Warhammer Wiki: Units](https://totalwarwarhammer.fandom.com/wiki/Units) |
| **World of Warcraft** (Blizzard) | This is where the word **leash** is documented. When a mob leashes it **clears its aggro list, enters Evade mode, runs back to its spawn point and resets** — immune to everything and regenerating while it does. Bosses leash on leaving a defined area regardless of distance. Instance trash generally does not leash at all | Shipped for twenty years, and the term went industry-wide from here | [Warcraft Wiki: Leash](https://warcraft.wiki.gg/wiki/Leash) · [Wowpedia: Evade](https://wowpedia.fandom.com/wiki/Evade) |
| **Bad North** (Plausible Concept) — **the bar** | **There is no order type.** Richard Meredith: "Your primary action in the game is to tell a unit to go to a grid space." Combat is entirely emergent from where the squad is standing — "Since you can only move units, it's up to you to position them in areas where they can decide for themselves where to attack." Individual soldiers inside a squad make their own choices, driven by a courage value and knowledge of where their friends are | Shipped on PC, console and mobile from one command. The Steam page sells it as the design: "you control the broad strokes of the battle, giving high level commands to your soldiers who try their best to carry them out in the heat of the moment" | [TheSixthAxis interview with Richard Meredith](https://www.thesixthaxis.com/2018/04/25/getting-to-grips-with-bad-norths-take-on-real-time-strategy/) · [New Game+ review](https://newgameplus.co.uk/2019/04/01/bad-north/) · [Game Developer: Meredith on gamefeel](https://www.gamedeveloper.com/design/-i-bad-north-s-i-richard-meredith-talks-about-making-good-gamefeel-) · [Steam store page](https://store.steampowered.com/app/688420/) |
| **Halo Wars** (Ensemble) — the console constraint | Controls were rebuilt for a gamepad: A selects (one tap = one unit, double tap = all units of that type), and the Circle Menu replaced menu chrome. The original game **shipped without any way to force units to hold position**, and without custom control groups. Halo Wars 2 added both | Shipped, and the omission is named as a limitation in retrospectives — the console budget bought fewer order types, and the sequel bought them back | [Halo Wiki: Circle Menu](https://halo.fandom.com/wiki/Circle_Menu) · [Wayward Strategy: Halo Wars, the ultimate design for console RTS](https://waywardstrategy.com/2020/03/23/halo-wars-the-ultimate-design-for-console-rts/) |

---

## The named techniques — real industry names only

| Name | What it names | Where it is documented |
|---|---|---|
| **attack-move** / **A-move** | An order that walks to a point AND engages what it meets. "Available for at least 20 years in almost all RTS games, usually done with the 'a' key" | [Blizzard Game Guide](https://news.blizzard.com/en-us/article/4552956/game-guide-basic-unit-controls) · [Wildfire Games (0 A.D.) forum](https://wildfiregames.com/forum/topic/15303-attack-move/) |
| **acquisition range** / **acquire range** | The radius at which a unit notices a target it was not told about. Separate from attack range | [WC3 — Hive](https://www.hiveworkshop.com/threads/acquisition-range.181333/) · [Dota 2 — Liquipedia](https://liquipedia.net/dota2/Lane_Creeps) |
| **target acquisition** / **automatic targeting** | The system that picks the target once one is in range and no order named one | [Liquipedia: Automatic Targeting](https://liquipedia.net/starcraft2/Automatic_Targeting) |
| **aggro** / **aggro radius** | The same idea from the enemy's side, plus the memory of who it is angry at | [Dota 2 Wiki](https://dota2.fandom.com/wiki/Neutral_creeps) · [Warcraft Wiki: Leash](https://warcraft.wiki.gg/wiki/Leash) |
| **leash** / **leash range** | The bound on the chase, and the return that follows breaking it | [Warcraft Wiki: Leash](https://warcraft.wiki.gg/wiki/Leash) · [SC2Mapster: Data/Units](https://sc2mapster.wiki.gg/wiki/Data/Units) |
| **leash reset radius** | The smaller inner circle a leashed unit must re-enter before it may acquire again — the anti-kite guard | [SC2Mapster: Data/Units](https://sc2mapster.wiki.gg/wiki/Data/Units) |
| **guard distance** / **guard return distance** / **guard return time** | Warcraft III's and Dota's names for the leash and the delay before walking home | [Hive](https://www.hiveworkshop.com/threads/changing-gameplay-constants-for-roc-maps.149065/) · [Liquipedia: Neutral Creeps](https://liquipedia.net/dota2/Neutral_Creeps) |
| **guard position** | The anchor point the leash is measured from | [Hive: Unit Guard Position](https://www.hiveworkshop.com/threads/unit-guard-position.267649/) |
| **evade** / **reset** | What a leashed enemy does on the way home: drops aggro, becomes untouchable, heals | [Wowpedia: Evade](https://wowpedia.fandom.com/wiki/Evade) |
| **stance** | A persistent per-unit setting deciding how far it may go on its own | [AoE Wiki: Unit stance](https://ageofempires.fandom.com/wiki/Unit_stance) |
| **hold position** / **stand ground** | Fight what comes in range, never take a step | [Blizzard Game Guide](https://news.blizzard.com/en-us/article/4552956/game-guide-basic-unit-controls) · [AoE Wiki](https://ageofempires.fandom.com/wiki/Unit_stance) |
| **guard mode** / **skirmish mode** | Total War's names for "engage but never pursue" and "back off when they get close" | [TWCenter](https://www.twcenter.net/threads/guard-mode.675883/) |
| **fire at will** / **hold fire** | Whether a unit shoots on its own without moving | [RimWorld Wiki: Combat](https://rimworldwiki.com/wiki/Combat) |
| **Call for Help** | League of Legends' formal in-game name for an ally's attack pulling minion aggro. StarCraft II has the same field name: `CallForHelpRadius` / `CallForHelpPeriod` | [LoL Wiki: Minion](https://wiki.leagueoflegends.com/en-us/Minion) · [core.sc2mod GameData.xml](https://github.com/SC2Mapster/SC2GameData/blob/master/mods/core.sc2mod/base.sc2data/GameData/GameData.xml) |
| **smart command** / context-sensitive default click | One button whose meaning comes from what is under the cursor. In StarCraft "Attack, Move, Gather and Set Rally Point can be activated with a right-click on a relevant target" | [Liquipedia: Basic Unit Commands](https://liquipedia.net/starcraft/Basic_Unit_Commands) |
| **"return-to-post"** | **No standard name.** The documented names are AoE2's "return to their original position", WC3's "guard position", SC2's "the original point", WoW's "evade / reset" | — |
| **"tether"** | **No standard name found in any source read here.** Every documented case uses **leash** | — |

---

## The leash anchor — where everybody measures FROM

**This is the one place the majority is unanimous, and it is worth stating on its own, because it is
where this repo currently differs.**

| Game | The leash is anchored to | Source |
|---|---|---|
| **StarCraft II** | "the original point" — where the **idle** unit was standing when it acquired | [SC2Mapster: Data/Units](https://sc2mapster.wiki.gg/wiki/Data/Units) |
| **Age of Empires II** | "their original position" | [AoE Wiki](https://ageofempires.fandom.com/wiki/Unit_stance) |
| **Warcraft III** | the unit's **guard position** | [Hive](https://www.hiveworkshop.com/threads/unit-guard-position.267649/) |
| **Dota 2** | "its original spot in the camp" | [Liquipedia](https://liquipedia.net/dota2/Neutral_Creeps) |
| **World of Warcraft** | the **spawn point** | [Warcraft Wiki: Leash](https://warcraft.wiki.gg/wiki/Leash) |

⚠ **Nobody found here anchors the leash to the moment of noticing.** In every case it is anchored to a
**post** — a place the unit belongs — and the leash is the answer to "how far may you stray from your
post", not "how far may you chase from where you spotted it". Whether the post updates when the player
issues a new move order is **not settled by any source read here**; WC3 exposes `AI - Recycle Unit's
Guard Position` and `AI - Lock Unit's Guard Position` as separate trigger actions, which implies the
post is mutable but does not say when the engine moves it on its own.

---

## The specific failure modes people report

**When a unit DOES auto-engage during a move order:**

- **Bait.** "Attack move can cause units to chase enemy units out of position… allowing your opponent to
  bait your units with a single unit to draw them out of a fortified position." Attributed to melee and
  air units alike. — [StarCraft Wiki: Attack move](https://starcraft.fandom.com/wiki/Attack_move)
- **The wrong target.** "When melee units carry out an attack move, they can waste time chasing other
  units, which would reduce their focus on priority targets." The shipped fix is to issue **hold
  position** on arrival. — [SC2 Mechanics Wiki: Hold Position Command](https://starcraft-ii-mechanics.fandom.com/wiki/Hold_Position_Command)
- **Watchtowers and chokes.** Units posted on a Xel'Naga watchtower chase passing enemies off it "by
  accident". — [SC2 Mechanics Wiki](https://starcraft-ii-mechanics.fandom.com/wiki/Hold_Position_Command)
- **Formation loss.** In Total War, without Guard Mode melee units chase routers and ranged units run
  into the melee. Guard Mode exists purely to stop it. — [TWCenter](https://www.twcenter.net/threads/guard-mode.675883/)

**When a unit does NOT auto-engage:**

- **Slaughter without retaliation.** "The Move command sends units to a designated area, ignoring all
  enemies along the way (even if it is attacked). This can quickly lead to a massive slaughter of your
  forces." — [StarCraft Wiki: Attack move](https://starcraft.fandom.com/wiki/Attack_move) ·
  [classic.battle.net unit commands](http://classic.battle.net/scc/GS/com.shtml)
- **Tedium.** RimWorld's drafted pawns never advance, so mopping up stragglers is manual; the mods
  written to add chasing recommend using it "only for cleanup". — [Steam: RunAndGun](https://steamcommunity.com/sharedfiles/filedetails/?id=1204108550)

**When the leash itself is wrong:**

- **Leash reset on damage = infinite drag.** In WoW "hitting a mob seems to reset the leash range. This
  means you can pull a mob to a far off location by periodically attacking it." — [Warcraft Tavern:
  Leash behaviour](https://www.warcrafttavern.com/wow-classic/guides/leash-behavior/)
- **Kiting in and out of the leash edge.** SC2's stated reason for a second, smaller reset radius. The
  cost of the fix is named too: a window where the returning unit will not fight back. —
  [SC2Mapster: Data/Units](https://sc2mapster.wiki.gg/wiki/Data/Units)
- **Aggressive-on-the-way-home.** Dota's returning neutral still attacks anything within 500 range while
  walking back, so "gave up" does not mean "harmless". — [Liquipedia: Neutral Creeps](https://liquipedia.net/dota2/Neutral_Creeps)

**When the stance is removed:**

- AoE4 shipped with only Stand Ground and drew standing complaints that the loss "severely limits" unit
  control. — [Official forum](https://forums.ageofempires.com/t/where-is-the-defensive-stance/180406)
- AoE2's Defensive stance draws the opposite complaint — that it is too weak to be worth using, and that
  units appear to ignore it and pursue anyway. — [Official forum: "DEFENSIVE STANCE IS
  USELESS"](https://forums.ageofempires.com/t/defensive-stance-is-useless/169389) ·
  [Steam: units ignoring stance](https://steamcommunity.com/app/813780/discussions/0/3410929607715642206/)

---

## How the order type is expressed in the interface

**And the test that matters here: this game has ONE mouse button doing everything — left-drag boxes a
squad, a short left-press moves it, the right button does nothing.**

| Game | How the player says which behaviour they want | Needs a second button or a modifier? |
|---|---|---|
| **StarCraft II** — Attack-Move | **A key, then left-click.** Or the attack button in the command card, then click | **YES — cannot be expressed here** |
| **StarCraft II** — Hold Position | **H key** | **YES — cannot be expressed here** |
| **StarCraft II** — Move vs Attack Target | **Nothing extra.** One button, and the meaning comes from what is under the cursor: enemy = Attack Target, ground = Move | **NO — this is expressible on the existing left-press** |
| **Age of Empires II** — stances | Four **icons in the command bar** at the bottom, clicked after selecting the unit; persistent until changed; a default is set in the options menu | **NO extra button, but it needs a UI panel that does not exist here** |
| **Age of Empires IV** — Stand Ground | One button on the unit panel | Same as above |
| **Total War** — Guard Mode / Skirmish | **Square toggle buttons** on the unit panel. Guard Mode has **no default hotkey at all** — binding it requires editing `custom_keys.xml`. Warhammer III adds a default-on setting in Options > Battle Interface | **NO extra button, but it needs a UI panel** |
| **RimWorld** — drafted / Fire at Will | Toggle buttons on the selected pawn's panel, plus a hotkey | **NO extra button, but it needs a UI panel** |
| **Dota 2 / League / WoW / WC3 creeps** | **Nothing. The player never says anything.** Acquisition, leash and return are entirely automatic | **NO — costs zero interface** |
| **Bad North** | **Nothing.** One command exists: go to that grid space. Combat follows from position. On a controller it is a teardrop cursor plus the A button | **NO — this is the one-button case, and it is the bar this repo set** |
| **Halo Wars** | Gamepad: A to select, Circle Menu for everything else. The original shipped with **no hold-position order at all** because there was no room for it | The console budget removed order types rather than encoding them |

---

## Who did the opposite

**RimWorld is the strongest opposite case, and Age of Empires IV is the second.**

**RimWorld** refuses to let a commanded pawn move on its own, ever. Drafted pawns "stand where you tell
them"; there is no attack-move, no pursue, no leash — because there is no chase to bound. The only
automation is whether the pawn shoots from where it already stands (**Fire at Will**), and even with
that off it will still defend itself.

- **What it bought**: cover discipline. Players describe the auto-advance the mods add as suicide in the
  base game's ranged combat, because leaving cover to close distance is how a colonist dies.
- **What it cost**: manual cleanup. Three separate popular mods exist to add chasing, and their own
  descriptions recommend turning it on "only for cleanup".
- Sources: [RimWorld Wiki: Drafting](https://rimworldwiki.com/wiki/Drafting) · [Steam: Drafted
  Auto-Combat](https://steamcommunity.com/sharedfiles/filedetails/?id=3546270076) · [Steam:
  RunAndGun](https://steamcommunity.com/sharedfiles/filedetails/?id=1204108550)

**Age of Empires IV** deleted the stance system its own series invented, keeping only Stand Ground and
blending aggressive and defensive into a single automatic behaviour: pursue while in reach, return to
the original position when the enemy is lost.

- **What it bought**: one fewer thing to manage, and a unit that never walks past a fight by accident.
- **What it cost**: players cannot stop a pursuit at all, and the official forum carries standing
  requests for the Defensive stance to come back.
- Sources: [AoE Wiki: Unit stance](https://ageofempires.fandom.com/wiki/Unit_stance) · [Official
  forum](https://forums.ageofempires.com/t/where-is-the-defensive-stance/180406) ·
  [Steam](https://steamcommunity.com/app/1466860/discussions/0/3371530631543111333/)

**Halo Wars** is the opposite case for the interface question specifically: faced with a gamepad, it did
not compress order types into modifiers — it **shipped without them**, and the sequel added them back
once the control scheme had matured.

- Source: [Wayward Strategy](https://waywardstrategy.com/2020/03/23/halo-wars-the-ultimate-design-for-console-rts/)

---

## What this does not settle

- **The AoE2 Defensive-stance chase distance has no published number** in anything found. Every source
  says "a certain number of tiles". One community post gives "0-3 tiles" but is describing *Star Wars:
  Galactic Battlegrounds*, not AoE2, and says the pre-Definitive-Edition behaviour differed. Treat the
  number as unknown. — [Steam discussion](https://steamcommunity.com/app/813780/discussions/0/2441462402302394257/)
- **Whether a move order moves the leash anchor is not documented** for any game read here. WC3 exposes
  guard-position triggers that imply it is mutable; nothing states the engine's own rule.
- **Bad North's internal engagement rule was not found.** Every claim about Bad North's combat above is
  from press and one developer interview; the developers have not published the actual acquisition or
  engagement logic. Meredith's Game Developer piece describes courage values and friend-awareness, not
  radii.
- **No GDC talk was found** on attack-move or auto-engage design specifically. The searches surfaced
  general RTS-AI discussion, not a talk on this decision.
- **SC2 distance units were not converted to tiles.** The `21` / `5` / `5.5` figures are in StarCraft
  II's own game-distance units and should not be read as this game's 조각.
- ⚠ **Read through search, not fetched.** Everything except the two StarCraft II XML files came through
  web search summarising those pages, because the egress proxy blocked direct fetching of every domain.
  The URLs are checkable; the reading of them here is one step removed.
