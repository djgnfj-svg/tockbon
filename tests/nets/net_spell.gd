extends RefCounted
## 투사체와 문양 파이프라인. 🔴 **이 그물이 도는 것 자체가 `spell_sim.gd` 가 RefCounted 인 덕이다.**
##
## 여기가 잡는 것은 전부 "에러 없이 조용히 틀리는" 종류다:
##  · 얇은 벽 통과 — 한 프레임이라 **눈으로 절대 못 본다.** 사용자에게는 「가끔 안 터진다」로만 보인다
##  · 좌우 비대칭 감쇠 — 「왼쪽으로 쏘면 조금 덜 나간다」로만 보인다
##  · id 재사용 — 옛 자취가 새 탄에 달라붙는다. 에러 없이 화면만 이상해진다
##
## ⚠ **결정론 계약(정수만)은 이 그물이 못 잰다.** 같은 프로세스의 두 인스턴스는 float도
##  똑같은 답을 낸다 — `net_determinism` 의 폴더 텍스트 스캔이 유일한 감지기다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Aim := preload("res://src/actor/aim.gd")
## 🔴 주석·문자열 스트리퍼를 **빌려 온다** — 소스 텍스트를 훑는 그물이 여럿이고 스트리퍼는 하나여야 한다.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const SPELL_SIM_SCRIPT := "res://src/sim/spell_sim.gd"

## 발사 속도(고정소수점). 조준 정규화가 어느 방향에서든 이 크기를 내놔야 한다.
const SPEED_FP := Tuning.SIM_SIZES[0]["speed"] << SpellSim.FP_SHIFT

## 벽 격자(`_wall_grid`)의 돌 기둥 열. 🔴 **한 곳에 둔다** — 「몇 발에 뚫리나」를 재려면
##  벽이 어디서 어디까지인지를 알아야 하고, 그 숫자가 두 곳에 있으면 벽을 옮길 때 조용히 갈라진다.
const WALL_X0 := 40
const WALL_X1 := 43

## 돌·나무 속에 판 방의 경계(셀). 🔴 **한 곳에 둔다** — 흔적 깊이를 재려면 벽이 어디서
##  시작하는지를 알아야 하고, 그 숫자가 두 곳에 있으면 방을 옮길 때 조용히 갈라진다.
const CAVE_X0 := 20
const CAVE_X1 := 60
const CAVE_Y0 := 55
const CAVE_Y1 := 85

## 🔴 위로 쏘는 검사들의 발사 원점(셀). **상자 바닥 가까이에서 위로 쏜다** —
##  올라간 만큼 다시 떨어질 자리가 있어야 vx가 0이 되는 것을 **날면서** 볼 수 있다.
## ⚠ 32px 전환에서 ×2 했다(128,130 → 256,260). 아래 `_box_grid` 는 격자에서 파생돼 저절로 2배다.
const UP_OX := 256
const UP_OY := 260


func run(t) -> void:
	_pack_unpack(t)
	_list_is_finite(t)
	_aim_normalizes(t)
	_drag_and_gravity(t)
	_drag_is_symmetric(t)
	_thin_wall(t)
	_up_and_back(t)
	_command_boundary(t)
	_aim_boundary(t)
	_id_across_reset(t)
	_every_glyph_runs(t)
	_blast_command(t)
	_changed_counter(t)
	_blast_glyph(t)
	_blast_chain(t)
	_blast_budget(t)
	_blast_notice(t)
	_spread_makes_eight(t)
	_spread_hands_over_list(t)
	_spread_advances_on_birth_tick(t)
	_order_changes_the_spell(t)
	_spread_capped_per_circle(t)
	_kind_decides_continuation(t)
	_every_impact_carves(t)
	_repeated_shots_pierce_the_wall(t)
	_carve_follows_gen(t)
	_rune_leaves_a_trace(t)
	_every_rune_traces(t)
	_rune_trace_has_the_none_branch(t)
	_empty_list_bolts_leave_marks(t)
	_glyph_bolt_also_traces(t)
	_rune_trace_follows_gen(t)
	_spread_without_room(t)
	_spread_partial(t)
	_crater_follows_gen(t)


# ══════════════════════════════════════════════════════════════════
#  남은 문양 목록 — 정수 하나
# ══════════════════════════════════════════════════════════════════

## 팩/언팩 왕복. 🔴 **순서가 살아남아야 한다** — 문양은 안쪽 층부터 바깥으로 해석되고,
##  순서가 뒤집히면 확산→폭발이 폭발→확산이 된다. 그건 **다른 마법**이지 버그로 안 보인다.
func _pack_unpack(t) -> void:
	var cases: Array[Array] = [
		[],
		[1],
		[1, 2],
		[2, 1],                    # 🔴 위와 같은 두 문양, 다른 순서 — 결과가 달라야 한다
		[3, 1, 4, 1, 5, 9, 2],     # 상한인 7층
	]
	for list: Array in cases:
		var typed: Array[int] = []
		typed.assign(list)
		t.eq(_unpack(Glyph.pack(typed)), typed, "목록 %s가 팩/언팩을 왕복한다" % [typed])

	# 순서가 실제로 다른 정수가 되나. 같은 정수가 나오면 위 왕복 검사가 통째로 무의미하다.
	var ab: Array[int] = [1, 2]
	var ba: Array[int] = [2, 1]
	t.ok(Glyph.pack(ab) != Glyph.pack(ba), "순서가 다르면 다른 정수다")

	# 구조 검증. ⚠ 「그런 문양이 실재하나」는 여기가 아니라 `spell_sim.fire()`가 본다.
	var too_many: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1]
	t.expect_error("Glyph: 층이 8개다")
	t.eq(Glyph.pack(too_many), Glyph.GLYPH_NONE, "8층은 짖고 빈 목록이 된다")

	var has_zero: Array[int] = [1, 0]
	t.expect_error("Glyph: 문양 id 0")
	t.eq(Glyph.pack(has_zero), Glyph.GLYPH_NONE, "예약값 0은 문양 id가 될 수 없다")

	var too_big: Array[int] = [Glyph.MASK + 1]
	t.expect_error("Glyph: 문양 id 16")
	t.eq(Glyph.pack(too_big), Glyph.GLYPH_NONE, "니블을 넘는 id는 짖고 버려진다")

	# count_of 는 `max_per_circle` 제약의 소비자다 — 이게 틀리면 확산이 두 번 든 목록이 통과한다.
	var twice: Array[int] = [1, 2, 1]
	t.eq(Glyph.count_of(Glyph.pack(twice), 1), 2, "count_of가 같은 문양을 두 번 센다")
	t.eq(Glyph.count_of(Glyph.pack(twice), 2), 1, "count_of가 다른 문양을 한 번 센다")


## 🔴🔴 **폭발 → 폭발 → … 이 무한이 될 수 없다.** `rest`가 매번 4비트씩 줄어드니
##  `_impact`의 while 루프에 **상한 가드가 원리적으로 필요 없다** — 그 논증을 여기서 잰다.
##  ⚠ 이게 깨지면 프레임이 통째로 멈춘다(에러 없이 게임이 얼어붙는다).
func _list_is_finite(t) -> void:
	var full: Array[int] = []
	for _i in Tuning.GLYPH_MAX_LAYERS:
		full.append(Glyph.MASK)
	var g := Glyph.pack(full)

	# 🔴 부호 비트를 건드리면 `>> 4`가 산술 시프트라 부호 확장으로 **에러 없이 영원히 돈다.**
	t.ok(g > 0, "가득 찬 목록이 양수다 (부호 비트에 여유가 있다)")

	var steps := 0
	while g != Glyph.GLYPH_NONE and steps <= Tuning.GLYPH_MAX_LAYERS:
		g = Glyph.rest(g)
		steps += 1
	t.eq(g, Glyph.GLYPH_NONE, "가득 찬 목록도 반드시 빈다")
	t.eq(steps, Tuning.GLYPH_MAX_LAYERS, "정확히 %d번에 빈다" % Tuning.GLYPH_MAX_LAYERS)


# ══════════════════════════════════════════════════════════════════
#  발사 — 정수 정규화
# ══════════════════════════════════════════════════════════════════

## 🔴 어느 방향으로 쏘든 속도 크기가 같아야 한다. 안 그러면 「대각으로 쏘면 더 멀리 간다」가 된다.
##
## ⚠ **짧은 조준 벡터로 재는 게 요점이다.** `AIM_SHIFT`를 0으로 죽여도 조준 (100,100)에서는
##  오차가 0.2%라 안 보인다 — (1,1)에서는 **41% 빨라진다**(`isqrt(2)=1`이라 √2배).
##  마우스가 캐릭터 바로 옆에 있을 때가 정확히 그 경우다.
func _aim_normalizes(t) -> void:
	var aims: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
		Vector2i(3, 1), Vector2i(100, 0), Vector2i(100, 100),
	]
	for a: Vector2i in aims:
		var sim := SpellSim.new()
		t.ok(_fire(sim, 128, 70, a.x, a.y), "조준 %s로 발사된다" % a)
		if sim.active_count() == 0:
			continue
		var vx: int = sim.get_vx()[0]
		var vy: int = sim.get_vy()[0]
		# 제곱으로 비교한다 — 그물이 sqrt를 쓸 이유가 없고, 2% 여유는 절삭 몫이다.
		var got2 := vx * vx + vy * vy
		var want2 := SPEED_FP * SPEED_FP
		t.ok(absi(got2 - want2) * 100 <= want2 * 4,
			"조준 %s의 속도 크기가 %d에 붙는다 (v²=%d · 기대 %d)" % [a, SPEED_FP, got2, want2])

	# 좌우 대칭. 조준을 좌우로 뒤집으면 vx의 절댓값이 **정확히** 같아야 한다.
	var r := SpellSim.new()
	var l := SpellSim.new()
	_fire(r, 128, 70, 3, -1)
	_fire(l, 128, 70, -3, -1)
	t.eq(absi(r.get_vx()[0]), absi(l.get_vx()[0]), "좌우 조준의 속도가 대칭이다")
	t.eq(r.get_vy()[0], l.get_vy()[0], "좌우 조준의 세로 속도가 같다")


