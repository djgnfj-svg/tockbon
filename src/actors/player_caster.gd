extends Node2D
## 조준선 · 발사 · 슬롯 선택 — **베이스캠프와 숲이 공유한다** (백로그 R4).
##
## 🔴 왜 뽑았나: 세션 25까지 이 로직은 `base.gd` 안에 있었다. 숲이 생기면 그대로 복사됐을 텐데,
## 복사본에는 **`to_assembly()`를 빼먹는 함정이 같이 복사된다** — 직접 Dictionary를 만들면
## `assembly.score`가 빠져 **손그림 점수가 조용히 사라지고 기준 위력으로 나간다**
## (ring_design.gd 주석). 한 곳에 두면 함정도 한 곳뿐이다.
##
## 플레이어의 **자식으로 원점에 붙는다** — 그래서 `global_position`이 곧 총구다.
## 씬은 이 노드를 두 갈래로만 쓴다: `notice`/`slot_changed`를 HUD에 잇고, 책이 펼쳐지면 `enabled = false`.

## 한 줄 안내문을 HUD로 (HUD를 직접 참조하지 않는다 — 베이스와 숲의 HUD가 다르다).
signal notice(text: String, warn: bool)
## 고른 슬롯이 바뀌었다 — HUD가 강조 칸을 옮긴다.
signal slot_changed(slot: int)

## 🔴 위력은 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다 (core에 있는 이유).
const RingPower := preload("res://src/core/ring_power.gd")

## 조준선 길이·색 (연출값 — 밸런스 아님).
const AIM_FROM := 14.0
const AIM_TO := 34.0
const AIM_ARMED := Color(0.95, 0.65, 0.25, 0.85)
const AIM_EMPTY := Color(0.6, 0.6, 0.6, 0.35)

## false면 조준·발사·슬롯이 전부 멎는다 (책이 펼쳐진 동안).
var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

var _aim := Vector2.RIGHT
var _slot: int = 0


## 지금 고른 슬롯 · 조준 방향 — 씬이 읽는다 (테스트도 이 API로만 본다).
func slot() -> int:
	return _slot


func aim() -> Vector2:
	return _aim


func _process(_delta: float) -> void:
	if not enabled:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		_aim = to_mouse.normalized()
	queue_redraw()


## 🔴 발사는 **좌클릭만**이다 (사용자 확정). Space는 발사가 아니다 — 시험대가 Space도 받는 건
## 시험대 사정이다. Space를 다른 용도로 임의 배정하지도 마라: 그건 사용자가 정할 몫이다.
func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	for i in GameState.EQUIP_SLOTS:
		if event.is_action_pressed(StringName("cast_slot_%d" % (i + 1))):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"attack_basic"):
		fire()
		get_viewport().set_input_as_handled()


func select_slot(slot: int) -> void:
	_slot = slot
	slot_changed.emit(slot)
	var design: RingDesign = GameState.ring_equipped[slot]
	if design == null:
		notice.emit("슬롯 %d — 비어 있다 (1~4로 다른 슬롯)" % (slot + 1), false)
	else:
		notice.emit("슬롯 %d — %s (위력 %d)" % [slot + 1, design.display_name,
			RingPower.power_display(design.total_score)], false)
	queue_redraw()


## 🔴 `to_assembly()`로 쏜다 — 그래야 `assembly.score`(손그림 점수)가 실려 **그때 그린 위력이
## 그대로 난다**. 직접 Dictionary를 만들면 score가 빠져 조용히 기준 위력이 된다.
func fire() -> void:
	var design: RingDesign = GameState.ring_equipped[_slot]
	if design == null:
		notice.emit("슬롯 %d이 비어 있다 — 1~4로 다른 슬롯을 골라라" % (_slot + 1), true)
		return
	EventBus.ring_cast_requested.emit(design.to_assembly(), global_position, _aim)


## 조준선 — 장착됐으면 불빛, 빈 슬롯이면 흐리게. 쏘기 전에 슬롯 상태가 손끝에서 보인다.
func _draw() -> void:
	if not enabled:
		return
	var armed := GameState.ring_equipped[_slot] != null
	draw_line(_aim * AIM_FROM, _aim * AIM_TO, AIM_ARMED if armed else AIM_EMPTY, 2.0)
