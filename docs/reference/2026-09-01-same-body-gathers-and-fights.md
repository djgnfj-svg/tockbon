# Do other games make the SAME body gather and fight, or split gathering off to workers?

**Both ship. The split is the common one; the shared body is priced by a clock or a mode switch, and every
game that shares the body puts a floor under the gathering side so it cannot reach zero.**

⚠⚠ **Sourcing caveat for this whole file.** `WebFetch` and `curl` were both blocked by the session's
egress proxy on 2026-09-01, so **no page below was opened** — every line rests on search-result snippets
returned for a targeted query. Treat each row as "a search returned this from that URL", not as a page
read end to end. **Re-open the links before quoting any of it to the user as a fact.**

## Cases — the same body gathers AND fights

| Who | What they did | How it turned out | Source |
|---|---|---|---|
| **Kingdom: Two Crowns** (noio + Licorice / Raw Fury) | Archers are one body: they hunt rabbits and deer for coin during the day and fall back behind the outer wall at night. An archer put on a tower **stops hunting rabbits** | Shipped. Priced by the **day/night clock plus distance from the wall**. The game keeps **2 archers per side as hunters** so the player cannot soft-lock with no income | https://kingdomthegame.fandom.com/wiki/Archer · https://kingdomthegame.fandom.com/wiki/Archer_tower · https://steamcommunity.com/sharedfiles/filedetails/?id=1588497381 |
| **Warcraft III** (Blizzard) | **Call to Arms**: a bell at the Town Hall turns gold/lumber Peasants into Militia. **45-second timer**, or "Back to Work" to end it early; on return they resume the job they were on. While Militia they mine nothing | Shipped and load-bearing for the Human race. Wiki advice names the cost out loud: using it tells the enemy you have no army, and **"you'll be weakened from the lack of resources"** | https://wowpedia.fandom.com/wiki/Militia_(Warcraft_III) · http://classic.battle.net/war3/human/units/militia.shtml · https://liquipedia.net/warcraft/Call_to_Arms |
| **Company of Heroes** (Relic) | **No worker unit exists.** Infantry squads capture Strategic Points, and holding a sector is the income. Gathering and fighting are literally the same act | Shipped across three games. "Resource acquisition hinges on territorial control rather than worker harvesting" | https://companyofheroes.fandom.com/wiki/Resources · https://companyofheroes.fandom.com/wiki/Strategic_Point · https://companyofheroes.fandom.com/wiki/Infantry |
| **Dwarf Fortress** | A squad on the **Active/Train** alert stays in the barracks all the time; the **Inactive** alert switches the same dwarves back to civilian labour | Long-standing. The price is total: a soldiering dwarf is out of the workforce, not slowed down in it | https://dwarffortresswiki.org/index.php/DF2014:Military_F.A.Q. · https://dwarffortresswiki.org/index.php/DF2014:Military |
| **RimWorld** | **Drafting** takes a colonist off their normal work schedule and puts them under direct command; drafted pawns cannot haul. **Auto-undrafts after 10,000 ticks (~2.8 min)** with no threat | Shipped. A mode switch with an automatic return, so the player is never taxed for forgetting | https://rimworldwiki.com/wiki/Drafting |
| **Age of Empires II** | **Town Bell** garrisons every villager within 23 tiles into the nearest shelter; gathering stops until "Back to Work". Garrisoned villagers add arrows to the Town Center | Shipped. "Can be very costly, as it halts all resource gathering therefore setting back progress" | https://ageofempires.fandom.com/wiki/Town_Bell · https://ageofempires.fandom.com/wiki/Villager_(Age_of_Empires_II) |
| **Northgard** (Shiro Games) | **One villager pool.** A villager assigned to a military camp becomes a Warrior / Axe Thrower / Shield Bearer / Skirmisher and stops producing. "A villager is needed for any role to be taken" | Shipped. The army is subtracted from the economy rather than paid for out of it | https://northgard.fandom.com/wiki/Villager · https://northgard.fandom.com/wiki/How_to_play_guide_for_Northgard |

## Who did the opposite — separate workers or fully automated gathering

