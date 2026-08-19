extends SceneTree
## The headless run-player. Plays whole runs with scripted PLANS and prints, per island: soldiers
## lost, HP pool in and out, fight duration, how much of the island's time limit that spent, and how
## many actions the plan cost.
##
## `plan-then-watch`, section 11, is what this file answers now. The shape it replaced interleaved
## loading, launching and stepping on every frame inside one `while outcome() == RUNNING` loop —
## which is exactly what that design deletes. **A policy is now a PLAN GENERATOR**: it decides where
## every soldier lands before anything moves, the plan is committed once, and then the island is
## stepped to a verdict with nothing touched.
##
## It is not a net: nothing here asserts, everything here reports. A number that comes out wrong is
## a design answer, not a red round. **This round's job is to REPORT, not to tune** — `TIME_LIMITS`
## and every other rule constant are read as they stand; a probe that adjusts a constant to make its
## own run look better is grading itself.
##
## ⚠⚠ **The brake is deliberately absent** (`plan-then-watch`, OPEN 0 — the user: 「일단 빼고 만든
## 이후에 추가하자는 거임」). Boats are unlimited and free, so 「everything onto the cheapest beach」
## is expected to DOMINATE. **This file measures that and prints the number; it does not tune it
## away, and it must never invent a departure delay, a per-beach cap or a boat count to make the
## arithmetic close.** The baseline policy IS the dominant plan, on purpose.
##
## **The last probe this repo had graded itself in its owner's favour twice** — it modelled
## one-shot as `force >= hp` after a cap had made that false, and it never read the flee table. So
## the last thing this file does is feed itself a run that MUST be reported as a loss (one soldier,
## one HP), and the landing-point pair below carries its OWN inversion too: two runs landing by the
## SAME plan must produce identical numbers, or the near/far and near/quiet comparisons above it
## are noise rather than a measurement of the landing point.
##
## Run it with:
##   Godot.exe --headless --path <project> --script res://tools/probe/run_run.gd
## An `--import` pass has to have happened at least once, or every `class_name` in `src/sim` is
## invisible to `--script` and this dies with "Nonexistent function 'new'".


## The frame this probe hands `Battle.step`. ⚠ **It is no longer the discretisation the fight is
## computed at** — `step` runs whole `Rules.SIM_SUBSTEP_SEC` passes and carries the leftover
## (`plan-then-watch`, 5.2), so 0.05 is exactly three sub-steps and the numbers below are NOT
## comparable with anything this file printed before that landed. That is why the baseline is
## re-measured and printed FIRST, at whatever enemy counts `islands.gd` holds today.
const DT := 0.05

## Hang guard. Island 3's limit is 90 s = 1800 steps, so this can only fire if the clock stops
## advancing — and a probe that hangs prints nothing at all, which is the failure shape that
## disarmed a whole net in this repo once.
const MAX_STEPS := 4000

## Two landing tiles count as the SAME beach below this separation, in tiles. Used only by the
## `split` plan, which needs its two beaches to be genuinely different places.
const SPLIT_MIN_SEPARATION := 6.0

## ⚠⚠ **The route this probe walks, as node ids — and without one it walks NOWHERE.** A `Run` now
## starts in `State.MAP` and `_advance()` lands back in `MAP` instead of stepping `island_index`, so
## the driver's old `BATTLE`/`REWARD` loop fell out on its first iteration and every policy played
## **zero islands** — with no `[!!]` line, because a `break` is the loop's normal exit. That is how
## the design doc's HP table became unreproducible while reading as measured.
##
## Two routes, because the fork is what the map exists for and one route cannot show it:
##
##  · `ROUTE_BEAK` — floor 2 right, floor 3 left. **Both pay the beak**, so the roster is only what
##    node 0's cell reward added: 10 + 3 = 13. The FEWEST soldiers a run can field
##  · `ROUTE_CELLS` — floor 2 left, floor 3 right. **Three cell nodes**, so the roster reaches
##    10 + 3 x 3 = 19 and the run never picks a beak at all
##
## Both pass the chest (node 5) and end on the boss (node 6). ⚠ **Five nodes, four of them islands** —
## the old three-island runs are not comparable with these, and neither is the 49% the `TIME_LIMITS`
## comment carries.
##
## ⚠⚠ **`ROUTE_CELLS` is the DEFAULT and that choice is not neutral, so it is written down**: the
## policy sweep needs four island rows to compare and the beak branch dies on its second node, which
## would leave the sweep with two. It is **not** the route that flatters the numbers by accident —
## `_the_fork_costs` plays BOTH and prints that the beak branch **loses the run outright**, so the
## harsher answer is on screen either way rather than hidden behind the default.
const ROUTE_BEAK := [0, 2, 3, 5, 6]
const ROUTE_CELLS := [0, 1, 4, 5, 6]


func _initialize() -> void:
	print("[프로브] 헤드리스 런 — 계획을 짜고, 커밋하고, 판정까지 본다 (dt %.2fs = 서브스텝 %d개)"
			% [DT, int(round(DT / Rules.SIM_SUBSTEP_SEC))])
	print("         잃은 병사 · HP 풀 들어감->나옴 · 전투 길이 · 제한 시간 대비 %")

	# ⚠⚠ **The baseline is printed BEFORE anything else and at the enemy counts the tree holds
	# today.** The 49% figure `islands.gd`'s TIME_LIMITS comment carries is a PRE-SUB-STEP number:
	# comparing a post-sub-step result against it compares two different simulations, and the round
	# would book a design win that is a discretisation artefact.
	var near_rows := _policy("near")
	_baseline_verdict(near_rows)

	var far_rows := _policy("far")
	var quiet_rows := _policy("quiet")
	var split_rows := _policy("split")
	var reversed_rows := _policy("near", true)

	_same_beach_is_a_control(near_rows)
	_order_matters(near_rows, reversed_rows)
	_the_dominant_plan(near_rows)
	_the_fork_costs()
	_the_ladder_is_inert()
	_inverted_must_lose()

	_verdicts(near_rows, far_rows, quiet_rows, split_rows)

	print("")
	print("[프로브] 끝.")
	quit(0)


