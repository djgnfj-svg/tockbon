extends RefCounted
## The player's run-scoped progress — XP, level, money, how many glyph three-picks are waiting to be opened,
## and (Stage I, `stage1-bosses.md`) which boss rewards are waiting to be taken.
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
const Tuning := preload("res://src/sim/sim_tuning.gd")

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

## **원석 — the research currency, and the only thing that survives a run.**
##  `docs/decisions/gems-from-bosses-and-levels.md`: **two doors, a boss (3~4) and a level (1), and no kill
##  ever pays out directly.** A trash mob reaches this only through XP → level, which is what keeps the GDD's
##  "killing is a gain, walking past is also a gain" true — XP was safe to give per kill because it dies with
##  the run, and a permanent currency is not.
##
## **It is deliberately *not* cleared by `reset()`.** Every other field here reverts, and this one must not —
##  "what is permanent is a pool, not an object" (GDD) is unimplementable if the count restarts at 0 every
##  time you die. `reset()`'s own body names this as its single exception.
##
## **Nothing spends it, and that is not an oversight.** The price of an unlock is one of `town.md`'s open
##  TBDs and belongs to the user, and that doc's old "three per unlock" arithmetic was **voided** by this
##  yield being 5x what it was written against. A counter that goes up with nothing to spend it on is honest;
##  a buy button that took a number and gave nothing back would be the fake. **The research window says so on
##  screen**, rather than leaving the player to infer it.
##
## **The name in code is `gems`, on screen 원석** — the same split every other identifier here holds
##  (CLAUDE.md: code is English, what the player reads is Korean).
var gems := 0

## The two doors' yields. **A range for the boss, a flat 1 for the level** — the decision doc's own numbers.
##  A full clear is 2 bosses + ~3 levels ≈ **9~11**; a death at level 2 ≈ **2**, and *never 0*, which is what
##  makes the run-end settlement screen worth opening in an early run.
const GEMS_PER_BOSS_MIN := 3
const GEMS_PER_BOSS_MAX := 4
const GEMS_PER_LEVEL := 1

## **Stage I (`stage1-bosses.md`) — which bosses have died with their reward not yet taken.** Keyed by
## `MonsterDefs` kind, not a bare bool — the bull's own room ① water and the rooster's own room ③ water gate
## independently, and a shared flag would let one boss's reward-taking accidentally release the other's water
## the moment both have died in the same session.
##
## **Presence as a key carries "has died at all"; the stored value carries "is it still pending."** One field
## answers both questions — a boss that has never died has no key at all, told apart from one whose reward was
## already taken (`false`, same as never-died, if the value alone were read) by `.has()` instead of `.get()`.
## `boss_died()`/`is_reward_pending()` below are the two questions asked separately, so a caller never has to
## re-derive this distinction by hand.
## **Private, like `_drawn` below** — `net_pick._no_pushed_out_glyph_is_stashed_anywhere` scans every `.gd`
## file for a top-level public `Array`/`Dictionary` field not on its own hardcoded allowlist (the no-inventory
## decision, `docs/decisions/no-inventory.md`). The accessor methods below are the only door in or out, the
## same discipline `_drawn`'s own `drawn()`/`is_pick_open()` pair already holds.
var _reward_pending: Dictionary = {}

## **Stage 3 (`rune-lock-and-receiving.md`) — which runes the player has been granted.** A set-shaped
## `Dictionary`, the same idiom `_reward_pending` above already holds — presence as a key is the whole fact,
## no separate bool to disagree with it.
##
## **Starts non-empty, at the fixed starting kit** (`_starting_runes()` below) — `Progress` is not the thing
## that decides which rune sits in the seat (`spell_circle.DEFAULT_RUNE` does that), but the player boots
## already owning the none rune, or the palette would veil the very rune the seat starts with.
##
## **This is the actual lock** (Stage B). Change only `spell_circle.DEFAULT_RUNE` and leave this at `{none,
## fire}` and the player presses Tab, fire is unveiled (never locked), and it goes straight into the seat —
## the lock is void and nothing barks (`spell_circle.DEFAULT_RUNE`'s own comment says the same from the other
## side). Fire has to be **earned**, not merely absent from the seat.
##
## **Private, like `_reward_pending`** — `net_pick._no_pushed_out_glyph_is_stashed_anywhere` scans every `.gd`
## file for a top-level `Array`/`Dictionary` field not on its own hardcoded allowlist (the no-inventory
## decision, `docs/decisions/no-inventory.md`). `grant_rune()`/`owns_rune()` below are the only door in or out.
var _owned_runes: Dictionary = _starting_runes()

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
		# **The level door** (`docs/decisions/gems-from-bosses-and-levels.md`). It rides the same
		#  loop as `pending_picks` on purpose: one crossing = one pick = one 원석, so a single big
		#  award that crosses two thresholds pays both, and neither can drift from the other.
		gems += GEMS_PER_LEVEL


