extends Node2D
## 배경 — 격자 뒤의 밤하늘. 개념은 `docs/design/배경.md` 가 기준이다.
##
## 🔴🔴 **이 노드만으로는 한 픽셀도 안 보인다.** 격자 스프라이트(`CellRenderer`)가 월드 전체를
##  불투명하게 덮고 있어서, `cell_grid.gdshader` 의 `empty_id` 로 **빈칸을 투명으로 빼야** 비로소 보인다.
##  ⚠ 그 둘은 한 짝이다 — 셰이더 쪽을 되돌리면 여기는 조용히 죽는다(에러 없음).
##
## 🔴 **`stage.tscn` 에서 `CellRenderer` 보다 먼저(위에) 있어야 한다.** 씬 순서가 곧 그리는 순서다.
##
## 🔴🔴 **왜 그림이 아니라 코드인가**: 월드가 16,384 × 4,032px 이라 한 장으로 못 덮는다
##  (`배경.md` 「크기 — 통짜로는 못 그린다」). 그림 후보가 정해지기 전에도 **「배경이 화면에 도달하는
##  경로」는 먼저 서 있어야 한다** — 안 그러면 그림을 아무리 잘 뽑아도 안 나오고,
##  이 리포가 그 사고를 물에서 이미 한 번 겪었다(CLAUDE.md 「볼 것이 화면에 도달하는 경로가 있나」).
##
## ⚠ **지금은 단색 그라데이션 + 별이다.** 그림이 정해지면 이 파일이 그걸 까는 자리가 된다.

const Fx := preload("res://src/view/fx_tuning.gd")

## 🔴 카메라를 따라다니는 대신 **화면을 통째로 덮는 고정 레이어**다.
##  ⚠ 시차(parallax)를 넣으려면 층을 갈라야 하고 그건 그림이 정해진 뒤의 일이다(`배경.md`).
var _cam: Camera2D = null
var _view: Vector2 = Vector2.ZERO


func setup(cam: Camera2D) -> void:
	_cam = cam
	_view = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	z_index = Fx.BG_Z_INDEX


func _process(_dt: float) -> void:
	# 🔴 카메라가 움직이면 다시 그린다. 그리는 좌표가 카메라에 매여 있어서다.
	queue_redraw()


func _draw() -> void:
	if _cam == null:
		return

	# 🔴 카메라 중심에서 화면 크기만큼. **월드 전체를 덮지 않는다** —
	#  16,384 × 4,032px 을 매 프레임 그리면 화면 밖 99%가 낭비다.
	var half := _view * 0.5
	var origin := _cam.global_position - half
	var rect := Rect2(origin, _view)

	# 위는 어둡고 아래로 갈수록 살짝 밝은 밤하늘. 세로 그라데이션.
	# ⚠ **밤 팔레트를 강제하는 이유**: 무대 빈칸이 거의 검정이라 배경이 밝으면
	#  캐릭터·몬스터 실루엣이 전부 죽는다(`배경.md` 「밤 팔레트를 강제한다」).
	var steps := Fx.BG_GRADIENT_STEPS
	var band := _view.y / float(steps)
	for i in steps:
		var t := float(i) / float(steps - 1)
		var c := Fx.BG_TOP.lerp(Fx.BG_BOTTOM, t)
		draw_rect(Rect2(origin.x, origin.y + band * float(i), _view.x, band + 1.0), c)

	_draw_stars(rect)


## 별. 🔴 **월드 좌표에 고정된 격자에서 뽑는다** — 화면 좌표로 뽑으면 카메라가 움직일 때
##  별이 같이 따라와서 「창문에 붙은 점」으로 읽힌다.
## ⚠ `sin` 해시를 쓴다. **여기는 `src/view/` 라 float 계약이 아니다**(`src/sim/` 만 정수다).
func _draw_stars(rect: Rect2) -> void:
	var cell := Fx.BG_STAR_CELL_PX
	var x0 := floorf(rect.position.x / cell) * cell
	var y0 := floorf(rect.position.y / cell) * cell
	var nx := int(rect.size.x / cell) + 2
	var ny := int(rect.size.y / cell) + 2

	for iy in ny:
		for ix in nx:
			var gx := x0 + float(ix) * cell
			var gy := y0 + float(iy) * cell
			# 격자 칸마다 고정 난수 셋 — 있나 · 어디에 · 얼마나 밝나
			var h := _hash2(gx, gy)
			if h > Fx.BG_STAR_DENSITY:
				continue
			var ox := _hash2(gx + 17.0, gy) * cell
			var oy := _hash2(gx, gy + 31.0) * cell
			var a := Fx.BG_STAR_ALPHA_MIN + _hash2(gx + 7.0, gy + 7.0) * (
				Fx.BG_STAR_ALPHA_MAX - Fx.BG_STAR_ALPHA_MIN)
			var c := Fx.BG_STAR_COLOR
			c.a = a
			draw_rect(Rect2(gx + ox, gy + oy, Fx.BG_STAR_PX, Fx.BG_STAR_PX), c)


func _hash2(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
