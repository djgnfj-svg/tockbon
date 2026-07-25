extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 **고리 조립 책**(진·룬·문양)이 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 왼쪽 숲길에서 E를 누르면 **챕터 선택**이 뜨고, 골라서 보스방 원정을 나간다 (세58-B — 옛 숲 즉시 전환 대체).
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
## 상점 패널 (세66 도파민 재편) — 돈(coin)→잉크. 정제대·공방과 같은 이유로 preload가 안전.
## 🔴 세66-2: 해독대(decode)는 은퇴했다 — 룬 획득 통로가 「조각→해독」에서 「퀘스트 턴인」으로 옮겨간다(설계 D).
const ShopPanelScene := preload("res://src/base/shop_panel.tscn")
const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 길잡이 NPC가 여는 통합 시트 패널 (세션40, 옛 quest_panel 흡수) — 퀘스트 탭으로 연다(class_name 없음).
const TabPanel := preload("res://src/hud/tab_panel.gd")
## 온보딩 그리기 튜토 대사 상자 (세션41) — 첫 마법 전 NPC가 개념을 가르친다. 루트=CanvasLayer, 스크립트=$Box.
const DialogueBoxScene := preload("res://src/hud/dialogue_box.tscn")
## 🔴 스크립트 preload = 캐스트 타입 ($Box는 get_node로 Node라, open()/finished를 정적으로 부르려면 이걸로 캐스트).
const DialogueBox := preload("res://src/hud/dialogue_box.gd")
## 🔴 위력 표시는 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다 (core에 있는 이유).
const RingPower := preload("res://src/core/ring_power.gd")
## 챕터 선택 패널 (세58-B) — 숲길 게이트 [E]가 씬 전환 대신 이 모달을 연다. 루트=CanvasLayer,
## 스크립트=$Panel (chest·dialogue_box 선례). 패널은 base를 안 물어 preload가 안전(순환 아님).
const ChapterPanelScene := preload("res://src/hud/chapter_panel.tscn")
const ChapterPanel := preload("res://src/hud/chapter_panel.gd")   # 캐스트 타입 ($Panel은 get_node로 Node라)

## 책상에서 펴는 책 (base.tscn이 ring_forge_panel.tscn을 물려 준다).
## 🔴 여긴 PackedScene이어도 된다 — **책은 base를 안 문다**(순환이 아니다). 아래와 대비된다.
@export var forge_scene: PackedScene = preload("res://src/drawing/ring_forge_panel.tscn")
## 숲길 게이트가 여는 챕터 보스방 (세58-B — 옛 forest_scene_path 자리). 🔴 **PackedScene이 아니라
## 경로다. 바꾸지 마라.** base가 boss_room을 preload하고 boss_room이 base를 preload하면 **순환**이라,
## 먼저 로드되는 쪽의 상대가 **노드 0개짜리 껍데기**로 굳는다 → 귀환·사망해도 베이스로 못 돌아간다.
## 자세한 근거는 `boss_room.gd`의 `base_scene_path` 주석. **헤드리스는 이걸 못 잡는다.**
@export_file("*.tscn") var boss_room_scene_path: String = "res://src/field/boss_room.tscn"

@onready var _desk: InteractZone = $Desk
@onready var _gate: InteractZone = $ForestGate
@onready var _refine_zone: InteractZone = $Refine
@onready var _craft_zone: InteractZone = $Craft
@onready var _shop_zone: InteractZone = $Shop
@onready var _npc: InteractZone = $Npc
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud
# 🔴 캠퍼스 바닥 (세66-4 마법학교 마을) — 잔디·돌포장 길을 코드로 깐다 (boss_room `_fill_tiles` 선례).
@onready var _ground: ColorRect = $Ground
@onready var _grass: TileMapLayer = $TileGrass
@onready var _road: TileMapLayer = $TileRoad
# 🔴 tab_panel.tscn 루트는 CanvasLayer(layer 5)고, 스크립트(Control)는 그 자식 Panel이다.
@onready var _sheet: TabPanel = $Sheet/Panel
# 🔴 길잡이 머리 위 물음표 (세션40) — 정산할 퀘스트가 있을 때만 보인다. 근접(Prompt)과 별개로 늘 뜬다.
@onready var _npc_mark: Label = $Npc/Mark

