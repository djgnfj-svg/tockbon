extends RefCounted
## The background layer (`src/view/sky_background.gd`, `docs/design/background.md`) — **wired but never seen
## on screen.** Another session was mid-edit in `src/actor/world_step.gd` when that doc was written, so the
## project did not parse; it parses now.
##
## **Not one net anywhere mentioned `SkyBackground` before this file** (grepped). The whole layer could
## vanish — a dropped texture path, a swapped scene order, a shader that stopped punching empty cells
## transparent — and the suite would stay green. That is worse here than usual: a background failing
## silently looks exactly like a background that was never built at all.
##
## **Driven, not grepped, wherever execution can reach it** — the same technique already proved three times
## in `rune-lock-and-receiving.md`'s own verification (`_can_pick` on an untreed `CircleWindow`, `_set_loadout`
## on a live `Stage`, `_revoke_unowned_rune` called directly). Only the shader's own fragment logic truly
## resists (no GPU render pass headless) — that one piece is a text scan, named honestly as one, not dressed
## up as an execution check.
##
## **Does not re-measure what `net_render.gd` already covers.** `_injection_matches_shader` there scans
## *every* uniform `cell_renderer.gd`'s shader declares against every `set_shader_parameter()` call — `empty_id`
## is already inside that net generically. What it cannot see is the injected *value*; this file drives that.
##
## **Not touched**: the art, `sky_background.gd`'s drawing code, or `background.md`'s decisions. This file only
## adds the missing measurement.

const Fx := preload("res://src/view/fx_tuning.gd")
const SkyBackground := preload("res://src/view/sky_background.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
## **Borrows** the comment/string stripper — two nets sweep source text, so there must be exactly one
##  stripper (`net_circle.gd`'s own reason for the same borrow).
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"
const STAGE_SCRIPT := "res://src/stage/stage.gd"
const SHADER_PATH := "res://src/view/cell_grid.gdshader"


func run(t) -> void:
	_both_far_textures_load(t)
	_far_textures_are_1920x544_and_mirrored(t)
	_setup_wires_the_farm_picture_by_default(t)
	_set_backdrop_stores_the_picture_it_is_given(t)
	_far_parallax_ratios_are_pinned(t)
	_layer_y_actually_responds_to_the_ratio(t)
	_horizon_anchor_is_pinned_by_value(t)
	_vertical_follow_frac_actually_damps_the_far_layer(t)
	_cell_renderer_derives_empty_id_from_the_material_table(t)
	_shader_zeroes_alpha_on_the_empty_material(t)
	_sky_background_sits_before_cell_renderer_in_the_scene(t)
	_ready_actually_calls_setup(t)
	_underground_depth_constants_are_pinned(t)
	_far_picture_stops_at_the_ground_line(t)
	_depth_fill_bands_cover_the_whole_range_in_order(t)
	_cell_renderer_derives_depth_uniforms_from_fx_tuning(t)
	_shader_applies_depth_dim_before_fire_and_water_overwrite_c(t)


# ══════════════════════════════════════════════════════════════════
#  The art loads and is the right shape
# ══════════════════════════════════════════════════════════════════

## **Both textures load.** `net_monster_sprite`'s own precedent: a wrong path makes exactly that entry
## null, nothing else — proven by inversion (mutation-tested by hand, not encoded as a scenario here; the
## table these paths are read from is small enough that breaking one and rerunning is the direct check).
## **It was four until the near strip was deleted** (the user: "뭔가 길에 있을법한 레이어, 그거 지워줘").
func _both_far_textures_load(t) -> void:
	var paths := {
		"농장 원경(bg_farm)": Fx.BG_FAR_TEXTURE,
		"마을 원경(bg_town)": Fx.BG_TOWN_FAR_TEXTURE,
	}
	for label: String in paths:
		var path: String = paths[label]
		var tex: Texture2D = load(path)
		t.ok(tex != null, "%s 그림을 읽었다 (%s)" % [label, path])


## **The far pair is 1920x544, mirrored** (`background.md`: "far scenery ... mirrored 1920x544"). It is the
## only pair left — the near strip that used to sit in front of it was deleted at the user's word, and it
## never carried this contract anyway (its two files were 960x136 and 1920x214, matching neither the far
## pair nor each other).
##
## **The raw png is opened, bypassing the import** — `net_monster_sprite`'s own reason: fix the art without
## rerunning the import and the game draws the stale `.ctex` while a check against the import alone stays green.
func _far_textures_are_1920x544_and_mirrored(t) -> void:
	var pairs: Array = [
		["bg_farm", Fx.BG_FAR_TEXTURE],
		["bg_town", Fx.BG_TOWN_FAR_TEXTURE],
	]
	for pair: Array in pairs:
		var name: String = pair[0]
		var path: String = pair[1]
		var tex: Texture2D = load(path)
		t.ok(tex != null, "%s를 읽는다 (%s)" % [name, path])
		if tex == null:
			continue
		t.eq(tex.get_width(), 1920, "%s 폭이 1920이다" % name)
		t.eq(tex.get_height(), 544, "%s 높이가 544다" % name)

		t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % path)
		var img := Image.load_from_file(path)
		t.ok(img != null, "%s 원본 png를 연다 (임포트를 안 거친다)" % name)
		if img == null:
			continue
		t.eq(Vector2i(img.get_width(), img.get_height()), Vector2i(1920, 544),
			"%s 원본 png 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)" % name)
		if img.get_width() != 1920 or img.get_height() != 544:
			continue

		# **Every row, not a sample** — a mirror seam that breaks in only a few rows (a bad crop, an off-by-one
		#  in the flip) would survive a sparse check. Stops at the first mismatch either way.
		var mirrored := true
		for y in img.get_height():
			for x in img.get_width() / 2:
				if img.get_pixel(x, y) != img.get_pixel(img.get_width() - 1 - x, y):
					mirrored = false
					break
			if not mirrored:
				break
		t.ok(mirrored, "%s 왼쪽 절반과 오른쪽 절반이 완전히 좌우 대칭이다 (이음매 없이 타일링된다)" % name)