# ══════════════════════════════════════════════════════════════════
#  궤적 — 항력 + 중력 (기획 판정 3의 그물 대리)
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **거의 수직으로 쏜다.** 수평으로 쏘면 벽에 먼저 닿아 틱을 못 채우고,
##  그러면 아래 「vx가 결국 정확히 0이 된다」를 **날면서** 확인할 수가 없다.
##  ⚠ 조준 (1,-100)은 vx가 속도의 1/100쯤으로 시작해 항력에 절삭되어 0이 되는데,
##   비행은 그보다 오래 이어진다.
##
## 🔴🔴 **32px 전환에서 원점을 ×2 했다**(128,130 → 256,260). `speed` 와 `GRAVITY_FP` 가 **함께**
##  2배가 돼서 **비행 틱 수는 그대로이고 거리만 2배**가 됐다 — 원점을 안 옮기면 탄이 상자 천장을
##  뚫고 올라가 **오르는 중에 죽고**, 그러면 「올라갔다가 처진다」를 잴 수가 없다(실측으로 그렇게 빨개졌다).
##  ⚠ `_box_grid` 는 격자 크기에서 파생되므로 저절로 2배가 됐다. **원점만 손으로 옮긴다.**
func _drag_and_gravity(t) -> void:
	var g := _box_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, UP_OX, UP_OY, 1, -100), "거의 수직으로 위로 쏜다")

	var vxs: Array[int] = [sim.get_vx()[0]]
	var vys: Array[int] = [sim.get_vy()[0]]
	while sim.active_count() > 0 and vxs.size() <= Tuning.LIFETIME_TICKS:
		sim.step(g)
		if sim.active_count() == 0:
			break
		vxs.append(sim.get_vx()[0])
		vys.append(sim.get_vy()[0])

	var shrinking := true
	for k in range(1, vxs.size()):
		if absi(vxs[k]) > absi(vxs[k - 1]):
			shrinking = false
	t.ok(shrinking, "항력이 vx를 매 틱 줄인다 (%d → %d · %d틱)" % [vxs[0], vxs[-1], vxs.size()])

	# 🔴🔴 **이건 버그가 아니라 계약이다**(기획 「궤적」). 정수 절삭으로 가로 속도가 결국
	#  정확히 0이 되고, 그때부터 탄은 수직으로만 떨어진다 — 「힘이 다해 꽂힌다」로 읽힌다.
	#  ⚠ 그물이 이걸 안 재면 다음 사람이 버그로 보고 고친다.
	t.eq(vxs[-1], 0, "정수 절삭으로 가로 속도가 결국 정확히 0이 된다 (계약이다)")

	var falling := true
	for k in range(1, vys.size()):
		if vys[k] < vys[k - 1]:
			falling = false
	t.ok(falling, "중력이 vy를 단조로 키운다")
	t.ok(vys[0] < 0 and vys[-1] > 0,
		"위로 나갔다가 아래로 처진다 (vy %d → %d)" % [vys[0], vys[-1]])


## 🔴 **항력이 `/`지 `>>`가 아닌 것을 잰다.** `>>`는 음수에서 내림이라 왼쪽으로 나는 탄만
##  감쇠가 0.5/256 더 세진다 — 눈으로는 「왼쪽으로 쏘면 조금 덜 나간다」로만 보이고,
##  그 정도 차이는 아무도 버그로 신고하지 않는다.
func _drag_is_symmetric(t) -> void:
	var right := _vx_series(1)
	var left := _vx_series(-1)
	t.eq(right.size(), left.size(), "좌우 비행이 같은 틱 수를 산다")
	var same := right.size() == left.size()
	for k in mini(right.size(), left.size()):
		if right[k] != -left[k]:
			same = false
	t.ok(same, "좌우 vx 수열이 부호만 다르다 (%d틱)" % right.size())


## 거의 수직으로 쏜 탄의 vx 수열. `sign`이 +1이면 오른쪽으로 살짝 기운다.
func _vx_series(sign: int) -> Array[int]:
	var g := _box_grid()
	var sim := SpellSim.new()
	_fire(sim, UP_OX, UP_OY, sign, -100)
	var out: Array[int] = [sim.get_vx()[0]]
	while sim.active_count() > 0 and out.size() <= Tuning.LIFETIME_TICKS:
		sim.step(g)
		if sim.active_count() == 0:
			break
		out.append(sim.get_vx()[0])
	return out


# ══════════════════════════════════════════════════════════════════
#  이동 판정 — 지나간 칸을 전부 밟나
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **벽이 1셀이다.** 탄은 첫 틱에 20셀을 뛰므로 벽이 두 틱 사이 **중간**에 들어온다 —
##  「도착 칸만 검사」로 짜면 그냥 통과하고, **한 프레임이라 눈으로 절대 못 본다.**
##  사용자에게는 「가끔 안 터진다」로만 보인다.
func _thin_wall(t) -> void:
	var walled := CellGrid.new()
	walled.apply(CellGrid.cmd_fill(25, 0, 25, CellGrid.H - 1, Mat.STONE))
	var hit := SpellSim.new()
	t.ok(_fire(hit, 10, 70, 100, 0), "1셀 벽 앞에서 수평으로 쏜다")
	for _i in 3:
		hit.step(walled)
	t.eq(hit.active_count(), 0, "1셀 벽을 통과하지 않는다 (Bresenham)")

	# 🔴 **대조군이 없으면 위 초록이 「벽에 맞았다」인지 「그냥 죽었다」인지 못 가른다.**
	#  같은 자리·같은 틱 수로 벽만 뺀다.
	var open := CellGrid.new()
	var miss := SpellSim.new()
	t.ok(_fire(miss, 10, 70, 100, 0), "같은 자리에서 벽 없이 쏜다")
	for _i in 3:
		miss.step(open)
	t.eq(miss.active_count(), 1, "벽이 없으면 같은 3틱을 살아서 난다")


## 기획 「극단값」: 위로 수직으로 쏘면 **되돌아와 자기 머리 위에 떨어진다.**
##
## 🔴 그리고 그게 **수명이 진짜 안전망인 이유**다 — 중력이 있으면 탄은 반드시 땅에 닿거나
##  격자 밖으로 나가므로 영원히 도는 투사체가 원리적으로 없다.
##  ⚠ 반대로 수명이 비행보다 짧으면 탄이 **공중에서 그냥 사라지고**, 그건 고장으로 읽힌다.
func _up_and_back(t) -> void:
	var g := _box_grid()
	var sim := SpellSim.new()
	var ox := UP_OX
	var oy := UP_OY
	t.ok(_fire(sim, ox, oy, 0, -1), "수직으로 위로 쏜다")

	var turned := false
	var ticks := 0
	var last_x := ox
	var last_y := oy
	var top_y := oy
	while sim.active_count() > 0 and ticks <= Tuning.LIFETIME_TICKS:
		last_x = sim.get_px()[0] >> SpellSim.FP_SHIFT
		last_y = sim.get_py()[0] >> SpellSim.FP_SHIFT
		top_y = mini(top_y, last_y)
		sim.step(g)
		ticks += 1
		if sim.active_count() > 0 and sim.get_vy()[0] > 0:
			turned = true

	t.eq(sim.active_count(), 0, "위로 쏜 탄이 반드시 착탄한다")
	t.ok(turned, "올라가다 방향이 뒤집힌다")
	t.ok(top_y < oy - 20, "실제로 높이 올라간다 (최고점 셀 y=%d · 발사점 %d)" % [top_y, oy])
	t.eq(last_x, ox, "자기 머리 위에 떨어진다 (x가 그대로다)")
	t.ok(last_y > oy, "쏜 자리보다 아래에서 착탄한다 (y=%d)" % last_y)
	t.ok(ticks < Tuning.LIFETIME_TICKS,
		"수명 %d틱에 안 걸린다 — 진짜 안전망이다 (%d틱 비행)" % [Tuning.LIFETIME_TICKS, ticks])


# ══════════════════════════════════════════════════════════════════
#  커맨드 경계
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **발사는 설계상 선을 넘는 유일한 커맨드다 — 검증을 여기서 안 하면 할 데가 없다.**
##  ⚠ 로컬 마우스로는 도달 불가한 값들이지만 **네트워크가 그 문을 연다.**
func _command_boundary(t) -> void:
	var sim := SpellSim.new()

	# 🔴 조준 0벡터는 **정상 입력**이다(캐릭터 한가운데를 그대로 클릭). 짖으면 안 된다 —
	#  래퍼가 stderr를 실패로 치니 여기서 짖으면 평소 조작이 그물을 빨갛게 만든다.
	t.ok(not _fire(sim, 100, 70, 0, 0), "조준 0벡터는 조용히 버린다")
	t.eq(sim.active_count(), 0, "조준 0벡터는 탄을 안 만든다")

	# 🔴 `_px`가 PackedInt32Array라 범위 밖 원점은 **에러 없이 32비트로 잘린다** —
	#  투사체가 격자 반대편에서 시작하고, 그 잘림은 결정론적이라 desync조차 안 난다.
	t.expect_error("격자 밖 원점")
	t.ok(not _fire(sim, CellGrid.W + 10, 70, 1, 0), "격자 밖 원점은 짖고 버린다")

	t.expect_error("모르는 룬")
	t.ok(not sim.fire(SpellSim.cmd_fire(100, 70, 1, 0, 99, Glyph.GLYPH_NONE)),
		"모르는 룬은 짖고 버린다")

	t.expect_error("모르는 주문 커맨드")
	t.ok(not sim.fire({"spell_kind": 77}), "모르는 주문 커맨드는 짖고 버린다")

	# `len2 << 16`이 오버플로하면 정규화가 조용히 틀어진다.
	t.expect_error("i16 범위 밖")
	t.ok(not _fire(sim, 100, 70, SpellSim.AIM_MAX + 1, 0), "i16 밖 조준은 짖고 버린다")

	# 🔴 표에 없는 문양. 조립창(B)이 생기면 같은 표를 읽어 놓기 전에 막지만,
	#  커맨드 경계는 그때도 **네트워크에서 오는 목록**을 봐야 한다.
	t.expect_error("모르는 문양 id")
	t.ok(not _fire(sim, 100, 70, 1, 0, Glyph.MASK), "표에 없는 문양은 발사 시점에 짖고 버린다")
	t.eq(sim.active_count(), 0, "버린 발사가 탄을 안 남긴다")

	# 🔴 상한은 **짖고 버린다** — 밀기 기계를 만들지 않는다(계획 9). 확산이 한 마법진에
	#  하나뿐이라 싱글에서 1 → 8발이 상한이고 32에 원리적으로 도달할 수 없다.
	#  도달하면 그건 버그이므로 짖어야 한다.
	var full := SpellSim.new()
	for _i in Tuning.MAX_PROJECTILES:
		_fire(full, 100, 70, 1, 0)
	t.eq(full.active_count(), Tuning.MAX_PROJECTILES, "상한까지 채워진다")
	t.expect_error("동시 투사체 상한")
	t.ok(not _fire(full, 100, 70, 1, 0), "상한을 넘으면 짖고 버린다")
	t.eq(full.active_count(), Tuning.MAX_PROJECTILES, "상한을 넘긴 발사가 배열을 안 늘린다")


