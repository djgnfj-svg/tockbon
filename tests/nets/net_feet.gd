extends RefCounted
## **The drawn point never lands on a 조각 whose 눈금 differs from the sim's 조각.** 티켓 03-21.
##
## The claim under test is one sentence: **`FieldView._offset_kept_on_level` shortens a walking body's
## seat offset just enough that the point it is drawn at stays on the sim's own 눈금 — and shortens
## nothing when no ledge is in reach.**
##
## ⚠⚠ **NOTHING HERE TOUCHES THE TREE.** `Grid.new()`, `Islands.load_board` and one `FieldView.new()`
## that is freed at the end are the whole fixture. The function takes its grid as an argument for exactly
## this reason — it is one of `GLOSSARY.md`'s 「pure camera functions, drivable with `.new()`」.
##
## ⚠⚠ **THE DEFECT IS MEASURED HERE TOO, NOT ONLY THE FIX.** The sweep counts the cases that go wrong
## with the raw `at + off` the game shipped yesterday, and refuses to pass unless that count is large on
## the hand island AND on the generated ones. A sweep that reached no ledge at all would otherwise stay
## green on the day the fix is deleted.
##
## ⚠⚠ **EVERY ROW IS INVERTED.** The sweep is fed the unfixed answer, 「no ledge, no shrink」 is fed
## `Vector2.ZERO` (which passes the sweep and the named run both, while deleting the whole seat spread),
## and the continuity row is fed a sixteen-step quantised answer — the fixed-step scan the ticket refuses.
## Each must be caught. **Twice in one night a check was written to catch a defect and shipped carrying
## that same defect**, which is what `how-nets-lie` is for.
##
## ⚠ **The labels are Korean because they are printed output**, which is what every net here does.


## **Seeds 1..SEEDS, pinned.** A generator is measured over many boards or not at all — the hand island
## proves the hand island. ⚠ **The ticket's measurement was 100 of 100 seeds carrying the defect**, so
## this is the number that measurement was taken at.
const SEEDS := 100

## **The offset lengths a real seat can be, plus the bound itself.** `Look.SEAT_PITCH_TILES` is 2/3, so a
## seat sits 0.667 out along an edge and 0.943 out at a corner; 0.5 is the short reach and 1.0 is
## `Look.SEAT_OFFSET_MAX_TILES`, which no lattice seat reaches but the clamp permits.
## ⚠ Plain `const` Array: a `const` packed array is a parse error on 4.7.1, so every read casts.
const MAGS := [0.5, 0.667, 0.943, 1.0]

## The five 조각 the user watched a 부대 walk along the top of the cliff, and the direction that lifted them.
const RUN_Y := 3
const RUN_X0 := 8
const RUN_X1 := 12
const RUN_OFF := Vector2(0.0, 1.0)

## The continuity walk: how far `at` moves per step, how many steps, and the most the drawn point may
## move for one of them.
## ⚠⚠ **0.02 IS THE WHOLE POINT OF THE ROW.** A sixteen-step scan of a 0.943 조각 offset answers on a
## 0.059 조각 ladder, so a bound anywhere above that would let the refused shape ship green.
const WALK_STEP := 0.01
const WALK_STEPS := 340
const WALK_FROM_X := 2.0
const WALK_BOUND := 0.02
const WALK_SCAN_STEPS := 16
const WALK_OFF := Vector2(0.943, 0.0)

## The synthetic board the continuity row walks: all land, level 0 west of the line and level 2 east of
## it. **Hand-built rather than borrowed from an island** so that `at` never leaves one 눈금 mid-walk —
## a base 조각 that changed level under the walk would be a real step and would say nothing about scans.
const WALK_ROWS := [
	"..............",
	"..............",
	"..............",
	"..............",
	"..............",
	"..............",
	"..............",
	"..............",
]
const WALK_TIERS := [
	"00000022222222",
	"00000022222222",
	"00000022222222",
	"00000022222222",
	"00000022222222",
	"00000022222222",
	"00000022222222",
	"00000022222222",
]
## 조각 5 is the last level-0 one, so the ledge the walk approaches is the line at x = 5.5.
const WALK_LEDGE_X := 5.5
const WALK_Y := 4


var _field: FieldView = null
## What the sweep leaves behind for 「no ledge, no shrink」 to read — the two rows ask about the same
## cases and the sweep is the expensive thing in this file, so the boards are walked once.
var _free_cases := 0
var _free_bad: Array[String] = []


