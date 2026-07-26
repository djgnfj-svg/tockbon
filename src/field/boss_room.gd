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
## 🔴 **나가는 길은 둘이고 둘 다 `_extract`로 간다** (세88 반복 사냥터):
##  • **남쪽 출구**(`zone_id = &"exit"`, 씬에 상시 존재) — **언제든** 나갈 수 있다.
##  • **보스 자리 포탈**(`zone_id = &"portal"`, 처치 후 스폰) — 보스를 잡은 자리에서 남쪽까지
##    먼 길을 되돌아가지 않게 하는 지름길이다. 「처치 후에만」은 아직 살아있는 계약이다.
##
## 🔴 **한 씬 + ChapterDef 파라미터다** — 챕터별 씬 3장을 만들지 않는다(설계 확정). 방 구성이
## 동일(바닥·보스 하나·입구)하고 다른 건 데이터(보스·색)뿐이라, 씬을 늘리면 mouse_filter·z_index·
## 레이어 함정을 그 수만큼 다시 밟는다. "새 챕터 = data/chapters/*.tres 한 장"이 여기서 성립한다.
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
## 귀환 포탈 — 기존 portal.tscn 재사용(신규 프롭 0). Prompt 문구는 세44 프롭 계약대로 부모가 덮는다.
##
## 🔴 **왜 처치 후에만 스폰하나 — 근거가 세88에 바뀌었다.** 예전 주석은 *"미리 있으면 안 잡고
## 나가기가 공짜가 된다"*였는데, 지금은 **남쪽 출구(`&"exit"`)로 언제든 나갈 수 있다** — 반복
## 사냥터가 되려면 그래야 하고, 잡몹만 잡고 나가는 건 **재료만 얻고 확정 보상(`reward_unlock`)은
## 못 얻는** 것이라 공짜가 아니다. 이 포탈이 남은 이유는 **보스 자리에서 남쪽까지 되돌아가는 먼
## 길을 덜어 주는 지름길**이다. ⚠ 그래도 씬에 미리 놓지 마라 — `test_chapter_auto`가 「처치 전엔
## `portal`이 없다」를 재고 있고, 그건 아직 살아있는 계약이다(재방문 때도 매번 다시 뜬다).
const PortalScene := preload("res://src/props/portal.tscn")
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
## 귀환 포탈이 보스가 죽은 자리에서 비켜 서는 거리 — 보스 자리에 흩어지는 낱개 드롭과 안 겹치게 (연출값).
const PORTAL_OFFSET := Vector2(88.0, 0.0)

## 타일 소스 (assets/sprites/field/tileset_forest.tres): 0 = 풀(마을 쪽), 1 = 보스방 어두운 바닥.
const TILE_SRC_GRASS := 0
const TILE_SRC_FLOOR := 1
## 남쪽 출구로 이어지는 풀길 (칸 수 — 연출값). 어두운 숲 바닥에 마을 쪽 풀 타일을 깔아 **걸어가 보기
## 전에도** "저기가 나가는 길"로 읽히게 한다(출구 자체는 겉모습이 없는 InteractZone이다 — 보라색
## 차원문 Polygon2D를 베끼지 않기로 한 결정). 🔴 **길의 중심 x는 `Exit` 노드에서 파생한다** — 좌표를
## 두 번 적으면 출구를 옮길 때 길만 제자리에 남는다. 끄려면 `EXIT_PATH_ROWS = 0`.
const EXIT_PATH_WIDTH_CELLS := 3
const EXIT_PATH_ROWS := 3

@onready var _ground: ColorRect = $Ground
@onready var _tiles: TileMapLayer = $TileGround
## 🔴 남쪽 상시 귀환 출구 (세88) — 씬에 미리 있다. `zone_id = &"exit"`이고 `&"portal"`이 아닌 이유는
## PortalScene 위 주석에 있다.
@onready var _exit: InteractZone = $Exit
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud

var _chapter: ChapterDef = null
var _boss: Node2D = null
## 클리어 처리는 한 번뿐 — enemy_died는 EventBus 전역이라 가드 없이는 무엇이든 두 번 처리될 수 있다.
var _cleared: bool = false
## 씬 전환은 한 번뿐 — 귀환 도중 죽거나, 죽는 중에 E를 누르면 두 번 갈아탄다 (forest 계약 이관).
var _leaving: bool = false


