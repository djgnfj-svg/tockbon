extends Line2D
## 부드러운 먹선 렌더 — Line2D + 필압 width_curve (GDD §10.5 비주얼 아이덴티티).
## 픽셀아트 위에 얹히는 매끄러운 잉크 스트로크. 사용: preload 후 .new().

const Recognizer := preload("res://src/drawing/recognizer.gd")
const InkRender := preload("res://src/core/ink_render.gd")

const BASE_WIDTH := 3.5
const INK_COLOR := Color(0.13, 0.11, 0.10)


func _init() -> void:
	width = BASE_WIDTH
	default_color = INK_COLOR
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = true


## 라이브 드로잉 중 점 추가 (스무딩 없음 — 확정 시 setup으로 교체)
func append_live(p: Vector2) -> void:
	add_point(p)


## 획 확정 렌더: 스무딩 + 필압 폭 곡선 적용
func setup(px_points: PackedVector2Array, pressures: PackedFloat32Array) -> void:
	points = Recognizer.smoothed(px_points, 1)
	width_curve = InkRender.pressure_curve(pressures)


## 라이브 중 필압만 갱신 — 점은 건드리지 않는다 (머물면 부푸는 게 실시간으로 보이게).
## 곡선 생성은 core에 맡긴다: 자체 구현은 1.0에서 잘라 합성 필압의 부푼 구간을 삼킨다.
func refresh_live_pressures(pressures: PackedFloat32Array) -> void:
	width_curve = InkRender.pressure_curve(pressures)
