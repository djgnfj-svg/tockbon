extends Node2D
## 캐릭터 · 지팡이. 🔴 **화면만 만진다 — 캐릭터 상태를 안 바꾼다.**
##
## 🔴 **지팡이 끝의 단일 소스가 여기다.** 그림과 발사 원점이 갈라지면
##  「쏜 데서 안 나간다」로 보이고, 그건 스샷으로만 드러난다.
## ⚠ 보간이 없는 게 맞다 — 캐릭터는 60Hz(렌더와 같은 시계)라 틱 사이가 없다.
##  보간이 필요한 건 20Hz 시뮬을 그리는 `spell_view.gd`뿐이다.

const Character := preload("res://src/actor/character.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

var _ch: Character = null

## 🔴 지금 장착된 것. 껍데기가 조합을 바꿀 때 밀어 넣는다.
##  ⚠ **화면 전용 사본이다** — 발사 커맨드는 껍데기가 자기 값으로 만든다. 여기서 되돌려 주지 않는다.
var loadout_glyphs := Glyph.GLYPH_NONE
var loadout_element := Tuning.ELEM_FIRE


func setup(ch: Character) -> void:
	_ch = ch
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
	draw_rect(Rect2(_ch.x, _ch.y, Character.W_PX, Character.H_PX), Fx.CHAR_BODY, true)
	draw_rect(Rect2(
		_ch.x, _ch.y + Character.H_PX - Fx.CHAR_TRIM_PX,
		Character.W_PX, Fx.CHAR_TRIM_PX), Fx.CHAR_TRIM, true)
	var tip := tip_px()
	draw_line(_ch.center(), tip, Fx.STAFF_COLOR, Fx.STAFF_WIDTH_PX)

	# 🔴🔴 **총구가 장착을 나른다.** 크기 = 층 수 · 색 = 맨 안쪽 문양(`fx_tuning` 주석).
	#  ⚠ 가산 합성이 아니라 보통 합성이라(이 노드는 `spell_view`와 달리 재질이 없다)
	#   겉 무리를 알파로 깐다.
	var r := Fx.muzzle_radius(loadout_glyphs)
	var tint := Fx.muzzle_tint(loadout_glyphs, loadout_element)
	draw_circle(tip, r * Fx.MUZZLE_GLOW_RATIO,
		Color(tint.r, tint.g, tint.b, Fx.MUZZLE_GLOW_A), true)
	draw_circle(tip, r, tint, true)
