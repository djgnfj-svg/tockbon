extends RefCounted
## 캐릭터 — 이동·중력·점프·착지·**스텝 오프셋**. 격자를 **읽기만** 한다.
##
## 🔴🔴 **`Node`가 아니라 `RefCounted`인 게 요점이다.** 캐릭터가 `Node`면 스텝 오프셋을
##  헤드리스로 못 잰다 — 판정 4(「자기가 부순 지형 위를 걸어 다니나」)가 그물로 넘어가느냐
##  눈으로만 보느냐가 여기서 갈린다.
##
## 🔴🔴 **Godot 물리(`CharacterBody2D` + 콜리전)를 쓰지 않는다.** 지형이 TileMap이 아니라 4px
##  셀 배열이라, 물리 엔진에 태우려면 **폭발마다 콜리전 셰이프를 다시 구워야 한다.**
##  폭발 하나가 셀 수백 개를 바꾸니 그게 진짜 비용이다. ⇒ 이동·착지를 직접 짜고 셀을 직접 읽는다.
##
## 🔴 **여기는 float을 써도 된다.** GDD 멀티 표가 못 박았다 — 격자·투사체는 결정론,
##  **플레이어·몬스터·아이템은 호스트 권위**다. 정수 지옥은 격자에 닿는 코드만이다.
##  ⚠ 그래서 이 파일은 `net_determinism`의 대상이 아니다. 대신 `net_layers`가
##   **`src/view/`·`src/stage/` 경로 문자열이 안 나오는 것**을 잰다.
##   🔴 그건 「화면을 참조하지 않는다」까지고, **「씬 트리를 모른다」는 아무도 안 잰다** —
##    `Input`·`Engine` 같은 전역은 preload 없이 닿으므로 경로 스캔에 안 걸린다.
##    지키는 것은 규율뿐이다. 여기에 `Input.`을 한 줄 쓰면 그물은 초록이고 서버만 죽는다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
## 🔴 통지의 좌표계(고정소수점)를 읽으려면 그 상수가 필요하다. **`src/sim/` 을 참조하는 것은
##  계약 안쪽이다** — 막히는 것은 `src/view/`·`src/stage/` 뿐이다(`net_layers`).
const SpellSim := preload("res://src/sim/spell_sim.gd")

## 캐릭터 크기. 🔴 **16px = 4셀 = 지형 타일과 정확히 같다**(GDD 격자).
##  캐릭터와 타일 두께를 같게 잡은 것이 「저 벽을 뚫으면 지나갈 수 있다」를 화면에서 세게 만드는 장치다.
const W_PX := 16
const H_PX := 16

## 🔴🔴 **스텝 오프셋 2셀(8px).** 이게 없으면 캐릭터가 **자기가 부순 4px 턱에 걸려 멈춘다.**
##  셀이 4px이라 폭발이 지나간 자리는 매끈한 바닥이 아니라 1~2셀짜리 턱이 널린 면이고,
##  이 게임에서는 그게 예외가 아니라 **기본 상태**다 — 마법을 쏘는 게 곧 지형을 부수는 것이니까.
##
## ⚠ **2셀인 이유**: 4셀(16px)로 두면 지형 타일 하나를 통째로 걸어 올라가서
##  **「저 벽을 뚫으면 지나갈 수 있다」는 위력 감각이 뭉개진다.** 1셀이면 조금만 파여도 걸린다.
## ⚠ 대신 쓸 수 있던 것(경사면 처리 · 캡슐 충돌 · 아무것도 안 함)은 기획 문서 「나중에 다시 열 것」에 있다.
const STEP_CELLS := 2
const STEP_PX := STEP_CELLS * Tuning.CELL_PX

## 🔴 손맛값이다 — 화면을 보고 정했다. 근거를 같이 적어야 다음 사람이 못 되돌린다.
##  · 이동 130px/s = 8타일/s. 960px 화면을 7.4초에 가로지른다. 「걷는다」로 읽히는 하한쯤이다
##  · 중력 1200px/s² + 점프 -360px/s ⇒ 도달 높이 v²/2g = 54px = **3.4타일**,
##    체공 0.6초. 3타일 = 캐릭터 셋을 쌓은 높이라 「저기까지 뛴다」가 눈으로 가늠된다
##  · 낙하 상한 900px/s는 프레임당 15px(4셀)로, 벽을 뚫고 지나가지 않게 하는 안전선이다
const MOVE_SPEED_PX := 130.0
const GRAVITY_PX := 1200.0
const JUMP_VY_PX := -360.0
const MAX_FALL_PX := 900.0

