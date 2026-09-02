# Four layout candidates for ONE big body panel (03-02, second 시안 round: the user wants everything
# visible on one plate, RimWorld-like but simpler, no tabs), photographed IN THE GAME with a real body
# pressed. **Not a net** — nothing here can go red, and nothing here is `src/`: the layouts are drawn
# by a `HudView` subclass whose `_draw` is overridden for the shot, through the view's own two leaves
# plus `draw_texture_rect` for the bars.
#
# ⚠ **Nothing here can go red, so a stale step writes a wrong PNG without failing** — `shoot_pick.gd`'s
# rule. **A shot with no panel means the hand is empty**: every save prints the hand's size.
#
# ⚠ **What is real and what is a sample.** Name, 체력, 공격력 and 공격속도 are read off the sim
# (`army.name_of`, `Battle.soldier_hp`, `Army.max_hp_of`, `Army.damage_of`, `Army.period_of`). 허기,
# 방어력, the five 적성 numbers and the 특성 word do not exist in the sim yet (05-07, 11-01) and are
# SAMPLE values, printed once as 「시안 표본값」 so nobody reads them off the picture as facts.
#
# The plates are pulled at their own sizes and live OUTSIDE `res://` (they are candidates, not assets),
# so they are loaded with `Image.load_from_file` + `ImageTexture.create_from_image`.
#
# Run (a window has to open — a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_panel_layouts.gd
extends SceneTree

const OUT_DIR := "res://tools/shot/out/panel_layouts"
const SHOT := OUT_DIR + "/layout_%s.png"
const PLATE_DIR := "C:/Users/djgnf/.claude/jobs/868533fc/tmp/layouts"
const PLATES := {
	"A": PLATE_DIR + "/plate_A_480x180.png",
	"B": PLATE_DIR + "/plate_B_480x150.png",
	"C": PLATE_DIR + "/plate_C_400x200.png",
	"D": PLATE_DIR + "/plate_D_520x200.png",
	"E1": PLATE_DIR + "/plate_E1_520x140.png",
	"E2": PLATE_DIR + "/plate_E2_360x170.png",
}
const LAYOUTS := ["A", "B", "C", "D", "E1", "E2"]

## The icon set for E1/E2 (third 시안 round: 「far less text — icons, bars, no labels」), 24x24 each,
## outside `res://` like the plates.
const ICON_DIR := "C:/Users/djgnf/.claude/jobs/868533fc/tmp/icons"
const ICONS := ["hp", "hunger", "attack", "defense", "speed", "cook", "craft", "fish", "mine", "log"]
## E-row geometry: a 24 px row on a 28 px pitch under the 19 px name row; icon to its thing 4, group
## to group 8; a bar or a number is centred on its icon.
const ICON_PX := 24.0
const ROW_PITCH := 28.0
const ICON_GAP := 4.0
const GROUP_GAP := 8.0
const APT_BAR_W := 64.0

## The panel's own typography, the numbers 03-02 settled: pad 8, pitch 19, Galmuri at 15.
const PAD := 8.0
const PITCH := 19.0
const FONT_PX := 15
## D's name line: Galmuri at 2x is still on its pixel grid.
const BIG_PX := 30
## B's bar: the body's own 64x16 frame drawn at 2x width, 1x height; the 50x8 fill inside it the same
## way, cropped from the right by the ratio exactly as `FieldView._put_bar` crops it.
const BAR_W := 128.0
const BAR_H := 16.0
const BAR_SCALE_X := 2.0

## SAMPLE values (see the header). 「시안 표본값」.
const SAMPLE_HUNGER := 100
const SAMPLE_DEFENCE := 0
const SAMPLE_TRAIT := "절식"
const SAMPLE_APTITUDE := [["요리", 2], ["제작", 0], ["낚시", 3], ["채광", 1], ["벌목", 0]]