## ⚠⚠ **The re-measured baseline, and it is the number every later comparison stands on.** The stop
## condition `plan-then-watch` 8.2 sets is on the BASELINE and on nothing else: the whole roster onto
## the single cheapest sendable tile must LOSE an island, or its worst island must finish above 70%
## of that island's limit. Anything short of that and the clock is still decoration.
func _baseline_verdict(rows: Array) -> void:
	print("")
	print("=== 기준선 재측정 — 서브스텝이 들어온 뒤의 숫자다 (옛 49% 와 직접 비교 금지) ===")
	var worst := 0.0
	var lost_any := false
	for i in rows.size():
		var row: Dictionary = rows[i]
		var limit := Islands.time_limit_of(int(row["island"]))
		var share := float(row["dur"]) / limit * 100.0
		worst = maxf(worst, share)
		if not bool(row["won"]):
			lost_any = true
		print("  섬 %d — %.1fs / 제한 %.0fs = %.1f%% · %s" % [
			int(row["island"]) + 1, float(row["dur"]), limit, share,
			"승" if bool(row["won"]) else "패"])
	print("  기준선 최악: %.1f%% · 진 섬: %s" % [worst, "있음" if lost_any else "없음"])
	var passes := lost_any or worst >= 70.0
	print("  섬은 질 수 있는가 (기준선이 한 섬을 지거나, 최악이 70%% 이상): %s" % _mark(passes))


## The remaining questions, graded out loud. A probe whose output has to be eyeballed gets eyeballed
## in its author's favour — this repo's last one did, twice — so each row says what it wanted, what
## it got, and which of the two won. **Nothing here is fixed up to pass.**
func _verdicts(near_rows: Array, far_rows: Array, quiet_rows: Array, split_rows: Array) -> void:
	print("")
	print("=== 계획서(plan-then-watch, 11절)가 요구한 숫자, 그대로 채점 ===")

	# ⚠⚠ **A run's LENGTH is now a variable, and grading on `size() ==` graded the wrong thing.**
	# Two policies can die on different nodes, so the row that asks "do casualties and time differ"
	# was reporting 미달 because the two runs were not the same length — which is the STRONGEST
	# possible difference, reported as an absence. The length gap is printed as its own line instead,
	# and the comparison runs over the islands both runs actually played.
	print("  1. 같은 섬, 두 해안(가까운 곳 vs 먼 곳) — 사상자와 시간이 달라야 한다")
	if near_rows.size() != far_rows.size():
		print("     ⚠ 런 길이 자체가 갈렸다 — 가까운 곳 %d섬 · 먼 곳 %d섬 (한쪽이 더 일찍 졌다)"
				% [near_rows.size(), far_rows.size()])
	var landing_matters := mini(near_rows.size(), far_rows.size()) >= 1
	for i in mini(near_rows.size(), far_rows.size()):
		var n := near_rows[i] as Dictionary
		var f := far_rows[i] as Dictionary
		var differ := absf(float(n["damage"]) - float(f["damage"])) > 0.01 \
				or absf(float(n["dur"]) - float(f["dur"])) > 0.01
		if not differ:
			landing_matters = false
		print("     섬 %d — 가까운 곳 피해 %.1f / %.1fs · 먼 곳 피해 %.1f / %.1fs: %s" % [
			i + 1, float(n["damage"]), float(n["dur"]), float(f["damage"]), float(f["dur"]),
			_mark(differ)])
	print("  1 결과: %s — 다르면 착륙 지점이 진짜 결정이고, 같으면 그림만 산 것이다"
			% _mark(landing_matters))

	print("  2. 항구 옆(최저가) vs 적이 없는 곳")
	var near_dominant := 0
	var quiet_dominant := 0
	var split_count := 0
	var pairs := mini(near_rows.size(), quiet_rows.size())
	for i in pairs:
		var n := near_rows[i] as Dictionary
		var q := quiet_rows[i] as Dictionary
		var near_wins_dmg := float(n["damage"]) <= float(q["damage"])
		var near_wins_dur := float(n["dur"]) <= float(q["dur"])
		if near_wins_dmg and near_wins_dur:
			near_dominant += 1
		elif not near_wins_dmg and not near_wins_dur:
			quiet_dominant += 1
		else:
			split_count += 1
		print("     섬 %d — 항구 옆 피해 %.1f / %.1fs · 적 없는 곳 피해 %.1f / %.1fs" % [
			i + 1, float(n["damage"]), float(n["dur"]), float(q["damage"]), float(q["dur"])])
	if pairs > 0 and near_dominant == pairs:
		print("  2 결과: 항구 옆이 사상자·시간 둘 다 이긴다 — 「항상 항구 옆」이 지배적이다 (OPEN 0 의 제동 장치가 필요하다는 뜻)")
	elif pairs > 0 and quiet_dominant == pairs:
		print("  2 결과: 적이 없는 곳이 둘 다 이긴다 — 거리보다 교전 회피가 더 크다")
	else:
		print("  2 결과: 섬마다 갈린다 — %d/%d 항구 옆 완승, %d/%d 적 없는 곳 완승, %d 갈림"
				% [near_dominant, pairs, quiet_dominant, pairs, split_count])

	# ⚠ `split` is the ONLY plan that exercises the one axis the player still has under OPEN 0 —
	# WHICH beaches, and how many. It is not optional padding.
	print("  3. 나눠 상륙 — 플레이어에게 남은 유일한 축이 숫자를 움직이는가")
	if split_rows.size() != near_rows.size():
		print("     ⚠ 런 길이가 갈렸다 — 한 해안 %d섬 · 두 해안 %d섬"
				% [near_rows.size(), split_rows.size()])
	var split_differs := mini(near_rows.size(), split_rows.size()) >= 1
	for i in mini(near_rows.size(), split_rows.size()):
		var n := near_rows[i] as Dictionary
		var s := split_rows[i] as Dictionary
		var differ2 := absf(float(n["damage"]) - float(s["damage"])) > 0.01 \
				or absf(float(n["dur"]) - float(s["dur"])) > 0.01
		if not differ2:
			split_differs = false
		print("     섬 %d — 한 해안 피해 %.1f / %.1fs · 두 해안 피해 %.1f / %.1fs: %s" % [
			i + 1, float(n["damage"]), float(n["dur"]), float(s["damage"]), float(s["dur"]),
			_mark(differ2)])
	print("  3 결과: %s" % _mark(split_differs))

	# ⚠ **`_input_open` is gone and its absence is the report.** The hand cannot press anything at
	# all once the island is committed — that is 결정 1, not a defect — so the old 「입력 가능 %」
	# column is the constant 0 by construction and would silently stop meaning anything. What
	# replaced it is the number of PLANNING actions, which is where the hand now lives.
	print("")
	print("  4. 손이 움직인 곳 — 실행 중 0회는 설계다 (결정 1). 대신 계획 단계의 행동 수를 센다.")
	for i in near_rows.size():
		var row: Dictionary = near_rows[i]
		print("     섬 %d — 계획 행동 %d회 (놓기 %d + 시작 1) · 실행 중 조작 0회"
				% [i + 1, int(row["plan_actions"]), int(row["sends"])])


