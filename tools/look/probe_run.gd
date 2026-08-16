extends SceneTree
## A throwaway instrument: **can one person play a run from second zero to the boss?**
##
## `probe_field.gd` measures the opening FRAME — what is standing there and how far away. It cannot measure
## the sentence the user actually said, 「보스까지 원 세션을 하고 싶은데 도저히 게임이 진행이 안 돼」, because
## that sentence is about a hundred and fifty seconds and not about one. This one PLAYS the run: it drives
## the real shell, takes the title's own `start_pressed` signal, and then holds a scripted stick until the
## host is dead or `Rules.BOSS_HUNT_AT` has passed.
##
## Headless is correct here — **no pixels are read**, only numbers. No window opens and it quits itself.
##
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tools/look/probe_run.gd
##   ... -- seed=123 attempts=3     ## same two knobs, pinned
##   ... -- check                   ## the instrument's own three known-answer controls
##
## ⚠ **It is an instrument, so `CLAUDE.md`'s rule about inverting the INSTRUMENT binds it.** `check` runs
## three staged fields whose answers are known before the run starts — an empty one that must come back
## 진행 불가, a ring of lions that must come back 죽었다, and one squirrel at a time that must come back
## 진행 가능. **Two directions, deliberately**: a probe that can only ever say 「못 한다」 passes the first
## two controls and is worth nothing. The empty field is the exact case this file's brief named — surviving
## a field with nothing in it must NOT read as playable, which is why the verdict is three tests and not one.
##
## ⚠ **The camera is 1280x720 at `Look.ZOOM_NEAR` 1.6, so the screen is 800x450 WORLD pixels.**
## `project.godot` stretches a 1280x720 viewport into a 1920x1080 window (`canvas_items`), so the window's
## size is not the world's. `probe_field.gd` assumes a 1920x1080 box and therefore reports a screen **5.76x
## too large in area**; the real one is printed at boot so the difference cannot be inherited silently. That
## file is deliberately left alone — its numbers are already in circulation this session, and a measurement
## that quietly moves another instrument's output under the people reading it is worse than a loud one.

# -- the clock ---------------------------------------------------------------------------------------
## The shell runs on the render clock; this runs on a fixed one so two launches with one seed agree.
const STEP_DT := 1.0 / 60.0
const SAMPLE_EVERY := 15.0
## Enough attempts that 「몇 번 죽었나」 is a number rather than a coin flip.
const ATTEMPTS := 3
const SEED_BASE := 20260816

# -- the policy --------------------------------------------------------------------------------------
## How close a thing that would one-shot the host has to be before the stick turns around. Every hunter in
## the build is under `Rules.HOST_SPEED`, so walking away always works and this only has to fire in time.
const FLEE_DIST := 300.0
## Left click. `Body.setup()` opens with 물기 on it and this probe never rebinds anything.
const BITE_KEY := 0
## Frames between `await process_frame`. Nothing here reads a pixel, so the loop does not need its own
## rendered frame — but a completely await-free run of thirty thousand iterations never yields at all.
const YIELD_EVERY := 900

# -- the verdict's own thresholds --------------------------------------------------------------------
## ⚠ **These are the INSTRUMENT's numbers, not the design's.** Nothing in the repo says how much dead air a
## run may carry; they exist so that 「진행 가능」 is a judgement with a stated bar rather than a feeling,
## and so that surviving an EMPTY field cannot read as a pass. Change them and say so.
const DEAD_AIR_MAX := 0.25      ## fraction of the run with nothing takeable on screen
const KILL_GAP_MAX := 30.0      ## seconds between kills

## One letter per species, in `Parts.Species` order, so the kill column fits a console row. The long names
## are `Parts.SPECIES_NAME` and this is deliberately not a second copy of them — it is an abbreviation of
## the same list, and `_kills_str()` asserts the two are the same length before using it.
const SHORT := ["까", "말", "보", "다", "코", "치", "사", "쥐", "토", "개", "멧"]

var _main: Node = null
var _seed := SEED_BASE
var _attempts := ATTEMPTS
## "" for the real field. One of the three staged controls otherwise — see `_stage()`.
var _control := ""
var _stage_angle := 0.0

