Type: task
Status: open

# Rebuild the five measurements the purge left with nothing watching them

## What closes it

**Five behaviours that still run have a net again**, and each new net can be made to go red by breaking
the thing it names.

## Why this ticket exists

The 2026-08-27 purge deleted the harbour system, and **the checks that measured live behaviour through
it died with it.** Nothing on this list is dead code: it all still runs, every frame, unwatched.

| What still runs | What watched it |
|---|---|
| **`_phase_boats`'s arc-length walk** | the only literal check of it anywhere |
| **`leg` monotonicity and its `path.size()-2` ceiling** | same |
| **the hull is over water on every sub-step** | same |
| **the return leg's bookkeeping** — `cum` rebuilt, `dist` unchanged, `t`/`leg` reset | same |
| **`_try_unload` / `_free_tiles_from` placement order**, and the 「a fourth boat waits」 boundary | same |

⚠⚠ **AND THE HEAVIEST ONE HAS NOTHING TO DO WITH HARBOURS: `Battle.step`'s sub-step decomposition.**
The rows that pinned it — that `step(dt)` consumes whole `Rules.SIM_SUBSTEP_SEC` chunks and carries the
remainder, and that one `step(1.0)` is NOT sixty `step(1/60)` — died only because they needed a
committed plan, and a plan was made with `send`. **Every number the sim produces rests on that
decomposition.** It is the first row to rebuild, and it is cheap: a summon plus a commit gets a fight
running, and the assertion is about the clock, not about boats.

## The rule this ticket keeps

⚠⚠ **A REBUILT NET MUST BE ABLE TO GO RED, AND THIS PURGE FOUND FIVE THAT COULD NOT.** An emptied table
made `shove_tiles_of` return 0.0, which turned `t.ok(distance >= tiles - 0.01)` into `distance >= -0.01`
— true for every input. Fourteen assertions were passing on it. **Before writing an assertion that
leans on a magnitude, ask whether that magnitude can go to zero**, and put a floor under it if it can.
`how-nets-lie` carries the full entry.

⚠ **The two verbs take different tiles.** `send` took a BEACH; `summon` takes WATER inside the band.
The helpers written today say which one they return in their own names — `_summonable_water_on`,
`_a_band_water_tile` — and a new fixture should do the same.

## What NOT to do

⚠ **Do not rebuild these against the boat system if that system is about to be replaced.** The beasts
own the boats now and the player never places one; a net written against the player's summon path is a
net that dies the day bodies start the island already ashore. **Ask which of the five outlive that
change before writing any of them** — the sub-step decomposition does, and the boat arithmetic may not.
