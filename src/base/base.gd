extends Node2D
## 베이스(허브) — 익스트랙션 루프의 귀환 지점.
## 책상에서 E를 누르면 **고리 조립 책**(진·룬·문양)이 베이스 위에 뜬다.
## 씬 전환 없음 — ESC로 닫으면 베이스가 그대로 뒤에 남는다.
## 왼쪽 숲길에서 E를 누르면 **바로** 원정을 나간다 (세112 1d — 챕터 선택 화면이 폐기됐다. `_depart_to_chapter`).
## 🔴🔴 세95: 그 문이 **화자·정산까지 겸한다** — 길잡이 NPC가 은퇴했다(`_on_gate_talk` 머리말이 계약 정본).
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
##  • 🔴🔴 **첫 화면 = 문 앞 폐허** (세89 4단계 · 설계 `world_and_visual_design.md` §4).
##    스폰이 `(370, 850)` = 숲길 문 바로 앞이다 — *"문이 나를 소환했다"*가 곧 게임의 첫 장면이라
##    **문을 옮기지 않고 스폰을 문으로 데려왔다**(문 위치는 「서쪽 정문 = 숲으로 나가는 유일한 길」이라는
##    뜻을 지고 있다). 뷰포트 960×540 + 카메라 limit 클램프 → 첫 화면 = **(0,580)~(960,1120)**.
##    그 창 안에 드는 것: 문(빛남) · 공방 잔해 · 기념비(영구 잔해) · 실습동 잔해 · 연습장.
##    **서고·매점은 일부러 창 밖**이다(온전한 = 색을 가진 건물이 첫 화면에 있으면 안 된다).
##    🔴 스폰을 또 옮기려면 **허수아비 5개와 도로 밴드(`_build_campus`)를 같이** 옮겨라.
##  • 허수아비 5개는 전부 플레이어 시작점에서 **사거리 안**(≈390px = 260px/s × 1.5s, balance)에 있다.
##    더 멀리 두면 걸어가서 쏘기 전엔 안 닿아 연습장이 장식이 된다 (tests/test_base_auto가 못 박는다).
##    🔴 **이웃 간격은 90px 미만**으로 붙여 놨다 — 감전 연쇄 반경(`status_shock_chain_px`)이 90이라
##    더 벌리면 연습장에서 연쇄가 **한 번도 안 터진다**(세50에 102px로 실제로 그랬다).
##  • 🔴 스폰 **바로 위 390px**에는 layer-1(world) 몸이 하나도 없다 — 진이 총구에서 죽는지 재는
##    `_test_desk_does_not_eat_the_spell`이 그 자리로 쏜다. 잔해 프롭의 `Body`가 layer 1이라
##    스폰 북쪽에 두면 정확히 이 자리를 밟는다(그래서 잔해는 북동·남동으로 비껴 놨다).
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
## 세97 N15: 공방(재료 → 부품). 책상 [E] → 책 → [⚒ 부품 제작]으로 연다(건물이 아니다).
const WorkshopPanelScript := preload("res://src/base/workshop_panel.gd")
const WorkshopPanelScene := preload("res://src/base/workshop_panel.tscn")
## 🔴🔴 **세90: 정제대·공방·매점 패널 preload 셋을 걷었다** — 마을에서 그 건물 셋을 뺐으므로
##   여는 [E]가 없다(아래 `STATION_UNLOCKS` 머리말 = 되살리는 절차의 정본).
##   ⚠ **패널 스크립트·씬(`refine_panel`·`workshop_panel`·`shop_panel`)과 레시피 데이터는 살아 있다** —
##   지운 건 「마을에서 그걸 여는 길」뿐이다. 그래서 `test_workshop_auto`는 그대로 그린이다
##   (그 그물은 패널을 직접 열어 재고, 마을을 안 지난다).
const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 🔴 세95: `TabPanel` preload를 걷었다 — 문 [E]가 **더 이상 목표 시트를 안 연다**(`_on_gate_talk` 주석).
##   시트는 `tab_panel.gd`가 스스로 [Tab]·[I]·[Q]·[C]로 여닫으므로 `base.tscn`의 `Sheet` 인스턴스만으로 돈다.
##   ⚠ 그래서 `tab_panel.open_quest()`는 **부르는 곳이 0**이 됐다(공개 API로 남아 있다 — 리드 판단 몫).
## 온보딩 대사 상자 (세션41 → 세95에 화자가 문으로 옮겨졌다). 루트=CanvasLayer, 스크립트=$Box.
const DialogueBoxScene := preload("res://src/hud/dialogue_box.tscn")
## 🔴 스크립트 preload = 캐스트 타입 ($Box는 get_node로 Node라, open()/finished를 정적으로 부르려면 이걸로 캐스트).
const DialogueBox := preload("res://src/hud/dialogue_box.gd")
## 🔴 위력 표시는 여기서 계산하지 않는다 — 리포트·발사·HUD가 **같은 함수**를 본다 (core에 있는 이유).
const RingPower := preload("res://src/core/ring_power.gd")
## 🔴 세112 1d: 챕터 선택 패널 preload 둘을 걷었다 — `src/hud/chapter_panel`이 **삭제됐다**
##   (`room_loop_design.md` §5 걷어내기 표 · `genre_pivot` D9). 문 [E]는 고르게 하지 않고 바로 나간다.

