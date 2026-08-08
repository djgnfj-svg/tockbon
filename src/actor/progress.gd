extends RefCounted
## The player's run-scoped progress — XP, level, money, and how many glyph three-picks are waiting to be opened.
##
## **`src/actor/`, not `src/sim/`.** The same argument `spell_circle.gd`'s header already makes for the
##  loadout: this is **host-authoritative run state**, not lockstep-deterministic sim state (GDD multiplayer
##  table). It also has to be reachable from Stage C, which needs `randi` for the three-pick draw — `src/sim/`
##  bans that outright (`net_determinism`'s folder scan), so putting `Progress` there would have to be undone
##  the moment that stage starts.
##
## **A level does only one thing: it raises `pending_picks`.** No health, no layers — the design doc's own
##  boundary ("a level gives only the three-pick"). `WorldStep` owns one instance and awards into it from the
##  death loop; `stage.gd` only reads it to draw the HUD.

const ThreePick := preload("res://src/actor/three_pick.gd")

## **The XP needed to advance past `level`.** Provisional, chosen while looking at nothing yet — a knob to
##  turn once the numbers are seen on screen (the plan's own "not by the user" table).
##
## **Retuned twice, both times against the doc's actual grounds — "20-30 trash mobs -> three level-ups per
##  run" — not the "7-10 kills per level" phrasing alone.**
##  · `40 + 20*level`: pure pig (12 XP, the fast bound) reached level 5 by kill 30. Too fast.
##  · `80 + 40*level`: pure pig reached level 3 at kill 30 — right for pure pig, but a **mixed** run (the
##    population the doc's grounds actually describe) only reaches level 2 by kill 30. Too slow for the
##    typical case.
##  · `60 + 30*level` (current): pure pig lands level 3 at ~kill 23, alternating pig+hen at ~kill 30 — both
##    inside the doc's range, with the realistic mixed population landing on the number itself.
##  Measured, not computed by hand (`net_progress._leveling_rate_measured_by_value` holds both exact
##  sequences as a record, not an assertion — see that function for why it is written that way).
static func xp_for_level(level: int) -> int:
	return 60 + 30 * level

var xp := 0
var level := 0
var money := 0
## **How many glyph three-picks are waiting to be opened.** Levelling twice before one is opened **stacks**
##  (the plan's own TBD, decided that way) — it is the only option that cannot silently eat a reward.
var pending_picks := 0

## **A slot and a count, nothing more** (the plan's own words). The doc asks for the dice — decline and
##  reroll — as a **permanent unlock** that does not exist yet (no research bench, `docs/design/town.md`,
##  zero code). **0, and no code path anywhere raises it.** Writing a knob that looks live but that nothing
##  can turn is CLAUDE.md's fake-code shape ("swallowing the absence of a feature so it looks like one exists
##  in miniature") — this stays visibly inert instead: a real field, read by the future dice button, moved by
##  nothing today.
var dice_left := 0

## **Empty = no pick is open.** Not a separate bool — a bool and a list can disagree (open with nothing
##  drawn, or drawn but marked closed), and this repo has already been burned by exactly that shape of state
##  duplication once (`docs/decisions/no-inventory.md`'s whole argument against a stash is the same one).
var _drawn: Array[int] = []
## **A fresh generator per `Progress` instance, not the engine's shared global RNG** (`randi()`/`randf()`).
##  `src/actor/` allows non-determinism (GDD multiplayer table — this is host-authoritative state, not
##  lockstep), but the global RNG's stream is shared with anything else in the process that calls it, so a
##  net seeding it for one check could quietly perturb another. Each `Progress` owns its own stream instead.
var _rng := RandomNumberGenerator.new()


