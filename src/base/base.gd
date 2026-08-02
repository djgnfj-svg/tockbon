extends Node2D
## 마을(허브) — 게임의 진입점(project.godot run/main_scene). 책상 [E]로 고리 조립 책을 씬 전환 없이
## 띄우고, 숲길 문 [E]가 세계관 대사·퀘스트 정산·출발을 혼자 다 맡는다.
## 🔴 조준·발사·슬롯은 여기 없다 — `src/actors/player_caster.gd`가 쥔다(복사하면 `to_assembly()`를
##   빼먹는 함정까지 복사돼 손그림 점수가 조용히 빠진다). 여기는 caster를 HUD에 잇기만 한다.
##
## 🔴 씬(base.tscn)의 조용히 깨지는 자리 — .tscn엔 주석을 못 달아 여기 적는다:
##  • `Ground.mouse_filter = IGNORE` — 지우면 화면을 덮은 ColorRect가 좌클릭을 전부 먹어 `_unhandled_input`이
##    안 오고 **발사가 통째로 죽는다**(에러도 경고도 없다. 같은 이유로 HUD도 IGNORE다).
##  • Player = 레이어 2 · Desk·ForestGate = 레이어 64(interaction) — world(1)에 두면 캐리어 마스크 5에
##    걸려 **쏘는 순간 내 몸/책상에 부딪혀 총구에서 죽는다.**
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(z 0) 뒤에 가려 안 보인다.
##  • 스폰 바로 위 390px엔 layer-1(world) 몸이 하나도 없어야 한다 — 진이 총구에서 죽는지 재는 테스트가
##    그 자리로 쏜다(그래서 잔해 프롭은 북동·남동으로 비껴 놨다).
##  • 허수아비 5는 스폰에서 사거리(≈390px) 안 · **이웃 간격 90px 미만**(감전 연쇄 반경) — 더 벌리면
##    연습장에서 연쇄가 한 번도 안 터지고, 더 멀리 두면 걸어가기 전엔 안 닿아 장식이 된다.
##  • 스폰을 옮기려면 허수아비 5개와 도로 밴드(`_build_campus`)를 **같이** 옮겨라.

const RingForgePanelScript := preload("res://src/drawing/ring_forge_panel.gd")
const WorkshopPanelScript := preload("res://src/base/workshop_panel.gd")
const WorkshopPanelScene := preload("res://src/base/workshop_panel.tscn")
const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 온보딩 대사 상자. 루트=CanvasLayer, 스크립트=$Box.
const DialogueBoxScene := preload("res://src/hud/dialogue_box.tscn")
## 🔴 스크립트 preload = 캐스트 타입 ($Box는 get_node로 Node라 open()/finished를 정적으로 부르려면 필요).
const DialogueBox := preload("res://src/hud/dialogue_box.gd")
## 🔴 위력 표시를 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다.
const RingPower := preload("res://src/core/ring_power.gd")

## 🔴 게이트 표 — {씬 노드 이름: codex 해금 id}. 해금 전 = 잔해(잠김) · 해금 후 = 온전(열림).
## 🔴🔴 **노드 이름으로 찾으므로 노드가 없거나 개명하면 조용히 no-op이다.** 지금 표가 비어 있어
##   「마을 되살리기」는 잠들어 있다(은퇴가 아니다 — 기계·프롭·패널·레시피는 전부 살아 있다).
## 🔴 되살릴 땐 **넷이 한 덩어리다**: ① `base.tscn`에 프롭 노드 ② 여기 `{"노드이름": &"station_*"}` 한 줄
##   ③ 그 퀘스트의 `reward_unlock`에 같은 id ④ `_ready`에 `interacted.connect(...)` + 여는 함수.
##   🔴🔴 **②만 하고 ③을 빠뜨리면 그 건물은 영영 잔해**인데 기존 세이브엔 옛 값이 남아 F5로는 안 드러난다
##   (새 게임에서만 죽는다) = 이 프로젝트가 제일 비싸게 배운 형태의 침묵.
## ⚠ 표가 비면 `_refresh_village_tint`가 곧장 return하므로 `Dusk`는 `TINT_RUINED`로 고정이다.
const STATION_UNLOCKS: Dictionary = {}