# ─────────────────────── 마을 되살리기 (세89 — 망한 마법 마을) ───────────────────────
#
# 🔴 세계관(`docs/takbon-design/world_and_visual_design.md` §1~2): 마을은 무너져 **잔해**로 서 있고,
# 퀘스트를 깨면 **저절로** 온전해진다. 방아쇠는 `QuestDef.reward_unlock` — 정산 순간 codex가 나가고
# 아래 소비자가 그 건물의 겉모습·상호작용을 뒤집는다.
#
# 🔴🔴 **재료를 모아 그 자리에서 [E]로 사는 「결제」 단계는 세66에 사용자가 거부했다 — 되살리지 마라.**
#   세37 `_station_interact`(+ `balance.station_build_costs`)가 그것이었다. 그때 거부된 이유는
#   *"플레이어가 하는 일이 노동이 된다"*였고, 지금 모델은 **보상**이다(퀘스트를 깨면 선다).

## 🔴 게이트 표 — {씬 노드 이름: codex 해금 id}. 해금 전 = 잔해(잠김) · 해금 후 = 온전(열림).
##
## 🔴🔴 **세90: 표가 비었다 — 「마을 되살리기」는 데이터가 없어 잠들어 있다(은퇴가 아니다).**
##   사용자 확정으로 마을을 **「캐릭 + 마법문 + 마법 제작대(책상)」 셋**으로 줄이면서 게이트 대상이던
##   정제대(`Refine`)·공방(`Craft`)을 `base.tscn`에서 뺐다. 표는 **노드 이름으로 찾으므로 노드가
##   없으면 조용히 no-op**이라, 옛 두 줄을 남겨 두면 T3(소비자 없는 거짓 손잡이)가 된다 → 비웠다.
##
##   ✅ **기계는 전부 살아 있다** — `_on_station_unlocked` · `_refresh_stations` ·
##   `_apply_station_state`(monitoring 잠금 + 잔해/온전 전환) · `_refresh_village_tint`.
##   프롭 씬(`refine_station.tscn`·`craft_station.tscn`·`shop_station.tscn`)도 `Ruin` 자식과
##   잔해 PNG를 그대로 들고 있고, 패널·레시피 데이터도 안 지웠다.
##
## 🔴 **되살리는 절차 (정본 — 세 곳이 한 덩어리다)**:
##   ① `base.tscn`에 그 프롭 노드를 다시 꽂는다(ExtResource + node 한 블록).
##   ② 여기 표에 `{"노드이름": &"station_*"}` 한 줄.
##   ③ 그걸 여는 퀘스트의 `reward_unlock`에 같은 id 한 줄.
##   ④ `_ready`에 `interacted.connect(...)` 한 줄 + 그 패널을 여는 함수(git 이력에 있다: 세89 커밋).
##   🔴🔴 **②만 하고 ③을 빠뜨리면 그 건물은 영영 잔해**인데 **기존 세이브엔 옛 값이 남아 F5로는
##   안 드러난다**(새 게임에서만 죽는다) = 이 프로젝트가 제일 비싸게 배운 형태의 침묵.
##   그물 = `test_quests_auto`의 「열쇠와 문이 짝이 맞는다」가 **양방향으로** 잰다.
##
## ⚠ **`Dusk`(마을 색조)는 이제 씬 값에서 안 움직인다** — `_refresh_village_tint`가 빈 표에서
##   return하므로 `TINT_RUINED`(옅은 회보라)로 고정이다. 되돌릴 건물이 0채라 그게 맞는 상태다.
const STATION_UNLOCKS: Dictionary = {}

## 온전할 때만 보이는 자식 — 잔해 위에 상인(`Keeper`)이 서 있으면 안 된다(설계 §5 #4).
## 🔴 `LightPool` = 되살아난 건물 발밑의 빛 웅덩이(설계 §3 *"건물마다 발밑에 빛 웅덩이 하나"*).
##   **폐허엔 빛이 없다**는 규칙이 이 한 줄이다 — 첫 화면에서 빛나는 건 문뿐이어야 한다(설계 §4).
##   밝기·색은 씬이 쥐고 맥동은 `light_pool.gd`가 쥔다(그쪽 머리말) — 여기선 **보이나 마나**만 가른다.
const WHOLE_ONLY_PARTS: Array[String] = ["Sprite", "Keeper", "LightPool"]
## 잔해일 때만 보이는 자식. 세89 4단계에 `Refine`·`Craft` 프롭에 도착했다(`bld_*_ruin.png`).
## 🔴 **표(`STATION_UNLOCKS`)에 건물을 올리면 `Ruin` 자식을 반드시 같이 달아라** — 없으면 잔해
##   동안 `Sprite`만 꺼져 건물이 통째로 안 보인다. 그물 = `test_base_auto [10]`(잔해 자식 + 텍스처 로드).
## ⚠ 기념비(`Monument`)는 여기 안 든다 — **영구 잔해**라 전환 자체가 없다(스프라이트가 곧 잔해다.
##   `monument.tscn`이 `monument_circle_ruin.png`을 직접 문다 — 깨진 마법진이 마을이 망한 발단이라
##   되돌릴 열쇠가 애초에 없다, 설계 §1).
const RUIN_PART := "Ruin"

## 🔴 마을 색조 = 진행도 (설계 §3 — *"마법 = 빛. 빛은 있어야 할 곳(마을)에 없다"*).
## 되돌린 건물이 늘수록 `Dusk`(CanvasModulate)가 회보라 → 중립으로 간다. **셰이더 0 · 노드 0** —
## 손잡이는 이미 씬에 꽂혀 있었다(`Dusk.color`가 원래 `Color(0.9, 0.88, 0.96)`이었다).
## 🔴 **밝기는 유지한다**(성분 전부 0.86 이상) — 사용자 확정 *"어두운 폐허 각하"*(세73과 안 싸운다).
## ⚠ `CanvasModulate`는 곱하기뿐이라 **채도를 못 뺀다** — 「색을 빼는」 일은 잔해 아트가 한다(4단계).
## 연출값이라 balance가 아니라 const다 (`MARK_NEW`와 같은 결).
const TINT_RUINED := Color(0.90, 0.86, 1.00)   ## 아무것도 못 되돌린 폐허 — 옅은 회보라
const TINT_WHOLE := Color(1.0, 1.0, 1.0)       ## 마을이 돌아왔다 — 중립

