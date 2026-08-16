class_name Hud
extends Control
## Four numbers, a bar and a map — plus, while the boss is hunting, the two things §D adds: a directional
## arrow off the edge while it is out of sight, and a screen-wide announcement the instant it starts.
##
## **The last game drowned in debug overlays** — the user's own report is that the screen became unreadable
## because every session added one more readout. So this file has no debug mode and no toggle: what is here
## is what a player needs, and anything a developer wants goes to stdout instead.
##
## The bar is not decoration either. The GDD's core sensation is a dozen clones being swallowed in a row
## and the gauge lurching forward; if that does not read on screen, the harvest is invisible and the round
## trip cannot feel like anything.

## **Not one constant of its own, and for a day that sentence was a shade wider than the truth.** Six
## colours, seven pixel offsets, three font sizes and the legend's clock all used to be declared here,
## which is the second copy `look.gd` exists to prevent — and the check on the HP colour then read
## `Hud.HP_COLOR`, asserting a file against itself. They are `Look.HUD_*` now. ⚠ **The bar's chase rate
## was the one left behind**, inline in `_process` as a bare `0.001` under a header claiming none existed;
## it is `Look.HUD_BAR_CHASE`, and `net_numbers` pins it literal-to-literal like the other thirty-four.

var world: World = null

## The camera's TRUE rectangle in world coordinates, written by the shell every frame from
## `main.gd::_true_camera_rect()`.
##
## ⚠ **Not `FieldView.view_rect`.** That one is padded 20% for culling, so anything drawn from it draws a
## camera box a fifth too big — a difference nothing on screen announces and no check about culling would
## see. `main.gd::_camera_rect()` keeps its padding and keeps feeding `view.view_rect`; this field gets its
## own unpadded function. Two callers, two rects, and that is the whole reason this is not just assigned
## the one that already exists.
##
## Reset to `Rect2()` by the shell's `_bind_world()` alongside `world`, so a run that ends does not leave a
## stale camera box behind for the next one to draw before its first frame.
##
## Read by `_paint_minimap`, and by nothing else.
var camera_rect := Rect2()

var _bar_shown := 0.0


func _ready() -> void:
	# Offsets, not just anchors — see the same note in `card_panel.gd`. Every readout here is placed from
	# `size`, so a zero-sized Control puts the HP line and the whole minimap into the top-left corner, on
	# top of the bank, with every assertion about what is inside the map still passing.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if world == null:
		return
	# The bar chases the real value instead of snapping to it, so a dozen absorptions in a row read as one
	# surge rather than as twelve invisible increments.
	#
	# The fraction comes from `World::level_progress()` and is not computed here. This file used to restate
	# the formula, which agreed with the sim only while the level cost was flat; the day the cost started
	# rising the bar would have divided by a base the sim no longer charged — parsing fine, every net green,
	# and the only readout of progress in the game quietly wrong.
	_bar_shown = lerpf(_bar_shown, world.level_progress(), 1.0 - pow(Look.HUD_BAR_CHASE, delta))
	queue_redraw()


func _draw() -> void:
	_paint(self)


