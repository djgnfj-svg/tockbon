class_name Run
extends RefCounted
## The phase machine: TITLE -> PLAY -> ENDING -> (TITLE or PLAY again). Nothing here touches the tree —
## a net drives it with `.new()`, same as everything else under `sim/`.
##
## **`start()` and `restart()` always build a brand-new `World`.** Reusing one and calling `setup()` again
## is how state leaks between runs — `World` has twenty mutable fields and a missed one is a silent bug
## that only shows on the second run, which is the run nobody tests.
##
## **`paused` is the only pause in the game.** `step()` skips `world.step()` while it is set; the shell
## sets it and keeps no copy of its own. `World::step`'s `pending_levels` guard is a different sentence —
## the sim refusing to advance past an unspent level, not "a panel is open". **`Tab` is its one setter**:
## one flag with one owner is what stops a second early return appearing in `World::step()`, where a panel
## opening and a panel closing would then have to agree across two files.

enum Phase { TITLE, PLAY, ENDING }
enum Outcome { NONE, CLEARED, DIED }

var phase: int = Phase.TITLE
var outcome: int = Outcome.NONE
var world: World = null          ## null while TITLE. Built fresh by start()/restart()
var result := RunResult.new()    ## only meaningful in ENDING
var paused := false              ## the ONE pause flag in the game

var seed_used := 0               ## the seed the current (or most recently ended) world was built with

## Counts down during the great absorption. Positive means a CLEARED ending was detected but has not
## flipped `phase` yet — see step()'s early branch and Outcome's latch below.
var absorb_beat := 0.0


func start(run_seed: int) -> void:
	_open(run_seed)


## From ENDING, without passing through TITLE — 다시 하기 is another run, not a retry of the same ground.
func restart(run_seed: int) -> void:
	_open(run_seed)


func to_title() -> void:
	phase = Phase.TITLE
	world = null


## PLAY only. The end is detected here, in this order, and nowhere else: death, then clear.
func step(dt: float) -> void:
	if phase != Phase.PLAY or paused:
		return
	if absorb_beat > 0.0:
		# The latch is this shape, not a flag: while the beat runs, host_hp is never read below, so being
		# hit mid-beat cannot rewrite a clear into a death.
		absorb_beat -= dt
		world.step(dt)
		# `swarm.count <= 1` is the swarm actually finishing early, because `Swarm._clear_arrivals()`
		# removes each body the moment it arrives instead of waiting for the beat's own clock — a scattered
		# swarm was converging well inside CLEAR_ABSORB_TIME and then sitting still for what was left of it.
		# `absorb_beat <= 0.0` stays as the cap for the rare straggler `_finish_clear()`'s own fallback
		# loop still exists for (a clone the pull never quite closed the gap on in time).
		if world.swarm.count <= 1 or absorb_beat <= 0.0:
			_finish_clear()
		return
	world.step(dt)
	if world.host_hp <= 0:
		_end(Outcome.DIED)
	elif world.stage_cleared:
		_begin_clear()


func _open(run_seed: int) -> void:
	world = World.new()
	world.setup(run_seed)
	seed_used = run_seed
	phase = Phase.PLAY
	outcome = Outcome.NONE
	absorb_beat = 0.0
	# `Tab` sets `paused` and the shell does not close the panel on the run ending. Without this line,
	# ending a run with the body panel open and hitting 다시 하기 opens the new run frozen.
	paused = false


func _end(o: int) -> void:
	outcome = o
	phase = Phase.ENDING
	_snapshot()


## Starts the great absorption. Levels stop being granted the instant this runs — a level earned by
## eating the boss would open three cards on top of the ending, since `World::step()` freezes on
## `pending_levels > 0`. Whatever is pending is dropped.
func _begin_clear() -> void:
	outcome = Outcome.CLEARED
	absorb_beat = Rules.CLEAR_ABSORB_TIME
	world.swarm.clear_pull = true
	world.beat_frozen = true   ## also stops the ecosystem stepping — see the field's own doc in world.gd
	world.pending_levels = 0
	world.offer = PackedInt32Array()
	_snapshot()   ## result.elapsed is stamped at DETECTION — the beat is not part of the player's time


## Bodies removed here bank their cargo; bodies removed by dying do not — that asymmetry is the whole
## point of `carried` living in a packed array (`Swarm`'s own header). Banking is NOT eating: this cargo
## was already counted into `swarm.eaten` at the moment it was picked up, so it must not go through
## `swarm.eat()` again here.
func _finish_clear() -> void:
	# Backwards: remove_at() swaps the last row down, and a forward walk would skip whatever landed there.
	for i in range(world.swarm.count - 1, 0, -1):
		# Force comes home too — the same line `Swarm.absorb()` and `Swarm._clear_arrivals()` carry. This
		# is the third of the three paths that bring a body home, and for a while it was one of the two
		# that dropped force on the floor while `V` kept it.
		world.swarm.force[0] += world.swarm.force[i]
		world.swarm.banked += world.swarm.carried[i]
		world.swarm.carried[i] = 0.0
		world.swarm.remove_at(i)
	world.swarm.clear_pull = false
	outcome = Outcome.CLEARED
	phase = Phase.ENDING


func _snapshot() -> void:
	result = RunResult.new()
	result.outcome = outcome
	result.elapsed = world.elapsed
	result.experience = roundi(world.swarm.eaten)
	result.cargo_lost = roundi(world.cargo_lost)
	result.peak_swarm = world.peak_swarm
	result.clones_lost = world.clones_lost
	# species and body_slots stay at RunResult's empty defaults — plan 4 and plan 3 are what fill them.