## 온전할 때만 보이는 자식 — 잔해 위에 상인(`Keeper`)이 서 있으면 안 되고, **폐허엔 빛이 없다**(`LightPool`).
## 밝기·색은 씬이 쥐고 맥동은 `light_pool.gd`가 쥔다 — 여기선 보이나 마나만 가른다.
const WHOLE_ONLY_PARTS: Array[String] = ["Sprite", "Keeper", "LightPool"]
## 잔해일 때만 보이는 자식.
## 🔴 **표에 건물을 올리면 `Ruin` 자식을 반드시 같이 달아라** — 없으면 잔해 동안 `Sprite`만 꺼져
##   건물이 통째로 안 보인다. ⚠ 기념비는 여기 안 든다(영구 잔해라 전환 자체가 없다).
const RUIN_PART := "Ruin"

## 🔴 마을 색조 = 진행도. 되돌린 건물이 늘수록 `Dusk`(CanvasModulate)가 회보라 → 중립으로 간다.
## 🔴 **밝기는 유지한다**(성분 전부 0.86 이상) — 「어두운 폐허」는 각하됐다.
## ⚠ `CanvasModulate`는 곱하기뿐이라 **채도를 못 뺀다** — 「색을 빼는」 일은 잔해 아트가 한다.
## 연출값이라 balance가 아니라 const다.
const TINT_RUINED := Color(0.90, 0.86, 1.00)   ## 아무것도 못 되돌린 폐허 — 옅은 회보라
const TINT_WHOLE := Color(1.0, 1.0, 1.0)       ## 마을이 돌아왔다 — 중립

## 책상에서 펴는 책. 🔴 여긴 PackedScene이어도 된다 — **책은 base를 안 문다**(순환이 아니다).
@export var forge_scene: PackedScene = preload("res://src/drawing/ring_forge_panel.tscn")
## 숲길 게이트가 여는 챕터 보스방. 🔴 **PackedScene이 아니라 경로다. 바꾸지 마라** — base가 boss_room을
## preload하고 boss_room이 base를 preload하면 **순환**이라 먼저 로드되는 쪽의 상대가 **노드 0개짜리
## 껍데기**로 굳는다(귀환·사망해도 마을로 못 돌아온다). **헤드리스는 이걸 못 잡는다.**
@export_file("*.tscn") var boss_room_scene_path: String = "res://src/field/boss_room.tscn"

@onready var _desk: InteractZone = $Desk
## 🔴 문 하나가 「나가는 길」과 「화자·정산」을 겸한다 — 계약 정본은 `_on_gate_talk` 머리말.
@onready var _gate: InteractZone = $ForestGate
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud
@onready var _ground: ColorRect = $Ground
@onready var _grass: TileMapLayer = $TileGrass
@onready var _road: TileMapLayer = $TileRoad
# 문 위 물음표 — 정산할 퀘스트가 있을 때만 보인다(근접 Prompt와 별개로 늘 뜬다).
#   ⚠ 노드는 `base.tscn`이 `ForestGate`의 자식으로 단다 — 공용 프롭 씬에 넣으면 정산도 없는 [?]가
#   보스방·다른 무대에 따라간다.
@onready var _gate_mark: Label = $ForestGate/Mark

## 🔴 한 번에 하나의 모달만 — `_overlay` 슬롯이 비어 있어야 새 패널이 열린다.
var _overlay: CanvasLayer = null
var _forge: RingForgePanelScript = null
## 책 위에 겹쳐 뜨는 공방(재료 → 부품). null이면 안 열려 있다.
var _workshop: WorkshopPanelScript = null
## 오프닝 대사 — 이 마을 방문에 한 번만.
var _dialogue: CanvasLayer = null
var _gate_intro_shown := false