## One attempt's accumulation, reset by `_play()`.
var _kills := PackedInt32Array()
var _dead_air := 0.0
var _gap_now := 0.0
var _gap_max := 0.0
var _win_had_target := false


func _initialize() -> void:
	var want_check := false
	for a in OS.get_cmdline_user_args():
		if a == "check":
			want_check = true
		elif a.begins_with("seed="):
			_seed = int(a.substr(5))
		elif a.begins_with("attempts="):
			_attempts = maxi(1, int(a.substr(9)))
	if not await _boot():
		quit(1)
		return
	if want_check:
		await _known_answers()
	else:
		await _session("실제 필드", _attempts)
	quit(0)


## The real path in — `main.gd`'s own `_ready()` builds every child, and the title's own signal is what
## starts the run. A private starter called directly would hide the shell's `connect()` line.
func _boot() -> bool:
	_main = load("res://src/shell/main.gd").new()
	root.add_child(_main)
	await _frames(4)
	_main.title.start_pressed.emit()
	await _frames(4)
	if _main.run.phase != Run.Phase.PLAY:
		printerr("[플레이] 시작 신호가 PLAY로 안 갔다 — 아래 숫자는 전부 무효다")
		return false
	# `main._process` is the one caller of `run.step()`, and this file calls it by hand instead: the shell's
	# input phase polls the real `Input` singleton, which is empty headless, so the host would stand still for
	# a hundred and fifty seconds and the probe would report the field's emptiness as the policy's.
	_main.set_process(false)
	_main.set_process_unhandled_key_input(false)
	# The two views consume one-frame lists that `World.begin_frame()` clears. Nothing here reads a pixel, so
	# they are switched off rather than driven — left on the engine's clock they would drain the death list
	# this file counts kills out of.
	_main.view.set_process(false)
	_main.hud.set_process(false)
	print("\n[플레이] 화면은 %s 월드픽셀 (뷰포트 %s ÷ 줌 %.2f)"
			% [str(_main._true_camera_rect().size), str(_main.get_viewport_rect().size), Look.ZOOM_NEAR])
	print("         probe_field 는 1920x1080 을 가정한다 — 면적으로 5.76배 크다")
	return true


# -- a session: N attempts on one field ------------------------------------------------------------------

func _session(label: String, attempts: int) -> Dictionary:
	var reached := 0
	var deaths := 0
	var dead_air := 0.0
	var lived := 0.0
	var gap := 0.0
	var kills := PackedInt32Array()
	kills.resize(Parts.SPECIES_NAME.size())
	print("\n=== %s ===" % label)
	print("  정책: 한 방에 안 죽고 · 호스트보다 안 빠르고 · 죽기 전에 죽일 수 있는 것만 노린다.")
	print("        시체가 발밑에 있으면 서서 먹는다. 한 방에 죽일 수 있는 것이 %.0fpx 안에 오면 물러난다."
			% FLEE_DIST)
	print("        F·V·1·3 은 한 번도 안 누른다 — 혼자 걸어가서 좌클릭하는 손 하나뿐이다.")
	for n in attempts:
		var r := await _play(_seed + n, n + 1)
		if bool(r["reached"]):
			reached += 1
		if bool(r["died"]):
			deaths += 1
		dead_air += float(r["dead_air"])
		lived += float(r["lived"])
		gap = maxf(gap, float(r["gap"]))
		for s in kills.size():
			kills[s] += int(_kills[s])
	var out := {"reached": reached, "attempts": attempts, "deaths": deaths,
			"dead_air": dead_air, "lived": lived, "gap": gap, "kills": kills}
	_verdict(out)
	return out


