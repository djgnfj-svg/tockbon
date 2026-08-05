extends RefCounted
## 지팡이 끝 — `docs/plans/2.active/staff-and-fire-origin.md`.
##
## 🔴🔴 **이 그물이 있는 이유가 배치 하나다.** 끝을 구하는 함수가 `src/view/` 에 있었으면
##  씬을 세워야 하고 헤드리스에는 픽셀이 없다 ⇒ 「벽에 붙어 쏘면 어디가 파이나」가 **눈에만** 남는다.
##  `src/actor/staff.gd` 로 옮기면서 그게 **값**이 됐다.
##
## 🔴🔴 **대조군이 이 그물의 절반이다.** 「끝 셀이 빈칸이다」만 재면 **캐릭터를 벽에서 멀리
##  세워 놔도 초록**이고, 그러면 배치가 관문인지도 모르는 채 통과한다.
##  ⇒ 같은 배치에서 **클램프 없는 값**(`pivot + dir × LEN_PX`)이 **실제로 고체 셀**인 것을 같이 잰다.
##  (`net_damage._run_gauntlet` 의 대조군과 같은 어법이다.)
##
## ⚠ **이 그물이 원리적으로 못 잴 것 — 라벨을 여기까지 넓히지 마라:**
##  · **그림 끝과 발사 자리가 같나** — 코드가 같은 함수를 부르는 것까지는 구조가 막지만
##    **그려진 픽셀은 눈이다**
##  · **`draw_set_transform` 복원** — `character_view.gd:131` 실측: 지워도 전부 초록이었다
##  · **지팡이가 손에서 나가는 것으로 읽히나 · 위·아래가 어색하지 않나** — 눈이다

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Character := preload("res://src/actor/character.gd")
const Staff := preload("res://src/actor/staff.gd")
## 🔴 그물은 폴더 계약 **밖**이다 — `src/view/` 를 봐도 된다(`net_layers.RULES` 는 `src/` 만 훑는다).
##  고리 색(`staff_tint`)이 연출 상수라 여기 있고, 그걸 재는 검사가 아래 하나 있다.
const Fx := preload("res://src/view/fx_tuning.gd")

## 🔴 상자를 **셀에 딱 맞춰** 세운다. 안 맞으면 「상자가 덮는 셀」을 손으로 세게 되고,
##  그 셈이 틀려도 아무도 안 짖는다. 아래 첫 단언이 딱 맞는 것을 확인한다.
const BOX_CX := 80
const BOX_CY := 192
const BOX_X := BOX_CX * Tuning.CELL_PX
const BOX_Y := BOX_CY * Tuning.CELL_PX

## 벽 세상의 돌기둥(셀). 🔴 **두꺼워야 한다** — 한 칸이면 클램프 없는 값(36px 앞)이 기둥을
##  **지나쳐** 빈칸에 앉고, 그러면 대조군이 「고체다」를 못 단언해 이 그물의 절반이 죽는다.
const WALL_CX0 := 88
const WALL_CX1 := 95

## 여덟 방향. 🔴 **정수로 적고 여기서 정규화한다** — 축평행 방향의 성분이 **정확히 0**이어야
##  `_axis_exit` 의 「이 축은 안 가둔다」 갈래를 실제로 지난다. `rotated()` 로 만들면 4e-8 이 남는다.
const DIR_STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


func run(t) -> void:
	_box_sits_on_cell_edges(t)
	_pivot_stays_inside_the_box(t)
	_tip_is_never_inside_terrain(t)
	_tip_reaches_full_length_in_the_open(t)
	_tip_is_clamped_in_the_middle_by_a_wall(t)
	_staff_tint_carries_the_loadout(t)


## 🔴 아래 배치 전부의 전제다. `W_PX`·`H_PX` 가 셀의 배수가 아니게 되는 날 여기가 먼저 빨개진다.
func _box_sits_on_cell_edges(t) -> void:
	t.eq(Character.W_PX % Tuning.CELL_PX, 0,
		"상자 폭 %d 가 셀 %d 의 배수다 (배치의 전제)" % [Character.W_PX, Tuning.CELL_PX])
	t.eq(Character.H_PX % Tuning.CELL_PX, 0,
		"상자 높이 %d 가 셀 %d 의 배수다 (배치의 전제)" % [Character.H_PX, Tuning.CELL_PX])
	t.eq(DIR_STEPS.size(), 8, "훑는 방향이 여덟이다")


## 그물 6 — 🔴 피벗이 상자 **안**이어야 한다. 넘으면 「상자 안은 지형이 없다」는 하한의
##  안전 근거가 죽고, 그때 하한까지 줄인 끝이 **벽 안**에 앉는다.
## ⚠ 값이 아니라 **범위**를 잰다 — 손맛값이라 눈이 바꿀 자리다(기획 「미정」).
func _pivot_stays_inside_the_box(t) -> void:
	t.ok(Staff.PIVOT_DY_PX >= 0.0 and Staff.PIVOT_DY_PX < Character.H_PX * 0.5,
		"손 높이 %.1f 가 상자 안이다 (0 ≤ dy < %d)" % [Staff.PIVOT_DY_PX, Character.H_PX / 2])
	var p := Staff.pivot_px(BOX_X, BOX_Y)
	t.ok(p.x >= float(BOX_X) and p.x <= float(BOX_X + Character.W_PX - 1)
			and p.y >= float(BOX_Y) and p.y <= float(BOX_Y + Character.H_PX - 1),
		"피벗 %s 가 상자[%d,%d]~[%d,%d] 안이다" % [
			p, BOX_X, BOX_Y, BOX_X + Character.W_PX - 1, BOX_Y + Character.H_PX - 1])