func _ready() -> void:
	# 🔴 ui_modal_open은 오토로드라 씬 전환에도 살아남는다 — 모달이 켜진 채 씬이 바뀌면 새 패널은
	# 닫혀 있는데 플래그만 true라 영영 잠긴다.
	GameState.ui_modal_open = false
	# 마을=집 — 원정 플래그를 내린다 (귀환·사망이 다 여기로 온다).
	GameState.in_expedition = false
	_build_campus()
	_setup_camera()
	_desk.interacted.connect(_open_drawing)
	# 🔴🔴 문 [E] 하나에 두 일이 실린다 — 정산 대사 → 출발. **`_depart_to_chapter`를 직접 잇지 마라**
	#   (그러면 정산이 통째로 빠지는데, 연결 개수만 세는 그물은 그 형태를 못 잡는다).
	_gate.interacted.connect(_on_gate_talk)
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# 판정은 GameState가, 알림은 씬이 HUD로 (caster.notice와 같은 채널).
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_ready.connect(_on_quest_ready)
	# 문 위 마크 — 정산 대기가 생기거나 없어지는 **모든** 경로에서 갱신한다(달성·해금·정산·시트 읽기·조립).
	EventBus.quest_ready.connect(_refresh_gate_mark)
	EventBus.quest_completed.connect(_refresh_gate_mark)
	EventBus.codex_unlocked.connect(_refresh_gate_mark)
	EventBus.quests_seen.connect(_refresh_gate_mark)
	EventBus.ring_design_committed.connect(_refresh_gate_mark)
	_refresh_gate_mark()
	# 🔴🔴 마을 되살리기 — `_ready`(초기 상태)와 `codex_unlocked`(전환) **둘 다** 필요하다: 수신만
	#   있으면 「이어하기」가 되살린 건물을 잔해로 띄우고, 초기화만 있으면 정산해도 **그 방문 내내
	#   잠긴 채**다(마을을 나갔다 와야 열린다 = 에러 없는 침묵).
	# ⚠ 지금은 `STATION_UNLOCKS`가 비어 둘 다 no-op이지만 배선은 **일부러 남긴다** — 표에 한 줄이
	#   돌아오는 순간 그대로 살아나야 한다(걷어 두면 「표만 채웠는데 아무 일도 안 일어난다」를 다시 캔다).
	EventBus.codex_unlocked.connect(_on_station_unlocked)
	_refresh_stations()
	# 온보딩 — 첫 마법진을 아직 안 맺었으면 **문**으로 유도한다.
	if not GameState.is_quest_done(&"q00_first_draw"):
		# 🔴 `sticky` — 온보딩 **목표**다(경고가 아니다). 안 붙이면 첫 안내가 4.5초 뒤 사라져
		# 새 플레이어가 어디로 갈지 모른다.
		_hud.say("문이 너를 불렀다 — 문 앞에서 [E]", false, true)

# ─────────────────────────── 캠퍼스 바닥 ───────────────────────────

## 잔디·돌포장 길을 코드로 깐다 — Ground(ColorRect) rect에서 셀 범위를 파생시켜 월드 크기를 바꿔도
## 자동으로 맞는다(.tscn에 tile_map_data를 굳히지 않는다).
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
	# 🔴🔴 **여기와 `base.tscn` 배치는 한 몸이다** — 밴드만 옮기면 길이 건물과 어긋나고, 씬만 옮기면
	#   건물이 잔디 위에 뜬다. 안 닿는 길을 남기면 「잔디 위로 뻗어 아무 데도 안 닿는 길」이 된다(에러 0).
	# 🔴 **한 장으로 깐다** — 두 사각형으로 마당+진입로를 나누면 겹치는 자리에서 **직각 계단이 크게 튀어**
	#   「길」이 아니라 「잘못 깐 바닥」으로 읽힌다(실측 스샷).
	# ⚠ 범위는 남은 넷을 다 덮도록 잡았다: 문(200,820)·기념비(620,920)·책상(860,840)·허수아비(395~470,
	#   968~1132). 하나를 옮기면 여기도 같이 본다. 안 쓰는 자리를 깎으면 광장 한복판에 잔디 구멍이 뚫린다.
	var bands: Array[Rect2] = [
		Rect2(200, 660, 760, 440),     # 문 앞 폐허 광장 — 이게 지금 마을의 전부다
	]
	for band in bands:
		_fill_road(band, Vector2i(0, 1))
	# 마법진 무늬 자국 = 기념비(깨진 마법진) 발밑.
	# 🔴 좌표를 **베끼지 않고 기념비 노드에서 파생**한다 — 손으로 적으면 캠퍼스를 옮길 때 무늬만 옛
	#   자리에 남아 **잔디 한복판에 뜬다**(에러 0 = 「파생 대신 복제」).
	var monu := get_node_or_null(^"Monument") as Node2D
	if monu != null:
		_road.set_cell(Vector2i(floori(monu.position.x / ts), floori(monu.position.y / ts)), 0, Vector2i(2, 1))


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


