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


func setup(ch: Character, circle: SpellCircle) -> void:
	_ch = ch
	_circle = circle
	queue_redraw()


func _process(_dt: float) -> void:
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


func _draw() -> void:
	if _ch == null:
		return
	# 🔴🔴 **깜빡임의 시계가 `invuln_left` 자체다.** 틱마다 한 칸 줄므로 홀짝만 봐도
	#  0.2초 동안 두 번 깜빡인다 — 여기서 `delta`를 누산하면 그 순간 시계가 둘이 되고,
	#  무적이 끝났는데 깜빡이는 일이 난다. ⚠ **읽기만 한다**(이 파일 첫 줄).
	var dim := 1.0 if (_ch.invuln_left & 1) == 0 else Fx.INVULN_DIM_A

	# 🔴🔴 **쓰러지면 실루엣이 통째로 바뀐다** — 눕힌 납작한 상자다. 색만 바꾸면 무적 흐림·불
	#  테두리와 같은 축을 써서 셋이 겹칠 때 못 가른다. ⚠ 지팡이도 총구도 안 그린다 —
	#  **못 쏘는 상태**라 그리면 「쏠 수 있어 보인다」가 된다.
	if _ch.downed:
		var h := Character.W_PX * Fx.CHAR_DOWN_H_RATIO
		draw_rect(Rect2(_ch.x, _ch.y + Character.H_PX - h, Character.W_PX, h),
			Fx.CHAR_DOWN, true)
		return

	var body := Fx.CHAR_BODY
	var trim := Fx.CHAR_TRIM
	body.a *= dim
	trim.a *= dim
	draw_rect(Rect2(_ch.x, _ch.y, Character.W_PX, Character.H_PX), body, true)
	draw_rect(Rect2(
		_ch.x, _ch.y + Character.H_PX - Fx.CHAR_TRIM_PX,
		Character.W_PX, Fx.CHAR_TRIM_PX), trim, true)
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