## 책상에서 펴는 책 (base.tscn이 ring_forge_panel.tscn을 물려 준다).
## 🔴 여긴 PackedScene이어도 된다 — **책은 base를 안 문다**(순환이 아니다). 아래와 대비된다.
@export var forge_scene: PackedScene = preload("res://src/drawing/ring_forge_panel.tscn")
## 숲길 게이트가 여는 챕터 보스방 (세58-B — 옛 forest_scene_path 자리). 🔴 **PackedScene이 아니라
## 경로다. 바꾸지 마라.** base가 boss_room을 preload하고 boss_room이 base를 preload하면 **순환**이라,
## 먼저 로드되는 쪽의 상대가 **노드 0개짜리 껍데기**로 굳는다 → 귀환·사망해도 베이스로 못 돌아간다.
## 자세한 근거는 `boss_room.gd`의 `base_scene_path` 주석. **헤드리스는 이걸 못 잡는다.**
@export_file("*.tscn") var boss_room_scene_path: String = "res://src/field/boss_room.tscn"

@onready var _desk: InteractZone = $Desk
## 🔴🔴 **세95: 문 하나가 「나가는 길」과 「화자·정산」을 겸한다** (설계 `world_and_visual_design.md` §2 ·
##   사용자 확정). 길잡이 NPC(`Npc`)는 은퇴했다 — *「아무도 안 모았다 · 나는 뒤늦게 온 자」*인데 사람이
##   서 있으면 「왜 그동안 안 주웠나」가 생긴다. ⚠ **씬 파일·PNG는 안 지웠다**(`src/props/npc_guide.tscn`·
##   `assets/sprites/base/npc_guide.png`) — 「주민 복귀」를 쓸 날의 재료고, 로드만 안 되면 비용이 0이다.
##   🔴 옛 이름을 만나면 여기서 해소해라: `_npc`·`_on_npc_talk`·`_refresh_npc_mark` → **`_gate`·
##   `_on_gate_talk`·`_refresh_gate_mark`**(같은 코드가 문으로 옮겨온 것이다. 되살릴 게 아니다).
@onready var _gate: InteractZone = $ForestGate
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud
# 🔴 캠퍼스 바닥 (세66-4 마법학교 마을) — 잔디·돌포장 길을 코드로 깐다 (boss_room `_fill_tiles` 선례).
@onready var _ground: ColorRect = $Ground
@onready var _grass: TileMapLayer = $TileGrass
@onready var _road: TileMapLayer = $TileRoad
# 🔴 문 위 물음표 (세션40 길잡이 → 세95 문). 정산할 퀘스트가 있을 때만 보인다. 근접(Prompt)과 별개로 늘 뜬다.
#   ⚠ 노드는 `base.tscn`이 `ForestGate`의 자식으로 단다 — `forest_gate.tscn`(공용 프롭)에 넣으면
#   보스방·다른 무대에 정산도 없는 [?]가 따라간다.
@onready var _gate_mark: Label = $ForestGate/Mark