func run(t) -> void:
	_field = FieldView.new()
	_the_sweep(t)
	_the_cliff_run_the_user_walked(t)
	_no_ledge_no_shrink(t)
	_a_piece_line_under_the_foot(t)
	_the_rule_is_wired_into_glided(t)
	_the_answer_slides_and_never_steps(t)
	_the_answer_never_teleports(t)
	_what_the_cap_costs_the_spread(t)
	_a_stair_still_slides_inside_one_piece(t)
	_field.free()
	_field = null
	# **The sentinel.** See `run_nets.done` — without it a `run()` that dies half way still reports
	# every check it managed first, in a shape a healthy net cannot be told from.
	t.done()


# == the sweep =========================================================================================

## **Every walkable 조각 of the hand island and of `SEEDS` generated islands, eight directions, four
## magnitudes: the kept offset puts the drawn point on a 조각 of the SAME 눈금. Zero exceptions.**
##
## ⚠ **The box test is an INDEPENDENT oracle.** It asks the grid whether any 조각 within Chebyshev reach
## of the base carries a different 눈금 — it does not re-run the function's own segment arithmetic, so a
## function that merely agreed with itself could not make the 「no ledge」 half agree with it.
func _the_sweep(t) -> void:
	var dirs := _dirs()
	var bad: Array[String] = []
	var raw_bad_hand := 0
	var raw_bad_gen := 0
	var shrunk := 0
	var cases := 0
	for entry: Array in _boards():
		var label: String = entry[0]
		var g: Grid = entry[1]
		var hand: bool = bool(entry[2])
		for ty in g.h:
			for tx in g.w:
				if not g.is_passable(tx, ty):
					continue
				var at := Vector2(float(tx), float(ty))
				var base := g.level_at(tx, ty)
				# Two radii cover the four magnitudes, and both are asked once per 조각 rather than once
				# per case: the answer cannot change with the direction.
				var clear_near := _box_is_one_level(g, tx, ty, base, 1)
				var clear_far := clear_near and _box_is_one_level(g, tx, ty, base, 2)
				for raw_dir: Vector2 in dirs:
					for raw_mag in MAGS:
						var mag := float(raw_mag)
						var off: Vector2 = raw_dir * mag
						var kept: Vector2 = _field._offset_kept_on_level(g, at, off)
						cases += 1
						var drawn := at + kept
						if g.level_at(int(round(drawn.x)), int(round(drawn.y))) != base:
							if bad.size() < 4:
								bad.append("%s 조각(%d,%d) 오프셋%s" % [label, tx, ty, str(off)])
						# The defect itself, with the fix taken back out.
						var raw := at + off
						if g.level_at(int(round(raw.x)), int(round(raw.y))) != base:
							if hand:
								raw_bad_hand += 1
							else:
								raw_bad_gen += 1
						if kept != off:
							shrunk += 1
						var clear: bool = clear_near if mag <= 0.5 else clear_far
						if clear:
							_free_cases += 1
							if kept != off and _free_bad.size() < 4:
								_free_bad.append("%s 조각(%d,%d) 오프셋%s" % [label, tx, ty, str(off)])

	t.ok(cases > 500_000, "쓸어본 경우가 오십만을 넘는다 — 자가 점검 (%d 건)" % cases)
	t.eq(bad.size(), 0, "그려지는 점이 눈금이 다른 조각에 하나도 안 앉는다 %s" % str(bad))
	t.ok(raw_bad_hand > 0,
		"뒤집기 — 손으로 그린 섬에서 안 줄인 오프셋은 실제로 절벽을 넘는다 (%d 건)" % raw_bad_hand)
	t.ok(raw_bad_gen > 0,
		"뒤집기 — 생성된 섬에서도 안 줄인 오프셋이 절벽을 넘는다 (%d 건)" % raw_bad_gen)
	t.ok(shrunk > 0, "실제로 줄인 경우가 있다 — 자가 점검 (%d 건)" % shrunk)