func _ready() -> void:
	# 🔴 출격 = 만HP/만마나 (forest.gd 계약 이관). 이게 없으면 죽는 게 이득이 된다 —
	# 다친 몸으로 포탈까지 버티느니 그 자리에서 죽는 편이 싸진다.
	GameState.reset_player_hp()
	GameState.restore_mana_full()
	GameState.in_expedition = true
	# 🔴 모달 플래그를 내린다 — 오토로드라 씬 전환에도 남는다 (base.gd _ready와 같은 안전망).
	GameState.ui_modal_open = false
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# 🔴 남쪽 출구도 **포탈과 같은 `_extract`로** 간다 — 여기 안 이으면 E가 먹히는데 아무 일도 안
	# 일어나고(안내만 뜬다), 가방이 창고로 안 가고 자동 저장도 안 돈다(에러 없이).
	_exit.interacted.connect(_extract)
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
	_fill_tiles()
	_clamp_camera_to_room()
	# 🔴 스폰이 실패하면 **여기서 멈춘다** — `_spawn_boss` 안의 `return`은 자기 함수만 벗어나므로,
	# 예전엔 이미 떠나기로 한 방(`_leaving = true`)이 잡몹을 깔고 「…를 쓰러뜨려라」를 한 프레임
	# 띄웠다(세84 감사 #38). 챕터-null 분기(위)는 return이 `_ready` 자신이라 원래부터 제대로 멈춘다.
	if not _spawn_boss():
		return
	_spawn_mobs()
	var boss_def := Db.get_enemy(_chapter.boss_enemy_id)
	var boss_name := boss_def.display_name if boss_def != null else String(_chapter.boss_enemy_id)
	# 🔴 세84 #36: `sticky` — **방의 목표 줄이다**. say()에 수명이 붙었으므로(경고가 목표를 덮고
	# 영구 상주하던 걸 고쳤다) 여기 안 붙이면 목표가 4.5초 뒤 조용히 사라진다.
	_hud.say("%s — %s를 쓰러뜨려라. 잡으면 귀환 포탈이 열린다" % [_chapter.title, boss_name], false, true)


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


## 바닥 타일을 Ground rect에 맞춰 깐다 — 챕터 분위기 틴트(room_ground_color)는 Ground(ColorRect)가
## 가장자리로 내보이고, 타일은 보스방 전용 어두운 바닥(tile_boss_floor)으로 통일한다.
## 예외 = **남쪽 출구 앞 풀길**(EXIT_PATH_* 참조) — 마을 쪽 풀 타일로 나가는 길을 표시한다.
func _fill_tiles() -> void:
	var ts: Vector2i = _tiles.tile_set.tile_size
	var rect := Rect2(_ground.position, _ground.size).grow(-float(ts.x))   # 가장자리 한 칸은 틴트가 보이게
	var from := Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y))
	var to := Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y))
	# 출구 좌표는 여기서 베끼지 않는다 — 씬의 Exit 노드에서 칸으로 환산한다.
	var path_cx: int = floori(_exit.position.x / float(ts.x))
	var path_half: int = (EXIT_PATH_WIDTH_CELLS - 1) / 2
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var on_path: bool = y >= to.y - EXIT_PATH_ROWS and absi(x - path_cx) <= path_half
			_tiles.set_cell(Vector2i(x, y),
				TILE_SRC_GRASS if on_path else TILE_SRC_FLOOR, Vector2i.ZERO)


## 보스 동적 스폰 — 두 경로 (ChapterDef 계약):
##  • boss_scene_path가 있으면 그 전용 씬 (snake_boss.tscn — enemy_id는 씬이 이미 품고 있다)
##  • 비면 forest_enemy.tscn 범용 스폰 — 🔴 **add_child 전에 enemy_id 대입** (forest.tscn이
##    인스턴스 오버라이드로 하던 것을 코드로. _ready가 이 id로 .tres를 물기 때문에 순서가 계약이다).
##
## 🔴 반환 = **계속 진행해도 되는가**. `boss_scene_path`는 「새 챕터 = .tres 한 장」에서 실제로
## 편집되는 자리라 오타가 나기 쉽고, 실패하면 `_ready`의 나머지(잡몹·목표 안내)를 **건너뛰어야 한다**.
func _spawn_boss() -> bool:
	if _chapter.boss_scene_path != "":
		var packed := load(_chapter.boss_scene_path) as PackedScene
		if packed == null:
			push_error("boss_room: boss_scene_path '%s'를 못 읽었다 — 베이스로 되돌아간다"
				% _chapter.boss_scene_path)
			_leaving = true
			_to_base.call_deferred()
			return false
		_boss = packed.instantiate() as Node2D
	else:
		var enemy := EnemyScene.instantiate() as Node2D
		enemy.set(&"enemy_id", _chapter.boss_enemy_id)
		_boss = enemy
	# 🔴 위치도 add_child **앞**이 계약이다 (enemy_id와 같은 이유) — snake_body가 _ready에서
	# 부모의 그 시점 위치로 자취를 프리시드하므로, 뒤에 옮기면 ch3 입장 첫 프레임에 마디 12개가
	# 원점→boss_spawn으로 끌려간다(세54 「정지 뭉침」 재림). 루트가 원점이라 position == global.
	_boss.position = _chapter.boss_spawn
	add_child(_boss)
	return true


