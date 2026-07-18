extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 **고리 조립 책**(진·룬·문양)이 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 왼쪽 숲길에서 E를 누르면 **원정**을 나간다 (씬 전환 — 세션 26).
##
## 🔴 여기가 **게임의 진입점**이다 (project.godot run/main_scene, 사용자 확정 세션 21).
## 세션 22에 폴더가 `src/playground` → `src/base`로 바뀌었다 — "버려도 되는 실험"이라는
## 거짓 신호 때문에 리드가 세션 21에 엉뚱한 씬을 띄워 "다 사라졌다"고 헤맸다.
##
## 🔴 M1 (세션 22): 책·숲을 preload가 아니라 **@export로 받는다** — 진입 씬은 조합 루트라 모듈을
## 조립하는 게 정당했지만(그래서 preload도 위반은 아니었다), 씬을 인스펙터에서 갈아 끼울 수 있으면
## 규칙 논쟁 자체가 사라진다. 책의 계약은 여전히 셋뿐: open() / design_committed / closed.
##
## 🔴 세션 24: **그린 마법진을 여기서 쏜다.** 그전엔 잘 그려 위력을 올려도 확인할 데가 시험대뿐이라,
## 본 게임에서는 손그림 점수가 **보이지 않는 숫자**였다. 이제 책상 옆이 연습장(허수아비)이다.
##
## 🔴 세션 26: **조준·발사·슬롯이 여기 없다** — `src/actors/player_caster.gd`가 쥔다.
## 숲이 같은 로직을 필요로 하는데, 복사하면 **`to_assembly()`를 빼먹는 함정까지 복사된다**
## (그러면 손그림 점수가 조용히 빠져 기준 위력으로 나간다). 여기는 caster를 HUD에 잇기만 한다.
##
## 씬(base.tscn) 쪽 결정 — .tscn엔 주석을 못 달아서 여기 적는다:
##  • `RingSpellSystem`은 **@export가 아니라 씬에 직접 인스턴스**로 놨다. 책(forge_scene)과 달리
##    이 스크립트는 발사 시스템을 **한 번도 참조하지 않는다** — EventBus.ring_cast_requested로만
##    말한다. 참조가 없으니 갈아 끼울 @export 구멍도 필요 없다(있으면 안 쓰는 필드만 는다).
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(ColorRect, z=0) **뒤에
##    가려 안 보인다**. 시험대가 같은 함정을 세션 13에 밟았다.
##  • 허수아비 5개는 전부 플레이어 시작점에서 **사거리 안**(≈390px = 260px/s × 1.5s, balance)에 있다.
##    더 멀리 두면 걸어가서 쏘기 전엔 안 닿아 연습장이 장식이 된다 (tests/test_base_auto가 못 박는다).
##  • Player = 레이어 2(player) / Desk·ForestGate = 레이어 64(interaction). 🔴 전부 기본 레이어
##    1(**world**)에 있었는데, 캐리어 마스크가 5(world+enemy)라 **쏘는 순간 내 몸에 부딪혀 총구에서
##    죽었다** (책상 쪽으로 쏘면 책상에서). 레이어 이름표(project.godot)대로 옮겨서 푼 것이다.
##    상호작용 지점의 마스크는 2 — 플레이어를 감지해야 "[E]"가 뜬다.
##  • 🔴 **`Ground.mouse_filter = 2`(IGNORE) — 지우면 발사가 통째로 죽는다** (세션 25).
##    Ground는 화면을 다 덮는 ColorRect인데 **Control의 기본 mouse_filter는 STOP**이라,
##    바닥이 좌클릭을 전부 먹어 `_unhandled_input`까지 오지 않았다 → `_fire()`가 아예 안 불렸다.
##    사용자: *"마법진이 다 그려져도 발사가 안됨"* → *"좌클릭이 안먹나?"* (사용자가 맞혔다).
##    ⚠ **에러도 경고도 없다** — 레이어 함정(위)과 같은 종류의 침묵이다. 그리고 리드의 검증이
##    전부 `_fire()` 직접 호출/액션 주입이라 **Control 계층을 건너뛰어** 두 세션을 못 잡았다.
##    (같은 이유로 HUD도 IGNORE다 — hud.gd `_ready` 참조.)

