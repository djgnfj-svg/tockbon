extends Node2D
## 챕터 던전 — **한 씬 안에서 방을 이어서 깬다**(입장 → 적 전멸 → 상자·문 → 다음 방 … → 마지막 방의 귀환 문).
## 어느 챕터인가는 `GameState.pending_chapter`가 나른다(`change_scene_to_file`이 인자를 못 싣는다).
## 죽으면 즉시 베이스 + 가방 손실(bag_lost).
##
## 🔴 **한 씬 + `ChapterDef` 파라미터다** — 챕터마다 씬을 새로 만들면 아래 함정을 그 수만큼 다시 밟는다.
##  전용 무대가 필요하면 `ChapterDef.room_scene_path` + **상속 씬**으로 노드 계약을 물려받아라.
##
## 🔴 **나가는 길을 새로 세우거든 반드시 `_wire_exit()`을 지나게 해라** — 연결을 빠뜨리면 E는 먹히고
##  안내도 뜨는데 **가방이 조용히 증발한다**(에러 0).
## 🔴 **남쪽 `$Exit`는 화면에 아무 표시가 없다** — 안내이던 흙길 줄기가 걷혔고 문 그림이 아직 없다.
##  헤드리스는 이걸 못 잡는다. 🔴 옛 귀환 포탈(`&"portal"`)을 되살리지 마라 — 씬·코드·그물을 다 없앴다.
##
## **무대는 고정, 서 있는 것은 매 판 굴러간다** — 몹·네임드·지점의 **자리는 절대 안 굴린다**(자리는
##  지형이 정하는 것이라 데이터가 든다). 굴리는 건 「거기 뭐가 서 있나」뿐이다.
## 🔴 **잡몹·네임드는 `_spawn_enemy_at` 한 문을 지난다**(보스 id 제외 가드가 거기 한 줄이다).
##  새 스폰 경로가 그 문을 안 지나면 **잡몹 한 마리로 챕터 클리어 + 보상 룬이 조용히 나간다.**
## 🔴 **지점을 세우면 입구에서 거기까지 흙길이 깔린다** — 방이 열린 숲이라 길이 없으면 「저쪽에 뭔가
##  있다」를 알 방법이 아예 없고, **에러 0으로 아무도 안 가는 물건**이 된다.
##
## 🔴 **출격 = 만HP/만마나는 이 씬의 `_ready`가 한다**(베이스가 아니다 — 다른 진입 경로에서 조용히 달라진다).
##  HP 자체는 GameState가 쥔다(오토로드라 씬을 갈아타도 남는다).
##
## 씬(boss_room.tscn) 쪽 결정 — .tscn엔 주석을 못 달아서 여기 적는다:
##  • 🔴🔴 **`Ground.mouse_filter = 2`(IGNORE) — 지우면 발사가 통째로 죽는다.** 화면을 덮는 ColorRect가
##    좌클릭을 다 먹어 `_unhandled_input`에 안 온다. **에러·경고 0이고 헤드리스로는 절대 못 잡는다.**
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(z=0) 뒤에 가려 안 보인다.
##  • 🔴 나무는 **물리 몸이 없는 장식**이다 — StaticBody2D로 만들면 world 레이어라 캐리어(마스크 5)가
##    나무마다 터진다. 붙어 있는 감지용 `Area2D`가 `collision_layer = 0`인 것도 같은 이유다.
##    ⚠ 나무는 **적을 가린다**(y-sort가 없다) — 그래서 프롭 배치가 스폰·문·지점 둘레를 비운다(`_prop_spot_ok`).
##  • 🔴 **방 크기의 소유자는 씬의 `Ground` rect 하나다** — 타일·카메라·프롭이 전부 거기서 파생한다.
##    ⚠ **씬·데이터가 손으로 든 좌표는 rect를 안 따라간다**(`Player`·`Exit`·`Lights/*` ·
##    `data/chapters/*.tres`의 스폰 좌표) — 방을 옮기면 그것들을 같이 옮겨라.
##  • 🔴 **방은 낮이다** — 횃불(additive 웅덩이)은 밝은 바닥 위에서 빛이 아니라 희뿌연 얼룩으로 읽힌다.
##    되살리려거든 **밤 챕터를 만들 때** 해라. 바닥 시트도 이미 낮 밝기라 밝기 곱을 또 물리면
##    **에러 0으로 화면만 형광색이 된다**(`_apply_chapter_tint`가 옅은 틴트만 얹는 이유).
##
## 🔴 바닥 타일은 코드가 깐다 — .tscn에 tile_map_data를 굳히면 방 크기를 바꿀 때마다 에디터로 다시 칠해야 한다.

const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 범용 보스 스폰 몸 — ChapterDef.boss_scene_path가 비면 이 씬 + enemy_id로 스폰한다.
const EnemyScene := preload("res://src/field/forest_enemy.tscn")
## 🔴 codex 해금 id → 「이름(어디에 쓰는지)」 단일 소스. 여기서 `Db.get_glyph_ring`을 부르면
##  **룬 보상이 원시 id + 거짓 안내**로 나간다(밴드는 고리 자리고 룬은 중심 자리다).
const CodexText := preload("res://src/core/codex_text.gd")
## 🔴 드롭 굴림·낱개 스폰의 **단일 소스** — 적과 지점이 **같은 함수**를 부른다.
##  ⚠ **여기 굴림 로직을 적지 마라**(적으면 `DropEntry`의 배타 짝 규칙이 두 벌이 되어 조용히 갈라진다).
const DropRoll := preload("res://src/field/drop_roll.gd")
## 🔴 **지급의 단일 소스** — 상자는 낱개 픽업을 안 뿌려 픽업 노드를 안 지나므로, 「해금물이면 codex,
##  아이템이면 가방」 분기를 여기 다시 적으면 **상자에서 나온 두루마리만 해금이 안 걸리고 에러가 0이다.**
const DropPickup := preload("res://src/props/drop_pickup.gd")

## 돌아갈 곳 — 🔴 **PackedScene이 아니라 경로다. 바꾸지 마라.** base가 boss_room을 경로로 물고
## boss_room이 base를 PackedScene으로 물면 **순환 preload**로 한쪽이 노드 0개 껍데기가 돼
## 귀환·사망 시 베이스로 못 돌아간다(헤드리스는 못 잡고 실게임 부팅에서만 드러난다).
@export_file("*.tscn") var base_scene_path: String = "res://src/base/base.tscn"

## 쓰러진 뒤 베이스로 돌아가기까지 (초) — 연출값. 0이면 뭘 맞고 죽었는지 못 보고 화면이 바뀐다.
const DEATH_BEAT_SEC := 0.9

## 🔴 **바닥은 source 2 한 장이 전부다.** 옛 source 0·1도 타일셋에 살아 있지만 방은 안 쓴다
## (지우면 source id가 밀려 이 상수가 조용히 어긋난다 — 그냥 둔다).
const TILE_SRC_GROUND := 2

## 이웃 비트마스크 — 「어느 변이 흙이 아닌가」(cons)·「어느 쪽으로 이어지나」(conn)에 같이 쓴다.
const DIR_T := 1
const DIR_B := 2
const DIR_L := 4
const DIR_R := 8

## 흙길 아틀라스 표 — **이웃이 좌표를 고른다**(9분할 오토타일). 키 = 흙이 **아닌** 변의 비트마스크.
## 🔴 **좌표를 짐작하지 마라** — 시트 40칸은 「넓은 길(9분할)」과 「폭 1칸 오솔길」이 섞여 있고
##  둘은 변의 풀 두께가 다르다(실측 12px ↔ 24px). **한 줄기 안에서 섞으면 이음매가 어긋난다.**
const ROAD_EDGE := {
	0: Vector2i(5, 0),            # 사방이 흙 = 중앙 (변형은 `_road_center_atlas`가 고른다)
	DIR_T: Vector2i(1, 0),        # 위가 풀 = 상변 A (B는 `_road_edge_atlas`가 번갈아 깐다)
	DIR_B: Vector2i(1, 1),        # 아래가 풀 = 하변 A
	DIR_L: Vector2i(4, 0),        # 왼쪽이 풀 = 좌변
	DIR_R: Vector2i(6, 0),        # 오른쪽이 풀 = 우변
	DIR_T | DIR_L: Vector2i(0, 0),
	DIR_T | DIR_R: Vector2i(3, 0),
	DIR_B | DIR_L: Vector2i(0, 1),
	DIR_B | DIR_R: Vector2i(3, 1),
}
## 상·하변의 B판 — 🔴 **같은 것만 이으면 굴곡이 주기로 반복돼 격자가 보인다.**
const ROAD_TOP_B := Vector2i(2, 0)
const ROAD_BOTTOM_B := Vector2i(2, 1)
## 안쪽 모서리(흙 한복판에 풀이 모서리로 파고든 칸) — 키 = 파고든 모서리의 비트마스크.
const ROAD_NUB := {
	DIR_T | DIR_L: Vector2i(4, 1),
	DIR_T | DIR_R: Vector2i(5, 1),
	DIR_B | DIR_L: Vector2i(6, 1),
	DIR_B | DIR_R: Vector2i(7, 1),
}
## 폭 1칸 오솔길 — 키 = 흙으로 **이어지는** 변의 비트마스크(9분할과 키의 뜻이 반대다).
## ⚠ 지금 방의 길은 전부 3칸 폭이라 여기로 안 온다. 랜드마크 길을 1칸으로 깔 때 산다.
const ROAD_NARROW := {
	0: Vector2i(4, 4),                     # 외딴 한 칸 — 시트에 없는 형태라 맨흙으로 떨어뜨린다
	DIR_T: Vector2i(0, 3),
	DIR_B: Vector2i(1, 3),
	DIR_L: Vector2i(2, 3),
	DIR_R: Vector2i(3, 3),
	DIR_T | DIR_B: Vector2i(0, 2),
	DIR_L | DIR_R: Vector2i(2, 2),
	DIR_B | DIR_R: Vector2i(4, 2),
	DIR_B | DIR_L: Vector2i(5, 2),
	DIR_T | DIR_R: Vector2i(6, 2),
	DIR_T | DIR_L: Vector2i(7, 2),
	DIR_B | DIR_L | DIR_R: Vector2i(5, 3),
	DIR_T | DIR_L | DIR_R: Vector2i(6, 3),
	DIR_T | DIR_B | DIR_R: Vector2i(7, 3),
	DIR_T | DIR_B | DIR_L: Vector2i(0, 4),
	DIR_T | DIR_B | DIR_L | DIR_R: Vector2i(4, 3),
}
const ROAD_NARROW_VERT_B := Vector2i(1, 2)
const ROAD_NARROW_HORZ_B := Vector2i(3, 2)

## 벌판·길 한복판의 **변형** — 무늬 없는 한 칸만 반복해 깔면 벌판이 단조롭다.
## ⚠ **얼룩 칸 (7,4)는 일부러 뺐다** — 변에 걸친 풀 얼룩이 16%라 자기 자신 옆에서만 이어진다.
##  섞어 깔면 반쪽 얼룩이 잘려 이음매가 튄다.
const GRASS_PLAIN := Vector2i(1, 4)
const GRASS_SUN := Vector2i(2, 4)     # 볕에 마른 풀
const GRASS_SPROUT := Vector2i(3, 4)  # 새순·잔꽃 (밝은 점 — 조금만)
const ROAD_CENTER_B := Vector2i(7, 0)
const ROAD_WEEDY := Vector2i(6, 4)    # 잔풀 난 흙 — 긴 길의 단조로움을 깨는 칸
const ROAD_GRAVEL := Vector2i(5, 4)