## One attempt. Returns what the verdict block sums.
func _play(run_seed: int, nth: int) -> Dictionary:
	# The same two calls 다시 하기 makes, with the seed pinned. `main._start()` seeds from
	# `Time.get_ticks_usec()`, so without this the field is a different one every launch.
	_main.run.restart(run_seed)
	_main._bind_world()
	_kills = PackedInt32Array()
	_kills.resize(Parts.SPECIES_NAME.size())
	_dead_air = 0.0
	_gap_now = 0.0
	_gap_max = 0.0
	_win_had_target = false

	var w: World = _main.run.world
	if _control != "":
		w.critter_count = 0
		w.boss_index = -1
	var next_sample := SAMPLE_EVERY
	var frames := 0
	var cap := int(Rules.BOSS_HUNT_AT / STEP_DT) + 1200
	print("\n  -- 시도 %d (씨앗 %d) --" % [nth, run_seed])
	_header()
	_win_had_target = _nearest_on_screen(w) >= 0.0
	_sample(w)
	while _main.run.phase == Run.Phase.PLAY and w.elapsed < Rules.BOSS_HUNT_AT and frames < cap:
		_tick(w)
		frames += 1
		if w.elapsed >= next_sample:
			_sample(w)
			next_sample += SAMPLE_EVERY
			_win_had_target = false
		if frames % YIELD_EVERY == 0:
			await process_frame
	# The tail counts: a run whose last kill was at second 40 and then walked to 150 has a 110s gap, and
	# waiting for the NEXT kill to close it would report the gap as whatever the last closed one was.
	_gap_max = maxf(_gap_max, _gap_now)
	_sample(w)
	var died: bool = _main.run.phase != Run.Phase.PLAY and _main.run.outcome == Run.Outcome.DIED
	print("     → %s · %.0f초 · 잡은 것 %d마리" % [
			"죽었다" if died else "보스가 오는 시각까지 살았다", w.elapsed, _total_kills()])
	return {"reached": not died and w.elapsed >= Rules.BOSS_HUNT_AT, "died": died,
			"dead_air": _dead_air, "lived": w.elapsed, "gap": _gap_max}


## ONE simulation frame, in the shell's own order and out of the shell's own calls.
##
## ⚠ **`main._read_input()` is deliberately not called** — it polls the real `Input` singleton. Everything it
## writes into `sim` is written by `_policy()` instead, through the same two entry points a key reaches:
## `swarm.host_input` and `World.fire()`.
func _tick(w: World) -> void:
	_main.run.begin_frame()
	_stage(w)
	# The shell's `_sync_cards()` puts the offer on screen and the player clicks it; `_on_card_picked` is the
	# far side of that click and it is the real handler, not a private shortcut. **Before `step()`**, because
	# `World.step()` refuses to advance at all while an offer is standing — the run would freeze here forever.
	if w.pending_levels > 0 and not w.offer.is_empty():
		_main._on_card_picked(w.offer[0])
	_policy(w)
	_main.run.paused = false
	_main.run.step(STEP_DT)
	if _main.run.phase == Run.Phase.PLAY:
		# The shell's own camera writers, in the shell's own order. Driven rather than copied, because
		# 「화면에 몇 마리 있나」 is read off `_true_camera_rect()` and a second copy of the zoom would answer
		# a question about a camera the game does not have.
		_main._follow_camera(STEP_DT)
		_main._apply_shake()
		_main._apply_zoom(STEP_DT)
		_main.view.view_rect = _main._camera_rect()
		_main.hud.camera_rect = _main._true_camera_rect()
	# **Read after `step()` and before the next `begin_frame()`** — that list lives exactly one frame.
	for d in w.critters_died_this_frame:
		var s := int(d["species"])
		if s >= 0 and s < _kills.size():
			_kills[s] += 1
		_gap_max = maxf(_gap_max, _gap_now)
		_gap_now = 0.0
	_gap_now += STEP_DT
	# Dead air is measured ON SCREEN, because that is what the user was describing — 「내가 때릴 수 있는
	# 애가 없고 (…) 그냥 몬스터가 내 주변에 없어」. A takeable creature 1400px away is not an answer.
	if _nearest_on_screen(w) < 0.0:
		_dead_air += STEP_DT
	else:
		_win_had_target = true


# -- the hand ----------------------------------------------------------------------------------------