## 카메라 경계·부드러운 추적 — Camera2D는 이미 player.tscn에 있다(공유 씬).
## 🔴 limit·smoothing은 **런타임에만** 세팅한다 — player.tscn에 baked하면 월드 크기가 다른 boss_room이 오염된다.
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


# ─────────────────── 마을 되살리기 소비자 (위 STATION_UNLOCKS 참조) ───────────────────

## 해금이 하나 들어왔다 — 마을 건물 id일 때만 되돌린다(룬·진·고리·챕터 클리어는 조용히 지나간다).
func _on_station_unlocked(unlock_id: StringName) -> void:
	if not STATION_UNLOCKS.values().has(unlock_id):
		return
	_refresh_stations()


## 표의 건물마다 codex 상태를 겉모습·상호작용에 반영한다.
## 🔴 `_ready`(초기 상태)와 `_on_station_unlocked`(전환)가 **같은 함수**를 부른다 — 두 경로가 갈라지면
## 「새로 들어오면 잔해인데 그 자리서 깨면 온전」 같은 모순이 조용히 생긴다.
func _refresh_stations() -> void:
	for node_name: String in STATION_UNLOCKS:
		var zone := get_node_or_null(node_name) as InteractZone
		if zone == null:
			continue   # 노드를 옮기거나 이름을 바꿔도 여기서 죽지 않는다
		_apply_station_state(zone, GameState.is_unlocked(STATION_UNLOCKS[node_name]))
	_refresh_village_tint()


## 건물 하나의 상태 — `built=false`면 잔해다: [E] 안내가 안 뜨고 눌러도 아무 일이 없다.
##
## 🔴 게이트를 **`monitoring`으로** 건다(시그널 연결을 끊었다 잇는 게 아니라): ① 안내(Prompt)와 E 입력이
##   한 손잡이로 같이 닫힌다 ② 연결을 끊었다 잇는 수법은 「리페어런팅 시 콜백이 영구히 죽는」 함정을 심는다.
## ⚠ **몸(`Body`)은 안 건드린다** — 잔해도 단단하고, 그 몸이 `collision_layer = 1`(world)이라 건드리면
##   「진이 총구에서 안 죽는다」 그물에 닿는다.
## ⚠ `set_deferred` — Area2D의 `monitoring`은 물리 질의 flush 중에 바꾸면 엔진이 **조용히 무시**한다.
func _apply_station_state(zone: InteractZone, built: bool) -> void:
	zone.set_deferred(&"monitoring", built)
	var prompt := zone.get_node_or_null(^"Prompt") as CanvasItem
	if prompt != null and not built:
		# 잠그는 순간 안내가 떠 있었으면 내린다 — monitoring을 끄면 body_exited가 안 온다.
		prompt.visible = false
	# 🔴 잔해/온전을 **따로** 가른다 — 짝으로 묶어 `Ruin`이 없으면 통째로 return하면 `LightPool`(빛 웅덩이)이
	#   `Ruin` 없는 프롭에서 **조용히 안 꺼진다**(폐허가 빛나는데 에러가 0이다).
	var ruin := zone.get_node_or_null(RUIN_PART) as CanvasItem
	if ruin != null:
		ruin.visible = not built
	for part_name: String in WHOLE_ONLY_PARTS:
		var part := zone.get_node_or_null(part_name) as CanvasItem
		if part != null:
			part.visible = built