## 풀 타일(시트 (1,4))의 **바탕색** — 64×64 중 95%가 이 한 색이다.
## ⚠ **PNG에서 베낀 사본이라 그림을 다시 그리면 낡는다** — 그물이 PNG를 직접 읽어 대조하므로 빨개진다.
const GRASS_TILE_BASE := Color(0.2745, 0.5098, 0.1961)

## 챕터 색을 **옅은 틴트**로 읽는 세기. 0이면 세 챕터가 한 색이 되고, 1에 가까우면 흙이 형광으로 탄다.
## ⚠ 상·하한은 **안전선**이다 — 하한이 없으면 「어두운 챕터」 하나가 방을 통째로 밤으로 되돌린다.
## 🔴 **밝기를 정규화하지 않는다** — 챕터마다 평균을 1로 맞춰 색조만 남기면 세 챕터의 화면색 차이가
##  채널당 3~4/255로 줄어 사실상 한 무대가 된다. 그래서 기준이 **고정 참조 밝기**다.
## ⚠ `CHAPTER_TINT_REF_LUM`은 데이터의 사본이 아니라 「곱이 1이 되는 챕터 밝기」라는 기준점이다.
##  챕터를 더 밝게/어둡게 하려면 `data/chapters/*.tres`의 `room_ground_color`를 움직여라.
const CHAPTER_TINT_STRENGTH := 0.42
const CHAPTER_TINT_REF_LUM := 0.32
const CHAPTER_TINT_MIN := 0.80
const CHAPTER_TINT_MAX := 1.12

## 흙길의 **폭**(칸 수 — 연출값). 흙길은 지금 「입구 → 지점」과 「문 → 방 밖」 둘뿐이고,
##  지점 길의 손잡이는 `ChapterDef.landmarks`다(비우면 그 길이 통째로 사라진다).
## ⚠ 폭을 1로 줄이면 시트의 **오솔길 칸**(`ROAD_NARROW`)으로 갈린다.
## ⚠ 이름의 `EXIT_`는 옛 나가는 길에서 온 것이다 — 지금 개명하면 `_road_between` 쪽만 낡는다.
const EXIT_PATH_WIDTH_CELLS := 3

## 지점 노드에 새기는 `landmark_id` — 열림 처리와 `NamedSpawn.at_landmark`가 이걸 묻는다.
## 🔴 **왜 meta인가**: 슬롯 배열을 순서로 되짚으면 `_spawn_landmarks`가 `continue`로 건너뛴 슬롯
##  하나에 그 뒤가 통째로 한 칸씩 밀리고 **에러가 0이다.** meta는 노드를 만든 그 줄에서 붙는다.
const LANDMARK_ID_META := &"landmark_id"

## **프롭 표 — 「새 프롭 = 씬 한 장 + 여기 한 줄」.** 큰 것부터 놓아 작은 것이 사이를 채우게 한다
##  (다만 그건 손버릇이지 계약이 아니다 — 순서를 뒤집어도 개수는 ±2고 그물도 안 잰다).
##  • `share` = 격자 한 칸이 이 종류가 될 확률(백분위 · 누적으로 잘린다).
##    🔴 **후보 수 ≠ 선 수다** — 회피·겹침이 절반 넘게 쳐낸다(후보 45%가 화면당 나무 3.2~3.9그루로
##    떨어진 실측이 있다). `share`를 조일 땐 **그물이 찍는 실제 개수만** 보고 맞춰라.
##  • `sep`  = 이웃과의 최소 간격 반지름 — 문턱은 **둘의 합**이다.
##  • `road` = 🔴 **그림 반폭이 아니라 밑동 반폭이다** — 「길을 막는다」로 읽히는 건 기둥이지 가지가
##    아니다(가지가 길가에 걸치는 건 오히려 숲답다). ⚠ 그물이 같은 값을 따로 들고 대조한다.
const PROP_TABLE: Array[Dictionary] = [
	{"scene": "res://src/props/tree.tscn", "share": 44, "sep": 60.0, "road": 40.0},
	{"scene": "res://src/props/bush.tscn", "share": 26, "sep": 22.0, "road": 28.0},
]
## 🔴 나무만 씬의 `Trees` 아래로 간다 — 그물이 **그 홀더로** 나무 계약(물리 몸 0 · 뒤에서 비침)을
##  재므로, 여기로 꽂아야 새 나무가 저절로 그 그물에 든다. ⚠ 홀더가 비어 보여도 지우지 마라(매 판 찬다).
##  나머지는 `Props` 홀더로 가고, 그 홀더는 **타일 바로 뒤**에 꽂혀 몸·적·마법 아래에 깔린다.
const PROP_TREE_KIND := 0
const PROP_HOLDER := "Props"

## 배치 격자 (연출값). 지터를 안 주면 프롭이 **격자로 줄을 서** 벽지가 된다.
## ⚠ 지터가 격자의 절반에 가까워질수록 이웃이 붙어 겹침 검사가 많이 쳐낸다(비율 ≈ 0.375가 그 사이 자리다).
## ⚠ **share와 같이 움직여야 한다** — 격자를 조이면 후보 수가 늘어 밀도가 같이 뛴다.
const PROP_GRID := 120.0
const PROP_JITTER := 45.0
## 방 가장자리 여백 — 프롭이 벽선 밖으로 반쯤 걸치지 않게.
const PROP_EDGE_MARGIN := 60.0
## ⓓ 흙길 회피의 **세로 두께** — 밑동이 길 칸에 걸치는지만 보면 되므로 얇다(가로는 `road` 반폭).
const PROP_ROAD_BAND := 16.0
## ⓐ 잡몹·네임드 자리 — 적이 프롭에 파묻히면 「보이는 몸에 쏜다」가 깨진다.
const PROP_CLEAR_SPAWN := 100.0
## 보스 자리만 더 넓다 — 여긴 **무대**고(볕이 드는 빈터 `SunGlade`) 뱀 보스는 마디가 길어 100px론 걸린다.
const PROP_CLEAR_BOSS := 260.0
## ⓑ 입구·탈출구 — 시작 시야와 [E] 찾기.
const PROP_CLEAR_GATE := 150.0
## ⓔ 지점(둥지) — 둥지 그림이 192×152라 반폭 96 + 여유. 파묻히면 「저건 다르다」가 죽는다.
const PROP_CLEAR_LANDMARK := 220.0

@onready var _ground: ColorRect = $Ground
@onready var _tiles: TileMapLayer = $TileGround
@onready var _tree_holder: Node2D = $Trees
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud

var _chapter: ChapterDef = null
## 나가는 길 전부 — 지금은 씬의 남쪽 `$Exit` 하나다.
## ⚠ **배열로 남긴다** — `_prop_spot_ok` ⓑ가 순회하고, 문이 늘면 그대로 받는다.
##  🔴 단수 참조로 되돌리면 프롭 회피가 문을 못 보게 된다(에러 0).
var _exits: Array[InteractZone] = []
## 이 판에 실제로 선 지점들 — **입구→지점 흙길이 이 배열에서 파생한다.** 좌표를 두 번 적으면
## 지점을 옮길 때 길만 제자리에 남는다.
var _landmarks: Array[Node2D] = []
## 🔴 이 판에 깔린 **흙길 칸**(키 = 타일 셀) — 프롭 회피(ⓓ)가 **바로 이 표를 읽는다.**
##  「길이 어디 있나」를 두 번 계산하면 길 규칙을 고칠 때 타일과 프롭이 조용히 갈라진다.
var _road: Dictionary = {}
## 방 클리어 — **「방마다」다**(상자·문을 여는 방아쇠 · `_enter_room`이 매번 false로 되돌린다).
## ⚠ **챕터 클리어(codex·보상)와 다른 물건이다** — 그건 `_chapter_cleared`가 진다.
var _cleared: bool = false
## 🔴 **챕터 클리어 처리는 판에 한 번뿐** — `enemy_died`는 EventBus 전역이라 가드 없이는 두 번 돈다.
## 🔴 `_cleared`와 합치지 마라 — 그건 방마다 리셋되므로 챕터 보상이 방마다 다시 열릴 수 있게 된다.
var _chapter_cleared: bool = false
## 씬 전환은 한 번뿐 — 귀환 도중 죽거나, 죽는 중에 E를 누르면 두 번 갈아탄다.
## 🔴 **판 전체 수명이다 — `_enter_room`이 건드리면 안 된다.**
var _leaving: bool = false
## 지금 몇 번째 방인가 (0부터). **배치 굴림의 salt**로 들어가 방마다 다른 숲이 된다.
var _room_index: int = 0
## 이 방의 상자 종류 — **문이 고른 값**이 `_enter_room`으로 들어온다. 첫 방은 `ROOM_CHEST_ID`.
var _room_chest_id: StringName = ROOM_CHEST_ID
## 입구 = 씬이 쥔 `Player`의 처음 자리. 방마다 여기로 되돌린다.
## 🔴 **왜 상수가 아니라 「처음 자리를 기억」인가**: 그물이 `add_child` 전에 Player를 프롭 자리로 옮겨
##  규칙 ⓑ가 실제로 도는지 잰다. 코드가 좌표를 박아 덮어쓰면 그 주입이 무효가 돼 늘 그린이다.
var _entrance: Vector2 = Vector2.ZERO
## 🔴 `_spawn_props`가 만드는 홀더 — **필드로 든다.** 매번 새로 만들면 방마다 쌓여 `Props`가 둘·셋이
##  되고, `get_node_or_null("Props")`가 **첫 번째만** 돌려줘 그물이 옛 홀더를 본다(에러 0).
var _prop_holder: Node2D = null


## **방을 헐 때 비우는 그룹.**
## 🔴 **`interact_zones`가 여기 든 것이 함정이자 계약이다** — `interact_zone.gd`가 자기를 그 그룹에
##  넣으므로 씬의 남쪽 `$Exit`도 든다. 가드 없이 헐면 **나가는 길이 방 하나 지나고 사라지는데
##  에러가 0이다.** ⇒ 그룹을 빼서 피하지 않고 `_teardown_room`의 `owner` 가드로 막는다 — 그래야
##  코드가 만든 문이 그룹을 늘리지 않아도 저절로 헐린다.
const ROOM_GROUPS: Array[StringName] = [
	&"enemies", &"props", &"landmarks", &"drop_pickups",
	&"enemy_projectiles", &"player_projectiles", &"blasts", &"pillars",
	&"interact_zones", &"room_rewards",
]

## 🔴 **방 보상 상자의 그룹 — `landmarks`를 재사용하지 않는다.** 그 그룹은 「데이터가 세운 지점」이라는
##  뜻이고, 그물이 **그룹 수 == `ChapterDef.landmarks` 슬롯 수**를 단언한다. 보상 상자가 거기 끼면
##  방을 깬 뒤에 그 그물이 빨개진다(에러 0 · 원인 불명).
const ROOM_REWARD_GROUP := &"room_rewards"

## 방 보상 상자의 종류 — 잠정값이라 `.tres` 스키마가 아니라 **스크립트 const로 시작한다**
##  (확정 전에 스키마를 만들면 F5 뒤 그 스키마가 낡는다).
## ⚠ `LandmarkDef`가 「지점」에서 「상자 종류」로 뜻만 옮겨 온 필드다 — 그 사슬(`LandmarkDef.drops`)이
##  죽으면 지점이 유일 공급원인 재료가 끊겨 레시피 도달 그물이 빨개진다.
const ROOM_CHEST_ID := &"lm_nest"

