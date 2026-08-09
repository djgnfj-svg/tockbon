extends RefCounted
## The attack prediction (`docs/design/attack-prediction.md`) — replaces the "!" windup tell with a red mark
## on the ground shaped to each move. **Driven, not grepped** — the same technique already proved three times
## this plan (`_can_pick` on an untreed `CircleWindow`, `_set_loadout` on a live `Stage`, `_revoke_unowned_rune`
## called directly): a subclass overrides the two low-level primitives (`_draw_predict_rect`/`_draw_predict_ring`)
## to record the exact geometry asked for, and every check here reads that recorded geometry by value.
##
## **The top-level WINDUP/STUN dispatch is `net_monster_charge.gd`'s own test**
## (`_pattern_indicator_draws_the_right_thing_for_the_right_state`) — not duplicated here, only renamed there
## when the leaf it recorded ("telegraph") was retired. This file starts one level in: given WINDUP is
## showing, does the *right shape* appear for the *right move*, with the *right numbers*.
##
## **What this file cannot measure**: pixel-level appearance (color, the pulse actually reading as urgent at
## 0.4s) — that is verify-look's seat, honestly, the same line `net_monster_charge.gd`'s own comment already
## draws for `_draw()`.

const MonsterView := preload("res://src/view/monster_view.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const BossAi := preload("res://src/actor/boss_ai.gd")
const MonsterBolts := preload("res://src/actor/monster_bolts.gd")
const Character := preload("res://src/actor/character.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const FLOOR_W_CX := 2000


## Records the actual geometry each move's shape asks to be drawn — one level lower than
## `net_monster_charge.gd`'s own recording view (which only records *which* leaf ran). Overriding the two
## shared primitives instead of each move's own function catches every move through one seat, and catches a
## mutation that keeps the right function running but wrongs the numbers inside it (the class this file's own
## header exists to close — a branch-swap alone is not the only way this could quietly lie).
class _GeometryRecordingView extends MonsterView:
	var rects: Array[Rect2] = []
	var rings: Array[Dictionary] = []
	var stun_ran := false

	func _draw_predict_rect(rect: Rect2) -> void:
		rects.append(rect)

	func _draw_predict_ring(center: Vector2, radius: float) -> void:
		rings.append({"center": center, "radius": radius})

	func _draw_stun_ring(_r: Rect2) -> void:
		stun_ran = true


func run(t) -> void:
	_charge_lane_is_capped_by_the_safety_distance_on_an_open_floor(t)
	_charge_lane_is_capped_by_the_safety_distance_in_phase2(t)
	_charge_lane_stops_at_the_real_wall_not_the_safety_cap(t)
	_fire_stream_is_bolt_range_horizontal_from_the_spawn_point(t)
	_gore_reach_is_54px_not_the_120px_gate(t)
	_gore_reach_is_symmetric_not_directional(t)
	_slam_landing_uses_the_continuous_estimate_and_adds_the_ignite_ring(t)
	_leap_landing_has_no_ignite_ring(t)
	_direction_tracks_the_live_player_not_the_stale_pattern_dir(t)
	_gore_substitutes_for_charge_live_when_in_range_and_reverts_when_not(t)
	_a_move_choice_swap_draws_the_wrong_shape_and_the_check_catches_it(t)


# ══════════════════════════════════════════════════════════════════
#  CHARGE — the lane
# ══════════════════════════════════════════════════════════════════

## **Independently-derived expected distance, not the same formula re-read** — the plan's own numbers
## ("up to 61 ticks at 280 px/s") computed by hand: 61 ticks x 0.05s x 280px/s = 854.0px. Re-deriving the
## formula from `BossAi`'s own constants and comparing it against this fixed literal is what catches a
## mutation to the formula itself; comparing two computations of the same formula would not.
func _charge_lane_is_capped_by_the_safety_distance_on_an_open_floor(t) -> void:
	var kind := Defs.KIND_BULL
	var stand_x := 5000   # far from any wall on the open floor grid
	var m := Monster.new(1, kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.CHARGE
	m.pattern_dir = -1

	var view := _GeometryRecordingView.new()
	view.setup(null, null, _floor_grid())
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rects.size(), 1, "차징 예고가 사각형 하나를 그린다 (전제)")
	t.eq(view.rects[0].size.x, 854.0,
		"열린 바닥에서 차징 예고 길이가 안전 거리(854px = 61틱 x 0.05s x 280px/s)와 같다")
	t.eq(view.rects[0].size.y, float(Defs.h_px(kind)), "예고 띠의 높이가 황소 상자 높이와 같다")
	view.free()


## Phase 2 halves the duration and doubles the speed (`PHASE2_DURATION_DIVISOR`/`PHASE2_SPEED_MULT`) —
## **31 ticks x 0.05s x 560px/s = 868.0px**, the plan's own second number, independently derived the same way.
func _charge_lane_is_capped_by_the_safety_distance_in_phase2(t) -> void:
	var kind := Defs.KIND_BULL
	var stand_x := 5000
	var m := Monster.new(1, kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	m.hp = 1   # phase 2 = hp*2 <= max_hp
	t.ok(m.is_phase2(), "2페이즈 조건을 채웠다 (전제)")
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.CHARGE
	m.pattern_dir = -1

	var view := _GeometryRecordingView.new()
	view.setup(null, null, _floor_grid())
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rects.size(), 1, "2페이즈에서도 예고 사각형이 하나다 (전제)")
	t.eq(view.rects[0].size.x, 868.0,
		"2페이즈 차징 예고 길이가 868px(31틱 x 0.05s x 560px/s)와 같다 — 열린 바닥의 854px보다 길다")
	view.free()


## **Hand-derived against a real wall, not against the code's own raycast result.** A 4-cell wall (16px) is
## built at cx 100-103 (px [400,416)); the bull stands at x=600 charging left. The box (88px wide) is blocked
## the instant its right edge would enter the wall — worked out by hand: the lane must stop with its own left
## edge flush at x=416 (the wall's own near face), stepping in `Tuning.CELL_PX` increments from x=600, **never**
## reaching the 854px safety-cap distance the check above already pins.
func _charge_lane_stops_at_the_real_wall_not_the_safety_cap(t) -> void:
	var kind := Defs.KIND_BULL
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(100, FLOOR_CY - 20, 103, FLOOR_CY - 1, Mat.STONE))

	var stand_x := 600
	var m := Monster.new(1, kind, stand_x, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.CHARGE
	m.pattern_dir = -1

	var view := _GeometryRecordingView.new()
	view.setup(null, null, g)
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rects.size(), 1, "벽 앞에서도 예고 사각형이 하나다 (전제)")
	var lane := view.rects[0]
	t.eq(lane.position.x, 416.0, "예고 띠가 벽면(x=416)에서 정확히 멈춘다 (안전거리 854px까지 안 간다)")
	t.eq(lane.size.x, 184.0, "예고 띠 길이가 600 -> 416, 184px다")
	view.free()


# ══════════════════════════════════════════════════════════════════
#  FIRE — the stream
# ══════════════════════════════════════════════════════════════════

## The line originates at `m.center()` (the exact point `WorldStep.frame()`'s own `_bolts.spawn(m.center().x,
## m.center().y, ...)` call uses for the real bolt) and is exactly `BOLT_RANGE_PX` long, horizontal only.
func _fire_stream_is_bolt_range_horizontal_from_the_spawn_point(t) -> void:
	var kind := Defs.KIND_BULL
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.FIRE
	m.pattern_dir = 1

	var view := _GeometryRecordingView.new()
	view.setup(null, null, null)
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rects.size(), 1, "화염 예고가 사각형 하나를 그린다 (전제)")
	var line := view.rects[0]
	var c := m.center()
	t.eq(line.position.x, c.x, "화염 줄기가 몸통 중심(발사 지점)에서 시작한다")
	t.eq(line.size.x, MonsterBolts.BOLT_RANGE_PX, "화염 줄기 길이가 BOLT_RANGE_PX(480)와 같다")
	t.eq(line.get_center().y, c.y, "화염 줄기가 몸통 중심 높이에서 수평이다 (세로 성분이 없다)")
	view.free()

	# The other direction — the line must extend the other way, not just mirror in place.
	m.pattern_dir = -1
	var view2 := _GeometryRecordingView.new()
	view2.setup(null, null, null)
	view2._draw_pattern_indicator(m, r)
	var line2 := view2.rects[0]
	t.eq(line2.position.x, c.x - MonsterBolts.BOLT_RANGE_PX, "반대쪽을 보면 줄기가 반대쪽으로 뻗는다")
	view2.free()