## The whole scripted player. Three rules, in this order, and nothing else.
func _policy(w: World) -> void:
	var host: Vector2 = w.swarm.pos[0]

	# 1 — back away from anything that would take the host out in one touch.
	var away := Vector2.ZERO
	for k in w.critter_count:
		if _one_touch(w, k) < w.host_hp:
			continue
		var d := host.distance_to(w.critter_pos[k])
		if d > FLEE_DIST:
			continue
		var v: Vector2 = host - w.critter_pos[k]
		if v.length_squared() > 0.0001:
			# Weighted by nearness, so a ring of them resolves toward the widest gap rather than to zero.
			away += v.normalized() / maxf(1.0, d)
	if away.length_squared() > 0.000001:
		w.swarm.host_input = away.normalized()
		return

	# 2 — stand on a corpse in reach. `World._step_corpses()` advances a meal on proximity alone, so the
	# whole of 「먹는다」 is not walking away from it.
	for i in w.corpse_count:
		if host.distance_to(w.corpse_pos[i]) <= w.corpse_reach(i, true):
			w.swarm.host_input = Vector2.ZERO
			return

	# 3 — walk at the nearest thing worth fighting, and bite it when it is inside 물기's own reach.
	var target := _nearest_takeable(w)
	if target < 0:
		w.swarm.host_input = Vector2.ZERO
		return
	var to: Vector2 = w.critter_pos[target] - host
	var aim: Vector2 = w.critter_pos[target]
	# **Computed before the strike and used after it.** `fire()` can kill, and `_remove_critter()` swaps a
	# stranger into row `target` on that same call — reading the position afterwards steers at whoever landed.
	if to.length() <= float(Parts.RANGE[Parts.BITE]) + w.critter_radius(target):
		# Fired every frame it is off cooldown, which is a player clicking perfectly. `Body.fire()` owns the
		# gate, so this is not a second cooldown — it is the ceiling the design allows.
		w.fire(BITE_KEY, aim)
	w.swarm.host_input = to.normalized() if to.length_squared() > 0.0001 else Vector2.ZERO


## What ONE touch from creature `k` actually takes off the host. **Zero for most of the opening field.**
##
## Two rules decide it and the probe used to model NEITHER:
##
## - **A fleeing creature never attacks anything, ever.** `World._contact()`'s second pass returns on
##   `critter_flees` before it looks at a distance, and nothing ever flips that column after `_write_critter`
##   sets it from `Rules.SPECIES_FLEES`. 말 · 다람쥐 · 치타 · 토끼 therefore deal **zero damage for the whole
##   run** — `SPECIES_FLEES`' own comment says so in those words.
## - **`Rules.MAX_HIT_FRACTION` clamps what is left** to a fraction of the victim's CEILING, and
##   `World._capped_hit()` is the one place that arithmetic is written. Raw force is not what arrives.
##
## ⚠ **Written as `critter_force >= host_hp`, this was wrong in the direction that decides the verdict.**
## Measured on the shipped field over six seeds: the hand spent **28–47% of every run walking backwards**,
## most of it away from the eight 말 and one 치타 of the opening layout — creatures that are structurally
## incapable of touching it — and `_takeable()` refused the same rows, so `_nearest_on_screen()` reported
## 「없음」 while something perfectly safe stood on screen. **Both numbers the verdict fails on, dead air and
## the kill gap, are computed out of this one call**, which is why it is driven off `World` rather than
## restated here.
func _one_touch(w: World, k: int) -> int:
	if int(w.critter_flees[k]) == 1:
		return 0
	return w._capped_hit(int(w.critter_force[k]), w.body.hp_max(w.level))


## Is creature `k` something a LONE host can actually take. Three tests, and each is a different reason the
## user could not play:
##  1. one touch does not take the host out — through `_one_touch()`, never through raw force
##  2. it is not faster than the host — the horse and the cheetah are HERDED with the swarm and never
##     chased (`the-horse-is-herded-not-outrun`), and this hand has no swarm, so walking at one is a
##     hundred and fifty seconds of nothing
##  3. the trade closes: the swings it takes to kill it, at 물기's own cooldown, cost less health than the
##     host has
func _takeable(w: World, k: int) -> bool:
	if _one_touch(w, k) >= w.host_hp:
		return false
	if float(Rules.SPECIES_SPEED_MUL[int(w.critter_species[k])]) > 1.0:
		return false
	var f := maxi(1, w.swarm.force[0])
	var swings := int(ceil(float(w.critter_hp[k]) / float(f)))
	var secs := float(swings) * w.body.part_cooldown(Parts.BITE)
	var back := int(floor(secs / Rules.CLONE_ATTACK_PERIOD)) * _one_touch(w, k)
	return back < w.host_hp