## 🔴🔴 **경계 함수는 못 쓰는 커맨드를 내놓으면 안 된다.**
##
## ⚠ 도달 불가한 상태가 아니다 — 기획 「극단값」이 「발밑을 쏘면 지형이 사라지고 캐릭터가
##  떨어진다 · 막지 않는다」고 정했으므로 **캐릭터는 실제로 격자 아래로 나간다.**
##  클램프가 없으면 그때 좌클릭이 `push_error`로 죽고 화면에서는 「아무 일도 안 일어난다」로만 보인다.
func _aim_boundary(t) -> void:
	var sim := SpellSim.new()
	var mouse := Vector2(500.0, 300.0)

	var below := Vector2(400.0, float((CellGrid.H + 40) * Tuning.CELL_PX))
	var c1 := Aim.fire_cmd(below, mouse, Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)
	t.eq(int(c1["oy"]), CellGrid.H - 1, "격자 아래로 나간 원점이 마지막 줄로 클램프된다")
	t.ok(sim.fire(c1), "격자 밖에서 쏴도 발사가 산다 (짖지 않는다)")

	var left := Vector2(-500.0, 200.0)
	var c2 := Aim.fire_cmd(left, mouse, Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)
	t.eq(int(c2["ox"]), 0, "왼쪽 밖 원점이 0열로 클램프된다")
	t.ok(sim.fire(c2), "왼쪽 밖에서도 발사가 산다")

	# 🔴 조준은 **클램프한 원점 기준**이어야 한다. 원점만 옮기고 마우스 셀을 그대로 빼면
	#  격자 밖에서 쏠 때 방향이 조용히 틀어진다.
	t.eq(int(c2["adx"]), _cell(mouse.x) - 0, "조준이 클램프한 원점 기준으로 계산된다")

	# ⚠ 셀 변환이 `floori`여야 한다 — `int()`는 0 쪽으로 잘라서 **화면 왼쪽·위 밖에서만** 한 칸
	#  튀고, 그건 눈으로 거의 못 본다.
	var c3 := Aim.fire_cmd(Vector2(4.0, 4.0), Vector2(-1.0, -1.0),
		Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)
	t.eq(int(c3["adx"]), -2, "음수 px가 내림으로 셀이 된다 (floori)")


static func _cell(px: float) -> int:
	return floori(px / float(Tuning.CELL_PX))


## 🔴 **리셋에서 id를 되돌리면 옛 자취가 새 탄에 달라붙는다.** 렌더가 자취를 id로 짝짓기
##  때문이고, 에러 하나 없이 화면만 이상해진다.
func _id_across_reset(t) -> void:
	var sim := SpellSim.new()
	_fire(sim, 100, 70, 1, 0)
	var before: int = sim.get_id()[0]
	sim.reset()
	t.eq(sim.active_count(), 0, "리셋이 탄을 전부 지운다")
	_fire(sim, 100, 70, 1, 0)
	t.ok(sim.get_id()[0] > before,
		"id가 리셋을 넘어 단조 증가한다 (%d → %d)" % [before, sim.get_id()[0]])


# ══════════════════════════════════════════════════════════════════
#  문양 파이프라인
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **표에만 있고 코드에 없는 문양을 래퍼의 stderr 검사에 공짜로 건다** —
##  `_run_glyph`가 모르는 id에 짖으므로, `ALL`을 한 번씩 실행해 보는 것만으로 걸린다.
##
## ⚠ **`ALL`이 비면 이 검사는 아무것도 안 돌고 초록이 된다.** 그게 이 리포가 죽는 방식이라
##  개수를 라벨에 박는다 — 단계 3에서는 0개가 정상이고(탄은 빈 목록을 들고 난다),
##  단계 4·6에서 저절로 켜진다.
func _every_glyph_runs(t) -> void:
	t.ok(Glyph.ALL.size() == Glyph.DEFS.size(),
		"실행해 볼 문양이 %d개다 (ALL과 DEFS가 같다)" % Glyph.ALL.size())
	for id: int in Glyph.ALL:
		var g := _wall_grid()
		var sim := SpellSim.new()
		var one: Array[int] = [id]
		var nm: StringName = Glyph.DEFS[id]["name"]
		t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(one)), "문양 %s를 실은 탄이 나간다" % nm)
		if sim.active_count() == 0:
			continue
		# 🔴 **원본 탄의 id로 짝짓는다** — 확산이면 착탄 뒤에 새 탄 8개가 남으므로
		#  `active_count() == 0`으로 재면 확산이 들어오는 순간 빨개진다.
		var origin: int = sim.get_id()[0]
		for _i in 16:
			sim.step(g)
		t.ok(not _has_id(sim, origin), "문양 %s가 착탄에서 실행되고 원본 탄이 사라진다" % nm)


# ══════════════════════════════════════════════════════════════════
#  폭발 — 마법이 세상에 남기는 것
# ══════════════════════════════════════════════════════════════════

## 🔴 **정수 원반이다.** 사각형으로 지우면 아래 「모서리」와 「칸 수」가 둘 다 걸린다.
##  ⚠ 원이 아니면 결정론은 멀쩡한데 **구멍 모양이 네모라 「폭발」로 안 읽힌다** — 화면 문제라
##   에러가 안 난다.
func _blast_command(t) -> void:
	var rd := Tuning.blast_rd(0)
	var cx := 100
	var cy := 70
	var g := _solid_grid()
	var before := g.count_material(Mat.STONE)
	# 점화는 여기서 재지 않는다(`net_fire`의 몫이다) — 돌뿐인 격자라 붙을 것도 없다.
	g.apply(CellGrid.cmd_blast(cx, cy, rd, 0))

	t.eq(g.mat_at(cx, cy), Mat.EMPTY, "폭발 한가운데가 비었다")
	t.eq(g.mat_at(cx + rd, cy), Mat.EMPTY, "반경 끝(정확히 rd)이 비었다")
	t.eq(g.mat_at(cx + rd + 1, cy), Mat.STONE, "반경 밖 한 칸은 남았다")
	t.eq(g.mat_at(cx + rd, cy + rd), Mat.STONE, "대각 모서리는 안 지워진다 (네모가 아니라 원이다)")

	# 사각형이면 (2rd+1)² = 625칸, 원이면 πr² ≈ 452칸이다. 10% 여유는 정수 격자 몫이다.
	var gone := before - g.count_material(Mat.STONE)
	var area := int(PI * rd * rd)
	t.ok(absi(gone - area) * 10 <= area,
		"지운 칸 수가 원 넓이에 붙는다 (%d칸 · πr²≈%d)" % [gone, area])

	# 🔴 격자 밖은 **클램프**다. 범위 검사가 없으면 `_mat[i]`가 셀마다 엔진 에러를 내는데,
	#  그건 `SCRIPT ERROR` grep에 안 걸리는 침묵사다.
	var edge := _solid_grid()
	edge.apply(CellGrid.cmd_blast(0, 0, rd, 0))
	t.eq(edge.mat_at(0, 0), Mat.EMPTY, "격자 모서리에서 터져도 지워진다")
	t.eq(edge.mat_at(rd + 1, 0), Mat.STONE, "모서리 폭발이 반경만큼만 지운다")

	# 반경 0은 조용히 아무 일도 안 한다 — 확산 하한이 붙으면 실제로 0이 나올 수 있다.
	var zero := _solid_grid()
	zero.consume_changed()
	zero.apply(CellGrid.cmd_blast(50, 50, 0, 0))
	t.eq(zero.consume_changed(), 0, "반경 0 폭발은 한 칸도 안 건드린다")


## 🔴🔴 **「화면을 다시 올려야 하나」의 단일 소스다.** 폭발은 커맨드 큐를 안 지나므로
##  껍데기가 걸쇠를 따로 들면 그 걸쇠를 조용히 빠뜨려 **구멍이 화면에 안 뜬다.**
func _changed_counter(t) -> void:
	var g := CellGrid.new()
	t.eq(g.consume_changed(), 0, "아무것도 안 바꿨으면 0이다")
	g.apply(CellGrid.cmd_fill(0, 0, 3, 3, Mat.STONE))
	t.eq(g.consume_changed(), 16, "채운 칸 수를 센다")
	t.eq(g.consume_changed(), 0, "읽으면 0으로 돌아간다")
	g.apply(CellGrid.cmd_blast(100, 70, Tuning.blast_rd(0), 0))
	t.ok(g.consume_changed() > 0, "폭발도 센다 (커맨드 큐를 안 지나는 변경이다)")


## 기획 판정 1의 그물 대리: **문양을 넣으면 지형 자국이 생긴다.**
func _blast_glyph(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var before := g.count_material(Mat.STONE)
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(one)), "폭발 문양을 실은 탄이 나간다")
	t.eq(_run_ticks(sim, g, 12), 1, "착탄에서 폭발이 한 번 일어난다")
	var after := g.count_material(Mat.STONE)
	t.ok(after < before, "벽에 구멍이 남는다 (돌 %d → %d)" % [before, after])

	# 🔴 대조군 — **문양 없이 쏘면 훨씬 조금 판다.** 이게 없으면 위 초록이
	#  「폭발이 팠다」인지 「착탄이 원래 그만큼 판다」인지 못 가른다.
	#
	# ⚠ **전에는 「문양이 없으면 지형이 그대로다」였다.** 2026-08-05부터 모든 착탄이 파므로
	#  (`spell_sim._impact` 의 ①) 그 문장이 죽었다 ⇒ 「파나 마나」가 아니라 **「얼마나」**로 가른다.
	# 🔴🔴 **그리고 그 대비가 곧 판정 4다** — 뒤집힌 결정(`_rune_trace` 의 「지형은 안 부순다」)이
	#  원래 막으려던 것이 「확산이 폭발을 겸하는 것처럼 보인다」이고, 막는 것은 **크기 차이**다.
	#  ⚠ 두 값이 가까워지면 화면에서 폭발과 착탄이 다시 뭉개진다 — **여기가 그 경보다.**
	var g2 := _wall_grid()
	var s2 := SpellSim.new()
	var kept := g2.count_material(Mat.STONE)
	t.ok(_fire(s2, 10, 70, 100, 0), "문양 없이 쏜다 (진 + 룬만)")
	t.eq(_run_ticks(s2, g2, 12), 0, "문양이 없으면 폭발이 없다")
	var carved := kept - g2.count_material(Mat.STONE)
	var blown := before - after
	t.ok(carved > 0, "문양이 없어도 착탄이 판다 (%d칸)" % carved)
	# ⚠ 문턱 4는 **손으로 고른 값이다** — 반경 제곱비(8²/2² = 16배)에서 정수 격자와 「반쪽 원반」
	#  몫을 크게 깎은 하한이다. 🔴 반경을 키워 두 개가 화면에서 뭉개지기 시작하면 여기가 먼저 짖는다.
	t.ok(blown > carved * 4,
		"폭발이 착탄보다 4배 넘게 판다 (%d칸 vs %d칸)" % [blown, carved])


## 🔴🔴 **TERMINAL은 탄을 안 만드니 같은 자리에서 다음 문양이 이어 실행된다**(GDD 문양 실행 규칙).
##  ⚠ 구멍은 같은 자리라 화면에서 **하나로 보인다** — 횟수로만 구별된다. 그래서 그물이 잰다.
func _blast_chain(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var two: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(two)), "폭발 두 층을 실은 탄이 나간다")

	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	for _i in 12:
		sim.step(g)
		if sim.blast_count() > 0 and bx.is_empty():
			# ⚠ 사본을 뜬다 — 다음 `step()`이 통지를 지운다.
			bx = sim.get_blast_x().duplicate()
			by = sim.get_blast_y().duplicate()
	t.eq(bx.size(), 2, "폭발 → 폭발이 **같은 틱에** 두 번 터진다")
	if bx.size() == 2:
		t.ok(bx[0] == bx[1] and by[0] == by[1],
			"두 폭발이 같은 자리다 ((%d,%d) · (%d,%d))" % [bx[0], by[0], bx[1], by[1]])
	t.eq(sim.pending_count(), 0, "예산(%d) 안이라 밀리지 않는다" % Tuning.MAX_BLASTS_PER_TICK)