## 🔴 한 번에 하나의 모달만 — `_overlay` 슬롯이 비어 있어야 새 패널이 열린다.
## ⚠ 세90에 마을 상호작용이 책상 하나로 줄어 지금 이 슬롯을 쓰는 건 책(`_forge`)뿐이다 —
##   **슬롯 규약은 그대로 둔다**(정제대·공방을 되살리면 그날 다시 셋이 다툰다).
var _overlay: CanvasLayer = null
var _forge: RingForgePanelScript = null
## 세97 N15: 책 위에 겹쳐 뜨는 공방(재료 → 부품). null이면 안 열려 있다.
var _workshop: WorkshopPanelScript = null
## 🔴 온보딩 오프닝 대사 (세션41 → 세95: 화자가 길잡이에서 **문**으로 옮겨졌다). 이 마을 방문에 한 번만.
var _dialogue: CanvasLayer = null
var _gate_intro_shown := false

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
	# 🔴🔴 **세95: 문 [E] 하나에 두 일이 실린다** — 정산 대사(옛 길잡이) → 출발.
	#   `_depart_to_chapter`를 직접 잇지 마라(그러면 정산이 통째로 빠진다. 그 형태를
	#   `test_base_auto [12]`가 잡는다 — 연결 개수만 세는 [8]은 못 잡는다).
	_gate.interacted.connect(_on_gate_talk)
	# 🔴 세90: 정제대·공방·매점 연결 셋을 걷었다 (그 노드가 씬에 없다 — `STATION_UNLOCKS` 머리말).
	#   ⚠ 되살릴 땐 **연결은 늘 잇고** 여닫는 손잡이는 `monitoring`으로 해라 — 연결을 끊었다 이었다
	#   하면 세50의 「리페어런팅 시 콜백이 영구히 죽는」 함정을 심는다(`_apply_station_state` 주석).
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# 퀘스트 완료 알림 (세션36) — GameState가 판정, 씬은 HUD로 알린다(caster.notice와 같은 채널).
	EventBus.quest_completed.connect(_on_quest_completed)
	# 🔴 목표 달성 넛지 (세션40 턴인) — 숲에서 목표를 채우면 "돌아가 정산하라"를 HUD로 알린다.
	EventBus.quest_ready.connect(_on_quest_ready)
	# 🔴 문 위 물음표 (세션40 → 세95) — 정산할 퀘스트가 생기거나(달성·해금) 없어질 때(정산) 갱신.
	EventBus.quest_ready.connect(_refresh_gate_mark)
	EventBus.quest_completed.connect(_refresh_gate_mark)
	EventBus.codex_unlocked.connect(_refresh_gate_mark)
	# 🔴 시트로 새 목표를 읽으면(mark_quests_seen → quests_seen) [!]를 끈다 (세션43).
	EventBus.quests_seen.connect(_refresh_gate_mark)
	# 🔴 첫 마법진(q00, 세션41) — 맺으면 [?]가 켜지도록 조립 완료도 물음표를 갱신한다
	#   (조립은 마을에서 일어나므로 "돌아가 정산하라" 넛지 대신 문 위 [?]로 안내한다).
	EventBus.ring_design_committed.connect(_refresh_gate_mark)
	_refresh_gate_mark()
	# 🔴🔴 **세89: 마을 되살리기 — codex가 건물의 겉모습·상호작용을 가른다.**
	#   `_ready`(초기 상태 반영)와 `codex_unlocked`(전환) **둘 다** 필요하다: 수신만 있으면
	#   「이어하기」가 되살린 건물을 잔해로 띄우고, 초기화만 있으면 퀘스트를 정산해도 **그 방문 내내
	#   잠긴 채**다(마을을 나갔다 와야 열린다 = 에러 없는 침묵).
	# ⚠ **세90: 지금 `STATION_UNLOCKS`가 비어 둘 다 no-op이다** — 배선은 **일부러 남긴다.**
	#   표에 한 줄이 돌아오는 순간 되살리기가 그대로 살아나야 하고, 이 두 줄이 그 조건이다
	#   (걷어 두면 「표만 채웠는데 아무 일도 안 일어난다」를 다음 세션이 다시 디버깅한다).
	EventBus.codex_unlocked.connect(_on_station_unlocked)
	_refresh_stations()
	#
	# 🔴🔴 **세89: 세66-2 인터림 브리지를 걷었다** (설계 `world_and_visual_design.md` §2·§8).
	#   그 자리엔 매 방문 `station_refine`·`station_craft`·`station_shop` codex를 **심는 루프**가 있었다 —
	#   건설이 은퇴(세66)했는데 q03·q04가 그걸 `UNLOCK` 목표로 삼고 있어서, 안 심으면 온보딩 사슬이
	#   막혔기 때문이다. 즉 **퀘스트가 자기 완료 조건을 스스로 심는 순환**이었다.
	#   세89에 방향을 뒤집었다: **퀘스트를 깨면 건물이 저절로 선다**(`QuestDef.reward_unlock`).
	#   🔴 **되살리지 마라** — 브리지가 있으면 표에 건물을 올려도 codex가 이미 심겨 있어 **잔해 단계가
	#   조용히 통째로 건너뛰어진다**(그런데 새 게임에서만 드러난다).
	#
	# ⚠ **세90: q03·q04는 이제 건물을 되돌리지 않는다** — 정제대·공방이 마을에서 빠져
	#   `reward_unlock`을 비웠다(보상은 재료만). 사슬(KILL 5 → EXTRACT 2)과 재료 보상량은 무변경이고,
	#   q05→q04로 옮긴 `mat_night_bloom ×2`도 그대로다(`test_quests_auto`가 잰다).
	# 🔴 온보딩 (세션41 → 세95) — 첫 마법진을 아직 안 맺었으면 **문**으로 유도한다 (q00 완료되면 안 뜬다).
	#   🔴 세95: 옛 문구는 *"길잡이에게 [E]로 말을 걸어라 — … 마법진을 **그리는** 것"*이었다. 두 곳이
	#   거짓이었다: ⓐ 가리키는 사람이 은퇴했고 ⓑ 「그린다」는 세83 폐지어다(지금은 조립해서 **맺는다**).
	if not GameState.is_quest_done(&"q00_first_draw"):
		# 🔴 세84 #36: `sticky` — 온보딩 **목표**다(경고가 아니다). 수명이 붙은 뒤엔 안 붙이면
		# 첫 안내가 4.5초 뒤 사라져 새 플레이어가 어디로 갈지 모른다.
		_hud.say("문이 너를 불렀다 — 문 앞에서 [E]", false, true)

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
	# 돌포장 길·안뜰 (세89 4단계 캠퍼스 재구축 — 설계 §4 「첫 화면」)
	#
	# 🔴🔴 **여기와 `base.tscn` 배치는 한 몸이다.** 밴드만 옮기면 길이 건물과 어긋나고, 씬만 옮기면
	#   건물이 잔디 위에 뜬다 — 설계 §6이 「바뀌는 것 여섯」에 ②(씬)와 ④(이 배열)를 따로 센 이유다.
	#
	# 🔴🔴 **세90: 마을을 셋으로 줄여 길도 두 줄로 줄였다.** 옛 배열은 7줄로 캠퍼스를 가로질러
	#   **동쪽 안뜰·매점 분기·서고 분기**까지 깔았는데, 그 건물들이 씬에서 빠지자 **길만 잔디 위로
	#   1.7km 뻗어 아무 데도 안 닿는** 상태가 됐다(에러 0 = 감사 T5의 그 자리, 세89에 무늬 자국이
	#   같은 병으로 잔디 한복판에 떴다). 남은 둘은 실제로 **가는 곳이 있는** 길이다.
	# 🔴 **한 장으로 깐다.** 두 사각형으로 마당+진입로를 만들어 봤더니 겹치는 자리에서 **직각 계단이
	#   크게 튀었다**(실측 스샷) — 밴드가 7개였던 세89엔 각 조각이 작아 「길」로 읽혔지만, 마을이 셋으로
	#   줄어 조각도 커지자 그 모양이 「길」이 아니라 「잘못 깐 바닥」이 됐다. 지금 마을 = **문 앞 광장 하나**다.
	# ⚠ 범위는 **남은 넷을 다 덮도록** 잡았다: 문(200,820)·기념비(620,920)·책상(860,840)·
	#   허수아비(395~470, 968~1132). 하나를 옮기면 여기도 같이 본다(위 「한 몸」 주석).
	# 🔴 세95에 길잡이(560,700)가 은퇴했지만 **범위는 안 줄였다** — 그 자리는 문과 기념비 사이라
	#   깎으면 광장 한복판에 잔디 구멍이 뚫린다(위 「한 장으로 깐다」 = 조각을 나누면 계단이 튄다).
	#   즉 광장의 모양은 「누가 서 있나」가 아니라 **바닥이 한 덩어리인가**가 정한다.
	var bands: Array[Rect2] = [
		Rect2(200, 660, 760, 440),     # 문 앞 폐허 광장 — 이게 지금 마을의 전부다
	]
	for band in bands:
		_fill_road(band, Vector2i(0, 1))
	# 마법진 무늬 자국 = 기념비(깨진 마법진) 발밑 — 마을이 망한 발단이 여기 남아 있다(설계 §1).
	# 🔴 좌표를 **베끼지 않고 기념비 노드에서 파생**한다. 옛 코드는 `(1200, 780)`을 손으로 적어 뒀는데,
	#   캠퍼스를 옮기면 무늬만 옛 자리에 남아 **잔디 한복판에 뜬다**(에러 0 = 감사 T5 「파생 대신 복제」).
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


