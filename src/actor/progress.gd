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
const UnlockDefs := preload("res://src/actor/unlock_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")

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

## **The run-end settlement screen's three numbers** (`run-end-settlement.md`, Stage A).
##  `run_ticks` moves once per 20Hz tick (`advance_tick()`, called from `WorldStep.frame()`'s tick branch —
##  not once per 60Hz frame, or play time would read 3x). `damage_dealt` is the sum of `Monster.take_dealt()`
##  across both hp-removal paths (direct hit/blast and `_burn`) — see that file's own header for why "one
##  place" was wrong. Both revert to 0 in `reset()`, the same as `xp`/`level`/`money`.
var run_ticks := 0
var damage_dealt := 0

## **Snapshot of `gems` at the moment this run began, taken inside `reset()`** — the one place that means
##  "a run begins" (the gate, `R`, and going home all route through `WorldStep.reset()` -> this). `gems` itself
##  survives `reset()` (its own comment below); this field is what lets `gems_this_run()` read only the
##  current run's earnings instead of every previous run's total. Setting it anywhere else (e.g. the departure
##  gate) would be a second place, and a mid-run `R` would then measure a delta across a run that no longer
##  exists (`run-end-settlement.md`'s own reasoning for why this must live here).
var _gems_at_run_start := 0
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
## **What spends it is `buy()` below** (`research-bench-unlocks.md`) — three unlocks at
##  `GEMS_PER_UNLOCK` each, which at 9~11 a full run is roughly one unlock per run. Until that feature there
##  was deliberately no sink at all, and this box said so: a counter that goes up with nothing to spend it on
##  is honest, a buy button that took a number and gave nothing back is the fake.
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

## **What one unlock costs — the user's number, and it sits beside the two that pay it out on purpose.**
##  Earn and spend in one file, so "is the pace right" is a question you can answer by reading eleven lines
##  rather than by opening two. At 9~11 원석 a full run this is **about one unlock per run**, the shape the
##  user picked ("한 번 갔다 오면 하나 열린다"). `town.md`'s 원석 section — its old "three per unlock"
##  arithmetic is void, having been written when a run yielded 1~2.
##  **Named, not line-numbered.** This cited a line number in town.md and landed on the wrong paragraph the moment that
##  file's header grew by four lines: **a line number is a path into a file**, and it rots exactly the way
##  the GDD's "name docs, don't path them" rule (`GDD.md`, "Natural law") says a folder path does.
## **The whole sink is three purchases (30).** After that the counter climbs with nothing to spend on again;
##  widening it is the dice axis's job, not this constant's.
const GEMS_PER_UNLOCK := 10

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
## **This default stays `_starting_runes()` and must NOT become `_run_start_runes()`, even though `reset()`
## now uses the latter.** GDScript initialises fields in declaration order, and `_unlocked` (declared below)
## does not exist yet at this point — folding purchases in here would read an empty set at best. It is also
## correct on its own terms: a freshly constructed `Progress` has bought nothing, so the two functions agree
## at boot anyway. The place the fold actually has to happen is `reset()`, where a *later* run begins.
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

## **Stage 2 (`onboarding-and-palette-tabs.md`) — which circles the player has been granted.** The same
## set-shaped `Dictionary` idiom as `_owned_runes` above, for the same reason: presence as a key is the
## whole fact. **삼각 is not owned at boot — the user confirmed it explicitly.** Only 동그라미 sits in the
## starting kit (`_starting_circles()` below), so the 진 tab shows one cell until a circle is granted by
## some future door (none exists yet — this stage only has to stop hiding the question, the same
## "skeleton first" `docs/design/` already allows for a TBD reward path).
##
## **Private, like `_owned_runes`** — `net_pick._no_pushed_out_glyph_is_stashed_anywhere` scans every
## `.gd` file under `src/` for a class-level `Array`/`Dictionary` not on its own allowlist
## (`docs/decisions/no-inventory.md`). This field is on that allowlist deliberately, the same argument
## `_owned_runes`'s own entry there makes: it is a record of what has been granted, not a glyph that left
## a spell layer. `grant_circle()`/`owns_circle()` are the only doors in or out.
var _owned_circles: Dictionary = _starting_circles()

