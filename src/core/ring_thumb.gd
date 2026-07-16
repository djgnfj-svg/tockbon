extends Control
## 고리 도안 썸네일 (core·리드 소유) — RingDesign(진 원 + 룬 중심 + 8칸 문양)을 작은 사각형에
## 그린다. 옛 SpellDesign을 그리는 DesignThumb의 고리 모델판 (#17 2단계).
## HUD 하단 슬롯·장착 화면이 "조립한 그 마법진"을 이름표가 아니라 그림으로 고른다.
##
## 🔴 색·기하는 조립 보드(ring_board.gd)와 **같은 값**을 쓴다 — 책↔캔버스 mismatch(메모리
## takbon-no-per-stroke-verify)를 되풀이하지 않으려면 만드는 판과 보는 썸네일이 같은 그림이어야 한다.
##
## 사용: const RingThumb := preload("res://src/core/ring_thumb.gd")

const SLOTS := 8
const GLYPH_NONE := -1
const G_GATHER := 0    # 응집 ← (안쪽 화살표)
const G_RADIATE := 1   # 발산 → (바깥 화살표)

# ── 색 (ring_board.gd와 동일) ──
const RING_LINE := Color(0.42, 0.30, 0.12, 0.72)
const RUNE_COLOR := Color(0.62, 0.22, 0.12)          # 불
const SLOT_OPEN := Color(0.42, 0.30, 0.12, 0.35)     # 열린 빈 칸
const GLYPH_COLORS := [
	Color(0.16, 0.34, 0.55),   # 응집 = 남색
	Color(0.72, 0.28, 0.12),   # 발산 = 주홍
]

## 진 경계 원의 반지름 (위젯 절반의 이 비율)
const BOUNDARY_FRAC := 0.86
## 문양 칸이 앉는 반지름 (경계 반지름의 이 비율 — ring_board.RING_RADIUS_FRAC와 맞춤)
const RING_RADIUS_FRAC := 0.60
const RUNE_DOT_FRAC := 0.14   # 룬 중심점 크기 (경계 반지름 대비)
const TICK_FRAC := 0.16       # 문양 화살표 길이 (경계 반지름 대비)

## 표시 중인 도안 (null = 빈 슬롯 — 아무것도 그리지 않는다)
var design: RingDesign = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## 표시할 도안 지정 (null이면 비운다). 같은 도안이어도 다시 그린다 — 캐시 판단은 호출부 몫
func set_design(d: RingDesign) -> void:
	design = d
	queue_redraw()


func _draw() -> void:
	if design == null:
		return
	var center := size * 0.5
	var boundary := minf(size.x, size.y) * 0.5 * BOUNDARY_FRAC
	if boundary <= 1.0:
		return

	# 진 = 바깥 그릇(경계 원)
	draw_arc(center, boundary, 0.0, TAU, 40, RING_LINE, maxf(1.0, boundary * 0.06), true)

	# 룬 = 중심점 (지금은 불만)
	draw_circle(center, boundary * RUNE_DOT_FRAC, RUNE_COLOR)

	# 문양 = 룬과 진 사이 8칸. 슬롯 0 = 위(-90°), 시계방향.
	var ring: Array = design.rings[0] if not design.rings.is_empty() else []
	var slot_r := boundary * RING_RADIUS_FRAC
	var tick := boundary * TICK_FRAC
	for k in SLOTS:
		var ang := -PI * 0.5 + float(k) * TAU / float(SLOTS)
		var dir := Vector2(cos(ang), sin(ang))
		var pos := center + dir * slot_r
		var code := int(ring[k]) if k < ring.size() else GLYPH_NONE
		if code == GLYPH_NONE:
			# 열린 빈 칸만 옅은 점으로 (닫힌 칸은 아무것도 안 그린다)
			if design.open.has(k):
				draw_circle(pos, maxf(1.0, tick * 0.28), SLOT_OPEN)
			continue
		var col: Color = GLYPH_COLORS[code] if code < GLYPH_COLORS.size() else RING_LINE
		# 응집=안쪽(룬)으로, 발산=바깥(진)으로 향하는 짧은 화살표
		var toward := -dir if code == G_GATHER else dir
		var tail := pos - toward * tick * 0.5
		var head := pos + toward * tick * 0.5
		var w := maxf(1.0, boundary * 0.06)
		draw_line(tail, head, col, w, true)
		# 화살촉 — head 양쪽으로 짧게
		var perp := toward.orthogonal()
		var barb := tick * 0.4
		draw_line(head, head - toward * barb + perp * barb * 0.6, col, w, true)
		draw_line(head, head - toward * barb - perp * barb * 0.6, col, w, true)