## 문 개수 · 한 판의 방 개수 — 둘 다 **F5로 재보려고 넣은 잠정값**이라 스크립트 const로 시작한다.
const DOOR_COUNT := 3
const ROOM_COUNT := 5
## 문이 서는 자리 — 북쪽 벽 안쪽으로 이만큼. 벽에 딱 붙이면 트리거가 화면 밖에 걸린다.
const DOOR_INSET := 90.0
## 문 x는 방 너비를 `DOOR_COUNT + 1`로 나눠 고르게 둔다 — 좌표를 안 박는다(방을 바꾸면 따라온다).
##  ⚠ 방마다 조금씩 흔든다 — 그래야 방이 「같은 방」으로 안 읽힌다.
const DOOR_JITTER := 70.0
## `preload`가 아니라 `load`인 이유는 `boss_scene_path`와 같다(씬 순환).
const DOOR_SCENE := "res://src/props/door.tscn"
## 마지막 방의 귀환 문 글자 — 🔴 **이 문만 `_extract()`로 간다.**
const RETURN_DOOR_LABEL := "마을로 돌아간다"


## 문이 고를 수 있는 보상 = 「쓸 수 있는 상자 종류」 전부.
## 🔴 **목록을 손으로 안 든다 — `Db`에서 거른다.** 「새 상자 종류 = `.tres` 한 장」이 그래야 성립하고,
##  손 목록을 두면 새 `.tres`를 넣어도 문에 안 뜨는데 **에러가 0이다.**
## 🔴 **미리보기 문구도 여기서 파생한다**(`LandmarkDef.title`) — 문에 글자를 박으면 그 순간 거짓말이 된다.
func _reward_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for def: LandmarkDef in Db.all_landmarks():
		if def == null or def.scene_path == "" or def.drops.is_empty():
			continue
		out.append(def.id)
	return out


func _ready() -> void:
	# ── 판에 한 번 ────────────────────────────────────────────────────────────
	# 🔴 **아래 셋을 `_enter_room`으로 흘리지 마라** — **방마다 만HP/만마나**가 되어 「방을 이어서
	#  깬다」의 소모가 통째로 사라지는데 **에러가 0이다.**
	GameState.reset_player_hp()
	GameState.restore_mana_full()
	GameState.in_expedition = true
	# 모달 플래그를 내린다 — 오토로드라 씬 전환에도 남는다.
	GameState.ui_modal_open = false
	# ⚠ **연결도 판 1회다** — 방마다 다시 이으면 같은 시그널이 방 수만큼 겹쳐 발사·안내가 중복된다.
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.enemy_died.connect(_on_enemy_died)
	# 완료가 아니라 정산 대기라 quest_ready를 듣는다.
	EventBus.quest_ready.connect(_on_quest_ready)
	# 🔴 입구를 **읽어서** 기억한다(`_entrance` 머리말 — 박으면 그물의 주입이 죽는다).
	_entrance = _player.position

	# 🔴 어느 챕터인가 — 비었거나 미등록이면 **조용히 빈 방을 띄우지 않는다.**
	# F6으로 이 씬을 직접 실행하면 pending_chapter가 비어 여기로 온다 — 베이스로 되돌린다.
	_chapter = Db.get_chapter(GameState.pending_chapter)
	if _chapter == null:
		push_error("boss_room: pending_chapter '%s'가 Db.chapters에 없다 — 베이스로 되돌아간다"
			% String(GameState.pending_chapter))
		_leaving = true
		_to_base.call_deferred()
		return

	_apply_chapter_tint()
	# 🔴 `_prop_spot_ok` ⓑ가 `_exits`를 읽으므로 `_spawn_props`보다 **먼저여야 한다.**
	#  판 1회인 이유 = 출구는 씬 노드라 방을 헐어도 살아 있다(`ROOM_GROUPS` 머리말).
	_wire_exit()
	# ⚠ **카메라 경계도 판 1회다** — `Ground` rect에서 파생하는데 그 rect가 방마다 안 바뀐다.
	_clamp_camera_to_room()
	_enter_room(0)


## **방 하나를 세운다 — 「방마다」의 전부다.**
##
## 🔴 **두 번 불러도 안 깨지는 것이 이 함수의 계약이다.** 깨지는 자리 셋을 여기서 막는다:
##   ⓐ `Props` 홀더가 쌓인다 → `_prop_holder`를 재사용한다
##   ⓑ 헌 노드가 **`queue_free`만으로는 그룹 질의에서 안 빠진다**(프레임 끝에야 지워진다) →
##      `_teardown_room`이 트리에서 먼저 뽑는다. 안 뽑으면 새 프롭이 **헌 프롭을 피해** 놓인다.
##   ⓒ 타일이 덮어써지지 않는 칸이 남는다(테두리 위 길) → `_fill_tiles`가 먼저 `clear()`한다.
##
## 🔴 **호출은 `call_deferred`로 해라** — 방아쇠가 「마지막 적 사망」이라 **물리 flush 한복판**이고,
##  거기서 `add_child`/`remove_child`를 하면 엔진이 짖는다. ⚠ 그 에러는 `ERROR:`지 `SCRIPT ERROR:`가
##  아니라 테스트 러너를 그대로 통과한다. (`_ready`의 첫 호출은 물리 밖이라 직접 불러도 된다.)
##
## ⚠ `index`는 **배치 굴림의 salt**로만 쓰인다. `chest_id`가 비면 `ROOM_CHEST_ID`로 떨어진다.
func _enter_room(index: int, chest_id: StringName = &"") -> void:
	_room_index = index
	_room_chest_id = chest_id if chest_id != &"" else ROOM_CHEST_ID
	# 🔴 **`_cleared`만 되돌린다 — `_leaving`은 판 수명이다.** 여기서 내리면 귀환·사망 도중에
	#  방이 하나 더 서서 **두 번 씬을 갈아탄다.**
	_cleared = false
	_teardown_room()
	# 🔴 입구로 되돌린다 — `_spawn_props` ⓑ와 `_landmark_road_cells`가 **플레이어 자리에서 파생**하므로
	#  둘보다 반드시 먼저다.
	_player.position = _entrance
	# 🔴 **지점이 `_fill_tiles`보다 먼저다** — 입구→지점 흙길이 `_landmarks`에서 파생한다.
	#  뒤바뀌면 지점은 서 있는데 **길이 안 깔려** 아무도 안 가는 물건이 되고 에러가 0이다.
	_spawn_landmarks()
	_fill_tiles()
	# 🔴 **`_fill_tiles` 뒤다** — 프롭이 흙길을 피하려면(ⓓ) `_road`가 이미 차 있어야 한다.
	#  뒤바뀌면 표가 비어 **회피가 통째로 무효**가 되는데 에러는 0이다(길 위에 나무가 선다).
	# 🔴 그리고 **잡몹·보스보다 앞이다** — `add_child` 순서가 곧 그리는 순서라(둘 다 z 0이다),
	#  뒤로 밀면 프롭이 적·플레이어 위에 덮인다.
	_spawn_props()
	# 🔴 스폰이 실패하면 **여기서 멈춘다** — `_spawn_boss` 안의 `return`은 자기 함수만 벗어나므로,
	# 예전엔 이미 떠나기로 한 방이 잡몹을 깔고 「…를 쓰러뜨려라」를 한 프레임 띄웠다.
	if not _spawn_boss():
		return
	_spawn_mobs()
	# 네임드는 **잡몹 뒤**다 — 「이 판에 얹힌 것」이라는 순서로 읽히고, 그물도 같은 순서로 센다.
	_spawn_named()
	_say_room_goal()


## **방을 헌다 — 코드가 만든 것만.**
##
## 🔴 **`owner` 가드가 이 함수의 심장이다** — 씬이 쥔 노드는 `owner`가 방 루트고 `add_child`로 붙인
##  노드는 null이다. 없으면 씬의 `$Exit`가 방 하나 지나고 사라진다(에러 0).
## 🔴 **`queue_free`만으로는 모자란다 — 트리에서 먼저 뽑는다.** `queue_free`는 프레임 끝에야 반영돼
##  그 사이 `_spawn_props`가 돌면 헌 프롭이 **아직 그룹에 있어** 새 프롭의 겹침 검사에 걸린다.
## ⚠ **홀더 자체는 안 헌다** — `Trees`는 씬 노드고 `Props`는 재사용한다.
func _teardown_room() -> void:
	for group: StringName in ROOM_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			if node.owner != null:
				continue   # 씬이 쥔 노드 — 판 수명이다
			var parent := node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.queue_free()
	_landmarks.clear()
	_road.clear()


## 방의 목표 줄 — **방마다 다시 띄운다**(안 띄우면 옛 방의 줄이 남는다).
## 🔴 `sticky`인 이유 = `say()`에 수명이 있어 안 붙이면 목표가 4.5초 뒤 조용히 사라진다.
## 🔴🔴 **이 줄은 규칙이 바뀔 때마다 마지막까지 옛 조작을 가르친다 — 이미 세 번 거짓말했다.**
##  sticky는 「유효한 지시만」이 계약이라 틀린 조작을 가르치는 순간 위반인데, **그물이 이 줄을 안 문다
##  (문구 사본만 스캔한다) ⇒ 재는 것은 F5·스샷뿐이다.** ⚠ 규칙을 또 바꾸거든 **여기부터 열어라.**
func _say_room_goal() -> void:
	var boss_def := Db.get_enemy(_chapter.boss_enemy_id)
	var boss_name := boss_def.display_name if boss_def != null else String(_chapter.boss_enemy_id)
	_hud.say("%s — 방 %d/%d. 적을 모두 쓰러뜨리면 상자와 문이 열린다 (%s도 여기 있다)"
		% [_chapter.title, _room_index + 1, ROOM_COUNT, boss_name], false, true)


## 이 방이 깨졌나 — 상자·문이 이 값에서 열린다. 그물이 읽는 **공개 문**이다.
func room_cleared() -> bool:
	return _cleared


## **살아 있는 적 수** — `queue_free`된 시체를 뺀다.
##
## 🔴 **이 필터가 없으면 방 클리어가 영영 안 온다.** `forest_enemy._die`가 `enemy_died`를
##  **`queue_free()` 앞에서** 쏘므로 수신 시점에 죽은 그 몸이 아직 그룹에 있다(늘 1로 잡힌다).
##  ⚠ **필터만으로는 모자라다** — 죽는 자기 자신은 emit 시점에 아직 `queue_free` 전이라 필터에도
##   안 걸린다. ⇒ 짝은 `_on_enemy_died`의 `call_deferred`이고 **둘 중 하나만 있으면 안 열린다.**
## ⚠ `dummy_target`(허수아비)도 그룹 `"enemies"`다 — 방에 놓는 날 클리어가 영영 안 온다.
func _live_enemies() -> int:
	var n := 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			n += 1
	return n


