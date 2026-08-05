extends Node2D
## 캐릭터 · 지팡이. 🔴 **화면만 만진다 — 캐릭터 상태를 안 바꾼다.**
##
## 🔴🔴 **지팡이 끝의 단일 소스는 이제 여기가 아니라 `src/actor/staff.gd` 다.**
##  그림과 발사 원점이 갈라지면 「쏜 데서 안 나간다」로 보이고 그건 스샷으로만 드러난다 —
##  ⇒ **여기서 끝을 다시 계산하지 마라.** 아래 `tip_px()` 는 그 함수를 **부르기만** 한다.
## ⚠ 보간이 없는 게 맞다 — 캐릭터는 60Hz(렌더와 같은 시계)라 틱 사이가 없다.
##  보간이 필요한 건 20Hz 시뮬을 그리는 `spell_view.gd`뿐이다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Character := preload("res://src/actor/character.gd")
const Staff := preload("res://src/actor/staff.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")

var _ch: Character = null

## 🔴🔴 **지팡이가 지형에 막혀 짧아지므로 화면이 격자를 든다. 읽기만 한다.**
##  ⚠ **이걸 안 받으면 화면은 옛 자리에 그리고 발사만 새 자리로 간다** — 셋이 하나라는
##   계약이 그 자리에서 깨지고 **에러가 하나도 안 난다.** 그래서 `setup()` 의 인자다.
var _grid: CellGrid = null

## 🔴🔴 **사본이 아니라 참조다.** 매 `_draw()`에 읽으므로 껍데기가 조합을 바꾸면 지팡이 끝 색이
##  **저절로** 따라온다. 사본을 두면 밀어 넣기를 한 번 깜빡하는 순간 「조합을 바꿨는데
##  화면이 그대로다」가 되고 **에러가 안 난다** — 그게 v1이 죽은 방식이다.
## ⚠ **읽기만 한다.** 화면이 조립 상태를 바꾸면 그 순간 단일 소스가 아니게 된다.
var _circle: SpellCircle = null

## 몸 시트. 🔴 **경로는 `fx_tuning` 이 든다**(연출 상수는 한 파일) — 여기 문자열을 또 적으면
##  `assets/` 를 옮기는 날 한쪽만 따라오고, 그 어긋남을 잡는 그물이 **없다**(`assets/` 는 폴더 스캔 밖이다).
## ⚠ **null 검사를 안 붙인다.** 못 읽으면 `load()` 와 `draw_texture_rect_region` 이 둘 다 짖는다 —
##  조용히 `return` 하면 **캐릭터가 안 보이는데 아무도 안 짖는** 이 리포의 대표 침묵사가 된다.
var _body_tex: Texture2D = load(Fx.CHAR_SHEET)

## 지팡이 시트. ⚠ **`_body_tex` 와 같은 어법이다 — null 검사를 안 붙인다**(위 근거 그대로).
var _staff_tex: Texture2D = load(Fx.STAFF_SHEET)

## 🔴🔴 **「걷는 중인가」를 캐릭터에 묻지 않는다.** `character.gd` 에 그런 상태가 없고, 넣으려면
##  그 파일을 고쳐야 하는데 **화면만 만진다**가 이 파일의 계약이다.
##  ⇒ **직전 프레임의 x와 비교한다.** 뷰가 드는 상태는 이 하나뿐이다.
## ⚠ 밀려서 움직일 때도 「걷는 중」이 된다 — `fx_tuning.CHAR_WALK_PX_PER_FRAME` 주석에 적은
##  대로 알고 고른 것이다.
var _prev_x := 0
var _moving := false


func setup(ch: Character, circle: SpellCircle, grid: CellGrid) -> void:
	_ch = ch
	_circle = circle
	_grid = grid
	# ⚠ **여기서 `_prev_x` 를 맞춰 둔다.** 안 맞추면 첫 프레임에 「0 → 스폰 x」 가 움직임으로 읽혀
	#  가만히 선 캐릭터가 한 프레임 걷는다.
	if _ch != null:
		_prev_x = _ch.x
	queue_redraw()