| Who | What they did | What they said they gained | Source |
|---|---|---|---|
| **Bad North** (Plausible Concept) | **No gathering of any kind.** Coin comes only from houses left standing at the end of a wave — big 3, medium 2, small 1 | Aimed at "a different audience ... put off by the complexity and the up-front demands of a typical RTS"; "a very low granularity of interaction" | https://bad-north.fandom.com/wiki/Bad_North%27s_Basic_Rules · https://www.nintendo.com/en-gb/News/2018/April/Interview-Taking-on-hordes-of-invading-Vikings-in-Bad-North-1368315.html · https://80.lv/articles/bad-north-cure-minimalistic-rts-with-vikings |
| **Thronefall** (Grizzly Games) | **No worker bodies at all.** Houses, farms, mines and harbours pay out per survived night; a building destroyed in the night pays nothing the next morning | Tyroller: keeping it simple means "you have to take things away". They removed the choice of **what** to build and **where**, leaving only **when**. Game Developer frames it as "subtracting a simple (but core) element of strategy games opened up a wealth of interesting design possibilities" | https://www.gamedeveloper.com/design/mastering-minimalism-and-layering-complexity-with-strategy-game-thronefall · https://en.wikipedia.org/wiki/Thronefall |
| **They Are Billions** (Numantian) | **No gatherer bodies on the map.** Buildings accrue gold/lumber/stone/iron/oil over time. Workers are an abstract pool — and **every unit costs 1 worker**, so the army eats the same pool the buildings need | The tension lives in the pool, not in bodies walking. Production buildings can be paused to free their workers | https://they-are-billions.fandom.com/wiki/Resources · https://theyarebillions-archive.fandom.com/wiki/Workers |
| **Halo Wars** (Ensemble Studios) | **Removed map gathering entirely** — supplies arrive at Supply Pads / Warehouses, resource management confined to bases | Stated reason is the console pad: RTS control schemes "were unable to provide control schemes that would deliver a good gameplay experience on a console" | https://www.halopedia.org/Halo_Wars · https://en.wikipedia.org/wiki/Halo_Wars |

## What Bad North uses instead of gathering

**Nothing is gathered.** The cost between waves comes from three places, none of them an economy:

- **Income is the defence result.** Vikings throw torches at houses; a house that burns down pays nothing.
  So the only lever on income is how well the wave was fought — https://bad-north.fandom.com/wiki/Bad_North%27s_Basic_Rules
- **A map timer that eats islands.** Turn-lines show which turn the mist takes which islands; once taken
  they are locked from being played and their rewards are gone. The player never gets to play every island —
  https://bad-north.fandom.com/wiki/Bad_North%27s_Basic_Rules · https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/BadNorth
- **Permanent loss.** A dead commander is gone with its whole squad; all commanders dead is a run over.
  Fleeing is possible — a commander boards an empty beached boat, but only one big enough for everyone alive —
  https://bad-north.fandom.com/wiki/Commander · https://bad-north.fandom.com/wiki/Regenerate_and_Flee
- **Coins cost real amounts**: first class upgrade 6, then 12, then 20 — https://bad-north.fandom.com/wiki/Bad_North%27s_Basic_Rules

## The failure mode "the two never compete, so the choice is free"

⚠ **No postmortem was found naming gathering-vs-defending specifically.** The closest named case is one
step out, about army-vs-economy:

- **Rob Pardo on why Warcraft III added upkeep**: "Players would build up to the unit cap in the game and
  just play there. Then if they lost their units they'd have this big gold and lumber surplus that they'd
  just spend to rebuild their army and max out again. It just didn't play very fun." The fix was upkeep —
  a bigger army saps gold income, so the surplus cannot make the choice free —
  https://flylib.com/books/en/2.489.1.80/1/ (interview in Fullerton, *Game Design Workshop*)
- **Sid Meier, GDC 2012 "Interesting Decisions"**: if every player picks B out of A/B/C, "the game might as
  well not give them the choice" — https://www.gamedeveloper.com/design/gdc-2012-sid-meier-on-how-to-see-games-as-sets-of-interesting-decisions · https://www.youtube.com/watch?v=WggIdtrqgKg

## What this does not settle

- **No source found for the exact failure mode.** Repeated searches for a wave-defence postmortem saying
  "the build phase had no real choice" returned nothing usable.
- **Kingdom's hunter floor** ("2 archers per side stay hunters so you don't get softlocked") comes from a
  community wiki and a community Steam guide, **not from the developer**. Treat the number as unverified.
- **Against the Storm cannot answer this question — it has no combat at all.** Fighting happens off screen
  and is summarised as forest Hostility — https://en.wikipedia.org/wiki/Against_the_Storm_(video_game) ·
  https://www.blog.radiator.debacle.us/2023/06/design-review-of-against-storm-by.html
- **Diplomacy is Not an Option is a shared pool, not a clean split**: unoccupied citizens are assigned to
  builder / gatherer / soldier. Whether a soldier can also gather was not established —
  https://store.steampowered.com/app/1272320/Diplomacy_is_Not_an_Option/ · https://www.noobfeed.com/reviews/diplomacy-is-not-an-option-review
- **Thronefall's designers were not found saying anything about workers specifically.** Their quoted
  subtraction is about **what and where to build**, not about gathering bodies.
