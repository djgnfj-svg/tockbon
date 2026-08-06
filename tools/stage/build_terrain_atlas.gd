extends SceneTree
## 붓 그림(`assets/stage/terrain_tiles.png`)을 **재료 표에서 굽는다.** 재료가 늘 때만 돌린다.
##
## 실행: Godot_v4.7.1-stable_win64.exe --headless --script tools/stage/build_terrain_atlas.gd
##
## 🔴🔴 **왜 생겼나.** 이 png 는 2026-08-07까지 **손으로 색을 맞춘 것**이었다.
##  `docs/design/지형-굽기.md` 가 그 대가를 적어 뒀다 — 재료 색을 바꾸면 **에디터 붓 색만 조용히
##  낡고**, 게임 화면은 안 틀리므로 **아무도 눈치 못 챈다.** 붓을 집을 때만 헷갈린다.
##  ⇒ 이제 `cell_materials.DEFS` 의 `rgb` 에서 파생된다. **손으로 맞출 것이 없다.**
##
## ⚠ **이건 게임 그래픽이 아니라 에디터에서 보이는 견본이다.** 실제 화면은 셀 격자가 그리고
##  색은 같은 `rgb` 에서 나온다 — 그래서 **둘이 저절로 같다**(전에는 저절로가 아니었다).
##
## 🔴 **납작한 단색이다. 무늬를 넣지 마라** — 무늬를 넣는 순간 그건 「견본」이 아니라 아트가 되고,
##  에디터에서 본 것과 게임에서 보는 것이 달라진다. 지금은 **붓 색 = 그 재료의 실제 색**이다.
##
## ⚠ **돌린 뒤 에디터가 다시 임포트해야 붓에 보인다**(`.png.import`). 에디터가 켜져 있으면
##  창에 포커스가 갈 때 자동으로 한다 — 안 보이면 그것부터 의심해라.

const Mat := preload("res://src/sim/cell_materials.gd")
const Palette := preload("res://tools/stage/terrain_palette.gd")

const OUT_PATH := "res://assets/stage/terrain_tiles.png"


func _init() -> void:
	var ids := Palette.paintable()
	if ids.is_empty():
		push_error("[build_terrain_atlas] 그릴 수 있는 재료가 하나도 없다")
		quit(1)
		return

	var px := Palette.tile_px()
	var img := Image.create(px * ids.size(), px, false, Image.FORMAT_RGB8)

	var names := PackedStringArray()
	for i in ids.size():
		var id: int = ids[i]
		var rgb := Mat.rgb_of(id)
		# 🔴 `Color8` 로 채운다 — `cell_renderer._rgb_to_color` 와 **같은 변환**이어야
		#  붓 색과 화면 색이 같다. 여기서 255로 직접 나누면 그 둘이 미묘하게 갈린다.
		var c := Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
		var at := Palette.atlas_of(i)
		img.fill_rect(Rect2i(at.x * px, at.y * px, px, px), c)
		names.append("%s(%d)=#%06X" % [Mat.material_name(id), id, rgb])

	# ⚠ `res://` 는 읽기 전용 경로가 아니다(에디터/툴 실행) — 그래도 절대 경로로 바꿔 저장한다.
	var err := img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		push_error("[build_terrain_atlas] png 저장 실패 — 에러 코드 %d" % err)
		quit(1)
		return

	print("[build_terrain_atlas] 저장됨: %s (%d×%dpx, 칸 %d개)" % [
		OUT_PATH, px * ids.size(), px, ids.size()])
	print("  " + ", ".join(names))
	print("  ⚠ 이어서 `build_terrain_tileset.gd` 도 돌려라 — 타일셋이 칸 수를 따라와야 한다.")
	quit(0)