func _paint(c: CanvasItem) -> void:
	if world == null:
		return
	var sw := world.swarm

	# Through the leaf, not `c.draw_rect` here. These two were the only bare draw calls left in this file,
	# and a per-function scan cannot see a leaf go empty if the drawing never went through one.
	var wide := size.x - Look.HUD_BAR_INSETS
	_paint_rect(c, Rect2(Look.HUD_BAR_AT, Vector2(wide, Look.HUD_BAR_HEIGHT)), Look.HUD_BAR_BG)
	_paint_rect(c, Rect2(Look.HUD_BAR_AT, Vector2(wide * _bar_shown, Look.HUD_BAR_HEIGHT)),
			Look.HUD_BAR_FILL)

	# §F-9: the level's own kick, over the whole groove and independent of `_bar_shown`'s chase — the chase
	# alone reads as draining over time, not as a MOMENT the way this flash does. Then the short phrase,
	# both timed off `World.level_show` rather than a diff of `level` held here (§0-2).
	if world.level_show < Look.LEVEL_BAR_FLASH_TIME:
		var flash: Color = Look.LEVEL_BAR_FLASH_COLOR
		flash.a *= (1.0 - world.level_show / Look.LEVEL_BAR_FLASH_TIME)
		_paint_rect(c, Rect2(Look.HUD_BAR_AT, Vector2(wide, Look.HUD_BAR_HEIGHT)), flash)
	if world.level_show < Look.LEVEL_TEXT_TIME:
		_paint_text(c, Look.LEVEL_TEXT_AT, "레벨업!", Look.FONT_LEVEL_TEXT, Look.LEVEL_POP_COLOR)

	_paint_text(c, Look.HUD_BANK_AT, "%d" % int(sw.banked), Look.FONT_HUD_BANK, Look.HUD_TEXT)
	_paint_text(c, Look.HUD_CARRY_AT,
			"무리 %d · 지고 있는 것 %d" % [sw.count - 1, int(sw.total_carried())], Look.FONT_HUD_ROW,
			Look.HUD_CARRY_COLOR)

	# **The CURRENT value and the CEILING, as one string.** `hp_max()` is a pure function of level and what
	# is worn; `host_hp` is what is left. Both are printed because either alone is unreadable — "9" says
	# nothing without the 39 beside it, and a gauge that only shrinks was the whole problem with the row of
	# circles this replaced (a host opening at `Rules.HOST_HP` 30 drew thirty of them, 788px wide, off a
	# 1280px screen by level 7). **One line, one leaf, and its width does not grow with the maximum.**
	#
	# ⚠ **The ceiling, not `maxi(world.host_hp, Rules.HOST_HP)`.** That was accidentally right only while
	# the single source of HP above the floor moved current and maximum together; read as the ceiling, a
	# damaged host with a mane reads as being at full health. `world.body` is constructed at `World`'s
	# declaration, so this is reachable on the very first frame.
	_paint_text(c, Vector2(Look.HUD_HP_AT_UP.x, size.y - Look.HUD_HP_AT_UP.y),
			"%d/%d" % [world.host_hp, world.body.hp_max(world.level)], Look.FONT_HUD_HP, Look.HUD_HP_COLOR)

	# **The only instruction the player ever gets.** Every clause of the old line became false in one plan —
	# the dash moved off its own key into an active slot, rally stopped taking a cursor point, and three
	# keys appeared. It goes through `_paint_text` so a net reads what a player would read; grepping this
	# file for the string would measure its text and not what reached the screen.
	if world.elapsed < Look.HUD_LEGEND_TIME:
		_paint_text(c, Vector2(Look.HUD_LEGEND_AT_UP.x, size.y - Look.HUD_LEGEND_AT_UP.y),
				"WASD 이동 · F 나누기 · V 모으기 · 1 집결 · 2 흩어지기 · 3 보내기 · Tab 몸",
				Look.FONT_HUD_ROW, Look.HUD_DIM_TEXT)

	_paint_minimap(c, _minimap_frame(), camera_rect, _minimap_marks())

	# **The boss's own direction, off the edge of the screen — screen space, so it lives here and not on
	# `field_view` (§D-2).** Empty while there is no boss, while it is already inside the camera, before the
	# hunt has started, or before the camera box has ever been set (the same `Rect2()` guard `_paint_minimap`'s
	# own camera box uses, for the same reason — `_bind_world()` leaves it empty between runs).
	if world.boss_hunting() and world.boss_index >= 0 and camera_rect.size.x > 0.0 \
			and camera_rect.size.y > 0.0:
		var boss_p: Vector2 = world.critter_pos[world.boss_index]
		if not camera_rect.has_point(boss_p):
			var centre := camera_rect.get_center()
			var to_boss := boss_p - centre
			if to_boss.length_squared() > 1.0:
				var dir := to_boss.normalized()
				# The standard "project to a box's edge" trick: whichever axis's scale is SMALLER is the one
				# that actually reaches an edge first, so the point lands on the nearer wall or the nearer
				# floor/ceiling and never past a corner.
				var half := size * 0.5 - Vector2.ONE * Look.BOSS_ARROW_MARGIN
				var scale := INF
				if absf(dir.x) > 0.0001:
					scale = minf(scale, half.x / absf(dir.x))
				if absf(dir.y) > 0.0001:
					scale = minf(scale, half.y / absf(dir.y))
				_paint_tri(c, size * 0.5 + dir * scale, dir, Look.BOSS_ARROW_SIZE, Look.BOSS_ARROW_COLOR)

	# The hurt vignette, last, so it sits over everything else. `host_grace` already counts DOWN from
	# `Rules.HOST_HIT_GRACE` for `HOST_HURT_COLOR`'s own window — reusing it here is what keeps this owning
	# no clock of its own. Four bands rather than a border stroke, through `_paint_rect` alone.
	if world.host_grace > 0.0:
		var vignette := Look.HURT_VIGNETTE
		vignette.a *= clampf(world.host_grace / Rules.HOST_HIT_GRACE, 0.0, 1.0)
		var band := Look.HURT_VIGNETTE_WIDTH
		_paint_rect(c, Rect2(Vector2.ZERO, Vector2(size.x, band)), vignette)
		_paint_rect(c, Rect2(Vector2(0.0, size.y - band), Vector2(size.x, band)), vignette)
		_paint_rect(c, Rect2(Vector2.ZERO, Vector2(band, size.y)), vignette)
		_paint_rect(c, Rect2(Vector2(size.x - band, 0.0), Vector2(band, size.y)), vignette)

	# **The boss-hunt announcement, over everything — even the vignette.** A pure function of
	# `world.elapsed - Rules.BOSS_HUNT_AT`, gated by `World.boss_hunting()` so this does not restate the
	# threshold comparison itself (see that function for why it is derived and not latched). The wash
	# mixes its alpha toward zero rather than snapping off, so its own last frame does not read as a flicker.
	if world.boss_hunting():
		var since := world.elapsed - Rules.BOSS_HUNT_AT
		if since < Look.BOSS_HUNT_FLASH_TIME:
			var wash: Color = Look.BOSS_HUNT_FLASH
			wash.a *= clampf(1.0 - since / Look.BOSS_HUNT_FLASH_TIME, 0.0, 1.0)
			_paint_rect(c, Rect2(Vector2.ZERO, size), wash)
		if since < Look.BOSS_HUNT_TEXT_TIME:
			# **Korean, because it is in-game text.** Measured and centred the same way `field_view.gd`'s
			# `_label()` centres a force number, but through `get_theme_default_font()` rather than
			# `ThemeDB.fallback_font` — that is the one that renders Korean, see `_paint_text`'s own note.
			var line := "그것이 온다"
			var font := get_theme_default_font()
			var text_sz := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Look.FONT_BOSS_HUNT_TEXT)
			var text_p := size * 0.5 - text_sz * 0.5
			_paint_text(c, text_p, line, Look.FONT_BOSS_HUNT_TEXT, Look.HUD_TEXT)