const RingForgePanelScript := preload("res://src/drawing/ring_forge_panel.gd")
## 정제대 패널 (세션29) — 재료→특별잉크·종이. 책과 달리 base를 안 물어 preload가 안전(순환 아님).
const RefinePanelScene := preload("res://src/base/refine_panel.tscn")
## 공방 패널 (세션32) — 재료→장비 + 착용/해제. 정제대와 같은 이유로 preload가 안전.
const WorkshopPanelScene := preload("res://src/base/workshop_panel.tscn")
## 해독대 패널 (세션34) — 룬 조각→룬 해금. 정제대·공방과 같은 이유로 preload가 안전.
const DecodePanelScene := preload("res://src/base/decode_panel.tscn")
const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 길잡이 NPC(세션37)가 여는 퀘스트 패널 — 타입을 얻어 open()을 정적으로 부른다(class_name 없음).
const QuestPanel := preload("res://src/hud/quest_panel.gd")
## 🔴 위력 표시는 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다 (core에 있는 이유).
const RingPower := preload("res://src/core/ring_power.gd")

## 책상에서 펴는 책 (base.tscn이 ring_forge_panel.tscn을 물려 준다).
## 🔴 여긴 PackedScene이어도 된다 — **책은 base를 안 문다**(순환이 아니다). 아래와 대비된다.
@export var forge_scene: PackedScene = preload("res://src/drawing/ring_forge_panel.tscn")
## 숲길에서 나가는 원정 (세션 26) — 🔴 **PackedScene이 아니라 경로다. 바꾸지 마라.**
## base가 forest를 preload하고 forest가 base를 preload하면 **순환**이라, 먼저 로드되는 쪽의
## 상대가 **노드 0개짜리 껍데기**로 굳는다 → 숲에서 귀환·사망해도 베이스로 못 돌아간다.
## 자세한 근거는 `forest.gd`의 `base_scene_path` 주석. **헤드리스는 이걸 못 잡는다.**
@export_file("*.tscn") var forest_scene_path: String = "res://src/field/forest.tscn"

@onready var _desk: InteractZone = $Desk
@onready var _gate: InteractZone = $ForestGate
@onready var _refine_zone: InteractZone = $Refine
@onready var _craft_zone: InteractZone = $Craft
@onready var _decode_zone: InteractZone = $Decode
@onready var _npc: InteractZone = $Npc
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud
# 🔴 quest_panel.tscn 루트는 CanvasLayer(layer 5)고, 스크립트(Control)는 그 자식 Panel이다.
@onready var _quest: QuestPanel = $Quest/Panel

## 🔴 한 번에 하나의 모달만 — 책·정제대·공방이 같은 `_overlay` 슬롯을 쓴다. 하나 열려 있으면 다른 건 안 열린다.
var _overlay: CanvasLayer = null
var _forge: RingForgePanelScript = null
var _refine: Control = null
var _workshop: Control = null
var _decode: Control = null

func _ready() -> void:
	# 🔴 씬 진입 시 모달 플래그를 내린다 — ui_modal_open은 오토로드라 씬 전환에도 살아남는다.
	# 어떤 경로로든 모달이 켜진 채 씬이 바뀌면 새 패널은 _open=false인데 플래그만 true라 잠긴다.
	GameState.ui_modal_open = false
	# 🔴 베이스=집. 허기가 멎고 배를 채운다 (세션 35 — 귀환·사망이 다 여기로 오므로 회복도 여기서).
	GameState.in_expedition = false
	GameState.restore_hunger_full()
	_desk.interacted.connect(_open_drawing)
	_gate.interacted.connect(_to_forest)
	# 🔴 건설형 스테이션 (세션37) — 안 지어졌으면 E=건설 시도, 지어졌으면 E=패널. _station_interact가 가른다.
	_refine_zone.interacted.connect(func() -> void:
		_station_interact(&"station_refine", "정제대", _refine_zone, _open_refine_panel))
	_craft_zone.interacted.connect(func() -> void:
		_station_interact(&"station_craft", "공방", _craft_zone, _open_workshop_panel))
	_decode_zone.interacted.connect(func() -> void:
		_station_interact(&"station_decode", "탁본 해독대", _decode_zone, _open_decode_panel))
	# 길잡이 NPC (세션37) — E로 목표(퀘스트) 패널을 연다. Q 토글과 같은 내용.
	_npc.interacted.connect(func() -> void: _quest.open())
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# 퀘스트 완료 알림 (세션36) — GameState가 판정, 씬은 HUD로 알린다(caster.notice와 같은 채널).
	EventBus.quest_completed.connect(_on_quest_completed)
	# 🔴 스테이션 건설 상태를 화면에 반영 (안 지어진 것은 어둡게 + "건설" 안내). 저장된 상태 기준.
	_refresh_stations()

# ─────────────────────────── 원정 ───────────────────────────