# ══════════════════════════════════════════════════════════════════
#  GORE — the real reach, not the gate
# ══════════════════════════════════════════════════════════════════

## `(88 + 20) / 2 = 54`, the plan's own number — not `BossAi.gore_range_px`'s 120.
func _gore_reach_is_54px_not_the_120px_gate(t) -> void:
	var kind := Defs.KIND_BULL
	t.eq(BossAi.gore_range_px(kind), 120.0, "고르기 선택 게이트는 120px다 (전제 — 이 값을 그리면 안 된다)")

	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.CHARGE   # gore substitutes for charge
	var target_x := m.center().x   # standing right under it — well inside 54px, let alone 120px
	var target_y := float(m.y)

	var view := _GeometryRecordingView.new()
	view.setup(null, _still_char(m, target_x, target_y), null)
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rects.size(), 1, "고르기 예고가 사각형 하나를 그린다 (전제)")
	t.eq(view.rects[0].size.x, 108.0, "고르기 예고 폭이 108px다 (54px x 2 — 120px 게이트가 아니다)")
	view.free()


## Box overlap does not care which side the player stands on — the band is centered on the monster, not
## thrown out in `dir`'s direction the way the charge lane and fire stream are.
func _gore_reach_is_symmetric_not_directional(t) -> void:
	var kind := Defs.KIND_BULL
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.CHARGE
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	var reach := (float(Defs.w_px(kind)) + Character.W_PX) * 0.5

	for target_x: float in [m.center().x - 1.0, m.center().x + 1.0]:
		var view := _GeometryRecordingView.new()
		view.setup(null, _still_char(m, target_x, float(m.y)), null)
		view._draw_pattern_indicator(m, r)
		t.eq(view.rects[0].position.x, m.center().x - reach,
			"플레이어가 %s쪽에 있어도 고르기 띠는 몸통 중심에 그대로 대칭이다" % ("왼" if target_x < m.center().x else "오른"))
		view.free()