# ══════════════════════════════════════════════════════════════════
#  set_backdrop / setup — the node actually stores what it is given
# ══════════════════════════════════════════════════════════════════

## **`setup()` wires the farm pair by default** (stage 1, `background.md`) — swap in the town pair by accident
## and this goes red. `resource_path` is compared, not the `Texture2D` reference — `load()` caches by path, so
## a reference-equality check would pass even if `set_backdrop`'s own internals silently substituted a
## different-but-cached resource; the path is the one thing that actually says "this is the file that was asked for".
func _setup_wires_the_farm_picture_by_default(t) -> void:
	var bg := SkyBackground.new()
	var cam := Camera2D.new()
	bg.setup(cam)
	var far: Texture2D = bg.get("_far")
	t.ok(far != null, "setup() 뒤에 원경이 실렸다 (전제)")
	if far != null:
		t.eq(far.resource_path, Fx.BG_FAR_TEXTURE, "setup()이 기본으로 농장 원경을 쓴다")
	t.ok(not bg.get_property_list().any(func(d): return d["name"] == "_near"),
		"근경 필드 자체가 사라졌다 (레이어를 끈 게 아니라 지웠다)")
	bg.free()
	cam.free()


## **`set_backdrop()` actually stores what it is given, driven directly** — handing it the town pair (not the
## default farm picture `setup()` always passes) and reading `_far` back is what would catch `set_backdrop`
## storing something other than what it was handed — testing `setup()`'s own hardcoded call alone could
## never distinguish that.
func _set_backdrop_stores_the_picture_it_is_given(t) -> void:
	var bg := SkyBackground.new()
	bg.set_backdrop(Fx.BG_TOWN_FAR_TEXTURE)
	var far: Texture2D = bg.get("_far")
	t.ok(far != null, "set_backdrop() 뒤에 원경이 실렸다 (전제)")
	if far != null:
		t.eq(far.resource_path, Fx.BG_TOWN_FAR_TEXTURE, "준 그림이 그대로 들어간다")
	bg.free()


# ══════════════════════════════════════════════════════════════════
#  Parallax — far and near must actually differ, or there is no parallax at all
# ══════════════════════════════════════════════════════════════════

## **Pinned by value, not only compared against each other** — an A/B comparison catches "diverged", never
## "both vanished" (CLAUDE.md: fold two paths into one and `scan == scan`, all green).
func _far_parallax_ratios_are_pinned(t) -> void:
	t.eq(Fx.BG_FAR_SCROLL_X, 0.25, "원경 가로 시차 비율이 고정값이다 (0.25)")
	t.eq(Fx.BG_FAR_SCROLL_Y, 0.08, "원경 세로 시차 비율이 고정값이다 (0.08)")
	t.ok(Fx.BG_FAR_SCROLL_Y < Fx.BG_FAR_SCROLL_X,
		"세로가 가로보다 약하다 — 한 번 떨어지는 사이에 그림이 화면을 벗어나지 않는 이유다")