## 🔴 출격이 **HP를 되돌리지 않는다** — 그건 숲이 한다 (forest.gd `_ready`).
## 여기서 하면 "베이스에서 나갈 때만" 만HP고, 시험대·다른 진입 경로로 숲에 들어가면 조용히 다르다.
func _to_forest() -> void:
	if _overlay != null:   # 책을 펴 놓고 E를 눌러 나가면 책이 열린 채 씬이 바뀐다
		return
	get_tree().change_scene_to_file(forest_scene_path)

## 목표 하나를 달성했다 — HUD에 알린다(보상은 GameState가 이미 창고에 넣었다). [Q]로 전체 확인.
func _on_quest_completed(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — [Q]로 확인" % q.title)

# ─────────────────────────── 거점 건설 (세션37) ───────────────────────────
## 🔴 거점은 **재료로 직접 짓는다** (사용자 확정: "거점을 내가 직접 업데이트, 시작은 아무것도 없는 상태").
## 안 지어졌으면 E=건설 시도(재료 소모), 지어졌으면 E=패널. 건설 상태는 codex(station_*)로 —
## 저장·is_unlocked·**UNLOCK 퀘스트 자동 진행**("○○를 지어라"가 건설 순간 완료)이 전부 공짜로 재사용된다.
const NOT_BUILT_MOD := Color(0.46, 0.46, 0.52)

func _station_interact(station_id: StringName, title: String, zone: InteractZone, open_fn: Callable) -> void:
	if GameState.is_unlocked(station_id):
		open_fn.call()
		return
	var cost: Dictionary = GameState.balance.station_build_costs.get(station_id, {})
	if not GameState.can_afford(cost):
		Audio.play(&"pop")
		_hud.say("%s 건설 재료 부족 — 필요: %s" % [title, _cost_text(station_id)], true)
		return
	GameState.spend(cost)
	# 🔴 codex 심기 + UNLOCK 퀘스트 진행 (GameState._on_codex_unlocked). Audio가 unlock음도 낸다.
	EventBus.codex_unlocked.emit(station_id)
	Audio.play(&"craft")
	_refresh_station(zone, station_id, title)
	_hud.say("%s 완성! 이제 [E]로 쓸 수 있다" % title)

## 세 건설형 스테이션의 겉모습·안내문을 저장된 건설 상태에 맞춘다 (_ready·건설 직후 호출).
func _refresh_stations() -> void:
	_refresh_station(_refine_zone, &"station_refine", "정제대")
	_refresh_station(_craft_zone, &"station_craft", "공방")
	_refresh_station(_decode_zone, &"station_decode", "탁본 해독대")

## 안 지어졌으면 어둡게 + "[E] 정제대 건설 (재료…)", 지어졌으면 원색 + "[E] 정제대".
func _refresh_station(zone: InteractZone, station_id: StringName, title: String) -> void:
	var built: bool = GameState.is_unlocked(station_id)
	zone.modulate = Color.WHITE if built else NOT_BUILT_MOD
	var prompt := zone.get_node_or_null("Prompt") as Label
	if prompt != null:
		prompt.text = ("[E] " + title) if built else "[E] %s 건설 (%s)" % [title, _cost_text(station_id)]

## 건설 비용을 "이름 n, 이름 n"으로 (안내·버튼 문구용). balance.station_build_costs가 정본.
func _cost_text(station_id: StringName) -> String:
	var cost: Dictionary = GameState.balance.station_build_costs.get(station_id, {})
	var parts: Array[String] = []
	for item_id: StringName in cost:
		var it := Db.get_item(item_id)
		var nm: String = it.display_name if it != null and it.display_name != "" else String(item_id)
		parts.append("%s %d" % [nm, int(cost[item_id])])
	return ", ".join(parts)

# ─────────────────────────── 고리 조립 책 ───────────────────────────

## 책상에서 E — 고리 조립 책을 편다. 이미 열려 있으면 무시.
## 🔴 책이 펼쳐지는 순간 caster를 끈다 — 안 끄면 **책을 덮는 클릭이 그대로 발사가 된다.**
## 끄는 시점을 `_forge`(패널 인스턴스)에 묶는 이유: 패널의 `is_open()`은 덮는 애니가 끝날 때까지
## 참이라, 그동안 클릭이 새어 나간다.
func _open_drawing() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)  # 조립하는 동안 이동 정지
	_player.caster.enabled = false      # 조준선·발사·슬롯 정지
	GameState.ui_modal_open = true      # 창고(I)가 책 위로 겹쳐 열리지 않게 — 모달 하나만
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_forge = forge_scene.instantiate() as RingForgePanelScript   # 진→룬→문양본→문양, 손으로 따라 그어 확정
	if _forge == null:
		push_error("forge_scene이 RingForgePanel이 아니다")
		return
	_overlay.add_child(_forge)
	_forge.design_committed.connect(_on_ring_committed)
	_forge.commit_rejected.connect(_on_ring_rejected)
	_forge.closed.connect(_close_drawing)   # ESC(ui_cancel) → 패널이 closed 발신
	_forge.open()