## Whether every 조각 within `r` of `(tx, ty)` carries `base` as its 눈금. **A sufficient test for 「no
## ledge within reach」**: the whole segment stays inside this box, so a box of one 눈금 cannot hide one.
func _box_is_one_level(g: Grid, tx: int, ty: int, base: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if g.level_at(tx + dx, ty + dy) != base:
				return false
	return true


# == the named run =====================================================================================

## **The five 조각 the user watched a 부대 walk along the cliff top are each held back**, one row each.
## ⚠⚠ **NOT AN AGGREGATE.** A fix that mends the sweep's count while leaving this run lifted is the exact
## shape the user would see again, and a count cannot say it happened.
func _the_cliff_run_the_user_walked(t) -> void:
	var g := Grid.new()
	Islands.load_into(g)
	for tx in range(RUN_X0, RUN_X1 + 1):
		var at := Vector2(float(tx), float(RUN_Y))
		var base := g.level_at(tx, RUN_Y)
		var raw := at + RUN_OFF
		t.ok(g.level_at(int(round(raw.x)), int(round(raw.y))) != base,
			"뒤집기 — 조각(%d,%d) 은 안 줄이면 정말로 눈금이 다른 조각에 앉는다" % [tx, RUN_Y])
		var kept: Vector2 = _field._offset_kept_on_level(g, at, RUN_OFF)
		var drawn := at + kept
		t.ok(kept != RUN_OFF and g.level_at(int(round(drawn.x)), int(round(drawn.y))) == base,
			"조각(%d,%d) 은 절벽 앞에서 멈춘다" % [tx, RUN_Y])


# == no ledge, no shrink ===============================================================================

## **On a 조각 with no differing 눈금 within reach the offset comes back UNCHANGED, bit for bit.**
##
## ⚠⚠ **WITHOUT THIS ROW `return Vector2.ZERO` PASSES THE SWEEP AND THE NAMED RUN BOTH**, and deletes the
## whole seat spread on its way — nine bodies stacked on one point, silently. The inversion runs the row's
## own predicate over a flat board against that answer and requires every case to be caught.
func _no_ledge_no_shrink(t) -> void:
	t.ok(_free_cases > 100_000,
		"절벽이 안 닿는 경우를 충분히 쓸었다 — 자가 점검 (%d 건)" % _free_cases)
	t.eq(_free_bad.size(), 0, "절벽이 없으면 오프셋을 한 톨도 안 줄인다 %s" % str(_free_bad))

	# **The inversion**, on a board that is one 눈금 everywhere the reach can see. The real answer keeps
	# every offset; a `Vector2.ZERO` answer keeps none.
	# ⚠⚠ **THIS ROW USED TO COMPARE `Vector2.ZERO` AGAINST `off` AND NEVER CALL THE FUNCTION** — the logic
	# was right and it measured nothing at all (`verify`, second round). **An inversion that does not drive
	# the subject is an assertion about arithmetic**, and it would have stayed green with the whole file
	# deleted. It drives the function now and compares the two answers side by side.
	var g := Grid.new()
	g.load_rows(WALK_ROWS, WALK_TIERS)
	var at := Vector2(2.0, float(WALK_Y))
	var kept_all := 0
	var zero_caught := 0
	var total := 0
	for raw_dir: Vector2 in _dirs():
		for raw_mag in MAGS:
			var off: Vector2 = raw_dir * float(raw_mag)
			total += 1
			var answer: Vector2 = _field._offset_kept_on_level(g, at, off)
			if answer == off:
				kept_all += 1
			if answer != Vector2.ZERO:
				zero_caught += 1
	t.eq(kept_all, total, "평평한 판 한가운데서는 서른두 경우 다 그대로 돌아온다")
	t.eq(zero_caught, total,
		"뒤집기 — 진짜 답이 서른두 경우 다 0 이 아니다, 그러니 전부 0 인 답은 이 줄에 걸린다")


# == a foot on the 조각 line ============================================================================

## **`at` sitting EXACTLY on a 조각 line is still held to its own 눈금.**
##
## ⚠⚠ **THE FIRST BUILD PUNCHED THROUGH HERE**, and it is the one shape 「walk out from a 조각 centre」
## does not cover: `round` sends a point on `k + 0.5` to `k + 1`, so the base is read off the far 조각
## while a backwards offset starts on the near one, and the stretch before the first crossing was taken
## on trust. `verify` measured 770 of 20448 such cases wrong on the hand island.
## ⚠ **`verify` found no live path that reaches an exact half** — `Battle._walk` snaps to integer centres
## and interpolates otherwise. **The row stands anyway**: the ticket's sentence is 「zero exceptions」, and
## a rule that holds only for the inputs it expected is a rule with a hole waiting for a caller.
func _a_piece_line_under_the_foot(t) -> void:
	var g := Grid.new()
	Islands.load_into(g)
	var dirs := _dirs()
	var bad: Array[String] = []
	var raw_bad := 0
	var cases := 0
	for ty in g.h:
		for tx in g.w:
			if not g.is_passable(tx, ty):
				continue
			for half: Vector2 in [Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5)]:
				var at := Vector2(float(tx), float(ty)) + half
				var base := g.level_at(int(round(at.x)), int(round(at.y)))
				for raw_dir: Vector2 in dirs:
					for raw_mag in MAGS:
						var off: Vector2 = raw_dir * float(raw_mag)
						cases += 1
						var drawn: Vector2 = at + _field._offset_kept_on_level(g, at, off)
						if g.level_at(int(round(drawn.x)), int(round(drawn.y))) != base:
							if bad.size() < 4:
								bad.append("발 %s 오프셋%s" % [str(at), str(off)])
						var raw := at + off
						if g.level_at(int(round(raw.x)), int(round(raw.y))) != base:
							raw_bad += 1
	t.ok(cases > 10_000, "조각 선 위에 선 경우를 충분히 쓸었다 — 자가 점검 (%d 건)" % cases)
	t.ok(raw_bad > 0, "뒤집기 — 조각 선 위에서도 안 줄인 오프셋은 절벽을 넘는다 (%d 건)" % raw_bad)
	t.eq(bad.size(), 0, "발이 조각 선 위에 정확히 놓여도 그려지는 점이 눈금을 안 바꾼다 %s" % str(bad))


