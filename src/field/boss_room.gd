extends Node2D
## 챕터 보스방 (세58-B 세피리아식 메인 루프) — 옛 `forest.gd`의 원정 계약을 물려받은 축소판.
## ⚠ 아래에서 「forest.gd·forest.tscn 이관」으로 부르는 두 파일은 **세58-B에 삭제됐다**
## (찾지 마라 — 필요하면 git 이력). **원정 계약의 라이브 정본은 이 파일이다.**
##
## 루프: 베이스 숲길 [E] → 챕터 선택 → 이 방(보스 + 잡몹) → 처치 → 낱개 드롭 줍기 → 귀환 [E] → 베이스.
## ⚠ 「상자 루팅」 단계는 없다 — 상자는 세66에 은퇴했고 모든 적이 낱개로 떨군다(`forest_enemy._spawn_loose`).
## 죽으면 즉시 베이스 + 가방 손실(bag_lost). 어느 챕터인가는 `GameState.pending_chapter`가 나른다
## (change_scene_to_file이 인자를 못 실어 오토로드가 나른다 — in_expedition과 같은 결).
##
## 🔴🔴 **나가는 길은 「상시 출구」 한 종류뿐이다** (세99 D1·D7 — **포탈은 세99에 은퇴했다**).
##  • 전부 `zone_id = &"exit"`이고 전부 `_extract` **하나**로 간다. **처음부터 서 있고 조건이 없다.**
##  • 여럿 — `ChapterDef.extract_points`에 좌표를 적으면 그 자리에 `exit_zone.tscn`이 선다.
##    비면 씬의 남쪽 `$Exit` 하나 = **세98까지와 동일**(회귀 0).
##    🔴 **단수 참조를 되살리지 마라** — `_exits` 배열이 ⓐ `_extract` 연결 ⓑ `_fill_tiles` 풀길의
##    **공통 출처**다. 하나라도 빠지면 「E는 먹히는데 아무 일도 안 나고 가방이 조용히 증발」하거나
##    「나갈 데가 있는 줄 모른다」가 된다(설계 §6 S12).
##  • 홀드 — `InteractZone.hold_sec`은 **길이가 아니라 스위치**다(실제 초 = `balance.extract_hold_sec`).
##    켜는 자리는 `_wire_extract_zone` **한 곳**이다 — 연결과 홀드를 같이 걸어야 새 길을 뚫을 때
##    한쪽만 빠지지 않는다.
##
## 🔴 **은퇴한 것 = 보스 자리 「귀환 포탈」**(`zone_id = &"portal"` · `src/props/portal.tscn` 삭제).
##  사용자 확정(세99): *"보스죽으면 포탈 x"*. **왜 없앴나** — D1이 탈출구를 여럿으로 만들고 D7이
##  전부 꾹 눌러 나가게 했는데 **포탈만 「보스를 잡아야 열리는 특별한 물건」**으로 남아 규칙이 둘이
##  됐다. 지금은 **보스를 잡아도 살아서 출구까지 돌아가야 한다**(익스트랙션의 결).
##  🔴 **`&"portal"`을 되살리지 마라** — 그 값을 쥔 씬도·스폰하는 코드도·재는 그물도 전부 없앴다.
##  보스 자리에서 남쪽까지 되돌아가는 먼 길은 **`extract_points`에 보스 근처 좌표를 한 줄** 적어
##  덜어 준다(= 지름길도 그냥 「상시 출구」다. **데이터라 F5로 옮길 수 있다** — 코드가 아니다).
##
## 🔴 **한 씬 + ChapterDef 파라미터다** — 챕터별 씬 3장을 만들지 않는다(설계 확정). 방 구성이
## 동일(바닥·보스 하나·입구)하고 다른 건 데이터(보스·색)뿐이라, 씬을 늘리면 mouse_filter·z_index·
## 레이어 함정을 그 수만큼 다시 밟는다. "새 챕터 = data/chapters/*.tres 한 장"이 여기서 성립한다.
## ⚠ **세99: 위 「설계 확정」은 뒤집혔다** — 사용자가 챕터마다 무대를 따로 만들기로 정했고
##  (`docs/takbon-design/dungeon_structure_design.md` D8), 그 손잡이인 **`ChapterDef.room_scene_path`가
##  이미 들어와 있다**. 이 씬은 이제 **그 필드가 비었을 때의 기본값**이다.
##  🔴 위 문단이 경고한 함정(mouse_filter·z_index·레이어)은 **여전히 유효하다** — 그래서 새 맵은
##  **상속 씬**으로 만들어 이 씬의 노드 계약을 물려받는 것을 권한다(설계 §7 단계 4).
##
## 🔴🔴 **세99 D5·D6 — 무대는 고정, 서 있는 것은 매 판 굴러간다.**
##  • **몹 풀**(D5): `MobSpawn.pool_tag` → `ChapterDef.mob_pool`에서 **weight 비례**로 뽑는다.
##    🔴 **좌표는 절대 안 굴린다**(사용자 확정 *"지형은 동일하고 나오는 몬스터들이 랜덤"*) —
##    자리는 지형이 정하는 것이라 사람이 놓고, 바뀌는 건 「거기 뭐가 서 있나」뿐이다.
##    `pool_tag`가 비면 `enemy_id` 그대로 = **세98까지와 동일**(회귀 0).
##  • **네임드**(D6): `ChapterDef.named_pool`을 **항목마다 독립으로** 굴린다.
##    🔴 **「하나도 안 뜸」이 정상 결과다** — 그게 「오늘 뭔가 있다」를 만든다.
##    🔴 **표시는 생김새다(덩치·몸 색조) — 빛나게 하지 마라**(*"몸에서 빛이나는거 까진 별로임"*).
##    오라·HUD 알림·입장 문구는 **각하됐다.** `at_landmark` 해석은 단계 3 몫이라 지금은 안 선다.
##  🔴🔴 **잡몹·네임드는 `_spawn_enemy_at` 한 문을 지난다 — 거기 보스 id 제외 가드가 있다**(설계 §6 S9).
##   새 스폰 경로를 만들거든 **그 문을 지나게 해라.** 안 지나면 풀에 보스 id가 섞이는 날
##   **잡몹 한 마리로 `chapter_clear_*` + 보상 룬이 조용히 나간다(에러 0).**
##  🔴 **시드를 고정하지 마라** — 랜덤이 전역 스트림 하나뿐이라 테스트가 `seed()`를 잡으면 드롭 굴림 등과
##   스트림을 나눠 써 flake가 된다. 그물(`tests/test_mob_roll_auto.gd`)은 **확률·가중치 양끝을 주입**해 잰다.
##
## 🔴 **HP는 GameState가 쥔다** — 오토로드라 씬을 갈아타도 남는다 (forest.gd와 같은 이유).
## 출격 = 만HP/만마나는 **이 씬이 한다** (베이스가 아니다 — 다른 진입 경로로 들어가면 조용히 달라진다).
##
## 씬(boss_room.tscn) 쪽 결정 — .tscn엔 주석을 못 달아서 여기 적는다 (forest.tscn 주석 이관):
##  • 🔴 **`Ground.mouse_filter = 2`(IGNORE) — 지우면 발사가 통째로 죽는다.** Ground는 화면을
##    다 덮는 ColorRect인데 Control의 기본 mouse_filter는 STOP이라 바닥이 좌클릭을 전부 먹는다
##    → `_unhandled_input`에 안 와서 발사가 아예 안 불린다. **에러도 경고도 없고, 헤드리스로는
##    절대 못 잡는다** (세25 베이스·세26 숲이 정확히 이걸로 밟았다 — 새 씬마다 되살아나는 함정).
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(z=0) 뒤에 가려 안 보인다.
##  • 나무는 **물리 없는 장식**(tree.tscn) — StaticBody2D로 만들면 world 레이어라 캐리어(마스크 5)가
##    나무마다 터진다. ⚠ 그래서 충돌은 안 나지만 **적을 가린다** — 나무 20그루는 세 규칙으로 놓았다:
##    ⓐ 잡몹·보스 스폰(`ChapterDef.mob_spawns` + `boss_spawn`)에서 **100px 이상**
##    ⓑ 플레이어 스폰·남쪽 출구에서 **150px 이상**(시작 시야·[E] 찾기)
##    ⓒ 어귀·중간·깊은 대역에 고르게. 🔴 **정본은 `data/chapters/*.tres`의 `position`이다**(설계
##    문서 §13-2 표와 이미 갈라져 있다) — 옮길 땐 `scratch_dev_room.md` §5-ⓓ 스크립트로 재검산해라.
##  • 방 크기 **2400×2200**(x −1200~1200 · y −1500~700, 세88에 1200×1040에서 키웠다) — 세로로 긴
##    이유는 남쪽 입구(플레이어 스폰 y=+600)에서 북쪽 보스(y=−1350)까지 「깊이 들어간다」가 이동으로
##    읽히게. 구역(어귀·중간·깊은)은 **코드 개념이 아니라 `mob_spawns` y좌표 관례**다 — 새 스키마 0.
##  • 횃불 8개(x=∓500 · y ∈ {+450,−150,−750,−1300}) + BossGlow(0,−1350). 4개로는 4.4배 방의
##    3/4이 어둡다.
##
## 🔴 바닥 타일은 `_ready`가 코드로 깐다 — .tscn에 tile_map_data 베이스64를 손으로 굳히면
## 방 크기를 바꿀 때마다 에디터로 다시 칠해야 한다. Ground rect에서 셀 범위를 파생시켜 늘 맞는다.