## **What has been bought at the research bench — permanent, and the second thing here that survives
##  `reset()`** (`research-bench-unlocks.md`). Set-shaped, keyed by `UnlockDefs` id, the
##  same idiom `_reward_pending` and `_owned_runes` above already hold.
##
## **One set, not one field per axis.** Had the double jump been its own `var _unlocked_double_jump := false`,
##  `reset()` would have **two** things to not clear instead of one, and a bare bool is invisible to
##  `net_pick`'s stash scan — so the second one would be protected by nothing at all. One collection means one
##  thing to protect and one inverted check protecting it.
##
## **`reset()` does not mention this field, and that absence is the whole feature.** Adding `_unlocked.clear()`
##  there erases every purchase of every past run at once and **nothing barks** — the player simply finds the
##  bench empty again. `net_research` measures the survival by value, so adding that line goes red, exactly
##  the way adding `gems = 0` already does.
##
## **Private, like `_reward_pending` and `_owned_runes`** — `net_pick._no_pushed_out_glyph_is_stashed_anywhere`
##  scans every `.gd` under `src/` for a class-level `Array`/`Dictionary` not on its own allowlist
##  (`docs/decisions/no-inventory.md`). This field is **on that allowlist deliberately**, not missed by a
##  widened regex: it is a record of what has been bought, not of a glyph that left a spell layer — the same
##  argument `_owned_runes`'s own entry there makes. `can_buy()`/`buy()`/`air_jump_budget()` are the only
##  doors in or out.
var _unlocked: Dictionary = {}

## **Empty = no pick is open.** Not a separate bool — a bool and a list can disagree (open with nothing
##  drawn, or drawn but marked closed), and this repo has already been burned by exactly that shape of state
##  duplication once (`docs/decisions/no-inventory.md`'s whole argument against a stash is the same one).
var _drawn: Array[int] = []
## **A fresh generator per `Progress` instance, not the engine's shared global RNG** (`randi()`/`randf()`).
##  `src/actor/` allows non-determinism (GDD multiplayer table — this is host-authoritative state, not
##  lockstep), but the global RNG's stream is shared with anything else in the process that calls it, so a
##  net seeding it for one check could quietly perturb another. Each `Progress` owns its own stream instead.
var _rng := RandomNumberGenerator.new()

## **Stage 7 (`onboarding-and-palette-tabs.md`) — has the player already been walked through the tab strip
## once.** `stage.gd` reads this to decide whether `_leave_town()` starts the onboarding step machine.
## **Survives `reset()` and `next_stage()` both, deliberately** — the same discipline `gems`/`_unlocked`
## already hold one level up (a pool instead of a single fact): clearing it on `R` would show the
## walkthrough again on every reset, which reads as a broken tutorial, not a fresh run.
##
## **A bare `bool`, not a set-shaped `Dictionary`.** There is nothing here to enumerate and no way for this
## single fact to grow into a stash, so `net_pick._no_pushed_out_glyph_is_stashed_anywhere` (which scans
## only `Array`/`Dictionary` fields) does not need an allowlist entry for it — a scalar cannot hide a glyph
## the way a collection could. `mark_onboarding_seen()`/`has_seen_onboarding()` are still the only doors,
## the same paired-accessor shape `_owned_runes` holds, so nothing outside this file pokes the field raw.
var _onboarding_seen := false


func has_seen_onboarding() -> bool:
	return _onboarding_seen


func mark_onboarding_seen() -> void:
	_onboarding_seen = true


## **The other onboarding beat — "마을 + 레벨업 했을 때만 있으면 됨" (user decision).** The assembly
## walkthrough above teaches the circle; this one teaches the door into `pending_picks` (P), which a first
## level-up otherwise hands the player with no indication of how to open it. Same shape as
## `_onboarding_seen` right above it for the same reason: **a bare `bool`, not a step machine** — there is
## nothing to advance through, only "has P been pressed with a pick waiting, ever" — and it **survives
## `reset()` and `next_stage()` both**, deliberately, the same discipline that keeps `_onboarding_seen` from
## replaying on every `R` (`reset()`'s own comment on that field).
var _pick_onboarding_seen := false