## Nearest takeable creature anywhere on the field, or -1.
func _nearest_takeable(w: World) -> int:
	var best := -1
	var best_d := INF
	var host: Vector2 = w.swarm.pos[0]
	for k in w.critter_count:
		if not _takeable(w, k):
			continue
		var d := host.distance_to(w.critter_pos[k])
		if d < best_d:
			best_d = d
			best = k
	return best


## The same question restricted to what the camera actually shows. Distance to the nearest one, or -1.
func _nearest_on_screen(w: World) -> float:
	var box: Rect2 = _main._true_camera_rect()
	var host: Vector2 = w.swarm.pos[0]
	var best := -1.0
	for k in w.critter_count:
		if not box.has_point(w.critter_pos[k]):
			continue
		if not _takeable(w, k):
			continue
		var d := host.distance_to(w.critter_pos[k])
		if best < 0.0 or d < best:
			best = d
	return best


# -- the staged controls -----------------------------------------------------------------------------

## Rewritten every frame on purpose: the point of a control is that the field cannot drift into something
## else while the policy plays it.
func _stage(w: World) -> void:
	match _control:
		"empty":
			w.critter_count = 0
			w.boss_index = -1
		"lions":
			w.critter_count = 0
			w.boss_index = -1
			for m in 8:
				var a := TAU * float(m) / 8.0
				# 30px: inside `critter_reach + BODY_RADIUS` for a lion, so contact is not a matter of luck.
				w._write_critter(int(Parts.Species.LION),
						w.swarm.pos[0] + Vector2(cos(a), sin(a)) * 30.0, 60)
		"squirrels":
			w.boss_index = -1
			# **One at a time, inside 물기's reach, and a 다람쥐 rather than a 까마귀.** A squirrel flees, so
			# `World._contact()`'s second pass returns before it ever hits back — this control is a field
			# where the policy simply cannot be hurt, which is what a POSITIVE control has to be.
			#
			# ⚠ **The crow version of this control failed, and it failed for a reason worth keeping.** Four
			# crows countered the opening host down to 9 hp; `Rules.HP_PER_LEVEL` gives back 3 a level and
			# nothing else in the build heals, so from then on a force-10 crow read as a one-shot threat and
			# the policy fled every crow for the remaining 135 seconds. The instrument was right; the control
			# was not a control.
			#
			# ⚠ **The truncation is the other half, and its absence is what the self-check caught first.**
			# Written as `if critter_count == 0: write one`, `World._spawn_critter()` keeps arriving on its own
			# every `CRITTER_INTERVAL` — the count is then never 0 again, nothing is ever staged after the
			# first, and the control was quietly measuring the ordinary field with a head start.
			w.critter_count = mini(w.critter_count, 1)
			if w.critter_count == 0 or int(w.critter_species[0]) != int(Parts.Species.SQUIRREL):
				w.critter_count = 0
				_stage_angle += 1.1
				w._write_critter(int(Parts.Species.SQUIRREL),
						w.swarm.pos[0] + Vector2(cos(_stage_angle), sin(_stage_angle)) * 60.0, 4)


## Three fields whose answer is known before the run starts, in both directions.
func _known_answers() -> void:
	print("\n########## 계기 자가 점검 — 답을 미리 아는 세 판 ##########")
	_control = "empty"
	var a := await _session("대조 A · 생물이 하나도 없는 필드 — 기대: 진행 불가, 잡은 것 0", 1)
	_control = "lions"
	var b := await _session("대조 B · 사자 여덟에 붙어 둘러싸인 필드 — 기대: 죽는다", 1)
	_control = "squirrels"
	var c := await _session("대조 C · 언제나 다람쥐 한 마리가 발밑에 — 기대: 진행 가능", 1)
	_control = ""

	var a_ok: bool = _total_of(a) == 0 and not _playable(a)
	var b_ok: bool = int(b["deaths"]) >= 1
	var c_ok: bool = _playable(c) and _total_of(c) > 0
	print("\n########## 자가 점검 결과 ##########")
	print("  A 빈 필드    기대 진행 불가·0마리   실제 %s·%d마리   %s"
			% ["진행 가능" if _playable(a) else "진행 불가", _total_of(a), "통과" if a_ok else "실패"])
	print("  B 사자 밭    기대 죽는다            실제 죽음 %d회      %s"
			% [int(b["deaths"]), "통과" if b_ok else "실패"])
	print("  C 다람쥐 밭  기대 진행 가능         실제 %s·%d마리   %s"
			% ["진행 가능" if _playable(c) else "진행 불가", _total_of(c), "통과" if c_ok else "실패"])
	if a_ok and b_ok and c_ok:
		print("  ⇒ 계기는 양쪽으로 다 움직인다. 실제 필드의 숫자를 믿어도 된다.")
	else:
		printerr("  ⇒ 계기가 답을 아는 판에서 틀렸다. 실제 필드의 숫자는 아무 의미가 없다.")