## 그물 1·2 — 🔴🔴 **사방이 막힌 세상에서 여덟 방향.**
##
## 🔴 **하한이 「표면」이면 여기가 빨개진다.** `_box_free` 가 지키는 범위는
##  `[px, px+W−1] × [py, py+H−1]` 이라 표면(`box + 크기`)은 **이미 다음 셀**이다 —
##  표면으로 짜면 아래를 볼 때 끝이 바닥 셀 안에 앉는다(위험 1).
## 🔴 **대조군**: 같은 배치에서 클램프 없는 값은 전부 고체 셀이다 ⇒ 「배치가 관문이다」.
func _tip_is_never_inside_terrain(t) -> void:
	var g := _boxed_world()
	t.ok(_box_is_free(g), "상자가 덮는 셀이 전부 빈칸이다 (배치의 전제)")
	t.ok(g.is_solid(BOX_CX - 1, BOX_CY), "상자 왼쪽 셀은 고체다 (사방이 막혔다)")
	t.ok(g.is_solid(BOX_CX, BOX_CY + Character.H_PX / Tuning.CELL_PX),
		"상자 아래 셀은 고체다 (바닥이다)")

	for step: Vector2i in DIR_STEPS:
		var dir := Vector2(step).normalized()
		var tip := Staff.tip_px(g, BOX_X, BOX_Y, dir)
		t.ok(not _solid_at(g, tip), "%s 로 조준하면 끝(%s)이 빈 셀이다" % [step, tip])
		# 🔴 대조군 — 클램프가 없었다면 어디였나.
		var raw := Staff.pivot_px(BOX_X, BOX_Y) + dir * Staff.LEN_PX
		t.ok(_solid_at(g, raw),
			"%s: 클램프 없는 값(%s)은 실제로 고체 셀이다 (배치가 관문이다)" % [step, raw])
		_tip_points_along_aim(t, dir, tip, step)


## 그물 3 — 막는 것이 없으면 정확히 `LEN_PX` 다. 🔴 **클램프가 늘 물면** 지팡이가
##  영영 짧은 채로 남는데, 그건 「그냥 그런 길이인가 보다」로 보여서 눈으로 거의 못 잡는다.
func _tip_reaches_full_length_in_the_open(t) -> void:
	var g := CellGrid.new()
	for step: Vector2i in DIR_STEPS:
		var dir := Vector2(step).normalized()
		var tip := Staff.tip_px(g, BOX_X, BOX_Y, dir)
		var len_px := (tip - Staff.pivot_px(BOX_X, BOX_Y)).length()
		t.ok(is_equal_approx(len_px, Staff.LEN_PX),
			"%s: 빈 하늘에서는 길이가 정확히 %.1f 다 (%.3f)" % [step, Staff.LEN_PX, len_px])
		_tip_points_along_aim(t, dir, tip, step)


## 그물 1·2·4 — 🔴 **하한도 상한도 아닌 중간에서 잘리나.** 위 두 검사만 있으면
##  「늘 하한」이나 「늘 상한」으로 짜도 각각 하나씩은 초록이다.
func _tip_is_clamped_in_the_middle_by_a_wall(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(WALL_CX0, 0, WALL_CX1, CellGrid.H - 1, Mat.STONE))
	t.ok(_box_is_free(g), "상자가 덮는 셀이 전부 빈칸이다 (배치의 전제)")

	var pivot := Staff.pivot_px(BOX_X, BOX_Y)
	var dir := Vector2.RIGHT
	var tip := Staff.tip_px(g, BOX_X, BOX_Y, dir)
	var len_px := (tip - pivot).length()
	t.ok(not _solid_at(g, tip), "벽 앞에서 끝(%s)이 빈 셀이다" % tip)
	t.ok(_solid_at(g, pivot + dir * Staff.LEN_PX),
		"클램프 없는 값(%s)은 벽 **안**이다 (배치가 관문이다)" % (pivot + dir * Staff.LEN_PX))
	# 🔴 **중간이다.** 하한(상자 마지막 안쪽 픽셀)보다 길고 `LEN_PX` 보다 짧다 ⇒ 화면에서
	#  「벽에 다가가면 지팡이가 눌려 짧아진다」가 되는 자리다(판정 2 — 보는 것은 눈이다).
	var floor_len := float(BOX_X + Character.W_PX - 1) - pivot.x
	t.ok(len_px > floor_len and len_px < Staff.LEN_PX,
		"길이 %.1f 가 하한(%.1f)과 전장(%.1f) **사이**다" % [len_px, floor_len, Staff.LEN_PX])
	_tip_points_along_aim(t, dir, tip, Vector2i(1, 0))