func has_seen_pick_onboarding() -> bool:
	return _pick_onboarding_seen


func mark_pick_onboarding_seen() -> void:
	_pick_onboarding_seen = true


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


## Called once per 20Hz tick, from `WorldStep.frame()`'s tick branch — **not** from the 60Hz `step()` loop,
##  the same distinction `Monster.on_tick`/`step()` already hold, or play time would read 3x actual.
func advance_tick() -> void:
	run_ticks += 1


## `n` is hp actually removed from a monster, already summed across both removal paths by
##  `Monster.take_dealt()` — this function only adds, it does not re-derive what counts as damage.
func add_damage(n: int) -> void:
	damage_dealt += n


## **This run's earnings only** — `gems` itself holds every run's total (it survives `reset()`), so reading it
##  raw here would count a previous run's pool too. `run-end-settlement.md`, acceptance 7.
func gems_this_run() -> int:
	return gems - _gems_at_run_start


## Play time in whole seconds. `run_ticks` moves at 20Hz (`60 / Tuning.TICK_DIVIDER`, the same conversion
##  `stage.gd`'s own HUD line uses) — dividing by the frame rate instead would read 3x too fast.
func run_seconds() -> int:
	return run_ticks / (60 / Tuning.TICK_DIVIDER)


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
## which the player is allowed to place there). Written as a literal in two places, a future retune of the kit
## would update only one, and the day the field and `reset()` disagree R hands back a different kit than a
## fresh boot.
##
## **`reset()` no longer calls this directly — it calls `_run_start_runes()`, which calls this.** The kit is
## still stated in exactly one place; what changed is that a run now begins with the kit **plus what has been
## bought** (`research-bench-unlocks.md`). Do not "restore" `reset()` to calling this function: that strips
## every purchased rune out on the way through the departure gate, silently.
static func _starting_runes() -> Dictionary:
	return {Tuning.ELEM_NONE: true}


## **The fixed starting kit for circles — 동그라미 only** (`onboarding-and-palette-tabs.md`, the user's own
## "삼각진은 안 가지고 있다"). The same shape as `_starting_runes()` above, for the same reason: written as
## a literal here rather than derived from `CircleDefs.ALL`, so a future circle added to that table does
## not appear owned by accident the day it lands.
static func _starting_circles() -> Dictionary:
	return {CircleDefs.CIRCLE_ROUND: true}


## **Stage 3 — the bull's reward (Stage C) calls this.** Granting an already-owned rune is a harmless no-op,
## the same Dictionary-assignment idiom `set_boss_reward_pending` already holds for a redundant call.
func grant_rune(rune_id: int) -> void:
	_owned_runes[rune_id] = true


## Does the player own `rune_id`. **The palette asks this** (`circle_window._slot_accepts`) to veil a rune
## nobody has been given yet — an unowned rune is drawn but not pickable, not filtered out of the palette
## entirely (`rune-lock-and-receiving.md`: "veiled, not hidden").
func owns_rune(rune_id: int) -> bool:
	return _owned_runes.get(rune_id, false)


## **Stage 2 — the same door as `grant_rune()` above, for circles.** Granting an already-owned circle is
## a harmless no-op, the same `Dictionary`-assignment idiom.
func grant_circle(circle_id: int) -> void:
	_owned_circles[circle_id] = true


## Does the player own `circle_id`. **The palette asks this** (`palette_layout.items_of`) to leave an
## ungranted circle out of the 진 tab entirely — the reversed rule from runes' "veiled, not hidden"
## (`docs/decisions/palette-hides-what-you-do-not-own.md`): what you do not have has no cell at all.
func owns_circle(circle_id: int) -> bool:
	return _owned_circles.get(circle_id, false)


## **Is this unlock buyable at all — asked of the catalogue and of what is already bought, never of
##  `owns_rune()`.** That distinction is the feature's sharpest edge: the bull grants 불 mid-run
##  (`stage.gd`'s boss reward), so `owns_rune(불)` is true while nothing has been bought. Guarding on
##  ownership would **refuse a legitimate purchase** — and read the other way round, it would let a granted
##  rune count as bought and survive `reset()` for free, which is exactly the permanence the player is
##  paying 10 원석 for.
## **It does not look at `gems`.** Affordability is a separate question with a separate answer on screen (a
##  dim chip, not a missing one), so `buy()` asks both and this asks one.
func can_buy(unlock_id: int) -> bool:
	return UnlockDefs.is_for_sale(unlock_id) and not _unlocked.has(unlock_id)