func _process(_dt: float) -> void:
	# 🔴🔴 **걷기 시계를 따로 만들지 않는다.** 「움직였나」도 「몇 번째 칸인가」도 전부 `_ch.x` 에서
	#  나온다 — `delta` 를 누산하면 그 순간 시계가 둘이 되고 **「멈췄는데 다리가 움직인다」**가 난다.
	#  ⚠ `_process` 는 프레임당 한 번이고 `_draw` 는 그 뒤에 온다 ⇒ 여기가 갱신 자리다.
	if _ch != null:
		_moving = _ch.x != _prev_x
		_prev_x = _ch.x
	# 캐릭터가 매 프레임 움직이고 지팡이가 매 프레임 마우스를 따라간다 ⇒ 늘 다시 그린다.
	queue_redraw()


## 마우스 쪽 단위 벡터. 마우스가 정확히 캐릭터 한가운데면 **바라보는 쪽**으로 떨어진다
## (0벡터를 정규화하면 0이 되고, 그러면 지팡이가 사라진다).
##
## ⚠ **기준이 상자 중심이지 지팡이 피벗이 아니다.** 피벗이 중심에서 `PIVOT_DY_PX` 만큼 아래라
##  둘이 그만큼 어긋나는데, **이번 변경에서 안 건드렸다** — 기획이 손 높이를 「미정」으로 뒀고
##  값이 정해지기 전에 기준을 옮기면 무엇 때문에 조준이 달라졌는지 갈리지 않는다.
##  🔴 손 높이를 눈으로 정하는 날 **여기를 같이 봐라.** 마우스가 캐릭터에 붙어 있을 때 제일 크게 보인다.
func aim_dir() -> Vector2:
	if _ch == null:
		return Vector2.RIGHT
	var d := get_global_mouse_position() - _ch.center()
	if d.length_squared() < 1.0:
		return Vector2(_ch.facing, 0)
	return d.normalized()


## 🔴 탄이 나가는 자리. `stage.gd`가 이걸 그대로 `aim.fire_cmd`에 넘긴다.
##
## 🔴🔴 **계산은 `Staff.tip_px()` 에 있다 — 여기서 다시 하지 마라.** 그리는 쪽(`_draw`)도
##  같은 함수를 부르므로 「그림 끝 · 발사 원점」이 **구조적으로** 같은 값이다.
##  ⚠ 여기서 한 줄이라도 다시 계산하면 그 순간 둘이 갈라질 수 있고, **에러는 안 난다.**
## 🔴 **`_grid` 에 null 검사를 안 붙인다.** 껍데기가 격자를 안 넘기면 여기서 **짖어야** 한다 —
##  조용히 옛 자리를 돌려주면 「화면은 옛 자리, 발사는 새 자리」가 **아무 에러 없이** 남고,
##  그게 이 문서의 위험 2다(`_body_tex` 에 null 검사를 안 붙인 것과 같은 규율).
func tip_px() -> Vector2:
	if _ch == null:
		return Vector2.ZERO
	return Staff.tip_px(_grid, _ch.x, _ch.y, aim_dir())


## 🔴🔴 **어느 칸을 그릴지 고른다. 순수 static 이라 그물이 직접 부를 수 있다.**
##  ⚠ 이게 **판정 3(걷기·점프·낙하 구별)과 4(쓰러짐)를 눈에서 그물로 옮기는 자리**다 —
##   씬도 캐릭터도 없이 조합을 넣고 칸 번호를 받아 볼 수 있다.
##
## 🔴🔴 **그래도 그물이 재는 것은 「코드가 다른 칸을 고른다」까지다.**
##  **여섯 칸을 전부 똑같이 그려도 그물은 초록이다** — 「그 칸의 그림이 실제로 다르다」는
##  원리적으로 눈만 잰다(계획 §7.2). 라벨을 거기까지 넓히지 마라.
##
## 우선순위가 계약이다:
##  ① **쓰러짐이 무엇보다 먼저다** — 쓰러진 채로 떨어지는 중이라도 「쓰러졌다」가 보여야
##    「살려야 한다」를 아무도 못 놓친다
##  ② 공중 — 올라가는 중과 떨어지는 중이 갈려야 점프가 화면에서 읽힌다
##  ③ 걷는 중 · 그밖에
## ⚠ `vy == 0` 인 공중은 **낙하**로 떨어진다(정점의 한 순간이라 어느 쪽이든 되지만 갈래를 하나로 둔다).
static func pick_state(downed: bool, on_ground: bool, vy: float, moving: bool) -> int:
	if downed:
		return Fx.CHAR_DOWNED
	if not on_ground:
		return Fx.CHAR_JUMP if vy < 0.0 else Fx.CHAR_FALL
	return Fx.CHAR_WALK if moving else Fx.CHAR_STAND