## 고리 마법진이 맺혔다 — RingDesign으로 감싸 GameState에 넘긴다(빈 슬롯에 자동 장착).
## 🔴 손그림 점수는 `assembly.score`를 타고 들어와 `total_score`가 된다 (세션 23).
## 세션 22까지 여기가 점수를 안 넘겨서 **저장된 도안의 total_score가 전부 0**이었다.
func _on_ring_committed(assembly: Dictionary) -> void:
	var design := RingDesign.from_assembly(assembly, "고리 마법진")
	EventBus.ring_design_committed.emit(design)

## 🔴 책을 덮었는데 **점수 미달로 안 맺혔다** (세션 25). 슬롯이 조용히 빈 채로 남으면
## "맺었는데 안 나간다"가 된다 — 사용자가 실제로 겪었고, 화면 어디에도 이유가 없었다.
func _on_ring_rejected(score: float) -> void:
	Audio.play(&"pop")
	_hud.say("마법진이 안 맺혔다 — 종합 %d점 (%d점을 넘겨야 견딘다). 책상에서 E로 다시 그려라"
		% [RingPower.score_display(score), RingPower.score_display(RingPower.threshold())], true)

func _close_drawing() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_forge = null
	_player.set_physics_process(true)
	_player.caster.enabled = true
	GameState.ui_modal_open = false

# ─────────────────────────── 정제대 (세션29) ───────────────────────────

## 정제대에서 E — 재료를 특별잉크·종이로 바꾸는 패널을 연다 (책과 같은 오버레이 슬롯·모달 규약).
## 🔴 책이 열려 있으면(_overlay != null) 안 연다 — 모달은 하나뿐이다.
## 🔴 세션37: 건설된 뒤에만 불린다 (_station_interact가 codex 확인 후 호출). 안 지어졌으면 건설 시도.
func _open_refine_panel() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)   # 정제하는 동안 이동 정지
	_player.caster.enabled = false        # 조준·발사 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_refine = RefinePanelScene.instantiate() as Control
	if _refine == null:
		push_error("refine_panel 인스턴스가 Control이 아니다")
		return
	_overlay.add_child(_refine)
	_refine.closed.connect(_close_refine)   # ESC → 패널이 closed 발신 (ui_modal_open도 패널이 끈다)
	_refine.open()

func _close_refine() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_refine = null
	_player.set_physics_process(true)
	_player.caster.enabled = true

# ─────────────────────────── 공방 (세션32) ───────────────────────────

## 공방에서 E — 재료를 장비로 만들고 착용하는 패널을 연다 (책·정제대와 같은 오버레이 슬롯·모달 규약).
## 🔴 다른 모달이 열려 있으면(_overlay != null) 안 연다 — 모달은 하나뿐이다.
func _open_workshop_panel() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)   # 공방을 쓰는 동안 이동 정지
	_player.caster.enabled = false        # 조준·발사 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_workshop = WorkshopPanelScene.instantiate() as Control
	if _workshop == null:
		push_error("workshop_panel 인스턴스가 Control이 아니다")
		return
	_overlay.add_child(_workshop)
	_workshop.closed.connect(_close_workshop)   # ESC → 패널이 closed 발신 (ui_modal_open도 패널이 끈다)
	_workshop.open()

func _close_workshop() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_workshop = null
	_player.set_physics_process(true)
	_player.caster.enabled = true

# ─────────────────────────── 탁본 해독대 (세션34 E4) ───────────────────────────

## 해독대에서 E — 룬 조각을 해독해 룬을 배우는 패널을 연다 (다른 모달과 같은 슬롯·모달 규약).
## 🔴 다른 모달이 열려 있으면(_overlay != null) 안 연다 — 모달은 하나뿐이다.
func _open_decode_panel() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)   # 해독하는 동안 이동 정지
	_player.caster.enabled = false        # 조준·발사 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_decode = DecodePanelScene.instantiate() as Control
	if _decode == null:
		push_error("decode_panel 인스턴스가 Control이 아니다")
		return
	_overlay.add_child(_decode)
	_decode.closed.connect(_close_decode)   # ESC → 패널이 closed 발신 (ui_modal_open도 패널이 끈다)
	_decode.open()

func _close_decode() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_decode = null
	_player.set_physics_process(true)
	_player.caster.enabled = true