## **The single door onto spending.** Returns whether anything happened; **false moves nothing at all** —
##  a partial spend (원석 gone, unlock not recorded) is unrecoverable and would look exactly like a UI that
##  ate the click.
##
## **It calls `grant_rune()` rather than writing `_owned_runes` itself** —
##  `net_progress._grant_rune_is_the_only_door_in` states that as a contract, and the reason survives here:
##  the rune becomes usable **this instant**, so the town's assembly bench can show it on the same visit
##  rather than only after the next departure. That immediacy changes nothing about *runs*, because the
##  bench is reachable only in town (`stage._interact()` returns early when not in town, and `_build_room()`
##  closes the window on every room switch) — a purchase can never happen mid-run, so "the run after the
##  purchase" is the next one either way.
func buy(unlock_id: int) -> bool:
	if not can_buy(unlock_id) or gems < GEMS_PER_UNLOCK:
		return false
	gems -= GEMS_PER_UNLOCK
	_unlocked[unlock_id] = true
	var rune := UnlockDefs.rune_of(unlock_id)
	if rune >= 0:
		grant_rune(rune)
	return true


## Has `unlock_id` been bought. **Not `owns_rune()`** — see `can_buy()`'s box for why the two must never be
##  read as the same question.
func is_unlocked(unlock_id: int) -> bool:
	return _unlocked.has(unlock_id)


## **How many air jumps the character gets. 0 or 1 — a function, never a stored number.**
##
## `stage._physics_process` re-derives `_char.air_jump_budget` from this every frame, immediately before the
##  world steps. **Immediate is the absence of a latch**: there is no purchase hook and no reset hook, and so
##  there is no hook to forget. This is the repo's own "derive, do not push" rule, the same one
##  `gate_view._process` states for `visible` ("hold a second flag here and the arch can go stale") and
##  `stage._build_room` states for `_town_view.visible`.
## **The return type is `int` and not `bool` so the budget can grow** — but nothing sells a second air jump
##  and the catalogue has no row for one, so today it is only ever 0 or 1.
func air_jump_budget() -> int:
	return 1 if _unlocked.has(UnlockDefs.UNLOCK_DOUBLE_JUMP) else 0


## **The rune set a run begins with — the fixed starting kit plus whatever has been bought.**
##
## **An instance method, not a `static` like `_starting_runes()`**, because it reads `_unlocked`. The two are
##  a pair on purpose: `_starting_runes()` stays the one place that says what a *fresh boot* owns, and this
##  is the one place that folds permanence into it. Inline either into `reset()` and the field default and
##  the reset would hand out different kits.
func _run_start_runes() -> Dictionary:
	var out := _starting_runes()
	for id: int in _unlocked:
		var r := UnlockDefs.rune_of(id)
		if r >= 0:
			out[r] = true
	return out


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


## **Walking from one stage into the next — the run does not end, so almost nothing here reverts.**
## Called by `WorldStep.next_stage()`, the sibling of `reset()` below and the same "one call site" discipline.
##
## **This function is a list of what a stage owns, and it is deliberately two lines long.** A run is
##  `town -> 1 -> 2 -> 3` (GDD's session loop), so **xp, level, money, `pending_picks`, `run_ticks`,
##  `damage_dealt`, `gems`, `_unlocked`, `_owned_runes`, `_owned_circles`, `_onboarding_seen`,
##  `_pick_onboarding_seen` and `_gems_at_run_start` all carry across.** Reaching
##  for `reset()` here instead — which is the obvious thing to do, since the shell already had exactly one
##  rebuild path — **strips every 원석 and every unlock earned in stage 1 the instant you walk into stage 2,
##  with nothing barking.** That is the single most dangerous edit that could be made to this file.
##
## **`_reward_pending` is what a stage owns.** Presence as a key *is* "this boss has died" (its own box
##  above), and `stage.gd`'s ending term and `gate_view`'s `visible` both read it — carried across, stage 2's
##  arch would be lit and its east wall already down on the frame you arrive, and stepping on its seat would
##  end the run instantly. **The rune the bull granted is not lost with it**: that lives in `_owned_runes`,
##  which this does not touch, so the reward survives while the "who has died here" record does not.
##
## **`_drawn` is cleared, `pending_picks` is not.** The open draw belongs to the stage you are leaving (the
##  shell closes every other window on a room build); the *unclaimed pick* is a reward and follows you.
func next_stage() -> void:
	_reward_pending.clear()
	_drawn.clear()