# ─────────────────── 마을 되살리기 소비자 (세89 — 위 STATION_UNLOCKS 참조) ───────────────────

## 해금이 하나 들어왔다 — 마을 건물 id일 때만 되돌린다(룬·진·고리·챕터 클리어는 조용히 지나간다).
func _on_station_unlocked(unlock_id: StringName) -> void:
	if not STATION_UNLOCKS.values().has(unlock_id):
		return
	_refresh_stations()


## 🔴 표의 건물마다 codex 상태를 겉모습·상호작용에 반영한다.
## `_ready`(초기 상태)와 `_on_station_unlocked`(전환)가 **같은 함수**를 부른다 — 두 경로가 갈라지면
## 「새로 들어오면 잔해인데 그 자리서 깨면 온전」 같은 모순이 조용히 생긴다(core에 `ring_power`를
## 한 벌만 둔 것과 같은 이유).
##
## ✅ **세89 4단계: 겉보기 전환이 실제로 돈다** — `Refine`·`Craft` 프롭에 `Ruin` 자식이 도착했다.
##   (그전엔 `Ruin`이 없어 `_apply_station_state`가 겉모습을 건너뛰고 게이트·색조만 돌았다.)
func _refresh_stations() -> void:
	for node_name: String in STATION_UNLOCKS:
		var zone := get_node_or_null(node_name) as InteractZone
		if zone == null:
			continue   # 4단계가 노드를 옮기거나 이름을 바꿔도 여기서 죽지 않는다
		_apply_station_state(zone, GameState.is_unlocked(STATION_UNLOCKS[node_name]))
	_refresh_village_tint()


## 건물 하나의 상태 — `built=false`면 잔해다: [E] 안내가 안 뜨고 눌러도 아무 일이 없다.
##
## 🔴 게이트를 **`monitoring`으로** 건다(시그널 연결을 끊었다 잇는 게 아니라). 이유 둘:
##   ① `interact_zone`이 플레이어를 아예 못 보게 되므로 **안내(Prompt)와 E 입력이 한 손잡이로**
##      같이 닫힌다 — 두 군데를 따로 끄면 한쪽만 되돌려도 안 드러난다.
##   ② 연결을 끊었다 잇는 수법은 세50이 심었다 뽑은 함정 그대로다(*"리페어런팅 시 콜백이 영구히 죽는다"*).
## ⚠ **몸(`Body` StaticBody2D)은 안 건드린다** — 잔해도 단단하다(지나갈 수 없다). 그리고 그 몸이
##   `collision_layer = 1`(world)이라 건드리면 `test_base_auto`의 「진이 총구에서 안 죽는다」에 닿는다.
## ⚠ `set_deferred` — Area2D의 `monitoring`은 물리 질의 flush 중에 바꾸면 엔진이 막고 **조용히 무시**한다.
func _apply_station_state(zone: InteractZone, built: bool) -> void:
	zone.set_deferred(&"monitoring", built)
	var prompt := zone.get_node_or_null(^"Prompt") as CanvasItem
	if prompt != null and not built:
		# 잠그는 순간 안내가 떠 있었으면 내린다 — monitoring을 끄면 body_exited가 안 온다.
		prompt.visible = false
	# 🔴 잔해/온전을 **따로** 가른다 — 짝으로 묶어 `Ruin`이 없으면 통째로 return하던 옛 형태는
	#   4단계에 잔해가 도착해 쓸모가 없어졌고, 그 return이 남아 있으면 `LightPool`(빛 웅덩이)이
	#   `Ruin` 없는 프롭에서 **조용히 안 꺼진다**(폐허가 빛나는데 에러가 0이다).
	var ruin := zone.get_node_or_null(RUIN_PART) as CanvasItem
	if ruin != null:
		ruin.visible = not built
	for part_name: String in WHOLE_ONLY_PARTS:
		var part := zone.get_node_or_null(part_name) as CanvasItem
		if part != null:
			part.visible = built


