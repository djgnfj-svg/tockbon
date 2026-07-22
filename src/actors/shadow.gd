extends Sprite2D
## 발밑 그림자 — 공용 배우 컴포넌트 (세63 설계 §D). 부착자(forest_enemy·player.tscn·snake_body)가
## `radius_px`를 덩치에 맞춰 정하고 add_child하면 끝이다 — 이 노드는 아무것도 폴링하지 않는다.
##
## 🔴 **절차적이 맞다** (도형 금지 규칙의 예외 판별, takbon-rules §0): 그림자는 생명체의 "겉모습"이
## 아니라 빛·음영 **이펙트**다 — death_puff·vfx Line2D와 같은 "그림"이고, 부드러운 반투명 타원은
## 도트로 그리면 오히려 계단이 생긴다. GradientTexture2D(radial, 검정→투명)로 소프트 타원이 공짜.
##
## 🔴 **z_index 음수 금지** — 세54에 음수 z 마디가 Ground(ColorRect, z0) 뒤로 숨었다. 몸 아래는
## z가 아니라 **트리 순서**(부착자가 move_child(shadow, 0))로 만든다. 뱀 마디처럼 절대 z가 필요한
## 자리는 부착자가 z_as_relative=false + z 0을 직접 세팅한다.
##
## 🔴 **어떤 그룹에도 가입하지 않는다** — 세59 트레일의 player_projectiles 무가입 함정과 같은 결
## (그룹을 세는 테스트가 거짓으로 는다). "enemies"·"player" 근처에 살지만 그림자는 몸이 아니다.
##
## class_name 없음 — 모듈 규칙(preload로만 참조).

## 그림자 반지름(px) — 부착자가 덩치에 맞춰 지정. 텍스처는 공유하고 scale로만 크기를 낸다.
@export var radius_px: float = 10.0

## 연출값 (밸런스 아님 — juice·vfx const 선례. 사용자가 눈으로 보며 조인다).
const TEX_SIZE := 64              ## 그라디언트 텍스처 한 변(px)
const SHADOW_ALPHA := 0.35        ## 중심 알파 (검정 → 바깥 투명)
const FLATTEN := 0.45             ## 비등방 세로 스케일 — 원 텍스처를 타원으로 눕힌다

## 🔴 텍스처는 전 그림자 공유 — per-instance 상태가 없어 안전하다 (hit_flash의 Shader 리소스
## 공유가 안전한 것과 같은 이유 — 인스턴스마다 갈라야 하는 건 uniform을 쥔 Material 쪽이다).
static var _shared_tex: GradientTexture2D = null


func _ready() -> void:
	texture = _shadow_texture()
	# 타원 = 원 텍스처의 비등방 스케일. 지름(radius_px×2)을 텍스처 한 변에 맞춘다.
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