## 🔴🔴 **넘친 폭발은 버려지지 않고 다음 틱으로 밀린다.** 버리면 「몰아 쏘면 몇 발이 안 터진다」가
##  되고 그건 **고장**으로 읽힌다 — 투사체 상한(짖고 버린다)과 정반대인 게 요점이다.
## ⚠ 확산이 들어오면 8발이 같은 틱에 착탄하므로 이 길은 **실제로 걸린다.**
func _blast_budget(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var n := Tuning.MAX_BLASTS_PER_TICK * 2
	t.eq(_volley(sim, n), n, "%d발이 같은 틱에 착탄하도록 같이 난다" % n)

	var per_tick: Array[int] = []
	var total := 0
	for _i in 12:
		sim.step(g)
		per_tick.append(sim.blast_count())
		total += sim.blast_count()

	var over := false
	for v: int in per_tick:
		if v > Tuning.MAX_BLASTS_PER_TICK:
			over = true
	t.ok(not over, "한 틱에 %d발을 안 넘는다 %s" % [Tuning.MAX_BLASTS_PER_TICK, per_tick])
	t.eq(total, n, "밀린 폭발이 하나도 안 버려진다 (%d발 전부 터졌다)" % n)
	t.eq(sim.pending_count(), 0, "다 갚고 나면 밀린 것이 0이다")


## 🔴 통지는 **그 틱 안에서만** 유효하다. 껍데기가 지우게 두면 한 번 깜빡하는 순간
##  같은 섬광이 **영원히 재생되고**, 에러는 안 난다.
func _blast_notice(t) -> void:
	var g := _wall_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(one)
	_fire(sim, 10, 70, 100, 0, packed)

	var seen := false
	for _i in 12:
		sim.step(g)
		if sim.blast_count() > 0:
			seen = true
			t.eq(int(sim.get_blast_gen()[0]), 0, "통지에 세대가 실린다")
			t.eq(int(sim.get_blast_element()[0]), Tuning.ELEM_FIRE, "통지에 룬이 실린다")
			break
	t.ok(seen, "폭발이 통지된다")
	sim.step(g)
	t.eq(sim.blast_count(), 0, "다음 틱에 통지가 지워진다")

	# 🔴 리셋이 밀린 파이프라인을 안 지우면, R로 새로 지은 지형에 **앞 실험의 폭발**이 구멍을 낸다 —
	#  두 조합을 비교하는 판정 1·2가 거기서 죽는다.
	var g2 := _wall_grid()
	var s2 := SpellSim.new()
	_volley(s2, Tuning.MAX_BLASTS_PER_TICK * 2)
	for _i in 6:
		s2.step(g2)
		if s2.pending_count() > 0:
			break
	t.ok(s2.pending_count() > 0, "예산을 넘겨 밀린 것이 있다 (%d개)" % s2.pending_count())
	s2.reset()
	t.eq(s2.pending_count(), 0, "리셋이 밀린 파이프라인을 지운다")
	var kept := g2.count_material(Mat.STONE)
	s2.step(g2)
	t.eq(g2.count_material(Mat.STONE), kept, "리셋 뒤에는 밀린 폭발이 안 터진다")


# ══════════════════════════════════════════════════════════════════
#  확산 — 순서가 결과의 종류를 바꾼다
# ══════════════════════════════════════════════════════════════════

## 🔴 8방향은 `(±1,0) (0,±1) (±1,±1)` — `sin`·`cos` 없이 정수로 그대로 나온다.
##
## 🔴🔴 **「여덟 방향이 전부 다르다」는 표에서 재고, 「여덟 발이 난다」는 폭발 횟수로 잰다.**
##  살아남은 수로 세면 안 된다 — 착탄점은 **반드시 무언가에 붙어 있고**(그걸 맞고 멈췄으니까),
##  그쪽으로 난 탄들은 **자기가 태어난 틱에** 그 벽에 부딪혀 죽는다. 평면에 맞으면 셋이 그렇다.
##  ⇒ 생존 수는 지형이 정하고, **태어난 수는 `_order_changes_the_spell`의 폭발 8회가 증명한다.**
func _spread_makes_eight(t) -> void:
	# ── 표 ──
	t.eq(SpellSim.SPREAD_DX.size(), Tuning.SPREAD_COUNT, "방향 표 길이가 SPREAD_COUNT")
	t.eq(SpellSim.SPREAD_DY.size(), SpellSim.SPREAD_DX.size(), "두 방향 표 길이가 같다")
	var seen: Dictionary = {}
	for k in Tuning.SPREAD_COUNT:
		var dx: int = SpellSim.SPREAD_DX[k]
		var dy: int = SpellSim.SPREAD_DY[k]
		t.ok(absi(dx) <= 1 and absi(dy) <= 1 and (dx != 0 or dy != 0),
			"방향 %d이 (±1,0)(0,±1)(±1,±1) 중 하나다 (%d,%d)" % [k, dx, dy])
		seen["%d,%d" % [dx, dy]] = true
	t.eq(seen.size(), Tuning.SPREAD_COUNT, "여덟 방향이 전부 다르다")

	# ── 실제 비행 ──
	var g := _cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack(one)), "확산만 실은 탄이 나간다")
	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break

	var alive := sim.active_count()
	# 검사가 헛돌지 않을 만큼은 살아 있어야 한다(평면에 맞으면 셋이 벽으로 나가 죽는다).
	t.ok(alive >= Tuning.SPREAD_COUNT - 3, "확산으로 난 탄이 살아 있다 (%d발)" % alive)

	var vx := sim.get_vx()
	var vy := sim.get_vy()
	var gens := sim.get_gen()
	var all_gen1 := true
	for i in alive:
		if int(gens[i]) != 1:
			all_gen1 = false
	t.ok(all_gen1, "확산으로 난 탄이 전부 세대 1이다")

	# 🔴 **자리로 잰다. 속도 부호로 재면 안 된다** — 한 틱만 지나도 중력이 vy를 전부 +로 밀어
	#  (-1,0)과 (-1,-1)이 같은 부호쌍이 된다. 같은 자리에서 난 탄들이 **서로 다른 칸에** 있어야
	#  방사형이다. ⚠ 「여덟 방향이 다르다」 자체는 위 표 검사가 이미 봤다.
	var px := sim.get_px()
	var py := sim.get_py()
	var spots: Dictionary = {}
	for i in alive:
		spots["%d,%d" % [px[i] >> SpellSim.FP_SHIFT, py[i] >> SpellSim.FP_SHIFT]] = true
	t.eq(spots.size(), alive, "살아남은 탄이 서로 다른 칸으로 흩어졌다")

	# 🔴 **작은 것들은 약하다** — 속도가 세대 표에서 나온다(항력 사거리가 곧 여기서 갈린다).
	# ⚠ 갓 난 탄은 **자기가 태어난 틱에 한 번 나아간다**(아래 `_spread_advances_on_birth_tick`)
	#  ⇒ 관측값에는 항력이 한 번 이미 먹혀 있어 표값보다 2~11% 낮다. 그래서 구간으로 잰다.
	var want := Tuning.speed_cells(1) << SpellSim.FP_SHIFT
	var want2 := want * want
	var in_band := true
	for i in alive:
		var got2: int = vx[i] * vx[i] + vy[i] * vy[i]
		if got2 > want2 or got2 * 100 < want2 * 70:
			in_band = false
	t.ok(in_band, "확산 탄의 속도가 세대 1 값(%d셀/틱)에서 나온다" % Tuning.speed_cells(1))
	t.ok(Tuning.speed_cells(1) < Tuning.speed_cells(0),
		"세대 1이 세대 0보다 느리다 (%d < %d)" % [Tuning.speed_cells(1), Tuning.speed_cells(0)])


## 🔴🔴 **「탄을 만드는 문양은 새 탄들에게 남은 목록을 넘긴다」**(GDD).
##  넘기지 않으면 확산→폭발이 그냥 확산이 되고, **에러 없이 마법 하나가 사라진다.**
func _spread_hands_over_list(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack(two)), "확산 → 폭발을 실은 탄이 나간다")

	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break

	# 살아남은 것이 **하나도 빠짐없이** 폭발을 들고 있어야 한다. 몇 개가 살아남았는지는
	# 지형이 정하므로 개수가 아니라 **비율**을 잰다(위 주석).
	var alive := sim.active_count()
	t.ok(alive > 0, "확산으로 난 탄이 살아 있다 (%d발)" % alive)
	var gl := sim.get_glyphs()
	var carried := 0
	for i in alive:
		if Glyph.first(gl[i]) == Glyph.GLYPH_BLAST:
			carried += 1
	t.eq(carried, alive, "살아남은 탄이 **전부** 남은 목록(폭발)을 들고 간다")


## 🔴🔴 **갓 난 탄은 자기가 태어난 틱에 한 번 나아간다.**
##  소멸이 swap-remove라 `_remove`가 **방금 태어난 탄을 현재 슬롯으로 끌어오고**, 루프가 그걸
##  이어서 돈다. 우연이 아니라 결정론적이고, 화면에서는 「착탄과 동시에 방사형으로 튄다」로 읽힌다.
## ⚠ 여기를 안 재면 다음 사람이 리팩터링하다 **한 틱 멈칫하는 확산**으로 바꿔 놓고도 모른다.
func _spread_advances_on_birth_tick(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	_fire(sim, 22, 70, 100, 0, Glyph.pack(one))
	var origin: int = sim.get_id()[0]
	for _i in 12:
		sim.step(g)
		if not _has_id(sim, origin):
			break
	t.ok(sim.active_count() > 0, "확산이 일어났다")
	# 태어난 자리에 그대로 서 있으면 `_prev`와 현재가 같다.
	var moved := true
	var px := sim.get_px()
	var py := sim.get_py()
	var qx := sim.get_prev_px()
	var qy := sim.get_prev_py()
	for i in sim.active_count():
		if px[i] == qx[i] and py[i] == qy[i]:
			moved = false
	t.ok(moved, "갓 난 탄이 태어난 틱에 이미 움직였다")


## 🔴🔴 **이 단계가 재는 것 전부.** 같은 문양 둘, 순서만 다른데 **결과의 종류**가 달라야 한다.
##  · 확산 → 폭발 = 퍼진 것들이 각자 터진다 → **폭발 여덟 번**
##  · 폭발 → 확산 = 먼저 한 번 크게 터지고 그 자리에서 퍼진다 → **폭발 한 번**
## ⚠ 그물이 낼 수 있는 건 이 **대리치**까지다. 「다른 마법으로 보이나」는 눈이 재는 것이고,
##  여기가 초록인데 화면에서 안 갈리면 **그게 이 단계가 멈춰야 하는 신호다**(기획 판정).
func _order_changes_the_spell(t) -> void:
	var spread_then_blast: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	var blast_then_spread: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD]

	var a := _count_blasts(Glyph.pack(spread_then_blast))
	var b := _count_blasts(Glyph.pack(blast_then_spread))
	t.eq(a, Tuning.SPREAD_COUNT, "확산 → 폭발은 폭발이 %d번이다" % Tuning.SPREAD_COUNT)
	t.eq(b, 1, "폭발 → 확산은 폭발이 1번이다")
	t.ok(a != b, "순서를 바꾸면 결과의 **종류**가 바뀐다 (%d회 vs %d회)" % [a, b])

	# 🔴 폭발 한 번 쪽은 **세대 0**이라 크게 터지고, 여덟 번 쪽은 세대 1이라 작게 터진다.
	#  그 차이가 지형 자국의 모양을 가른다(구멍 하나 vs 구멍 여덟).
	t.ok(Tuning.blast_rd(1) < Tuning.blast_rd(0),
		"세대 1 폭발이 더 작다 (rd %d < %d)" % [Tuning.blast_rd(1), Tuning.blast_rd(0)])