## 🔴 한 번에 하나의 모달만 — 책·정제대·공방이 같은 `_overlay` 슬롯을 쓴다. 하나 열려 있으면 다른 건 안 열린다.
var _overlay: CanvasLayer = null
var _forge: RingForgePanelScript = null
var _refine: Control = null
var _workshop: Control = null
var _shop: Control = null
## 🔴 온보딩 그리기 튜토 대사 (세션41) — 첫 마법 전 NPC가 개념을 가르친다. 이 베이스 방문에 한 번만.
var _dialogue: CanvasLayer = null
var _draw_tut_shown := false
## 챕터 선택 패널 인스턴스 (세58-B) — 온디맨드 인스턴스·닫히면 치운다 (dialogue와 같은 결.
## _overlay 슬롯을 안 쓰는 이유: 이 패널은 ui_modal_open을 스스로 토글하고 플레이어 정지도
## 폴링으로 해결돼, 책·정제대처럼 base가 물리·caster를 껐다 켤 필요가 없다).
var _chapter_sel: CanvasLayer = null

func _ready() -> void:
	# 🔴 씬 진입 시 모달 플래그를 내린다 — ui_modal_open은 오토로드라 씬 전환에도 살아남는다.
	# 어떤 경로로든 모달이 켜진 채 씬이 바뀌면 새 패널은 _open=false인데 플래그만 true라 잠긴다.
	GameState.ui_modal_open = false
	# 베이스=집 — 원정 플래그를 내린다 (귀환·사망이 다 여기로 온다).
	GameState.in_expedition = false
	# 🔴 마법학교 캠퍼스 (세66-4) — 잔디·돌포장 길을 깔고 카메라 경계를 월드에 물린다.
	_build_campus()
	_setup_camera()
	_desk.interacted.connect(_open_drawing)
	_gate.interacted.connect(_open_chapter_panel)
	# 🔴 마을 완비 (세66 도파민 재편, 설계 B) — 스테이션은 처음부터 다 있다. 건설 게이트 없이 바로 패널을 연다.
	#   세37 「빈 거점 재료 건설」(_station_interact가 station_* codex를 사서 여는 구조)은 은퇴했다.
	_refine_zone.interacted.connect(_open_refine_panel)
	_craft_zone.interacted.connect(_open_workshop_panel)
	_shop_zone.interacted.connect(_open_shop_panel)
	# 길잡이 NPC (세션37→40) — E로 그 자리서 정산하고(claim) 목표 패널을 연다.
	_npc.interacted.connect(_on_npc_talk)
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# 퀘스트 완료 알림 (세션36) — GameState가 판정, 씬은 HUD로 알린다(caster.notice와 같은 채널).
	EventBus.quest_completed.connect(_on_quest_completed)
	# 🔴 목표 달성 넛지 (세션40 턴인) — 숲에서 목표를 채우면 "돌아가 정산하라"를 HUD로 알린다.
	EventBus.quest_ready.connect(_on_quest_ready)
	# 🔴 NPC 머리 위 물음표 (세션40) — 정산할 퀘스트가 생기거나(달성·건설·해금) 없어질 때(정산) 갱신.
	EventBus.quest_ready.connect(_refresh_npc_mark)
	EventBus.quest_completed.connect(_refresh_npc_mark)
	EventBus.codex_unlocked.connect(_refresh_npc_mark)
	# 🔴 시트로 새 목표를 읽으면(mark_quests_seen → quests_seen) [!]를 끈다 (세션43).
	EventBus.quests_seen.connect(_refresh_npc_mark)
	# 🔴 첫 마법진(q00, 세션41) — 그리면 [?]가 켜지도록 그리기 완료도 물음표를 갱신한다
	#   (그리기는 베이스에서 일어나므로 "숲에서 돌아가라" 넛지 대신 옆의 길잡이 [?]로 안내한다).
	EventBus.ring_design_committed.connect(_refresh_npc_mark)
	_refresh_npc_mark()
	# 🔴 세66-2 인터림 브리지: 마을 완비 = 스테이션 codex를 미리 심어 옛 건설 퀘스트(q03~q05 UNLOCK station_*)를
	#   소급 완료시킨다 (세36 소급 경로 재사용). 건설이 사라졌으니 이 시드가 없으면 q05가 영영 미완이라 온보딩 사슬이 막힌다.
	#   station_decode도 심는다 — 해독대 자체는 은퇴했지만 q05가 그걸 노리면 소급 완료돼야 사슬이 안 막힌다.
	#   ⚠ is_unlocked 가드로 매 방문 재발신·중복 완료·audio 도배를 막는다.
	#   3단계에서 q03~q05를 삭제하고 qR1(첫 보스→첫 룬)로 교체하면 이 루프는 제거한다.
	for sid: StringName in [&"station_refine", &"station_craft", &"station_shop", &"station_decode"]:
		if not GameState.is_unlocked(sid):
			EventBus.codex_unlocked.emit(sid)
	# 🔴 온보딩 (세션41) — 첫 마법을 아직 안 그렸으면 길잡이로 유도한다 (q00 완료되면 안 뜬다).
	if not GameState.is_quest_done(&"q00_first_draw"):
		# 🔴 세84 #36: `sticky` — 온보딩 **목표**다(경고가 아니다). 수명이 붙은 뒤엔 안 붙이면
		# 첫 안내가 4.5초 뒤 사라져 새 플레이어가 어디로 갈지 모른다.
		_hud.say("길잡이에게 [E]로 말을 걸어라 — 첫 목표는 책상에서 마법진을 그리는 것이다", false, true)

