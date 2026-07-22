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
## 길잡이 NPC가 여는 통합 시트 패널 (세션40, 옛 quest_panel 흡수) — 퀘스트 탭으로 연다(class_name 없음).
const TabPanel := preload("res://src/hud/tab_panel.gd")
## 온보딩 그리기 튜토 대사 상자 (세션41) — 첫 마법 전 NPC가 개념을 가르친다. 루트=CanvasLayer, 스크립트=$Box.
const DialogueBoxScene := preload("res://src/hud/dialogue_box.tscn")
## 🔴 스크립트 preload = 캐스트 타입 ($Box는 get_node로 Node라, open()/finished를 정적으로 부르려면 이걸로 캐스트).
const DialogueBox := preload("res://src/hud/dialogue_box.gd")
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
# 🔴 tab_panel.tscn 루트는 CanvasLayer(layer 5)고, 스크립트(Control)는 그 자식 Panel이다.
@onready var _sheet: TabPanel = $Sheet/Panel
# 🔴 길잡이 머리 위 물음표 (세션40) — 정산할 퀘스트가 있을 때만 보인다. 근접(Prompt)과 별개로 늘 뜬다.
@onready var _npc_mark: Label = $Npc/Mark

## 🔴 한 번에 하나의 모달만 — 책·정제대·공방이 같은 `_overlay` 슬롯을 쓴다. 하나 열려 있으면 다른 건 안 열린다.
var _overlay: CanvasLayer = null
var _forge: RingForgePanelScript = null
var _refine: Control = null
var _workshop: Control = null
var _decode: Control = null
## 🔴 온보딩 그리기 튜토 대사 (세션41) — 첫 마법 전 NPC가 개념을 가르친다. 이 베이스 방문에 한 번만.
var _dialogue: CanvasLayer = null
var _draw_tut_shown := false

func _ready() -> void:
	# 🔴 씬 진입 시 모달 플래그를 내린다 — ui_modal_open은 오토로드라 씬 전환에도 살아남는다.
	# 어떤 경로로든 모달이 켜진 채 씬이 바뀌면 새 패널은 _open=false인데 플래그만 true라 잠긴다.
	GameState.ui_modal_open = false
	# 베이스=집 — 원정 플래그를 내린다 (귀환·사망이 다 여기로 온다).
	GameState.in_expedition = false
	_desk.interacted.connect(_open_drawing)
	_gate.interacted.connect(_to_forest)
	# 🔴 건설형 스테이션 (세션37) — 안 지어졌으면 E=건설 시도, 지어졌으면 E=패널. _station_interact가 가른다.
	_refine_zone.interacted.connect(func() -> void:
		_station_interact(&"station_refine", "정제대", _refine_zone, _open_refine_panel))
	_craft_zone.interacted.connect(func() -> void:
		_station_interact(&"station_craft", "공방", _craft_zone, _open_workshop_panel))
	_decode_zone.interacted.connect(func() -> void:
		_station_interact(&"station_decode", "탁본 해독대", _decode_zone, _open_decode_panel))
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
	# 🔴 스테이션 건설 상태를 화면에 반영 (안 지어진 것은 어둡게 + "건설" 안내). 저장된 상태 기준.
	_refresh_stations()
	# 🔴 온보딩 (세션41) — 첫 마법을 아직 안 그렸으면 길잡이로 유도한다 (q00 완료되면 안 뜬다).
	if not GameState.is_quest_done(&"q00_first_draw"):
		_hud.say("길잡이에게 [E]로 말을 걸어라 — 첫 목표는 책상에서 마법진을 그리는 것이다")

# ─────────────────────────── 원정 ───────────────────────────

## 🔴 출격이 **HP를 되돌리지 않는다** — 그건 숲이 한다 (forest.gd `_ready`).
## 여기서 하면 "베이스에서 나갈 때만" 만HP고, 시험대·다른 진입 경로로 숲에 들어가면 조용히 다르다.
func _to_forest() -> void:
	if _overlay != null:   # 책을 펴 놓고 E를 눌러 나가면 책이 열린 채 씬이 바뀐다
		return
	get_tree().change_scene_to_file(forest_scene_path)

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