func _mark(ok: bool) -> String:
	return "충족" if ok else "미달"


# --- the plans -------------------------------------------------------------------------------------

## One landing plan, played on all three islands. `kind` is
##  · "near"  — the whole roster onto the single CHEAPEST droppable tile. **The baseline**, and under
##              OPEN 0 also the dominant plan: with unlimited free boats there is nothing to pay for
##              sending everything to the shortest crossing
##  · "far"   — the whole roster onto the farthest droppable tile
##  · "quiet" — the whole roster onto the droppable tile whose nearest living enemy is farthest
##  · "split" — half the roster onto each of the two cheapest droppable tiles that are not the same
##              beach. **The only plan that exercises the one axis the player still has**
##
## `reverse` flips the DROP ORDER without changing a single landing tile — 4.4 says the order can now
## only decide formation (who takes the target tile and who takes the BFS-next), so this is the row
## that reports whether that is worth anything.
func _policy(kind: String, reverse := false) -> Array:
	var label: String = {
		"near": "가장 가까운 해안 (기준선)",
		"far": "가장 먼 해안",
		"quiet": "적이 가장 먼 해안",
		"split": "두 해안에 절반씩",
	}[kind]
	if reverse:
		label += " — 놓는 순서를 뒤집어서"
	return _play_run("계획 — %s" % label, kind, reverse, true)


## ⚠ The inversion for the landing-point pair itself: **two runs choosing the SAME plan must produce
## IDENTICAL numbers**, since the sim is deterministic and every landing-tile picker here is a pure
## function of grid + enemy state. If they do not match, every comparison in `_verdicts` is measuring
## run-to-run noise instead of the landing point.
func _same_beach_is_a_control(near_rows: Array) -> void:
	var repeat := _play_run("", "near", false, false)
	print("")
	print("=== 통제 — 같은 계획을 두 번 돌리면 숫자가 완전히 같아야 한다 ===")
	var same := near_rows.size() > 0 and near_rows.size() == repeat.size()
	for i in mini(near_rows.size(), repeat.size()):
		var a := near_rows[i] as Dictionary
		var b := repeat[i] as Dictionary
		var match_ok := absf(float(a["damage"]) - float(b["damage"])) < 0.01 \
				and absf(float(a["dur"]) - float(b["dur"])) < 0.01
		if not match_ok:
			same = false
		print("  섬 %d — 1회차 %.2f / %.2fs · 2회차 %.2f / %.2fs: %s" % [
			i + 1, float(a["damage"]), float(a["dur"]), float(b["damage"]), float(b["dur"]),
			_mark(match_ok)])
	print("  통제 결과: %s — 실패하면 위 비교는 착륙 지점이 아니라 잡음을 재는 것이다" % _mark(same))


## ⚠⚠ **The one thing 「순서」 can still decide, reported and not tuned to.** Under unlimited boats
## every boat departs on the commit frame, so order carries no timing at all; what survives is
## FORMATION — `_try_unload` writes `grid.reserved` in walk order, so the first-dropped boat aiming
## at a beach stands ON the target tile and the next stands on the BFS-next. This row runs the same
## tiles with the drop sequence reversed and reports whether anything measurable moved.
##
## ⚠ **If nothing moves, say so and leave the ghost fan alone.** `plan-then-watch` 4.4 forbids both
## available "fixes": an order glyph (a picture claiming more than the sim does) and a departure
## delay (that is OPEN 0's brake, and it is the user's call).
func _order_matters(near_rows: Array, reversed_rows: Array) -> void:
	print("")
	print("=== 놓는 순서 — 같은 칸, 순서만 뒤집었을 때 ===")
	var any := false
	for i in mini(near_rows.size(), reversed_rows.size()):
		var a := near_rows[i] as Dictionary
		var b := reversed_rows[i] as Dictionary
		var d_dmg := absf(float(a["damage"]) - float(b["damage"]))
		var d_dur := absf(float(a["dur"]) - float(b["dur"]))
		var d_form := float(b["front_id"]) != float(a["front_id"])
		if d_dmg > 0.01 or d_dur > 0.01 or d_form:
			any = true
		print("  섬 %d — 피해 차 %.2f · 시간 차 %.2fs · 목표 칸에 선 병사 %d -> %d" % [
			i + 1, d_dmg, d_dur, int(a["front_id"]), int(b["front_id"])])
	if any:
		print("  결과: 순서가 무언가를 바꾼다 — 대형(누가 앞자리인가)이 그 무언가다. 크기는 위 숫자 그대로다")
	else:
		print("  결과: 순서가 아무것도 안 바꾼다. ⚠ 그래도 유령 부채는 그대로 둔다 — 그것은 입력의 그림이고,")
		print("        여기에 글자를 붙이거나 출항 지연을 넣는 것은 OPEN 0 의 제동 장치이지 빌더의 결정이 아니다")