## Called by `WorldStep.reset()` — **not by `stage.gd` directly**, the same discipline that keeps the queue
##  and the fire count reverting in one place (`world_step.gd`'s own `reset()` comment). A second call site
##  here would be the same trap: touch it in two places and the day only one gets fixed, R quietly stops
##  reverting progress.
##
## **`next_stage()` above is the other door and it is not this one.** A stage transition is inside a run.
## `_rng` is **not** reseeded — a stage reset is not a reason to make the next draw deterministic again.
func reset() -> void:
	xp = 0
	level = 0
	money = 0
	pending_picks = 0
	run_ticks = 0
	damage_dealt = 0
	_drawn.clear()
	_reward_pending.clear()
	# **`gems` is not here, and its absence is the point.** It is one of the two permanent things this object
	#  holds (its own box above) — the town's whole reason to exist is that something survives the run.
	#  `net_progress` measures that it survives, so deleting this comment and adding the line goes red.
	# **`_unlocked` is not here either, for the same reason and with more at stake.** `gems = 0` here would
	#  cost the player one run's earnings; `_unlocked.clear()` here would erase **every purchase ever made**,
	#  silently, and the bench would simply look empty again. `net_research` measures its survival across
	#  this call by value, for a rune unlock and for the double jump separately.
	# **`_gems_at_run_start` is re-snapshotted here, every time.** `reset()` is the one place that means "a
	#  run begins" — a second reset call site added later that forgets this line would leave the settlement
	#  screen's delta silently reading against a stale snapshot (`run-end-settlement.md`'s own Risk 5).
	_gems_at_run_start = gems
	# **Reverts to the starting kit, not to empty** — a stage reset (R) is a fresh run, and a fresh run boots
	#  owning only none (`_starting_runes()`'s own comment), the same fixed kit `_owned_runes`'s field default
	#  holds. Clearing to `{}` would brick the reset run's own starting rune (risk 2, `circle_window`'s header:
	#  "the rune stays bright and pickable" is the failure this avoids for a different reason here). Any rune
	#  earned mid-run (fire, from the bull) does **not** survive — a reset is a fresh run, not a checkpoint.
	# **A *bought* rune does survive, and that is the whole difference between a grant and a purchase**
	#  (`research-bench-unlocks.md`): `_run_start_runes()` is `_starting_runes()` with the permanent set
	#  folded in. Write `_starting_runes()` here instead and every rune the player paid 10 원석 for is stripped
	#  out on the way through the departure gate, with nothing barking.
	_owned_runes = _run_start_runes()
	# **Reverts to the starting kit, the same as `_owned_runes` above** — there is no purchase axis for
	#  circles yet (no `UnlockDefs` row grants one), so there is no permanent set to fold in and no
	#  `_run_start_circles()` pair to write. The day a circle can be bought or earned permanently, this line
	#  needs the same split `_owned_runes`/`_run_start_runes()` already draws.
	_owned_circles = _starting_circles()
	# **`_onboarding_seen` is not here, and its absence is the point** — the same reasoning `gems`/`_unlocked`
	#  give above, one level down to a single fact instead of a pool. Clearing it on every `R` would show the
	#  onboarding walkthrough again on every reset, which reads as the tutorial being broken, not as a fresh
	#  run. `net_progress` measures that it survives `reset()` and `next_stage()` both, by value.
	# **`_pick_onboarding_seen` is not here either, for the identical reason** — the level-up hint's own
	#  header states it survives both doors; clearing it here would be the same tutorial-looks-broken bug
	#  one field over.