# -- the minimap -----------------------------------------------------------------------------------------
## Bottom-right, **computed from this `Control`'s own `size`**. ⚠ `set_anchors_preset` leaves the offsets
## alone, so a `Control` on a bare `CanvasLayer` can sit at `size == (0, 0)` and pile the map into the
## top-left corner with every mark assertion still passing — that defect already shipped once on this build,
## which is why a check asserts this rectangle's position and extent and not only what is inside it.
func _minimap_frame() -> Rect2:
	return Rect2(size - Look.MINIMAP_SIZE - Vector2.ONE * Look.MINIMAP_MARGIN, Look.MINIMAP_SIZE)


## Every mark, in MAP space, as `{"p": Vector2, "r": float, "col": Color}` — so a check reads what was
## drawn rather than what was intended.
##
## **It draws from `world`, never from the view.** The host always, every clone, the **boss always**, and
## any other creature only within `Look.MINIMAP_SHOW_DIST` of the host: the map is orientation, not
## intelligence, and the boss being on it from the first second is what makes it a place you walk toward.
func _minimap_marks() -> Array:
	var out := []
	if world == null:
		return out
	var frame := _minimap_frame()
	var sw := world.swarm
	var host: Vector2 = sw.pos[0]
	# **Water first, so every body is drawn on top of it.** A pond is the only mark here that is terrain
	# rather than a body: it is not gated by `MINIMAP_SHOW_DIST`, and its radius is the real one scaled by
	# the map rather than a fixed dot — a pond you cannot judge the size of is not the thing you were
	# looking at the map to find.
	#
	# ⚠ **`frame.size.x / Rules.FIELD.x`, not an average of the two axes.** They are equal today (240/3840
	# and 135/2160 are both 1/16) and a mean would hide the day one of them stops being — at which point
	# every pond on the map is the wrong size in a way nothing on screen explains.
	if world.terrain != null:
		var scale := frame.size.x / Rules.FIELD.x
		for i in world.terrain.water_pos.size():
			out.append({"p": _to_map(world.terrain.water_pos[i], frame),
					"r": float(world.terrain.water_radius[i]) * scale,
					"col": Look.MINIMAP_WATER_COLOR})
	for i in range(1, sw.count):
		out.append({"p": _to_map(sw.pos[i], frame), "r": Look.MINIMAP_CLONE_R, "col": Look.CLONE_COLOR})
	for k in world.critter_count:
		var p := world.critter_pos[k]
		if k != world.boss_index and host.distance_to(p) > Look.MINIMAP_SHOW_DIST:
			continue
		var col: Color = FieldView.SPECIES_COLOR[world.critter_species[k]]
		var r := Look.MINIMAP_CREATURE_R
		# **While the hunt is on**, the boss's own dot pulses between its ordinary size and
		# `MINIMAP_BOSS_PULSE_MUL` times it — a pure function of `elapsed`, so this holds no timer of its
		# own (§0-2). Every other mark on the map is a fixed radius; this is the one that moves, and it
		# moves for exactly as long as the boss is actually coming.
		if k == world.boss_index and world.boss_hunting():
			var phase := (sin(world.elapsed * Look.MINIMAP_BOSS_PULSE_FREQ) + 1.0) * 0.5
			r = lerpf(Look.MINIMAP_CREATURE_R, Look.MINIMAP_CREATURE_R * Look.MINIMAP_BOSS_PULSE_MUL, phase)
		out.append({"p": _to_map(p, frame), "r": r, "col": col})
	# The host goes on last so nothing is drawn over the one mark you are looking for.
	out.append({"p": _to_map(host, frame), "r": Look.MINIMAP_HOST_R, "col": Look.HOST_COLOR})
	return out