## 폭발 총 횟수. 🔴 **닫힌 동굴에서 센다** — 확산 8발이 전부 뭔가에 맞아야 8회가 나온다
##  (기획 「무대」가 상자를 고른 이유와 같다).
func _count_blasts(packed: int) -> int:
	var g := _cave_grid()
	var sim := SpellSim.new()
	if not _fire(sim, 22, 70, 100, 0, packed):
		return -1
	var total := 0
	# 예산이 틱당 4발이라 8발은 최소 두 틱에 나뉜다. 떨어지는 탄이 바닥에 닿을 시간까지 넉넉히.
	for _i in 90:
		sim.step(g)
		total += sim.blast_count()
	return total


## 🔴🔴 **`max_per_circle`의 첫 소비자다.** GDD가 폭증을 상한이 아니라 **제약**으로 막기로 했고,
##  확산이 하나뿐이면 8 → 64 폭증이 **구조적으로 불가능해진다.**
## ⚠ 조립창(B)이 생기면 같은 표를 읽어 놓기 전에 막는다 — 그래도 커맨드 경계는 남는다.
##  네트워크는 조립창을 안 지난다.
func _spread_capped_per_circle(t) -> void:
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_SPREAD]["max_per_circle"]), 1,
		"확산은 한 마법진에 하나까지다 (GDD)")

	var sim := SpellSim.new()
	var twice: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_SPREAD]
	t.expect_error("한 마법진에")
	t.ok(not _fire(sim, 10, 70, 100, 0, Glyph.pack(twice)),
		"확산 두 겹은 발사 시점에 짖고 버려진다")
	t.eq(sim.active_count(), 0, "버린 발사가 탄을 안 남긴다")

	# 폭발은 무제한이라 두 겹이 통과해야 한다 — 제약이 **모든 문양에 걸리면** 그건 다른 버그다.
	var blast_twice: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, 10, 70, 100, 0, Glyph.pack(blast_twice)), "폭발 두 겹은 통과한다 (무제한)")

	# 🔴 **크기 하한.** 확산이 하나뿐이라 2세대는 이미 원리적으로 못 나오지만, 그 규칙이
	#  느슨해지는 날을 위한 구조적 바닥이다.
	t.ok(Tuning.SPLIT_MAX >= 1, "확산이 최소 한 번은 걸린다")


## 🔴🔴 **`kind`가 「이어질지 끝날지」를 고른다**(GDD 「문양의 실행 규칙」).
##  ⚠ 이 축에 소비자가 없으면 표의 `kind`를 바꿔도 아무 일이 안 일어나고, 그러면 규칙이
##   주석에만 남는다. 아래 둘이 그 축의 관측 지점이다.
func _kind_decides_continuation(t) -> void:
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_BLAST]["kind"]), Glyph.KIND_TERMINAL, "폭발은 TERMINAL이다")
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_SPREAD]["kind"]), Glyph.KIND_SPAWN, "확산은 SPAWN이다")

	# TERMINAL: 탄이 안 생기므로 **같은 자리에서 이어진다** ⇒ 폭발 두 겹이 두 번 터진다.
	var chain: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.eq(_count_blasts(Glyph.pack(chain)), 2, "TERMINAL은 같은 자리에서 이어 실행된다")

	# SPAWN: 목록을 새 탄이 들고 갔으므로 **여기서 끝난다** ⇒ 확산 → 폭발이 8번이지 9번이 아니다.
	# 🔴 9가 나오면 `kind` 분기가 죽어서 목록이 **두 번** 실행된 것이다.
	var hand_over: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.eq(_count_blasts(Glyph.pack(hand_over)), Tuning.SPREAD_COUNT,
		"SPAWN은 목록을 넘기고 그 자리에서 끝난다 (8번이지 9번이 아니다)")


# ══════════════════════════════════════════════════════════════════
#  파기 — 모든 착탄이 지형을 판다
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **문양이 없어도, 룬이 무속성이어도 착탄은 판다**(`spell_sim._impact` 의 ①).
##
## ⚠ **이 그물이 메우는 자리가 정확히 「파는 반경 0」이었고, 그게 내내 초록이었다** —
##  사용자가 게임을 하고 「일반 마법이랑 불마법이 벽을 한 칸도 못 줄인다 · **공격한 건지
##  아닌지도 구분이 안 간다**」고 보고할 때까지 아무도 안 짖었다(2026-08-05).
##
## 🔴🔴 **「줄었다」로 끝내면 반경이 아무 값이어도 초록이다** —
##  `net_damage._enqueue_becomes_a_projectile` 이 「나아갔다」로 끝냈다가 **두 배 속도가
##  그냥 통과했던** 그 모양이다. ⇒ **깊이로 반경을 못 박는다.**
##  ⚠ **세로 폭이 아니라 깊이인 이유**: 착탄점은 벽 왼쪽 **빈칸**이라 원반의 오른쪽 절반만
##   벽에 들어간다. 벽 첫 열의 세로 폭은 `2·√(r²−1)+1` 이라 **그물이 `_disc` 를 베끼게 되고**,
##   둘이 갈라지면 그물이 틀린 쪽 편을 든다. 깊이는 `dy = 0` 줄이라 **반경과 정확히 같다.**
func _every_impact_carves(t) -> void:
	# ── ① 돌벽 + 무속성. 🔴 사용자가 지목한 절반이 여기다 — 「**일반 마법이랑** 불마법이」.
	var stone := _cave_grid()
	var s := SpellSim.new()
	t.ok(s.fire(SpellSim.cmd_fire(22, 70, 100, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE)),
		"무속성 · 문양 없는 탄이 돌벽으로 나간다")
	var before := stone.count_material(Mat.STONE)
	_run_until_impact(s, stone, 12)
	var carved := before - stone.count_material(Mat.STONE)
	t.ok(carved > 0, "돌이 준다 (%d칸 · 돌 %d → %d)" % [
		carved, before, stone.count_material(Mat.STONE)])
	# 🔴 파기는 폭발이 아니다 — 섬광도 흔들림도 안 뜬다. 그게 판정 4를 돕는 방향이다.
	t.eq(s.blast_count(), 0, "파기는 폭발 통지를 안 낸다 (구멍은 나는데 화면이 안 번쩍한다)")
	t.eq(_eaten_depth(stone), Tuning.carve_r(0),
		"판 깊이가 세대 0의 파는 반경(%d셀)이다" % Tuning.carve_r(0))

	# ── ② 나무벽 + 불 룬 — **파고 그 자리에 불.** 실제 그림은 **고리**다:
	#  안쪽 `carve_r` 은 파이고 `carve_r < r ≤ rune_r` 인 띠가 탄다.
	# 🔴🔴 **`carve_r < rune_r` 이 그 고리의 유일한 조건이다** — 안 서면 파기가 태울 연료를
	#  먼저 지워 **불만 조용히 사라진다.** 값 축은 `net_tables` 가 세대마다 잰다.
	var wood := _wood_cave_grid()
	var s2 := SpellSim.new()
	t.ok(_fire(s2, 22, 70, 100, 0), "불 룬 · 문양 없는 탄이 나무벽으로 나간다")
	_run_until_impact(s2, wood, 12)
	t.eq(_eaten_depth(wood), Tuning.carve_r(0),
		"나무벽도 같은 반경(%d셀)만큼 파인다 (재료를 안 가린다)" % Tuning.carve_r(0))
	t.ok(wood.burning_count() > 0,
		"그리고 그 자리에 불이 붙는다 (%d칸)" % wood.burning_count())
	# 🔴 불이 파기보다 **바깥까지** 닿는 것이 「고리」의 값 표현이다.
	t.eq(_burn_depth(wood, CAVE_X1 + 1, CAVE_X1 + 20, CAVE_Y0, CAVE_Y1, true), Tuning.rune_r(0),
		"불이 파기 바깥 %d셀까지 닿는다 (고리다 — 점화 %d > 파기 %d)" % [
			Tuning.rune_r(0) - Tuning.carve_r(0), Tuning.rune_r(0), Tuning.carve_r(0)])


## 🔴🔴 **같은 자리를 여러 번 쏘면 뚫린다**(판정 3). 사용자가 「한 칸도 못 줄인다」로 연
##  문서라 **뚫리느냐가 곧 이 단계의 답이다.**
## ⚠ **단언은 「뚫렸다」까지고 발수는 기록이다** — 목표 숫자를 박으면 값이 두 벌이 되고,
##  손맛은 화면이 정한다(기획 「미정」).
## 🔴 **매번 새 `SpellSim` 이다** — 같은 격자에 한 발씩 쏘는 것이 「같은 자리를 여러 번」이고,
##  한 시뮬에 몰아 쏘면 여덟 발이 같은 틱에 날아가 **다른 상황**이 된다.
func _repeated_shots_pierce_the_wall(t) -> void:
	var g := _wall_grid()
	t.ok(not _wall_pierced(g), "쏘기 전에는 벽이 안 뚫려 있다 (검사의 전제)")
	var shots := 0
	while shots < 20 and not _wall_pierced(g):
		var sim := SpellSim.new()
		if not _fire(sim, 10, 70, 100, 0):
			break
		shots += 1
		_run_until_impact(sim, g, 12)
	# 🔴 **라벨이 「무슨 벽인지」까지 말해야 한다.** 이 벽은 4셀 = **타일 반 장**이고
	#  무대의 진짜 타일은 8셀이다(`sim_tuning.TILE_CELLS`) — 여기 발수를 게임의 발수로 읽으면 틀린다.
	#  ⚠ 실측(verify-run): **8셀 벽은 5발**이다. 매 발 `carve_r` 만큼 곧게 전진하지 않는다 —
	#   중력으로 착탄 행이 흔들려 앞 발이 얕게 판 이웃 행에 떨어지는 발이 섞인다.
	t.ok(_wall_pierced(g),
		"같은 자리를 반복해 쏘면 벽 %d셀(타일 %s장)이 뚫린다 (**%d발** — 기록이다)" % [
			WALL_X1 - WALL_X0 + 1,
			"%.1f" % (float(WALL_X1 - WALL_X0 + 1) / float(Tuning.TILE_CELLS)), shots])
	# 🔴 대조군 — **한 발로는 안 뚫린다.** 없으면 위 초록이 「여러 발이라 뚫렸다」인지
	#  「한 발이 원래 뚫는다」인지 못 가른다. ⚠ 그 둘이 갈리는 것이 판정 4(폭발은 한 방)다.
	t.ok(shots > 1, "한 발로는 안 뚫린다 (%d발이 필요했다)" % shots)


