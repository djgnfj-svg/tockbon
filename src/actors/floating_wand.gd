extends Sprite2D
## 떠있는 지팡이 — 세피리아식 (사용자 확정). 마녀의 손에서 완드를 떼어 **몸 옆에 둥둥 띄우고
## 조준 방향(커서)을 향하게** 하는 순수 연출 노드. **플레이어의 자식**으로 붙는다.
##
## 🔴 두 역할이 다르다: **떠있는 지팡이 = 도구(장착한 WAND 아이템)**, 그 안으로 **그린 진/마법진이
## 발사**된다(세피리아에서 떠있는 무기와 같은 그림). 그래서 이 노드는 `GameState.equipment[WAND]`가
## 있을 때만 보인다 — 지팡이를 장착하면 나타나고, 맨손이면 사라진다(맨손도 몸 중심에서 쏠 수 있다).
##
## 🔴 **총구(muzzle) 단일 소스**: 발사 원점(지팡이 끝)의 기하는 여기서만 계산한다(`muzzle_position()`).
## caster가 이 함수를 불러 발사 좌표로 쓴다 — 지오메트리를 caster에 복제하면 세션들이 두려워하는
## "두 곳이 조용히 갈라짐"이 된다(slot_angle 선례). 지팡이가 없으면 caster가 몸 중심으로 폴백한다.
##
## 손맛 수치(HOVER_*·BOB_*·MUZZLE_LEN)는 전부 **연출값 const**다(밸런스 아님 — PUSH_DECAY 선례).
## 사용자가 F5로 조율한다.

## 몸에서 지팡이까지 거리(px) — "옆에" 떠있는 느낌.
## 🔴 세90: 22 → 30. 캐릭터가 2배(그림 폭 16 → 32)가 되면서 22px는 **몸 안쪽**이 됐다
##   (반폭 16이라 몸 밖으로 6px밖에 안 나온다 = "옆에 떠있다"가 "몸에 박혀 있다"로 읽힌다).
##   ⚠ 캐릭터 배율을 또 바꾸면 여기도 같이 본다 — `tools/bake_player_sheet.py` 머리말 참조.
const HOVER_RADIUS := 30.0
## 조준 방향에서 옆으로 벌리는 각(rad) — 커서 정면이 아니라 살짝 옆에 떠서 "겨눈다"로 읽힌다.
const SIDE_ANGLE := 0.7
## 떠있는 위치가 조준을 따라가는 감쇠 속도(높을수록 딱 붙음, 낮을수록 흐느적). 둥둥거림의 핵심.
const HOVER_FOLLOW := 9.0
## 상하 둥둥 진폭(px)·속도(rad/s).
const BOB_AMP := 2.5
const BOB_SPEED := 3.5
## 지팡이 끝(총구)이 노드 중심에서 얼마나 앞(로컬 +X)인가 — floating_wand.png 끝 글로우 위치에 맞춘다.
## 스프라이트 32×16·centered → 텍스처 x30(바깥 빛끝) ≈ 로컬 +14 (아트 실측, scratch_floating_wand_art.md).
const MUZZLE_LEN := 14.0

var _caster: Node2D = null   ## 조준 방향을 읽어올 형제 노드(player_caster)
var _hover_angle := 0.0      ## 현재 떠있는 위치의 각(감쇠 추종 대상 = aim+SIDE_ANGLE)
var _t := 0.0                ## 둥둥 위상 누적


func _ready() -> void:
	z_index = 3   # 플레이어 스프라이트(z 2) 위에 — 몸 앞에 떠 있게
	_caster = get_parent().get_node_or_null("Caster")


func _process(delta: float) -> void:
	# 🔴 장착한 지팡이가 없으면 숨긴다 — 떠있는 지팡이 = 장착한 WAND 아이템의 표현.
	if not GameState.equipment.has(Enums.ItemKind.WAND):
		visible = false
		return
	visible = true

	# 모달(책·창고)이 열리면 그 자리에 멎는다 — 조준이 안 도니 갱신할 것도 없다.
	if GameState.ui_modal_open:
		return

	_t += delta
	var aim: Vector2 = _aim()
	var aim_ang := aim.angle()

	# 떠있는 위치: 조준에서 SIDE_ANGLE만큼 벌린 각으로 감쇠 추종(흐느적) + 상하 둥둥.
	# 좌우 벌림 방향은 조준 위/아래에 따라 뒤집어 항상 "아래쪽 옆"에 앉게 한다.
	var side := SIDE_ANGLE if aim.y >= 0.0 else -SIDE_ANGLE
	_hover_angle = lerp_angle(_hover_angle, aim_ang + side, minf(1.0, HOVER_FOLLOW * delta))
	var bob := sin(_t * BOB_SPEED) * BOB_AMP
	position = Vector2(HOVER_RADIUS, 0.0).rotated(_hover_angle) + Vector2(0.0, bob)

	# 지팡이 끝은 항상 커서를 향한다(감쇠 위치와 별개 — 위치는 흐느적, 조준은 정확).
	rotation = aim_ang
	# 왼쪽을 겨누면 스프라이트가 뒤집혀 손잡이·끝이 반대로 서니 세로로 미러해 세운다.
	flip_v = absf(aim_ang) > PI * 0.5


## 🔴 발사 원점(지팡이 끝) — caster가 이 값을 발사 좌표로 쓴다(총구 단일 소스).
func muzzle_position() -> Vector2:
	return to_global(Vector2(MUZZLE_LEN, 0.0))


## 조준 방향 — 형제 caster에서 읽는다. caster가 없거나 못 읽으면 오른쪽 기본.
func _aim() -> Vector2:
	if _caster and _caster.has_method("aim"):
		return _caster.aim()
	return Vector2.RIGHT