const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 범용 보스 스폰 몸 — ChapterDef.boss_scene_path가 비면 이 씬 + enemy_id로 스폰한다.
## preload가 안전한 이유: forest_enemy는 boss_room을 안 문다 (base⇄forest 순환 함정 무관).
const EnemyScene := preload("res://src/field/forest_enemy.tscn")
## 🔴 늘린 탈출구 (세99 D1) — **`zone_id = &"exit"`을 파일에 굳힌 전용 프롭**이다.
## ⚠ 겉모습은 없다(씬의 `$Exit`와 같은 결) — **보이는 표시는 `_fill_tiles`의 풀길이 전부**다.
##  좌표만 늘리고 풀길을 안 깔면 플레이어는 「거기 나갈 데가 있다」를 알 방법이 없다(설계 §6 S12).
const ExitZoneScene := preload("res://src/props/exit_zone.tscn")
## 🔴 codex 해금 id → 「이름(어디에 쓰는지)」 단일 소스 (세87 S4). 여기서 `Db.get_glyph_ring` 하나만
## 부르면 **룬 보상이 원시 id + 거짓 안내**("rune_water(책상에서 밴드에 끼워라)")로 나간다 —
## 밴드는 고리 자리고 룬은 중심 자리다. 발신처가 셋(클리어·제작·두루마리)이라 core에 뽑혀 있다.
const CodexText := preload("res://src/core/codex_text.gd")