# ══════════════════════════════════════════════════════════════════
#  룬의 흔적 — 문양이 없어도 착탄은 룬만큼은 한다
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **기획 변경의 본체.** 문양이 하나도 없는 탄도 착탄하면 불 룬만큼은 한다.
##  ⚠ 이게 없으면 「폭발 → 확산」에서 만들어진 탄 여덟이 **빈 목록**을 들고 나서 흔적을 0으로 남긴다 —
##   실측으로 키 5는 매끈한 구멍 하나 외에 아무 데도 안 건드렸다. **조합의 절반이 화면에서 증발한다.**
func _rune_leaves_a_trace(t) -> void:
	# 나무에 맞으면 불이 붙는다.
	var wood := _wood_cave_grid()
	var sim := SpellSim.new()
	t.ok(_fire(sim, 22, 70, 100, 0), "문양 없는 탄을 나무에 쏜다")
	var before := wood.count_material(Mat.WOOD)
	_run_until_impact(sim, wood, 12)
	t.ok(wood.burning_count() > 0,
		"문양이 없어도 착탄점에 불이 붙는다 (%d칸)" % wood.burning_count())

	# 🔴🔴 **흔적 자신은 지형을 안 부순다** — 파는 것은 착탄(`_impact` 의 ①)이지 룬이 아니다.
	#  ⚠ **전에는 「한 칸도 안 부순다」로 쟀고 2026-08-05에 그 관측이 죽었다.** 이제 모든 착탄이
	#   파므로 남는 물음은 「**룬이 파는 양을 바꾸나**」이고, 답은 「안 바꾼다」다 — ①에 분기가 없다.
	#  🔴 **그게 「어떤 탄은 파고 어떤 탄은 안 판다」를 막는 유일한 거동 관측이다.**
	#   `_impact` 의 ①을 `_rune_trace` 안으로 옮기면 무속성만 안 파고, 여기가 그때 빨개진다.
	#  ⚠ 불이 번지기 전에 재야 한다 — 다 타면 나무가 줄어드는 게 맞다(그건 불의 일이지 흔적의 일이 아니다).
	t.eq(before - wood.count_material(Mat.WOOD), _carved_by(Tuning.ELEM_NONE, true),
		"파는 양이 룬과 무관하다 (불 룬과 무속성이 나무를 같은 칸 수 판다)")
	t.eq(sim.blast_count(), 0, "룬 흔적은 폭발이 아니다 (폭발 통지가 0이다)")

	# 돌에는 불이 안 붙는다 — 연료가 없으니까. 「탈 것이 있는 곳으로만」이 여기도 그대로다.
	var stone := _cave_grid()
	var s2 := SpellSim.new()
	t.ok(_fire(s2, 22, 70, 100, 0), "문양 없는 탄을 돌에 쏜다")
	var kept := stone.count_material(Mat.STONE)
	_run_until_impact(s2, stone, 12)
	t.eq(stone.burning_count(), 0, "돌에는 흔적이 안 남는다 (연료가 0이다)")
	t.eq(kept - stone.count_material(Mat.STONE), _carved_by(Tuning.ELEM_NONE, false),
		"돌도 룬과 무관하게 같은 만큼 파인다")


## 같은 자리에 룬 `element` 로 **문양 없이** 한 발 쏘고, 줄어든 재료 칸 수를 돌려준다.
## 🔴 대조군 전용이다 — 「룬이 파는 양을 바꾸나」는 **같은 배치·같은 궤적**으로만 잴 수 있고,
##  거동(속도·궤적)이 룬과 무관한 것은 `sim_tuning.ELEM_NONE` 이 못 박은 성질이다.
## ⚠ `grid.step()` 을 안 부르므로 **불이 번지지 않는다** — 재료가 주는 원인은 파기 하나뿐이다.
func _carved_by(element: int, wood_walls: bool) -> int:
	var g := _wood_cave_grid() if wood_walls else _cave_grid()
	var mat := Mat.WOOD if wood_walls else Mat.STONE
	var sim := SpellSim.new()
	if not sim.fire(SpellSim.cmd_fire(22, 70, 100, 0, element, Glyph.GLYPH_NONE)):
		push_error("net_spell: 대조군 발사가 거부됐다 (룬 %d)" % element)
		return -1
	var before := g.count_material(mat)
	_run_until_impact(sim, g, 12)
	return before - g.count_material(mat)


## 🔴 표에만 있고 코드에 없는 룬을 **래퍼의 stderr 검사에 공짜로** 건다
##  (`_rune_trace`가 모르는 흔적에 짖는다). `_every_glyph_runs`와 같은 장치다.
##
## 🔴🔴 **라벨이 재는 것과 같아야 한다.** 옛 라벨은 「룬 %d의 흔적이 **세상에 남는다**」였고
##  실제로 잰 것은 `burning_count() > 0` 하나였다 — **무속성은 정의상 0이라 그 라벨이 곧 거짓이 된다.**
##  ⚠ `continue`로 무속성을 건너뛰는 것은 **사면 넓히기**다(CLAUDE.md). 라벨을 좁힌다:
##  「**룬마다 `ELEM_DEFS`의 `trace`가 말하는 결과가 실제로 난다**」.
## 🔴 **`else`가 `t.ok(false)`인 것이 이 교정의 핵심이다** — 흔적 종류가 셋이 되는 날
##  코드보다 **그물이 먼저 짖는다.**
##
## 🔴🔴 **그리고 이것이 판정 7의 그물이다**(기획 「무속성 룬과 불 룬이 다르나」).
##  무속성은 「아무것도 안 한다」라서 **발사가 거부된 것과 화면에서 구별이 안 된다** ⇒
##  넷을 **같이** 단언한다: `fire()`가 참 · 탄이 실제로 났다 · 착탄해서 원본이 사라졌다 ·
##  **그리고 격자가 실제로 변했다.** 안 하면 「무속성이면 발사가 거부된다」는 버그도 초록이다.
##  ⚠ 마지막 항은 2026-08-05에 **부호가 뒤집혔다**(「한 칸도 안 변한다」 → 「변한다」) —
##   파기가 룬과 무관해지면서 무속성도 판다. 갈래 안에 이유를 적어 뒀다.
## ⚠ 대조군은 따로 만들지 않는다 — **같은 루프의 불 룬이 대조군이다**(같은 자리·같은 조합).
##  그래서 두 갈래가 `burning_count` 를 반대 방향으로 잰다.
func _every_rune_traces(t) -> void:
	t.eq(Tuning.ELEM_ALL.size(), Tuning.ELEM_DEFS.size(),
		"착탄시켜 볼 룬이 %d개다" % Tuning.ELEM_ALL.size())
	for element: int in Tuning.ELEM_ALL:
		var g := _wood_cave_grid()
		var sim := SpellSim.new()
		t.ok(sim.fire(SpellSim.cmd_fire(22, 70, 100, 0, element, Glyph.GLYPH_NONE)),
			"룬 %d: fire()가 참을 준다" % element)
		# 🔴 `fire()`의 참만 믿지 않는다 — 탄이 **실제로** 났나.
		t.eq(sim.active_count(), 1, "룬 %d: 탄이 실제로 났다" % element)
		if sim.active_count() != 1:
			# ⚠ 여기서 조용히 넘어가면 검사가 「실패」가 아니라 **없어진다.**
			t.ok(false, "룬 %d: 탄이 없어서 흔적을 **하나도 못 쟀다**" % element)
			continue
		var origin: int = sim.get_id()[0]

		# 🔴 **여기서 계수기를 0으로 맞춘다.** 동굴을 판 것까지 세면 아래 「안 변했다」가 뜻이 없다.
		g.consume_changed()
		_run_until_impact(sim, g, 12)
		t.ok(not _has_id(sim, origin), "룬 %d: 탄이 착탄까지 살아서 사라졌다" % element)
		# ⚠ 한 번만 읽는다 — `consume_changed()`는 **읽으면 0으로 돌아간다.**
		var changed := g.consume_changed()

		var def: Variant = Tuning.ELEM_DEFS.get(element, null)
		t.ok(def is Dictionary, "룬 %d이 ELEM_DEFS에 있다" % element)
		if not (def is Dictionary):
			continue
		var trace := int((def as Dictionary).get("trace", -1))
		if trace == Tuning.TRACE_IGNITE:
			t.ok(g.burning_count() > 0,
				"룬 %d(점화): 불이 붙는다 (%d칸)" % [element, g.burning_count()])
			t.ok(changed > 0, "룬 %d(점화): 격자가 실제로 변했다 (%d칸)" % [element, changed])
		elif trace == Tuning.TRACE_NONE:
			t.eq(g.burning_count(), 0, "룬 %d(흔적 없음): 불이 한 칸도 안 붙는다" % element)
			# ⚠ **전에는 「격자가 한 칸도 안 변한다」였다.** 2026-08-05에 무속성의 뜻이
			#  「세상에 아무것도 안 한다」에서 **「흔적을 안 남긴다」**로 좁아졌다 — 파기가
			#  `_impact` 의 ①로 올라가 룬과 무관해졌고, 사용자가 **일반 마법도** 벽을 파야
			#  한다고 지목했다.
			# 🔴 **그래도 「발사가 거부된 것과 구별된다」는 남아야 하므로** 0 대신 **양수**를
			#  요구한다. 안 하면 「무속성이면 발사가 거부된다」는 버그가 다시 초록이 된다.
			t.ok(changed > 0,
				"룬 %d(흔적 없음): 그래도 격자를 판다 (%d칸)" % [element, changed])
		elif trace == Tuning.TRACE_WET:
			# 🔴 **불 갈래의 거울이다.** 같은 자리·같은 조합으로 쏘고, **남는 것만** 다르다.
			#  ⇒ 같은 루프의 불 룬이 그대로 대조군이 된다(위 주석의 어법).
			t.ok(g.count_material(Mat.WATER) > 0,
				"룬 %d(적심): 물이 생긴다 (%d칸)" % [element, g.count_material(Mat.WATER)])
			# 🔴 **물 룬은 불을 안 붙인다.** 반대쪽을 안 재면 「모든 룬이 다 한다」가 통과한다.
			t.eq(g.burning_count(), 0, "룬 %d(적심): 불은 한 칸도 안 붙는다" % element)
			t.ok(changed > 0, "룬 %d(적심): 격자가 실제로 변했다 (%d칸)" % [element, changed])
		else:
			t.ok(false, "흔적 종류 %d에 이 그물이 단언을 안 갖고 있다 (룬 %d)" % [trace, element])