## **`_layer_y()` is the function that actually consumes the ratio, driven directly on an untreed node** — the
## same technique proved for `_can_pick`/`_set_loadout`/`_revoke_unowned_rune`. Pinning the constants above
## cannot catch `_draw()` reading the wrong one for a given layer; this at least proves the math itself
## responds differently to the two ratios it is handed, with the formula's own two extremes checked too
## (ratio 1 = nailed to the anchor, ratio 0 = glued to the screen top).
func _layer_y_actually_responds_to_the_ratio(t) -> void:
	var bg := SkyBackground.new()
	var screen_top := 1000.0
	var a_y: float = bg.call("_layer_y", screen_top, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y)
	var b_y: float = bg.call("_layer_y", screen_top, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y * 2.0)
	t.ok(a_y != b_y,
		"같은 화면 위치·같은 기준점이어도 비율이 다르면 다른 y가 나온다 (%.2f vs %.2f)" % [a_y, b_y])
	t.eq(bg.call("_layer_y", screen_top, 500.0, 1.0), 500.0,
		"비율이 1이면 기준점에 완전히 고정된다 (공식 자체의 전제)")
	t.eq(bg.call("_layer_y", screen_top, 500.0, 0.0), screen_top,
		"비율이 0이면 화면 위쪽 끝에 완전히 붙는다 (공식 자체의 전제)")
	bg.free()


## **The horizon — `background.md`'s own words: "verify the horizon offset the first time it runs".** Not yet
## run and looked at — this pins today's value so a future change is visible, and is not an assertion that
## 300 is correct. (`background.md` calls this "`BG_Y_OFFSET`"; the actual constant is `BG_FAR_ANCHOR_Y` —
## the file has no `BG_Y_OFFSET`. Named here so the mismatch is on record, not silently worked around.)
func _horizon_anchor_is_pinned_by_value(t) -> void:
	t.eq(Fx.BG_FAR_ANCHOR_Y, 300.0,
		"수평선 위치(BG_FAR_ANCHOR_Y)가 300이다 — 화면에서 아직 확인되지 않은 값이고, 바뀌면 여기가 먼저 움직인다")


## **`BG_VERTICAL_FOLLOW_FRAC` is pinned and, more importantly, driven** — pinning the constant alone would
## stay green even if `_far_y`/`_draw` forgot to multiply by it (the exact "declared but unused" shape
## CLAUDE.md's own "no fake nets" section warns about).
##
## **The quantity that matters is on-screen displacement, not distance from the world anchor.**
## `_layer_y(screen_top, anchor, ratio) - screen_top` — the layer's position *relative to the screen*,
## i.e. what the eye reads as "did it move when the camera moved" — reduces algebraically to
## `ratio * (anchor - screen_top)`. The anchor cancels out of a *comparison between two camera positions*
## entirely, so the same camera move at a smaller ratio must produce a strictly smaller on-screen shift,
## independent of where the anchor sits. **That is "follows less."** A first version of this check compared
## `abs(y - anchor)` instead (distance from the anchor) and a real run caught it backwards — at screen_top
## 200 the damped ratio landed *farther* from `BG_FAR_ANCHOR_Y` than the raw one, because a smaller ratio
## pulls the result toward `screen_top`, not toward the anchor. Direction only makes sense measured on
## screen, never against the anchor.
func _vertical_follow_frac_actually_damps_the_far_layer(t) -> void:
	t.ok(Fx.BG_VERTICAL_FOLLOW_FRAC >= 0.0 and Fx.BG_VERTICAL_FOLLOW_FRAC <= 1.0,
		"세로 시차 감쇠 계수가 0..1 사이다 (0=화면에서 전혀 안 움직인다, 1=오늘 비율 그대로 움직인다)")
	if Fx.BG_VERTICAL_FOLLOW_FRAC >= 1.0:
		return

	var bg := SkyBackground.new()
	# **Both under the ground-line clamp (`BG_UNDER_TOP_Y - fh` = 96).** A first version used 200/500 and
	#  caught itself: at those depths the damped ratio's pre-clamp value already exceeds 96, so `_far_y`
	#  returns the *same* clamped 96 at both points and the "shift" measured is really the clamp's own
	#  constant output minus a moving `screen_top` — 300 vs the raw path's unclamped 24, backwards from
	#  what the check means to prove. 0/80 keeps every pre-clamp value on this test below 96 for both the
	#  damped and the raw ratio, so the comparison actually isolates the ratio.
	var top_a := 0.0
	var top_b := 80.0
	var fh := 544.0

	# **Far layer, through the real `_far_y()`.** Below the clamp threshold at both points (see above),
	#  so the comparison measures the ratio, not the clamp.
	var far_a: float = (bg.call("_far_y", top_a, fh) as float) - top_a
	var far_b: float = (bg.call("_far_y", top_b, fh) as float) - top_b
	var far_damped_shift := absf(far_a - far_b)
	var far_raw_a: float = (bg.call("_layer_y", top_a, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y) as float) - top_a
	var far_raw_b: float = (bg.call("_layer_y", top_b, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y) as float) - top_b
	var far_raw_shift := absf(far_raw_a - far_raw_b)
	t.ok(far_damped_shift < far_raw_shift,
		"같은 카메라 이동에 대해 원경이 화면에서 실제로 덜 움직인다 (감쇠 %.2f vs 원래 %.2f)" % [far_damped_shift, far_raw_shift])

	bg.free()


