extends CharacterBody2D
## 플레이어 — WASD 이동. 조준·발사·슬롯은 자식 `Caster`(player_caster.gd)가 쥔다.
##
## 🔴 **베이스캠프와 숲이 같은 몸을 쓴다** (세션 26). 세션 25까지 플레이어는 `base.tscn`에
## **인라인**이라 숲이 쓰려면 base를 preload해야 했고, 그건 모듈 간 직접 참조 금지 위반이었다.
## 그래서 `src/actors`(공용 배우 모듈)로 뺐다 — base도 field도 여기서 조립한다.
##
## 🔴 **레이어 계약을 지켜라: layer 2(player) / mask 1(world)** (player.tscn).
## 기본 레이어 1(world)로 되돌리면 **쏘는 순간 진이 내 몸에 부딪혀 총구에서 죽는다** —
## 캐리어 마스크가 5(world+enemy)이기 때문이다. **에러도 경고도 없다** (세션 24에 실제로 겪었다).
## mask에 3(enemy)을 더하지도 마라: 적이 나를 밀어내는 게임이 아니다.
##
## 🔴 그룹 `"player"` = **적이 나를 찾는 유일한 경로**다 (forest_enemy가 이 그룹으로 조준한다).
## 지우면 적이 제자리에 굳는데 에러는 안 난다.

const PlayerCaster := preload("res://src/actors/player_caster.gd")

@onready var caster: PlayerCaster = $Caster

func _ready() -> void:
	add_to_group("player")

## 🔴 속도는 balance가 쥔다 (수치를 코드에 박지 않는다 — TECH_SPEC §10).
func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * GameState.balance.player_move_speed
	move_and_slide()