## 마을 색조 = 되돌린 건물 비율.
## 🔴 분모를 표(`STATION_UNLOCKS`)에서 **파생**한다 — 손으로 적으면 건물을 하나 늘릴 때 색조만 조용히
## 옛 비율로 남는다.
func _refresh_village_tint() -> void:
	var dusk := get_node_or_null(^"Dusk") as CanvasModulate
	if dusk == null or STATION_UNLOCKS.is_empty():
		return
	var built := 0
	for node_name: String in STATION_UNLOCKS:
		if GameState.is_unlocked(STATION_UNLOCKS[node_name]):
			built += 1
	dusk.color = TINT_RUINED.lerp(TINT_WHOLE, float(built) / float(STATION_UNLOCKS.size()))


# ─────────────────────────── 원정 (챕터 보스방) ───────────────────────────

## 🔴 출격이 **HP를 되돌리지 않는다** — 그건 보스방이 한다. 여기서 하면 "마을에서 나갈 때만" 만HP고,
## 다른 진입 경로로 들어가면 조용히 다르다.
## 🔴 챕터 id를 하드코딩하지 않는다 — `Db.chapters_sorted()`의 맨 앞(order 최솟값)이 정본이다. 상수로
##   베끼면 「새 챕터 = .tres 한 장」이 깨지고, 1장을 개명하면 조용히 빈 `pending_chapter`로 나간다.
## 🔴🔴 `pending_chapter`를 **반드시 채운다** — `change_scene_to_file`은 인자를 못 실어 이 오토로드가
##   나르고, 비면 `boss_room._ready`가 설계대로 마을로 되돌린다(= 「나갔는데 도로 마을」, 에러 0).
##   그래서 챕터가 0장이면 **전환 자체를 안 한다** — 그 왕복은 플레이어에게 무반응으로만 보인다.
## ⚠ 아래 모달 가드는 로그 없이 return하지만 **어느 갈래도 「눌렀는데 아무 일도 안 난다」로 끝나지 않는다**
##   (모달 중엔 `ui_modal_open`이라 문 [E]가 애초에 안 오고, 대사는 끝나면 체이닝이 다시 부른다).
func _depart_to_chapter() -> void:
	if _overlay != null or _dialogue != null:   # 모달 중엔 안 나간다 (플래그를 켠 채 씬이 바뀐다)
		return
	var chapters := Db.chapters_sorted()
	if chapters.is_empty():
		_hud.say("나갈 곳이 없다 — 챕터를 못 읽었다 (data/chapters/*.tres)", true)
		return
	GameState.pending_chapter = chapters[0].id
	get_tree().change_scene_to_file(boss_room_scene_path)