# == the rule is actually wired in =====================================================================

## The glide entry a walking body used to leave behind at 조각 (8,3) — a whole storey up. **The resting
## glide's straight line back to the seat is what this row is about**, and this is its far end.
const GLIDE_FROM := Vector2(8.0, 3.9)
## How many frames of the glide are stepped, and how long each is. Together they walk the whole line.
const GLIDE_FRAMES := 60
const GLIDE_FRAME_SEC := 0.004


## **The real `_glided`, both branches, on the real island.**
##
## ⚠⚠ **THIS IS THE ROW THE SECOND ROUND EXISTS FOR.** `verify` reverted `_glided`'s call back to
## `return at + off` and ran the whole suite: **not one character of the result changed.** Every other row
## in this file calls `_offset_kept_on_level` directly, and `net_draw_leaf` only asks whether the name is
## in a table — 「is it called」 was measured nowhere at all, so **the user's bug could come all the way
## back and the repo would stay green.**
## ⚠ **The unclamped answer comes from `_glide_target`**, the same function `_glided` itself calls, so the
## inversion is the real line and not a copy of it written here.
func _the_rule_is_wired_into_glided(t) -> void:
	var g := Grid.new()
	Islands.load_into(g)
	var b := Battle.new()
	b.grid = g
	var fv := FieldView.new()
	fv.battle = b
	var at := Vector2(float(RUN_X0), float(RUN_Y))
	var base := g.level_at(RUN_X0, RUN_Y)
	var uid := 4_100_001
	t.ok(g.hold(uid, g.tile_index(RUN_X0, RUN_Y)), "자가 점검 — 몸 하나가 조각(8,3) 을 잡는다")

	# -- the walking branch --
	fv._seat_offset["s0"] = RUN_OFF
	var raw := at + RUN_OFF
	t.ok(g.level_at(int(round(raw.x)), int(round(raw.y))) != base,
		"뒤집기 — 안 줄인 걷는 답은 눈금이 다른 조각에 앉는다")
	var walked: Vector2 = fv._glided("s0", at, uid, false, 0.0)
	t.ok(g.level_at(int(round(walked.x)), int(round(walked.y))) == base,
		"진짜 _glided 의 걷는 갈래가 절벽을 안 넘는다 — 호출이 빠지면 이 줄이 빨개진다")

	# -- the resting branch, one frame at a time along the glide --
	var raw_bad := 0
	var clamped_bad := 0
	for k in range(1, GLIDE_FRAMES + 1):
		var delta := float(k) * GLIDE_FRAME_SEC
		fv._seat_glide["s0"] = GLIDE_FROM
		var target: Vector2 = fv._glide_target("s0", at, uid, true, delta)
		if g.level_at(int(round(target.x)), int(round(target.y))) != base:
			raw_bad += 1
		fv._seat_glide["s0"] = GLIDE_FROM
		var drawn: Vector2 = fv._glided("s0", at, uid, true, delta)
		if g.level_at(int(round(drawn.x)), int(round(drawn.y))) != base:
			clamped_bad += 1
	t.ok(raw_bad > 0,
		"뒤집기 — 자리로 미끄러지는 직선은 실제로 눈금이 다른 조각을 지난다 (%d/%d 프레임)"
			% [raw_bad, GLIDE_FRAMES])
	t.eq(clamped_bad, 0, "진짜 _glided 의 쉬는 갈래도 절벽을 안 넘는다 — 미끄러지는 내내")

	# **A settled body away from any ledge is not moved at all.**
	# ⚠⚠ **THIS ROW USED TO SAY 「a settled body is never moved」 FULL STOP, AND THE LENGTH CAP MADE THAT
	# FALSE.** The ray shape only shortened an offset pointing AT a ledge, and a seat never leaves its own
	# 칸; the cap shortens in every direction, so a body seated beside a cliff IS drawn in. **That is the
	# price the cap is paying and it is not weakened away** — the claim is narrowed to 「away from a ledge」
	# and the price itself is measured two rows down, at the 조각 the user named.
	var far := _a_piece_with_no_ledge_near(g)
	var far_uid := uid + 1
	t.ok(far.x >= 0.0, "자가 점검 — 절벽이 안 닿는 조각을 손섬에서 찾았다 %s" % str(far))
	t.ok(g.hold(far_uid, g.tile_index(int(far.x), int(far.y))), "자가 점검 — 거기에 몸 하나가 선다")
	fv._seat_glide.erase("f0")
	var seat: Vector2 = fv._glided("f0", far, far_uid, true, 0.016)
	t.ok(seat.is_equal_approx(fv._stand_point(far, far_uid, true)),
		"절벽에서 떨어진 자리에 앉은 몸은 규칙이 한 톨도 안 옮긴다")

	# The price, at 조각 (8,3): the seat IS drawn in, and **not past half a 조각**.
	fv._seat_glide.erase("s0")
	var near_seat: Vector2 = fv._glided("s0", at, uid, true, 0.016)
	var want: Vector2 = fv._stand_point(at, uid, true)
	t.ok(not near_seat.is_equal_approx(want), "절벽 옆에 앉은 몸은 자리 쪽으로 당겨진다 — 이게 값이다")
	t.ok((near_seat - at).length() > 0.49,
		"당겨져도 반 조각 밑으로는 안 준다 (%.4f 조각)" % (near_seat - at).length())
	fv.free()