# ══════════════════════════════════════════════════════════════════
#  SLAM / LEAP — the landing marker
# ══════════════════════════════════════════════════════════════════

## `air_time = 2*450/2400 = 0.375s`, `h_speed = 140 * 1.5 = 210px/s` (`MOVE_SLAM.leap_speed_mult`) ->
## `dist = 78.75px`, independently computed by hand from the same public numbers `boss_ai.gd` documents.
## **Two rings** — the landing marker, and the ignite ring at `spread_cells(6) x (points(5)/2=2) + ignite_r(2)
## = 14 cells = 56px`, the exact ±56px the plan's own message names.
func _slam_landing_uses_the_continuous_estimate_and_adds_the_ignite_ring(t) -> void:
	var kind := Defs.KIND_BULL
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.SLAM
	m.pattern_dir = 1

	var view := _GeometryRecordingView.new()
	view.setup(null, null, null)
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rings.size(), 2, "슬램 예고는 착지 고리와 점화 고리, 둘을 그린다")
	var landing_x: float = m.center().x + 78.75
	t.ok(is_equal_approx(view.rings[0]["center"].x, landing_x),
		"착지 지점이 몸통 중심에서 78.75px 앞이다 (2*450/2400 x 140*1.5)")
	t.eq(view.rings[0]["center"].y, r.end.y, "착지 지점이 상자의 바닥선(발이 닿는 y)에 있다")
	t.eq(view.rings[0]["radius"], maxf(r.size.x, r.size.y) * 0.5, "착지 고리 반지름이 상자 크기에서 나온다")
	t.eq(view.rings[1]["radius"], 56.0, "점화 고리 반지름이 56px다 (스프레드 6 x (점 5/2=2) + 반경 2 = 14칸)")
	t.eq(view.rings[1]["center"], view.rings[0]["center"], "점화 고리도 같은 착지 지점을 중심으로 한다")
	view.free()


## The rooster's leap ignites nothing — only the landing marker, never a second ring.
func _leap_landing_has_no_ignite_ring(t) -> void:
	var kind := Defs.KIND_ROOSTER
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.pattern_dir = 1

	var view := _GeometryRecordingView.new()
	view.setup(null, null, null)
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	t.eq(view.rings.size(), 1, "수탉의 도약 예고는 착지 고리 하나뿐이다 (점화 고리가 없다)")
	var landing_x: float = m.center().x + 400.0 * (2.0 * 500.0 / Character.GRAVITY_PX)
	t.ok(is_equal_approx(view.rings[0]["center"].x, landing_x),
		"착지 지점이 2*500/2400 x (200*2.0)로 계산된다")
	view.free()


# ══════════════════════════════════════════════════════════════════
#  Honesty — live-tracks the player, does not lie from the stale `pattern_dir`
# ══════════════════════════════════════════════════════════════════

## **The core contract of this whole feature.** `pattern_dir` still holds whatever the *previous* move locked
## — during WINDUP the sim has not touched it yet (`boss_ai.gd`'s own header). Setting it to one side while
## the live player stands on the other and asserting the mark follows the player, not the stale field, is
## what proves this doesn't lie for however long WINDUP has left.
func _direction_tracks_the_live_player_not_the_stale_pattern_dir(t) -> void:
	var kind := Defs.KIND_BULL
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.FIRE
	m.pattern_dir = 1   # stale — locked by whatever the *previous* move was

	var char := _still_char(m, m.center().x - 200.0, float(m.y))   # the live player is to the LEFT
	var view := _GeometryRecordingView.new()
	view.setup(null, char, null)
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	view._draw_pattern_indicator(m, r)

	var c := m.center()
	t.eq(view.rects[0].position.x, c.x - MonsterBolts.BOLT_RANGE_PX,
		"플레이어가 왼쪽에 있으면 stale pattern_dir(+1)이 아니라 실제 방향(왼쪽)으로 그려진다")
	view.free()

	# Move the player to the right instead — the mark must follow, live, same stale `pattern_dir` throughout.
	var char2 := _still_char(m, m.center().x + 200.0, float(m.y))
	var view2 := _GeometryRecordingView.new()
	view2.setup(null, char2, null)
	view2._draw_pattern_indicator(m, r)
	t.eq(view2.rects[0].position.x, c.x, "플레이어가 오른쪽으로 옮기면 같은 stale pattern_dir인데도 마크가 따라간다")
	view2.free()