## 상태 → 시트에서 잘라 올 칸. 🔴 **표(`Fx.CHAR_FRAMES`)가 단일 소스다** — 여기서 칸 번호를
##  계산하면 「표를 고쳤는데 화면이 그대로다」가 난다.
## 🔴 **여러 칸짜리 상태(걷기)의 시계가 `_ch.x` 다.** `CHAR_WALK_PX_PER_FRAME` 마다 한 칸 넘어간다 —
##  ⚠ `absi` 인 이유: 왼쪽으로 걸으면 x가 줄고, 음수 나눗셈이 0 쪽으로 잘려 **좌우가 비대칭**이 된다.
## 🔴 없는 상태를 물으면 **여기서 짖는다.** `get`으로 덮으면 표를 빠뜨린 상태가 조용히 0번 칸을 쓴다.
func _cell_rect(state: int) -> Rect2:
	var cells: Array = Fx.CHAR_FRAMES[state]
	var idx := 0
	if cells.size() > 1:
		idx = (absi(_ch.x) / Fx.CHAR_WALK_PX_PER_FRAME) % cells.size()
	# 🔴🔴 **시트 안 좌표다 — `Fx.CHAR_CELL_PX` 를 쓴다. `Character.W_PX` 가 아니다.**
	#  상자가 20px으로 좁아진 뒤로 둘이 다른 값이고, 여기에 `W_PX` 를 쓰면 시트를 20px 단위로
	#  잘라 **엉뚱한 칸의 조각**을 그린다. ⚠ 에러가 하나도 안 난다.
	return Rect2(int(cells[idx]) * Fx.CHAR_CELL_PX, 0, Fx.CHAR_CELL_PX, Fx.CHAR_CELL_PX)