## 그물 4 — 끝이 늘 **조준 방향 위**에 있고 전장을 안 넘는다.
## ⚠ 이게 없으면 「끝이 빈 셀이다」를 **피벗을 그대로 돌려주는** 구현으로도 통과시킬 수 있다.
func _tip_points_along_aim(t, dir: Vector2, tip: Vector2, step: Vector2i) -> void:
	var v := tip - Staff.pivot_px(BOX_X, BOX_Y)
	t.ok(v.length() > 0.0 and v.normalized().dot(dir) > 0.9999,
		"%s: 끝이 조준 방향 위에 있다 (%s)" % [step, v])
	t.ok(v.length() <= Staff.LEN_PX + 0.001,
		"%s: 끝이 전장을 안 넘는다 (%.3f ≤ %.1f)" % [step, v.length(), Staff.LEN_PX])


## 그물 7 — 🔴🔴 **끝의 고리 색이 장착을 나른다.** 총구 구슬이 사라지며 **남은 축은 색 하나**라,
##  이 함수가 갈라지지 않는 것이 「조합을 바꾸면 화면이 바뀐다」의 전부다.
##  ⚠ **재는 것은 「색이 다르다」까지다.** 그 색이 화면의 링에 실제로 칠해지는지는 눈이다.
func _staff_tint_carries_the_loadout(t) -> void:
	var elem := Tuning.ELEM_FIRE
	var spread := Glyph.pack([Glyph.GLYPH_SPREAD])
	var blast := Glyph.pack([Glyph.GLYPH_BLAST])
	var c_spread := Fx.staff_tint(spread, elem, true)
	var c_blast := Fx.staff_tint(blast, elem, true)
	var c_none := Fx.staff_tint(Glyph.GLYPH_NONE, elem, true)
	t.ok(c_spread != c_blast, "문양이 다르면 색이 다르다 (확산 %s ≠ 폭발 %s)" % [c_spread, c_blast])
	t.ok(c_none != c_spread and c_none != c_blast,
		"문양이 비면 룬 색으로 떨어진다 (%s)" % c_none)

	# 🔴🔴 **키 4(확산→폭발)와 키 5(폭발→확산)** — 층 수가 같으므로 **색만이 순서를 나른다.**
	#  GDD가 「순서가 화면에 안 보이면 플레이어는 규칙을 영영 못 배운다」고 적은 자리다.
	var k4 := Glyph.pack([Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST])
	var k5 := Glyph.pack([Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD])
	t.ok(k4 != k5, "키 4와 키 5가 서로 다른 목록이다 (검사의 전제)")
	t.ok(Fx.staff_tint(k4, elem, true) != Fx.staff_tint(k5, elem, true),
		"순서를 바꾸면 색이 바뀐다 (키 4 %s ≠ 키 5 %s)" % [
			Fx.staff_tint(k4, elem, true), Fx.staff_tint(k5, elem, true)])

	# 🔴 **못 쏘면 회색으로 죽는다.** 조립창의 빈 룬 자리와 **같은 회색**이라 두 화면이 같은 말을 한다.
	#  ⚠ 목록과 무관하다 — 「조합은 그대로고 룬만 빠졌다」가 아니라 「지금은 못 쏜다」가 이 색의 뜻이다.
	for g: int in [Glyph.GLYPH_NONE, spread, blast, k4]:
		t.eq(Fx.staff_tint(g, elem, false), Fx.DEAD_TINT,
			"못 쏘면 목록(%d)과 무관하게 회색으로 죽는다" % g)
	# 🔴 뒤집기 — 「늘 회색」으로 짜도 위 줄들이 통과하는 길을 막는다.
	t.ok(Fx.staff_tint(k4, elem, true) != Fx.DEAD_TINT, "쏠 수 있으면 회색이 아니다")


# ── 세상 만들기 ────────────────────────────────────────────────────

## 🔴 **사방이 막힌 세상 — 상자 셀만 빈칸이다.** 하한이 실제로 물리는 유일한 배치다.
func _boxed_world() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(
		BOX_CX, BOX_CY,
		BOX_CX + Character.W_PX / Tuning.CELL_PX - 1,
		BOX_CY + Character.H_PX / Tuning.CELL_PX - 1, Mat.EMPTY))
	return g


## `character._box_free` 와 **같은 범위**를 본다 — 하한의 안전 근거가 그것이라
## 여기서 범위를 달리 세면 그물이 게임과 다른 것을 재게 된다.
func _box_is_free(g: CellGrid) -> bool:
	for cy in range(BOX_CY, BOX_CY + Character.H_PX / Tuning.CELL_PX):
		for cx in range(BOX_CX, BOX_CX + Character.W_PX / Tuning.CELL_PX):
			if g.is_solid(cx, cy):
				return false
	return true


func _solid_at(g: CellGrid, p: Vector2) -> bool:
	return g.is_solid(
		floori(p.x / float(Tuning.CELL_PX)), floori(p.y / float(Tuning.CELL_PX)))