## The hud with `_draw` replaced by one of the four layouts. Everything goes out through the view's
## own `_paint_panel` / `_paint_line` leaves so the letters are the game's letters; the two bars in B
## are the only strokes drawn here directly.
class LayoutHud extends HudView:
	var layout := "A"
	var plate: Texture2D = null
	## name -> ImageTexture, filled by the shooter for E1/E2.
	var icons := {}
	var frame: Texture2D = load(Look.HP_BAR_FRAME) as Texture2D
	var fill: Texture2D = load(Look.HP_BAR_FILL) as Texture2D
	## Per frame: the plate's rect and the furthest right / lowest ink any line reached, so the
	## shooter can say whether the layout fit without anybody looking.
	var plate_rect := Rect2()
	var ink_right := 0.0
	var ink_bottom := 0.0
	var lines_drawn := 0

	func _draw() -> void:
		if battle == null or _picked.is_empty() or plate == null:
			return
		var size := plate.get_size()
		var origin := Vector2(0.0, Look.viewport_size_px().y - size.y)
		plate_rect = Rect2(origin, size)
		ink_right = 0.0
		ink_bottom = 0.0
		lines_drawn = 0
		_paint_panel(plate, origin)
		match layout:
			"A":
				_layout_a(origin)
			"B":
				_layout_b(origin)
			"C":
				_layout_c(origin)
			"D":
				_layout_d(origin)
			"E1":
				_layout_e(origin, false)
			_:
				_layout_e(origin, true)

	# -- the values ------------------------------------------------------------------------------

	func _id() -> int:
		return int(_picked[0])

	func _name_line() -> String:
		var who: String = battle.army.name_of(_id())
		if _picked.size() > 1:
			who += " x %d" % _picked.size()
		return "이름 " + who

	func _hp_frac() -> float:
		var mx := battle.army.max_hp_of(_id())
		return 0.0 if mx <= 0.0 else clampf(float(battle.soldier_hp[_id()]) / mx, 0.0, 1.0)

	func _hp_text() -> String:
		return "%d/%d" % [int(battle.soldier_hp[_id()]), int(battle.army.max_hp_of(_id()))]

	func _attack_text() -> String:
		return _num(battle.army.damage_of(_id()))

	func _speed_text() -> String:
		return _num(battle.army.period_of(_id()))

	## 5.0 reads as 「5」 and 2.4 as 「2.4」.
	func _num(v: float) -> String:
		return str(int(v)) if is_equal_approx(v, floorf(v)) else "%.1f" % v

	func _aptitude_lines() -> Array:
		var out := []
		for row in SAMPLE_APTITUDE:
			out.append("%s %d" % [str(row[0]), int(row[1])])
		return out

	# -- the strokes -----------------------------------------------------------------------------

	## One line at `size_px`, its baseline `ascent` under `top`. Records how far its ink reaches.
	func _line(text: String, x: float, baseline: float, size_px: int = FONT_PX) -> void:
		var font := panel_font()
		_paint_line(text, Vector2(x, baseline), font, size_px, Look.COL_PANEL_TEXT)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		ink_right = maxf(ink_right, x + w)
		ink_bottom = maxf(ink_bottom, baseline + font.get_descent(size_px))
		lines_drawn += 1

	## A column of lines, one pitch apart, starting at `baseline`.
	func _column(texts: Array, x: float, baseline: float) -> void:
		for i in texts.size():
			_line(str(texts[i]), x, baseline + float(i) * PITCH)

	## The body's own bar, 2x wide, its top at `top`, filled to `frac` from the left.
	func _bar(x: float, top: float, frac: float) -> void:
		_bar_w(x, top, BAR_W, frac)

	## The same bar at any width `w` (64 = the frame's own size, 128 = 2x): the frame is stretched to
	## `w`, the fill by the same factor and cropped from the right by `frac`, both 16 tall.
	func _bar_w(x: float, top: float, w: float, frac: float) -> void:
		draw_texture_rect(frame, Rect2(Vector2(x, top), Vector2(w, BAR_H)), false)
		ink_right = maxf(ink_right, x + w)
		ink_bottom = maxf(ink_bottom, top + BAR_H)
		if frac <= 0.0:
			return
		var sx := w / float(frame.get_width())
		var fw := float(fill.get_width())
		var fh := float(fill.get_height())
		var inset := Vector2((w - fw * sx) * 0.5, (BAR_H - fh) * 0.5)
		draw_texture_rect_region(fill,
			Rect2(Vector2(x, top) + inset, Vector2(fw * sx * frac, fh)),
			Rect2(0.0, 0.0, fw * frac, fh))

	func _first_baseline(origin: Vector2, size_px: int = FONT_PX) -> float:
		return origin.y + PAD + panel_font().get_ascent(size_px)

	## A 24x24 icon at 1:1, its top-left at (x, top). Answers the x just past it and the gap.
	func _icon(name: String, x: float, top: float) -> float:
		var tex: Texture2D = icons.get(name, null)
		if tex != null:
			draw_texture(tex, Vector2(x, top))
		ink_right = maxf(ink_right, x + ICON_PX)
		ink_bottom = maxf(ink_bottom, top + ICON_PX)
		return x + ICON_PX + ICON_GAP

	## A bar of `w` px, centred on a 24 px row whose top is `top`. Answers the x past it.
	func _row_bar(x: float, top: float, w: float, frac: float) -> float:
		_bar_w(x, top + (ICON_PX - BAR_H) * 0.5, w, frac)
		return x + w

	## A number (or a word) centred on a 24 px row. Answers the x past it.
	func _row_text(text: String, x: float, top: float) -> float:
		var font := panel_font()
		var asc := font.get_ascent(FONT_PX)
		_line(text, x, top + floorf((ICON_PX - asc) * 0.5) + asc)
		return x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x

	## [icon][bar] as one group; answers the x past it.
	func _icon_bar(name: String, x: float, top: float, w: float, frac: float) -> float:
		return _row_bar(_icon(name, x, top), top, w, frac)

	## [icon] 「number」 as one group; answers the x past it.
	func _icon_num(name: String, x: float, top: float, text: String) -> float:
		return _row_text(text, _icon(name, x, top), top)

	# -- A 「세 칸」 480x180 ------------------------------------------------------------------------
	func _layout_a(o: Vector2) -> void:
		var y0 := _first_baseline(o)
		_line(_name_line(), o.x + PAD, y0)
		var y1 := y0 + PITCH
		_column(["상태", "체력 " + _hp_text(), "허기 %d" % SAMPLE_HUNGER, "특성 " + SAMPLE_TRAIT],
			o.x + PAD, y1)
		_column(["능력치", "공격력 " + _attack_text(), "방어력 %d" % SAMPLE_DEFENCE,
			"공격속도 " + _speed_text()], o.x + PAD + 150.0, y1)
		_column(["적성"] + _aptitude_lines(), o.x + PAD + 300.0, y1)

	# -- B 「림월드식」 480x150 ---------------------------------------------------------------------
	func _layout_b(o: Vector2) -> void:
		var y0 := _first_baseline(o)
		var x := o.x + PAD
		_line(_name_line(), x, y0)
		var label_w := panel_font().get_string_size("체력 ", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
		_line("체력", x, y0 + PITCH)
		_bar(x + label_w, y0 + PITCH - 14.0, _hp_frac())
		_line("허기", x, y0 + 2.0 * PITCH)
		_bar(x + label_w, y0 + 2.0 * PITCH - 14.0, float(SAMPLE_HUNGER) / 100.0)
		_line("특성 " + SAMPLE_TRAIT, x, y0 + 3.0 * PITCH)
		var rx := o.x + PAD + 200.0
		_column(["공격력 " + _attack_text(), "방어력 %d" % SAMPLE_DEFENCE, "공격속도 " + _speed_text()],
			rx, y0)
		_column(_aptitude_lines(), rx + 130.0, y0)

	# -- C 「두 줄」 400x200 ------------------------------------------------------------------------
	func _layout_c(o: Vector2) -> void:
		var y0 := _first_baseline(o)
		var x := o.x + PAD
		_column([_name_line(), "체력 " + _hp_text(), "허기 %d" % SAMPLE_HUNGER, "특성 " + SAMPLE_TRAIT],
			x, y0)
		var y1 := y0 + 5.0 * PITCH
		var apt := _aptitude_lines()
		_column(["능력치 공격 %s 방어 %d 속도 %s" % [_attack_text(), SAMPLE_DEFENCE, _speed_text()],
			"적성 %s %s %s" % [apt[0], apt[1], apt[2]], "%s %s" % [apt[3], apt[4]]], x, y1)

	# -- D 「이름 크게」 520x200 --------------------------------------------------------------------
	func _layout_d(o: Vector2) -> void:
		var y0 := _first_baseline(o, BIG_PX)
		_line(_name_line(), o.x + PAD, y0, BIG_PX)
		var y1 := y0 + PAD + PITCH
		_column(["상태", "체력 " + _hp_text(), "허기 %d" % SAMPLE_HUNGER, "특성 " + SAMPLE_TRAIT],
			o.x + PAD, y1)
		_column(["능력치", "공격력 " + _attack_text(), "방어력 %d" % SAMPLE_DEFENCE,
			"공격속도 " + _speed_text()], o.x + PAD + 170.0, y1)
		_column(["적성"] + _aptitude_lines(), o.x + PAD + 340.0, y1)

	# -- E1 「넓은 띠」 520x140 · E2 「좁게」 360x170 ---------------------------------------------------
	## Icons, bars and numbers, no labels. `narrow` splits the five 적성 into three and two rows.
	func _layout_e(o: Vector2, narrow: bool) -> void:
		var x0 := o.x + PAD
		# row0: the name alone, no 「이름」 label.
		var who: String = battle.army.name_of(_id())
		if _picked.size() > 1:
			who += " x %d" % _picked.size()
		_line(who, x0, _first_baseline(o))
		var top := o.y + PAD + PITCH
		# row1: [heart][hp bar 2x]  [bowl][hunger bar 2x]
		var x := _icon_bar("hp", x0, top, BAR_W, _hp_frac())
		_icon_bar("hunger", x + GROUP_GAP, top, BAR_W, float(SAMPLE_HUNGER) / 100.0)
		# row2: [sword] 5  [shield] 0  [chevrons] 2.4
		top += ROW_PITCH
		x = _icon_num("attack", x0, top, _attack_text())
		x = _icon_num("defense", x + GROUP_GAP, top, str(SAMPLE_DEFENCE))
		_icon_num("speed", x + GROUP_GAP, top, _speed_text())
		# row3 (and row4 when narrow): the five 적성 as [icon][64 px bar at level / 10]
		var apt_icons := ["cook", "craft", "fish", "mine", "log"]
		top += ROW_PITCH
		x = x0
		for i in apt_icons.size():
			if narrow and i == 3:
				top += ROW_PITCH
				x = x0
			var level := int((SAMPLE_APTITUDE[i] as Array)[1])
			x = _icon_bar(str(apt_icons[i]), x, top, APT_BAR_W, float(level) / 10.0) + GROUP_GAP
		# last row: the 특성 word alone, as text on the row's top.
		top += ROW_PITCH
		_line(SAMPLE_TRAIT, x0, top + panel_font().get_ascent(FONT_PX))


var _game: Game = null
var _hud: LayoutHud = null
var _plates := {}
var _icons := {}
var _step := 0
var _wait := 0
var _who := -1
var _shot := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for k: String in PLATES:
		var img := Image.load_from_file(str(PLATES[k]))
		if img == null:
			print("[shot] plate %s did not load from %s" % [k, str(PLATES[k])])
			continue
		_plates[k] = ImageTexture.create_from_image(img)
		print("[shot] plate %s %s" % [k, str(img.get_size())])
	for n: String in ICONS:
		var ic := Image.load_from_file(ICON_DIR + "/" + n + ".png")
		if ic == null:
			print("[shot] icon %s did not load" % n)
			continue
		_icons[n] = ImageTexture.create_from_image(ic)
	print("[shot] icons loaded %d of %d" % [_icons.size(), ICONS.size()])
	print("[shot] 시안 표본값 — 허기 %d · 방어력 %d · 특성 %s · 적성 %s (sim 에 없는 값, 표본)"
		% [SAMPLE_HUNGER, SAMPLE_DEFENCE, SAMPLE_TRAIT, str(SAMPLE_APTITUDE)])
	_game = Game.new()
	root.add_child(_game)


## ⚠ From the first `_process` step and not `_initialize` — `_ready` has not run there (measured in
## `shoot_panel.gd`). Before the title press, so the real `_open_island` binds this one.
func _swap_in_layout_hud() -> void:
	_game.remove_child(_game.hud_view)
	_game.hud_view.queue_free()
	_hud = LayoutHud.new()
	_hud.icons = _icons
	_game.hud_view = _hud
	_game.add_child(_hud)
	_game.move_child(_hud, 1)


func _press(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _release(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
	return ev


func _motion(at: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.relative = Vector2.ZERO
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _save(layout: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT % layout))
	var r := _hud.plate_rect
	var fit_x := _hud.ink_right <= r.end.x - PAD
	var fit_y := _hud.ink_bottom <= r.end.y - PAD
	print("[shot] layout_%s hand=%d plate=%s lines=%d ink_right=%.1f (limit %.1f) ink_bottom=%.1f (limit %.1f) fits=%s"
		% [layout, _game.hand.ids.size(), str(r), _hud.lines_drawn, _hud.ink_right, r.end.x - PAD,
			_hud.ink_bottom, r.end.y - PAD, str(fit_x and fit_y)])


func _body_at_screen() -> Vector2:
	var b: Battle = _game.battle
	var ashore := b.ashore_ids()
	if ashore.is_empty():
		return Vector2(-1.0, -1.0)
	_who = int(ashore[0])
	var p: Vector2 = b.soldier_pos[_who]
	return _game.field_view.tile_to_screen_px(int(p.x), int(p.y))


func _process(_delta: float) -> bool:
	if _step >= 4:
		_game._unhandled_input(_motion(Look.viewport_size_px() * 0.5))
	_wait += 1
	if _wait < 6:
		return false
	_wait = 0
	match _step:
		0:
			_swap_in_layout_hud()
			_game._unhandled_input(_press(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			for _i in 240:
				_game._process(1.0 / 60.0)
		2:
			for _i in 10:
				_game._unhandled_input(_wheel_up())
		3:
			var at := _body_at_screen()
			if at.x >= 0.0:
				_game._unhandled_input(_press(at))
				_game._unhandled_input(_release(at))
			print("[shot] pressed=%s who=%d hand=%d" % [str(at), _who, _game.hand.ids.size()])
			_hud.layout = LAYOUTS[0]
			_hud.plate = _plates.get(LAYOUTS[0], null)
		_:
			# One layout per step from here: save the one that has been up for six frames, then
			# put the next one up.
			if _shot < LAYOUTS.size():
				_save(LAYOUTS[_shot])
				_shot += 1
				if _shot < LAYOUTS.size():
					_hud.layout = LAYOUTS[_shot]
					_hud.plate = _plates.get(LAYOUTS[_shot], null)
				else:
					print("[shot] done who=%d" % _who)
					return true
	_step += 1
	return false
