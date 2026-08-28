# **Six seas, one island, one camera.** Saves `tools/shot/out/water/water_N_<name>.png`, one per candidate.
#
# WARNING **This exists because the sea cannot be decided in words** (2026-08-26, the user: "흠 아직은
# 좀 애매하네 어딜 어떻게 수정해야 할지도 애매하고"). The dials that matter -- ripple strength, swell
# size, contrast, colour -- do not describe themselves. Rendering the candidates and putting them side
# by side is the only thing that has ever settled a look in this repo.
#
# WARNING **It overrides the shader's uniforms and writes NOTHING back.** The values that ship live in
# `src/look.gd`; when a candidate wins, its numbers are copied there by hand. Nothing here is a source.
#
# Run (a window has to open -- a headless run has no renderer to read a frame back from):
#   Godot_v4.7.1-stable_win64.exe --path . -s tools/shot/shoot_water.gd
extends SceneTree

const SHOT := "res://tools/shot/out/water/water_%d_%s.png"
const CROP := "res://tools/shot/out/water/crop_%d_%s.png"
## Where the close-up is cut from, as a fraction of the frame, how wide it is, and how far it is blown
## up. ⚠ **It has to land on OPEN SEA** -- a crop centred on the island photographs the island.
const CROP_AT := Vector2(0.14, 0.13)
const CROP_FRACTION := 0.24
const CROP_ZOOM := 4
## ⚠ **A SECOND close-up, on the coast**, because 물가 and 거품 live where the water meets the rock and
## the open-sea crop above cannot see either of them.
const EDGE := "res://tools/shot/out/water/edge_%d_%s.png"
const EDGE_AT := Vector2(0.26, 0.55)
const EDGE_FRACTION := 0.30
## ⚠⚠ **How many frames pass between one shot and the next, and it matters when the thing being judged
## MOVES.** Six frames is a tenth of a second: four shots of a breathing lip taken that close together
## are four pictures of the same instant. The shader's clock runs on real time and cannot be advanced by
## hand, so the only way to photograph a change is to wait for it.
const GAP_FRAMES := 90
## ⚠ **Whether the swordsman and the house are taken out of the frame.** They are, whenever the water is
## the subject — anything standing in every picture is only something to look at instead of the thing
## being judged. **Turn it off for the rounds where THEY are the subject.**
const STRIP_BODIES := true

# Each row is a whole LOOK, not one dial: a sea reads as a sea or does not, and moving one number at a
# time produces six pictures nobody can tell apart.
const LOOKS := [
	# â â  **THE SUBJECT IS ë¬¼ê°, AND ê±°í IS BEING TAKEN AWAY** (2026-08-28, the user: ãê±°íì´ ë§ì
	# ì ¸ëë°.. ê·¸ ë´ê° ìíê±´ ì´ë¯¸ì§ìì ê·¸ ë¬¼ê°ì ë¬¼ê°ê° ëë¬´ ìì°ì¤ë¬ì´ê² ê°ì§ê³  ì¶ë¤ëê±°ì ê±°íë ìì²­ì ì´ã).
	# The previous round read the reference frames as **rings** and built three of them; the user was
	# pointing at the thing AT the rock the whole time. In those frames the shore carries a **soft pale
	# band that hugs the land and changes width along it** â not a hairline, not a ring â and out in the
	# water there is at most ONE faint line, often none.
	# â  The band is the swash (`foam_lip_*`), which stands at 0.06 of a tile: a sixth of what the frames
	# show. Every row below widens it and takes the travelling foam down; they differ in how wide, how
	# much variation, and whether any foam is left at all.
	{"name": "1_soft_lip", "foam_lip_tiles": 0.20, "foam_lip_alpha": 0.34,
	 "foam_alpha": 0.15, "foam_bands": 1.0, "foam_tiles": 1.8},
	{"name": "2_wider_lip", "foam_lip_tiles": 0.30, "foam_lip_alpha": 0.34,
	 "foam_alpha": 0.15, "foam_bands": 1.0, "foam_tiles": 1.8},
	{"name": "3_no_foam_at_all", "foam_lip_tiles": 0.24, "foam_lip_alpha": 0.36,
	 "foam_alpha": 0.0},
	{"name": "4_one_faint_line", "foam_lip_tiles": 0.24, "foam_lip_alpha": 0.34,
	 "foam_alpha": 0.18, "foam_bands": 1.0, "foam_tiles": 2.6, "foam_fade_out": 0.85},
	{"name": "5_more_swing", "foam_lip_tiles": 0.22, "foam_lip_alpha": 0.34,
	 "foam_lip_wob": 0.80, "foam_lip_peel": 0.45,
	 "foam_alpha": 0.15, "foam_bands": 1.0, "foam_tiles": 1.8},
	{"name": "6_widest_faintest", "foam_lip_tiles": 0.38, "foam_lip_alpha": 0.28,
	 "foam_alpha": 0.10, "foam_bands": 1.0, "foam_tiles": 1.8},
]

var _game: Game = null
var _step := 0
var _wait := 0
var _shot := 0


func _initialize() -> void:
	root.size = Vector2i(int(Look.VIEWPORT_W_PX), int(Look.VIEWPORT_H_PX))
	_game = Game.new()
	root.add_child(_game)