# -- the table ---------------------------------------------------------------------------------------

func _header() -> void:
	print("       초    체력      힘  레벨  무리    경험치  화면안  가장가까운사냥감  잡은것        잡을게있었나")


func _sample(w: World) -> void:
	var nearest := _nearest_on_screen(w)
	var box: Rect2 = _main._true_camera_rect()
	var on_screen := 0
	for k in w.critter_count:
		if box.has_point(w.critter_pos[k]):
			on_screen += 1
	print("   %6.0f  %3d/%-3d %5d %5d %5d %9.0f %6d %14s  %-12s  %s" % [
			w.elapsed, w.host_hp, w.body.hp_max(w.level), w.swarm.force[0], w.level, w.swarm.count,
			w.swarm.banked, on_screen,
			"없음" if nearest < 0.0 else "%.0fpx" % nearest,
			_kills_str(), "예" if _win_had_target else "아니오"])


func _verdict(r: Dictionary) -> void:
	var lived := maxf(0.0001, float(r["lived"]))
	var frac := float(r["dead_air"]) / lived
	var why := PackedStringArray()
	if int(r["reached"]) <= 0:
		why.append("보스까지 못 갔다")
	if frac > DEAD_AIR_MAX:
		why.append("빈 시간이 %.0f%%" % (frac * 100.0))
	if float(r["gap"]) > KILL_GAP_MAX:
		why.append("공백이 %.0f초" % float(r["gap"]))
	var kills: PackedInt32Array = r["kills"]
	var by := ""
	for s in kills.size():
		by += "%s %d  " % [String(Parts.SPECIES_NAME[s]), int(kills[s])]
	print("\n  === 판정 ===")
	print("  보스까지 살아서 갔는가       : %s (%d/%d 시도)"
			% ["예" if int(r["reached"]) > 0 else "아니오", int(r["reached"]), int(r["attempts"])])
	print("  죽은 횟수                    : %d회 / %d시도" % [int(r["deaths"]), int(r["attempts"])])
	print("  화면에 잡을 게 없던 시간     : %.0f초 / %.0f초 (%.0f%%)"
			% [float(r["dead_air"]), lived, frac * 100.0])
	print("  잡은 것 사이의 최장 공백     : %.0f초" % float(r["gap"]))
	print("  종별 사냥                    : %s" % by.strip_edges())
	print("  ⇒ %s" % ("진행 가능" if why.is_empty() else "진행 불가 — " + ", ".join(why)))


## The verdict's own boolean, in one place, so the controls above judge by exactly what the block prints.
func _playable(r: Dictionary) -> bool:
	var lived := maxf(0.0001, float(r["lived"]))
	return int(r["reached"]) > 0 \
			and float(r["dead_air"]) / lived <= DEAD_AIR_MAX \
			and float(r["gap"]) <= KILL_GAP_MAX


func _total_kills() -> int:
	var n := 0
	for v in _kills:
		n += int(v)
	return n


func _total_of(r: Dictionary) -> int:
	var n := 0
	for v in r["kills"]:
		n += int(v)
	return n


func _kills_str() -> String:
	if SHORT.size() != Parts.SPECIES_NAME.size():
		return "표가 어긋났다"
	var out := ""
	for s in _kills.size():
		if int(_kills[s]) > 0:
			out += "%s%d " % [String(SHORT[s]), int(_kills[s])]
	return "-" if out == "" else out.strip_edges()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