# ─── 체력 ─────────────────────────────────────────────────────────
## 🔴 **숫자다**(기획 「체력과 피해량」). 기준 피해 10이라 **열 대**를 맞아야 쓰러진다 —
##  한 방 죽음이면 재미가 아니라 분노라는 것이 이 값의 전부다.
const MAX_HP := 100

## 🔴 **직격과 폭발이 같은 값이다.** 기획이 정한 것은 기준선 하나뿐이고, 축을 안 늘리는 것이
##  뼈 먼저다 — ⚠ **폭발 쪽은 가정이고 사용자가 뒤집을 자리다**(계획 §4).
const DAMAGE_HIT := 10

## 🔴🔴 **타격만 걸리는 무적이다. 0.2초 = 4틱**(기획 「무적」).
##  ⚠ **불 위에 서 있는 것(지속)은 여기 안 걸린다** — 무적을 하나로 두면 불이 무해해지고,
##   그러면 「연료를 어디 두느냐가 곧 레벨 디자인」이 플레이어에게 무의미해진다.
##   ⇒ 지속 피해 경로는 이 값을 **읽지도 쓰지도 않는다**(단계 3).
const INVULN_TICKS := 4

## 불 위에 서 있으면 **초당** 이만큼 깎인다.
## ⚠ **가정이다**(계획 §4) — 「불 위 1초 = 탄 한 대」로 읽힌다. 사용자가 뒤집을 자리다.
## 🔴 **초당이라 프레임(60Hz)에서 돈다.** 비율이라 프레임이 자연스럽고, 틱에 두면
##  「한 대가 세 대」 문제가 아예 없다.
const BURN_DPS := 10.0

# ─── 밀림 · 반동 ──────────────────────────────────────────────────
## 🔴🔴 **이게 「비켜」다**(기획). 말로 비키는 게 아니라 **몸이 밀리는 것**이 상황을 만든다.
##  ⚠ **낭떠러지 보호는 없다** — 발판 끝에서도 밀리고, 밀려 떨어지는 일이 난다. 알고 고른 것이다.
##
## ⚠ **셋 다 가정이다**(계획 §4) — 기획이 「세기는 미정」으로 두었고 **사용자가 뒤집을 자리**다.
##  · 밀림 400px/s = 이동(130)의 3배. **뒤집기(반대 입력을 넣고도 변위가 남나)가 성립하는 하한**에서 나왔다
##  · 감쇠 초당 ×0.02 (τ≈0.26초) — 「탁 밀고 잦아든다」
##  · 반동 200px/s — 가로 총 변위 51px · 세로 도달 16.7px(점프의 1/3). 「공짜가 아니다」
const KB_SPEED_PX := 400.0
const KB_DECAY_PER_SEC := 0.02
const RECOIL_SPEED_PX := 200.0

## 좌상단 px. 🔴🔴 **정수다. 소수부는 `_rem_*`가 따로 들고 있는다.**
##  소수 위치로 두면 상자가 셀 경계를 반 칸 걸치고, 그러면 **착지 높이가 매번 최대 1px 달라진다** —
##  캐릭터가 지표면에서 1px 떠 있는 상태로 영원히 서 있고, 그건 그물이 「정확히 지표면」을
##  못 재게 만든다(실측: 384가 기대인데 384.0~384.99가 나왔다).
##  ⚠ 그리고 `snap_2d_transforms_to_pixel`이 켜져 있어 **어차피 화면에서는 정수로 그려진다** —
##   소수 위치는 얻는 게 하나도 없이 판정만 흐린다.
var x := 0
var y := 0
var vy := 0.0
var on_ground := false
## 마지막으로 향한 쪽(+1 오른쪽 · -1 왼쪽). 마우스가 캐릭터 위에 정확히 있을 때의 기본 방향이다.
var facing := 1

## 🔴 **정수다**(계획 §6 위험 12). float HP는 HUD도 판정도 흐린다 — 지속 피해가 붙는 날
##  누산기를 따로 들지 이 값을 소수로 만들지 마라.
var hp := MAX_HP
## 남은 무적 **틱** 수. 🔴 **화면도 이 값을 읽는다**(`character_view`의 깜빡임) —
##  깜빡임 시계를 따로 만들면 시계가 둘이 되고, 무적이 끝났는데 깜빡이는 일이 난다.
var invuln_left := 0