func _click(at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	return ev


func _wheel_up() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Look.viewport_size_px() * 0.5
	return ev


func _sea_material() -> ShaderMaterial:
	return _game.field_view._sea.material_override as ShaderMaterial


func _apply(look: Dictionary) -> void:
	# Every candidate starts from the shipped values, so an omitted key means "unchanged" rather than
	# "whatever the previous candidate left behind".
	# ⚠⚠ **CUT FROM FORTY-ODD DIALS TO EIGHTEEN ON 2026-08-28.** The sea this shooter was written
	# against is gone: the flat-border spike won and the shader now draws a border and nothing else.
	# **Setting a uniform the shader does not have is silent** — the old list would have run, printed six
	# happy lines and produced six identical pictures.
	var mat := _sea_material()
	FieldView._hand_the_sea_its_look(mat)
	for key in look.keys():
		if key == "name":
			continue
		mat.set_shader_parameter(str(key), look[key])

## WARNING **The swordsman and the house come OUT of these pictures** (2026-08-28, the user:
## 「캐릭터랑 건물제거 다시잡을꺼임」). Both are placeholders being redone, and a candidate sheet is
## judged by what differs between its frames -- anything standing in every frame is only something to
## look at instead of the water.
## ⚠⚠ **The processing has to be turned off FIRST, and the first attempt did not.** The shell is a real
## child of the tree, so the engine calls its `_process` every frame on its own; hiding the pooled
## sprites only lasted until the next repaint set them visible again, and the swordsman stood in all
## seven frames. **The buildings survived the same bug only because they are rebuilt per island rather
## than per frame** — which is exactly the kind of half-working that reads as working.
func _strip() -> void:
	_game.set_process(false)
	for child in _game.get_children():
		child.set_process(false)
		child.set_physics_process(false)
	var fv := _game.field_view
	if fv._builds != null:
		fv._builds.visible = false
	if fv._props != null:
		fv._props.visible = false
	for s in fv._sprites:
		s.visible = false
	for h in fv._hulls:
		h.visible = false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(SHOT % [_shot, name]))
	# WARNING **A second picture, cropped and blown up, because the first sheet could not be judged**
	# (2026-08-26, the user: 「이건 모바일로는 잘 안 보인다」). The ripple is a few pixels wide, so on a
	# phone every candidate is the same grey rectangle. This cuts one patch of open sea out of the same
	# frame and enlarges it, which is the difference being asked about at a size that survives a screen.
	var w := img.get_width()
	var h := img.get_height()
	var side := int(min(w, h) * CROP_FRACTION)
	var crop := img.get_region(Rect2i(int(w * CROP_AT.x) - side / 2,
									  int(h * CROP_AT.y) - side / 2, side, side))
	crop.resize(side * CROP_ZOOM, side * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(CROP % [_shot, name]))
	var eside := int(min(w, h) * EDGE_FRACTION)
	var edge := img.get_region(Rect2i(int(w * EDGE_AT.x) - eside / 2,
									  int(h * EDGE_AT.y) - eside / 2, eside, eside))
	edge.resize(eside * CROP_ZOOM, eside * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
	edge.save_png(ProjectSettings.globalize_path(EDGE % [_shot, name]))
	print("[water] %d %s" % [_shot, name])
	_shot += 1


func _process(_delta: float) -> bool:
	_wait += 1
	if _wait < GAP_FRAMES:
		return false
	_wait = 0
	match _step:
		0:
			# WARNING **ONE press reaches the island** (ticket 12, 2026-08-28). Two more clicks stood here
			# -- a card and the refit board's 완료 -- and both screens are off the start path now, so they
			# were landing on the field itself and steering the run instead of walking to it.
			_game._unhandled_input(_click(Look.title_slot_hit_rect_px(0).get_center()))
		1:
			# Close enough that the ripple is above a pixel, far enough that a whole stretch of open
			# sea is in frame -- the two things being judged have to be in the same picture.
			for _i in 3:
				_game._unhandled_input(_wheel_up())
			# WARNING **Do not zoom ALL the way in.** The first sheet was shot close and the island filled it:
			# six pictures of a house with a sliver of sea, and nobody could tell four of them apart.
			# The thing being judged has to be most of the frame.
			# The clock is advanced ONCE, before the set, and never between shots: every candidate is
			# then the same instant of the same sea and the only difference is the dials.
			for _i in 120:
				_game._process(1.0 / 60.0)
			if STRIP_BODIES:
				_strip()
		_:
			# WARNING **Set on one step, SHOOT ON THE NEXT.** `get_texture()` hands back the frame that
			# was already drawn, so applying and saving in the same step saved every candidate one look
			# behind -- the first sheet had `deep_green`'s colours filed under `sharp` and the last look
			# missing entirely. A picture of the wrong thing does not announce itself.
			var i := (_step - 2) / 2
			if i >= LOOKS.size():
				return true
			var look: Dictionary = LOOKS[i]
			if (_step - 2) % 2 == 0:
				_apply(look)
			else:
				_save(str(look["name"]))
	_step += 1
	return false