## ⚠⚠ **The shape the missing brake produces, run explicitly and printed.** With boats unlimited and
## free, everything goes to one tile: this reports how far apart the roster actually ends up standing
## and how long it takes anyone to land a first blow. The next session picking a brake needs both.
func _the_dominant_plan(near_rows: Array) -> void:
	print("")
	print("=== 지배적인 계획 — 열셋을 한 칸에 (OPEN 0 에 제동 장치가 없을 때의 모습) ===")
	for i in near_rows.size():
		var row: Dictionary = near_rows[i]
		print("  섬 %d — 한 칸에 %d명 · 상륙 후 퍼진 반경 %.2f 타일 · 첫 타격까지 %.2fs" % [
			i + 1, int(row["sends"]), float(row["spread"]), float(row["first_blow"])])


## ⚠⚠ **The fork, measured — the one thing the map exists for.** The same baseline plan walked down
## the beak branch and down the cells branch, printed side by side: this is the number the design's
## claim *"the fork asks what you are short of and how much HP you can spend"* stands or falls on, and
## before this file could walk a route at all there was no way to produce it.
##
## ⚠ **What it currently reports is the ISLAND SHORTAGE, not the fork.** Three grids serve six
## island-opening nodes, so node 2 (floor 2, right) opens the LION grid — the boss island, fought at
## the second fight of the run. The two branches therefore differ mostly in which grids they draw, and
## that is a level-design fact rather than a reward fact. It becomes a fork measurement the day the
## three new grids land.
func _the_fork_costs() -> void:
	print("")
	print("=== 갈림길 — 같은 계획, 두 갈래 (부리 쪽 vs 세포 쪽) ===")
	# Verbose on both, because the per-island rows ARE the finding: the summary line below cannot say
	# which grid a branch drew, and that is what the two branches currently differ by.
	var beak := _play_run("부리 쪽 %s" % str(ROUTE_BEAK), "near", false, true, ROUTE_BEAK)
	var cells := _play_run("세포 쪽 %s" % str(ROUTE_CELLS), "near", false, true, ROUTE_CELLS)
	for pair in [["부리 쪽 %s" % str(ROUTE_BEAK), beak], ["세포 쪽 %s" % str(ROUTE_CELLS), cells]]:
		var rows: Array = pair[1]
		var damage := 0.0
		var lost := 0
		var beaten := 0
		for row: Dictionary in rows:
			damage += float(row["damage"])
			lost += int(row["lost"])
			if bool(row["won"]):
				beaten += 1
		print("  %s — 섬 %d개 중 %d개 승 · 총 피해 %.1f · 잃은 병사 %d" % [
			str(pair[0]), rows.size(), beaten, damage, lost])
	if beak.size() == cells.size():
		print("  ⚠ 두 갈래가 같은 수의 섬을 쳤다 — 갈림길이 길이로는 안 갈린다")
	else:
		print("  두 갈래가 친 섬 수가 다르다 (%d vs %d) — 한쪽이 더 일찍 끝났다"
				% [beak.size(), cells.size()])


## ⚠ **The speed ladder has to be arithmetically inert.** `Battle.step` runs whole sub-steps and
## carries the leftover, so the same plan driven at DT and at 6 x DT must land on identical state.
## If it does not, the RULE is wrong, not the multiplier — and the widget is playing a different game.
func _the_ladder_is_inert() -> void:
	print("")
	print("=== 배속 — 같은 계획을 1배속과 6배속으로 (똑같아야 한다) ===")
	var a := Run.new()
	var b := Run.new()
	# ⚠ **A fresh `Run` stands on the MAP, not on an island.** `begin_island()` returns null until a
	# node is entered, and the null then faults inside `_make_plan` two calls later with a message
	# about `soldier_state` that says nothing about the cause. Node 0 is the map's fixed first node.
	a.enter_node(0)
	b.enter_node(0)
	var ba := a.begin_island()
	var bb := b.begin_island()
	var plan := _make_plan(ba, "near", false)
	_run_plan(ba, plan, DT)
	_run_plan(bb, _make_plan(bb, "near", false), DT * 6.0)
	var hp_same := ba.enemy_hp.size() == bb.enemy_hp.size()
	var worst := 0.0
	for e in mini(ba.enemy_hp.size(), bb.enemy_hp.size()):
		worst = maxf(worst, absf(ba.enemy_hp[e] - bb.enemy_hp[e]))
	if worst > Rules.EPS:
		hp_same = false
	var same := hp_same and ba.outcome() == bb.outcome() \
			and absf(ba.elapsed - bb.elapsed) <= Rules.EPS
	print("  1배속 %.3fs / 판정 %d · 6배속 %.3fs / 판정 %d · 적 HP 최대 차 %.6f: %s" % [
		ba.elapsed, ba.outcome(), bb.elapsed, bb.outcome(), worst, _mark(same)])
	if not same:
		print("  [!!] 배속이 결과를 바꿨다 — SIM_SUBSTEP_SEC 쪽 규칙이 틀린 것이지 배수가 틀린 게 아니다")


# --- the driver ----------------------------------------------------------------------------------