# ─────────────────────────── 캠퍼스 바닥 (세66-4 마법학교 마을) ───────────────────────────

## 잔디·돌포장 길을 코드로 깐다 — boss_room `_fill_tiles` 선례. Ground(ColorRect) rect에서
## 셀 범위를 파생시켜 월드 크기를 바꿔도 자동으로 맞는다(.tscn에 tile_map_data를 굳히지 않는다).
## 🔴 아틀라스 좌표 계약(tileset_campus.tres): 잔디 (0,0)A·(1,0)B흙·(2,0)꽃 / 돌 (0,1)·plaza중심 (2,1).
func _build_campus() -> void:
	if _grass == null or _road == null or _ground == null:
		return
	var ts: int = _grass.tile_set.tile_size.x
	var w := int(_ground.size.x)
	var h := int(_ground.size.y)
	# 잔디 전역 (변형은 위치 해시로 — 장식이라 세이브 무관, 부팅마다 동일)
	for cy in range(0, ceili(float(h) / ts)):
		for cx in range(0, ceili(float(w) / ts)):
			_grass.set_cell(Vector2i(cx, cy), 0, _grass_variant(cx, cy))
	# 돌포장 길·안뜰 (설계 §3 밴드 rect — 정문↔안뜰↔건물을 잇는다)
	var bands: Array[Rect2] = [
		Rect2(240, 716, 1740, 128),    # 수평 척추: 정문↔안뜰↔매점
		Rect2(1136, 560, 128, 800),    # 수직 척추: 서고↔안뜰↔수련장
		Rect2(536, 585, 128, 259),     # 공방 분기
		Rect2(1736, 585, 128, 259),    # 실습동 분기
		Rect2(1916, 716, 128, 194),    # 매점 분기
		Rect2(1000, 580, 400, 400),    # 중앙 안뜰(plaza)
	]
	for band in bands:
		_fill_road(band, Vector2i(0, 1))
	# 안뜰 중심 = 마법진 무늬 자국 (기념비 발밑)
	_road.set_cell(Vector2i(int(1200.0 / ts), int(780.0 / ts)), 0, Vector2i(2, 1))


func _grass_variant(cx: int, cy: int) -> Vector2i:
	var hsh: int = absi((cx * 73856093) ^ (cy * 19349663)) % 100
	if hsh < 7:
		return Vector2i(2, 0)   # 꽃 7%
	elif hsh < 24:
		return Vector2i(1, 0)   # 흙 변형 17%
	return Vector2i(0, 0)