func _to_map(p: Vector2, frame: Rect2) -> Vector2:
	return frame.position + (p / Rules.FIELD) * frame.size


## The hook a net spies, and it holds **zero** bare `c.draw_*` of its own — background, edge, camera box and
## every mark all go through the two leaves below.
##
## The edge is a slightly larger filled rectangle UNDER the background rather than an unfilled one over it:
## `_paint_rect` is exactly one `draw_rect` and an outline would need a second pair of arguments that
## nothing else in this file wants.
func _paint_minimap(c: CanvasItem, frame: Rect2, camera: Rect2, marks: Array) -> void:
	_paint_rect(c, frame.grow(2.0), Look.MINIMAP_FRAME)
	_paint_rect(c, frame, Look.MINIMAP_BG)
	# ⚠ **The camera's TRUE rectangle**, not the view's padded one — see `camera_rect`. An empty rect is what
	# `_bind_world()` leaves behind, and drawing it would put a dot in the map's top-left corner.
	#
	# ⚠ **Clipped, because the camera routinely hangs off the field.** The host against the west edge at
	# `Look.ZOOM_FAR` on a 1280-wide viewport puts `camera_rect.position.x` at −786, which maps ~49px LEFT
	# of a 240px map: a bright bar drawn straight across the play area, every frame. Nothing else this
	# `Control` draws leaves its own rectangle, and an empty intersection draws nothing at all.
	if camera.size.x > 0.0 and camera.size.y > 0.0:
		_paint_rect(c, Rect2(_to_map(camera.position, frame),
				(camera.size / Rules.FIELD) * frame.size).intersection(frame),
				Look.MINIMAP_CAMERA_COLOR)
	for m: Dictionary in marks:
		_paint_mark(c, m["p"], m["r"], m["col"])


## The hook. `draw_string` is a native call and Godot refuses to override it — a parse error — so every
## readout goes through this one method instead, and a net overrides it to capture what a player would
## actually read. Without it "the HUD drew something" is all that can be measured, and the last game's
## own lesson is that three of the four numbers this build reports would reach the screen through an
## entirely unmeasured file.
func _paint_text(c: CanvasItem, p: Vector2, text: String, font_size: int, col: Color) -> void:
	c.draw_string(get_theme_default_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

## Every rectangle in this file: the level bar's two halves, and the minimap's background, edge and camera
## box. **Exactly one `draw_rect`**, and a per-function scan pins that — a leaf that is not counted can be
## emptied with the round green, which is measured on this repo and not a worry.
func _paint_rect(c: CanvasItem, r: Rect2, col: Color) -> void:
	c.draw_rect(r, col)


## One minimap mark. **Its own leaf and not the field's `_paint_disc`**: this one is in SCREEN space on a
## `Control` and that one is in world space on a `Node2D`, and a spy that saw both could not tell a rock
## from the boss.
func _paint_mark(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_circle(p, r, col)

## §D-2's edge arrow: a triangle pointing along `dir`, centred at `p`. Its own leaf — `_paint_rect` draws a
## rectangle and `_paint_mark` a circle, and neither can be an arrow.
## ⚠ **The two shape ratios are `Look.BOSS_ARROW_BACK`/`_HALF_WIDTH`, not bare `0.5`s.** This file declares
## no constant of its own (see its header) and the pixel half of that rule is enforced by hand — the colour
## scan cannot see a number.
func _paint_tri(c: CanvasItem, p: Vector2, dir: Vector2, size_px: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var back := p - dir * (size_px * Look.BOSS_ARROW_BACK)
	var half := side * (size_px * Look.BOSS_ARROW_HALF_WIDTH)
	c.draw_colored_polygon(PackedVector2Array([p + dir * size_px, back + half, back - half]), col)

## **`_paint_heart` is gone and nothing replaced it.** The HP readout is one `_paint_text` call now, so
## there is no third leaf for it. Nothing bounded the row's length, and the fix the user chose was to stop
## drawing a row.