## 🔴🔴 **`_rune_trace`의 `TRACE_NONE` 갈래는 거동으로 못 지킨다.**
##  그 두 줄을 지워도 **위 단언이 전부 통과한다** — 「아무것도 안 한다」와 「짖고 아무것도 안 한다」는
##  격자에서 구별이 안 되기 때문이다(실측). 잡는 것은 래퍼의 stderr뿐이다.
##
## 🔴 **그런데 지금 그 짖음이 안 사면되는 이유가 「말이 우연히 다른 덕」이다.** 누가
##  `expect_error("룬 흔적")` 류를 어디서든 선언하는 날 — 🔴 **사면은 실행 전체에 걸린다** —
##  이 갈래는 **아무도 안 보는 코드**가 된다. ⇒ 우연에 기대지 않고 바늘을 하나 건다.
##
## 🔴 **라벨이 재는 것**: 「`_rune_trace`에 `TRACE_NONE` 갈래가 **있다**」까지다.
##  ⚠ **「무속성이 아무것도 안 한다」가 아니다** — 그건 거동이고 텍스트는 문법만 본다.
##   거동 쪽은 위 `_every_rune_traces`가 잰다.
func _rune_trace_has_the_none_branch(t) -> void:
	var raw := _read(SPELL_SIM_SCRIPT)
	t.ok(raw.length() > 0, "spell_sim.gd를 읽었다 (%d바이트)" % raw.length())
	t.ok(not raw.contains("\"\"\""), "spell_sim.gd에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var body := _func_body(NetDeterminism._strip(raw), "_rune_trace")
	# 🔴 **함수를 못 찾으면 빈 문자열이고 아래가 공짜로 「없다」가 된다.** 전제를 먼저 건다.
	t.ok(body.length() > 0, "spell_sim.gd에서 `_rune_trace` 본문을 떠냈다 (%d자)" % body.length())
	t.ok(body.contains("TRACE_IGNITE"),
		"떠낸 것이 정말 `_rune_trace`다 (이미 아는 갈래가 들어 있다)")
	t.ok(body.contains("Tuning.TRACE_NONE"), "`_rune_trace`에 `TRACE_NONE` 갈래가 있다")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_spell: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()


## `func <이름>(` 부터 **다음 `func` 직전까지.** ⚠ 함수가 없으면 빈 문자열이다 —
##  부르는 쪽이 그걸 단언해야 한다.
func _func_body(src: String, nm: String) -> String:
	var head := src.find("func %s(" % nm)
	if head < 0:
		return ""
	var tail := src.find("\nfunc ", head + 1)
	return src.substr(head, -1 if tail < 0 else tail - head)


## 🔴🔴 **이 검사가 기획 변경의 이유 그 자체다.**
##  확산으로 난 탄 여덟은 **빈 목록**을 들고 난다. 그것들이 각자 흔적을 남기지 않으면
##  「폭발 1번 + 잔불 8갈래」의 **잔불 쪽이 통째로 없다.**
##
## ⚠ 「불이 붙었나」로는 부족하다 — 부모 하나만 붙어도 참이 된다.
##  ⇒ **불이 붙은 자리가 얼마나 넓게 흩어졌나**를 잰다. 확산은 8방향으로 날아가 각자 다른 벽에
##   맞으므로 상자가 넓고, 문양 없는 한 발은 착탄점 한 곳뿐이라 좁다.
func _empty_list_bolts_leave_marks(t) -> void:
	var lone := _burning_spread(Glyph.GLYPH_NONE)
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	var spread := _burning_spread(Glyph.pack(one))
	t.ok(lone > 0, "문양 없는 한 발도 흔적을 남긴다 (폭 %d셀)" % lone)
	t.ok(spread > lone * 2,
		"확산 여덟 발의 흔적이 훨씬 넓게 흩어진다 (폭 %d셀 vs %d셀)" % [spread, lone])


## 🔴🔴 **문양을 든 탄도 흔적을 남긴다.**
##  ⚠ 실측으로 `_impact` 에 「목록이 비었을 때만」 분기를 넣어도 574개가 전부 초록이었다 —
##   룬 검사가 죄다 **문양 없는 탄**으로만 쐈기 때문이다. 규칙이 둘로 갈라지는 걸 막으려고
##   분기를 안 뒀는데, **그 결정을 지키는 사람이 없었다.**
##
## 🔴 **폭발로는 못 잰다** — `rune_r < rd` 가 계약이라 흔적이 폭발 반경 안에 통째로 묻힌다.
##  ⇒ **확산**으로 잰다. 확산은 파괴를 안 하니 원본의 흔적이 벽에 그대로 남는다.
## 🔴 **깊이가 가른다.** 원본은 세대 0이라 벽을 3셀 파고들고, 확산으로 난 탄은 세대 1이라 1셀이다.
##  둘 다 **같은 벽**을 때리므로 「불이 붙었나」로는 구별이 안 된다.
func _glyph_bolt_also_traces(t) -> void:
	var g := _wood_cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	t.ok(_fire(sim, 22, 70, 100, 0, Glyph.pack(one)), "확산을 실은 탄이 나간다")
	_run_until_impact(sim, g, 12)
	t.eq(_burn_depth(g, CAVE_X1 + 1, CAVE_X1 + 20, CAVE_Y0, CAVE_Y1, true), Tuning.rune_r(0),
		"문양을 든 탄도 흔적을 남긴다 (벽 %d셀 — 세대 1 흔적 %d셀로는 못 낸다)" % [
			Tuning.rune_r(0), Tuning.rune_r(1)])


## 🔴🔴 **세대 1의 흔적이 세대 0보다 작아야 한다.**
##  ⚠ 실측으로 `Tuning.rune_r(gen)` 을 `rune_r(0)` 으로 바꿔도 574개가 전부 초록이었다 —
##   `net_tables` 는 **표의 단조만** 잰다. 파생 경로를 아무도 안 봤다.
##   그러면 「작은 것들이 약하다」가 이 축에서만 화면에 안 드러나고,
##   **「잔불 8갈래」가 원본과 같은 굵기로 뜬다.**
##
## 🔴 **바닥으로 잰다.** 원본은 오른쪽 벽에서 죽었고 흔적이 3셀이라 12셀 아래 바닥에 못 닿는다.
##  ⇒ 바닥에 남은 자국은 **확산으로 난 세대 1 탄의 것뿐**이다.
func _rune_trace_follows_gen(t) -> void:
	var g := _wood_cave_grid()
	var sim := SpellSim.new()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	_fire(sim, 22, 70, 100, 0, Glyph.pack(one))
	for _i in 20:
		sim.step(g)
	var depth := _burn_depth(g, CAVE_X0, CAVE_X1, CAVE_Y1 + 1, CAVE_Y1 + 20, false)
	t.ok(depth > 0, "확산으로 난 탄이 바닥에도 흔적을 남긴다")
	t.eq(depth, Tuning.rune_r(1),
		"그 흔적이 **세대 1** 크기다 (%d셀 · 세대 0이면 %d셀이다)" % [depth, Tuning.rune_r(0)])


## 🔴🔴 **슬롯이 없어 확산이 하나도 못 나면, 남은 목록이 착탄점에서 세대 0으로 실행된다** —
##  「확산 → 폭발」이 작은 구멍 여덟 대신 **큰 구멍 하나**가 된다. GDD가 다른 마법이라고 못 박은 차이다.
##  ⇒ 조용히 다른 마법이 되느니 **짖고 버려야** 한다.
##
## ⚠ 도달 불가한 상태가 아니다 — 벽에 대고 빠르게 네 번 누르면 닿는 범위다.
func _spread_without_room(t) -> void:
	var g := _cave_grid()
	var sim := SpellSim.new()

	# 벽 코앞에서 확산 → 폭발을 쏜다. 첫 틱에 착탄한다.
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.ok(_fire(sim, CAVE_X1 - 2, 70, 100, 0, Glyph.pack(two)), "확산 → 폭발을 실은 탄이 나간다")
	# 나머지 슬롯을 **오래 나는** 탄으로 채운다(방을 가로질러 왼쪽으로 간다).
	while sim.active_count() < Tuning.MAX_PROJECTILES:
		_fire(sim, CAVE_X1 - 2, 70, -100, -20)
	t.eq(sim.active_count(), Tuning.MAX_PROJECTILES, "슬롯이 꽉 찬 채로 확산이 착탄한다")

	# 8번의 `_launch` 실패 + 확산 자신의 짖음. 둘 다 정당하다.
	t.expect_error("동시 투사체 상한")
	t.expect_error("확산이 슬롯을 하나도 못 얻었다")
	var total := 0
	for _i in 40:
		sim.step(g)
		total += sim.blast_count()
	t.eq(total, 0,
		"슬롯이 없으면 남은 폭발을 **버린다** (세대 0 폭발 한 방으로 안 바뀐다)")

	# 🔴 대조군 — 자리가 있으면 같은 목록이 폭발 8회다. 이게 없으면 위 0이
	#  「버렸다」인지 「원래 안 터진다」인지 못 가른다.
	t.eq(_count_blasts(Glyph.pack(two)), Tuning.SPREAD_COUNT,
		"자리가 있으면 같은 목록이 폭발 %d회다" % Tuning.SPREAD_COUNT)


## 🔴🔴 **구덩이 크기가 세대 표에서 나오나.**
##  통지가 반경을 안 나르므로(연출이 안 쓴다) `_run_glyph`가 `blast_rd(gen)`을 쓰는지는
##  **격자에 남은 구멍으로** 재는 수밖에 없다.
##
## ⚠ **세대 0으로 재면 헛돈다.** `blast_rd(0)`이 12라, 코드에 12를 상수로 박아도 12 == 12다 —
##  처음에 그렇게 짰고 「상수로 박아도 안 걸린다」는 주석까지 달아 놓고 **정확히 그 경우를
##  통과시켰다.** ⇒ **세대 1(6셀)로 재야 표를 실제로 읽는지가 갈린다.**
## 🔴 세대 1 폭발 **하나만** 만드는 법: 자유 슬롯을 1개만 남기고 확산시킨다. 그러면 첫 방향
##  (+1,0) 하나만 태어나 옆 벽에 즉시 착탄하고, 구덩이가 딱 하나 남는다.
func _crater_follows_gen(t) -> void:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	t.eq(_crater_depth(Glyph.pack(one), Tuning.MAX_PROJECTILES - 1), Tuning.blast_rd(0),
		"세대 0 구덩이가 %d셀이다" % Tuning.blast_rd(0))

	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.expect_error("동시 투사체 상한")
	# 🔴🔴 **부모의 파기가 벽을 `carve_r(0)` 만큼 물러나게 해 놓는다** — 자식은 그만큼 깊은
	#  자리에서 착탄하므로 깊이가 **두 값의 합**이다.
	#  ⚠ 2026-08-05 전에는 `blast_rd(1)` 하나였다. 착탄이 파기 시작하며 이 배치가 한 칸 밀렸다.
	var want := Tuning.carve_r(0) + Tuning.blast_rd(1)
	t.eq(_crater_depth(Glyph.pack(two), 1), want,
		"세대 1 구덩이가 %d셀이다 (부모가 판 %d + 세대 1 폭발 %d · 표를 실제로 읽는다)" % [
			want, Tuning.carve_r(0), Tuning.blast_rd(1)])
	t.ok(Tuning.blast_rd(1) < Tuning.blast_rd(0), "두 값이 애초에 다르다 (검사가 헛돌지 않는다)")


## 🔴🔴 **파는 반경도 세대를 따르나** (판정 7의 거동 축).
##  ⚠ `net_tables` 는 **표의 단조만** 잰다 — `Tuning.carve_r(gen)` 을 `carve_r(0)` 으로 바꿔도
##   표 축은 전부 초록이다. 🔴 `_rune_trace_follows_gen` 이 룬 흔적에서 이미 데인 자리고
##   (실측으로 574개가 전부 초록이었다), 파기도 같은 파생 경로다.
##
## 🔴 **깊이의 합으로 가른다**: 부모(세대 0)가 벽을 `carve_r(0)` 물러나게 하고, 확산으로 난
##  세대 1 탄이 **그 자리에서** `carve_r(1)` 을 더 판다 ⇒ 세대를 무시하면 `carve_r(0) × 2` 다.
func _carve_follows_gen(t) -> void:
	# 🔴 문양이 하나도 없다 — 파는 것은 착탄뿐이라 깊이가 곧 반경이다.
	t.eq(_crater_depth(Glyph.GLYPH_NONE, 0), Tuning.carve_r(0),
		"문양 없는 한 발이 벽을 세대 0 반경(%d셀)만큼 판다" % Tuning.carve_r(0))

	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	t.expect_error("동시 투사체 상한")
	var want := Tuning.carve_r(0) + Tuning.carve_r(1)
	t.eq(_crater_depth(Glyph.pack(one), 1), want,
		"확산 한 발이 그보다 세대 1 반경(%d셀)만큼 더 판다 (합 %d셀)" % [Tuning.carve_r(1), want])
	t.ok(Tuning.carve_r(1) < Tuning.carve_r(0),
		"두 값이 애초에 다르다 (%d < %d · 검사가 헛돌지 않는다)" % [
			Tuning.carve_r(1), Tuning.carve_r(0)])


## 오른쪽 벽을 몇 셀 파고들었나. 자유 슬롯을 `free_slots`개만 남기고 쏜다.
func _crater_depth(packed: int, free_slots: int) -> int:
	var g := _cave_grid()
	var sim := SpellSim.new()
	if not _fire(sim, CAVE_X1 - 2, 70, 100, 0, packed):
		return -1
	# 🔴 채움탄은 **왼쪽으로** 난다 — 반대편 벽에서 착탄하므로 오른쪽 벽 측정에 안 섞인다.
	#  ⚠ 「문양이 없어서 지형을 안 부순다」가 근거였는데 **2026-08-05에 그게 거짓이 됐다**
	#   (모든 착탄이 판다). 실제로 살아 있는 근거는 **방향**이다.
	while sim.active_count() < Tuning.MAX_PROJECTILES - free_slots:
		if not _fire(sim, CAVE_X1 - 2, 70, -100, -20):
			break
	for _i in 30:
		sim.step(g)
	return _eaten_depth(g)


## 오른쪽 벽이 몇 셀 사라졌나. 🔴 `_burn_depth` 의 파괴판이고 **같은 벽을 잰다** —
##  두 깊이를 맞대면 「안쪽은 파이고 바깥 띠가 탄다」는 고리가 값으로 나온다.
## ⚠ 방 안(x ≤ `CAVE_X1`)은 원래 빈칸이라 안 센다. 세는 것은 **벽이 먹힌 깊이**뿐이다.
func _eaten_depth(g: CellGrid) -> int:
	var reach := CAVE_X1
	for y in range(CAVE_Y0, CAVE_Y1 + 1):
		for x in range(CAVE_X1 + 1, CAVE_X1 + 40):
			if g.mat_at(x, y) == Mat.EMPTY:
				reach = maxi(reach, x)
	return reach - CAVE_X1


## 🔴🔴 **확산이 일부만 나면 방사형이 한쪽으로 찌그러진 채 마법이 진행된다.**
##  그물이 0발만 재고 있어서, 1~7발 나는 중간 상태를 아무도 안 봤다.
## 🔴 여기서 재는 계약: **태어난 수만큼 폭발한다.** 하나라도 태어나면 목록은 그들에게
##  넘어가고, **착탄점에서 세대 0으로 실행되지 않는다** — 그러면 `free+1`회가 나온다.
func _spread_partial(t) -> void:
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(two)
	t.expect_error("동시 투사체 상한")
	for free_slots: int in [1, 4, 7]:
		var g := _cave_grid()
		var sim := SpellSim.new()
		_fire(sim, CAVE_X1 - 2, 70, 100, 0, packed)
		while sim.active_count() < Tuning.MAX_PROJECTILES - free_slots:
			if not _fire(sim, CAVE_X1 - 2, 70, -100, -20):
				break
		var total := 0
		for _i in 60:
			sim.step(g)
			total += sim.blast_count()
		t.eq(total, free_slots,
			"자유 슬롯 %d개면 폭발이 %d회다 (태어난 수만큼만)" % [free_slots, free_slots])


## 방 밖으로 불이 몇 셀 파고들었나. `horizontal`이면 오른쪽 벽 깊이, 아니면 바닥 깊이다.
## ⚠ 이 그물은 `grid.step()` 을 안 부른다 ⇒ **불이 번지지 않는다.**
##  재는 것은 **점화 자국**이지 불이 아니다 — 그래서 깊이가 반경과 정확히 같다.
func _burn_depth(g: CellGrid, x0: int, x1: int, y0: int, y1: int, horizontal: bool) -> int:
	var far := -1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if (g.flag_at(x, y) & Mat.FLAG_BURNING) == 0:
				continue
			far = maxi(far, x if horizontal else y)
	if far < 0:
		return 0
	return far - (CAVE_X1 if horizontal else CAVE_Y1)


## 불이 붙은 칸들의 가로 폭(셀). 흔적이 **한 곳인가 여덟 곳인가**를 나르는 값이다.
## ⚠ 불은 번지므로 **같은 틱 수**로 두 조합을 재야 비교가 성립한다.
func _burning_spread(packed: int) -> int:
	var g := _wood_cave_grid()
	var sim := SpellSim.new()
	if not _fire(sim, 22, 70, 100, 0, packed):
		return -1
	for _i in 16:
		sim.step(g)
	var lo := CellGrid.W
	var hi := -1
	for y in range(50, 92):
		for x in range(10, 70):
			if (g.flag_at(x, y) & Mat.FLAG_BURNING) != 0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return 0 if hi < 0 else hi - lo + 1


# ══════════════════════════════════════════════════════════════════
#  도구
# ══════════════════════════════════════════════════════════════════

func _fire(sim: SpellSim, ox: int, oy: int, adx: int, ady: int,
		glyphs: int = Glyph.GLYPH_NONE) -> bool:
	return sim.fire(SpellSim.cmd_fire(ox, oy, adx, ady, Tuning.ELEM_FIRE, glyphs))


func _unpack(g: int) -> Array[int]:
	var out: Array[int] = []
	var cur := g
	while cur != Glyph.GLYPH_NONE:
		out.append(Glyph.first(cur))
		cur = Glyph.rest(cur)
	return out


func _has_id(sim: SpellSim, id: int) -> bool:
	var ids := sim.get_id()
	for i in sim.active_count():
		if ids[i] == id:
			return true
	return false


## 폭발 문양을 실은 탄 `n`발을 **같은 틱에 착탄하도록** 나란히 쏜다. 실제로 나간 수를 돌려준다.
##
## 🔴🔴 **줄 간격이 폭발 반경보다 넓어야 한다.** 같은 자리에 몰아 쏘면 첫 폭발이 벽을 지워 버려
##  나머지가 **그 구멍으로 그냥 날아간다** — 예산 검사가 초록으로 통과하는데 실제로는 한 발만
##  터진 것이다(처음에 그렇게 짰다가 걸렸다). 간격 16셀 > 반경 12셀이라 서로 안 지운다.
func _volley(sim: SpellSim, n: int) -> int:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	var packed := Glyph.pack(one)
	var gap := Tuning.blast_rd(0) + 4
	var fired := 0
	for k in n:
		if _fire(sim, 10, 8 + k * gap, 100, 0, packed):
			fired += 1
	return fired


## `ticks`틱을 돌리고 그동안의 **폭발 총 횟수**를 돌려준다.
## ⚠ 통지는 틱마다 지워지므로 매 틱 걷어야 한다.
func _run_ticks(sim: SpellSim, grid: CellGrid, ticks: int) -> int:
	var n := 0
	for _i in ticks:
		sim.step(grid)
		n += sim.blast_count()
	return n


## 4셀 두께의 돌 벽. 탄이 여기서 착탄한다.
func _wall_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(WALL_X0, 0, WALL_X1, CellGrid.H - 1, Mat.STONE))
	return g


