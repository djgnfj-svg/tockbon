extends Control
## 도안 썸네일 (core·리드 소유) — SpellDesign.strokes(플레이어가 밤에 그린 원본 획)를
## 먹선으로 그려 주어진 사각형 안에 맞춰 넣는다. "어제 그린 그 도안"을 이름표가 아니라 그림으로 고른다.
## 도안을 보여 주는 **단일 지점** — UI(장착·HUD)·거점(작업대 수리·장착)이 전부 이 위젯을 쓴다
## (모듈 간 직접 preload 금지 규칙 때문에 core에 있다 — TECH_SPEC §2·§4.4).
##
## 먹선 로직(색·굵기·필압·스무딩·bbox)은 전부 InkRender — 여기서는 피팅(스케일·중앙 정렬)만 한다.
## 사용: const DesignThumb := preload("res://src/core/design_thumb.gd")
##
## **폴백은 호출자가 주입한다.** strokes 없는 도안(샘플·구세이브)에 룬 글리프를 띄우려면
## `fallback_builder`에 Control을 만들어 주는 Callable을 넣어라. core가 모듈의 스타일
## (InkStyle 등)을 preload하면 의존 방향이 뒤집히므로, core는 폴백의 모양을 알지 않는다.

const InkRender := preload("res://src/core/ink_render.gd")

const PADDING := 2.0
## 점 하나짜리 도안(bbox ≈ 0)에서 스케일이 발산하지 않게 한다
const MIN_EXTENT := 0.01
const MAX_SCALE := 512.0

## 표시 중인 도안 (null = 빈 슬롯 — 아무것도 그리지 않는다)
var design: SpellDesign = null
## 먹선 굵기 배율 — 칸이 작을수록 줄여야 뭉개지지 않는다 (HUD 슬롯 0.5 / 장착 화면 1.0)
var width_mult: float = 1.0
## 표시할 획 — 기본은 화살표까지 전부 (플레이어가 그린 그림의 일부다)
var roles: Array = InkRender.ALL_ROLES
## 먹선을 못 그릴 때(strokes 없음) 대신 넣을 Control을 만드는 Callable.
## 시그니처: func(design: SpellDesign, size: Vector2) -> Control. 비우면 빈칸으로 둔다
var fallback_builder: Callable = Callable()

var _ink: Node2D = null
var _fallback: Control = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	# 피팅은 칸 크기에 의존한다 — 컨테이너가 레이아웃을 확정한 뒤 다시 그린다
	resized.connect(_rebuild)
	_rebuild()


## 표시할 도안 지정 (null이면 비운다). 같은 도안이어도 다시 그린다 — 캐시 판단은 호출부 몫
func set_design(d: SpellDesign) -> void:
	design = d
	if is_inside_tree():
		_rebuild()


## 먹선이 실제로 그려졌는가 — strokes가 빈 샘플 도안은 false (호출자가 폴백을 판단할 때)
func has_ink() -> bool:
	return _ink != null


## 그려진 먹선의 경계 (선 굵기 포함, 위젯 로컬 좌표) — 피팅 검증·정렬용
func ink_rect() -> Rect2:
	if _ink == null:
		return Rect2()
	var box := InkRender.design_bbox(design, roles)
	var half := Vector2.ONE * InkRender.BASE_WIDTH * width_mult * 0.5
	var pos := box.position * _fit + _ink.position - half
	return Rect2(pos, box.size * _fit + half * 2.0)


var _fit: float = 1.0


# ─────────────────────────── 렌더 ───────────────────────────

func _rebuild() -> void:
	_clear()
	if design == null:
		return
	# 레이아웃 전(크기 0)에는 그릴 수 없다 — resized에서 다시 불린다
	if size.x <= 0.0 or size.y <= 0.0:
		return

	# bbox를 알아야 스케일이 나오고, 스케일을 알아야 그릴 수 있다.
	# InkRender.design_bbox가 점 계산만 해주므로 렌더는 1회로 끝난다.
	var box := InkRender.design_bbox(design, roles)
	if box.size == Vector2.ZERO and box.position == Vector2.ZERO:
		_show_fallback()   # strokes 없는 샘플 도안
		return

	# 선은 점 바깥으로 굵기의 절반만큼 번진다 — 여백에 미리 반영
	var margin := PADDING + InkRender.BASE_WIDTH * width_mult * 0.5
	var inner := size - Vector2.ONE * margin * 2.0
	if inner.x <= 1.0 or inner.y <= 1.0:
		inner = size  # 칸이 여백을 낼 수 없을 만큼 작다 — 그림을 살린다 (clip_contents가 받아낸다)
	_fit = clampf(minf(
		inner.x / maxf(box.size.x, MIN_EXTENT),
		inner.y / maxf(box.size.y, MIN_EXTENT)), 0.0, MAX_SCALE)

	_ink = InkRender.build_design(design, _fit, {
		"roles": roles, "bright": false, "width_mult": width_mult,
	})
	if _ink == null:
		_show_fallback()
		return
	# build_design은 진 중심을 원점에 둔다 — bbox 중심을 칸 중심에 맞춘다
	_ink.position = size * 0.5 - box.get_center() * _fit
	add_child(_ink)


## strokes가 없는 도안(샘플·구세이브)은 호출자가 준 폴백으로 — core는 모양을 모른다
func _show_fallback() -> void:
	if not fallback_builder.is_valid():
		return
	var node: Control = fallback_builder.call(design, size)
	if node == null:
		return
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 버튼 위에 얹힐 수 있다 — 클릭을 먹지 않게
	_fallback = node
	add_child(node)


func _clear() -> void:
	for node: Node in [_ink, _fallback]:
		if node != null:
			remove_child(node)  # queue_free만으로는 has_ink()가 한 프레임 거짓말한다
			node.queue_free()
	_ink = null
	_fallback = null
	_fit = 1.0