## The first walkable 조각 of `g` with no other 눈금 anywhere in its eight neighbours, or `(-1, -1)`.
## **Searched rather than typed** so a board edit cannot leave this row pointing at a cliff.
func _a_piece_with_no_ledge_near(g: Grid) -> Vector2:
	for ty in g.h:
		for tx in g.w:
			if not g.is_passable(tx, ty):
				continue
			if _box_is_one_level(g, tx, ty, g.level_at(tx, ty), 1):
				return Vector2(float(tx), float(ty))
	return Vector2(-1.0, -1.0)


# == continuity ========================================================================================

## **Walking `at` at a ledge, the drawn point slides toward it and never steps.**
##
## ⚠⚠ **THIS IS THE ROW THAT REFUSES A FIXED-STEP SCAN.** Sixteen samples along a 0.943 조각 offset is a
## 0.059 조각 ladder under every walking body, and nothing else in this file can tell that apart from the
## exact answer. The inversion at the foot builds that ladder and requires it to be caught.
func _the_answer_slides_and_never_steps(t) -> void:
	var g := Grid.new()
	g.load_rows(WALK_ROWS, WALK_TIERS)
	t.eq(g.level_at(5, WALK_Y), 0, "자가 점검 — 걷는 판의 조각 5 는 0 층이다")
	t.eq(g.level_at(6, WALK_Y), 2, "자가 점검 — 걷는 판의 조각 6 은 2 층이다")

	var exact := _walk_drawn(g, false)
	var scanned := _walk_drawn(g, true)
	var last := float(exact[exact.size() - 1])
	t.ok(last > float(exact[0]), "자가 점검 — 걸음이 절벽 쪽으로 실제로 다가간다")
	t.ok(last < WALK_LEDGE_X, "걸음 끝에서도 그려지는 점이 절벽 선을 안 넘는다 (%.4f)" % last)
	# The unshortened answer at the last step is 6.343 — a whole 조각 past the line. Landing within a
	# hair of the line instead is what says the offset was held back rather than merely aimed short.
	t.ok(WALK_LEDGE_X - last < 0.01, "걸음 끝에서 그려지는 점이 절벽 선 바로 앞에 선다 (%.4f)" % last)
	var worst := _worst_step(exact)
	t.ok(worst <= WALK_BOUND,
		"절벽으로 걸어가는 동안 그려지는 점이 %.3f 조각 넘게 안 튄다 (최대 %.4f)" % [WALK_BOUND, worst])
	var scan_worst := _worst_step(scanned)
	t.ok(scan_worst > WALK_BOUND,
		"뒤집기 — 고정 간격 %d 단계로 훑는 답은 이 줄에 걸린다 (최대 %.4f)"
			% [WALK_SCAN_STEPS, scan_worst])


