extends Node2D
## 보물 상자 프롭 (세55 능동 루팅) — 보스/특별 적(`EnemyDef.drops_chest`)이 죽으면
## `forest_enemy._spawn_chest`가 죽은 자리에 이 씬을 심는다. 플레이어가 [E]로 열면 loot_panel이
## 떠서 카드를 눌러 담는다(타르코프식 능동 루팅). 낱개 픽업 + 자석(세51)의 보스 대체물이다.
##
## 🔴 **자기완결적이다 — forest.gd가 상자를 배선하지 않는다.** 상자는 처치 순간 **동적으로** 생기므로
## 씬 `_ready` 배선(귀환 지점·포털처럼)으로는 못 잡는다. 그래서 상자가 자기 InteractZone을 스스로
## 잇고, loot_panel도 **온디맨드로 인스턴스**한다(forest.gd가 map_panel을 그렇게 여는 선례).
## 결과: 어느 씬(숲·t2·장래의 다른 필드)에서 죽든 상자가 그대로 돈다 — 씬마다 패널을 놓을 필요가 없다.
##
## 🔴 **interact_zone 합성** — 책상·귀환지점과 같은 [E] 물건(zone_id=&"chest", layer64/mask2).
## 스프라이트·충돌·프롬프트는 chest.tscn이 쥐고, 이 스크립트는 **내용물·열기 흐름**만 쥔다.
##
## 🔴 **내용물 = forest_enemy가 굴린 결과** `[{"id","count"}]` — 상자 전용 드롭 필드를 안 만든다
## (`EnemyDef.drops` 재사용). loot_panel이 이 배열을 **참조로** 받아 루팅한 항목을 remove_at 한다.
## 그래서 패널이 닫힐 때 이 배열이 비었으면(다 주웠다) 상자가 스스로 사라지고, 안 비었으면 남아
## 재개봉된다(GDScript Array는 참조 전달 — 패널의 remove_at가 이 `_contents`에 그대로 반영된다).
##
## 🔴 class_name 선언 금지(서브에이전트 규칙 결). forest_enemy가 chest.tscn을 preload로 무는데,
## 상자는 forest/actors를 안 물어 순환이 없다(drop_pickup과 같은 결).

const InteractZone := preload("res://src/actors/interact_zone.gd")
## 온디맨드 loot_panel (map_panel 선례) — 루트=CanvasLayer, 스크립트는 자식 $Panel.
const LootPanelScene := preload("res://src/hud/loot_panel.tscn")

## 🔴 스프라이트 프레임 = 가로 스트립 `[닫힘 | 열림]`, 각 48px(chest.png 96×48). Sprite2D의
## region으로 잘라 쓴다(AnimatedSprite가 아니라 정적 2컷이라 region 토글이 가볍다).
const FRAME := 48.0
const REGION_CLOSED := Rect2(0.0, 0.0, FRAME, FRAME)
const REGION_OPEN := Rect2(FRAME, 0.0, FRAME, FRAME)

@onready var _zone: InteractZone = $InteractZone
@onready var _sprite: Sprite2D = $Sprite

## forest_enemy가 넘긴 내용물 `[{"id": StringName, "count": int}]`. loot_panel이 참조로 비운다.
var _contents: Array = []
## 열려 있는 패널 (한 번에 하나). 열려 있으면 재-개봉을 막는다.
var _panel: CanvasLayer = null


func _ready() -> void:
	# 테스트·장래 로직이 상자를 훑을 그룹.
	add_to_group("chests")
	_zone.interacted.connect(_open_loot)
	_show_open(false)


## 🔴 forest_enemy._spawn_chest가 부른다 — 내용물을 실어 준다. 위치는 그전에 잡혀 있다.
## 빈 상자는 forest_enemy가 애초에 안 만든다(_roll_drops가 비면 상자를 안 심는다).
func setup(contents: Array) -> void:
	_contents = contents


## [E] — loot_panel을 온디맨드로 띄우고 내용물을 참조로 넘긴다. 상자는 열린 프레임으로 바뀐다.
## 🔴 패널이 열려 있는 동안엔 `ui_modal_open`이 켜져 interact_zone이 E를 안 먹으므로 재진입이 없지만,
## 방어적으로 `_panel != null` 가드도 둔다(연출 프레임/중복 인스턴스 방지).
func _open_loot() -> void:
	if _panel != null:
		return
	_show_open(true)
	_panel = LootPanelScene.instantiate() as CanvasLayer
	# 🔴 current_scene에 붙인다 — 상자 자신(queue_free될 수 있다)이 아니라. CanvasLayer는 부모
	# 트랜스폼을 무시하므로 어디에 붙든 화면 고정으로 그려진다(map_panel과 같은 결).
	var scene := get_tree().current_scene
	(scene if scene != null else self).add_child(_panel)
	var panel := _panel.get_node("Panel")
	panel.closed.connect(_on_loot_closed)
	panel.open(_contents)


## 패널이 닫혔다 — 패널을 치우고, 내용물이 다 빠졌으면 상자를 없앤다.
func _on_loot_closed() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if _contents.is_empty():
		queue_free()          # 다 주웠다 — 상자가 사라진다
	else:
		_show_open(false)     # 남았다 — 닫힌 상자로 되돌려 재개봉 가능하게


## 스프라이트 프레임 토글(열림/닫힘). region으로 잘라 쓴다. 스프라이트가 아직 없으면(테스트 하네스)
## 조용히 넘어간다 — 상자 로직은 스프라이트 없이도 돈다.
func _show_open(open: bool) -> void:
	if _sprite == null:
		return
	_sprite.region_rect = REGION_OPEN if open else REGION_CLOSED