## 챕터 분위기 = **옅은 틴트**. `ChapterDef.room_ground_color`의 색조만 뽑아 1.0 언저리로 덮는다.
## 🔴 **밝기 곱으로 되돌리지 마라** — 바닥 시트가 이미 낮 밝기라 곱을 두 번 먹고 **에러 0으로
##  화면만 형광색이 된다**(흙이 형광 노랑으로 탄다).
## ⚠ 테두리(`Ground` ColorRect)도 같은 틴트를 먹은 풀색으로 맞춘다 — 타일이 못 덮는 가장자리 한 칸이
##  다른 색이면 방에 액자가 둘린다.
## ⚠ 이 곱은 `Daylight`(CanvasModulate) **앞**이다 — 화면 실색 = 타일색 × 틴트 × Daylight.
func _apply_chapter_tint() -> void:
	var tint := _chapter_tint()
	_tiles.modulate = tint
	_ground.color = Color(
		GRASS_TILE_BASE.r * tint.r, GRASS_TILE_BASE.g * tint.g, GRASS_TILE_BASE.b * tint.b, 1.0)


## **고정 참조 밝기**로 나눠 색조와 명암을 같이 남기고, 흰색에서 그만큼만 끌어온다
## (그래서 세기를 0으로 두면 곱이 통째로 1 = 그림 그대로가 된다).
func _chapter_tint() -> Color:
	var c := _chapter.room_ground_color
	return Color(
		_tint_channel(c.r), _tint_channel(c.g), _tint_channel(c.b), 1.0)


func _tint_channel(v: float) -> float:
	return clampf(lerpf(1.0, v / CHAPTER_TINT_REF_LUM, CHAPTER_TINT_STRENGTH),
		CHAPTER_TINT_MIN, CHAPTER_TINT_MAX)


## 🔴 카메라를 방 안으로 묶는다 — `player.tscn`의 `Camera2D`엔 `limit_*`이 없어서, 안 묶으면
## 플레이어가 경계 근처에 설 때 **화면 절반이 방 밖(엔진 배경색)으로 빈다.**
## ⚠ **Ground rect에서 파생한다** — 방 크기를 또 바꾸면 따라온다(좌표를 베끼면 그 순간 갈라진다).
## ⚠ 마을에는 영향이 없다: `player.tscn`은 씬마다 새 인스턴스라 limit도 이 방에서만 산다.
func _clamp_camera_to_room() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var top_left := _ground.global_position
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(top_left.x + _ground.size.x)
	cam.limit_bottom = int(top_left.y + _ground.size.y)


## 나가는 길을 살린다 — 씬의 남쪽 `$Exit`를 `_extract`에 잇는다.
## 🔴🔴 **연결을 빠뜨리면 에러가 0이고 화면도 멀쩡한데 가방이 조용히 증발한다**(E는 먹히고 안내도
##  뜨는데 창고로 안 가고 자동 저장도 안 돈다). ⇒ **나가는 길을 새로 세우거든 여기를 지나게 해라.**
## ⚠ 출구는 `zone_id = &"exit"`이다 — **씬 파일이 그 값을 쥔다.** 다른 값을 새로 만들지 마라.
func _wire_exit() -> void:
	_exits.clear()
	var south := get_node_or_null(^"Exit") as InteractZone
	if south == null:
		# 침묵 금지 — 출구가 없으면 나가는 길이 통째로 사라지는데 화면은 멀쩡하다.
		push_error("boss_room: 씬에 남쪽 출구($Exit)가 없다 — 나가는 길이 사라진다")
		return
	_exits.append(south)
	if not south.interacted.is_connected(_extract):
		south.interacted.connect(_extract)


## 지점(랜드마크)을 세운다 — **`ChapterDef.landmarks` → `Db.landmarks` → `LandmarkDef.scene_path`**
## 세 걸음이고, 🔴 **어느 걸음이 끊겨도 화면엔 아무 일도 안 난다.** 그래서 걸음마다 짖는다.
##
## 🔴 **「새 지점 = `.tres` 한 장 + 프롭 씬 한 장」이 여기서 성립한다** — 이 함수엔 지점 종류가 한 글자도
##  안 적혀 있다. 「열렸다」는 `opened` 하나로 오고, 무엇이 나오는지는 그 지점의 `.tres`가 정한다.
## 🔴 **`opened`를 잇는 건 방이다** — 지점이 `src/field/`를 물면 preload 방향(field → props 단방향)이 뒤집힌다.
## 🔴 그룹 `"landmarks"`도 **방이 붙인다** — 지점 씬마다 붙이면 새 지점 하나가 빠뜨리는 순간
##  「서 있는데 아무도 못 찾는」 물건이 된다.
func _spawn_landmarks() -> void:
	_landmarks.clear()
	for slot: LandmarkSlot in _chapter.landmarks:
		if slot == null:
			continue
		var def := Db.get_landmark(slot.landmark_id)
		if def == null:
			push_error("boss_room: landmark_id '%s'가 Db.landmarks에 없다 — 그 자리가 빈 채로 선다"
				% String(slot.landmark_id))
			continue
		if def.scene_path == "":
			push_error("boss_room: 지점 '%s'의 scene_path가 비었다 — 겉모습 없이 자리만 잡는다"
				% String(def.id))
			continue
		var packed := load(def.scene_path) as PackedScene
		if packed == null:
			push_error("boss_room: 지점 '%s'의 scene_path '%s'를 못 읽었다"
				% [String(def.id), def.scene_path])
			continue
		# 🔴 루트가 Node2D가 아니면 `as Node2D`가 null이라 아래 `.position`에서 **방이 통째로 죽는다.**
		#  「새 지점 = 프롭 씬 한 장」이 선언된 계약이라 남이 Control 루트 씬을 반드시 한 번은 꽂는다.
		var inst := packed.instantiate()
		var node := inst as Node2D
		if node == null:
			push_error("boss_room: 지점 '%s'의 씬 루트가 Node2D가 아니다(%s) — 자리를 못 잡아 안 세운다"
				% [String(def.id), inst.get_class()])
			inst.free()
			continue
		# 🔴 위치는 `add_child` **앞**이다(보스·잡몹과 같은 계약) — 지점 씬이 `_ready`에서 자기
		#  자리로 무언가를 파생시키면 뒤에 옮길 때 한 프레임 어긋난다.
		node.position = slot.position
		node.add_to_group(&"landmarks")
		# 🔴 **노드를 만든 그 줄에서** 새긴다(`LANDMARK_ID_META` 머리말).
		node.set_meta(LANDMARK_ID_META, def.id)
		add_child(node)
		_landmarks.append(node)
		# ⚠ `has_signal` 가드 — 「새 지점 = 프롭 씬 한 장」이라 남이 시그널 없는 씬을 꽂는다.
		#  가드가 없으면 그 한 장이 **판을 통째로 못 세운다**(위 Node2D 가드와 같은 결).
		if node.has_signal(&"opened"):
			node.connect(&"opened", _on_landmark_opened.bind(node))
		elif not def.drops.is_empty():
			# 🔴 침묵 금지 — 산출을 실어 놓고 **밟을 방법이 없는** 지점이다. 화면에선 그냥
			#  「예쁜 이정표」로 보이고 에러가 0이다.
			push_warning("boss_room: 지점 '%s'가 산출(drops %d줄)을 들었는데 씬에 `opened` 시그널이 없다 — 밟을 방법이 없다"
				% [String(def.id), def.drops.size()])


## **지점을 열었다 — 산출을 굴려 낱개로 뿌린다.**
##
## 🔴 **여기가 「무엇이 나오나」의 유일한 소유자다** — 지점 씬은 자기가 무엇을 주는지 **모른다.**
##  그래야 「새 지점 = `.tres` 한 장」이 성립한다.
## 🔴 **굴림·스폰은 `DropRoll`을 그대로 부른다** — 적의 `_die`가 부르는 그 함수다. 자기 굴림을
##  새로 쓰면 `DropEntry`의 배타 짝 규칙이 두 벌이 되고 **에러가 0이다.**
## ⚠ **재열기 가드는 여기 없다 — 지점이 진다.** 여기에도 두면 가드가 두 벌이라 한쪽을 지워도
##  뮤테이션이 안 걸린다(`_spawn_enemy_at`의 보스 가드와 같은 판단).
## ⚠ **연 상태를 `GameState`에 넣지 마라** — 방은 매 판 새로 서므로 노드가 들면 저절로 다시 찬다.
func _on_landmark_opened(node: Node2D) -> void:
	var id: StringName = node.get_meta(LANDMARK_ID_META, &"")
	var def := Db.get_landmark(id)
	if def == null:
		# 침묵 금지 — meta가 비었거나 Db에서 사라지면 **열었는데 아무것도 안 나오고 에러가 0**이다.
		push_error("boss_room: 열린 지점의 landmark_id('%s')를 Db에서 못 찾았다 — 산출이 통째로 사라진다"
			% String(id))
		return
	if def.drops.is_empty():
		# 🔴 데이터가 비면 **열어도 아무 일이 안 나고 화면은 멀쩡하다** — 채우는 건 데이터 몫이라 짖는다.
		push_warning("boss_room: 지점 '%s'의 drops가 비었다 — 열어도 아무것도 안 나온다 (설계 §10-2 세 층 미기입)"
			% String(def.id))
		return
	var rolled := DropRoll.roll(def.drops, GameState)
	if rolled.is_empty():
		return
	DropRoll.spawn_loose(self, node.global_position, rolled)


## 이 판에 실제로 **선** 지점 중 이 id인 것들의 자리 — `NamedSpawn.at_landmark`가 쓴다.
## 🔴 **「첫 번째」가 아니라 전부를 돌려주는 게 계약이다** — 같은 지점 2채가 문법상 가능한데
##  첫 번째만 고르면 **둘째 둥지엔 영영 우두머리가 안 뜨고 에러가 0이다.**
## ⚠ `_landmarks`는 **실제로 선 것만** 든다 — 그래서 「자리를 못 찾았다」가 곧 「그 지점이 이 판에
##  안 섰다」이고, 호출부가 그걸 에러로 승격한다.
func _landmark_sites(id: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if id == &"":
		return out
	for node: Node2D in _landmarks:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_meta(LANDMARK_ID_META, &"") == id:
			out.append(node.position)
	return out


## 바닥 타일을 Ground rect에 맞춰 깐다 — **벌판은 풀, 길은 흙길**이다(방이 낮이라 풀길은 길로 안 읽힌다).
## ⚠ 벌판은 **변형 셋을 섞는다** — 한 칸만 반복해 깔면 넓은 바닥이 단조롭다.
func _fill_tiles() -> void:
	# 🔴 **먼저 지운다.** 아래 첫 루프는 방 rect 안을 전부 덮어쓰지만, 둘째 루프가 그리는 **테두리 위
	#  길 칸**은 「길일 때만」 써진다 — 방마다 길이 갈리면 **헌 흙길 토막이 테두리에 남는다**(에러 0).
	_tiles.clear()
	var ts: Vector2i = _tiles.tile_set.tile_size
	var rect := Rect2(_ground.position, _ground.size).grow(-float(ts.x))   # 가장자리 한 칸은 틴트가 보이게
	var from := Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y))
	var to := Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y))
	# 🔴 **필드에 남긴다** — 프롭 회피(ⓓ)가 이 표를 그대로 읽는다. 지역 변수로 두면 「길이 어디
	#  있나」를 두 번 계산하게 되고, 길 규칙을 고치는 날 타일과 프롭이 조용히 갈라진다.
	_road = _road_cells(ts)
	var road := _road
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var cell := Vector2i(x, y)
			_tiles.set_cell(cell, TILE_SRC_GROUND,
				_road_atlas(cell, road) if road.has(cell) else _grass_atlas(cell))
	# 🔴 **길만 테두리 한 칸 위에도 그린다** — 마지막 칸에서 끊으면 그 칸이 「풀로 막힌 끝」 타일이 돼
	#  길이 방 안에서 막다른 골목으로 보이고, 출구가 겉모습이 없다는 것과 겹쳐 나갈 데를 못 찾는다.
	var outer_from := Vector2i(floori(_ground.position.x / ts.x), floori(_ground.position.y / ts.y))
	var outer_to := Vector2i(ceili((_ground.position.x + _ground.size.x) / ts.x),
		ceili((_ground.position.y + _ground.size.y) / ts.y))
	for cell: Vector2i in road:
		if cell.x >= from.x and cell.x < to.x and cell.y >= from.y and cell.y < to.y:
			continue   # 위 루프가 이미 그렸다
		if cell.x < outer_from.x or cell.x >= outer_to.x or cell.y < outer_from.y or cell.y >= outer_to.y:
			continue   # 방 밖 — 길 계산에만 쓰이고 그려지진 않는다
		_tiles.set_cell(cell, TILE_SRC_GROUND, _road_atlas(cell, road))


