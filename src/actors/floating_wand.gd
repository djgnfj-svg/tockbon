extends Sprite2D
## 떠있는 지팡이 — 몸 옆에 띄우고 커서를 향하게 하는 연출 노드. 플레이어의 자식.
## 장착한 WAND 아이템의 표현이라 `GameState.equipment[WAND]`가 있을 때만 보인다(맨손은 몸 중심에서 쏜다).
## 🔴 **발사 총구 단일 소스** = `muzzle_position()`. caster에 기하를 복제하면 두 곳이 조용히 갈라진다.
## HOVER_*·BOB_*·MUZZLE_LEN은 연출값 const(밸런스 아님).

## 몸에서 지팡이까지 거리(px). ⚠ 캐릭터 배율을 바꾸면 여기도 같이 본다 — 반폭보다 작으면 몸 안에 박힌다.
const HOVER_RADIUS := 30.0
## 조준 방향에서 옆으로 벌리는 각(rad) — 커서 정면이 아니라 살짝 옆에 떠서 "겨눈다"로 읽힌다.
const SIDE_ANGLE := 0.7
## 떠있는 위치가 조준을 따라가는 감쇠 속도(높을수록 딱 붙음, 낮을수록 흐느적). 둥둥거림의 핵심.
const HOVER_FOLLOW := 9.0
## 상하 둥둥 진폭(px)·속도(rad/s).
const BOB_AMP := 2.5
const BOB_SPEED := 3.5
## 지팡이 끝(총구)이 노드 중심에서 얼마나 앞(로컬 +X)인가 — 스프라이트 끝 글로우 위치에 맞춘 실측값.
const MUZZLE_LEN := 14.0

var _caster: Node2D = null
var _hover_angle := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 3   # 플레이어 스프라이트(z 2) 위 — 몸 앞에 떠 있게
	_caster = get_parent().get_node_or_null("Caster")


func _process(delta: float) -> void:
	if not GameState.equipment.has(Enums.ItemKind.WAND):
		visible = false
		return
	visible = true

	# 🔴 모달이 열리면 멎는다 — 조준이 안 도니 갱신할 것도 없다.
	if GameState.ui_modal_open:
		return

	_t += delta
	var aim: Vector2 = _aim()
	var aim_ang := aim.angle()

	# 벌림 방향을 조준 위/아래로 뒤집어 항상 "아래쪽 옆"에 앉게 한다.
	var side := SIDE_ANGLE if aim.y >= 0.0 else -SIDE_ANGLE
	_hover_angle = lerp_angle(_hover_angle, aim_ang + side, minf(1.0, HOVER_FOLLOW * delta))
	var bob := sin(_t * BOB_SPEED) * BOB_AMP
	position = Vector2(HOVER_RADIUS, 0.0).rotated(_hover_angle) + Vector2(0.0, bob)

	# 위치는 흐느적여도 조준은 정확해야 해서 회전만 커서를 직접 따른다.
	rotation = aim_ang
	# 왼쪽을 겨누면 손잡이·끝이 뒤집혀 서니 세로로 미러한다.
	flip_v = absf(aim_ang) > PI * 0.5


## 🔴 발사 원점 — caster가 이 값을 발사 좌표로 쓴다(총구 단일 소스).
func muzzle_position() -> Vector2:
	return to_global(Vector2(MUZZLE_LEN, 0.0))


func _aim() -> Vector2:
	if _caster and _caster.has_method("aim"):
		return _caster.aim()
	return Vector2.RIGHT