## 🔴 마을 색조 = 되돌린 건물 비율 (설계 §3). 표(`STATION_UNLOCKS`)에서 **파생**한다 —
## 분모를 손으로 적으면 건물을 하나 늘릴 때 색조만 조용히 옛 비율로 남는다.
func _refresh_village_tint() -> void:
	var dusk := get_node_or_null(^"Dusk") as CanvasModulate
	if dusk == null or STATION_UNLOCKS.is_empty():
		return
	var built := 0
	for node_name: String in STATION_UNLOCKS:
		if GameState.is_unlocked(STATION_UNLOCKS[node_name]):
			built += 1
	dusk.color = TINT_RUINED.lerp(TINT_WHOLE, float(built) / float(STATION_UNLOCKS.size()))


# ─────────────────────────── 원정 (챕터 보스방, 세58-B) ───────────────────────────

## 🔴 출격이 **HP를 되돌리지 않는다** — 그건 보스방이 한다 (boss_room.gd `_ready`).
## 여기서 하면 "베이스에서 나갈 때만" 만HP고, 다른 진입 경로로 들어가면 조용히 다르다.
## 🔴🔴 숲길 [E] = **바로 출발** (세112 1d · `room_loop_design.md` §5 · `genre_pivot` D9).
##   챕터 선택 모달이 폐기돼 「고르는 화면」이 없다 — 문은 첫 챕터로 곧장 내보낸다.
##
## 🔴 챕터 id를 하드코딩하지 않는다 — `Db.chapters_sorted()`의 맨 앞(order 최솟값)이 정본이다.
##   상수로 베끼면 「새 챕터 = .tres 한 장」(takbon-rules §4)이 깨지고, 1장을 개명하면 조용히 빈
##   `pending_chapter`로 나간다.
## 🔴🔴 `pending_chapter`를 **반드시 채운다** — `change_scene_to_file`은 인자를 못 실어 이 오토로드가
##   나르고, 비면 `boss_room._ready`가 설계대로 마을로 되돌린다(= 「나갔는데 도로 마을」, 에러 0).
##   그래서 챕터가 0장이면 **전환 자체를 안 한다** — 그 왕복은 플레이어에게 무반응으로만 보인다.
##
## 🔴 세95: 부르는 곳이 셋이다 — `_on_gate_talk`의 ⓑ 순수 원정 갈래 · ⓑ 대사 실패 갈래 ·
##   정산 대사의 `finished` 체이닝(`_start_turnin_dialogue`의 `on_finished`). 게이트 시그널에
##   **직접 잇지 마라**(그러면 정산이 통째로 빠진다).
## ⚠ 설계 §2 ⓒ — 아래 모달 가드는 **로그 없이 return**한다. 도달 조건과 그때의 행선지:
##   `_overlay`(책이 열림)·`_dialogue`(대사 중) → 애초에 `ui_modal_open`이라 문 [E]가 안 오고,
##   대사는 끝나면 체이닝이 다시 부른다. 즉 **어느 갈래도 「눌렀는데 아무 일도 안 난다」로 끝나지
##   않는다**(그게 이 return이 조용해도 되는 근거다). 챕터 0장 갈래만 안내가 필요해 HUD로 말한다.
func _depart_to_chapter() -> void:
	if _overlay != null or _dialogue != null:   # 모달 중엔 안 나간다 (플래그를 켠 채 씬이 바뀐다)
		return
	var chapters := Db.chapters_sorted()
	if chapters.is_empty():
		_hud.say("나갈 곳이 없다 — 챕터를 못 읽었다 (data/chapters/*.tres)", true)
		return
	GameState.pending_chapter = chapters[0].id
	get_tree().change_scene_to_file(boss_room_scene_path)