## 돌아갈 곳 — 🔴 **PackedScene이 아니라 경로다. 바꾸지 마라.** base가 boss_room을 경로로 물고
## boss_room이 base를 PackedScene으로 물면 **순환 preload**로 한쪽이 노드 0개 껍데기가 돼
## 귀환·사망 시 베이스로 못 돌아간다 (세26 forest가 실측 — 헤드리스는 못 잡고 실게임 부팅에서만 드러난다).
@export_file("*.tscn") var base_scene_path: String = "res://src/base/base.tscn"

## 쓰러진 뒤 베이스로 돌아가기까지 (초) — 연출값. 0이면 뭘 맞고 죽었는지 못 보고 화면이 바뀐다.
const DEATH_BEAT_SEC := 0.9

## 타일 소스 (assets/sprites/field/tileset_forest.tres): 0 = 풀(마을 쪽), 1 = 보스방 어두운 바닥.
const TILE_SRC_GRASS := 0
const TILE_SRC_FLOOR := 1
## 남쪽 출구로 이어지는 풀길 (칸 수 — 연출값). 어두운 숲 바닥에 마을 쪽 풀 타일을 깔아 **걸어가 보기
## 전에도** "저기가 나가는 길"로 읽히게 한다(출구 자체는 겉모습이 없는 InteractZone이다 — 보라색
## 차원문 Polygon2D를 베끼지 않기로 한 결정). 🔴 **길의 중심 x는 `Exit` 노드에서 파생한다** — 좌표를
## 두 번 적으면 출구를 옮길 때 길만 제자리에 남는다. 끄려면 `EXIT_PATH_ROWS = 0`.
const EXIT_PATH_WIDTH_CELLS := 3
const EXIT_PATH_ROWS := 3

## 🔴 D7 — 탈출 지점의 홀드를 **켜는** 값. `InteractZone.hold_sec`은 「몇 초」가 아니라
## 「0이냐 아니냐」 스위치라(실제 초 = `balance.extract_hold_sec`) 맨숫자 `1.0`을 씬·코드에 흩뿌리면
## 다음 사람이 **1초로 읽는다.** 이름을 붙여 그 오독을 막는다.
const HOLD_ON := 1.0

@onready var _ground: ColorRect = $Ground
@onready var _tiles: TileMapLayer = $TileGround
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud

var _chapter: ChapterDef = null
## 🔴 **나가는 길 전부**(세88 하나 → 세99 여럿). 씬의 남쪽 `$Exit` + `ChapterDef.extract_points`.
## **`_extract` 연결과 `_fill_tiles` 풀길이 둘 다 이 배열을 순회한다** — 단수 참조로 되돌리지 마라.
## ✅ 세99에 포탈이 은퇴해 **이 배열이 방의 탈출구 전량**이다(예외로 빠지는 길이 하나도 없다).
var _exits: Array[InteractZone] = []
## 클리어 처리는 한 번뿐 — enemy_died는 EventBus 전역이라 가드 없이는 무엇이든 두 번 처리될 수 있다.
var _cleared: bool = false
## 씬 전환은 한 번뿐 — 귀환 도중 죽거나, 죽는 중에 E를 누르면 두 번 갈아탄다 (forest 계약 이관).
var _leaving: bool = false


