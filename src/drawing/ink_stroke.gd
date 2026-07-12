extends Line2D
## 부드러운 먹선 렌더 — Line2D + 필압 width_curve (GDD §10.5 비주얼 아이덴티티).
## 픽셀아트 위에 얹히는 매끄러운 잉크 스트로크. 사용: preload 후 .new().

const Recognizer := preload("res://src/drawing/recognizer.gd")

const BASE_WIDTH := 3.5
const INK_COLOR := Color(0.13, 0.11, 0.10)
const MAX_CURVE_POINTS := 16


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
	width_curve = _pressure_curve(pressures)


func _pressure_curve(pressures: PackedFloat32Array) -> Curve:
	if pressures.size() < 2:
		return null
	var curve := Curve.new()
	var n := mini(pressures.size(), MAX_CURVE_POINTS)
	for i in n:
		var t := float(i) / float(n - 1)
		var idx := int(t * float(pressures.size() - 1))
		curve.add_point(Vector2(t, clampf(pressures[idx], 0.15, 1.0)))
	return curve
