extends CharacterBody2D
## 거점의 견습 필경사 — WASD 이동 · 마우스 에임 · 장착 도안 캐스팅 (모듈 D).
##
## 캐스팅 계약은 필드 플레이어(모듈 C)와 동일하다: cast_requested(design, 위치, 에임).
## 거점에서 쏘는 대상은 마당의 허수아비뿐이지만 **비용은 실제로 든다** — 마나가 줄고
## 도안 내구가 1 닳는다. 시험 발사가 공짜면 "쓸 때마다 닳는다"를 배울 자리가 없어진다
## (GDD §5 내구도 · §7 거점 시험 발사).
##
## 잠금: 시설 패널이 열려 있으면(locked) 이동·캐스팅 모두 멈춘다 — base.gd가 설정한다.

var locked: bool = false

var _speed: float = 120.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _aim_line: Line2D


func _ready() -> void:
	_speed = GameState.balance.player_move_speed
	_aim_line = Line2D.new()
	_aim_line.points = PackedVector2Array([Vector2(6, 0), Vector2(15, 0)])
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1, 1, 1, 0.5)
	add_child(_aim_line)


func _physics_process(_delta: float) -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		_aim_dir = to_mouse.normalized()
	_aim_line.rotation = _aim_dir.angle()
	if locked or GameState.ui_modal_open:
		velocity = Vector2.ZERO
		return
	velocity = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") * _speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if locked or GameState.ui_modal_open:
		return
	for slot in range(GameState.EQUIP_SLOTS):
		if event.is_action_pressed("cast_slot_%d" % (slot + 1)):
			try_cast(slot)
			get_viewport().set_input_as_handled()
			return


## 장착 슬롯 캐스트 요청 — 발신했으면 true.
## 빈 슬롯은 조용히 무시하고, 손상 도안은 cast_failed(BROKEN)를 받도록 그대로 넘긴다
## (거점에는 작업대가 있다 — "수리해라"라는 안내가 나가야 할 자리다).
##
## 🔴 고리 우선 (2026-07-17, 세션 21): **이젤에서 맺자마자 마당 허수아비에 쏴 볼 수 있어야 한다.**
## 그 전에는 거점에 RingSpellSystem이 없고 여기가 옛 SpellDesign만 봐서, 방금 조립한 고리를
## 확인하려면 **문으로 나가 필드까지 가야 했다** — 조립→확인 루프가 씬 전환을 건너야 닫혔다.
## 분기 순서·계약은 field/player.gd try_cast와 **동일하게** 맞춘다(두 경로가 갈라지면 안 된다).
func try_cast(slot: int) -> bool:
	if locked or GameState.ui_modal_open:
		return false
	if slot < 0 or slot >= GameState.EQUIP_SLOTS:
		return false
	# 고리 도안이 장착돼 있으면 그쪽으로 쏜다 (경제 없음, 진이 통째로 날아간다).
	# 옛 SpellDesign 경로는 아래로 그대로 살아 있다 (병행 은퇴 중).
	if slot < GameState.ring_equipped.size():
		var ring_design: RingDesign = GameState.ring_equipped[slot]
		if ring_design != null:
			EventBus.ring_cast_requested.emit(ring_design.to_assembly(), global_position, _aim_dir)
			EventBus.ring_cast_executed.emit(slot, ring_design)
			return true
	if slot >= GameState.equipped.size():
		return false
	var design: SpellDesign = GameState.equipped[slot]
	if design == null:
		return false
	EventBus.cast_requested.emit(design, global_position, _aim_dir)
	return true