## 🔴🔴 **문 [E] = 정산 + 원정.**
##  ⓐ 정산할 목표가 있으면 문이 먼저 말을 걸고(대사) → **끝나면 그대로** 출발로 이어진다.
##  ⓑ 정산할 게 없으면 **대사 없이 바로** 출발이다 — 안 그러면 "나가려는데 자꾸 대사가 뜬다"가 된다.
##
## 🔴🔴 **[E] 하나에 두 일을 태울 때 조용히 깨지는 자리 둘** (전부 실측된 것이다):
##  ⓐ `interact_zone`은 `GameState.ui_modal_open`이면 E를 **통째로 안 받고**, `dialogue_box.open()`이
##     그 플래그를 켠다 → 대사 중엔 문의 E가 죽는다. 그래서 출발을 **`finished`에 명시로 체이닝**한다.
##     안 하면 플레이어가 **E를 두 번** 눌러야 나간다.
##  ⓑ 🔴🔴 대사가 **한 줄도 안 나올 수 있다** — `Db.get_quest`가 전부 null이면 `_start_turnin_dialogue`가
##     `false`를 돌려주고 `finished`는 **영영 안 온다**. 그래서 출발을 `finished`에만 걸지 않고
##     **여기서 `false`를 받아 즉시 나간다** — 안 그러면 마을 밖으로 못 나가는 소프트락이다.
func _on_gate_talk() -> void:
	# 온보딩 — 아직 첫 마법진을 안 맺었으면 문이 먼저 이야기하고 **책상으로 보낸다**(여기선 안 나간다).
	#   ⚠ 문을 잠그는 게 아니다: `_gate_intro_shown`으로 이 방문에 한 번만 뜨고, 다음 [E]부턴 정상 흐름이다.
	if _dialogue == null and _overlay == null and not _gate_intro_shown \
			and not GameState.is_quest_done(&"q00_first_draw") and GameState.ring_designs.is_empty():
		_start_gate_intro()
		GameState.mark_quests_seen()   # 첫 목표 접수 — [!]를 끈다(오프닝 대사가 곧 설명한다)
		_refresh_gate_mark()
		return
	# 정산(턴인). 🔴 새 목표가 열려도 시트를 **강제로 열지 않는다** — [!]로 남겨 "[Tab]으로 확인"을 당긴다.
	#  ⚠ 정산할 게 없을 때도 시트를 안 연다: 문은 나가는 자리라 나가려고 누른 [E]가 시트를 여는 건 손에 안 맞는다.
	var claimed := GameState.claim_ready_quests()
	_refresh_gate_mark()
	if claimed.is_empty():
		_depart_to_chapter()   # ⓑ 순수 원정 — 대사 없이 바로
		return
	# ⓑ 대사를 못 띄웠으면(줄이 비었거나 다른 모달) **여기서 바로** 출발한다.
	if not _start_turnin_dialogue(claimed):
		_depart_to_chapter()

## 문의 오프닝 대사 — 가르치는 것 넷: ⓐ 왜 여기 있나(세계관) ⓑ 마법은 **조립해서 맺는다** ⓒ 책상 [E] ⓓ [Tab].
##  ⚠ 책 안의 단계별 안내는 `ring_forge_panel._say`가 하므로 여기선 **책을 펴기 전의 것만** 심는다.
##  ⚠ 화자는 문이다 — 짧고 건조하게.
const GATE_INTRO_LINES := [
	"…왔군. 늦었다.",
	"오래전 이 땅의 큰 마법진이 깨졌다. 문양이 전부 저 너머로 흩어졌다.",
	"나는 그때 남은 마지막 마법이고, 조각들이 빠져나간 길이다. 그래서 너를 불렀다.",
	"너는 이 세계의 마법을 배운 적이 없다. 외울 것도 없다 — 주워 온 조각을 이어 붙이면 된다.",
	"저 책상으로 가라. [E]로 책을 펴고 진·룬·문양을 골라 마법진 하나를 맺어라.",
	"할 일은 [Tab]으로 볼 수 있다. 가라.",
]

## 정산 대사의 **머리말** — 그 퀘스트를 처음 정산하는 순간에만 한 줄 앞에 붙는다.
##  ⚠ 여기 없는 퀘스트는 일반 문구만 나간다 — **표를 안 채워도 안 깨진다**(거짓 손잡이가 아니다).
##  ⚠ 퀘스트별 전용 대사를 `QuestDef`에 넣지 않은 이유 = 스키마 불변.
const TURNIN_PROLOGUE := {
	&"q00_first_draw": "네가 방금 맺은 그것이, 깨진 마법진의 조각 하나다. 나머지는 전부 저 너머로 흩어졌다.",
}

## 세계관·첫 목표를 심는다. 🔴 여기선 출발로 **안 이어진다**(아직 나갈 때가 아니다 — 먼저 책상).
func _start_gate_intro() -> void:
	_gate_intro_shown = true
	_show_dialogue(GATE_INTRO_LINES)