## **프롭을 규칙(ⓐ~ⓔ · `_prop_spot_ok`)으로 놓는다** — 좌표를 씬에 박으면 그 규칙을 사람이 매번
## 지켜야 하고 **어겨도 아무도 모른다.** 코드에 있으면 그물이 잴 수 있고 방을 옮겨도 배치가 따라온다.
##
## 🔴 **결정적이다 — 판마다 안 바뀐다**(`randf` 대신 `_cell_hash`). **프롭은 지형이라** 같은 챕터를
##  다시 들어가면 같은 숲이라야 「저 나무 뒤」가 기억이 된다. 챕터마다 갈리는 건 굴림이 아니라
##  **회피 조건**이다(몹 자리·지점·길이 챕터마다 달라 통과하는 칸이 갈린다).
## 🔴 그룹 `props`는 **방이 붙인다** — 씬이 놓은 것도 같은 목록에 넣는다(규칙은 「누가 놓았나」를 안 본다).
## ⚠ **좌우 반전(`flip_h`)으로 변화를 주지 않는다** — 광원이 왼쪽 위 고정이라 뒤집으면 그 프롭만
##  다른 해를 받는다. 변화는 **컷을 여러 장 두는 것**으로 준다.
func _spawn_props() -> void:
	var holder := _props_holder()

	var placed: Array[Vector2] = []
	var radii: Array[float] = []
	for child: Node in _tree_holder.get_children():
		var tree := child as Node2D
		if tree == null:
			continue
		tree.add_to_group(&"props")
		placed.append(tree.position)
		radii.append(float(PROP_TABLE[PROP_TREE_KIND]["sep"]))

	var area := Rect2(_ground.position, _ground.size).grow(-PROP_EDGE_MARGIN)
	for kind in PROP_TABLE.size():
		var packed := load(String(PROP_TABLE[kind]["scene"])) as PackedScene
		if packed == null:
			# 침묵 금지 — 씬 하나를 못 읽으면 그 층이 통째로 사라지는데 화면은 「그냥 휑한 숲」이다.
			push_error("boss_room: 프롭 씬 '%s'를 못 읽었다 — 그 층이 통째로 안 선다"
				% String(PROP_TABLE[kind]["scene"]))
			continue
		for at: Vector2 in _prop_spots(area, kind):
			if not _prop_spot_ok(at, kind, placed, radii):
				continue
			var node := packed.instantiate() as Node2D
			if node == null:
				continue
			node.position = at
			node.add_to_group(&"props")
			# 나무는 씬의 `Trees`로 — 씬이 놓은 나무와 같은 물건이라 홀더를 안 가른다.
			(_tree_holder if kind == PROP_TREE_KIND else holder).add_child(node)
			placed.append(at)
			radii.append(float(PROP_TABLE[kind]["sep"]))


## 프롭 홀더 — **한 번 만들고 계속 쓴다.**
## 🔴 매번 새로 만들면 `Props`가 방마다 쌓이고 `get_node_or_null("Props")`가 **첫 번째만** 돌려줘
##  그물·다음 코드가 **아무도 안 쓰는 헌 홀더**를 보게 된다(에러 0).
## 🔴 **타일 바로 뒤**에 꽂는다 — `add_child`는 맨 뒤에 붙는데, 그러면 덤불이 적·플레이어 **위에**
##  그려진다(둘 다 z 0이라 트리 순서가 곧 앞뒤다).
func _props_holder() -> Node2D:
	if _prop_holder != null and is_instance_valid(_prop_holder):
		return _prop_holder
	var holder := Node2D.new()
	holder.name = PROP_HOLDER
	add_child(holder)
	move_child(holder, _tiles.get_index() + 1)
	_prop_holder = holder
	return holder