## 쓰러졌나(체력 0). 🔴 **즉사가 아니다** — 행동불능이 되고 **중력은 그대로 받는다**(기획 「죽음」).
##  「팀킬이 재미이려면 복구할 길이 있어야 한다」가 이 상태의 이유다.
## ⚠ **혼자일 때 부활은 R(무대 리셋)뿐이다**(계획 §4 가정) — 동료가 일으켜 주는 것은 멀티가 붙는 날이다.
## 🔴 **파생값이지 따로 드는 상태가 아니다** — `hp == 0` 과 갈라지면 「체력은 0인데 걸어 다닌다」가
##  에러 없이 난다(계획 §1이 캐릭터를 한 덩어리로 둔 이유가 이것이다).
## ⚠ **언제 진짜 상태가 되나**: 조건은 하나다 — **「쓰러졌는데 hp가 0이 아닐 수 있다」**.
##  기획의 미정 둘이 그날을 만든다: **쓰러진 채 버티는 시간**(그 동안 hp가 회복될 수 있다) ·
##  **일으켜지면 체력이 얼마인가**(부분 체력 부활). 둘 중 하나가 정해지면 게터를 버리고 상태로 바꿔라.
var downed: bool:
	get:
		return hp <= 0

## 지금 불 위에 서 있나. 🔴 **화면이 읽는다**(불붙은 캐릭터). 매 프레임 다시 판정하므로
##  「불에서 나왔는데 계속 타 보인다」가 원리적으로 없다.
var burning := false

## 🔴🔴 **가로 밀림 속도.** `vy`와 달리 **가로에는 감쇠 장치가 없어서** 새 축이 필요했다 —
##  세로는 중력이 이미 그 일을 한다(그래서 반동의 세로 성분은 `vy`에 그냥 더한다).
## 🔴 **입력과 더해지고 시간에 따라 감쇠한다**(사용자 답 4). 「막힌다」도 「서서히 되돌아온다」도 아니다.
##  ⇒ 반대 입력을 넣어도 밀림이 도는 동안에는 **입력이 즉시 이기지 않는다.**
var kb_vx := 0.0

## 🔴 아직 1이 안 된 불 피해. **`hp`를 정수로 지키는 장치다**(계획 §6 위험 12) —
##  float HP는 HUD도 판정도 흐린다.
## ⚠ **불에서 나와도 안 비운다.** 비우면 불을 톡톡 밟고 지나가는 것이 **공짜**가 되고,
##  그건 「연료를 어디 두느냐가 곧 레벨 디자인」을 갉아먹는다.
var _burn_acc := 0.0

## 방금 맞은 것이 나를 미는 쪽(단위 벡터). 🔴 **2D다**(사용자 판정, 2026-08-04) —
##  반동이 이미 2D인데 밀림만 1D면 그 비대칭에 이유가 없고, **점프와 반동이 있어 공중 피격이
##  실제로 난다.**
## 🔴 **찾는 자리에서 바로 남긴다.** 「무엇에 맞았나」와 「어느 쪽으로 밀리나」를 따로 계산하면
##  두 벌이 되고, 어긋나도 **엉뚱한 쪽으로 밀린다**는 화면에서 손맛으로만 드러난다.
var _push_dir := Vector2.ZERO

## 아직 1px이 안 된 이동분. 🔴 이게 없으면 프레임당 2.17px가 **매번 2px로 잘려**
##  실제 속도가 60px/s만큼 조용히 느려진다.
var _rem_x := 0.0
var _rem_y := 0.0


## 🔴🔴 **체력과 무적도 같이 되돌린다.** 안 되돌리면 R(무대 리셋)로 되살아나지 못한다 —
##  혼자일 때 일으켜 줄 사람이 없어서 **R이 유일한 부활**이다(계획 §4).
func place(px: int, py: int) -> void:
	x = px
	y = py
	vy = 0.0
	_rem_x = 0.0
	_rem_y = 0.0
	on_ground = false
	hp = MAX_HP
	invuln_left = 0
	burning = false
	_burn_acc = 0.0
	kb_vx = 0.0


func center() -> Vector2:
	return Vector2(x + W_PX * 0.5, y + H_PX * 0.5)