func _ready() -> void:
	# 🔴 출격 = 만HP/만마나 (forest.gd 계약 이관). 이게 없으면 죽는 게 이득이 된다 —
	# 다친 몸으로 출구까지 버티느니 그 자리에서 죽는 편이 싸진다.
	GameState.reset_player_hp()
	GameState.restore_mana_full()
	GameState.in_expedition = true
	# 🔴 모달 플래그를 내린다 — 오토로드라 씬 전환에도 남는다 (base.gd _ready와 같은 안전망).
	GameState.ui_modal_open = false
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# ⚠ 출구 세우기·연결은 **챕터를 안 뒤**다(`extract_points`를 읽어야 한다) — 아래 `_build_exits`.
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.enemy_died.connect(_on_enemy_died)
	# 목표 달성 넛지 (세40 턴인 — forest 선례): 완료가 아니라 정산 대기라 quest_ready를 듣는다.
	EventBus.quest_ready.connect(_on_quest_ready)

	# 🔴 어느 챕터인가 — 비었거나 미등록이면 **조용히 빈 방을 띄우지 않는다** (침묵 금지).
	# F6으로 이 씬을 직접 실행하면 pending_chapter가 비어 여기로 온다 — 베이스로 되돌린다.
	_chapter = Db.get_chapter(GameState.pending_chapter)
	if _chapter == null:
		push_error("boss_room: pending_chapter '%s'가 Db.chapters에 없다 — 베이스로 되돌아간다"
			% String(GameState.pending_chapter))
		_leaving = true
		_to_base.call_deferred()
		return

	_ground.color = _chapter.room_ground_color
	# 🔴 **`_fill_tiles`보다 먼저다** — 풀길이 `_exits`에서 파생하므로, 순서가 뒤바뀌면 늘린 출구가
	# 화면에 **아무 표시 없이** 서고 D1이 통째로 무효가 된다(설계 §6 S12). 에러는 0이다.
	_build_exits()
	_fill_tiles()
	_clamp_camera_to_room()
	# 🔴 스폰이 실패하면 **여기서 멈춘다** — `_spawn_boss` 안의 `return`은 자기 함수만 벗어나므로,
	# 예전엔 이미 떠나기로 한 방(`_leaving = true`)이 잡몹을 깔고 「…를 쓰러뜨려라」를 한 프레임
	# 띄웠다(세84 감사 #38). 챕터-null 분기(위)는 return이 `_ready` 자신이라 원래부터 제대로 멈춘다.
	if not _spawn_boss():
		return
	_spawn_mobs()
	# 🔴 네임드는 **잡몹 뒤**다 — 보스·잡몹이 다 선 뒤라야 「이 판에 얹힌 것」이라는 순서가 읽히고,
	#  그물도 「보스1 + 잡몹N + 네임드0~M」이라는 같은 순서로 개수를 잰다(test_chapter_auto).
	_spawn_named()
	var boss_def := Db.get_enemy(_chapter.boss_enemy_id)
	var boss_name := boss_def.display_name if boss_def != null else String(_chapter.boss_enemy_id)
	# 🔴 세84 #36: `sticky` — **방의 목표 줄이다**. say()에 수명이 붙었으므로(경고가 목표를 덮고
	# 영구 상주하던 걸 고쳤다) 여기 안 붙이면 목표가 4.5초 뒤 조용히 사라진다.
	# 🔴🔴 세99(D2): 옛 줄은 *"«보스»를 쓰러뜨려라"*였는데 **확정은 「탈출이 목표 · 보스는 선택」**이다
	#   — 방의 **유일한 안내**가 거짓 지시로 남아 있었고 재는 그물이 없었다(설계 §6 S13).
	#   sticky는 **「유효한 지시만」**이 계약이라 이 줄이 곧 계약 위반이었다.
	# ⚠ **두 문장이 같이 읽혀야 한다** — 챕터 잠금은 여전히 `chapter_clear_*`를 요구하므로
	#   「보스는 선택」만 적으면 *"그럼 왜 잡나"*가 되고, 「잡아라」만 적으면 D2가 죽는다.
	_hud.say("%s — 살아서 나가면 이긴다. 출구에서 [E] 꾹. %s는 선택이지만 잡아야 다음 챕터가 열린다"
		% [_chapter.title, boss_name], false, true)


## 🔴🔴 카메라를 방 안으로 묶는다 (세88 — 리드가 MCP 스샷으로 잡았다).
##
## 방을 2400×2200으로 키우자 **입장 순간 화면 아래 절반이 방 밖(엔진 배경색 회색)으로 비었다**:
## 플레이어 스폰(0, 600)이 남쪽 경계(y 700)에서 100px인데 뷰포트 반높이가 270px이라 y 700~870이
## 그대로 화면에 들어왔다. `player.tscn`의 `Camera2D`엔 `limit_*`이 없다 — 마을(2400×1600)에서는
## 플레이어가 경계까지 잘 안 가서 **드러나지 않았을 뿐이다**(설계 부록도 "클램프가 어긋날 자리가
## 없다"고 적었는데, 어긋날 자리가 없던 게 아니라 **클램프 자체가 없었다**).
##
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


## 🔴 탈출구를 전부 세우고 **한 자리에서** 배선한다 (세99 D1).
##  ⓐ 씬의 남쪽 `$Exit`(세88부터 늘 있던 것) ⓑ `ChapterDef.extract_points`가 적은 자리들.
## 🔴 `extract_points`가 **비면 ⓐ 하나뿐** = 세98까지와 한 톨도 안 다르다(회귀 0).
## ⚠ 출구는 전부 `zone_id = &"exit"`이다 — 씬 파일이 그 값을 쥔다(`exit_zone.tscn`).
##  세99에 포탈이 은퇴하며 **zone_id가 갈릴 이유 자체가 없어졌다** — 다른 값을 새로 만들지 마라.
func _build_exits() -> void:
	_exits.clear()
	var south := get_node_or_null(^"Exit") as InteractZone
	if south != null:
		_exits.append(south)
	else:
		# 침묵 금지 — 출구가 하나도 없으면 상시 귀환이 통째로 사라지는데 화면은 멀쩡하다.
		push_error("boss_room: 씬에 남쪽 출구($Exit)가 없다 — 상시 귀환이 사라진다")
	for point: Vector2 in _chapter.extract_points:
		var zone := ExitZoneScene.instantiate() as InteractZone
		zone.position = point
		add_child(zone)
		_exits.append(zone)
	for zone: InteractZone in _exits:
		_wire_extract_zone(zone)