# ══════════════════════════════════════════════════════════════════
#  The three-piece contract (`background.md`) — "drop one and nothing shows, silently"
# ══════════════════════════════════════════════════════════════════

## **Piece 2 — `cell_renderer` derives `empty_id` from `Mat.EMPTY`, driven, not read as text.**
## `net_render._injection_matches_shader` already proves every uniform this shader declares has a matching
## injector by *name*, generically, across the whole file — it cannot see the injected *value*. This calls
## the real `setup()` on an untreed `CellRenderer` and reads the live `ShaderMaterial` back.
func _cell_renderer_derives_empty_id_from_the_material_table(t) -> void:
	var grid := CellGrid.new()
	var renderer := CellRenderer.new()
	renderer.setup(grid)
	var mat := renderer.material as ShaderMaterial
	t.ok(mat != null, "렌더러가 셰이더 머티리얼을 만들었다 (전제)")
	if mat == null:
		renderer.free()
		return
	t.eq(mat.get_shader_parameter("empty_id"), Mat.EMPTY,
		"empty_id 유니폼 값이 Mat.EMPTY에서 나온 값과 같다 (%d)" % Mat.EMPTY)
	renderer.free()


## **Piece 1 — the shader's own fragment logic. This is the one place that truly resists driving headless**
## (no GPU render pass) — a text scan, named honestly as one here, not dressed up as an execution check.
## **Narrow, not "contains `empty_id` somewhere"** — the exact comparison and the exact write into alpha, so a
## decoy mention of `empty_id` elsewhere in the file cannot satisfy it (the same evasion this repo has already
## measured against text scans generally — CLAUDE.md's own list).
func _shader_zeroes_alpha_on_the_empty_material(t) -> void:
	var f := FileAccess.open(SHADER_PATH, FileAccess.READ)
	t.ok(f != null, "셰이더 원본을 읽었다 (전제)")
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	# `.gdshader` is C-style (`//`), not GDScript (`#`) — `NetDeterminism._strip` does not recognize `//` and
	#  would leave a decoy comment intact (measured: `// float a = (mat_id == empty_id) ? 0.0 : 1.0;` alone
	#  would still satisfy a bare `.contains()`, the exact evasion CLAUDE.md already names). A separate,
	#  minimal stripper for exactly this one comment style — not a second copy of the shared one, a different
	#  language's comment syntax.
	var src := _strip_shader_line_comments(raw)
	t.ok(src.contains("uniform int empty_id;"), "empty_id 유니폼이 선언돼 있다")
	t.ok(src.contains("(mat_id == empty_id) ? 0.0 : 1.0"),
		"빈 칸의 material id가 empty_id와 같으면 alpha를 0으로 만드는 식이 살아 있는 코드로 그대로 있다")
	t.ok(src.contains("c.a *= a;"),
		"그 alpha가 실제로 COLOR에 곱해져 들어간다 (계산만 하고 안 쓰는 값이 아니다)")