## 🔴🔴 **60Hz(`_physics_process` 매번)로 돈다 — 시뮬 20Hz에 묶지 마라.**
##  20Hz에 묶으면 조작이 뚝뚝 끊겨 재는 것 3(「손에 붙나」)이 통째로 깨진다.
##  호스트 권위라 틱에 묶일 이유가 없다(GDD 멀티 표).
func step(grid: CellGrid, dt: float, axis: float, jump: bool) -> void:
	on_ground = _grounded(grid)
	# 🔴🔴 **대입이다. 「점프 + 반동」이 기술이 되는 자리가 정확히 여기다.**
	#  같은 프레임에 쏘면 이 줄이 **반동을 지우고**, 떠오른 뒤에 쏘면 반동이 살아 남아
	#  도달 높이가 **51 → 109px(2.1배)** 가 된다(실측).
	#  🔴 **의도된 것이다**(사용자 판정, 2026-08-04) — 「**언제 쏘느냐**」가 높이를 정하는 게 손맛이다.
	#  ⚠ **더하기로 바꾸지 마라.** 버그로 읽히기 쉬운 자리라 여기 적어 둔다.
	if jump and on_ground and not downed:
		vy = JUMP_VY_PX
	vy = minf(vy + GRAVITY_PX * dt, MAX_FALL_PX)

	# 🔴🔴 **쓰러지면 입력이 죽는다. 중력·밀림은 그대로다.**
	#  ⚠ 여기서 `vy`나 `kb_vx`까지 지우면 「즉사」와 화면에서 구별이 안 된다 —
	#   쓰러진 채로 **떨어지고 밀리는 것**이 「행동불능」을 「죽음」과 가르는 유일한 표시다.
	var move := 0.0 if downed else axis
	if move != 0.0:
		facing = 1 if move > 0.0 else -1
	# 🔴 축을 나눠 푼다 — 한 번에 대각으로 밀면 모서리에서 어느 쪽이 막혔는지 알 수 없어
	#  「벽에 붙어 점프하면 가끔 통과한다」가 된다.
	# 🔴🔴 **입력과 밀림을 더한다. 덮어쓰지 않는다**(사용자 답 4) — 덮어쓰면 밀리는 동안
	#  조작이 죽고, 그러면 「막힌다」가 되어 사용자가 안 고른 쪽이 된다.
	_move_x(grid, (move * MOVE_SPEED_PX + kb_vx) * dt)
	# ⚠ **민 뒤에 감쇠한다.** 앞에서 감쇠하면 맞은 그 프레임의 밀림이 한 프레임치 깎여 나간다.
	kb_vx *= pow(KB_DECAY_PER_SEC, dt)
	if _move_y(grid, vy * dt):
		vy = 0.0
	on_ground = _grounded(grid)
	# 🔴 **다 움직인 뒤에 본다.** 앞에서 보면 「방금 떠난 자리의 불」로 깎인다.
	_burn(grid, dt)


## 🔴🔴 **불 위에 서 있으면 깎인다 — 무적을 갱신하지도, 무적에 걸리지도 않는다.**
##  이 갈래가 이 기능의 전부다(기획 「무엇이 나를 때리나」). 무적을 하나로 두면
##  **불 위에 서 있어도 안 아파지고**, 그러면 「연료를 어디 두느냐가 곧 레벨 디자인」이
##  플레이어에게 무의미해진다. ⇒ 여기는 `invuln_left`를 **읽지도 쓰지도 않는다.**
func _burn(grid: CellGrid, dt: float) -> void:
	burning = _standing_in_fire(grid)
	if not burning:
		return
	_burn_acc += BURN_DPS * dt
	var whole := floori(_burn_acc)
	if whole <= 0:
		return
	_burn_acc -= float(whole)
	hp = maxi(0, hp - whole)


