extends Node2D
## 캐릭터 · 지팡이. 🔴 **화면만 만진다 — 캐릭터 상태를 안 바꾼다.**
##
## 🔴 **지팡이 끝의 단일 소스가 여기다.** 그림과 발사 원점이 갈라지면
##  「쏜 데서 안 나간다」로 보이고, 그건 스샷으로만 드러난다.
## ⚠ 보간이 없는 게 맞다 — 캐릭터는 60Hz(렌더와 같은 시계)라 틱 사이가 없다.
##  보간이 필요한 건 20Hz 시뮬을 그리는 `spell_view.gd`뿐이다.

const Character := preload("res://src/actor/character.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")

var _ch: Character = null

## 🔴🔴 **사본이 아니라 참조다.** 매 `_draw()`에 읽으므로 껍데기가 조합을 바꾸면 총구가
##  **저절로** 따라온다. 사본을 두면 밀어 넣기를 한 번 깜빡하는 순간 「조합을 바꿨는데
##  화면이 그대로다」가 되고 **에러가 안 난다** — 그게 v1이 죽은 방식이다.
## ⚠ **읽기만 한다.** 화면이 조립 상태를 바꾸면 그 순간 단일 소스가 아니게 된다.
var _circle: SpellCircle = null

## 몸 시트. 🔴 **경로는 `fx_tuning` 이 든다**(연출 상수는 한 파일) — 여기 문자열을 또 적으면
##  `assets/` 를 옮기는 날 한쪽만 따라오고, 그 어긋남을 잡는 그물이 **없다**(`assets/` 는 폴더 스캔 밖이다).
## ⚠ **null 검사를 안 붙인다.** 못 읽으면 `load()` 와 `draw_texture_rect_region` 이 둘 다 짖는다 —
##  조용히 `return` 하면 **캐릭터가 안 보이는데 아무도 안 짖는** 이 리포의 대표 침묵사가 된다.
var _body_tex: Texture2D = load(Fx.CHAR_SHEET)

## 🔴🔴 **「걷는 중인가」를 캐릭터에 묻지 않는다.** `character.gd` 에 그런 상태가 없고, 넣으려면
##  그 파일을 고쳐야 하는데 **화면만 만진다**가 이 파일의 계약이다.
##  ⇒ **직전 프레임의 x와 비교한다.** 뷰가 드는 상태는 이 하나뿐이다.
## ⚠ 밀려서 움직일 때도 「걷는 중」이 된다 — `fx_tuning.CHAR_WALK_PX_PER_FRAME` 주석에 적은
##  대로 알고 고른 것이다.
var _prev_x := 0
var _moving := false


func setup(ch: Character, circle: SpellCircle) -> void:
	_ch = ch
	_circle = circle
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
func aim_dir() -> Vector2:
	if _ch == null:
		return Vector2.RIGHT
	var d := get_global_mouse_position() - _ch.center()
	if d.length_squared() < 1.0:
		return Vector2(_ch.facing, 0)
	return d.normalized()


## 🔴 탄이 나가는 자리. `stage.gd`가 이걸 그대로 `aim.fire_cmd`에 넘긴다.
func tip_px() -> Vector2:
	if _ch == null:
		return Vector2.ZERO
	return _ch.center() + aim_dir() * Fx.STAFF_LEN_PX


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
	#  안 되돌리면 불 테두리·지팡이·**총구**가 뒤집힌 좌표계에서 그려진다. 총구는 조립창을 안 열고도
	#  늘 보이는 유일한 곳이라 그게 곧 조합 표시가 죽는 것이고, ⚠ **에러는 하나도 안 난다.**
	#  🔴 **그물이 이걸 못 잡는다** — 16px 때 verify-read가 복원 줄을 지워도 **전부 초록**인 것을
	#   확인했다. 지키는 것은 이 주석과 눈뿐이다.
	# 🔴🔴 **그림 칸(32px)이 충돌 상자(20px)보다 넓다 — 상자 *가운데*에 맞춰 그린다.**
	#  왼쪽 위에 맞춰 그리면 캐릭터가 상자 안에서 왼쪽으로 6px 쏠리고, 그건 「걸을 때 몸이
	#  한쪽으로 치우쳐 보인다」로만 드러난다. ⚠ 둘 다 짝수라 이 나눗셈이 정수로 떨어진다.
	#  🔴 그래서 **그림 중심과 상자 중심이 같다** — `_ch.center()` 에서 나가는 지팡이가
	#   상자를 좁힌 뒤에도 몸 한가운데에서 뻗는다.
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

	# 🔴🔴 **쓰러졌으면 여기서 끝이다 — 지팡이도 총구도 안 그린다.**
	#  **못 쏘는 상태**라 그리면 「쏠 수 있어 보인다」가 된다.
	#  ⚠ 불 테두리도 같이 빠진다 — 사각형 시절부터 그랬고 이번에 안 바꿨다.
	if _ch.downed:
		return

	# 🔴 **테두리라 무적 흐림과 겹쳐도 둘 다 보인다.** 불은 무적에 안 걸려서 그 겹침이 정상이다.
	if _ch.burning:
		draw_rect(Rect2(_ch.x, _ch.y, Character.W_PX, Character.H_PX),
			Fx.CHAR_BURN, false, Fx.CHAR_BURN_PX)
	var tip := tip_px()
	draw_line(_ch.center(), tip, Fx.STAFF_COLOR, Fx.STAFF_WIDTH_PX)

	if _circle == null:
		return

	# 🔴🔴 **총구가 장착을 나른다.** 크기 = 층 수 · 색 = 맨 안쪽 문양(`fx_tuning` 주석).
	#  ⚠ 가산 합성이 아니라 보통 합성이라(이 노드는 `spell_view`와 달리 재질이 없다)
	#   겉 무리를 알파로 깐다.
	# 🔴 매 프레임 **다시 읽는다** — 조립 상태가 바뀌는 순간이 따로 없다는 게 요점이다.
	var glyphs := _circle.packed_glyphs()
	var r := Fx.muzzle_radius(glyphs)

	# 🔴🔴 **못 쏘면 총구가 꺼진다.** 조립창을 안 열고도 늘 보이는 유일한 곳이라
	#  「지금은 못 쏜다」가 무대에서 바로 읽힌다 — 없으면 좌클릭이 안 먹는 게 **고장**으로 보인다.
	#  ⚠ 크기(층 수)는 그대로 둔다. 조합은 그대로고 **룬만 빠진 것**이라 그 사실이 보여야 한다.
	if not _circle.can_fire():
		draw_circle(tip, r, Fx.MUZZLE_DEAD, false, Fx.MUZZLE_DEAD_WIDTH_PX)
		return

	var tint := Fx.muzzle_tint(glyphs, _circle.element())
	draw_circle(tip, r * Fx.MUZZLE_GLOW_RATIO,
		Color(tint.r, tint.g, tint.b, Fx.MUZZLE_GLOW_A), true)
	draw_circle(tip, r, tint, true)
