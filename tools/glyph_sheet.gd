## 문양·룬 밑그림 시트 — 「모양을 고치려면 지금 뭐가 있는지부터 봐야 한다」.
##
## 왜: `RingBoard`의 밑그림은 점열을 **코드로 계산한다** — 열어볼 그림 파일이 없다.
##   그래서 "문양이 빈약하다"(BACKLOG R2)를 손보려 해도 **무엇을 고칠지 눈으로 못 본다.**
##   책을 열어 보려면 게임을 마을까지 몰고 가야 하는데(`ring_forge_panel.tscn`만 띄우면 패널이
##   닫힌 채라 **빈 화면**이다 — 실측), 이 도구는 그 static 함수를 직접 불러 격자로 그린다.
##
## 🔴 `--headless`를 쓰지 마라 — 렌더를 안 해서 빈 이미지가 나온다(`shot.gd`와 같은 이유).
## 🔴 `load()`로 지연 로드한다 — `-s` 스크립트의 `_init`은 오토로드 등록보다 먼저 돌아서
##   `preload`로 물면 그 스크립트가 참조하는 오토로드 식별자에서 컴파일 에러가 난다(세94 실측).
##
## 사용:
##   ... -s res://tools/glyph_sheet.gd -- <출력png> [glyph|rune]
extends SceneTree

const WAIT_FRAMES := 10

## 🔴 순서 = `Enums.GlyphCode` 값 순서(GATHER=0 … CONDENSE=8). 값이 0..8 연속이라 인덱스 = 코드다.
const GLYPH_NAMES: Array[String] = [
	"0 응집 GATHER", "1 발산 RADIATE", "2 관통 PIERCE",
	"3 유도 HOMING", "4 팅김 BOUNCE", "5 추진 THRUST",
	"6 확산 SPREAD", "7 폭발 EXPLODE", "8 응축 CONDENSE",
]

## ⚠ 🔴 **룬 값은 연속이 아니다** — `Enums.RuneType { FIRE=0, WATER=2, WIND=3, BOLT=4, EARTH=5, GRASS=6 }`
## (1은 옛 IMPACT 자리라 비어 있다). 인덱스로 순회하면 조용히 틀린 룬을 그린다.
const RUNE_CODES: Array[int] = [0, 2, 3, 4, 5, 6]
const RUNE_NAMES: Array[String] = [
	"0 불 FIRE", "2 물 WATER", "3 바람 WIND",
	"4 번개 BOLT", "5 흙 EARTH", "6 풀 GRASS",
]

var _out := ""
var _mode := "glyph"
var _frames := 0
var _shot := false
var _built := false


## 격자 한 장을 그리는 캔버스. `_draw` 안에서 판의 static 기하를 **그대로 부른다**
## (베끼면 「셀에서 본 모양 ≠ 손으로 그을 모양」이 갈라진다 — `ring_board.gd` 머리말의 그 규약).
class Sheet extends Node2D:
	var board: Object = null
	var names: Array[String] = []
	var codes: Array[int] = []
	var mode: String = "glyph"
	var cols: int = 3
	var rows: int = 3

	func _draw() -> void:
		var vp: Vector2 = get_viewport_rect().size
		var cw: float = vp.x / float(cols)
		var ch: float = vp.y / float(rows)
		# 종이색 배경 — 실제 판 배경과 같은 결로 둬야 선 굵기·대비가 화면과 비슷하게 읽힌다.
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.94, 0.90, 0.82))
		var font: Font = ThemeDB.fallback_font
		for i in names.size():
			var col: int = i % cols
			var row: int = i / cols
			var cell: Vector2 = Vector2(float(col) * cw, float(row) * ch)
			var ctr: Vector2 = cell + Vector2(cw, ch) * 0.5
			var sz: float = minf(cw, ch) * (0.22 if mode == "glyph" else 0.30)
			draw_rect(Rect2(cell, Vector2(cw, ch)), Color(0.60, 0.50, 0.35, 0.35), false, 2.0)
			var pts: PackedVector2Array = _path(codes[i], ctr, sz)
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.20, 0.14, 0.09), 3.0)
			# 실제 화면에서의 대략 크기 — 같은 모양을 작게 한 번 더(문양은 밴드에 아주 작게 깔린다).
			var small_ctr: Vector2 = cell + Vector2(cw * 0.86, ch * 0.20)
			var small: PackedVector2Array = _path(codes[i], small_ctr, sz * (0.28 if mode == "glyph" else 0.45))
			if small.size() >= 2:
				draw_polyline(small, Color(0.20, 0.14, 0.09, 0.75), 1.5)
			# 점 개수 — 「곡선을 넣으려면 점이 몇 개 드나」를 바로 보게 한다.
			draw_string(font, cell + Vector2(14.0, ch - 18.0),
				"%s   (%d점)" % [names[i], pts.size()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.30, 0.20, 0.10))
		var head := "문양 9종" if mode == "glyph" else "룬 6종"
		draw_string(font, Vector2(14.0, 26.0),
			"%s · 큰 것 = 확대 / 오른쪽 위 작은 것 = 실제 배치 크기 · 괄호 = 밑그림 점 개수" % head,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.35, 0.25, 0.12))

	## 🔴 모드마다 **다른 정본**을 부른다. 룬은 `rune_subpath`다 —
	## `rune_guide_verts`(꼭짓점만)를 직접 그리면 12등분 보간이 빠져 판과 다른 그림이 된다.
	func _path(code: int, at: Vector2, sz: float) -> PackedVector2Array:
		if mode == "rune":
			return board.rune_subpath(code, at, sz)
		return board.glyph_guide_pts(code, at, Vector2.UP, sz)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("[glyph_sheet] 인자: <출력png> [glyph|rune]")
		quit(1)
		return
	_out = args[0]
	if args.size() >= 2:
		_mode = args[1]


func _process(_delta: float) -> bool:
	if not _built:
		_built = true
		var board: Object = load("res://src/drawing/ring_board.gd")
		if board == null:
			push_error("[glyph_sheet] ring_board.gd 로드 실패")
			quit(1)
			return true
		var sheet := Sheet.new()
		sheet.board = board
		sheet.mode = _mode
		if _mode == "rune":
			sheet.names = RUNE_NAMES
			sheet.codes = RUNE_CODES
			sheet.cols = 3
			sheet.rows = 2
		else:
			sheet.names = GLYPH_NAMES
			sheet.codes = [0, 1, 2, 3, 4, 5, 6, 7, 8]
			sheet.cols = 3
			sheet.rows = 3
		root.add_child(sheet)
		return false
	if _shot:
		return true
	_frames += 1
	if _frames < WAIT_FRAMES:
		return false
	_shot = true
	# 🔴 그린 직후에 읽어야 한다 — 이 시그널 없이 읽으면 한 프레임 전(또는 빈) 화면이 나온다.
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)
	return false


func _grab() -> void:
	var img := root.get_texture().get_image()
	var e := img.save_png(_out)
	if e != OK:
		push_error("[glyph_sheet] 저장 실패 %s (err %d)" % [_out, e])
	else:
		print("[glyph_sheet] saved %s  %dx%d" % [_out, img.get_width(), img.get_height()])
	quit(0 if e == OK else 1)