## 🔴🔴 **문 [E] = 정산 + 원정** (세95 · 설계 `world_and_visual_design.md` §2. 옛 이름 `_on_npc_talk`).
##  ⓐ 정산할 목표가 있으면 문이 먼저 말을 걸고(대사) → **끝나면 그대로** 출발로 이어진다.
##  ⓑ 정산할 게 없으면 **대사 없이 바로** 출발이다 — 안 그러면 *"나가려는데 자꾸 대사가 뜬다"*가 된다.
##
## 🔴🔴 **[E] 하나에 두 일을 태울 때 조용히 깨지는 자리 셋** (설계 §2 표 — 전부 실측된 것이다):
##  ⓐ `interact_zone`은 `GameState.ui_modal_open`이면 E를 **통째로 안 받고**, `dialogue_box.open()`이
##     그 플래그를 켠다 → 대사 중엔 문의 E가 죽는다. 그래서 출발을 **`finished`에 명시로 체이닝**한다
##     (`_start_turnin_dialogue`의 `on_finished`). 안 하면 플레이어가 **E를 두 번** 눌러야 나간다.
##  ⓑ 🔴🔴 대사가 **한 줄도 안 나올 수 있다** — `Db.get_quest`가 전부 null이면(`.tres` 침묵사, 세50 ⓑ)
##     `_start_turnin_dialogue`가 `false`를 돌려주고 `finished`는 **영영 안 온다**. 그래서 출발을
##     `finished`에만 걸지 않고 **여기서 `false`를 받아 즉시 나간다** — 안 그러면 마을 밖으로 못 나가는 소프트락이다.
##  ⓒ `_show_dialogue`·`_depart_to_chapter`의 가드는 **로그 없이 return**한다. 한 [E]에 묶이면 그 return이
##     곧 「눌렀는데 아무 일도 안 난다」다 → 아래에서 각 갈래의 **행선지를 하나도 안 비워 둔다**.
##  ⚠ **옛 ⓓ(E 이중 소비)는 대상이 사라졌다** — 세112 1d에 챕터 선택 패널이 삭제돼, 대사 마지막 줄의
##     E가 「방금 뜬 패널을 즉시 닫는」 자리가 없다. 그 E는 이제 곧바로 씬 전환으로 이어진다.
func _on_gate_talk() -> void:
	# 🔴 온보딩 (세션41 → 세95): 아직 첫 마법진을 안 맺었으면(ring_designs 빔) 문이 먼저 이야기하고
	#   **책상으로 보낸다** — 여기선 챕터 선택을 열지 않는다(설계 §5: 문 → "책상으로 가라" → q00).
	#   ⚠ 문을 잠그는 게 아니다: `_gate_intro_shown`으로 이 방문에 한 번만 뜨고, 다음 [E]부턴 정상 흐름이다.
	if _dialogue == null and _overlay == null and not _gate_intro_shown \
			and not GameState.is_quest_done(&"q00_first_draw") and GameState.ring_designs.is_empty():
		_start_gate_intro()
		GameState.mark_quests_seen()   # 🔴 첫 목표 접수 (세션43) — [!]를 끈다. 오프닝 대사가 곧 설명한다
		_refresh_gate_mark()
		return
	# 🔴 정산(턴인). 달성한 목표를 정산하고 보상을 준다(_on_quest_completed가 HUD 완료 팝).
	#  🔴 정산으로 새 목표가 열려도 시트를 **강제로 열지 않는다** — [!]로 남겨 "[Tab]으로 확인"을 당긴다
	#  (그래야 [!]가 중간 게임에서도 산다, 세션43). ⚠ 세95에 「정산할 게 없으면 시트를 연다」를 **걷었다**:
	#  문은 나가는 자리라, 나가려고 누른 [E]가 목표 시트를 여는 건 손에 안 맞는다(시트는 [Tab]·[Q]가 연다).
	var claimed := GameState.claim_ready_quests()
	_refresh_gate_mark()
	if claimed.is_empty():
		_depart_to_chapter()   # ⓑ 순수 원정 — 대사 없이 바로
		return
	# 🔴 정산 대사 (세션44) — 조용히 보상만 주지 않고 문이 한마디 하고 다음을 가리킨다.
	#   ⓑ 대사를 못 띄웠으면(줄이 비었거나 다른 모달) **여기서 바로** 출발한다.
	if not _start_turnin_dialogue(claimed):
		_depart_to_chapter()

## 🔴 문의 오프닝 대사 (세션41 그리기 튜토 → 세95 전면 재작성 · 설계 §1·§5).
##  옛 판은 *"마법은 외우는 게 아니라 **그리는** 것이라네"* + *"밑그림을 손으로 따라 긋게"*였는데
##  🔴 **손 긋기는 세83에 폐지돼 지금 게임에 없는 조작**이다(스위치는 남아 있지만 기본이 꺼짐).
##  지금 가르치는 것 = ⓐ 왜 여기 있나(세계관) ⓑ 마법은 **조립해서 맺는다** ⓒ 책상 [E] ⓓ [Tab].
##  ⚠ 책 안의 단계별 안내는 `ring_forge_panel._say`가 하므로 여기선 **책을 펴기 전의 것만** 심는다.
##  ⚠ 화자는 문이다 — 설계 §7 *"짧고 건조하게"*.
const GATE_INTRO_LINES := [
	"…왔군. 늦었다.",
	"오래전 이 땅의 큰 마법진이 깨졌다. 문양이 전부 저 너머로 흩어졌다.",
	"나는 그때 남은 마지막 마법이고, 조각들이 빠져나간 길이다. 그래서 너를 불렀다.",
	"너는 이 세계의 마법을 배운 적이 없다. 외울 것도 없다 — 주워 온 조각을 이어 붙이면 된다.",
	"저 책상으로 가라. [E]로 책을 펴고 진·룬·문양을 골라 마법진 하나를 맺어라.",
	"할 일은 [Tab]으로 볼 수 있다. 가라.",
]

## 🔴 정산 대사의 **머리말** — 그 퀘스트를 처음 정산하는 순간에만 한 줄 앞에 붙는다 (설계 §5).
##  q00은 온보딩의 매듭이라 *"「첫 마법진」— 됐다"* 같은 일반 문구로는 세계관이 안 닫힌다.
##  ⚠ 여기 없는 퀘스트는 일반 문구만 나간다 — **표를 안 채워도 안 깨진다**(거짓 손잡이가 아니다).
##  ⚠ 퀘스트별 전용 대사를 `QuestDef`에 넣지 않은 이유 = 스키마 불변(세44 정산 대사와 같은 규율).
const TURNIN_PROLOGUE := {
	&"q00_first_draw": "네가 방금 맺은 그것이, 깨진 마법진의 조각 하나다. 나머지는 전부 저 너머로 흩어졌다.",
}

## 대사 상자를 띄워 세계관·첫 목표를 심는다. 끝나면(또는 ESC 건너뛰면) 상자만 치운다 —
##  🔴 여기선 챕터 선택으로 **안 이어진다**(아직 나갈 때가 아니다. 설계 §5: 먼저 책상).
func _start_gate_intro() -> void:
	_gate_intro_shown = true
	_show_dialogue(GATE_INTRO_LINES)