## `.gdshader` comments are C-style (`//` to end of line) — no block comments (`/* */`) exist in this file
## today, so only line comments are handled. Quoted strings are not stripped either (this shader has none).
static func _strip_shader_line_comments(src: String) -> String:
	var out := ""
	for raw: String in src.split("\n"):
		var idx := raw.find("//")
		out += (raw if idx < 0 else raw.substr(0, idx)) + "\n"
	return out


## **Piece 3 — scene order is draw order, driven through the real node tree, not the raw `.tscn` text.**
## `PackedScene.instantiate()` builds the real parent/child structure in memory without adding it to the live
## tree (`net_render._wired_stage_root`'s own established discipline) — `get_index()` on the result reflects
## true sibling order, which is exactly what 2D drawing order follows within one parent.
func _sky_background_sits_before_cell_renderer_in_the_scene(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 읽었다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	var sky := root.get_node_or_null("SkyBackground")
	var cell := root.get_node_or_null("CellRenderer")
	t.ok(sky != null and cell != null, "SkyBackground와 CellRenderer가 씬에 있다 (전제)")
	if sky != null and cell != null:
		t.eq(sky.get_parent(), cell.get_parent(), "둘이 같은 부모 밑 형제다 (전제 — 형제 순서가 곧 그리기 순서다)")
		t.ok(sky.get_index() < cell.get_index(),
			"SkyBackground가 CellRenderer보다 형제 인덱스가 앞선다 (%d < %d — 배경이 먼저, 그리드가 나중에 그려진다)" % [
				sky.get_index(), cell.get_index()])
	root.free()


## **The path to the screen.** The wiring and the color could both be correct and still put nothing on
## screen if nobody ever calls the door — CLAUDE.md's own named failure ("water material and color were both
## in, but nothing called `set_water`, so not one cell of water appeared").
func _ready_actually_calls_setup(t) -> void:
	var f := FileAccess.open(STAGE_SCRIPT, FileAccess.READ)
	t.ok(f != null, "stage.gd를 읽었다 (전제)")
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	# **Comments and strings are stripped first** — `pass # _sky.setup(_camera)` (the call commented out, dead)
	#  still contains the literal text and would satisfy a bare `.contains()` (measured: exactly this mutation
	#  passed before this file used the stripper). `NetDeterminism._strip` is GDScript-aware (`#`, not `//`),
	#  the correct one for this file.
	var src := NetDeterminism._strip(raw)
	t.ok(src.contains("_sky.setup(_camera)"), "_ready()가 배경의 setup()을 실제로 부른다 (주석이 아니라 실행되는 줄에서)")


# ══════════════════════════════════════════════════════════════════
#  Underground depth (`docs/design/underground-depth.md`, options ①·②) — the far picture stops
#  following the camera at the ground line, and both the screen-side bands and the shader-side dim are
#  derived from the map's real floor, not from `CellGrid.H` (the doc's own measured trap: 62% of the
#  grid's height is off the bottom of the drawn map, so a ramp tuned against `CellGrid.H` lands at a
#  third of what it was tuned for).
# ══════════════════════════════════════════════════════════════════

## **Pinned by value, not only "derived != 0"** — the same reasoning `_far_and_near_use_different_
## parallax_ratios` already gives: an A/B or a bare existence check catches "diverged" or "missing",
## never "computed but wrong". `BG_UNDER_BOTTOM_Y`/`CELL_DEPTH_SPAN` are derived expressions
## (`TerrainMap.MAP_H` x `TILE_CELLS` x `CELL_PX`, and that same product over `CellGrid.H`) — pinning
## the *result* here means a wrong multiplier or a swapped operand still shows up as a moved number.
func _underground_depth_constants_are_pinned(t) -> void:
	t.eq(Fx.BG_UNDER_TOP_Y, Fx.BG_NEAR_GROUND_Y,
		"지하 채움의 위쪽 경계가 지면선과 같다 (땅이 어디인지를 두 번째로 정의하지 않는다)")
	t.eq(Fx.BG_UNDER_BOTTOM_Y, 1536.0,
		"지하 채움의 바닥이 맵의 실제 바닥이다 (48 x 8 x 4 = 1536 — `CellGrid.H` 1008이 아니다)")
	t.eq(Fx.BG_UNDER_BANDS.size(), 4, "지하 밴드가 4단이다")
	t.eq(Fx.CELL_DEPTH_SPAN, 384.0 / 1008.0,
		"셰이더 depth_span이 그리드 전체(1008)가 아니라 맵의 실제 바닥(384칸)에서 나온 값이다")
	t.eq(Fx.CELL_DEEP_DIM, 0.6, "셰이더 depth 최대 어둡기 배율이 고정값이다")


## **The clamp actually presses the value down, driven directly** — `_far_y()` was pulled out of
## `_draw()` exactly so this could call it without a scene tree. Two things are measured, both required:
## near the surface the clamp must be a no-op (else the horizon itself would look wrong), and deep
## underground it must actually differ from the unclamped formula (an A/B against itself would pass even
## if the clamp line were deleted entirely — comparing against the *unclamped* `_layer_y()` call is what
## proves the clamp did something, not merely that it exists in source).
func _far_picture_stops_at_the_ground_line(t) -> void:
	var bg := SkyBackground.new()
	var fh := 544.0

	# `_far_y()` damps the ratio by `BG_VERTICAL_FOLLOW_FRAC` before calling `_layer_y()` — the comparison
	#  has to apply the same damping, or this reads a divergence that was never a clamp at all.
	var shallow := bg.call("_far_y", 0.0, fh) as float
	var shallow_unclamped := bg.call(
		"_layer_y", 0.0, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y * Fx.BG_VERTICAL_FOLLOW_FRAC) as float
	t.eq(shallow, shallow_unclamped, "지면 근처에서는 clamp가 원래 계산값을 안 건드린다 (전제)")

	# The doc's own measured example (`background.md`'s original, undamped 944) is kept as a bare `_layer_y`
	#  reference of the formula itself — the raw ratio, not production's damped one — so it stays a fixed
	#  algebra check independent of wherever `BG_VERTICAL_FOLLOW_FRAC` is tuned to.
	var deep_unclamped := bg.call("_layer_y", 1000.0, Fx.BG_FAR_ANCHOR_Y, Fx.BG_FAR_SCROLL_Y) as float
	t.eq(deep_unclamped, 944.0, "clamp 없는 계산값(원래 비율 기준)이 문서가 측정한 값과 같다 (944 — 이 검사의 전제)")

	var deep := bg.call("_far_y", 1000.0, fh) as float
	t.ok(deep + fh <= Fx.BG_UNDER_TOP_Y + 0.001,
		"깊은 곳에서는 원경 그림의 아랫변이 지면선을 절대 못 넘는다 (%.1f <= %.1f)" % [deep + fh, Fx.BG_UNDER_TOP_Y])
	t.ok(deep < deep_unclamped,
		"clamp가 실제로 원래 계산값보다 작게 눌렀다 (줄이 지워지면 이 줄이 먼저 빨개진다)")
	bg.free()


## **The band split, driven directly (`_band_segments()` is pure geometry, no `draw_rect`).** Measures
## exactly what the team asked after the first pass: "does the count actually drawn equal
## `Fx.BG_UNDER_BANDS`", not just "does it run". Coverage, order and no-gap/no-overlap are all checked —
## an off-by-one or a rounding skip in the split would show up as a missing or duplicated index here.
func _depth_fill_bands_cover_the_whole_range_in_order(t) -> void:
	var bg := SkyBackground.new()
	var n := Fx.BG_UNDER_BANDS.size()

	var segs: Array = bg.call("_band_segments", Fx.BG_UNDER_TOP_Y, Fx.BG_UNDER_BOTTOM_Y)
	t.eq(segs.size(), n,
		"지면선에서 맵 바닥까지 정확히 %d개 조각이 나온다 (밴드 하나도 안 건너뛴다)" % n)
	for i in segs.size():
		var seg: Array = segs[i]
		t.eq(int(seg[2]), i, "%d번째 조각이 %d번 밴드 색을 쓴다 (순서대로다)" % [i, i])
	for i in range(1, segs.size()):
		t.eq(segs[i][0], segs[i - 1][1],
			"%d번째와 %d번째 조각 사이에 틈도 겹침도 없다" % [i - 1, i])
	if segs.size() > 0:
		t.eq(segs[0][0], Fx.BG_UNDER_TOP_Y, "첫 조각이 지면선에서 시작한다")
		t.eq(segs[segs.size() - 1][1], Fx.BG_UNDER_BOTTOM_Y, "마지막 조각이 맵 바닥에서 끝난다")

	# Past the map's floor — 62% of the grid's height with nothing drawn on it — the last band must
	#  keep flooding the screen, not stop dead at the floor and leave the rest transparent.
	var tail: Array = bg.call("_band_segments", Fx.BG_UNDER_BOTTOM_Y - 10.0, Fx.BG_UNDER_BOTTOM_Y + 500.0)
	t.ok(tail.size() > 0, "맵 바닥 너머 구간에서도 조각이 나온다 (전제)")
	if tail.size() > 0:
		var last: Array = tail[tail.size() - 1]
		t.eq(int(last[2]), n - 1, "맵 바닥 너머는 마지막 밴드 색이 계속 채운다")
		t.eq(last[1], Fx.BG_UNDER_BOTTOM_Y + 500.0, "그 조각이 화면 끝까지 끊기지 않고 이어진다")
	bg.free()


## **Piece 2's sibling for the depth uniforms — `net_render._injection_matches_shader` already proves the
## *names* `depth_span`/`deep_dim` pair up between the shader and `cell_renderer.gd`; it cannot see the
## injected *value*.** Same technique as `_cell_renderer_derives_empty_id_from_the_material_table` above:
## real `setup()` on an untreed `CellRenderer`, real `ShaderMaterial` read back.
func _cell_renderer_derives_depth_uniforms_from_fx_tuning(t) -> void:
	var grid := CellGrid.new()
	var renderer := CellRenderer.new()
	renderer.setup(grid)
	var mat := renderer.material as ShaderMaterial
	t.ok(mat != null, "렌더러가 셰이더 머티리얼을 만들었다 (전제)")
	if mat == null:
		renderer.free()
		return
	t.eq(mat.get_shader_parameter("depth_span"), Fx.CELL_DEPTH_SPAN,
		"depth_span 유니폼 값이 Fx.CELL_DEPTH_SPAN과 같다 (%.4f)" % Fx.CELL_DEPTH_SPAN)
	t.eq(mat.get_shader_parameter("deep_dim"), Fx.CELL_DEEP_DIM,
		"deep_dim 유니폼 값이 Fx.CELL_DEEP_DIM과 같다 (%.2f)" % Fx.CELL_DEEP_DIM)
	renderer.free()


## **Piece 1's sibling — the shader's own fragment logic, the one place that truly resists driving
## headless (no GPU render pass).** A text scan, named honestly as one, narrow enough that a decoy
## mention elsewhere in the file cannot satisfy it (the same discipline
## `_shader_zeroes_alpha_on_the_empty_material` above already follows).
##
## **Ordering, not just presence.** `sky_background.gd`'s and `cell_grid.gdshader`'s own comments both
## claim fire and shallow water are deliberately *not* dimmed by depth — that claim is only true if the
## dim line runs before both branches that overwrite `c` wholesale. This measures the order, not the words.
func _shader_applies_depth_dim_before_fire_and_water_overwrite_c(t) -> void:
	var f := FileAccess.open(SHADER_PATH, FileAccess.READ)
	t.ok(f != null, "셰이더 원본을 읽었다 (전제)")
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var src := _strip_shader_line_comments(raw)

	t.ok(src.contains("uniform float depth_span;"), "depth_span 유니폼이 선언돼 있다")
	t.ok(src.contains("uniform float deep_dim;"), "deep_dim 유니폼이 선언돼 있다")
	t.ok(src.contains("c.rgb *= mix(1.0, deep_dim, depth);"),
		"깊이 어둡기가 실제로 c에 곱해져 들어간다 (계산만 하고 안 쓰는 값이 아니다)")

	var dim_at := src.find("c.rgb *= mix(1.0, deep_dim, depth);")
	var shallow_at := src.find("c = water_shallow;")
	var fire_at := src.find("c = mix(fire_lo, fire_hi,")
	t.ok(dim_at >= 0 and shallow_at >= 0 and fire_at >= 0, "세 줄을 다 셰이더에서 찾았다 (전제)")
	if dim_at >= 0 and shallow_at >= 0 and fire_at >= 0:
		t.ok(dim_at < shallow_at,
			"깊이 어둡기 줄이 얕은 물 분기보다 먼저 온다 (물이 깊이로 안 어두워진다)")
		t.ok(dim_at < fire_at,
			"깊이 어둡기 줄이 불 분기보다 먼저 온다 (불이 깊이로 안 어두워진다)")