## 🔴🔴 **발밑 한 줄을 같이 본다. 이 한 줄이 이 기능의 목숨이다.**
##  캐릭터가 서 있는 자리의 셀들은 **빈칸이라 연료가 0**이고, 불은 **발밑 나무 셀**에 붙어 있다.
##  ⚠ 빠뜨리면 코드는 돌고 그물도 짤 수 있는데 **게임에서만 아무 일이 안 난다.**
## 🔴 범위가 `_grounded`가 보는 줄과 같다 — 「밟고 있다」의 뜻이 두 벌이 되지 않는다.
func _standing_in_fire(grid: CellGrid) -> bool:
	var cx0 := floori(x / float(Tuning.CELL_PX))
	var cx1 := floori((x + W_PX - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(y / float(Tuning.CELL_PX))
	var cy1 := floori((y + H_PX) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			# 🔴 **「타나」는 격자에 물어본다** — 여기서 깃발을 직접 까면 규칙이 두 벌이 된다.
			if grid.is_burning(cx, cy):
				return true
	return false


# ══════════════════════════════════════════════════════════════════
#  맞았나 — 🔴🔴 **두 세계가 만나는 자리다**
# ══════════════════════════════════════════════════════════════════
# 시뮬(`src/sim/`)은 캐릭터를 **모른다.** 여기가 시뮬의 통지를 **읽기만** 해서 판정한다.
# ⚠ 거꾸로 하면(시뮬이 캐릭터를 알면) 결정론이 호스트 권위 위치에 묶여 **클라마다 격자가
#  갈라진다** — 에러는 안 나고 「멀티에서 지형이 서로 다르게 보인다」로만 드러난다(GDD).

## 🔴🔴 **틱에서만 돈다.** 60Hz에서 부르면 **한 대가 세 대가 된다** — 통지 배열은
##  `spell.step()` 시작에서만 지워지므로 틱 사이 세 프레임 동안 같은 값이 남아 있다.
##  ⚠ 무적이 두 대를 먹어서 **화면에서는 정상으로 보이고**, 무적과 무관한 지속 피해에서만
##   3배가 드러난다. ⇒ 입구는 `world_step.frame()` 의 **틱 갈래 안** 하나뿐이다.
##
## ⚠ **격자를 안 받는다.** 지금 이 판정에 격자가 필요 없고(지속 피해는 `step()`의 몫이다),
##  안 쓰는 인자는 「여기서 지형을 본다」는 거짓 손잡이가 된다.
func on_tick(spell: SpellSim) -> void:
	# ① 무적이면 아무것도 안 한다. 🔴 이 갈래가 판정 3-②의 전부다 —
	#  맞은 틱에 4를 채우고 다음 4틱을 이 줄이 먹는다(3틱 간격 = 한 대 · 5틱 간격 = 두 대).
	if invuln_left > 0:
		invuln_left -= 1
		return
	# ②③ 구간(직격)과 폭발. 🔴 **하나라도 맞으면 거기서 끝이다** —
	#  그게 판정 3-①(같은 틱에 폭발 둘을 맞아도 한 대)이다.
	if not (_hit_by_segment(spell) or _hit_by_blast(spell)):
		return
	# ④ hp는 0 아래로 안 내려간다(계획 §4).
	hp = maxi(0, hp - DAMAGE_HIT)
	invuln_left = INVULN_TICKS
	# 🔴 **맞은 것과 같은 자리에서 민다.** ⚠ 무적 중에는 위에서 돌아갔으므로 **피해도 밀림도 없다** —
	#  「한 대」가 한 대여야 한다.
	# ⚠ **가로는 대입, 세로는 덧셈**이다. `kb_vx`는 밀림 전용 축이라 「탁 밀린다」가 곧 대입이고,
	#  `vy`는 중력·점프와 **함께 쓰는 축**이라 덮어쓰면 그 둘을 지운다(반동도 같은 어법이다).
	if _push_dir != Vector2.ZERO:
		kb_vx = _push_dir.x * KB_SPEED_PX
		vy += _push_dir.y * KB_SPEED_PX


## 🔴 **쏘면 밀린다**(GDD 자연법칙). `world_step` 이 **`fire()` 가 참을 준 뒤에** 부른다 —
##  큐에 넣는 시점에 걸면 **거부된 발사에도 밀려서** 「안 나갔는데 밀린다」가 된다.
##
## 🔴🔴 **2D다. 아래로 쏘면 위로 뜬다** — 그게 GDD의 로켓점프이고, 자기 폭발에 맞는 것이 확정이라
##  **밀리면서 동시에 아프다.** 「위험과 기동이 같은 행동에서 나온다」가 이 조합의 값어치다.
## ⚠ 세로는 `vy`에 더한다 — 거기엔 이미 감쇠 장치(중력)가 있다.
func recoil(adx: int, ady: int) -> void:
	var d := _unit(float(adx), float(ady))
	kb_vx -= d.x * RECOIL_SPEED_PX
	vy -= d.y * RECOIL_SPEED_PX


## 단위 벡터. ⚠ **0벡터는 0으로 돌려준다** — 정규화하면 0으로 나눈다.
##  (조준 0벡터는 `spell_sim.fire()`도 조용히 버리는 정상 입력이다.)
static func _unit(dx: float, dy: float) -> Vector2:
	var d := Vector2(dx, dy)
	if d.length_squared() <= 0.0:
		return Vector2.ZERO
	return d.normalized()


## 🔴🔴 **선분 대 상자다. 사각형 대 사각형이 아니다.**
##  세대 0 탄은 틱당 40px을 뛰고 상자는 16px이라, 틱 경계 위치만 맞대면 **도약이 상자를
##  통째로 넘는다.** 한 프레임이라 눈으로 절대 못 본다(기획 「직격은 매 틱 사각형 겹침으로
##  재면 조용히 안 걸린다」).
func _hit_by_segment(spell: SpellSim) -> bool:
	var x0 := spell.get_seg_x0()
	var y0 := spell.get_seg_y0()
	var x1 := spell.get_seg_x1()
	var y1 := spell.get_seg_y1()
	for i in spell.seg_count():
		if _seg_hits_box(_fp_px(x0[i]), _fp_px(y0[i]), _fp_px(x1[i]), _fp_px(y1[i])):
			# 🔴 **탄이 가던 쪽으로** 민다 — 기획 「탄이 온 쪽에서 반대로」.
			#  ⚠ 반동과 **같은 어법**으로 정규화한다. 축마다 따로 부호만 쓰면 대각으로 맞을 때
			#   총 세기가 √2배가 되어 「대각선이 유난히 세다」가 된다.
			_push_dir = _unit(float(x1[i] - x0[i]), float(y1[i] - y0[i]))
			return true
	return false


## 🔴 **반경은 통지에 안 실려 있다** — 액터가 `Tuning.blast_rd(gen)` 을 읽는다.
##  실어 보내면 같은 값이 두 곳이 되고, 표를 고치는 날 한쪽만 따라온다.
func _hit_by_blast(spell: SpellSim) -> bool:
	var bx := spell.get_blast_x()
	var by := spell.get_blast_y()
	var bg := spell.get_blast_gen()
	for i in spell.blast_count():
		var r := float(Tuning.blast_rd(bg[i]) * Tuning.CELL_PX)
		if _circle_hits_box(_cell_px(bx[i]), _cell_px(by[i]), r):
			# 🔴🔴 **터진 자리에서 *멀어지는* 쪽이다.** 부호를 뒤집으면 폭발이 **빨아들이고**,
			#  그러면 기획의 「비켜」가 「빨려든다」가 된다. ⚠ 화면으로는 못 가른다 —
			#  밀렸든 빨려들었든 둘 다 「움직였다」로 보인다. ⇒ 그물이 부호를 잰다.
			# ⚠ 정확히 한가운데면 0이다 — 그때는 어느 쪽도 「맞다」고 할 수 없다.
			var c := center()
			_push_dir = _unit(c.x - _cell_px(bx[i]), c.y - _cell_px(by[i]))
			return true
	return false


## 🔴🔴 **좌표 변환은 이 함수 하나다.** 통지는 셀 고정소수점이고 캐릭터는 px다 —
##  두 곳에서 바꾸면 한쪽만 고치는 날이 오고, 그 어긋남은 「가끔 안 맞는다」로만 보인다.
static func _fp_px(fp: int) -> float:
	return float(fp) * Tuning.CELL_PX / SpellSim.FP_ONE


## 셀 번호 → 그 셀 **한가운데**의 px. 🔴 위 함수를 지나므로 규칙이 한 벌이다.
static func _cell_px(c: int) -> float:
	return _fp_px((c << SpellSim.FP_SHIFT) + SpellSim.FP_HALF)


## 선분(a→b) 대 상자. ⚠ **시작점이 상자 안이면 참이다** — 상자 안에서 태어난 탄도 잡힌다.
func _seg_hits_box(ax: float, ay: float, bx: float, by: float) -> bool:
	var rng := Vector2(0.0, 1.0)
	rng = _slab(rng, ax, bx - ax, float(x), float(x + W_PX))
	rng = _slab(rng, ay, by - ay, float(y), float(y + H_PX))
	return rng.x <= rng.y


## 한 축의 슬랩. 살아 있는 구간 `(lo, hi)`를 좁혀서 돌려준다.
## 🔴 **축을 함수 하나로 묶은 이유**: 두 축을 따로 쓰면 한쪽만 고치는 날이 오고,
##  그러면 「세로로 날아오는 탄만 안 맞는다」가 된다.
## ⚠ 축과 나란한 선분(d ≈ 0)은 나눗셈이 아니라 **범위 안에 있나**로 갈린다.
static func _slab(rng: Vector2, a: float, d: float, e0: float, e1: float) -> Vector2:
	if is_zero_approx(d):
		return rng if (a >= e0 and a <= e1) else Vector2(1.0, 0.0)
	var t0 := (e0 - a) / d
	var t1 := (e1 - a) / d
	return Vector2(maxf(rng.x, minf(t0, t1)), minf(rng.y, maxf(t0, t1)))


## 원 대 상자 — 상자에서 원 중심에 **제일 가까운 점**까지의 거리로 본다.
func _circle_hits_box(cx: float, cy: float, r: float) -> bool:
	var dx := cx - clampf(cx, float(x), float(x + W_PX))
	var dy := cy - clampf(cy, float(y), float(y + H_PX))
	return dx * dx + dy * dy <= r * r


## 수평. 막히면 **스텝 오프셋**을 시도한다.
## ⚠ 막히면 나머지를 **버린다** — 안 들고 있으면 벽에 붙어 있는 동안 나머지가 쌓였다가
##  벽이 사라지는 순간 캐릭터가 몇 px 순간이동한다.
func _move_x(grid: CellGrid, dx: float) -> void:
	_rem_x += dx
	var n := roundi(_rem_x)
	_rem_x -= n
	if n == 0:
		return
	var sgn := signi(n)
	# 🔴 1px씩 민다 — 한 번에 밀고 되돌리는 방식은 두꺼운 벽에서 「어디까지 갈 수 있었나」를 잃는다.
	for _i in absi(n):
		if _box_free(grid, x + sgn, y):
			x += sgn
			continue
		if not _try_step_up(grid, sgn):
			_rem_x = 0.0
			return


## 🔴 **공중에서는 안 된다.** 안 그러면 벽에 붙어 있는 동안 턱이 아니라 벽을 타고 오른다.
## ⚠ 올라갈 자리(`y - lift`)가 비어 있는지도 같이 본다 — 천장 아래 좁은 틈에서
##  머리를 박고 올라가면 캐릭터가 지형에 끼인다.
func _try_step_up(grid: CellGrid, dx: int) -> bool:
	if not on_ground:
		return false
	for lift in range(1, STEP_PX + 1):
		if _box_free(grid, x, y - lift) and _box_free(grid, x + dx, y - lift):
			x += dx
			y -= lift
			return true
	return false


## 수직. 막혔으면 true(호출부가 `vy`를 0으로 만든다).
func _move_y(grid: CellGrid, dy: float) -> bool:
	_rem_y += dy
	var n := roundi(_rem_y)
	_rem_y -= n
	if n == 0:
		return false
	var sgn := signi(n)
	for _i in absi(n):
		if not _box_free(grid, x, y + sgn):
			_rem_y = 0.0
			return true
		y += sgn
	return false


func _grounded(grid: CellGrid) -> bool:
	return not _box_free(grid, x, y + 1)


## 🔴 **「고체인가」는 격자에 물어본다**(`grid.is_solid`). 여기서 `mat_at() != EMPTY`로 다시
##  판정하면 규칙이 두 벌이 되고, 재료가 늘 때 「탄은 뚫는데 캐릭터는 막힌다」가 된다.
## ⚠ 상자가 덮는 마지막 픽셀은 `px + W_PX - 1`이다. `- 1`을 빼면 경계에 딱 붙었을 때
##  옆 칸을 한 줄 더 읽어 **벽에서 1px 떠서 멈춘다.**
## ⚠ 음수 나눗셈은 GDScript에서 0 쪽으로 잘린다(`-1 / 4 == 0`) — 격자 왼쪽·위 밖에서
##  셀 좌표가 한 칸 튄다. `floori`로 내림을 강제한다.
func _box_free(grid: CellGrid, px: int, py: int) -> bool:
	var cx0 := floori(px / float(Tuning.CELL_PX))
	var cx1 := floori((px + W_PX - 1) / float(Tuning.CELL_PX))
	var cy0 := floori(py / float(Tuning.CELL_PX))
	var cy1 := floori((py + H_PX - 1) / float(Tuning.CELL_PX))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if grid.is_solid(cx, cy):
				return false
	return true