func _fill_road(rect: Rect2, atlas: Vector2i) -> void:
	var ts: int = _road.tile_set.tile_size.x
	var from := Vector2i(floori(rect.position.x / ts), floori(rect.position.y / ts))
	var to := Vector2i(ceili(rect.end.x / ts), ceili(rect.end.y / ts))
	for cy in range(from.y, to.y):
		for cx in range(from.x, to.x):
			_road.set_cell(Vector2i(cx, cy), 0, atlas)


## 카메라 경계·부드러운 추적 — Camera2D는 이미 player.tscn에 있다(공유 씬). limit·smoothing은
## 🔴 여기서 런타임에만 세팅한다 — player.tscn에 baked하면 boss_room(월드 1200×1040)이 오염된다.
func _setup_camera() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(_ground.size.x)
	cam.limit_bottom = int(_ground.size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0


# ─────────────────────────── 원정 (챕터 보스방, 세58-B) ───────────────────────────

## 🔴 출격이 **HP를 되돌리지 않는다** — 그건 보스방이 한다 (boss_room.gd `_ready`).
## 여기서 하면 "베이스에서 나갈 때만" 만HP고, 다른 진입 경로로 들어가면 조용히 다르다.
## 숲길 [E] = 챕터 선택 모달 — 순서 잠금 3챕터를 보여주고, 고르면 pending_chapter에 실어
## 보스방으로 전환한다. 잠금 판정은 패널이 한다 (해금 판정은 패널이 — 룬 셀 선례).
func _open_chapter_panel() -> void:
	if _overlay != null or _dialogue != null or _chapter_sel != null:   # 모달은 하나뿐
		return
	_chapter_sel = ChapterPanelScene.instantiate() as CanvasLayer
	add_child(_chapter_sel)
	var panel := _chapter_sel.get_node("Panel") as ChapterPanel
	panel.chapter_selected.connect(_on_chapter_selected)
	panel.closed.connect(_on_chapter_panel_closed)
	panel.open()

## 챕터를 골랐다 — 오토로드에 실어 보스방으로. change_scene_to_file은 인자를 못 실으므로
## `GameState.pending_chapter`가 나른다 (boss_room._ready가 읽어 보스·바닥색을 세운다).
func _on_chapter_selected(id: StringName) -> void:
	GameState.pending_chapter = id
	get_tree().change_scene_to_file(boss_room_scene_path)

## 패널이 닫혔다 (선택 완료·ESC 취소 둘 다 온다) — 인스턴스만 치운다 (ui_modal_open은 패널이 끈다).
func _on_chapter_panel_closed() -> void:
	if _chapter_sel != null:
		_chapter_sel.queue_free()
		_chapter_sel = null

## 🔴 길잡이 정산 (세션40) — 말 걸면 달성(claimable)한 퀘스트를 그 자리서 정산하고 목표 패널을 연다.
##  quest_completed가 아래 _on_quest_completed로 HUD 완료 팝을 쏘므로 여기선 정산·개방만 한다.
##  "살아 돌아와라"는 실제 귀환(extraction_success)이 이미 채워 놨을 때만 여기서 함께 정산된다(공짜 완료 없음).
func _on_npc_talk() -> void:
	# 🔴 온보딩 (세션41): 아직 첫 마법진을 안 그렸으면(ring_designs 빔) NPC가 그리기 개념부터 가르친다.
	#   대사가 끝나면 목표를 시트로 보여준다. 한 번 그리고 나면(또는 이미 봤으면) 정상 흐름(정산+시트).
	if _dialogue == null and _overlay == null and not _draw_tut_shown \
			and not GameState.is_quest_done(&"q00_first_draw") and GameState.ring_designs.is_empty():
		_start_draw_tutorial()
		GameState.mark_quests_seen()   # 🔴 첫 목표 접수 (세션43) — [!]를 끈다. 튜토 대사가 곧 설명한다
		_refresh_npc_mark()
		return
	# 🔴 정산(턴인) + [!] 유도 (세션40→43). 달성한 목표를 정산하고 보상을 준다(_on_quest_completed가
	#  HUD 완료 팝). 🔴 정산으로 새 목표가 열리면 시트를 **강제로 열지 않는다** — [!]로 남겨 "[Tab]으로
	#  확인"을 당긴다(그래야 [!]가 중간 게임에서도 산다, 세션43). 정산할 게 없는 순수 방문일 때만 시트를
	#  열어 목표를 훑게 한다(=열람이 접수 처리 → [!] 꺼짐).
	var claimed := GameState.claim_ready_quests()
	if not claimed.is_empty():
		# 🔴 정산 대사 (세션44) — 조용히 보상만 주지 않고 길잡이가 치하하고 다음을 가리킨다.
		_start_turnin_dialogue(claimed)
	else:
		_sheet.open_quest()   # 열람 → tab_panel이 mark_quests_seen → quests_seen → _refresh_npc_mark
	_refresh_npc_mark()

## 🔴 그리기 개념 튜토 대사 (세션41) — 그리기 패널은 단계마다 스스로 안내하므로(ring_forge_panel `_say`),
##  여기선 **패널을 열기 전의 개념**(마법진=진·룬·문양을 손으로 그린다)만 심고 책상으로 보낸다.
const DRAW_TUTORIAL_LINES := [
	"마법은 외우는 게 아니라 그리는 것이라네. 저 책상에서 마법진을 손으로 그려 힘을 담지.",
	"마법진은 세 겹일세. 진(陣) — 바깥 그릇이자 날아갈 몸통. 룬 — 가운데에 담는 속성(자네는 아직 불뿐이지). 문양 — 진과 룬 사이 칸을 채우는 무늬.",
	"책을 펴면 오른쪽에서 진·룬·문양을 고르고, 왼쪽 판에 뜬 밑그림을 손으로 따라 긋게. 정성껏 따라 그을수록 마법이 세지네.",
	"다 그렸으면 [분석]으로 점수를 보고 [마력 주입]으로 맺네. 너무 엉성하면 펑 하고 날아가니 조심.",
	"자, 저 책상으로 가서 [E]로 첫 마법진을 그려 보게. 목표는 언제든 [Tab] 시트에서 볼 수 있네.",
]

## 대사 상자를 띄워 그리기 개념을 가르친다. 끝나면(또는 ESC 건너뛰면) 목표를 시트로 보여준다.
func _start_draw_tutorial() -> void:
	_draw_tut_shown = true
	# 🔴 대사 끝나면 닫고 책상으로 보낸다 — 시트를 자동으로 또 열지 않는다(마지막 줄이 [Tab]로 안내하므로).
	_show_dialogue(DRAW_TUTORIAL_LINES)

## 🔴 공용 대사 헬퍼 (세션41 튜토·세션44 정산이 함께 쓴다) — dialogue_box를 띄우고 끝나면 정리한다.
##  dialogue_box가 스스로 모달·일시정지를 잡으므로(ui_modal_open) 여기선 인스턴스·해제만 한다.
##  🔴 이미 대사·다른 모달이 떠 있으면 안 띄운다(모달 하나만 — 책·정제대와 같은 규약).
func _show_dialogue(lines: Array) -> void:
	if _dialogue != null or _overlay != null:
		return
	_dialogue = DialogueBoxScene.instantiate() as CanvasLayer
	add_child(_dialogue)
	var box := _dialogue.get_node("Box") as DialogueBox
	box.finished.connect(func() -> void:
		if _dialogue != null:
			_dialogue.queue_free()
			_dialogue = null)
	box.open(lines)

## 🔴 정산(턴인) 대사 (세션44, 사용자: "퀘스트 완료할 때도 대화가 있어야") — 달성한 목표를
##  치하하고 보상을 밝히고 다음을 가리킨다. 대사는 QuestDef.title·reward_items에서 조립한다
##  (퀘스트별 전용 대사 필드 없이 = 스키마 불변). 여러 목표를 한 번에 정산하면 각각 한 줄.
func _start_turnin_dialogue(claimed: Array) -> void:
	var lines: Array[String] = []
	for qid: StringName in claimed:
		var q := Db.get_quest(qid)
		if q == null:
			continue
		var reward := _reward_text(q)
		if reward != "":
			lines.append("「%s」— 해냈군! 약속한 삯일세, %s. 잘 챙겨 두게." % [q.title, reward])
		else:
			lines.append("「%s」— 해냈군! 자네 솜씨가 여물어 가는군." % q.title)
	if lines.is_empty():
		return
	# 🔴 정산으로 새 목표가 열렸으면 [Tab]으로 유도(시트를 강제로 열지 않는다 = [!] 유지, 세션43).
	if GameState.has_new_quest():
		lines.append("새 할 일이 생겼네 — [Tab] 시트에서 다음 목표를 확인하게.")
	else:
		lines.append("당분간은 이걸로 됐네. 몸 성히 다녀오게.")
	_show_dialogue(lines)

## 퀘스트 완료 보상을 "이름 n개, 이름 n개"로 (정산 대사용). QuestDef.reward_items가 정본.
func _reward_text(q: QuestDef) -> String:
	var parts: Array[String] = []
	for item_id: StringName in q.reward_items:
		var it := Db.get_item(item_id)
		var nm: String = it.display_name if it != null and it.display_name != "" else String(item_id)
		parts.append("%s %d개" % [nm, int(q.reward_items[item_id])])
	return ", ".join(parts)

## 목표 하나를 정산 완료했다 — HUD에 알린다(보상은 GameState가 이미 창고에 넣었다). [Q]로 전체 확인.
func _on_quest_completed(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 완료: %s (+보상) — [Q]로 확인" % q.title)

## 🔴 목표 달성 넛지 (세션40) — 아직 완료 아님. 길잡이에게 돌아가 정산하라고 HUD로 민다.
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 길잡이에게 돌아가 정산하라 [?]" % q.title)

## 🔴 길잡이 머리 위 마크 갱신 (세션40 [?] + 세션43 [!]). 시그널·초기화 양쪽에서 부른다.
##  우선순위: 정산 대기(claimable)면 [?](보상 받으러) · 아니면 안 읽은 새 목표면 [!]([Tab]으로 확인) ·
##  둘 다 없으면 숨김. 색으로도 구분 — [!] 노랑(새 목표 있음) · [?] 초록(가서 정산=보상). 연출값이라 const.
const MARK_NEW := Color(1.0, 0.9, 0.3)      ## [!] 안 읽은 새 목표 — [Tab] 시트로 확인하라
const MARK_CLAIM := Color(0.5, 0.92, 0.45)  ## [?] 달성 — 길잡이에게 가서 정산(보상)하라
func _refresh_npc_mark(_a: Variant = null) -> void:
	if GameState.has_claimable_quest():
		_npc_mark.text = "?"
		_npc_mark.add_theme_color_override(&"font_color", MARK_CLAIM)
		_npc_mark.visible = true
	elif GameState.has_new_quest():
		_npc_mark.text = "!"
		_npc_mark.add_theme_color_override(&"font_color", MARK_NEW)
		_npc_mark.visible = true
	else:
		_npc_mark.visible = false

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
	_forge = forge_scene.instantiate() as RingForgePanelScript   # 진→룬→문양, 손으로 따라 그어 확정
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
## 🔴 세66: 마을 완비 — 건설 게이트 없이 존이 바로 이걸 부른다 (세37 건설 은퇴).
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

# ─────────────────────────── 상점 (세66 도파민 재편) ───────────────────────────

## 상점에서 E — 돈(coin)을 잉크로 바꾸는 패널을 연다 (책·정제대·공방과 같은 오버레이 슬롯·모달 규약).
## 🔴 다른 모달이 열려 있으면(_overlay != null) 안 연다 — 모달은 하나뿐이다.
func _open_shop_panel() -> void:
	if _overlay != null:
		return
	_player.set_physics_process(false)   # 상점을 쓰는 동안 이동 정지
	_player.caster.enabled = false        # 조준·발사 정지
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_shop = ShopPanelScene.instantiate() as Control
	if _shop == null:
		push_error("shop_panel 인스턴스가 Control이 아니다")
		return
	_overlay.add_child(_shop)
	_shop.closed.connect(_close_shop)   # ESC → 패널이 closed 발신 (ui_modal_open도 패널이 끈다)
	_shop.open()

func _close_shop() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_shop = null
	_player.set_physics_process(true)
	_player.caster.enabled = true