## Plays one whole run and prints a line per island. Returns the per-island rows so a caller can
## compare two runs without re-reading the console.
func _play_run(label: String, kind: String, reverse: bool, verbose := true,
		route: Array = ROUTE_CELLS) -> Array:
	if verbose:
		print("")
		print("=== %s ===" % label)
	var run := Run.new()
	var rows: Array = []
	# Five nodes, four of them islands, plus a reward stop after each beak node, plus slack. A
	# `while true` here would turn a stuck state machine into a silent hang, and a hang prints nothing
	# at all.
	var guard := 0
	var step := 0
	while guard < 32:
		guard += 1
		var st := run.state()
		if st == Run.State.MAP:
			# ⚠ **The branch whose absence killed this file.** Without it the loop's very first
			# iteration fell into `else: break`, every policy played zero islands, and the exit was
			# indistinguishable from a run that finished.
			if step >= route.size():
				print("  [!!] 경로를 다 걸었는데 런이 안 끝났다 (상태 %s)" % _state_name(st))
				break
			var node := int(route[step])
			step += 1
			if not run.enter_node(node):
				print("  [!!] %d번 칸을 밟을 수 없다 — 경로가 지도와 안 맞는다" % node)
				break
			if verbose and Rules.map_island_of(node) < 0:
				print("  칸 %d (상자) — 회복해서 풀 %.1f 로 올라갔다" % [node, _pool(run.army)])
		elif st == Run.State.BATTLE:
			var idx := run.island_index
			var battle := run.begin_island()
			if battle == null:
				print("  [!!] begin_island 가 null 을 돌려줬다 (상태 %d)" % st)
				break
			var pool_in := _pool(run.army)
			var alive_in := run.army.living_count()
			var plan := _make_plan(battle, kind, reverse)
			if verbose:
				_print_crossings(battle)
			var res := _play_island(battle, plan)
			var pool_out := _pool(run.army)
			var won := battle.outcome() == Battle.Outcome.WON
			var row := {
				"node": run.map.at(),
				"island": idx,
				"won": won,
				"lost": alive_in - run.army.living_count(),
				"pool_in": pool_in,
				"pool_out": pool_out,
				"damage": pool_in - pool_out,
				"dur": battle.elapsed,
				"sends": int(res["sends"]),
				"plan_actions": int(res["plan_actions"]),
				"spread": float(res["spread"]),
				"first_blow": float(res["first_blow"]),
				"front_id": int(res["front_id"]),
			}
			rows.append(row)
			if verbose:
				_print_row(battle, row, res)
			if int(res["steps"]) >= MAX_STEPS:
				print("  [!!] 스텝 상한에 걸렸다 — 시계가 안 도는 것이다")
				break
			run.finish_island(won)
			if not won:
				break
		elif st == Run.State.REWARD:
			var pick := _beak_pick(run.army)
			if pick < 0:
				print("  [!!] 부리를 달 살아 있는 병사가 없다 — 런이 멈춘다")
				break
			run.apply_beak(pick)
			if verbose:
				print("  부리 -> 병사 #%d (%s, HP %.1f)" % [
					pick, Rules.name_of(int(run.army.type_id[pick])), run.army.hp[pick]])
		else:
			break
	if verbose:
		print("  런: %s · 살아남은 병사 %d · 남은 풀 %.1f" % [
			_state_name(run.state()), run.army.living_count(), _pool(run.army)])
	return rows


## ⚠ **2.4 asks for the crossing as a NUMBER on the console, not as an inference.** A water route is
## longer than the straight line it replaced and crossing time is `dist / speed`, so every
## `TIME_LIMITS` number is suspect after that change and nobody had measured by how much. This prints
## the shortest and longest sendable crossing on the island and what each costs in seconds at
## `Rules.BOAT_SPEED`, so the rise can be read off rather than argued about.
##
## ⚠ **It reports and does not tune.** `TIME_LIMITS` is read as it stands; retuning it is a decision
## with the user in it (`speed-off-open-landing`, 2.4).
func _print_crossings(battle: Battle) -> void:
	var lo := 1e30
	var hi := 0.0
	var count := 0
	for raw in _droppable_tiles(battle):
		var d := _crossing_of(battle, int(raw))
		if d >= 1e29:
			continue
		count += 1
		lo = minf(lo, d)
		hi = maxf(hi, d)
	if count == 0:
		print("       항로: 보낼 수 있는 칸이 없다")
		return
	print("       항로 %d칸 — 최단 %.2f칸 (%.2fs) · 최장 %.2f칸 (%.2fs) · 배 속도 %.1f칸/s" % [
		count, lo, lo / Rules.BOAT_SPEED, hi, hi / Rules.BOAT_SPEED, Rules.BOAT_SPEED])


func _print_row(battle: Battle, row: Dictionary, res: Dictionary) -> void:
	var dur := float(row["dur"])
	var limit := Islands.time_limit_of(int(row["island"]))
	# ⚠ **The node AND the island, because they are no longer the same number.** Three grids serve six
	# island-opening nodes today, so two rows of one run can carry the same 섬 number and mean two
	# different fights.
	print("  칸 %d (섬 %d) %s | 잃은 병사 %2d | 풀 %6.1f -> %6.1f (피해 %5.1f) | %5.1fs / %2.0fs = %4.1f%% | 놓기 %2d회 · 첫 타격 %.2fs | 남은 적 %d" % [
		int(row["node"]),
		int(row["island"]) + 1,
		"승" if bool(row["won"]) else _lose_name(battle),
		int(row["lost"]),
		float(row["pool_in"]), float(row["pool_out"]), float(row["damage"]),
		dur, limit, dur / limit * 100.0,
		int(row["sends"]), float(row["first_blow"]), battle.enemies_left()])
	print("       최장 정지 %.1fs · 상륙 병사가 막혀 서 있던 시간 %.1f%% · 상륙 반경 %.2f 타일" % [
		float(res["max_stall"]), float(res["stall_share"]), float(row["spread"])])
	if not bool(row["won"]):
		_print_survivors(battle)


