extends Sprite2D
## 발밑 그림자 — 공용 배우 컴포넌트. 부착자가 `radius_px`만 덩치에 맞춰 정하고 add_child하면 끝이다.
## 🔴 **z_index 음수 금지** — 음수 z는 Ground(ColorRect, z0) 뒤로 숨는다. 몸 아래로 깔려면
##   부착자가 `move_child(shadow, 0)`으로 트리 순서를 쓴다.
## 🔴 **어떤 그룹에도 가입하지 않는다** — 그룹을 세는 테스트가 거짓으로 는다.

## 그림자 반지름(px) — 부착자가 덩치에 맞춰 지정. 텍스처는 공유하고 scale로만 크기를 낸다.
@export var radius_px: float = 10.0

## 연출값 (밸런스 아님 — 사용자가 눈으로 보며 조인다).
const TEX_SIZE := 64              ## 그라디언트 텍스처 한 변(px)
const SHADOW_ALPHA := 0.35        ## 중심 알파 (검정 → 바깥 투명)
const FLATTEN := 0.45             ## 비등방 세로 스케일 — 원 텍스처를 타원으로 눕힌다

## 텍스처는 전 그림자 공유 — per-instance 상태가 없어 안전하다(갈라야 하는 건 uniform을 쥔 Material 쪽).
static var _shared_tex: GradientTexture2D = null


func _ready() -> void:
	texture = _shadow_texture()
	var s := radius_px * 2.0 / float(TEX_SIZE)
	scale = Vector2(s, s * FLATTEN)


static func _shadow_texture() -> GradientTexture2D:
	if _shared_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0.0, 0.0, 0.0, SHADOW_ALPHA))
		grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = TEX_SIZE
		tex.height = TEX_SIZE
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		_shared_tex = tex
	return _shared_tex
