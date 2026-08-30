# How do shipped games make an off-screen incoming threat get NOTICED in time?

**Nobody relies on the threat itself being visible. Every case pairs a signal that reaches the player
wherever the camera is pointed (sound, edge icon, text, a scripted pan) with a phase in which the player
still has time to act — and Bad North, the bar, is the one case whose signal is the crossing itself,
paid for with a player-driven camera and roughly 30 seconds of open water.**

## Cases

| Who | Mechanism | What it actually does | Source |
|---|---|---|---|
| **Bad North** (Plausible Concept, 2018) | Free orbit camera + visible crossing + audio | Island sits in water ringed by fog; longboats emerge from the fog on any bearing and the player rotates/zooms to watch them cross. A horn/gong sounds at the start of an invasion | [Gaming Respawn review](https://gamingrespawn.com/featured/37821/bad-north-review/) · [Rapid Reviews](https://www.rapidreviewsuk.com/bad-north-review/) · [Geeks Under Grace](https://www.geeksundergrace.com/gaming/review-bad-north-pc/) |
| **Bad North** — crossing length | Time budget | Player report: "30~ seconds for a boat to arrive, just for its occupants to be annihilated in less than 5 seconds" — the crossing is the warning, and it is long enough that players asked for fast-forward | [Steam discussion](https://steamcommunity.com/app/688420/discussions/0/1639793203780111919/) |
| **Bad North** — time control | Slow-motion, not pause | Time slows while a command is being issued or a destination picked; no free pause. `NoAutoPause` is only about tabbing out, not a gameplay pause | [Steam discussion](https://steamcommunity.com/app/688420/discussions/0/1639793203780111919/) · [TheSixthAxis review](https://www.thesixthaxis.com/2018/08/23/bad-north-review/) |
| **Thronefall** (Grizzly Games, 2023) | Screen-edge markers + build phase | Red circular icons on the screen edge and around the map show, before the night starts, how many of which enemy come from each spawn. The player triggers the night when ready | [WhatIfGaming first impressions](https://whatifgaming.com/thronefall-first-impressions-addictive-relaxing-and-a-lot-of-fun/) · [Thronefall wiki](https://throne-fall.github.io/game-content/enemies/index.html) |
| **They Are Billions** (Numantian, 2019) | Named bearing + countdown + minimap mark + music | "Zombie swarm detected near the colony from the &lt;cardinal direction&gt;" with a timer; the swarm is marked on the minimap with a yellow skull and the music changes. Announced 8 in-game hours ahead (24 for the final wave) | [They Are Billions wiki — Swarms](https://they-are-billions.fandom.com/wiki/Swarms) |
| **Terraria** (Re-Logic) | Status text naming the bearing | "A goblin army is approaching from the west!" / "…east!", repeated once (twice on a large world), before the wave spawns at the world edge and walks to spawn | [Official Terraria wiki — Goblin Army](https://terraria.wiki.gg/wiki/Goblin_Army) |
| **Plants vs. Zombies** (PopCap, 2009) | Scripted camera pan + banner + progress bar | Level opens with a pan from the lawn right to the zombie camp and back. A red "A HUGE WAVE OF ZOMBIES IS APPROACHING!" banner fires before each flag; the progress bar carries flag marks showing where the big waves sit | [PvZ wiki — Progress bar](https://plantsvszombies.wiki.gg/wiki/Progress_bar) · [PvZ wiki — Flag Zombie](https://plantsvszombies.wiki.gg/wiki/Flag_Zombie_(PvZ)) |
| **Don't Starve** (Klei) | Audio-only precursor, no visual | Growls/barks that start soft and grow louder, at least twice, plus a character voice line ("Did you hear that?"). Default first wave gives ~2 minutes' notice; later waves shorten it | [Don't Starve wiki — Hound Wave Survival Guide](https://dontstarve.wiki.gg/wiki/Guides/Hound_Wave_Survival_Guide) |

## Who did the opposite

**Sea of Thieves** (Rare) gives no affordance at all. The Map Table shows the crew's own ship, alliance
ships, and ships that *opted in* by flying the Reaper's Mark or reaching Emissary Grade V — ordinary
enemy ships are never marked. Spotting a threat is a sail on the horizon and a crew member in the
crow's nest.

- **What it bought**: the whole tension loop — scanning the horizon is the gameplay, and choosing to
  fly the Reaper's Mark is a real risk decision
- **What it cost**: being ambushed with no notice, and a standing community ask for map-table markers
- Source: [Sea of Thieves wiki — Map Table](https://seaofthieves.wiki.gg/wiki/Map_Table)

**Thronefall's own failure mode is the same warning read from the other end**: reviewers report the
spawn markers can sit behind scenery, "so you can easily miss one of them, and get overwhelmed because
you didn't think anything was coming from that direction." An edge indicator that can be occluded is not
an edge indicator.

## What this does not settle

- **No developer statement was found** on why Bad North's camera or fog radius is what it is. Oskar
  Stålberg's [Konsoll 2018 talk](https://www.youtube.com/watch?v=6JcFbivo8dQ) covers the procedural
  *look*, not the camera or the warning design. Every Bad North claim above is press/player observation
- **Bad North's default zoom is not documented anywhere found.** That the island sits in visible water
  inside a fog ring is attested; the exact framing is not
- **No case was found of a scripted camera cut in a real-time defence game** — the Plants vs. Zombies
  pan is an opening flourish before play starts, not an interruption mid-battle