## **A loop, not a single comparison** — one XP award can cross more than one threshold at once (a big kill,
##  or several kills landing in the same tick), and each crossing must raise `pending_picks` by one. The
##  remainder always carries over: this never rounds `xp` down to 0 at a level-up, only subtracts exactly
##  what that level cost.
##
## **The `need <= 0` guard is not a scenario that happens today** — `xp_for_level` is `60 + 30*level`, always
##  positive for the levels this game reaches. It is a guard against a future retune returning 0 (or negative):
##  without it, `xp -= 0` never shrinks `xp` below the threshold and this loop **spins forever with no error**
##  — the failure mode this harness handles worst, since a hung frame times the process out instead of turning
##  a net red (`net_progress._add_xp_guards_against_a_nonpositive_threshold` pins this by value).
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_for_level(level):
		var need := xp_for_level(level)
		if need <= 0:
			push_error("Progress: xp_for_level(%d) is %d - refusing to loop forever" % [level, need])
			break
		xp -= need
		level += 1
		pending_picks += 1


func add_money(amount: int) -> void:
	money += amount


func is_pick_open() -> bool:
	return not _drawn.is_empty()


## The three (or fewer) candidate ids currently on offer. Empty when no pick is open — the caller checks
## `is_pick_open()` first, the same idiom `is_pick_open` and `_drawn` themselves already share (one fact, one place).
##
## **A copy, not the live array.** `_drawn` *is* the open/closed flag (`is_pick_open()` reads its own
## emptiness) — Stages D and E are about to hold whatever this returns while the player clicks, and a
## consumer that sorts, filters or pops a *live* reference silently corrupts pick state from the outside: a
## four-card window, or a pick nothing can ever close, with no error raised (`net_progress` pins this: append
## to the returned array and `_drawn`'s own size must not move).
func drawn() -> Array[int]:
	return _drawn.duplicate()


## **Draws and opens a pick.** False (and no state change) if there is nothing pending, or one is already
##  open — the draw rule itself is `three_pick.draw`; this is only the stateful door onto it, the same split
##  as `spell_sim.fire()` wrapping the pure glyph-list rules.
## `owned` is the caller's job to supply (`SpellCircle.glyph_list()`) — `Progress` does not know about circles,
##  the same boundary `add_xp`/`add_money` already hold (it knows nothing about monsters either).
func open_pick(owned: Array[int]) -> bool:
	if pending_picks <= 0 or is_pick_open():
		return false
	_drawn = ThreePick.draw(owned, _rng)
	return true


## **Closes the pick without taking anything.** `pending_picks` is untouched — declining does not consume
## the pick (design doc: "dislike all three and you take none"). Only `take()` below consumes one.
func decline() -> void:
	_drawn.clear()


## **Stage E — consumes one pending pick. Bookkeeping only, nothing more.**
##
## **Placement itself already happened before this is ever called.** `spell_circle.place_glyph()` is "the
## single door" placement goes through (that file's own header) — `three_pick_window._gui_input` calls it
## directly on the layer click, and only *after* it returns `true` does it call this function. `take()` never
## takes a `SpellCircle` and never decides whether a placement is legal — the same boundary `open_pick()`
## already holds ("`owned` is the caller's job to supply... `Progress` does not know about circles"). Giving
## this function a circle reference just to re-run a decision already made would be **a second placement
## path** in miniature — exactly what the design doc's "nothing else" forbids.
##
## **`glyph_id` is checked against `_drawn`, not trusted blindly** — a stale call for an id that is not (or is
## no longer) one of the ones actually offered must not silently spend a pick and close the window on nothing.
func take(glyph_id: int) -> bool:
	if not _drawn.has(glyph_id):
		return false
	_drawn.clear()
	pending_picks -= 1
	return true


## Called by `WorldStep.reset()` — **not by `stage.gd` directly**, the same discipline that keeps the queue
##  and the fire count reverting in one place (`world_step.gd`'s own `reset()` comment). A second call site
##  here would be the same trap: touch it in two places and the day only one gets fixed, R quietly stops
##  reverting progress.
## `_rng` is **not** reseeded — a stage reset is not a reason to make the next draw deterministic again.
func reset() -> void:
	xp = 0
	level = 0
	money = 0
	pending_picks = 0
	_drawn.clear()