## 🔴🔴 나가는 길 하나를 **살린다** — 연결과 홀드 스위치가 **같은 함수 안**이어야 한다.
##  • 연결을 빠뜨리면: E가 먹히고 안내도 뜨는데 **아무 일도 안 일어나고 가방이 조용히 증발한다**
##    (창고로 안 가고 자동 저장도 안 돈다 — 에러 0. `_extract` 머리말이 경고한 그 자리다).
##  • 홀드를 빠뜨리면: 그 출구만 즉시 탈출이 돼 **D7의 긴장이 출구 하나로 새 나간다**(역시 에러 0).
## 🔴 부르는 곳은 `_build_exits` **하나뿐**이다 — 세99에 포탈이 은퇴하며 둘째 호출부가 사라졌다.
##  방 안에 나가는 길을 새로 세우는 코드를 또 쓰게 되거든 **여기를 지나게** 해라.
func _wire_extract_zone(zone: InteractZone) -> void:
	zone.hold_sec = HOLD_ON
	if not zone.interacted.is_connected(_extract):
		zone.interacted.connect(_extract)


## 바닥 타일을 Ground rect에 맞춰 깐다 — 챕터 분위기 틴트(room_ground_color)는 Ground(ColorRect)가
## 가장자리로 내보이고, 타일은 보스방 전용 어두운 바닥(tile_boss_floor)으로 통일한다.
## 예외 = **출구 앞 풀길**(EXIT_PATH_* 참조) — 마을 쪽 풀 타일로 나가는 길을 표시한다.
## 🔴 세99: 출구가 여럿이라 **풀길도 여럿**이다. 안 깔면 2번째 출구부터 플레이어가 거기 나갈 데가
##  있는 줄 모르고 D1이 통째로 무효가 된다(설계 §6 S12).
func _fill_tiles() -> void:
	var ts: Vector2i = _tiles.tile_set.tile_size
	var rect := Rect2(_ground.position, _ground.size).grow(-float(ts.x))   # 가장자리 한 칸은 틴트가 보이게
	var from := Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y))
	var to := Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y))
	var paths := _exit_paths(from, to, ts)
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var cell := Vector2i(x, y)
			var on_path := false
			for p: Rect2i in paths:
				if p.has_point(cell):
					on_path = true
					break
			_tiles.set_cell(cell, TILE_SRC_GRASS if on_path else TILE_SRC_FLOOR, Vector2i.ZERO)


