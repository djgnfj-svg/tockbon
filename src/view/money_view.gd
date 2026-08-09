extends Control
## Money, bottom-right — **an icon and a number, right-aligned.** Screen only; it reads `Progress`.
##
## **It exists because the status line was cut down.** `HUD/Progress` used to read
##  `Lv.3 · XP 12/60 · 돈 24` in one string. The user split that three ways: level **off screen entirely**
##  (「레벨은 안 보이게」), XP into a hairline under the health bar (`hp_view`), and money **into the corner**
##  (「돈도 오른쪽 구석에 표시해 주고」). A `Label` cannot put an icon beside its text, which is why this is a
##  drawn `Control` and not the old label moved.
##
## **Right-aligned, and that is the whole reason `MONEY_RECT` is wider than the content.** Laid out from the
##  left, the icon would walk sideways every time the amount gained a digit.

const Fx := preload("res://src/view/fx_tuning.gd")
const Progress := preload("res://src/actor/progress.gd")

## **A reference, not a copy** — the same rule every other view in this folder holds.
var _progress: Progress = null

## **No null check on the load, deliberately** — `load()` barks on a bad path, and a quiet `return` would
## make it "the coin is missing and nobody said why" (`character_view._body_tex`'s own call).
var _icon: Texture2D = load(Fx.MONEY_ICON_TEX)


func setup(progress: Progress) -> void:
	_progress = progress
	queue_redraw()


func _ready() -> void:
	position = Fx.MONEY_RECT.position
	size = Fx.MONEY_RECT.size
	# **`mouse_filter` comes from the scene** (`2` = IGNORE) — `net_render` forbids writing it here.


## Money changes on a kill, and there is no notification for it. Redrawing every frame is what keeps the
## number and `Progress` in step, the same call `hp_view` makes.
func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _progress == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := str(_progress.money)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONEY_TEXT_SIZE).x
	var mid := size.y * 0.5
	# Laid out from the right edge inward: number, gap, icon.
	_paint_amount(font, Vector2(size.x - w, mid + float(Fx.MONEY_TEXT_SIZE) * 0.36), text)
	_paint_icon(Rect2(
		size.x - w - Fx.MONEY_GAP_PX - Fx.MONEY_ICON_PX, mid - Fx.MONEY_ICON_PX * 0.5,
		Fx.MONEY_ICON_PX, Fx.MONEY_ICON_PX))


## **Its own method so a net can override it and read the string that was actually drawn** — asserting on
## `Progress.money` alone would pass with nothing painted at all.
func _paint_amount(font: Font, at: Vector2, text: String) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONEY_TEXT_SIZE, Fx.MONEY_TEXT)


## **The same seam for the icon**, and it is the half that a text-only check cannot see.
func _paint_icon(r: Rect2) -> void:
	draw_texture_rect(_icon, r, false, Fx.MONEY_ICON_TINT)