## **The boss door.** Called on a boss's death, the same place `set_boss_reward_pending()` is (`world_step`),
##  because the GDD's "Drops" makes them the same event.
##
## **The roll happens here, not at the call site.** `_rng` is this object's own stream (its own comment: not
##  the engine's shared global RNG), and a caller rolling for itself would either reach for `randi()` — which
##  perturbs anything else in the process using it — or need a second generator whose seeding nobody owns.
##  ⇒ The one place that holds the numbers is the one place that rolls them.
## **Returns what it gave**, so a settlement screen can show the number without re-deriving it.
func add_boss_gems() -> int:
	var n := _rng.randi_range(GEMS_PER_BOSS_MIN, GEMS_PER_BOSS_MAX)
	gems += n
	return n


func add_money(amount: int) -> void:
	money += amount


## **Stage I — called once, from `WorldStep`'s own death handling, the instant a boss's hp crosses 0.**
## `stage1-bosses.md`'s own words: "boss death sets a reward-pending flag." **Only for kinds that actually
## have a reward** (`BossAi.has_pattern(kind)` at the call site) — a trash mob calling this would put a key in
## the dict that nothing would ever clear, since no debug key targets a kind that isn't a boss.
func set_boss_reward_pending(kind: int) -> void:
	_reward_pending[kind] = true


## Is `kind`'s reward still pending. `false` for a kind that never died at all, same as one already cleared —
## a caller gating water on "has died AND reward taken" needs `boss_died(kind)` too, below; this alone only
## answers "would taking the reward right now do anything".
func is_reward_pending(kind: int) -> bool:
	return _reward_pending.get(kind, false)


## Has `kind` ever died this session — the other half of "reward pending" (`is_reward_pending` alone cannot
## tell "never died" from "died, reward taken long ago", both read `false`). Presence as a *key* in
## `_reward_pending` carries this, not the stored value.
func boss_died(kind: int) -> bool:
	return _reward_pending.has(kind)


## **The debug key's own door** (`stage1-bosses.md`: "the only thing that clears it in this build is a shell
## debug key... standing in for a decision the user has explicitly left open"). Clears whichever boss rewards
## are currently pending, all at once — the real game will only ever have at most one rune slot pending
## regardless (the GDD's own "assembly window"), so there is no reason for the debug key to target one kind
## over another. **A no-op if nothing is pending** — pressing it before any boss has died, or after the reward
## was already taken, changes nothing.
func clear_pending_boss_rewards() -> void:
	for kind: int in _reward_pending.keys():
		_reward_pending[kind] = false


## **The fixed starting kit** (`rune-lock-and-receiving.md`, Stage B) — **none, and only none.** Independent of
## whatever `spell_circle.DEFAULT_RUNE` currently is (that constant only says which rune sits in the seat, not
## which the player is allowed to place there). Both `_owned_runes`'s field default and `reset()` call this
## **one** function — write it as a literal in both places and a future retune of the kit only updates one of
## them, and the day the field and `reset()` disagree, R would hand back a different kit than a fresh boot.
static func _starting_runes() -> Dictionary:
	return {Tuning.ELEM_NONE: true}


## **Stage 3 — the bull's reward (Stage C) calls this.** Granting an already-owned rune is a harmless no-op,
## the same Dictionary-assignment idiom `set_boss_reward_pending` already holds for a redundant call.
func grant_rune(rune_id: int) -> void:
	_owned_runes[rune_id] = true


## Does the player own `rune_id`. **The palette asks this** (`circle_window._slot_accepts`) to veil a rune
## nobody has been given yet — an unowned rune is drawn but not pickable, not filtered out of the palette
## entirely (`rune-lock-and-receiving.md`: "veiled, not hidden").
func owns_rune(rune_id: int) -> bool:
	return _owned_runes.get(rune_id, false)


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
	_reward_pending.clear()
	# **`gems` is not here, and its absence is the point.** It is the one permanent thing this object holds
	#  (its own box above) — the town's whole reason to exist is that something survives the run.
	#  `net_progress` measures that it survives, so deleting this comment and adding the line goes red.
	# **Reverts to the starting kit, not to empty** — a stage reset (R) is a fresh run, and a fresh run boots
	#  owning only none (`_starting_runes()`'s own comment), the same fixed kit `_owned_runes`'s field default
	#  holds. Clearing to `{}` would brick the reset run's own starting rune (risk 2, `circle_window`'s header:
	#  "the rune stays bright and pickable" is the failure this avoids for a different reason here). Any rune
	#  earned mid-run (fire, from the bull) does **not** survive — a reset is a fresh run, not a checkpoint.
	_owned_runes = _starting_runes()