## The drawn x at every step of the walk, from the exact answer or from the refused scan.
func _walk_drawn(g: Grid, scanned: bool) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k in WALK_STEPS:
		var at := Vector2(WALK_FROM_X + float(k) * WALK_STEP, float(WALK_Y))
		var off: Vector2 = _scanned_offset(g, at, WALK_OFF) if scanned \
			else _field._offset_kept_on_level(g, at, WALK_OFF)
		out.append((at + off).x)
	return out


## The largest jump between two neighbouring steps of a walk.
func _worst_step(xs: PackedFloat64Array) -> float:
	var worst := 0.0
	for k in range(1, xs.size()):
		worst = maxf(worst, absf(float(xs[k]) - float(xs[k - 1])))
	return worst


## The refused shape, built here and nowhere else: `WALK_SCAN_STEPS` samples along the offset, keeping
## the last one still on the base 눈금. **It exists to be caught**, so it is written as plainly as the
## thing it stands in for.
func _scanned_offset(g: Grid, at: Vector2, off: Vector2) -> Vector2:
	var base := g.level_at(int(round(at.x)), int(round(at.y)))
	var kept := Vector2.ZERO
	for k in range(1, WALK_SCAN_STEPS + 1):
		var f := float(k) / float(WALK_SCAN_STEPS)
		var p := at + off * f
		if g.level_at(int(round(p.x)), int(round(p.y))) != base:
			break
		kept = off * f
	return kept


# == the jump ==========================================================================================

## Boards for the jump row: the hand island and this many generated ones.
const JUMP_SEEDS := 3
## How far `at` moves between two samples, how many samples along each axis from a 조각 centre, and the
## nudge that keeps every sample off a 조각 line. **50 steps of 0.02 is exactly one 조각 of travel**, so
## sweeping from every walkable 조각 covers every line between two neighbouring centres.
const JUMP_STEP := 0.02
const JUMP_SPAN := 50
const JUMP_NUDGE := 0.00373
## **The corner seat and nothing shorter.** The jump scales with the offset, so the longest offset a
## lattice seat can be is the worst case, and the worst case is what a bound is written against.
const JUMP_MAG := 0.943
## **The most the drawn point may move for one 0.02 조각 step of `at`.**
##
## ⚠⚠ **DERIVED, NOT TUNED.** The cap is a distance to a set of squares, so it is 1-Lipschitz in `at`:
## away from a 눈금 line the drawn point moves at most the step plus the cap's own change, 0.04. AT a
## line the cap is under the step on BOTH sides, so the two drawn points are within the step plus both
## caps, 0.06. **0.08 is that ceiling with float slack** — and it is twelve times under the 0.960 the ray
## shape produced, which is the number the inversion below has to break.
const JUMP_BOUND := 0.08
## What counts as 「the offset is gone」 when the price is being counted.
const NEAR_ZERO_TILES := 0.1


## **A 0.02 조각 step of `at` never moves the drawn point more than `JUMP_BOUND`** — over the hand island
## and `JUMP_SEEDS` generated ones, and **only across steps `Grid.can_step` allows**, so a 0↔2 line no
## body can walk is not counted.
##
## ⚠⚠ **THIS ROW IS WHY THE RULE CHANGED SHAPE.** The ray version measured **0.960 조각 in one frame, 168
## reachable positions on the hand island** — a body walking onto a stair had its picture snap most of a
## 조각 sideways, and before this ticket the drawn point was perfectly continuous. **The ticket would have
## been introducing that teleport.** The inversion runs the same sweep through the ray rule, kept in this
## file for the purpose, and requires it to break the bound.
func _the_answer_never_teleports(t) -> void:
	var dirs := _dirs()
	var worst := 0.0
	var worst_ray := 0.0
	var jumpy := 0
	var jumpy_ray := 0
	var steps := 0
	var near_zero := 0
	var samples := 0
	for entry: Array in _boards(JUMP_SEEDS):
		var g: Grid = entry[1]
		for ty in g.h:
			for tx in g.w:
				if not g.is_passable(tx, ty):
					continue
				var home := Vector2(float(tx), float(ty)) + Vector2(JUMP_NUDGE, JUMP_NUDGE)
				for axis: Vector2 in [Vector2(1.0, 0.0), Vector2(0.0, 1.0)]:
					for raw_dir: Vector2 in dirs:
						var off: Vector2 = raw_dir * JUMP_MAG
						var prev := Vector2.ZERO
						var prev_at := Vector2.ZERO
						var have := false
						for k in JUMP_SPAN + 1:
							var at: Vector2 = home + axis * (float(k) * JUMP_STEP)
							var kept: Vector2 = _field._offset_kept_on_level(g, at, off)
							var drawn := at + kept
							samples += 1
							if kept.length() <= NEAR_ZERO_TILES:
								near_zero += 1
							if have and _a_body_could_take_it(g, prev_at, at):
								steps += 1
								var moved := drawn.distance_to(prev)
								worst = maxf(worst, moved)
								if moved > JUMP_BOUND:
									jumpy += 1
								var ray_here := at + _ray_rule(g, at, off)
								var ray_there := prev_at + _ray_rule(g, prev_at, off)
								var ray_moved := ray_here.distance_to(ray_there)
								worst_ray = maxf(worst_ray, ray_moved)
								if ray_moved > JUMP_BOUND:
									jumpy_ray += 1
							prev = drawn
							prev_at = at
							have = true
	t.ok(steps > 100_000, "몸이 실제로 뗄 수 있는 걸음을 충분히 쟀다 — 자가 점검 (%d 걸음)" % steps)
	t.ok(jumpy_ray > 0 and worst_ray > JUMP_BOUND,
		"뒤집기 — 옛 광선 규칙은 이 줄에 걸린다 (최대 %.3f 조각 · %d 걸음)" % [worst_ray, jumpy_ray])
	t.eq(jumpy, 0, "0.02 조각 걸음에 그려지는 점이 %.2f 조각 넘게 안 튄다 (최대 %.4f)"
		% [JUMP_BOUND, worst])
	t.ok(near_zero > 0,
		"값 — 절벽을 넘는 동안 오프셋이 실제로 0 까지 줄어든다 (%d/%d 표본)" % [near_zero, samples])