## 공용 대사 헬퍼(오프닝·정산이 함께 쓴다) — 상자를 띄우고 끝나면 정리한다. 모달·일시정지는 상자가 스스로 잡는다.
##  🔴 이미 대사·다른 모달이 떠 있으면 안 띄운다(모달 하나만) → **false를 돌려준다.**
##  🔴🔴 `on_finished`는 **상자를 치운 뒤** 같은 람다 안에서 부른다(별도 `finished` 연결이 아니다) —
##   연결 순서에 기대면 `_dialogue`가 아직 non-null인 채로 후속이 돌아 `_depart_to_chapter`의 가드에
##   조용히 걸린다(= "대사가 끝났는데 안 나간다", 에러 0).
##  ⚠ `lines`가 비면 `open()`이 **그 자리에서** finished를 쏜다 → `on_finished`도 즉시 돈다(계약 유지).
func _show_dialogue(lines: Array, on_finished: Callable = Callable()) -> bool:
	if _dialogue != null or _overlay != null:
		return false
	_dialogue = DialogueBoxScene.instantiate() as CanvasLayer
	add_child(_dialogue)
	var box := _dialogue.get_node("Box") as DialogueBox
	box.finished.connect(func() -> void:
		if _dialogue != null:
			_dialogue.queue_free()
			_dialogue = null
		if on_finished.is_valid():
			on_finished.call())
	box.open(lines)
	return true

## 정산(턴인) 대사 — 정산한 목표를 짚고 보상을 밝히고 다음을 가리킨다. 대사는 `QuestDef.title`·
##  `reward_items`에서 조립한다(퀘스트별 전용 대사 필드 없이 = 스키마 불변).
##
## 🔴🔴 **반환값이 계약이다**: 대사를 실제로 띄웠으면 true. false면 `finished`가 **영영 안 오므로**
##  호출부가 그 자리에서 출발시켜야 한다(안 그러면 마을 밖으로 못 나간다).
func _start_turnin_dialogue(claimed: Array) -> bool:
	var lines: Array[String] = []
	for qid: StringName in claimed:
		var q := Db.get_quest(qid)
		if q == null:
			continue
		if TURNIN_PROLOGUE.has(qid):
			lines.append(String(TURNIN_PROLOGUE[qid]))
		var reward := _reward_text(q)
		if reward != "":
			lines.append("「%s」— 됐다. 약속한 것을 놓아 두었다: %s" % [q.title, reward])
		else:
			lines.append("「%s」— 됐다." % q.title)
	if lines.is_empty():
		return false
	# 새 목표가 열렸으면 [Tab]으로 유도(시트를 강제로 열지 않는다 = [!] 유지).
	if GameState.has_new_quest():
		lines.append("다음이 열렸다 — [Tab]으로 확인해라. 문을 연다.")
	else:
		lines.append("문을 연다.")
	# 🔴 마지막 줄("문을 연다")과 **같은 손잡이**로 출발한다 — 머리말 ⓐ의 체이닝이다.
	return _show_dialogue(lines, _depart_to_chapter)

## 퀘스트 완료 보상을 "이름 n개, 이름 n개"로 (정산 대사용). QuestDef.reward_items가 정본.
func _reward_text(q: QuestDef) -> String:
	var parts: Array[String] = []
	for item_id: StringName in q.reward_items:
		var it := Db.get_item(item_id)
		var nm: String = it.display_name if it != null and it.display_name != "" else String(item_id)
		parts.append("%s %d개" % [nm, int(q.reward_items[item_id])])
	return ", ".join(parts)