## 잡몹 길 (세66 도파민 — 즉시 보상 무대) — 방 앞쪽에 잡몹을 깐다. 플레이어가 뚫고 보스에 닿는다.
## 🔴 잡몹은 forest_enemy 범용 계약(그룹 enemies·layer4·take_hit·_die→coin 드롭). 신규 씬 0.
##  🔴 enemy_id·위치 대입은 add_child **앞** (보스와 같은 계약 — _ready가 그 id로 .tres를 문다).
##  클리어 판정은 안 건드린다 — 잡몹 죽음은 _on_enemy_died에서 boss_enemy_id가 아니라 무시된다
##  (잡몹=돈·손맛 1층, 보스=clear 2·3층). 웨이브 게이팅 없이 배치만(v1).
func _spawn_mobs() -> void:
	for spawn: MobSpawn in _chapter.mob_spawns:
		if spawn == null or spawn.enemy_id == &"":
			continue
		var mob := EnemyScene.instantiate() as Node2D
		mob.set(&"enemy_id", spawn.enemy_id)
		mob.position = spawn.position
		add_child(mob)


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
	# 반응하므로 첫 클리어에만 쏜다. **포탈은 매번 뜬다** (안 뜨면 재방문이 소프트락이 된다).
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
	_spawn_return_portal()
	# 🔴 세84 #36: `sticky` — 「포탈에서 E로 귀환하라」는 **아직 유효한 지시**다(귀환까지 남아야 한다).
	_hud.say("%s 클리어!%s 포탈에서 E로 귀환하라" % [_chapter.title, reward_line], false, true)


## 귀환 포탈 — 보스가 죽은 자리 옆에 스폰 (드롭이 그 자리에 흩어지므로 PORTAL_OFFSET만큼 비킨다).
## enemy_died 발신 시점엔 보스 노드가 아직 살아 있다(queue_free 전) — 위치를 여기서 읽을 수 있다.
func _spawn_return_portal() -> void:
	var portal := PortalScene.instantiate() as InteractZone
	var pos := _chapter.boss_spawn + PORTAL_OFFSET
	if _boss != null and is_instance_valid(_boss):
		pos = _boss.global_position + PORTAL_OFFSET
	add_child(portal)
	portal.global_position = pos
	# 세44 프롭 계약 — 문구는 부모가 덮는다 (기본 문구는 옛 「하강」 용법이라 여기선 거짓말이 된다).
	var prompt := portal.get_node_or_null("Prompt") as Label
	if prompt != null:
		prompt.text = "[E] 마을로 귀환"
	portal.interacted.connect(_extract)


## 🔴 귀환 성공 — `extraction_success`가 **가방(루팅분 포함)을 창고로 옮기고 자동 저장**한다
## (GameState·SaveManager가 이미 이 시그널에 연결돼 있다). 안 쏘면 루팅한 게 다음 사망 때 증발하고
## q02(EXTRACT)가 영영 안 찬다 — forest._extract 계약 그대로.
## ⚠ **부르는 곳이 둘이다** (세88): 남쪽 출구(`_ready`에서 연결) · 처치 후 포탈(`_spawn_return_portal`).
## `_leaving` 가드가 두 길을 한 번으로 묶는다 — 새 출구를 또 뚫으면 여기로 이어라(정산·저장이 여기 있다).
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


## 목표 하나를 달성했다 — 아직 완료 아님. 길잡이에게 돌아가 정산하라고 HUD로 민다 (forest 선례).
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 길잡이에게 돌아가 정산하라 [?]" % q.title)