func _draw() -> void:
	if _ch == null:
		return
	# 🔴🔴 **깜빡임의 시계가 `invuln_left` 자체다.** 틱마다 한 칸 줄므로 홀짝만 봐도
	#  0.2초 동안 두 번 깜빡인다 — 여기서 `delta`를 누산하면 그 순간 시계가 둘이 되고,
	#  무적이 끝났는데 깜빡이는 일이 난다. ⚠ **읽기만 한다**(이 파일 첫 줄).
	var dim := 1.0 if (_ch.invuln_left & 1) == 0 else Fx.INVULN_DIM_A

	# 🔴🔴 **어느 칸을 그리나 — 갈래는 `pick_state()` 하나뿐이다.** 여기서 조건을 또 쓰면
	#  화면과 그물이 서로 다른 규칙을 보게 된다(그물은 그 함수를 직접 부른다).
	var state := pick_state(_ch.downed, _ch.on_ground, _ch.vy, _moving)

	# 🔴🔴 **좌우는 한 벌 + 코드 반전이다.** 두 벌을 손으로 그리면 한쪽만 고치는 날이 오고,
	#  그 어긋남은 **왼쪽을 볼 때만** 드러나 눈으로 거의 못 잡는다. 반전은 그 갈라짐이 원리적으로 없다.
	#  ⚠ 그림이 4분의 3 각도라 반전이 **거울상**이 된다 — 알고 고른 것이다(기획 「몸은 좌우 두 벌」).
	# 🔴🔴 **`draw_set_transform` 은 뒤에 그리는 것 전부에 걸린다 — 반드시 되돌린다.**
	#  안 되돌리면 불 테두리·지팡이·**끝의 고리**가 뒤집힌 좌표계에서 그려진다. 지팡이 끝은
	#  조립창을 안 열고도 늘 보이는 유일한 곳이라 그게 곧 조합 표시가 죽는 것이고,
	#  ⚠ **에러는 하나도 안 난다.**
	#  🔴 **그물이 이걸 못 잡는다** — 16px 때 verify-read가 복원 줄을 지워도 **전부 초록**인 것을
	#   확인했다. 지키는 것은 이 주석과 눈뿐이다.
	# 🔴🔴 **그림 칸(32px)이 충돌 상자(20px)보다 넓다 — 상자 *가운데*에 맞춰 그린다.**
	#  왼쪽 위에 맞춰 그리면 캐릭터가 상자 안에서 왼쪽으로 6px 쏠리고, 그건 「걸을 때 몸이
	#  한쪽으로 치우쳐 보인다」로만 드러난다. ⚠ 둘 다 짝수라 이 나눗셈이 정수로 떨어진다.
	#  🔴 그래서 **그림 중심과 상자 중심이 같다** — `Staff.pivot_px()` 가 상자에서 나오는데
	#   상자를 좁힌 뒤에도 그 자리가 몸 그림의 한가운데다.
	var pad := (Fx.CHAR_CELL_PX - Character.W_PX) / 2
	var sprite_x := _ch.x - pad
	# ⚠ 왼쪽을 볼 때 원점을 **그림** 오른쪽 끝에 두는 이유: 스케일 -1이 로컬 x를 왼쪽으로 보내므로
	#  거기서 시작해야 그림이 같은 자리에 정확히 앉는다. **상자 끝이 아니라 그림 끝이다** —
	#  상자를 쓰면 방향을 바꿀 때마다 캐릭터가 `pad` 의 두 배(12px)만큼 튄다.
	#  🔴 그리고 그림 쪽 조건은 **`minx + maxx == CHAR_CELL_PX − 1`** 이다 — `net_sprite` 가 잰다.
	var flip := _ch.facing < 0
	draw_set_transform(
		Vector2(sprite_x + (Fx.CHAR_CELL_PX if flip else 0), _ch.y),
		0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect_region(_body_tex,
		Rect2(0.0, 0.0, Fx.CHAR_CELL_PX, Fx.CHAR_CELL_PX),
		_cell_rect(state), Color(1.0, 1.0, 1.0, dim))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 🔴🔴 **쓰러졌으면 여기서 끝이다 — 지팡이도 끝의 고리도 안 그린다.**
	#  **못 쏘는 상태**라 그리면 「쏠 수 있어 보인다」가 된다.
	#  ⚠ 불 테두리도 같이 빠진다 — 사각형 시절부터 그랬고 이번에 안 바꿨다.
	if _ch.downed:
		return

	# 🔴 **테두리라 무적 흐림과 겹쳐도 둘 다 보인다.** 불은 무적에 안 걸려서 그 겹침이 정상이다.
	if _ch.burning:
		draw_rect(Rect2(_ch.x, _ch.y, Character.W_PX, Character.H_PX),
			Fx.CHAR_BURN, false, Fx.CHAR_BURN_PX)
	# 🔴🔴 **피벗도 끝도 `Staff` 에서 나온다.** 여기서 `_ch.center()` 로 그리면 그리는 자리와
	#  발사 자리가 갈라지고, 그건 스샷으로만 드러난다.
	# ⚠ `aim_dir()` 을 두 번 부른다(여기 · `tip_px()` 안). **한 프레임 안에서 같은 값이라 안전하다** —
	#  마우스 자리는 프레임 동안 안 변한다. 🔴 `aim_dir()` 에 상태를 넣지 마라. 넣는 순간 그리는
	#  방향과 끝이 갈라지고, 그건 「지팡이가 살짝 휘어 보인다」로만 드러난다.
	var pivot := Staff.pivot_px(_ch.x, _ch.y)
	var tip := tip_px()
	var dir := aim_dir()
	_draw_staff(pivot, dir, (tip - pivot).length())

	if _circle == null:
		return

	# 🔴🔴 **끝의 고리가 장착을 나른다 — 색 하나로.** 총구 구슬(크기 = 층 수)은 사용자 판정으로
	#  지웠고, 무엇을 잃었는지는 `fx_tuning.STAFF_RING_*` 절에 적혀 있다.
	#
	# 🔴🔴 **월드 좌표계다 — 위 `_draw_staff` 가 변환을 되돌린 뒤여야 한다.**
	#  `tip` 이 이미 월드 px라 그게 자연스럽고, **복원 줄이 어디에 있어야 하는지가 코드 모양으로
	#  드러난다.** ⚠ 안 되돌리면 링이 엉뚱한 데 앉는데 **에러가 안 나고 그물도 못 잡는다.**
	#
	# 🔴 **링은 그림의 고리 위에 정확히 겹친다.** 끝에서 `INSET` 만큼 되돌아온 자리가 고리 중심이다
	#  (실측: 끝 36.0 · 고리 중심 x 32.0). ⚠ **자리 맞춤은 눈이 볼 자리다.**
	# 🔴 매 프레임 **다시 읽는다** — 조립 상태가 바뀌는 순간이 따로 없다는 게 요점이다.
	# ⚠ **「못 쏜다」 갈래는 `staff_tint` 안에 있다.** 여기서 가르면 그 갈래가 그물이 못 부르는
	#  자리로 내려가고, 그러면 판정 5가 눈에만 남는다.
	draw_circle(tip - dir * Fx.STAFF_RING_INSET_PX, Fx.STAFF_RING_R_PX,
		Fx.staff_tint(_circle.packed_glyphs(), _circle.element(), _circle.can_fire()),
		false, Fx.STAFF_RING_PX)


## 🔴🔴 **봉과 고리를 따로 그린다. 통째로 x축 스케일하면 안 된다.**
##  지팡이가 눌리면 길이가 `LEN_PX` 보다 짧아지는데, 그림을 통째로 늘리면 **고리가 타원으로
##  찌그러지고** 그 위에 얹을 색 링(정원)이 안 맞는다. ⇒ **봉만 줄이고 고리는 1:1로 끝에 붙인다.**
##  ⚠ 봉이 짧아지고 고리는 그대로인 것이 「벽에 다가가면 눌려 짧아진다」의 정직한 그림이다(판정 2).
##
## 🔴🔴 **`draw_set_transform` 은 뒤에 그리는 것 전부에 걸린다 — 반드시 되돌린다.**
##  안 되돌리면 뒤따르는 것(고리 색 링 · 다음 프레임)이 회전 좌표계에서 그려진다.
##  **에러는 하나도 안 난다.** 🔴 **그물이 이걸 못 잡는다** — 위 몸 그림 쪽에 실측이 적혀 있다.
##  지키는 것은 이 주석과 눈뿐이다.
##
## ⚠ **세로는 시트에서 읽는다**(`get_height()`). 상수로 박으면 「png 높이 · 상수」가 두 곳이 되고,
##  갈라지면 지팡이가 세로로 늘어나는데 에러가 안 난다.
## 🔴 **가로 기준은 `Staff.LEN_PX` 하나다** — `fx_tuning` 에 폭 상수를 또 두지 않는 이유가 그것이다.
func _draw_staff(pivot: Vector2, dir: Vector2, len_px: float) -> void:
	var sheet_h := float(_staff_tex.get_height())
	var ring := Fx.STAFF_RING_W_PX
	var rod := Staff.LEN_PX - ring
	# ⚠ 회전 좌표계다 — 원점이 피벗이고 +x 가 조준 방향이다. 그래서 아래 두 사각형이
	#  「피벗에서 얼마나 나갔나」로만 적힌다.
	draw_set_transform(pivot, dir.angle(), Vector2.ONE)
	# ① 봉 — 남은 길이에 맞춰 **가로로만** 줄인다. ⚠ `maxf` 는 지팡이가 고리보다 짧아지는
	#  극단(하한이 `ring` 보다 작은 상자)에서 폭이 음수가 되는 것을 막는다.
	draw_texture_rect_region(_staff_tex,
		Rect2(0.0, -Fx.STAFF_ANCHOR_Y_PX, maxf(0.0, len_px - ring), sheet_h),
		Rect2(0.0, 0.0, rod, sheet_h))
	# ② 고리 — **1:1이다.** 끝에 붙는다.
	draw_texture_rect_region(_staff_tex,
		Rect2(len_px - ring, -Fx.STAFF_ANCHOR_Y_PX, ring, sheet_h),
		Rect2(rod, 0.0, ring, sheet_h))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