## What was still standing when an island was lost. Without this a timeout reads identically
## whether the army was grinding the boss down and ran out of clock or whether every unit was
## frozen doing nothing at all — and "the enemies froze" is exactly the defect this phase exists
## to catch, so it must not be something a reader has to infer.
func _print_survivors(battle: Battle) -> void:
	var parts: Array = []
	for e in battle.enemy_alive.size():
		if battle.enemy_alive[e] != 0:
			parts.append("%s %.1f/%.1f @%s" % [
				Rules.name_of(int(battle.enemy_type[e])), battle.enemy_hp[e],
				Rules.hp_of(int(battle.enemy_type[e])), str(battle.enemy_pos[e])])
	print("       살아남은 적: %s" % (", ".join(PackedStringArray(parts)) if parts.size() > 0 else "없음"))
	var standing: Array = []
	for i in battle.ashore_ids():
		standing.append("#%d %s %.1f @%s" % [
			int(i), Rules.name_of(int(battle.army.type_id[int(i)])), battle.army.hp[int(i)],
			str(battle.soldier_pos[int(i)])])
	print("       상륙한 병사: %s" % (", ".join(PackedStringArray(standing)) if standing.size() > 0 else "없음"))


## ⚠⚠ **Plan, commit, watch — and the hand does nothing in between.** Every `send` happens before
## the first `step`, exactly as the shell now does it: the whole loop below touches `battle` through
## `begin_frame` and `step` and nothing else. A probe that reached into the fight would be measuring
## a game the player cannot play.
func _play_island(battle: Battle, plan: Array) -> Dictionary:
	var sends := 0
	var steps := 0
	var first_blow := -1.0

	for raw in plan:
		var entry: Dictionary = raw
		if battle.send(int(entry["sid"]), int(entry["tile"])) >= 0:
			sends += 1
	var committed := battle.commit()
	if not committed:
		print("  [!!] 커밋이 거절됐다 — 계획이 비어 있다 (놓기 %d회)" % sends)

	# The freeze detector. See `_stalls`.
	var prev_s: Array = battle.soldier_pos.duplicate()
	var prev_e: Array = battle.enemy_pos.duplicate()
	var stall_s := PackedFloat32Array()
	stall_s.resize(battle.soldier_state.size())
	var stall_e := PackedFloat32Array()
	stall_e.resize(battle.enemy_alive.size())
	var max_stall := 0.0
	var acc := {"ashore_s": 0.0, "stalled_s": 0.0}
	var spread := -1.0
	# ⚠ **Both of these are read at the moment the last boat empties, not at the verdict.** By the
	# end of an island every survivor has walked off its landing tile chasing something, so a
	# formation measured at the end is the constant -1 and reads as 「order changes nothing」 — the
	# exact conclusion 4.4's row exists to test honestly.
	var front := -1

	while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
		# Every driver of `Battle` clears last frame's facts before the next step — the shell, the
		# nets and this probe. `events` has no cap on purpose, so a driver that forgets grows it for
		# the whole island. This probe READS it (for the first blow), which makes forgetting loud
		# rather than quiet.
		battle.begin_frame()
		battle.step(DT)
		steps += 1
		if first_blow < 0.0:
			for raw_ev in battle.events:
				var ev: Dictionary = raw_ev
				if int(ev["kind"]) == Battle.Event.ATTACK:
					first_blow = battle.elapsed
					break
		if spread < 0.0 and _everyone_has_landed(battle):
			spread = _landed_spread(battle, plan)
			front = _front_soldier(battle, plan)
		max_stall = maxf(max_stall, _stalls(battle, prev_s, stall_s, prev_e, stall_e, acc))

	if spread < 0.0:
		spread = _landed_spread(battle, plan)
		front = _front_soldier(battle, plan)
	var ashore_s := float(acc["ashore_s"])
	var stall_share := 0.0 if ashore_s <= 0.0 else float(acc["stalled_s"]) / ashore_s * 100.0
	return {"steps": steps, "sends": sends, "plan_actions": sends + (1 if committed else 0),
			"max_stall": max_stall, "stall_share": stall_share, "spread": spread,
			"first_blow": maxf(first_blow, 0.0), "front_id": front}


## Steps one already-set-up island to a verdict at a chosen frame size. Used only by the speed row,
## which has to drive the SAME plan at two different `dt`s.
func _run_plan(battle: Battle, plan: Array, dt: float) -> void:
	for raw in plan:
		var entry: Dictionary = raw
		battle.send(int(entry["sid"]), int(entry["tile"]))
	battle.commit()
	var steps := 0
	while battle.outcome() == Battle.Outcome.RUNNING and steps < MAX_STEPS:
		battle.begin_frame()
		battle.step(dt)
		steps += 1


## True once no soldier this plan sent is still in a boat — either it is ashore or it is dead.
func _everyone_has_landed(battle: Battle) -> bool:
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.TRANSIT:
			return false
	return true


## How far a landed soldier ends up from the tile IT was aimed at, worst case, in tiles. Under
## OPEN 0 the whole roster aims at one tile and `_free_tiles_from` breadth-firsts them onto a disc —
## this is that disc's radius, and it is the number a landing-capacity brake would be sized from.
##
## ⚠ **Measured per soldier against its OWN plan tile, never against the plan's first one.** A
## two-beach plan measured against one beach reports the distance BETWEEN the beaches (36 tiles on
## island 1) and reads as a catastrophic scatter, which is the wrong number under the right label.
func _landed_spread(battle: Battle, plan: Array) -> float:
	var worst := 0.0
	for raw in plan:
		var entry: Dictionary = raw
		var i := int(entry["sid"])
		if battle.soldier_state[i] != Battle.SoldierState.ASHORE:
			continue
		var origin := battle.grid.tile_point(int(entry["tile"]))
		worst = maxf(worst, origin.distance_to(battle.soldier_pos[i]))
	return worst


