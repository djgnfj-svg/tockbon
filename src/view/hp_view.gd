extends Control
## The health and XP readout — **a framed red bar with the number inside it, and a thin XP line under it.**
## Screen only; it reads the character and `Progress` and never writes either.
##
## **The layout is the user's, stated twice.** First 「체력은 숫자만 있어도 될듯 빨간색」, which produced a big
##  number *above* a thin strip; then 「HP가 숫자가 바 안에 있어야 줬으면 좋겠고」 and 「XP는 아래 얇은 선으로」.
##  So: **the number lives inside the bar**, and XP is a separate hairline beneath. **Level is not drawn at
##  all** — 「레벨은 안 보이게, 레벨이라는 존재 자체가 있다는 것만 알면 될 거 같은데」. The level-up prompt
##  (`HUD/LevelUp`) stays, because that one is an instruction, not a statistic.
##
## **`assets/ui/hp_frame.png` was on disk, referenced by nothing.** This is the file that wires it — the same
##  "art that was generated but never painted" this repo has caught three times now (`circle-art.md`'s own
##  section). It is a hollow rounded box, so it is drawn **first** and the fill goes on top: that way the
##  frame's interior colour, whatever it turns out to be, cannot hide the bar.
##
## **Colour is the warning, not a blink.** A flashing bar competes with the invulnerability blink the
##  character sprite already does (`character_view._draw`'s `invuln_left & 1`), and two blinking things at
##  once read as a rendering fault.

const Fx := preload("res://src/view/fx_tuning.gd")
const Character := preload("res://src/actor/character.gd")
const Progress := preload("res://src/actor/progress.gd")

## **References, not copies** — the same discipline `character_view._ch` holds. Copy a number and the day one
##  push is forgotten it becomes "I took damage and the readout did not move", with nothing barking.
var _ch: Character = null
var _progress: Progress = null

## The frame art. **No null check, deliberately** — `load()` barks on a bad path and a quiet `return` would
##  make it "the bar is invisible and nobody said why", the same call `character_view._body_tex` makes.
var _frame_tex: Texture2D = load(Fx.HP_FRAME_TEX)


func setup(ch: Character, progress: Progress) -> void:
	_ch = ch
	_progress = progress
	queue_redraw()


func _ready() -> void:
	position = Fx.HP_RECT.position
	size = Fx.HP_RECT.size
	# **`mouse_filter` is set in the scene (`2` = IGNORE), never here** — `net_render` forbids writing it at
	#  runtime so the scene's value cannot become a false knob.


## Health and XP change on a tick, and neither sends a notification — the same situation `character_view` is
## in for position. Redrawing every frame is what keeps the picture and the model in step.
func _process(_dt: float) -> void:
	queue_redraw()


## **The filled fraction, clamped.** Negative hp is already blocked in `Character.take_hit`, but a bar that
## can draw past its own frame is how a gauge ends up painting over the art around it.
static func fill_frac(hp: int) -> float:
	if Character.MAX_HP <= 0:
		return 0.0
	return clampf(float(hp) / float(Character.MAX_HP), 0.0, 1.0)


## XP toward the next level, 0-1. **`Progress.xp_for_level` is the single source of the requirement** —
## recompute it here and the bar fills to a different mark than the level-up actually fires on.
static func xp_frac(progress: Progress) -> float:
	if progress == null:
		return 0.0
	var need := Progress.xp_for_level(progress.level)
	if need <= 0:
		return 0.0
	return clampf(float(progress.xp) / float(need), 0.0, 1.0)


## The number's colour — **it sits on the red fill now, so it is not red itself.** The previous version put
## a red number on the background; inside a red bar that would be invisible at full health and only appear as
## the bar drained, which reads as the number breaking rather than as health dropping.
static func number_color(hp: int) -> Color:
	return Fx.HP_TEXT_LOW.lerp(Fx.HP_TEXT, fill_frac(hp))


func _draw() -> void:
	if _ch == null:
		return
	# **Frame first.** It is a hollow box and its interior is not guaranteed transparent, so anything drawn
	#  before it could be covered; anything drawn after sits inside it.
	_paint_frame(Rect2(Vector2.ZERO, size))
	var inner := Fx.hp_inner_rect(size)
	_paint_fill(inner, fill_frac(_ch.hp))
	var font: Font = ThemeDB.fallback_font
	if font != null:
		_paint_number(font, inner, _ch.hp, number_color(_ch.hp))
	_paint_xp(Fx.hp_xp_rect(size), xp_frac(_progress))


## **Each part is its own method so a net can override it and read what it was handed.** CLAUDE.md: counting
## `_draw()` calls measures the engine, and Godot refuses to let a script override `draw_rect`/`draw_string`
## themselves — an ordinary method is the only seam.
func _paint_frame(r: Rect2) -> void:
	draw_texture_rect(_frame_tex, r, false, Fx.HP_FRAME_TINT)


## The bar. **Ground first, then the fill** — the other way round the fill is covered and the bar reads as
## permanently empty with every value still correct.
## **The fill keeps the ground's height and only loses width**, so nearly-dead is a sliver at the left edge
## rather than a stub floating in the middle.
func _paint_fill(r: Rect2, frac: float) -> void:
	draw_rect(r, Fx.HP_BAR_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Fx.HP_FULL, true)


## The number, **centred inside the bar** (the user's ask). Measured and shifted by half, the same idiom
## `monster_view._draw_dmg_number` uses — a left-aligned number would drift as the digit count changes.
func _paint_number(font: Font, bar: Rect2, hp: int, color: Color) -> void:
	var text := str(hp)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.HP_NUMBER_SIZE).x
	draw_string(font,
		Vector2(bar.get_center().x - w * 0.5,
			bar.get_center().y + float(Fx.HP_NUMBER_SIZE) * Fx.HP_NUMBER_BASELINE_FRAC),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.HP_NUMBER_SIZE, color)


## XP — **a hairline, not a second bar.** It carries no number and no frame on purpose: the user asked for
## 얇은 선, and giving it the same weight as health would make two gauges compete for the same glance.
func _paint_xp(r: Rect2, frac: float) -> void:
	draw_rect(r, Fx.XP_BAR_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Fx.XP_BAR, true)
