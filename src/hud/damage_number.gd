extends Label
## 떠오르는 피해 숫자 — 적을 때린 자리에서 위로 뜨며 사라진다.
## 🔴 **월드 좌표에 놓이는 Label이다** — CanvasLayer가 아니라 현재 씬에 직접 붙어 카메라 변환을
## 그대로 타야 적 머리 위에 붙어 있는 것처럼 보인다.
## 🔴 수치는 밸런스가 아니라 연출값(손맛)이라 const다.

const RISE_PX := 26.0     ## 살아 있는 동안 떠오르는 높이
const LIFE_SEC := 0.6     ## 생존 시간
const BIG_COLOR := Color(1.0, 0.85, 0.3)  ## 큰 타격 = 금색 강조

## juice.gd가 add_child 전에 채운다 (_ready가 읽는다).
var amount: float = 0.0
var big: bool = false
var world_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	text = str(maxi(1, roundi(amount)))
	add_theme_font_size_override("font_size", 22 if big else 15)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	if big:
		modulate = BIG_COLOR
	z_index = 100
	# Label 기준점이 좌상단이라 폭 절반만큼 왼쪽으로 밀어야 머리 위 가운데에 앉는다.
	reset_size()
	global_position = world_pos - Vector2(size.x * 0.5, size.y)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - RISE_PX, LIFE_SEC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFE_SEC).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
