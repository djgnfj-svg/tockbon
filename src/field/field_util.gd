extends RefCounted
## 필드 공용 플레이스홀더 헬퍼 — Polygon2D 비주얼·충돌 셰이프 생성 (모듈 C).
## 아트 교체 시 이 헬퍼 호출부만 스프라이트로 바꾸면 된다.

static func circle_points(radius: float, segments: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2.from_angle(a) * radius)
	return pts

static func add_circle_visual(parent: Node, radius: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = circle_points(radius)
	poly.color = color
	parent.add_child(poly)
	return poly

static func add_circle_collider(parent: Node, radius: float) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	parent.add_child(cs)
	return cs

static func add_rect_visual(parent: Node, size: Vector2, color: Color) -> Polygon2D:
	var half := size * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	poly.color = color
	parent.add_child(poly)
	return poly

static func add_rect_collider(parent: Node, size: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	parent.add_child(cs)
	return cs

## 밤 시야용 방사형 라이트 텍스처 (PointLight2D)
static func radial_light_texture(size: int = 256) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size
	tex.height = size
	return tex
