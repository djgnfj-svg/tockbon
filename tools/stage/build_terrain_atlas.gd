extends SceneTree
## **Bakes the brush image (`assets/stage/terrain_tiles.png`) from the material table.** Run only when a material is added.
##
## Run: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_atlas.gd
##
## **Why it exists.** This png used to be **hand-matched by color**.
##  `docs/design/terrain-baking.md` recorded the price — change a material color and **only the editor brush color
##  goes stale silently**, and since the game screen is not wrong, **nobody notices.** It only confuses you when picking a brush.
##  => It is now derived from `rgb` in `cell_materials.DEFS`. **There is nothing left to hand-match.**
##
## **This is not game graphics; it is the swatch visible in the editor.** The real screen is drawn by the cell grid
##  and its colors come from the same `rgb` — so **the two are the same by construction** (they were not, before).
##
## **Flat solid color. Do not put a pattern in it** — the moment you do, it stops being a "swatch" and becomes art,
##  and what you see in the editor differs from what you see in the game. Right now **brush color = that material's real color.**
##
## **After running it, the editor must re-import before it shows in the brush** (`.png.import`). If the editor is open
##  it does so automatically when the window takes focus — if it isn't showing, suspect that first.

const Mat := preload("res://src/sim/cell_materials.gd")
const Palette := preload("res://tools/stage/terrain_palette.gd")

const OUT_PATH := "res://assets/stage/terrain_tiles.png"


func _init() -> void:
	var ids := Palette.paintable()
	if ids.is_empty():
		push_error("[build_terrain_atlas] not one material can be drawn")
		quit(1)
		return

	var px := Palette.tile_px()
	var img := Image.create(px * ids.size(), px, false, Image.FORMAT_RGB8)

	var names := PackedStringArray()
	for i in ids.size():
		var id: int = ids[i]
		var rgb := Mat.rgb_of(id)
		# Fill with `Color8` — it must be **the same conversion** as `cell_renderer._rgb_to_color`
		#  for the brush color and the screen color to match. Dividing by 255 directly here makes the two subtly diverge.
		var c := Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
		var at := Palette.atlas_of(i)
		img.fill_rect(Rect2i(at.x * px, at.y * px, px, px), c)
		names.append("%s(%d)=#%06X" % [Mat.material_name(id), id, rgb])

	# `res://` is not a read-only path (editor/tool runs) — even so, save via an absolute path.
	var err := img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		push_error("[build_terrain_atlas] png save failed - error code %d" % err)
		quit(1)
		return

	print("[build_terrain_atlas] 저장됨: %s (%d×%dpx, 칸 %d개)" % [
		OUT_PATH, px * ids.size(), px, ids.size()])
	print("  " + ", ".join(names))
	print("  이어서 `build_terrain_tileset.gd` 도 돌려라 — 타일셋이 칸 수를 따라와야 한다.")
	quit(0)