## 이 종류가 노려 볼 **자리 후보**들 — 지터를 준 격자에서 뽑는다.
## 격자 칸마다 종류가 **하나로 정해지므로**(`_prop_kind_at`) 종류를 바꿔 가며 훑어도 같은 칸이
## 두 번 쓰이지 않는다. 순서(큰 것 → 작은 것)만으로 「작은 것이 사이를 채운다」가 나온다.
func _prop_spots(area: Rect2, kind: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cols := int(area.size.x / PROP_GRID)
	var rows := int(area.size.y / PROP_GRID)
	for j in rows + 1:
		for i in cols + 1:
			var cell := Vector2i(i, j)
			if _prop_kind_at(cell) != kind:
				continue
			var jx := (float(_cell_hash(cell, 41)) / 50.0 - 1.0) * PROP_JITTER
			var jy := (float(_cell_hash(cell, 47)) / 50.0 - 1.0) * PROP_JITTER
			var at := area.position + Vector2(float(i), float(j)) * PROP_GRID + Vector2(jx, jy)
			if not area.has_point(at):
				continue
			out.append(at)
	return out


## 격자 칸 하나가 무슨 종류인가 — `share`를 누적해 자른다. 합이 100에 못 미치면 나머지는 **빈칸**이다
## (그게 「듬성듬성」을 만든다 — 전부 채우면 벽지가 된다).
func _prop_kind_at(cell: Vector2i) -> int:
	var h := _cell_hash(cell, 53)
	var acc := 0
	for kind in PROP_TABLE.size():
		acc += int(PROP_TABLE[kind]["share"])
		if h < acc:
			return kind
	return -1


## 🔴 **규칙 ⓐ~ⓔ가 전부 여기 있다** — 한 자리에 모아 둬야 새 규칙을 더할 때 빠뜨릴 문이 없다.
## 🔴 좌표를 하나도 안 박는다: 스폰은 `ChapterDef`에서 · 입구는 `Player` 노드에서 · 출구는 `_exits`에서 ·
##  지점은 `_landmarks`에서 · 길은 `_road`에서 파생한다. **방을 바꾸면 배치가 따라온다.**
func _prop_spot_ok(at: Vector2, kind: int, placed: Array[Vector2], radii: Array[float]) -> bool:
	# ⓓ 흙길 위 금지 — 출구는 겉모습이 없어서 **보이는 안내가 그 길뿐**이다.
	if _prop_touches_road(at, float(PROP_TABLE[kind]["road"])):
		return false
	# ⓐ 잡몹·네임드·보스 자리 — 적이 프롭에 파묻히면 「보이는 몸에 쏜다」가 깨진다.
	if at.distance_to(_chapter.boss_spawn) < PROP_CLEAR_BOSS:
		return false
	for spawn: MobSpawn in _chapter.mob_spawns:
		if spawn != null and at.distance_to(spawn.position) < PROP_CLEAR_SPAWN:
			return false
	# ⚠ 네임드는 **뜰 수도 안 뜰 수도** 있지만 자리는 데이터에 있다 — 뜬 판에서만 파묻히면
	#  「어떤 판은 네임드가 안 보인다」가 돼서 오히려 더 나쁘다. 그래서 굴림과 무관하게 비운다.
	for named: NamedSpawn in _chapter.named_pool:
		if named != null and at.distance_to(named.position) < PROP_CLEAR_SPAWN:
			return false
	# ⓑ 입구(플레이어 스폰)·**모든 탈출구**
	if at.distance_to(_player.position) < PROP_CLEAR_GATE:
		return false
	for zone: InteractZone in _exits:
		if zone != null and is_instance_valid(zone) and at.distance_to(zone.position) < PROP_CLEAR_GATE:
			return false
	# ⓔ 지점(둥지) 둘레
	for landmark: Node2D in _landmarks:
		if landmark != null and is_instance_valid(landmark) \
			and at.distance_to(landmark.position) < PROP_CLEAR_LANDMARK:
			return false
	# 이웃과 겹치지 않는다 — 문턱은 **두 반지름의 합**이라 나무끼리는 멀고 잔돌끼리는 붙어도 된다.
	var sep := float(PROP_TABLE[kind]["sep"])
	for i in placed.size():
		if at.distance_to(placed[i]) < sep + radii[i]:
			return false
	return true


## ⓓ 이 자리의 **밑동이 흙길 칸을 밟는가** — 가로는 밑동 반폭(`road`), 세로는 얇은 띠다.
## 원점이 접지선이라(프롭 씬 계약) 이 검사가 곧 「길 위에 서 있나」다.
func _prop_touches_road(at: Vector2, pad: float) -> bool:
	var ts: Vector2i = _tiles.tile_set.tile_size
	var x0 := floori((at.x - pad) / float(ts.x))
	var x1 := floori((at.x + pad) / float(ts.x))
	var y0 := floori((at.y - PROP_ROAD_BAND) / float(ts.y))
	var y1 := floori((at.y + PROP_ROAD_BAND) / float(ts.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _road.has(Vector2i(x, y)):
				return true
	return false


## 흙길 칸 전부 — 줄기가 둘이다: **입구 → 지점** · **문 → 방 밖**.
## 🔴 **좌표는 노드에서 파생한다** — 여기 베끼면 지점·문을 옮길 때 길만 제자리에 남는다.
func _road_cells(ts: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var half: int = (EXIT_PATH_WIDTH_CELLS - 1) / 2
	_landmark_road_cells(half, ts, out)
	_door_road_cells(half, ts, out)
	return out


## 문에서 방 밖으로 뻗는 길.
## 🔴🔴 **길은 입장 때 깔리고 문은 클리어 때 서므로 자리를 `_door_spots()` 하나에서 파생시킨다** —
##  좌표를 두 번 계산하면 길만 엉뚱한 데 남고 에러가 0이다.
func _door_road_cells(half: int, ts: Vector2i, out: Dictionary) -> void:
	var rect := Rect2(_ground.position, _ground.size)
	for at: Vector2 in _door_spots():
		var cell := Vector2i(floori(at.x / float(ts.x)), floori(at.y / float(ts.y)))
		_road_between(_edge_cell_beyond(at, rect, ts), cell, half, out)


## 이 자리에서 **가장 가까운 변**을 골라 그 **한 칸 밖**의 셀을 돌려준다.
## 🔴 변을 거리로 고른다(좌표를 안 박는다) — 안 그러면 문을 옮기는 순간 길이 엉뚱한 변에 깔리는데
##  **에러가 0이고 화면만 거짓말한다.**
## 🔴 **한 칸 더 나가는 것**도 계약이다 — 마지막 칸에서 멈추면 그 칸이 「풀로 막힌 끝」이 돼 길이 끊겨 보인다.
func _edge_cell_beyond(at: Vector2, rect: Rect2, ts: Vector2i) -> Vector2i:
	var d_left := at.x - rect.position.x
	var d_right := rect.end.x - at.x
	var d_top := at.y - rect.position.y
	var d_bottom := rect.end.y - at.y
	var best := minf(minf(d_left, d_right), minf(d_top, d_bottom))
	var outside := at
	if is_equal_approx(best, d_top):
		outside.y = rect.position.y - float(ts.y)
	elif is_equal_approx(best, d_bottom):
		outside.y = rect.end.y + float(ts.y)
	elif is_equal_approx(best, d_left):
		outside.x = rect.position.x - float(ts.x)
	else:
		outside.x = rect.end.x + float(ts.x)
	return Vector2i(floori(outside.x / float(ts.x)), floori(outside.y / float(ts.y)))


## **들어가는 길 — 입구에서 지점까지.**
## 🔴 **길이 없으면 지점은 없는 것과 같다** — 방이 열린 숲이라 「저쪽에 뭔가 있다」를 알려 주는 건
##  바닥 그림뿐이다.
## 🔴🔴 **인자 순서가 길의 모양을 정한다 — `(지점, 입구)`다.** `_road_between`이 `(b.x, a.y)`에서
##  꺾으므로 이 순서라야 「입구에서 북쪽으로 곧게 들어가다가 지점 쪽으로 꺾인다」가 된다. 뒤집으면
##  먼저 남쪽 가장자리를 따라 가로로 달려 방 아래쪽이 통째로 흙 밭이 된다(에러 0 · 화면만 망가진다).
## 🔴 시작점은 **플레이어 스폰 노드**다 — 좌표를 여기 적으면 스폰을 옮길 때 길만 제자리에 남는다.
func _landmark_road_cells(half: int, ts: Vector2i, out: Dictionary) -> void:
	if _landmarks.is_empty():
		return
	var entrance := Vector2i(floori(_player.position.x / float(ts.x)),
		floori(_player.position.y / float(ts.y)))
	for node: Node2D in _landmarks:
		if node == null or not is_instance_valid(node):
			continue
		var cell := Vector2i(floori(node.position.x / float(ts.x)), floori(node.position.y / float(ts.y)))
		_road_between(cell, entrance, half, out)


## **임의의 두 칸을 흙길로 잇는다** — 가로 다리 → 세로 다리(ㄱ자), 폭 `half * 2 + 1`.
## ⚠ 경로탐색은 아니다 — 장애물을 안 본다(방이 열린 숲이라 필요가 없다).
## ⚠ 폭은 **한 줄기 안에서 일정해야 한다** — 시트의 9분할 칸과 오솔길 칸은 변의 풀 두께가 달라
##  (실측 12px ↔ 24px) 한 줄기에 섞으면 이음매가 어긋난다.
func _road_between(a: Vector2i, b: Vector2i, half: int, out: Dictionary) -> void:
	var corner := Vector2i(b.x, a.y)
	var drew := false
	if corner != a:
		_road_segment(a, corner, half, out)
		drew = true
	if corner != b:
		_road_segment(corner, b, half, out)
		drew = true
	if not drew:
		# 두 끝이 같은 칸 — 다리가 없으니 폭만 한 덩어리로 남긴다.
		for y in range(b.y - half, b.y + half + 1):
			for x in range(b.x - half, b.x + half + 1):
				out[Vector2i(x, y)] = true


## 다리 한 토막 — 🔴 **진행 방향과 직각으로만** `half`만큼 넓힌다. 양쪽으로 넓히면 꺾이지 않는
## 길에도 시작·끝에 혹이 붙는다.
func _road_segment(a: Vector2i, b: Vector2i, half: int, out: Dictionary) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	if a.y == b.y:
		y0 -= half
		y1 += half
	else:
		x0 -= half
		x1 += half
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out[Vector2i(x, y)] = true


## 흙길 한 칸의 아틀라스 좌표 — **이웃이 고른다**(9분할 오토타일).
## `cons` = 흙이 **아닌** 변 · `nub` = 두 변은 흙인데 그 사이 대각이 풀인 모서리(= 길이 ㄱ자로 꺾일 때 안쪽).
## ⚠ cons와 nub가 같이 있으면 **cons가 이긴다** — 시트가 그 조합을 안 들어서 안쪽 모서리가 살짝
##  각져 보일 뿐 깨지지는 않는다.
func _road_atlas(cell: Vector2i, road: Dictionary) -> Vector2i:
	var cons := 0
	if not road.has(cell + Vector2i(0, -1)):
		cons |= DIR_T
	if not road.has(cell + Vector2i(0, 1)):
		cons |= DIR_B
	if not road.has(cell + Vector2i(-1, 0)):
		cons |= DIR_L
	if not road.has(cell + Vector2i(1, 0)):
		cons |= DIR_R
	if not _road_is_thick(cell, road):
		# 폭 1칸 오솔길 — 「어느 쪽으로 이어지나」로 고른다(9분할과 키의 뜻이 반대다).
		return _road_narrow_atlas((~cons) & 15, cell)
	if cons != 0:
		return _road_edge_atlas(cons, cell)
	var nub := _road_nub(cell, road)
	if nub != 0:
		return ROAD_NUB[nub]
	return _road_center_atlas(cell)


## 이 칸이 **폭 2칸 이상**인가 — 자기를 품는 2×2 흙 덩어리가 하나라도 있으면 그렇다.
## 넓은 길(9분할)과 오솔길은 변의 풀 두께가 달라 **한 칸이라도 잘못 고르면 이음매가 튄다.**
func _road_is_thick(cell: Vector2i, road: Dictionary) -> bool:
	for oy in [-1, 0]:
		for ox in [-1, 0]:
			if road.has(cell + Vector2i(ox, oy)) and road.has(cell + Vector2i(ox + 1, oy)) \
				and road.has(cell + Vector2i(ox, oy + 1)) and road.has(cell + Vector2i(ox + 1, oy + 1)):
				return true
	return false


## 안쪽 모서리 비트 — 없으면 0. 🔴 **`cons == 0`일 때만 불러라** — 「두 변이 다 흙」이 nub의 전제인데
## 그 검사를 여기서 다시 안 한다.
## ⚠ 둘 이상이면 **먼저 찾은 것**을 쓴다(3칸 폭 길에선 한 번에 하나만 생긴다).
func _road_nub(cell: Vector2i, road: Dictionary) -> int:
	for pair: Array in [[DIR_T | DIR_L, Vector2i(-1, -1)], [DIR_T | DIR_R, Vector2i(1, -1)],
		[DIR_B | DIR_L, Vector2i(-1, 1)], [DIR_B | DIR_R, Vector2i(1, 1)]]:
		if not road.has(cell + (pair[1] as Vector2i)):
			return pair[0]
	return 0


## 변 칸 — 상·하변만 A/B를 번갈아 깐다(좌·우변은 시트에 한 판뿐이다).
func _road_edge_atlas(cons: int, cell: Vector2i) -> Vector2i:
	if cons == DIR_T and _cell_hash(cell, 11) < 50:
		return ROAD_TOP_B
	if cons == DIR_B and _cell_hash(cell, 11) < 50:
		return ROAD_BOTTOM_B
	return ROAD_EDGE.get(cons, ROAD_EDGE[0])


## 길 한복판 — **잔풀 난 흙을 섞는 게 이 칸의 핵심**이다(가장 많이 반복되는 면이라 여기가
## 단조로우면 길 전체가 벽지가 된다).
func _road_center_atlas(cell: Vector2i) -> Vector2i:
	var h := _cell_hash(cell, 3)
	if h < 8:
		return ROAD_GRAVEL
	if h < 38:
		return ROAD_WEEDY
	if h < 65:
		return ROAD_CENTER_B
	return ROAD_EDGE[0]


func _road_narrow_atlas(conn: int, cell: Vector2i) -> Vector2i:
	if conn == (DIR_T | DIR_B) and _cell_hash(cell, 11) < 50:
		return ROAD_NARROW_VERT_B
	if conn == (DIR_L | DIR_R) and _cell_hash(cell, 11) < 50:
		return ROAD_NARROW_HORZ_B
	return ROAD_NARROW.get(conn, ROAD_NARROW[0])


## 벌판 한 칸 — 풀 변형 셋(볕에 마른 ~25% · 새순 ~8%).
func _grass_atlas(cell: Vector2i) -> Vector2i:
	var h := _cell_hash(cell, 0)
	if h < 8:
		return GRASS_SPROUT
	if h < 33:
		return GRASS_SUN
	return GRASS_PLAIN


## 칸 좌표 → 0~99. 🔴 **규칙적이면 안 된다** — 모듈로로 고르면 무늬가 주기로 반복돼 벌판이 벽지가 된다.
## `salt`로 굴림을 갈라 둔다 — 같은 값을 쓰면 풀 변형과 길 변형이 **같은 자리에서 같이 튀어** 눈에 띈다.
## 🔴 `_room_index`가 salt에 섞여 방마다 숲이 갈리면서도 **결정성은 그대로 산다**(같은 방 번호는
##  늘 같은 배치다 — `randf`가 아니라 여전히 해시다).
func _cell_hash(cell: Vector2i, salt: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)
		^ ((salt + _room_index * 61) * 83492791)) % 100


## 보스 스폰 — 두 경로: `boss_scene_path`가 있으면 그 전용 씬, 비면 `forest_enemy.tscn` 범용 스폰.
## 🔴 **`add_child` 전에 `enemy_id` 대입** — `_ready`가 이 id로 .tres를 물기 때문에 순서가 계약이다.
## 🔴 반환 = **계속 진행해도 되는가.** 실패하면 호출부가 나머지(잡몹·목표 안내)를 건너뛰어야 한다.
## ⚠ **보스 노드를 필드로 들지 않는다** — 아무도 안 읽는 필드는 거짓 손잡이가 된다.
##  보스를 찾아야 하면 그룹 `"enemies"` + `enemy_id`로 집어라.
func _spawn_boss() -> bool:
	var boss: Node2D = null
	if _chapter.boss_scene_path != "":
		var packed := load(_chapter.boss_scene_path) as PackedScene
		if packed == null:
			push_error("boss_room: boss_scene_path '%s'를 못 읽었다 — 베이스로 되돌아간다"
				% _chapter.boss_scene_path)
			_leaving = true
			_to_base.call_deferred()
			return false
		boss = packed.instantiate() as Node2D
	else:
		var enemy := EnemyScene.instantiate() as Node2D
		enemy.set(&"enemy_id", _chapter.boss_enemy_id)
		boss = enemy
	# 🔴 위치도 add_child **앞**이 계약이다 — snake_body가 `_ready`에서 부모의 그 시점 위치로 자취를
	# 프리시드하므로, 뒤에 옮기면 입장 첫 프레임에 마디가 원점 → boss_spawn으로 끌려간다.
	boss.position = _chapter.boss_spawn
	add_child(boss)
	return true


## 잡몹을 깐다 — **자리는 고정, 정체만 굴린다.** 좌표는 언제나 `MobSpawn.position` 그대로고
## `pool_tag`가 비면 `enemy_id`가 그대로 선다.
## 🔴 후보가 0이면 그 자리가 **빈 채로 서고 에러가 0이라** `push_warning`으로 짖는다.
##  ⚠ 태그당 한 번만 짖는다 — 자리 9곳이 같은 태그를 가리키면 같은 경고가 9줄 나와 로그가 죽는다.
func _spawn_mobs() -> void:
	var warned := {}
	for spawn: MobSpawn in _chapter.mob_spawns:
		if spawn == null:
			continue
		var id := spawn.enemy_id
		if spawn.pool_tag != &"":
			id = _roll_pool_id(spawn.pool_tag)
			if id == &"" and not warned.has(spawn.pool_tag):
				warned[spawn.pool_tag] = true
				push_warning("boss_room: %s의 mob_pool에 태그 '%s' 후보가 없다 — 그 자리들이 빈 채로 선다"
					% [String(_chapter.id), String(spawn.pool_tag)])
		_spawn_enemy_at(id, spawn.position)


## `pool_tag`가 같은 `MobWeight`를 **weight 비례**로 하나 뽑는다. 후보가 없으면 `&""`.
## 🔴 **`weight <= 0`은 안 뽑는다** — 「임시로 빼려면 지우지 말고 0으로」가 `MobWeight.weight`의
##  약속이라, 안 지키면 거짓 손잡이가 되고 빼 둔 적이 그대로 나온다.
## ⚠ **시드를 고정하지 마라** — 이 리포의 랜덤은 전역 스트림 하나뿐이라 테스트가 `seed()`를 잡으면
##  드롭 굴림 등이 **같은 스트림을 소비**해 flake가 된다. 그물은 **확률·가중치의 양끝을 주입해** 잰다.
func _roll_pool_id(tag: StringName) -> StringName:
	var ids: Array[StringName] = []
	var weights: Array[int] = []
	var total := 0
	for mw: MobWeight in _chapter.mob_pool:
		if mw == null or mw.pool_tag != tag or mw.enemy_id == &"":
			continue
		if mw.weight <= 0:   # 0 이하 = 「지금은 빼 둔다」 (지우지 않고 끄는 손잡이)
			continue
		ids.append(mw.enemy_id)
		weights.append(mw.weight)
		total += mw.weight
	if total <= 0:
		return &""
	var pick := randi_range(1, total)
	for i in ids.size():
		pick -= weights[i]
		if pick <= 0:
			return ids[i]
	return ids[ids.size() - 1]   # 부동소수 없는 정수 누적이라 도달할 일이 없다 — 방어선


## 네임드 — `named_pool`의 **각 항목을 독립으로** 굴린다. **「하나도 안 뜸」이 정상 결과다**
##  (그게 「오늘 뭔가 있다」를 만든다).
## 🔴 **표시는 생김새다(덩치·전용 스프라이트) — 빛나게 하지 마라.** 오라·HUD 알림·입장 문구는 각하됐다.
## 🔴 **우두머리는 잠금이 아니다** — 「잡아야 열린다」를 만들지 마라(낱개를 줍는 시간 때문에
##  *"먼저 치우고 여는 편이 낫다"*는 저절로 생긴다).
## 🔴🔴 **`at_landmark`는 자리마다 따로 굴린다 — 「하나 굴려 전부에 세우기」가 아니다.** 한 번만
##  굴리면 같은 지점 2채의 우두머리 유무가 늘 붙어 다녀 **자리별 긴장이 죽는다.**
## 🔴 **미등록 id는 에러로 승격한다** — 자리를 못 찾으면 원점에 서거나 통째로 안 서는데, 둘 다
##  화면에서 「오늘은 네임드가 안 떴네」로 읽힌다.
func _spawn_named() -> void:
	for named: NamedSpawn in _chapter.named_pool:
		if named == null or named.enemy_id == &"":
			continue
		if named.at_landmark == &"":
			# `randf()`는 [0,1) — chance 0.0이면 절대 안 뜨고 1.0이면 반드시 뜬다(양끝이 그물의 손잡이).
			if randf() >= named.chance:
				continue
			_spawn_enemy_at(named.enemy_id, named.position)
			continue
		var sites := _landmark_sites(named.at_landmark)
		if sites.is_empty():
			push_error("boss_room: 네임드 '%s'의 at_landmark('%s')가 이 판에 선 지점에 없다 — 아무 데도 안 선다 (설계 §10-4 S22)"
				% [String(named.enemy_id), String(named.at_landmark)])
			continue
		for at: Vector2 in sites:
			if randf() >= named.chance:
				continue
			_spawn_enemy_at(named.enemy_id, at)


## 🔴🔴 적 하나를 세운다 — **잡몹·네임드가 지나는 유일한 문**이고 **보스 id 제외 가드가 여기 한 줄**이다.
##  클리어 판정이 `enemy_id` 일치 한 줄이라, 풀·네임드에 `boss_enemy_id`가 섞이면 **잡몹 한 마리를
##  잡았을 뿐인데 챕터 클리어 + 보상 룬이 조용히 나간다(에러 0).**
## 🔴 가드를 굴림 함수 쪽에 두지 않은 이유 = 문이 둘이면 가드도 둘이 되고 한쪽만 지워도 다른 쪽이
##  그린이라 뮤테이션이 안 걸린다. 여기 한 줄을 지우면 **두 경로가 같이 빨개진다.**
## 🔴 `enemy_id`·위치 대입은 `add_child` **앞**이 계약이다(`_ready`가 그 id로 .tres를 문다).
func _spawn_enemy_at(id: StringName, at: Vector2) -> bool:
	if id == &"":
		return false
	if _is_boss_id(id):
		push_warning("boss_room: 잡몹/네임드 자리에 보스 id('%s')가 들어왔다 — 세우지 않는다 (설계 §6 S9)"
			% String(id))
		return false
	var mob := EnemyScene.instantiate() as Node2D
	mob.set(&"enemy_id", id)
	mob.position = at
	add_child(mob)
	return true


## 클리어를 여는 id인가 — `_on_enemy_died`의 판정식과 **같은 비교**를 쓴다(사본이 아니라 파생).
func _is_boss_id(id: StringName) -> bool:
	return _chapter != null and id == _chapter.boss_enemy_id


## **적이 죽었다 — 여기서 판정이 둘로 갈린다.**
##  **챕터 클리어** = `enemy_id == boss_enemy_id`, 가드 `_chapter_cleared`(판 1회) → codex·보상 룬
##  **방 클리어** = 살아 있는 적이 0, 가드 `_cleared`(방마다) → 상자·문
##
## 🔴 **둘을 한 조건으로 합치지 마라.** 마지막 방은 보스를 안 세우므로 방 클리어를 보스로 못 재고,
##  반대로 방 클리어로 챕터 보상을 주면 **잡몹만 있는 방을 치워도 룬이 나간다**(에러 0).
func _on_enemy_died(enemy_id: StringName) -> void:
	if _chapter == null:
		return
	# 🔴🔴 **지연이 계약이다 — 두 이유가 겹친다**(둘 다 에러 0):
	#  ⓐ **죽는 그 몸은 아직 안 지워졌다** — `_die`가 `enemy_died`를 `queue_free()` 앞에서 쏘므로,
	#     바로 세면 마지막 한 마리가 자기 자신 때문에 늘 1로 잡혀 클리어가 영영 안 열린다.
	#  ⓑ 여기까지 오는 길이 **물리 flush 한복판**이라 `add_child`가 엔진을 짖게 한다 — 그 에러는
	#     `ERROR:`지 `SCRIPT ERROR:`가 아니라 테스트 러너를 그대로 통과한다.
	_check_room_cleared.call_deferred()
	if _chapter_cleared or enemy_id != _chapter.boss_enemy_id:
		return
	_chapter_cleared = true
	var clear_id := Db.chapter_clear_id(_chapter)
	# ⚠ 재방문이면 codex가 이미 있다 — 다시 쏘면 UNLOCK 퀘스트·해금음이 중복 반응하므로 첫 클리어에만.
	if not GameState.is_unlocked(clear_id):
		EventBus.codex_unlocked.emit(clear_id)
	# 클리어 보상은 `clear_id`와 **별도 축**이다(clear_id는 챕터 게이트, reward_unlock은 획득물).
	# `codex_unlocked` 한 발로 codex 심기 + 해금음 + UNLOCK 퀘스트 진행이 전부 따라온다.
	var reward_line := ""
	if _chapter.reward_unlock != &"" and not GameState.is_unlocked(_chapter.reward_unlock):
		EventBus.codex_unlocked.emit(_chapter.reward_unlock)
		# 🔴 문구는 `CodexText`가 낸다 — 룬·진·고리마다 「어디에 쓰는지」가 다르고(중심·바탕·밴드)
		# 발신처가 셋이라, 여기서 조회를 조립하면 그게 곧 사본이다.
		var reward_label := CodexText.label_of(_chapter.reward_unlock)
		if reward_label != "":
			reward_line = " 보상: %s" % reward_label
	# 🔴 `sticky`라 **없는 조작을 적으면 그대로 거짓 지시가 된다** — 보스 처치가 여는 것은 챕터
	# codex와 보상뿐이고, 다음에 할 일(방을 마저 비운다)은 `_on_room_cleared`가 낸다.
	_hud.say("%s 클리어!%s" % [_chapter.title, reward_line], false, true)


## **방 클리어 판정 = 살아 있는 적이 0.**
## 🔴 **`_live_enemies()`를 거치는 것이 계약이다** — 죽은 그 몸이 아직 그룹에 있어서 그냥 세면
##  **영영 0이 안 된다**(그 함수 머리말 참조).
## 🔴 **이 함수는 `call_deferred`로만 불러라**(호출부가 이유 둘을 적어 뒀다).
##  ⚠ 그래서 여기선 `_on_room_cleared`를 직접 부른다 — 이미 지연 문맥이라 한 번 더 미룰 이유가 없다.
func _check_room_cleared() -> void:
	if _cleared or _leaving:
		return
	if _live_enemies() > 0:
		return
	_cleared = true
	_on_room_cleared()


## 방이 깨졌다 — 상자와 문이 여기서 선다. 이미 지연 문맥이다.
func _on_room_cleared() -> void:
	_spawn_reward_chest()
	_spawn_doors()
	# 🔴 **안내를 갈아 끼운다 — 안 하면 앞의 sticky가 거짓 지시로 남는다.** 방을 깬 지금 할 일은
	#  문을 고르는 것이고, **그물이 아니라 눈이 잡는 자리**다.
	#  ⚠ `_on_enemy_died`의 챕터 클리어 줄보다 뒤에 온다(그쪽은 동기, 이쪽은 지연) — 그래서 이긴다.
	if _is_last_room():
		_hud.say("마지막 방을 비웠다 — 상자를 열고 문으로 마을에 돌아가라", false, true)
	else:
		_hud.say("방을 비웠다 — 상자를 열고 문을 골라 들어가라", false, true)


## **문이 설 자리** — 북쪽 벽 안쪽에 `DOOR_COUNT`개를 고르게.
## 🔴 **좌표를 하나도 안 박는다** — `Ground` rect에서 파생하므로 방을 줄이면 문이 따라온다.
## **북쪽인 이유**: 입구가 남쪽이라 「들어왔던 쪽이 아닌 데로 나간다」가 이동으로 읽힌다.
##  ⚠ 문을 **서로 다르게 생기게 하지 마라** — 「같은 문 3개」로 읽혀야 글자가 정보를 진다.
## 🔴 **방마다 x를 흔든다** — 안 흔들면 방을 넘어도 똑같은 그림이라 「새 방」이 안 읽힌다.
## 🔴 **문과 길이 이 함수 하나에서 파생한다** — 길은 입장 때, 문은 클리어 때 서는데 자리를 두 번
##  계산하면 **길만 엉뚱한 데 깔리고 에러가 0이다.**
func _door_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var rect := Rect2(_ground.position, _ground.size)
	var y := rect.position.y + DOOR_INSET
	for i in DOOR_COUNT:
		var t := float(i + 1) / float(DOOR_COUNT + 1)
		# `_cell_hash`는 0~99를 준다 — −1..+1로 옮겨 흔든다(방 번호가 salt에 이미 들어 있다).
		var jitter := (float(_cell_hash(Vector2i(i, 0), 29)) / 50.0 - 1.0) * DOOR_JITTER
		out.append(Vector2(rect.position.x + rect.size.x * t + jitter, y))
	return out


## **문을 세운다 — 방이 깨진 뒤에만.**
## `door.tscn`은 `interact_zone.gd`를 그대로 쓴다 — 문을 가르는 것은 씬이 아니라 **여기서 무는 보상**이다.
## 🔴 **미리보기 문구는 데이터에서 온다**(`LandmarkDef.title`) — 문 씬에 박으면 데이터가 바뀔 때 거짓말이 된다.
##  ⚠ 그 글자가 **늘 보여야** 고르는 근거가 된다(`Prompt`는 다가가야 뜬다).
## 그룹을 안 붙여도 `_teardown_room`이 헌다 — `owner` 가드가 「코드가 만든 것」을 잡고 문의
##  `interact_zone.gd`가 자기를 `interact_zones`에 넣기 때문이다.
func _spawn_doors() -> void:
	var packed := load(DOOR_SCENE) as PackedScene
	if packed == null:
		push_error("boss_room: 문 씬 '%s'를 못 읽었다 — 다음 방으로 못 간다" % DOOR_SCENE)
		return
	var spots := _door_spots()
	# 🔴 **마지막 방이면 문이 하나고 그 문이 판을 끝낸다.** 자리는 가운데 문 자리를 그대로 쓴다
	#  (따로 좌표를 만들지 않는다 — 길도 이미 거기 깔려 있다).
	if _is_last_room():
		var back := _make_door(packed, spots[spots.size() / 2], RETURN_DOOR_LABEL, _extract)
		if back == null:
			push_error("boss_room: 마지막 방인데 귀환 문을 못 세웠다 — 판이 안 끝난다")
		return
	var pool := _reward_pool()
	if pool.is_empty():
		# 침묵 금지 — 문이 안 서면 **방을 깨도 다음 방으로 갈 길이 없고 화면은 멀쩡하다.**
		push_error("boss_room: 쓸 수 있는 상자 종류가 하나도 없다 — 문이 안 서서 다음 방으로 못 간다")
		return
	for i in spots.size():
		var reward: StringName = pool[i % pool.size()]
		var def := Db.get_landmark(reward)
		var title := def.title if def != null and def.title != "" else String(reward)
		_make_door(packed, spots[i], title, _on_door_taken.bind(reward))


## 문 하나 — **자리·글자·배선만 다르고 나머지는 같다**(마지막 방의 귀환 문도 이걸 쓴다).
##  나누면 「보통 문은 되는데 귀환 문만 안 헐린다」 같은 자리가 생긴다.
func _make_door(packed: PackedScene, at: Vector2, label_text: String, on_taken: Callable) -> Node2D:
	var door := packed.instantiate() as Node2D
	if door == null:
		return null
	# 위치는 `add_child` 앞이다(지점·적·상자와 같은 계약).
	door.position = at
	var label := door.get_node_or_null(^"Reward") as Label
	if label != null:
		label.text = label_text
	add_child(door)
	if door.has_signal(&"interacted"):
		door.connect(&"interacted", on_taken)
	else:
		push_warning("boss_room: 문 씬에 `interacted`가 없다 — 눌러도 아무 일이 안 난다")
	return door


## 이 방이 판의 마지막인가 — `ROOM_COUNT` 하나에서 파생한다(개수를 두 곳에 적지 않는다).
func _is_last_room() -> bool:
	return _room_index + 1 >= ROOM_COUNT


## **문으로 들어갔다 — 다음 방을 같은 씬 안에 다시 세운다.**
## 🔴🔴 **씬을 갈아타지 마라** — `change_scene_to_file`은 새 `_ready`를 돌려 **방마다 만HP·만마나**가
##  되고(소모가 통째로 사라진다) 인자를 못 실어 GameState 신설이 붙는다. 게다가 방마다 씬 로드는
##  판당 5~6번 히치다.
## 🔴 **`call_deferred`다** — 여기서 방을 헐면 **지금 이 시그널을 쏜 문 자신을 free한다.**
## ⚠ `_leaving`은 **안 건드린다** — 판 수명이다(귀환·사망 이중 전환 가드).
func _on_door_taken(reward: StringName) -> void:
	if _leaving:
		return
	_enter_room.call_deferred(_room_index + 1, reward)


## **방 가운데에 보상 상자를 세운다.**
## 🔴 **자리는 `Ground` rect의 한복판이다 — 좌표를 안 박는다.** 씬의 `SunGlade`(볕뉘)가 같은 자리라
##  「저기가 무대다」가 공짜로 붙고, 방을 옮기면 빛과 상자가 같이 따라온다.
## 🔴 **새 씬을 안 만든다** — `chest.tscn`이 이미 그 기계다([E] 즉시 열기 · 재열기 가드 · 2컷 ·
##  `opened` 발신). 경로도 데이터에서 온다(`LandmarkDef.scene_path`).
## ⚠ **여기는 이미 지연 문맥이라** `add_child`가 물리 flush 밖이다. 물리 한복판에서 붙여도 노드는
##  정상으로 붙지만 엔진이 `ERROR: Can't change this state while flushing queries`를 찍고, 그 줄은
##  `SCRIPT ERROR:`가 아니라 테스트 러너를 통과한다 — **「노드가 안 붙는다」로는 못 잡는 자리다.**
func _spawn_reward_chest() -> void:
	var def := Db.get_landmark(_room_chest_id)
	if def == null or def.scene_path == "":
		# 침묵 금지 — 상자가 안 서면 방을 깨도 **보상이 통째로 없고 화면은 멀쩡하다.**
		push_error("boss_room: 보상 상자 '%s'를 Db.landmarks에서 못 찾았거나 scene_path가 비었다 — 방을 깨도 상자가 안 선다"
			% String(_room_chest_id))
		return
	var packed := load(def.scene_path) as PackedScene
	if packed == null:
		push_error("boss_room: 보상 상자 씬 '%s'를 못 읽었다" % def.scene_path)
		return
	var chest := packed.instantiate() as Node2D
	if chest == null:
		push_error("boss_room: 보상 상자 씬 루트가 Node2D가 아니다 — 자리를 못 잡아 안 세운다")
		return
	# 🔴 위치는 `add_child` **앞**이다(지점·적과 같은 계약 — 씬이 `_ready`에서 자기 자리를 쓴다).
	chest.position = _ground.position + _ground.size * 0.5
	chest.add_to_group(ROOM_REWARD_GROUP)
	add_child(chest)
	# ⚠ `has_signal` 가드 — 「새 상자 종류 = `.tres` 한 장」이라 남이 시그널 없는 씬을 꽂고,
	#  가드가 없으면 그 한 장이 방을 통째로 못 세운다.
	if chest.has_signal(&"opened"):
		chest.connect(&"opened", _on_reward_chest_opened)
	else:
		push_warning("boss_room: 보상 상자 씬에 `opened` 시그널이 없다 — 열어도 아무것도 안 나온다")


## **상자를 열었다 — 낱개를 안 뿌리고 바로 가방에 넣는다.**
## 🔴 **굴림은 `DropRoll.roll` 그대로**(단일 소스) — 상자가 자기 굴림을 새로 쓰면 `DropEntry`의
##  배타 짝 규칙이 두 벌이 되고 그게 조용히 갈라진다.
## 🔴 **지급도 `DropPickup.grant_one` 하나** — 「해금물이면 codex, 아이템이면 가방」을 여기 다시
##  적으면 그 순간 사본이고, 두루마리 해금이 상자 경로에서만 조용히 죽는다.
## ⚠ **낱개 스폰(`DropRoll.spawn_loose`)을 같이 부르지 마라** — 같은 드롭이 두 번 지급되고
##  두루마리는 **이중 해금**이 된다(에러 0).
func _on_reward_chest_opened() -> void:
	var def := Db.get_landmark(_room_chest_id)
	if def == null:
		return
	if def.drops.is_empty():
		# 데이터가 비면 열어도 아무 일이 안 나고 화면은 멀쩡하다 — 짖는다.
		push_warning("boss_room: 보상 상자 '%s'의 drops가 비었다 — 열어도 아무것도 안 나온다"
			% String(_room_chest_id))
		return
	for entry: Dictionary in DropRoll.roll(def.drops, GameState):
		DropPickup.grant_one(entry["id"], int(entry["count"]),
			entry.get("unlock", &""), GameState, EventBus)


## 귀환 성공 — `extraction_success`가 **가방(루팅분 포함)을 창고로 옮기고 자동 저장**한다.
## 🔴🔴 **`extraction_success`를 쏘는 유일한 자리다 — 지우지 마라.** 안 쏘면 가방→창고 이관·자동
##  저장·귀환 퀘스트가 **전부 조용히 멎는다.**
## 🔴 **부르는 곳은 `_wire_exit()`과 마지막 방의 귀환 문이다 — 새 길을 뚫으면 이리로 이어라.**
## ✅ 이중 전환 방어는 `_leaving` 가드가 이미 진다 — 길이 몇 개든 한 번으로 묶인다(새로 짜지 마라).
func _extract() -> void:
	if _leaving:
		return
	_leaving = true
	EventBus.extraction_success.emit()
	_to_base()


func _on_hp_changed(hp: float, _hp_max: float) -> void:
	if hp <= 0.0:
		_die()


## 쓰러졌다 — `bag_lost`가 가방을 비우고 자동 저장한다(세이브스컴 방지).
## 클리어 codex는 처치 순간 이미 심겼으므로 죽어도 다음 챕터는 열려 있다.
##
## 🔴 **사망 후 HP 복구를 쥐는 건 이 함수다** — HP는 오토로드가 쥐고 세이브에 없어서, 여기서 안
##  되돌리면 베이스로 걸어 나가는 몸이 HP 0인 채다(마을에 피해원이 생기는 날 즉사 버그가 된다).
##  ⚠ 베이스에 두면 「베이스를 거쳐 들어올 때만」 맞고 다른 진입 경로에선 조용히 달라진다.
## 🔴 복구는 **연출(DEATH_BEAT_SEC) 뒤**다 — 먼저 되돌리면 「쓰러졌다」를 띄운 채 HP 막대가 꽉 차
##  "안 죽었다"로 읽힌다. 그 emit이 `_on_hp_changed`를 다시 태우지만 `_leaving` 가드가 막는다.
func _die() -> void:
	if _leaving:
		return
	_leaving = true
	_player.caster.enabled = false
	_player.set_physics_process(false)
	_hud.say("쓰러졌다 — 베이스로 돌아온다", true)
	EventBus.bag_lost.emit()
	await get_tree().create_timer(DEATH_BEAT_SEC).timeout
	GameState.reset_player_hp()
	_to_base()


func _to_base() -> void:
	get_tree().change_scene_to_file(base_scene_path)


## 목표 하나를 달성했다 — 아직 완료 아님. 마을 **문**으로 돌아가 정산하라고 HUD로 민다.
## ⚠ `base.gd _on_quest_ready`와 **일부러 문구가 다르다** — 여긴 원정 중이라 「마을로 돌아가」가 붙고,
##  마을에선 이미 문 앞이라 안 붙는다.
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 마을로 돌아가 문에서 [E]로 정산하라 [?]" % q.title)
