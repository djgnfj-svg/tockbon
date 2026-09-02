# How long does a downed body stay down, and what ends that state?

**Three of the four shipped games hold the body down with NO clock — the state ends when the condition
that caused it ends, or when somebody walks over and fetches it. The one game with a clock (X-COM) is
the one where the downed enemy stands back up and fights again.**

Written for ticket 10-03 (capture the fallen). ⚠ **Sources are limited to hosts this session could open**
— see "What this does not settle".

## Cases

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **RimWorld** | Pawn goes **Downed** when pain shock hits or the Consciousness/Moving capacity fails. **No clock** — `MakeUndowned` fires only when `ShouldBeDowned()` goes false again. Death while down comes from a hediff (blood loss), never from a downed timer | Whether it is down at all is **one roll at the moment of knockdown**: animal **0.5**, mechanoid **1.0**, non-colony humanlike **0.8667 → 0.2632** on a curve over population intent (fewer colonists ⇒ likelier to survive and be capturable). Player-faction pawns skip the roll entirely | [Pawn_HealthTracker.cs](https://github.com/Chillu1/RimWorldDecompiled/blob/master/Verse/Pawn_HealthTracker.cs) · [HealthTuning.cs](https://github.com/Chillu1/RimWorldDecompiled/blob/master/Verse/HealthTuning.cs) (decompiled source mirror) |
| **RimWorld — the fetch** | `JobDefOf.Capture` **fails if the target is not Downed**, then: walk to the body (`Toils_Goto.GotoThing`) → **pick it up** (`Toils_Haul.StartCarryThing`) → walk to a prisoner bed → `CheckMakeTakeePrisoner` | Capture is a haul job. The body is carried cargo the whole way, and dropped if the job breaks | [JobDriver_TakeToBed.cs](https://github.com/Chillu1/RimWorldDecompiled/blob/master/RimWorld/JobDriver_TakeToBed.cs) |
| **Endless Sky** | A ship is **disabled**, not destroyed, "somewhere between 50% hull strength and 10%". It lies there. You fly to it and press **B** to board; crew count decides the capture | **No clock by default.** Self-recovery exists only as an **opt-in ship attribute**, `"disabled recovery time"`, and in the shipped data only one faction's living ships (avgi windjammers) carry it, at **720** | [PlayersManual](https://github.com/endless-sky/endless-sky/wiki/PlayersManual) · [Ship.cpp recovery block](https://github.com/endless-sky/endless-sky/blob/master/source/Ship.cpp) · [windjammers.txt](https://github.com/endless-sky/endless-sky/blob/master/data/avgi/windjammers.txt) |
| **Veloren** | "**A downed state, at the moment of death humanoids survive with 1 hp, and have to be helped up**". Downed = `CharacterState::Crawl` with death protection consumed | **No clock.** The body can only stand when death protection returns; the downed player's own way out is a voluntary `GiveUp`. **The only interaction allowed on a downed entity is `HelpDowned`** — someone walks to it and presses Interact | [CHANGELOG line 303](https://github.com/veloren/veloren/blob/master/CHANGELOG.md) · [health.rs `is_downed`](https://github.com/veloren/veloren/blob/master/common/src/comp/health.rs) · [crawl.rs](https://github.com/veloren/veloren/blob/master/common/src/states/crawl.rs) · [interactable.rs](https://github.com/veloren/veloren/blob/master/voxygen/src/session/interactable.rs) |

## Who did the opposite

**X-COM (measured in OpenXcom, which reimplements the 1994 rules).** The downed alien is on a clock and
gets up:

- Unconscious unit **heals 1 stun per turn** (`healStun(1)` in `BattleUnit::prepareNewTurn`)
- It **revives the moment `stunlevel < health`** and a free tile exists — including a tile next to the
  soldier who is carrying it, so carrying the body does not stop the clock
- **Fetching is optional**: the body is an item on the floor you can walk to and pick up, and an alien
  still unconscious when the mission ends counts as `STR_LIVE_ALIENS_RECOVERED`

Sources: [BattleUnit.cpp](https://github.com/OpenXcom/OpenXcom/blob/master/src/Savegame/BattleUnit.cpp) ·
[SavedBattleGame.cpp `reviveUnconsciousUnits`](https://github.com/OpenXcom/OpenXcom/blob/master/src/Savegame/SavedBattleGame.cpp) ·
[DebriefingState.cpp](https://github.com/OpenXcom/OpenXcom/blob/master/src/Battlescape/DebriefingState.cpp)

**Endless Sky is a second, weaker opposite**: the timer exists but is opt-in per ship, so the default
shipped answer is still "lies there forever".

## What the rule costs on screen

| Who | What the downed body is drawn with |
|---|---|
| **RimWorld** | **No new art.** The standing sprite is laid over at a random angle (45–135°, +180 half the time) and wiggled — wiggle period 300 ticks, length 90 — with a "wants to be rescued" icon popped every 200 ticks. [PawnDownedWiggler.cs](https://github.com/Chillu1/RimWorldDecompiled/blob/master/Verse/PawnDownedWiggler.cs) |
| **X-COM** | **Reuses the corpse art.** The unconscious unit becomes a body item built from `getCorpseBattlescape()` — the same sprite a dead one leaves. A game with no corpse has to draw one. [UnitDieBState.cpp](https://github.com/OpenXcom/OpenXcom/blob/master/src/Battlescape/UnitDieBState.cpp) |
| **Veloren** | **A whole new animation.** `CrawlAnimation` is its own file, and the downed body still moves — `handle_move(data, &mut update, 0.2)`, one fifth speed. [crawl.rs (anim)](https://github.com/veloren/veloren/blob/master/voxygen/anim/src/character/crawl.rs) |
| **Endless Sky** | Not measured. The hull sprite does not change shape when disabled; what stops being drawn was not checked |

## What this does not settle

- ⚠⚠ **Kenshi, Wartales, Mount & Blade, Dwarf Fortress, Going Medieval and Battle Brothers could not be
  checked.** Their sources live on hosts this session's egress policy blocks — `rimworldwiki.com`,
  every `*.fandom.com`, `steamcommunity.com`, `dwarffortresswiki.org`, `wiki.gg`, `ludeon.com`,
  `forums.taleworlds.com`. Only `github.com`, `raw.githubusercontent.com` and `gitlab.com` were open,
  so **every case above is an open-source game or a decompiled source mirror**
- **Search snippets said** Kenshi's KO point is `10 + Toughness^0.75` and that KO time scales with damage
  taken, and that Bannerlord's knocked-out troops become prisoners at battle end with a chance — **the
  pages behind those snippets could not be opened, so neither is a case**
- **Nobody above captures with a hand that is already busy fighting.** RimWorld's captor is drafted out
  of combat, Veloren's helper stands still. **Whether a fetch can happen mid-fight is untested here**
- **None of the four uses a "stand on its tile for a moment" fetch.** Three carry the body; one presses a
  key next to it