## **Gore substitution is decided at the same instant as direction, and this checks it is tracked the same
## way.** Standing inside `gore_range_px` at the moment WINDUP ends means gore fires, not a charge — this
## checks the *shape drawn* flips with the live distance, not with anything cached on `m`.
func _gore_substitutes_for_charge_live_when_in_range_and_reverts_when_not(t) -> void:
	var kind := Defs.KIND_BULL
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.CHARGE
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))
	var g := _floor_grid()

	# Close — inside 54px reach, well inside the 120px gate too. Gore's own band (108px wide) draws.
	var close := _still_char(m, m.center().x + 10.0, float(m.y))
	var v1 := _GeometryRecordingView.new()
	v1.setup(null, close, g)
	v1._draw_pattern_indicator(m, r)
	t.eq(v1.rects[0].size.x, 108.0, "가까이 있으면 고르기 띠(108px)가 그려진다")
	v1.free()

	# Far — outside the 120px gate entirely. The charge lane draws instead (capped at 854px on the open floor).
	var far := _still_char(m, m.center().x + 5000.0, float(m.y))
	var v2 := _GeometryRecordingView.new()
	v2.setup(null, far, g)
	v2._draw_pattern_indicator(m, r)
	t.eq(v2.rects[0].size.x, 854.0, "멀리 있으면 고르기가 아니라 차징 예고(854px)가 그려진다")
	v2.free()


# ══════════════════════════════════════════════════════════════════
#  Branch swap — the plan's own explicit mutation requirement
# ══════════════════════════════════════════════════════════════════

## **`net_monster_charge.gd`'s own dispatch test already proves WINDUP never draws the stun ring's shape and
## vice versa.** This is the same class of check one level in: a charge drawing gore's shape (or the reverse)
## must go red too. Proven by construction — the close/far pair above (`_gore_substitutes_for_charge_live_
## when_in_range_and_reverts_when_not`) already produces two different widths for the two branches; this
## function exists only to say plainly that swapping which branch fires for which distance is exactly what
## that check's two assertions catch, so a reviewer does not have to infer it from the numbers alone.
func _a_move_choice_swap_draws_the_wrong_shape_and_the_check_catches_it(t) -> void:
	var kind := Defs.KIND_BULL
	var m := Monster.new(1, kind, 600, FLOOR_TOP - Defs.h_px(kind))
	m.pattern = BossAi.Pattern.WINDUP
	m.move_choice = BossAi.MoveChoice.FIRE
	m.pattern_dir = 1
	var r := Rect2(m.x, m.y, Defs.w_px(kind), Defs.h_px(kind))

	var view := _GeometryRecordingView.new()
	view.setup(null, null, null)
	view._draw_pattern_indicator(m, r)
	# FIRE's own shape is a thin BOLT_RANGE_PX line. A charge lane (854px, box-height-thick) or a gore band
	# (108px) would both fail this same assertion, so a branch swap in either direction goes red here.
	t.eq(view.rects[0].size.x, MonsterBolts.BOLT_RANGE_PX,
		"FIRE가 선택됐는데 화염 줄기가 아닌 다른 폭이 그려지면 여기서 걸린다")
	t.ok(view.rects[0].size.y != float(Defs.h_px(kind)),
		"화염 줄기의 두께가 차징 띠의 상자 높이와 같지 않다 (모양이 실제로 다르다)")
	view.free()


# ══════════════════════════════════════════════════════════════════
#  Tools
# ══════════════════════════════════════════════════════════════════

func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, FLOOR_W_CX - 1, FLOOR_CY + 8 - 1, Mat.STONE))
	return g


## A `Character` placed so its own center sits at `(target_x, target_y)` — the same "own snapshot" shape
## `Monster._vertically_overlaps_target`/`WorldStep`'s own `target_x`/`target_y` already read, built directly
## rather than through a `WorldStep` (none of these checks need the tick machine, only a live position).
func _still_char(_m: Monster, target_x: float, target_y: float) -> Character:
	var ch := Character.new()
	ch.place(roundi(target_x - Character.W_PX * 0.5), roundi(target_y - Character.H_PX * 0.5))
	return ch