## 🔴 공용 대사 헬퍼 (세션41 오프닝·세션44 정산이 함께 쓴다) — dialogue_box를 띄우고 끝나면 정리한다.
##  dialogue_box가 스스로 모달·일시정지를 잡으므로(ui_modal_open) 여기선 인스턴스·해제만 한다.
##  🔴 이미 대사·다른 모달이 떠 있으면 안 띄운다(모달 하나만 — 책과 같은 규약) → **false를 돌려준다.**
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

## 🔴 정산(턴인) 대사 (세션44, 사용자: "퀘스트 완료할 때도 대화가 있어야") — 정산한 목표를 짚고
##  보상을 밝히고 다음을 가리킨다. 대사는 QuestDef.title·reward_items에서 조립한다
##  (퀘스트별 전용 대사 필드 없이 = 스키마 불변). 여러 목표를 한 번에 정산하면 각각 한 줄.
##
## 🔴🔴 **반환값이 계약이다** (설계 §2 ⓑ): 대사를 실제로 띄웠으면 true. false면 `finished`가
##  **영영 안 오므로** 호출부가 그 자리에서 출발시켜야 한다(안 그러면 마을 밖으로 못 나간다).
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
	# 🔴 정산으로 새 목표가 열렸으면 [Tab]으로 유도(시트를 강제로 열지 않는다 = [!] 유지, 세션43).
	if GameState.has_new_quest():
		lines.append("다음이 열렸다 — [Tab]으로 확인해라. 문을 연다.")
	else:
		lines.append("문을 연다.")
	# 🔴 마지막 줄("문을 연다")과 **같은 손잡이**로 출발한다 — 설계 §2 ⓐ의 체이닝이다.
	return _show_dialogue(lines, _depart_to_chapter)

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

## 🔴 목표 달성 넛지 (세션40 → 세95) — 아직 완료 아님. 문에서 정산하라고 HUD로 민다.
##  ⚠ 여긴 마을이라 "돌아가"가 아니다 — 그 문구는 원정 중에 뜨는 `boss_room._on_quest_ready`가 쥔다.
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 문에서 [E]로 정산하라 [?]" % q.title)

## 🔴 문 위 마크 갱신 (세션40 [?] + 세션43 [!] · 세95에 길잡이 머리에서 문 위로 옮겼다).
##  시그널·초기화 양쪽에서 부른다. 우선순위: 정산 대기(claimable)면 [?](보상 받으러) ·
##  아니면 안 읽은 새 목표면 [!]([Tab]으로 확인) · 둘 다 없으면 숨김.
##  색으로도 구분 — [!] 노랑(새 목표 있음) · [?] 초록(가서 정산=보상). 연출값이라 const.
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
	_forge = forge_scene.instantiate() as RingForgePanelScript   # 진→룬→문양, 손으로 따라 그어 확정
	if _forge == null:
		push_error("forge_scene이 RingForgePanel이 아니다")
		return
	_overlay.add_child(_forge)
	_forge.design_committed.connect(_on_ring_committed)
	_forge.commit_rejected.connect(_on_ring_rejected)
	_forge.closed.connect(_close_drawing)   # ESC(ui_cancel) → 패널이 closed 발신
	# 🔴 세97 N15: 책의 [⚒ 부품 제작] → 공방. **책상 하나가 조립과 제작을 다 연다**(사용자 확정).
	#   세90에 마을이 셋으로 줄며 공방 [E]가 사라져 **재료→부품 사슬이 통째로 도달 불가**였다
	#   (`rune_bolt`·`rune_earth`·`jin_plain_g2`·`jin_fuse`·`gr_condense2` 다섯이 못 열렸다).
	#   건물을 다시 세우지 않은 이유 = 세90 「마을은 셋」과 세95 세계관(*"문과 서고만 남았다"*)을
	#   안 건드리려는 것이다 — 책상은 이미 「마법 제작대」라 이름도 맞는다.
	_forge.craft_requested.connect(_open_workshop_panel)
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

# ──────── 정제대·공방·상점 패널 열기 (세29·32·66 → 세90에 걷었고 → 🔴 세97에 공방만 되살렸다) ────────
#
# 🔴 세90에 여섯 함수를 지웠다 — 세 건물이 `base.tscn`에서 빠져 **부르는 곳이 0**이 됐다.
#   ✅ **세97: 공방만 돌아왔다.** 단 **건물이 아니라 책(`ring_forge_panel`)의 버튼**이 연다
#   (`_open_drawing`의 `craft_requested` 연결 — 세90 「마을은 셋」을 안 건드리는 길이었다).
#   ⏳ **정제대·상점은 아직 문이 없다** — 되살릴 땐 아래 둘을 본으로 삼아라(형태가 같다).
#   git 이력(세89 커밋)에 원형이 그대로 있고, 건물로 세울 거면 절차 정본은 `STATION_UNLOCKS` 머리말 ①~④.

## 🔴 공방 = 재료 → 부품(진·고리·룬). 책 위에 **겹쳐** 띄운다 — 닫으면 조립하던 자리로 그대로 돌아온다.
## ⚠ **`ui_modal_open`을 여기서 false로 만들지 마라** — 책이 아직 열려 있는데 풀면 [I]·[Tab]이
##   책 위로 겹쳐 열린다(세28 「닫힌 invisible Control도 입력을 받는다」의 사촌).
##   그래서 `_close_workshop`은 플래그를 **다시 세운다**(공방 패널의 `close()`가 내려 버리므로).
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