## Whether a body could take the step between two drawn-point samples: it stays inside one 조각, or the
## 조각 it moves between is one `Grid.can_step` allows. **Off the board is not a step.**
func _a_body_could_take_it(g: Grid, from: Vector2, to: Vector2) -> bool:
	var ax := int(round(from.x))
	var ay := int(round(from.y))
	var bx := int(round(to.x))
	var by := int(round(to.y))
	if ax < 0 or ay < 0 or ax >= g.w or ay >= g.h:
		return false
	if bx < 0 or by < 0 or bx >= g.w or by >= g.h:
		return false
	if ax == bx and ay == by:
		return true
	return g.can_step(g.tile_index(ax, ay), g.tile_index(bx, by))


## **The shape this ticket replaced** — walk out ALONG `off` and stop before the first 조각 of another
## 눈금. It lives here and nowhere else, so the jump row can prove it is measuring the thing that was
## wrong rather than a bound nothing could ever break.
func _ray_rule(g: Grid, at: Vector2, off: Vector2) -> Vector2:
	var reach := off.length()
	if reach <= 0.0:
		return off
	var base := g.level_at(int(round(at.x)), int(round(at.y)))
	var ts := _ray_stretches(at, off)
	for i in ts.size():
		var t := float(ts[i])
		var next_t := 1.0 if i + 1 >= ts.size() else float(ts[i + 1])
		var mid := at + off * ((t + next_t) * 0.5)
		if g.level_at(int(round(mid.x)), int(round(mid.y))) == base:
			continue
		return off * maxf(t - Look.LEDGE_INSET_TILES / reach, 0.0)
	return off


## Where each 조각 the ray lies in begins: `0.0`, then every crossing in `(0, 1]`, sorted, ties merged.
func _ray_stretches(at: Vector2, off: Vector2) -> PackedFloat64Array:
	var raw := PackedFloat64Array()
	_ray_axis(at.x, off.x, raw)
	_ray_axis(at.y, off.y, raw)
	raw.sort()
	var out := PackedFloat64Array([0.0])
	for i in raw.size():
		var t := float(raw[i])
		if t <= 0.0 or t > 1.0:
			continue
		if t - float(out[out.size() - 1]) <= 1e-9:
			continue
		out.append(t)
	return out


## The `t` at which one axis crosses each `k + 0.5`, appended raw — the caller sorts and clips.
func _ray_axis(a: float, d: float, into: PackedFloat64Array) -> void:
	if absf(d) <= 1e-12:
		return
	var lo := minf(a, a + d)
	var hi := maxf(a, a + d)
	for k in range(floori(lo - 0.5), ceili(hi - 0.5) + 1):
		into.append((float(k) + 0.5 - a) / d)


# == what the cap costs ================================================================================

## Boards the price is counted over: the hand island and this many generated ones.
const COST_SEEDS := 10