## 목표 하나를 정산 완료했다 — HUD에 알린다(보상은 GameState가 이미 창고에 넣었다).
func _on_quest_completed(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 완료: %s (+보상) — [Q]로 확인" % q.title)

## 목표 달성 넛지 — 아직 완료가 아니다. 문에서 정산하라고 HUD로 민다.
##  ⚠ 여긴 마을이라 "돌아가"가 아니다 — 그 문구는 원정 중에 뜨는 `boss_room._on_quest_ready`가 쥔다.
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 문에서 [E]로 정산하라 [?]" % q.title)

## 문 위 마크 — 정산 대기(claimable)면 [?] · 아니면 안 읽은 새 목표면 [!] · 둘 다 없으면 숨김.
##  연출값이라 const.
const MARK_NEW := Color(1.0, 0.9, 0.3)      ## [!] 안 읽은 새 목표 — [Tab] 시트로 확인하라
const MARK_CLAIM := Color(0.5, 0.92, 0.45)  ## [?] 달성 — 문에서 [E]로 정산(보상)하라
func _refresh_gate_mark(_a: Variant = null) -> void:
	if GameState.has_claimable_quest():
		_gate_mark.text = "?"
		_gate_mark.add_theme_color_override(&"font_color", MARK_CLAIM)
		_gate_mark.visible = true
	elif GameState.has_new_quest():
		_gate_mark.text = "!"
		_gate_mark.add_theme_color_override(&"font_color", MARK_NEW)
		_gate_mark.visible = true
	else:
		_gate_mark.visible = false

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
	_forge = forge_scene.instantiate() as RingForgePanelScript
	if _forge == null:
		push_error("forge_scene이 RingForgePanel이 아니다")
		return
	_overlay.add_child(_forge)
	_forge.design_committed.connect(_on_ring_committed)
	_forge.commit_rejected.connect(_on_ring_rejected)
	_forge.closed.connect(_close_drawing)   # ESC(ui_cancel) → 패널이 closed 발신
	# 🔴 책의 [⚒ 부품 제작] → 공방. **책상 하나가 조립과 제작을 다 연다** — 마을에 공방 건물이 없어서
	#   이 버튼이 없으면 재료→부품 사슬이 통째로 도달 불가다.
	_forge.craft_requested.connect(_open_workshop_panel)
	_forge.open()

## 고리 마법진이 맺혔다 — RingDesign으로 감싸 GameState에 넘긴다(빈 슬롯에 자동 장착).
## 🔴 손그림 점수는 `assembly.score`를 타고 들어와 `total_score`가 된다 — 안 넘기면 저장된 도안의
## total_score가 전부 0이 된다.
func _on_ring_committed(assembly: Dictionary) -> void:
	var design := RingDesign.from_assembly(assembly, "고리 마법진")
	EventBus.ring_design_committed.emit(design)

## 🔴 책을 덮었는데 **점수 미달로 안 맺혔다.** 조용히 거부하면 슬롯이 빈 채 남아 "맺었는데 안 나간다"가
## 되고 화면 어디에도 이유가 없다.
func _on_ring_rejected(score: float) -> void:
	Audio.play(&"pop")
	_hud.say("마법진이 안 맺혔다 — 종합 %d점 (%d점을 넘겨야 견딘다). 책상에서 E로 다시 맺어라"
		% [RingPower.score_display(score), RingPower.score_display(RingPower.threshold())], true)

func _close_drawing() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_forge = null
	_player.set_physics_process(true)
	_player.caster.enabled = true
	GameState.ui_modal_open = false

# ─────────────────────────── 공방 패널 ───────────────────────────
#
# ⏳ 정제대·상점 패널과 레시피 데이터는 살아 있지만 **여는 [E]가 없다** — 되살릴 땐 아래 둘을
#   본으로 삼아라(형태가 같다). 건물로 세울 거면 절차 정본은 `STATION_UNLOCKS` 머리말 ①~④.

## 공방 = 재료 → 부품(진·고리·룬). 책 위에 **겹쳐** 띄운다 — 닫으면 조립하던 자리로 그대로 돌아온다.
## ⚠ **`ui_modal_open`을 여기서 false로 만들지 마라** — 책이 아직 열려 있는데 풀면 [I]·[Tab]이
##   책 위로 겹쳐 열린다. 그래서 `_close_workshop`은 플래그를 **다시 세운다**(공방의 `close()`가 내리므로).
func _open_workshop_panel() -> void:
	if _overlay == null or _workshop != null:
		return
	_workshop = WorkshopPanelScene.instantiate() as WorkshopPanelScript
	if _workshop == null:
		push_error("workshop_panel이 WorkshopPanel이 아니다")
		return
	_overlay.add_child(_workshop)   # 책과 같은 오버레이 = 책 위에 덮인다
	_workshop.closed.connect(_close_workshop)
	_workshop.open()


func _close_workshop() -> void:
	if _workshop != null:
		_workshop.queue_free()
		_workshop = null
	# 🔴 책이 아직 열려 있다 — 공방의 close()가 내린 모달 플래그를 되세운다(위 머리말).
	if _overlay != null:
		GameState.ui_modal_open = true
