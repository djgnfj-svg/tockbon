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

## 🔴 위력·마나 비용은 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다.
## 마나는 `GameState.cast_mana_cost()`(= `RingPower` 기본값 × 장비 보정)를 부른다 — 세85에
## `RingPower`를 직접 preload하던 줄을 걷었다(중간 참조가 남으면 장비 보정을 빼먹기 쉽다).
## 조준선 길이·색 (연출값 — 밸런스 아님). 빈 슬롯은 흐리게 — "못 쏨"이 손끝에서 보인다 (세션59
## 매직볼 은퇴 후 이 흐림이 다시 **참 신호**다).
const AIM_FROM := 14.0
const AIM_TO := 34.0
const AIM_ARMED := Color(0.95, 0.65, 0.25, 0.85)
const AIM_EMPTY := Color(0.75, 0.72, 0.65, 0.30)

## false면 조준·발사·슬롯이 전부 멎는다 (책이 펼쳐진 동안).
var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

var _aim := Vector2.RIGHT
var _slot: int = 0
## 🔴 떠있는 지팡이(형제 노드) — 발사 총구가 지팡이 끝이 된다(세피리아식). 지연 조회(노드 준비
## 순서 무관). 장착한 지팡이가 없어 지팡이가 숨으면 총구는 몸 중심으로 폴백한다(맨손 캐스팅).
var _wand: Node2D = null


## 지금 고른 슬롯 · 조준 방향 — 씬이 읽는다 (테스트도 이 API로만 본다).
func slot() -> int:
	return _slot


func aim() -> Vector2:
	return _aim


func _process(_delta: float) -> void:
	if not enabled or GameState.ui_modal_open:
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		_aim = to_mouse.normalized()
	queue_redraw()


## 🔴 발사는 **좌클릭만**이다 (사용자 확정). Space는 발사가 아니다 — 시험대가 Space도 받는 건
## 시험대 사정이다. Space를 다른 용도로 임의 배정하지도 마라: 그건 사용자가 정할 몫이다.
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or GameState.ui_modal_open:
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
	# 🔴 슬롯 선택 안내(notice→HUD.say)를 더 안 쏜다 (세64). HUD가 선택 슬롯 상세를 **상시 한 줄**로
	# 그려서, 여기서 또 say를 띄우면 같은 "슬롯 N … 그려 장착"이 두 줄로 겹친다(사용자 지적). 강조 칸
	# 이동만 알린다. 발사 거부 안내(fire의 notice)는 그대로 — 그건 상시 줄이 못 보여 주는 순간 피드백이다.
	slot_changed.emit(slot)
	queue_redraw()


## 🔴 `to_assembly()`로 쏜다 — 그래야 `assembly.score`(손그림 점수)가 실려 **그때 그린 위력이
## 그대로 난다**. 직접 Dictionary를 만들면 score가 빠져 조용히 기준 위력이 된다.
func fire() -> void:
	# 🔴 빈 슬롯은 발사 거부 (세션59, 사용자 확정 — 세션44 「매직볼 바닥」 은퇴). 새 연출(글로우
	# 볼·트레일·플래시)이 매직볼에도 실리자 "아무것도 안 그렸는데 마법이 나간다"로 읽혔다.
	# 이제 발사 = 그린 진뿐이다. ⚠ 거부는 조용히 하지 마라(commit_rejected 규칙과 같은 병) —
	# 안내가 없으면 "장착했는데 안 나간다"가 된다. 마나 판정보다 먼저 — 거부에 마나를 태우지 않는다.
	var design: RingDesign = GameState.ring_equipped[_slot]
	if design == null:
		notice.emit("장착된 진이 없다 — 책상(E)에서 그려 장착해라", true)
		return
	# 🔴 마나 소모 — 이게 없으면 좌클릭 연사다 (세션 35). 수치를 여기 박지 마라.
	# 🔴 세85: **`GameState.cast_mana_cost()`를 부른다** — 장착 지팡이의 `wand_mana_mult`가 얹힌 값이다
	# (은퇴한 `wand_pattern`을 대신하는 실효 축). HUD 마나 막대도 같은 함수를 봐야 「부족」 경계와
	# 실제 소모가 안 갈라진다.
	# ⚠ debug_free_cast(에디터 실행 전용) = 테스트 편의 무소모 — 익스포트에선 항상 false.
	if not GameState.debug_free_cast and not GameState.spend_mana(GameState.cast_mana_cost()):
		notice.emit("마나가 부족하다 — 잠시 기다려라", true)
		return
	EventBus.ring_cast_requested.emit(design.to_assembly(), _muzzle(), _aim)


## 🔴 발사 원점 = 떠있는 지팡이 끝(총구 단일 소스는 floating_wand). 지팡이가 없거나 숨었으면
## 몸 중심(global_position)으로 폴백 — 맨손도 쏠 수 있다.
func _muzzle() -> Vector2:
	if _wand == null:
		_wand = get_parent().get_node_or_null("FloatingWand")
	if _wand and _wand.visible:
		return _wand.muzzle_position()
	return global_position


## 조준선 — 장착됐으면 불빛, 빈 슬롯이면 흐리게. 쏘기 전에 슬롯 상태가 손끝에서 보인다.
func _draw() -> void:
	if not enabled:
		return
	var armed := GameState.ring_equipped[_slot] != null
	draw_line(_aim * AIM_FROM, _aim * AIM_TO, AIM_ARMED if armed else AIM_EMPTY, 2.0)