## **What the length cap costs the seat spread, as a number.**
##
## ⚠⚠ **THE FEAR WAS 「a row of dead-centred bodies along the cliff」 AND THE MEASUREMENT SAYS NO.** A body
## at rest stands on a 조각 CENTRE, and the nearest 조각 of another 눈금 has its square half a 조각 away —
## so **the cap can never pull a resting body inside half a 조각**, whatever it is standing next to. What
## it does take is the corner seats, which reach 0.943: those are drawn in to 0.499 beside a ledge. The
## counts go in the labels so the user reads the price rather than being told it is small.
func _what_the_cap_costs_the_spread(t) -> void:
	var dirs := _dirs()
	var walkable := 0
	var pulled := 0
	var near_zero := 0
	var min_kept := 99.0
	for entry: Array in _boards(COST_SEEDS):
		var g: Grid = entry[1]
		for ty in g.h:
			for tx in g.w:
				if not g.is_passable(tx, ty):
					continue
				walkable += 1
				var at := Vector2(float(tx), float(ty))
				var hit := false
				for raw_dir: Vector2 in dirs:
					var off: Vector2 = raw_dir * JUMP_MAG
					var kept: Vector2 = _field._offset_kept_on_level(g, at, off)
					if kept == off:
						continue
					hit = true
					var len_kept := kept.length()
					min_kept = minf(min_kept, len_kept)
					if len_kept <= NEAR_ZERO_TILES:
						near_zero += 1
				if hit:
					pulled += 1
	t.ok(walkable > 1000, "자가 점검 — 손섬과 시드 %d 개의 걸을 수 있는 조각을 다 셌다 (%d)"
		% [COST_SEEDS, walkable])
	t.ok(pulled > 0, "값 — 자리가 실제로 당겨지는 조각이 있다 (%d/%d 조각)" % [pulled, walkable])
	t.eq(near_zero, 0,
		"쉬는 몸은 한 조각도 자리를 통째로 잃지 않는다 — 당겨진 자리 중 %.2f 조각 이하가 없다"
			% NEAR_ZERO_TILES)
	t.ok(min_kept > 0.49,
		"쉬는 몸의 자리는 반 조각 밑으로 안 준다 — 당겨진 것 중 가장 짧은 것이 %.4f 조각" % min_kept)


# == the stair =========================================================================================

## **A stair 조각 still slides under a body's feet** — two points INSIDE one 조각 of a run answer with
## different `surface_h`.
##
## ⚠⚠ **「the mouth 조각 and the head 조각 differ」 DOES NOT MEASURE THIS.** Every 조각 of a run carries the
## same 눈금, so that pair stays true even if `surface_h` snapped every point to its 조각 centre — which is
## the one way this ticket could break the climb. **Only two points inside ONE 조각 can say it.**
func _a_stair_still_slides_inside_one_piece(t) -> void:
	var g := Grid.new()
	Islands.load_into(g)
	var stairs := 0
	var sliding := 0
	for ty in g.h:
		for tx in g.w:
			if not Grid.is_stair_level(g.level_at(tx, ty)):
				continue
			stairs += 1
			var run: Array = g.stair_run_of(g.tile_index(tx, ty))
			if run.is_empty():
				continue
			var ax: Vector2i = run[0]
			var axis := Vector2(float(ax.x), float(ax.y))
			var centre := Vector2(float(tx), float(ty))
			if not is_equal_approx(g.surface_h(centre - axis * 0.49),
					g.surface_h(centre + axis * 0.49)):
				sliding += 1
	t.ok(stairs > 0, "자가 점검 — 손으로 그린 섬에 계단 조각이 있다 (%d 개)" % stairs)
	t.ok(sliding > 0,
		"계단은 한 조각 안에서도 발밑이 오른다 — 조각 한가운데로 스냅되지 않았다 (%d/%d 조각)"
			% [sliding, stairs])


# == fixture ===========================================================================================

## The hand-drawn island first, then `SEEDS` generated ones. **Made once and handed to the sweep**, which
## is the only row that wants them all.
func _boards(seeds: int = SEEDS) -> Array:
	var out: Array = []
	var hand := Grid.new()
	Islands.load_into(hand)
	out.append(["손섬", hand, true])
	for s in range(1, seeds + 1):
		var board: Dictionary = IslandGen.board(s)
		if board.is_empty():
			continue
		var g := Grid.new()
		Islands.load_board(g, board)
		out.append(["시드%d" % s, g, false])
	return out


## The eight directions a seat offset can point, each a unit vector. **Diagonals are normalised**, so a
## magnitude means the same length in every direction and the corner seats are measured at their own reach.
func _dirs() -> Array:
	var out: Array = []
	for raw: Array in [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]:
		out.append(Vector2(float(raw[0]), float(raw[1])).normalized())
	return out