## 출구마다 풀길 칸 범위를 낸다 — 🔴 **좌표는 출구 노드에서 파생한다**(여기 베끼면 출구를 옮길 때
## 길만 제자리에 남는다). `from`은 포함·`to`는 배타 = `_fill_tiles`의 루프 범위 그대로.
func _exit_paths(from: Vector2i, to: Vector2i, ts: Vector2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if EXIT_PATH_ROWS <= 0:   # 끄는 손잡이 (연출값)
		return out
	var half: int = (EXIT_PATH_WIDTH_CELLS - 1) / 2
	for zone: InteractZone in _exits:
		if zone == null or not is_instance_valid(zone):
			continue
		var cell := Vector2i(floori(zone.position.x / float(ts.x)), floori(zone.position.y / float(ts.y)))
		out.append(_path_rect(cell, from, to, half))
	return out


## 출구 한 칸 → 「가장 가까운 방 가장자리로 이어지는 통로」.
##
## 🔴 **세88의 남쪽 출구에 대해 결과가 칸 하나까지 같다**(회귀 0): 출구 셀 y=10 · 채우는 마지막
## 줄 y=9 · `EXIT_PATH_ROWS=3` → y 7~10인데 루프가 10을 안 도니 실제로 깔리는 건 {7,8,9},
## 즉 옛 `y >= to.y - EXIT_PATH_ROWS`와 **같은 세 줄**이다. x도 `cell.x ± half`로 동일하다.
## 🔴 일반화가 필요한 이유: 늘린 출구는 남쪽이 아닐 수 있다. 「마지막 세 줄」로 두면 **동·서·북
## 출구엔 길이 자기 자리가 아닌 남쪽 끝에 깔린다**(에러 0 · 화면만 거짓말).
## ⚠ 방 한복판에 출구를 두면 통로가 **출구에서 가장자리까지 통째로** 깔린다 — 의도한 동작이다
##  (짧은 표시보다 「걸어 나가는 길」이 D1의 판단을 만든다).
func _path_rect(cell: Vector2i, from: Vector2i, to: Vector2i, half: int) -> Rect2i:
	var last := Vector2i(to.x - 1, to.y - 1)   # 실제로 칠하는 마지막 칸(포함)
	var d_left := cell.x - from.x
	var d_right := last.x - cell.x
	var d_top := cell.y - from.y
	var d_bottom := last.y - cell.y
	var best := mini(mini(d_left, d_right), mini(d_top, d_bottom))
	if best == d_bottom or best == d_top:
		var edge := last.y if best == d_bottom else from.y
		var inner := edge - (EXIT_PATH_ROWS - 1) if best == d_bottom else edge + (EXIT_PATH_ROWS - 1)
		var y0 := mini(cell.y, mini(edge, inner))
		var y1 := maxi(cell.y, maxi(edge, inner))
		return Rect2i(cell.x - half, y0, EXIT_PATH_WIDTH_CELLS, y1 - y0 + 1)
	var edge_x := last.x if best == d_right else from.x
	var inner_x := edge_x - (EXIT_PATH_ROWS - 1) if best == d_right else edge_x + (EXIT_PATH_ROWS - 1)
	var x0 := mini(cell.x, mini(edge_x, inner_x))
	var x1 := maxi(cell.x, maxi(edge_x, inner_x))
	return Rect2i(x0, cell.y - half, x1 - x0 + 1, EXIT_PATH_WIDTH_CELLS)


## 보스 동적 스폰 — 두 경로 (ChapterDef 계약):
##  • boss_scene_path가 있으면 그 전용 씬 (snake_boss.tscn — enemy_id는 씬이 이미 품고 있다)
##  • 비면 forest_enemy.tscn 범용 스폰 — 🔴 **add_child 전에 enemy_id 대입** (forest.tscn이
##    인스턴스 오버라이드로 하던 것을 코드로. _ready가 이 id로 .tres를 물기 때문에 순서가 계약이다).
##
## 🔴 반환 = **계속 진행해도 되는가**. `boss_scene_path`는 「새 챕터 = .tres 한 장」에서 실제로
## 편집되는 자리라 오타가 나기 쉽고, 실패하면 `_ready`의 나머지(잡몹·목표 안내)를 **건너뛰어야 한다**.
## ⚠ **보스 노드를 필드로 들지 않는다** — 세99에 포탈이 은퇴하며 유일한 독자(`_spawn_return_portal`이
##  죽은 자리를 읽던 것)가 사라졌다. 아무도 안 읽는 필드를 남기면 **거짓 손잡이**가 된다(감사 T3).
##  보스를 찾아야 하면 그룹 `"enemies"` + `enemy_id`로 집어라(그물이 이미 그렇게 한다).
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
	# 🔴 위치도 add_child **앞**이 계약이다 (enemy_id와 같은 이유) — snake_body가 _ready에서
	# 부모의 그 시점 위치로 자취를 프리시드하므로, 뒤에 옮기면 ch3 입장 첫 프레임에 마디 12개가
	# 원점→boss_spawn으로 끌려간다(세54 「정지 뭉침」 재림). 루트가 원점이라 position == global.
	boss.position = _chapter.boss_spawn
	add_child(boss)
	return true


## 잡몹 길 (세66 도파민 — 즉시 보상 무대) — 방 앞쪽에 잡몹을 깐다. 플레이어가 뚫고 보스에 닿는다.
## 🔴 잡몹은 forest_enemy 범용 계약(그룹 enemies·layer4·take_hit·_die→coin 드롭). 신규 씬 0.
##  클리어 판정은 안 건드린다 — 잡몹 죽음은 _on_enemy_died에서 boss_enemy_id가 아니라 무시된다
##  (잡몹=돈·손맛 1층, 보스=clear 2·3층). 웨이브 게이팅 없이 배치만(v1).
##
## 🔴🔴 **세99 D5 — 자리는 고정, 정체만 굴린다**(사용자 확정 *"지형은 동일하고 나오는 몬스터들이 랜덤"*).
##  좌표는 **언제나** `MobSpawn.position` 그대로다 — 굴리는 건 「거기 뭐가 서 있나」뿐이다.
##  `pool_tag`가 비면 `enemy_id` 그대로 = **세98까지와 한 톨도 안 다르다**(회귀 0).
## 🔴 후보가 0이면 그 자리가 **빈 채로 선다** — 에러가 0이라(설계 §6 S1) `push_warning`으로 짖는다.
##  ⚠ 태그당 한 번만 짖는다: 자리 9곳이 같은 태그를 가리키면 같은 경고가 9줄 나와 로그가 죽는다.
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


## 🔴 D5 굴림 — `pool_tag`가 같은 `MobWeight`를 **weight 비례**로 하나 뽑는다. 후보가 없으면 `&""`.
##
## 🔴 **`weight <= 0`은 안 뽑는다** — `MobWeight.weight` 주석이 *"임시로 빼려면 지우지 말고 0으로"*라고
##  약속한 손잡이다. 안 지키면 **거짓 손잡이**(감사 T3)가 되고, 0으로 빼 둔 적이 그대로 나온다.
## ⚠ **시드를 고정하지 않는다** — 이 리포의 랜덤은 전역 `randf()`/`randi_range()` 하나뿐이라
##  테스트가 전역 `seed()`를 잡으면 `forest_enemy._spawn_loose`의 각도 굴림 등이 **같은 스트림을 소비**해
##  순서가 조금만 바뀌어도 어긋난다(= flake). 그래서 그물은 **확률·가중치의 양끝을 주입해** 잰다.
func _roll_pool_id(tag: StringName) -> StringName:
	var ids: Array[StringName] = []
	var weights: Array[int] = []
	var total := 0
	for mw: MobWeight in _chapter.mob_pool:
		if mw == null or mw.pool_tag != tag or mw.enemy_id == &"":
			continue
		if mw.weight <= 0:   # 🔴 0 이하 = 「지금은 빼 둔다」 (지우지 않고 끄는 손잡이)
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


## 🔴 D6 네임드 — `named_pool`의 **각 항목을 독립으로** 굴린다. **「하나도 안 뜸」이 정상 결과다**
##  (사용자 원문 *"네임드가 있을 수도 없을 수도 있음"* — 그게 「오늘 뭔가 있다」를 만든다).
##
## 🔴🔴 **표시는 생김새다 — 빛나게 하지 않는다**(세99 사용자 확정: *"몸에서 빛이나는거 까진 별로임"*).
##  덩치(`EnemyDef.params.size` = 루트 scale이라 히트박스·그림자가 공짜로 따라온다)와 전용 스프라이트로
##  구별한다. **오라·HUD 알림·입장 문구는 각하됐다 — 만들지 마라.**
## ⚠ `at_landmark`는 **단계 3 몫**이라 지금은 해석하지 않는다. 채워 두면 조용히 안 뜨므로 짖는다.
func _spawn_named() -> void:
	for named: NamedSpawn in _chapter.named_pool:
		if named == null or named.enemy_id == &"":
			continue
		if named.at_landmark != &"":
			push_warning("boss_room: 네임드 '%s'의 at_landmark('%s') 해석은 단계 3 몫이다 — 이번 판엔 안 선다"
				% [String(named.enemy_id), String(named.at_landmark)])
			continue
		# 🔴 `randf()`는 [0,1) — chance 0.0이면 절대 안 뜨고 1.0이면 반드시 뜬다(양끝이 그물의 손잡이).
		if randf() >= named.chance:
			continue
		_spawn_enemy_at(named.enemy_id, named.position)


## 🔴🔴 적 하나를 세운다 — **잡몹·네임드가 지나는 유일한 문**이고 **보스 id 제외 가드가 여기 한 줄**이다.
##
## 왜 한 곳인가 (설계 §6 S9): `_on_enemy_died`의 클리어 판정이 **`enemy_id` 일치 한 줄**이라
## 풀·네임드에 `boss_enemy_id`가 섞이면 **잡몹 한 마리를 잡았을 뿐인데 `chapter_clear_*` + 보상 룬이
## 전부 조용히 나간다(에러 0)**. 세98까지 안 겹친 건 `mob_spawns`를 손으로 박아 **우연히 보장**되던 것뿐이다.
## 🔴 가드를 굴림 함수에 두지 않은 이유 = 문이 둘(잡몹·네임드)이면 **가드도 둘**이 되고 한쪽만 지워도
##  다른 쪽이 그린이라 뮤테이션이 안 걸린다. 여기 한 줄을 지우면 **두 경로가 같이 빨개진다.**
## 🔴 `enemy_id`·위치 대입은 `add_child` **앞**이 계약이다 (보스와 같은 이유 — `_ready`가 그 id로 .tres를 문다).
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


## 🔴 클리어를 여는 id인가 — `_on_enemy_died`의 판정식과 **같은 비교**를 쓴다(사본이 아니라 파생).
func _is_boss_id(id: StringName) -> bool:
	return _chapter != null and id == _chapter.boss_enemy_id


## 🔴 클리어 판정 = **보스 처치 순간** (루팅·귀환과 무관 — 죽어서 가방을 잃어도 클리어는 남는다.
## "이기면 열림"이 순수해서 억울함이 없다). 키는 `Db.chapter_clear_id` 파생 한 곳 — 여기서 문자열을
## 조립하지 않는다(세50 계열 오타 함정). codex_unlocked 한 발로 codex 심기 + UNLOCK 퀘스트 진행 +
## Audio unlock음이 전부 따라온다 (세37 station_* 패턴).
func _on_enemy_died(enemy_id: StringName) -> void:
	if _cleared or _chapter == null or enemy_id != _chapter.boss_enemy_id:
		return
	_cleared = true
	var clear_id := Db.chapter_clear_id(_chapter)
	# ⚠ 재입장(파밍 재방문)이면 codex가 이미 있다 — 다시 쏘면 UNLOCK 퀘스트·해금음이 중복으로
	# 반응하므로 첫 클리어에만 쏜다. ✅ **나가는 길은 이 함수와 무관하다** — 출구는 처음부터 서 있어서
	# 세99 이전의 「포탈이 안 뜨면 재방문 소프트락」이라는 위험 자체가 사라졌다.
	if not GameState.is_unlocked(clear_id):
		EventBus.codex_unlocked.emit(clear_id)
	# 🔴 클리어 보상 해금 (세71 첫 스테이지) — ChapterDef.reward_unlock가 있으면 codex에 심는다.
	# chapter_clear와 **별도 축**이다(clear_id는 챕터 게이트, reward_unlock은 획득물=문양 링/룬/진).
	# 첫 처치에만: 재방문 파밍 때 다시 쏘면 Audio 해금음·UNLOCK 퀘스트가 중복 반응한다(clear 가드와 같은 결).
	# codex_unlocked 한 발로 codex 심기 + 해금음 + UNLOCK 퀘스트 진행이 전부 따라온다(세37 station_* 패턴).
	var reward_line := ""
	if _chapter.reward_unlock != &"" and not GameState.is_unlocked(_chapter.reward_unlock):
		EventBus.codex_unlocked.emit(_chapter.reward_unlock)
		# 🔴 문구는 `CodexText`가 낸다 — 룬·진·고리마다 「어디에 쓰는지」가 다르고(중심·바탕·밴드)
		# 발신처가 셋이라, 여기서 조회를 조립하면 그게 곧 사본이다(감사 T5). 세88에 보상이 고리에서
		# **룬**으로 바뀌며 옛 `Db.get_glyph_ring` 한 줄이 원시 id + 거짓 안내를 찍고 있었다.
		var reward_label := CodexText.label_of(_chapter.reward_unlock)
		if reward_label != "":
			reward_line = " 보상: %s" % reward_label
	# 🔴 세84 #36: `sticky` — 클리어 뒤에도 **아직 할 일이 남아 있다**(살아서 나가야 한다). 그게
	# 이 줄이 sticky인 이유이자, 세99에 포탈을 없앤 이유이기도 하다 — 처치가 곧 끝이 아니다.
	# ⚠ **「포탈」을 다시 적지 마라**(T4: 없는 물건을 가리키는 안내는 그대로 거짓 지시가 된다).
	_hud.say("%s 클리어!%s 이제 살아서 나가라 — 출구에서 [E] 꾹" % [_chapter.title, reward_line],
		false, true)


## 🔴 귀환 성공 — `extraction_success`가 **가방(루팅분 포함)을 창고로 옮기고 자동 저장**한다
## (GameState·SaveManager가 이미 이 시그널에 연결돼 있다). 안 쏘면 루팅한 게 다음 사망 때 증발하고
## q02(EXTRACT)가 영영 안 찬다 — forest._extract 계약 그대로.
## ⚠ **부르는 곳이 여럿이다** — 출구 전부(`_build_exits`)가 `_wire_extract_zone` 한 문을 지난다.
## 새 길을 뚫으면 거기로 이어라 (세99에 포탈이 은퇴해 지금 발신원은 출구뿐이다).
## ✅ **이중 전환 방어는 이미 서 있다** — `_leaving` 가드가 길이 몇 개든 한 번으로 묶는다
##  (출구를 늘리며 새로 짜지 마라 — 세47 「이미 있는 배선」의 결).
func _extract() -> void:
	if _leaving:
		return
	_leaving = true
	EventBus.extraction_success.emit()
	_to_base()


func _on_hp_changed(hp: float, _hp_max: float) -> void:
	if hp <= 0.0:
		_die()


## 쓰러졌다 — `bag_lost`가 가방을 비우고 자동 저장한다(세이브스컴 방지). 클리어 codex는 처치 순간
## 이미 심겼으므로(§클리어 판정) 죽어도 다음 챕터는 열려 있다. forest._die 계약 그대로.
##
## 🔴 **사망 후 HP 복구를 쥐는 건 이 함수다** (세84 감사 #37). HP는 오토로드(GameState)가 쥐고
## 세이브에 없어서, 예전엔 되돌리는 경로가 **어디에도 없었다** — 베이스로 걸어 나가는 몸이 HP 0이었다
## (마을에 피해원이 0곳이라 표시 문제로만 보였지, 피해원이 하나 생기는 날 즉사 버그가 된다).
## ⚠ **「출격 = 만HP」의 단일 소스는 `_ready`**(`base._open_chapter_panel` 위 주석이 *"출격이 HP를
## 되돌리지 않는다 — 그건 보스방이 한다"*고 선언한다). 그래서 복구도 베이스가 아니라 **여기**가 쥔다 — 베이스에 두면
## 「베이스를 거쳐 들어올 때만」 맞고 다른 진입 경로에선 조용히 달라진다(그 주석이 경고한 그 함정).
## 🔴 복구는 **연출(DEATH_BEAT_SEC) 뒤**다: 먼저 되돌리면 「쓰러졌다」를 띄운 채 HP 막대가 꽉 차
## "안 죽었다"로 읽힌다. 되돌리는 emit이 `_on_hp_changed`를 다시 태우지만 `_leaving` 가드가 막는다.
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


## 목표 하나를 달성했다 — 아직 완료 아님. 마을 **문**으로 돌아가 정산하라고 HUD로 민다 (forest 선례).
## 🔴🔴 세95: 옛 문구는 *"길잡이에게 돌아가 정산하라 [?]"*였는데 **길잡이가 은퇴해 없는 사람을 가리켰다**
##   (끝의 `[?]`도 그 머리 위 마크였다 — 지금은 문 위에 뜬다, `base.gd _refresh_gate_mark`).
## ⚠ 이 줄은 **원정 중에 실제로 화면에 뜨는 안내**다. `base.gd _on_quest_ready`와 **일부러 문구가 다르다**:
##   여긴 원정 중이라 「마을로 돌아가」가 붙고, 마을에선 이미 문 앞이라 안 붙는다.
##   (세95 전엔 두 줄이 **한 글자도 안 달라** 감사 T5 「파생 대신 복제」의 표본이었다 — 지금은 뜻이 갈렸다.)
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 마을로 돌아가 문에서 [E]로 정산하라 [?]" % q.title)