## Which soldier is standing ON the plan's first landing tile — the front of the formation, and the
## only thing the drop order can still decide (`plan-then-watch`, 4.4). -1 when nobody is there.
func _front_soldier(battle: Battle, plan: Array) -> int:
	if plan.is_empty():
		return -1
	var target := battle.grid.tile_point(int((plan[0] as Dictionary)["tile"]))
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.DEAD:
			continue
		if battle.soldier_pos[i].distance_to(target) <= Rules.EPS:
			return i
	return -1


## Accumulates two numbers about units that are **motionless while their target is out of their
## reach** — so a unit standing because it is already in range, or because nothing is detected, is
## never counted.
##
## This is the instrument for "the enemies froze", which is the failure that cost the last game's
## movement rule two rounds and which no final-state check can see: a run where every unit stood
## still all island and a run where they fought both end with a verdict and a duration.
##
## ⚠ **The first version of this also reported "stall still unresolved when the island ended", and
## that number was structurally 0 on every win** — the win happens because the last enemy dies, and
## a dead target clears `chasing` for everyone on the same frame, so the reset always ran before
## the read. It printed 0.0s on twenty islands and read as proof of no deadlock while measuring
## nothing at all. **The instrument was inverted, not the sim.** What replaced it is the share of
## ashore soldier-seconds spent stalled, which no ending can zero.
##
## A queue at a doorway legitimately parks a unit for many seconds, so this reports NUMBERS and
## judges nothing: on these three islands the open field runs a few percent and the ring runs high.
func _stalls(battle: Battle, prev_s: Array, stall_s: PackedFloat32Array,
		prev_e: Array, stall_e: PackedFloat32Array, acc: Dictionary) -> float:
	var worst := 0.0
	for i in battle.soldier_state.size():
		var here: Vector2 = battle.soldier_pos[i]
		var chasing := false
		if battle.soldier_state[i] == Battle.SoldierState.ASHORE:
			acc["ashore_s"] = float(acc["ashore_s"]) + DT
			var t := int(battle.soldier_target[i])
			if t >= 0 and battle.enemy_alive[t] != 0:
				chasing = here.distance_to(battle.enemy_pos[t]) \
						> battle.army.range_of(i) + Rules.REACH_BONUS + Rules.EPS
		if chasing and here.distance_to(prev_s[i]) <= Rules.EPS:
			stall_s[i] += DT
			acc["stalled_s"] = float(acc["stalled_s"]) + DT
			worst = maxf(worst, stall_s[i])
		else:
			stall_s[i] = 0.0
		prev_s[i] = here
	for e in battle.enemy_alive.size():
		var here: Vector2 = battle.enemy_pos[e]
		var chasing := false
		if battle.enemy_alive[e] != 0:
			var t := int(battle.enemy_target[e])
			if t >= 0 and battle.is_hittable(t):
				chasing = here.distance_to(battle.soldier_pos[t]) \
						> Rules.range_of(int(battle.enemy_type[e])) + Rules.REACH_BONUS + Rules.EPS
		if chasing and here.distance_to(prev_e[e]) <= Rules.EPS:
			stall_e[e] += DT
			worst = maxf(worst, stall_e[e])
		else:
			stall_e[e] = 0.0
		prev_e[e] = here
	return worst


# --- plan generation -------------------------------------------------------------------------------

## The whole plan, as an ordered list of `{sid, tile}`. **The order IS the plan's order** — the user's
## own rule 「놓은 순서가 곧 순서다」 — and `battle.send` is called in exactly this sequence.
func _make_plan(battle: Battle, kind: String, reverse: bool) -> Array:
	var ids := _sendable_soldiers(battle)
	if reverse:
		ids.reverse()
	var out: Array = []
	if ids.is_empty():
		return out
	if kind == "split":
		var beaches := _two_beaches(battle)
		if beaches.size() < 2:
			beaches = [_pick_tile(battle, "near")]
		var half := ids.size() / 2
		for k in ids.size():
			var tile: int = int(beaches[0]) if k < half else int(beaches[1 % beaches.size()])
			out.append({"sid": int(ids[k]), "tile": tile})
		return out
	var one := _pick_tile(battle, kind)
	for raw in ids:
		out.append({"sid": int(raw), "tile": one})
	return out


## Every soldier that can still be sent, in army-id order. `send` refuses anything else, so a plan
## built from this list never contains a refusal the caller has to notice.
func _sendable_soldiers(battle: Battle) -> Array:
	var out: Array = []
	for i in battle.soldier_state.size():
		if battle.soldier_state[i] == Battle.SoldierState.RESERVE and battle.army.alive[i] != 0:
			out.append(i)
	return out


## Every tile a boat may be sent to — the UNION over every harbour, which is the same predicate
## `battle.send` refuses on. A probe policy can therefore never choose a tile the real game would have
## refused. ⚠ **It is no longer "the same one the droppable overlay is painted from"**: the overlay is
## deleted (`speed-off-open-landing`, question C — the screen marks what is BLOCKED and nothing else),
## so `Battle.send` is the only other reader of this predicate now.
func _droppable_tiles(battle: Battle) -> PackedInt32Array:
	var out := PackedInt32Array()
	if battle.grid == null:
		return out
	for t in battle.grid.passable.size():
		if battle.grid.home_harbour_for(t) >= 0:
			out.append(t)
	return out


## The crossing a boat aimed at `tile` actually sails: the LENGTH OF THE WATER ROUTE from the harbour
## `home_harbour_for` picks, which is the one `send` uses. Never re-derived from `start_harbour` —
## that would price a landing against a harbour no boat leaves from.
##
## ⚠⚠ **It was the straight-line distance and that is now the wrong number.**
## `speed-off-open-landing` made a boat sail a polyline around headlands, so a straight line prices a
## sail no boat makes — and since every policy below CHOOSES a tile by this function, pricing it wrong
## would silently make `near`, `far` and `split` pick the wrong beaches while every printed number
## still looked plausible. Measured on the three shipped grids: the route is strictly longer than the
## straight line on 82 / 74 / 80 of the sendable tiles and never shorter, by up to 1.41x.
func _crossing_of(battle: Battle, tile: int) -> float:
	var hb := battle.grid.home_harbour_for(tile)
	if hb < 0:
		return 1e30
	var route := battle.grid.water_route(hb, tile)
	if route.size() < 2:
		return 1e30
	var total := 0.0
	for k in range(1, route.size()):
		total += route[k - 1].distance_to(route[k])
	return total