## 벽에 **한 줄이라도 완전히 뚫린 곳**이 있나. 🔴 「돌이 줄었다」와 다른 물음이다 —
##  줄기만 하고 안 뚫리는 것이 사용자가 보고한 상태의 반대편이다.
func _wall_pierced(g: CellGrid) -> bool:
	for y in range(CellGrid.H):
		var open := true
		for x in range(WALL_X0, WALL_X1 + 1):
			if g.mat_at(x, y) != Mat.EMPTY:
				open = false
				break
		if open:
			return true
	return false


## 통째로 돌. 폭발이 지운 칸 수를 세는 자리다.
func _solid_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	return g


## 🔴🔴 **돌 속에 판 방.** 확산 8발이 **전부 뭔가에 맞는다** — 기획 「무대」가 상자를 고른 이유와 같다.
##
## ⚠ 얇은 바닥 위에서 재면 안 된다. 세대 1 폭발(rd 6)이 바닥을 뚫고 나머지가 격자 밖으로 새서
##  「폭발 8회」가 조용히 3회가 된다. **사방이 두꺼운 돌**이라 구덩이가 넓어져도 그 바깥은 여전히 돌이다.
##  (처음에 벽 하나짜리 무대로 짰다가 정확히 그렇게 걸렸다 — 폭발이 1회로 나왔다.)
func _cave_grid() -> CellGrid:
	var g := _solid_grid()
	g.apply(CellGrid.cmd_fill(CAVE_X0, CAVE_Y0, CAVE_X1, CAVE_Y1, Mat.EMPTY))
	return g


## 같은 방을 **나무**로 판 것. 룬 흔적은 연료가 있어야 보이므로 돌 동굴로는 못 잰다.
func _wood_cave_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.WOOD))
	g.apply(CellGrid.cmd_fill(CAVE_X0, CAVE_Y0, CAVE_X1, CAVE_Y1, Mat.EMPTY))
	return g


## 원본 탄이 착탄할 때까지(또는 `ticks`까지) 돈다.
func _run_until_impact(sim: SpellSim, grid: CellGrid, ticks: int) -> void:
	if sim.active_count() == 0:
		return
	var origin: int = sim.get_id()[0]
	for _i in ticks:
		sim.step(grid)
		if not _has_id(sim, origin):
			return


## 상자. 무대와 같은 모양이다 — 위로 쏜 탄이 허공으로 사라지지 않는다.
func _box_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, 3, Mat.STONE))
	g.apply(CellGrid.cmd_fill(0, CellGrid.H - 4, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(0, 0, 3, CellGrid.H - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(CellGrid.W - 4, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	return g