func _pick_tile(battle: Battle, kind: String) -> int:
	match kind:
		"far":
			return _extreme_tile(battle, false)
		"quiet":
			return _quietest_tile(battle)
		_:
			return _extreme_tile(battle, true)


## The cheapest (`cheapest == true`) or most expensive droppable tile, priced by its own crossing.
## Ties go to the lower tile index, which is row-major order, so two runs pick the same tile.
func _extreme_tile(battle: Battle, cheapest: bool) -> int:
	var best := -1
	var best_d := 0.0
	for raw in _droppable_tiles(battle):
		var t := int(raw)
		var d := _crossing_of(battle, t)
		if best == -1 or (d < best_d - Rules.EPS if cheapest else d > best_d + Rules.EPS):
			best = t
			best_d = d
	return best


## The droppable tile whose NEAREST living enemy is farthest away — "land where the enemy is not".
## Read from the SIM's own `enemy_alive` / `enemy_pos` at call time, never re-derived from what this
## probe expects to see there — a probe that grades its own step by modelling the enemy instead of
## reading it is the exact shape the last one's flee-table miss was.
func _quietest_tile(battle: Battle) -> int:
	var best := -1
	var best_min_d := -1.0
	for raw in _droppable_tiles(battle):
		var t := int(raw)
		var p := battle.grid.tile_point(t)
		var nearest_enemy := 1e30
		for e in battle.enemy_alive.size():
			if battle.enemy_alive[e] == 0:
				continue
			nearest_enemy = minf(nearest_enemy, p.distance_squared_to(battle.enemy_pos[e]))
		if nearest_enemy > best_min_d + Rules.EPS:
			best_min_d = nearest_enemy
			best = t
	return best


## The two cheapest droppable tiles that are at least `SPLIT_MIN_SEPARATION` tiles apart — two
## genuinely different beaches rather than two tiles of one. Empty when the island has only one.
func _two_beaches(battle: Battle) -> Array:
	var first := _extreme_tile(battle, true)
	if first < 0:
		return []
	var origin := battle.grid.tile_point(first)
	var second := -1
	var best_d := 0.0
	for raw in _droppable_tiles(battle):
		var t := int(raw)
		if battle.grid.tile_point(t).distance_to(origin) < SPLIT_MIN_SEPARATION:
			continue
		var d := _crossing_of(battle, t)
		if second == -1 or d < best_d - Rules.EPS:
			second = t
			best_d = d
	if second < 0:
		return []
	return [first, second]


# --- the inversion -------------------------------------------------------------------------------

## Fed a run that cannot be won: one soldier, one HP, against island 1's whole spawn list. If this
## reports anything but a loss the probe is grading in its own favour and every number above it is
## worth nothing.
func _inverted_must_lose() -> void:
	print("")
	print("=== 뒤집기 — 반드시 져야 하는 런 (병사 1명, 1 HP) ===")
	var run := Run.new()
	for i in range(1, run.army.alive.size()):
		run.army.kill(i)
	var h := run.army.hp
	h[0] = 1.0
	run.army.hp = h
	print("  살아 있는 병사 %d명, 풀 %.1f" % [run.army.living_count(), _pool(run.army)])

	# The same map step the ladder needs: no island is open until a node is entered.
	run.enter_node(0)
	var battle := run.begin_island()
	var res := _play_island(battle, _make_plan(battle, "near", false))
	var verdict := _outcome_name(battle)
	print("  섬 1 결과: %s · 남은 적 %d · %.1fs · %d 스텝" % [
		verdict, battle.enemies_left(), battle.elapsed, int(res["steps"])])
	if battle.outcome() == Battle.Outcome.LOST:
		print("  [OK] 져야 할 런이 실제로 졌다 — 위 숫자들을 믿어도 된다")
	else:
		print("  [!!] 져야 할 런이 지지 않았다 — 이 프로브의 모든 숫자를 믿지 마라")


# --- army helpers --------------------------------------------------------------------------------

func _pool(army: Army) -> float:
	var total := 0.0
	for i in army.hp.size():
		if army.alive[i] != 0:
			total += army.hp[i]
	return total


## The beak goes on the healthiest living melee, falling back to ranged. `living_ids_of_type` is
## already sorted highest-HP first and breaks ties on the smaller id, so two runs from identical
## state bolt it onto the same soldier.
func _beak_pick(army: Army) -> int:
	var ids := army.living_ids_of_type(Rules.CELL_MELEE)
	if ids.is_empty():
		ids = army.living_ids_of_type(Rules.CELL_RANGED)
	return -1 if ids.is_empty() else int(ids[0])


# --- names ---------------------------------------------------------------------------------------

func _outcome_name(battle: Battle) -> String:
	match battle.outcome():
		Battle.Outcome.WON:
			return "승"
		Battle.Outcome.LOST:
			return _lose_name(battle)
		_:
			return "안 끝남"
	return "?"


func _lose_name(battle: Battle) -> String:
	match battle.lose_reason():
		Battle.Lose.TIMEOUT:
			return "패(시간)"
		Battle.Lose.WIPED:
			return "패(전멸)"
		_:
			return "패"
	return "패"


func _state_name(st: int) -> String:
	match st:
		Run.State.MAP:
			return "지도"
		Run.State.BATTLE:
			return "진행 중"
		Run.State.REWARD:
			return "보상 대기"
		Run.State.WON:
			return "클리어"
		Run.State.LOST:
			return "실패"
		_:
			return "?"
	return "?"
