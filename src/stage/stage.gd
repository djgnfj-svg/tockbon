extends Node2D
## 무대 — **껍데기다. 본편에 안 남는다.**
##  시뮬(`src/sim/`)·캐릭터(`src/actor/`)·화면(`src/view/`)과 섞지 마라. 그 경계가 폴더의 요점이다.
##
## 🔴🔴 **틱 순서·커맨드 큐·분주기는 여기 없다** — `src/actor/world_step.gd` 가 든다.
##  껍데기가 그 순서를 다시 베끼면 그물이 게임과 다른 것을 재게 된다(`net_damage`가 잰다).
##  ⇒ 여기 남은 것은 **틱이 돈 프레임에 화면을 치는 것**뿐이다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const CharacterView := preload("res://src/view/character_view.gd")
const SpellView := preload("res://src/view/spell_view.gd")
const BlastFx := preload("res://src/view/blast_fx.gd")
const CircleWindow := preload("res://src/view/circle_window.gd")
const Character := preload("res://src/actor/character.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const Aim := preload("res://src/actor/aim.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const StageInput := preload("res://src/stage/stage_input.gd")

const MAP_W := 64
const MAP_H := 36

## 캐릭터 시작 자리(타일). 왼쪽 빈 바닥 — 기둥·나무 구역·돌 벽이 **오른쪽에 차례로 보이는** 자리다.
const SPAWN_TILE := Vector2i(3, 30)

## 손으로 편집하는 초기 지형. `#` 돌 · `=` 나무 · `.` 빈칸. 타일 하나 = 8×8 셀 = 32px.
## 🔴 **타일이 16px → 32px이 되는 동안 이 ASCII는 한 글자도 안 바뀌었다** — 전부 **타일 단위**로
##  쓰여 있어서다.
##
## 🔴🔴 **무대가 한 화면보다 크다. 그래서 카메라가 따라간다**(아래 `camera_center`).
##  격자 = 512×288셀 = **64×36타일 = 2048×1152 월드px** · 화면에 보이는 것 = **960×540 = 30×16.9타일**.
##
## 🔴🔴🔴 **정적 카메라를 버리며 잃은 것을 정확히 적는다 — 폭발이 화면 밖에서 터질 수 있다.**
##  옛 계약은 「무대 전체가 한 화면에 들어온다」였고, 그 이유는
##  「무대가 여백에 걸치면 **확산 8발 중 몇이 안 보이는 데서 터지고** 사용자에게는 「안 터졌다」로
##  읽힌다 — v1이 바닥 슬래브로 정확히 그렇게 데였다」였다.
##  ⇒ **그 이유는 안 사라졌다. 다만 이제 막을 수가 없다** — 확산 탄의 사거리(40타일)가
##   보이는 폭(30타일)보다 길어서, 수평으로 쏘면 **화면 밖 착탄이 원리적으로 난다.**
##  🔴 남은 것은 **「내 주변만은 반드시 보인다」**이고 `net_tables._stage_map` 이 그걸 잰다.
##  ⚠ 「안 터졌다」로 읽히는 일이 다시 나면 **여기가 원인이다.** 카메라를 줌아웃하거나
##   무대를 줄이거나 사거리를 줄이는 셋 중 하나다 — 셋 다 이 파일 밖의 결정이다.
##  ⚠ 무대가 여백에 걸치면 **확산 8발 중 몇이 안 보이는 데서 터지고**, 사용자에게는
##   「안 터졌다」로 읽힌다. v1이 바닥 슬래브를 여백에 세워 정확히 그렇게 데였다.
##  ⇒ **무대는 전부 보이는 끝 안에 있어야 한다.**
##
## 🔴 상자다 — 돌 바닥·천장·좌우 벽. **확산 8발이 전부 뭔가에 맞는다.**
##  위로 간 것들이 허공으로 사라지지 않는다.
## ⚠ 랜덤 지형을 쓰지 않는다 — 매번 달라지면 두 조합을 비교할 수 없다(기획 「무대」).
##
## 🔴🔴 **나무를 돌로 끊어 여러 덩어리로 나눈다. 이게 이 맵에서 제일 중요한 줄이다.**
##  한 덩어리로 이어 두면 **어디에 불이 붙든 결국 전부 탄다** — 실측으로 키 1(문양 없음)·키 4·키 5의
##  최종 나무가 셋 다 48로 수렴했다. 「가라앉은 뒤」 축이 조합을 통째로 구별 못 하게 된다.
##  ⇒ 끊어 두면 **몇 덩어리에 불이 붙었나**가 조합마다 달라진다(GDD 「연료를 어디 두느냐가 곧 레벨 디자인」).
##
## 🔴 **칸막이 두께를 「폭발이 못 뚫는 두께」로 잡지 않았다.** 그 기준은 전제가 틀렸다 —
##  폭발이 칸막이를 뚫어도 그 자리는 **빈칸**이 되고, **불은 빈칸도 못 건넌다**(`net_fire`가 잰다).
##  즉 폭발은 덩어리를 잇지 못하고 **틈을 넓힐 뿐**이라, 돌 한 칸만 있어도 격리는 영구적이다.
## ⇒ 실제로 중요한 기준은 **「작은 점화원이 두 덩어리를 동시에 못 켜는 폭」**이다:
##    룬 흔적 6셀 · 세대 1 폭발의 점화 18셀 ⇒ 칸막이 **3타일 = 24셀**이면 둘 다 못 건넌다.
##    ⚠ 세대 0 폭발의 점화 36셀은 **일부러** 건너간다 — 「큰 폭발은 넓게 지른다」가 그 조합의 성격이다.
##  🔴 **32px 전환에서 이 설계가 ×2로 정확히 보존됐다** — 타일도 반경도 같이 2배가 됐으므로
##   세 부등식(18 < 24 · 6 < 24 · 36 > 24)이 전부 같은 방향으로 산다. **맵을 안 고쳐도 되는 이유다.**
##  🔴 `net_tables`가 덩어리 수와 이 간격을 잰다. 맵을 손보면 거기가 먼저 빨개진다.
##
## 🔴🔴 **지형 높이가 캐릭터의 점프(108px = 3.4타일)를 기준으로 갈린다.** 이게 무대 설계의 전부다:
##   · 기둥 3타일(96px) · 나무 2타일(64px)  → **걸어서/뛰어서 넘는다.** 무대를 돌아다닐 수 있다
##   · 오른쪽 돌 벽 12타일                   → **뚫어야 지나간다.** GDD의 「저 벽을 뚫으면
##     지나갈 수 있다」가 화면에서 세어지는 자리다
##  ⚠ 처음엔 기둥을 6타일로 세웠다가 **캐릭터가 왼쪽 구석에 갇혔다** — 그러면 재는 것 3
##   (「캐릭터를 움직이며 쏘는 것이 손에 붙나」)을 애초에 못 잰다.
const MAP: Array[String] = [
	"############################################################....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#.............................###########..................#....",
	"#..........................................................#....",
	"#................................................##........#....",
	"#................................................##........#....",
	"#.............###########........................##........#....",
	"#................................................##........#....",
	"#................................................##........#....",
	"#................................................##........#....",
	"#................................................##........#....",
	"#................................................##........#....",
	"#................................................##........#....",
	"#.......##.......................................##........#....",
	"#.......##..====###====###====###====###====....##...===...#....",
	"#.......##..====###====###====###====###====....##...===...#....",
	"############################################################....",
	"############################################################....",
	"................................................................",
	"................................................................",
]

const MAP_CHARS: Dictionary = {"#": Mat.STONE, "=": Mat.WOOD}

## 🔴🔴 **디버그 조합 — 이 단계의 측정 장치다.** 조합을 번갈아 쏘는 것이 몇 초 안에 돼야
##  판정 1·2(문양을 넣고 뺀 차이 · 순서를 바꾼 차이)를 잴 수 있다.
##
## 🔴🔴 **4와 5가 이 단계의 전부다.** 같은 문양 둘, 순서만 다르다:
##   4 확산 → 폭발 = 8방향으로 퍼지고 **퍼진 것들이 각자 터진다** → 구멍 여덟
##   5 폭발 → 확산 = 먼저 크게 터지고 **그 자리에서 8갈래로 퍼진다** → 큰 구멍 하나 + 잔불 여덟
##  ⇒ 지형 자국이 다르면 판정 2가 참이다.
##
## 🔴 확산이 두 번 든 목록은 애초에 여기 안 만든다(GDD 「확산은 한 마법진에 하나만」).
##  그래도 `spell_sim.fire()`가 커맨드 경계에서 한 번 더 본다 — 네트워크는 이 표를 안 지난다.
## ⚠ 없는 번호는 표에 없고, HUD가 **있는 번호만** 보여 준다(아래 `_loadout_help`).
const LOADOUTS: Dictionary = {
	1: [],
	2: [Glyph.GLYPH_SPREAD],
	3: [Glyph.GLYPH_BLAST],
	4: [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST],
	5: [Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD],
}

@onready var _renderer: CellRenderer = $CellRenderer
@onready var _input: StageInput = $StageInput
## 🔴🔴 **이 껍데기가 죽는 1번 방식이 `mouse_filter`다.** 발사가 좌클릭인데 HUD가 `Control`이다.
##  `Panel`·`ColorRect`·컨테이너를 뒷판으로 씌우는 순간 기본값 STOP이 좌클릭을 통째로 먹고,
##  **에러는 안 나고 전 그물은 그린이다.** ⇒ HUD 아래 `Control`은 전부 `mouse_filter = 2`(IGNORE).
##  ⚠ 런타임에 훑어서 강제로 고치지 마라 — 그러면 `.tscn`에 적힌 값이 **아무 의미 없는 거짓
##   손잡이**가 되고, 나중에 모달이 STOP으로 뒤를 막아야 할 때 그걸 조용히 뒤엎는다(v1 실측).
@onready var _hud: Label = $HUD/Stats
## 🔴🔴 **체력은 `HUD/Stats` 와 다른 노드다.** 같이 적으면 두 곳이 되는 게 아니라 —
##  `Stats` 는 조립창을 열면 **숨는다**(`_toggle_assembly`). 체력이 거기 있으면 조립 중에
##  「내가 불에 타고 있는지」가 화면에서 통째로 사라진다(기획 「화면」).
@onready var _hp_label: Label = $HUD/Health
## 🔴🔴 **카메라가 캐릭터를 따라간다.** 옛 계약(「흔들림 전용 · 위치가 뷰포트 한가운데라 변환이 항등」)은
##  **죽었다** — 화면 확대율이 2배가 되며 보이는 월드가 960×540으로 줄어 무대(2048×1152)가
##  한 화면에 안 들어간다. 정적 카메라로는 캐릭터가 화면 밖이다.
##
## 🔴 **두 축이 한 노드에 얹힌다**: `position` = 추종(아래 `camera_center`) · `offset` = 흔들림.
##  ⚠ **섞지 마라** — 흔들림을 `position` 에 더하면 다음 프레임 추종이 그걸 덮어써서 흔들림이 사라진다.
## ⚠ 뷰포트 좌표 → 월드 좌표 변환은 **반드시** 캔버스 변환을 되돌려야 한다(`stage_input._to_world`).
##  🔴 **그게 이제 흔들림뿐 아니라 추종에도 걸린다** — 안 되돌리면 조준이 카메라가 움직인 만큼 어긋난다.
@onready var _camera: Camera2D = $Camera2D
## 🔴 조립창은 `HUD`(`CanvasLayer`) 아래다 — `Node2D`로 두면 화면 흔들림에 같이 흔들린다.
##  ⚠ **껍데기는 열고 닫기만 시킨다.** 창이 제 상태를 알고, 좌표도 제 것을 쓴다.
@onready var _circle_window: CircleWindow = $HUD/CircleWindow
@onready var _char_view: CharacterView = $CharacterView
@onready var _spell_view: SpellView = $SpellView
@onready var _blast_fx: BlastFx = $BlastFx

var _grid := CellGrid.new()
var _char := Character.new()
var _spell := SpellSim.new()

## 🔴🔴 **장착 상태의 단일 소스.** 디버그 키도 (앞으로) 조립창도 이것 하나를 만진다 —
##  껍데기가 팩된 목록 사본을 따로 들면 「키를 눌렀는데 총구가 그대로다」가 되고
##  **에러가 하나도 안 난다**(계획 §1).
var _circle := SpellCircle.new()

## ⚠ **프리셋 번호를 안 든다.** 조립창이 문양을 손대는 순간 「마지막으로 누른 번호」와 실제
##  장착이 갈리기 때문이다(계획 §1 · 위험 9) — HUD에서 뺐고, 그러니 들 이유도 없어졌다.
##  🔴 **번호를 지우는 것이 곧 「상태가 하나다」의 마지막 조각이다.**

## 🔴🔴 **세상을 미는 것은 이것 하나다.** 위 셋(`_grid`·`_char`·`_spell`)을 **넘겨서** 든다 —
##  껍데기가 따로 밀면 순서가 두 벌이 되고, 그게 이 파일이 죽는 방식이다.
##  ⚠ 선언 순서가 계약이다. 위 셋보다 먼저 선언하면 `null`을 들고 태어난다.
var _world := WorldStep.new(_grid, _spell, _char)

## 🔴 발사 수와 착탄 수를 **따로** 찍는다 — 둘이 갈라지는 게 곧 진단이다(HUD).
##  발사 0 = 좌클릭이 안 닿는다(`mouse_filter`) · 발사 > 착탄 = 격자 밖으로 나가 소멸했다.
##  ⚠ 발사 수는 `_world` 가 든다 — 커맨드가 실제로 받아들여진 자리가 거기다.
## 🔴🔴 **판정 2의 그물 대리치가 이 숫자다** — 확산→폭발은 8회, 폭발→확산은 1회여야 한다.
##  화면에서 안 갈리는데 이 숫자만 맞으면 그게 이 단계가 멈춰야 하는 신호다.
var _blast_count := 0


func _ready() -> void:
	# 🔴🔴 **글자 크기를 여기서 밀어 넣는다.** `Label` 이 엔진 기본(16)을 쓰는데, 옛 화면 배율 2.0이
	#  그걸 암묵적으로 화면 32px로 만들어 주고 있었다 — 배율이 1.0이 되며 **크기만 안 따라왔다.**
	#  ⚠ **왜 씬이 아니라 여기인지**는 `fx_tuning.HUD_FONT_SIZE` 주석에 있다(연출 상수는 한 파일).
	for label: Label in [_hud, _hp_label]:
		label.add_theme_font_size_override("font_size", Fx.HUD_FONT_SIZE)
	_renderer.setup(_grid)
	# 🔴 총구가 조립 상태를 **읽는다.** 사본을 밀어 넣으면 밀어 넣기를 한 번 깜빡하는 순간
	#  「조합을 바꿨는데 화면이 그대로다」가 되고, 그게 v1이 죽은 방식이다.
	_char_view.setup(_char, _circle)
	# 🔴 조립창도 **같은 것**을 읽는다 — 사본을 주면 「키 4↔5로 그림이 뒤집힌다」가 사라지고,
	#  그게 단일 소스(계획 §1)의 눈에 보이는 유일한 증거다.
	_circle_window.setup(_circle)
	_spell_view.setup(_spell)
	_input.fire_requested.connect(_fire_at)
	_input.reset_requested.connect(reset_stage)
	_input.loadout_requested.connect(_set_loadout)
	# 🔴🔴 **세상을 안 멈춘다** — 여기서 `get_tree().paused`를 건드리지 마라.
	#  창을 연 채로 걷고·쏘고·불이 번지는 것이 기획 판정 4의 전부다.
	_input.assembly_toggled.connect(_toggle_assembly)
	# ⚠ 시작 장착은 **모델의 기본값**이다(`SpellCircle`의 생성자) — 여기서 프리셋을 한 번
	#  밀어 넣던 줄을 지웠다. 밀어 넣으면 「시작 상태」가 두 곳이 되고, 그중 하나만 고치는 날이 온다.
	reset_stage()


## 🔴🔴 **float이 시뮬로 들어가는 유일한 문이고, `Aim.fire_cmd`가 그걸 딱 한 번 닫는다.**
##  지팡이 끝도 마우스도 여기서는 아직 float px다.
## Tab. 🔴 **창을 열면 HUD를 숨긴다**(사용자 판정, 2026-08-03).
##  창이 화면 90%라 `HUD/Stats`를 덮는데, 왼쪽 96px 띠에 **글자 앞부분만 잘려 남아** 창에 붙어 보였다.
##  ⚠ **대가를 알고 고른 것이다** — 조립 중에는 틱·발사 수를 못 본다. 이 HUD는 껍데기의 디버그
##   표시라 본편에 안 남는다(이 파일 첫 줄).
##
## 🔴 **창이 단일 소스다.** HUD 걸쇠를 따로 들면 둘이 갈라져 「닫았는데 HUD가 안 돌아온다」가 되고,
##  그건 껍데기가 죽는 조용한 방식이다. ⇒ 창의 상태를 **읽어서** 정한다.
func _toggle_assembly() -> void:
	_circle_window.toggle()
	_hud.visible = not _circle_window.visible


## 🔴 룬도 문양도 **조립 상태에서 나온다.** 껍데기가 `ELEM_FIRE`를 따로 박으면 룬 자리가
##  거짓 손잡이가 되고, 룬을 바꿀 수 있게 되는 날 발사만 조용히 안 따라온다.
func _fire_at(world_px: Vector2) -> void:
	# 🔴🔴 **못 쏘면 커맨드를 아예 안 만든다.** 만들면 빈 룬이 `fire()`의 룬 검사에 걸려 짖고,
	#  래퍼가 stderr를 실패로 치니 **평소 조작이 그물을 빨갛게 만든다.**
	#  ⚠ 여기서도 짖지 마라 — 빈 룬으로 클릭하는 것은 **정상 입력**이다.
	#   「못 쏜다」는 총구가 꺼지는 것으로 말한다(`character_view`).
	if not _circle.can_fire():
		return
	_world.enqueue(Aim.fire_cmd(
		_char_view.tip_px(), world_px, _circle.element(), _circle.packed_glyphs()))


## ⚠ 표에 없는 번호는 **조용히 무시한다.** 눌러도 아무 일이 없는 게 「빈 조합으로 바뀌는 것」보다
##  낫다 — 후자는 판정 1(문양을 넣고 뺀 차이)과 화면에서 구별이 안 된다.
##  🔴 HUD가 있는 번호를 늘 보여 주므로 사용자에게 그 사실이 보인다.
##
## 🔴🔴 **프리셋은 조립 상태를 덮어쓸 뿐이다** — 상태를 따로 안 든다. 그래서 조립창이 붙어도
##  두 길(키 · 클릭)이 같은 것을 만지고, 총구·HUD가 **저절로** 따라온다(계획 §1).
func _set_loadout(n: int) -> void:
	if not LOADOUTS.has(n):
		return
	var list: Array[int] = []
	list.assign(LOADOUTS[n])
	# 🔴🔴 **프리셋이 진·룬까지 놓는다.** 문양만 놓으면 진을 뺀 사용자가 **갇힌다** —
	#  키 다섯이 전부 죽고 빠져나올 길이 조립창 하나뿐이다.
	#  ⇒ 진까지 놓으므로 **키 1이 곧 조립 리셋**이다.
	# ⚠ 순서(진 → 룬 → 문양)는 `apply_preset` **안에** 갇혀 있다. 여기서 세 줄로 풀면
	#  뒤집는 날 문양이 조용히 사라진다.
	# 🔴 표(`LOADOUTS`)를 안 넓혔다 — 진·룬은 **기본 지급 상수 둘**에서 나온다.
	_circle.apply_preset(
		SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE, Glyph.pack(list))


## 🔴🔴 **여기서 세상을 밀지 마라.** 순서는 `world_step.frame()` 안에 있고, 이 함수가 아는 것은
##  **「틱이 돌았나」** 하나다. 베끼는 순간 그물이 재는 순서와 게임의 순서가 갈린다.
func _physics_process(delta: float) -> void:
	if _world.frame(delta, _input.move_axis(), _input.jump_pressed()):
		_on_ticked()
	_update_hud()


## 틱이 돈 프레임에만 화면을 친다.
## 🔴 **통지는 다음 틱의 `spell.step()` 이 지운다** — 캐릭터가 걸은 뒤에 읽어도 아직 살아 있다.
func _on_ticked() -> void:
	# 🔴 자취는 시뮬이 **돈 뒤**여야 한 틱 낡지 않는다.
	_spell_view.on_tick()

	# 🔴🔴 **폭발 통지는 이 틱 안에서만 유효하다** — 다음 `step()`이 지운다.
	#  여기서 안 읽으면 섬광도 흔들림도 없이 구멍만 남고, **에러는 안 난다.**
	_blast_fx.on_blasts(_spell.get_blast_x(), _spell.get_blast_y(),
		_spell.get_blast_element(), _spell.get_blast_gen())
	_blast_count += _spell.blast_count()

	# 🔴🔴 **격자가 센 값 하나로 판단한다.** 껍데기가 따로 걸쇠를 들면 폭발처럼
	#  **커맨드 큐를 안 지나는 변경**이 그 걸쇠를 조용히 빠뜨려 구멍이 화면에 안 뜬다.
	#  ⚠ 읽으면 0으로 돌아가므로 **매 틱 반드시 한 번** 불러야 한다.
	#  ⇒ 아무것도 안 바뀐 틱에는 업로드를 건너뛴다 = 정지 상태 비용 ≈ 0.
	if _grid.consume_changed() > 0:
		_renderer.refresh()


## 🔴🔴 **렌더 시계는 여기 하나다.** 시뮬은 20Hz인데 화면은 60fps라, 보간 없이는 투사체가
##  틱당 40px씩 순간이동한다.
##  ⚠ **시계를 하나 더 만들지 않는 게 요점이다.** 분주기는 `_world`가 이미 들고 있고,
##   여기서는 그걸 **읽기만** 한다(`phase()`). 뷰가 자기 `delta`를 누산하면 그 순간 시계가 둘이 된다.
func _process(_dt: float) -> void:
	_spell_view.set_render_alpha(float(_world.phase()) / float(Tuning.TICK_DIVIDER))
	# 🔴🔴 **추종은 `position`, 흔들림은 `offset`.** 한 축에 둘을 얹으면 다음 프레임 추종이
	#  흔들림을 덮어써서 **흔들림이 조용히 사라진다.**
	# ⚠ 보이는 크기는 `get_viewport_rect()` 에서 읽는다 — `ProjectSettings` 를 여기서 또 읽으면
	#  창 모드가 바뀌는 날 두 곳이 갈라진다.
	_camera.position = camera_center(_char.center(), get_viewport_rect().size, world_size())
	# 🔴 흔들림은 **카메라 offset**이다. `stage_input._to_world`가 캔버스 변환을 되돌리므로
	#  흔드는 동안에도 조준이 안 어긋난다 — 안 되돌리면 에러 없이 클릭이 엉뚱한 셀로 간다.
	# ⚠ 이 노드의 `_process`와 `blast_fx`의 `_process` 순서는 보장이 없어 **한 프레임 늦을 수 있다** —
	#  0.2초짜리 흔들림에서는 관측 불가다.
	_camera.offset = Vector2(_blast_fx.shake_offset())


## R. 🔴🔴 **장식이 아니다** — 지형 자국이 이 단계의 주 증거인데, 앞 실험의 구멍이 남아 있으면
##  두 조합을 비교할 수가 없다. 리셋 없이는 판정 1·2가 성립하지 않는다.
func reset_stage() -> void:
	_grid.apply(CellGrid.cmd_reset())
	_spell.reset()
	# 🔴 뷰도 같이 비운다. 안 비우면 죽은 투사체의 자취와 섬광이 R을 누를 때마다 쌓인다.
	_spell_view.clear()
	_blast_fx.clear()
	_camera.offset = Vector2.ZERO
	# 🔴 **계수기를 전부 되돌린다.** 하나만 남기면 위 「발사 > 착탄 = 격자 밖 소멸」 진단이
	#  R 한 번에 영영 거짓이 된다 — R은 이 단계의 주 측정 장치라 그 진단이 곧 눈이다.
	#  ⚠ 큐와 발사 수는 `_world` 가 든다 — 여기서 또 만지면 되돌리는 자리가 두 곳이 된다.
	_world.reset()
	_blast_count = 0
	build_terrain_into(_grid)
	_char.place(
		SPAWN_TILE.x * Tuning.TILE_CELLS * Tuning.CELL_PX,
		SPAWN_TILE.y * Tuning.TILE_CELLS * Tuning.CELL_PX)


## 세상의 크기(월드 px). 🔴 **격자에서 나온다** — `MAP` 에서 세면 맵을 줄이는 날 카메라만 안 따라온다.
static func world_size() -> Vector2:
	return Vector2(CellGrid.W, CellGrid.H) * float(Tuning.CELL_PX)


## 🔴🔴 **카메라가 볼 한가운데. 순수 static 이라 그물이 직접 잰다.**
##  씬도 캐릭터도 없이 자리를 넣고 카메라 위치를 받아 볼 수 있다 — `pick_state` 와 같은 어법이다.
##
## 🔴 **세상 밖을 안 보여 준다(클램프).** 안 막으면 무대 가장자리에서 화면에 빈 공간이 들어오고,
##  그 빈 공간은 **격자 밖이라 아무것도 안 그려져** 「세상이 잘렸다」로 보인다.
## ⚠ **세상이 화면보다 좁으면 클램프 구간이 뒤집힌다**(`lo > hi`) — `clampf` 에 그대로 넘기면
##  조용히 한쪽 끝으로 붙는다. 그때는 **세상 한가운데**에 두는 것이 맞다.
##  🔴 지금 세상(2048×1152)이 화면(960×540)보다 크므로 이 갈래는 안 도는데, **안 도는 갈래라
##   틀려도 아무도 안 짖는다** — 그물이 그 갈래를 따로 잰다.
static func camera_center(focus: Vector2, view: Vector2, world: Vector2) -> Vector2:
	return Vector2(_axis_center(focus.x, view.x, world.x), _axis_center(focus.y, view.y, world.y))


static func _axis_center(f: float, v: float, w: float) -> float:
	if w <= v:
		return w * 0.5
	return clampf(f, v * 0.5, w - v * 0.5)


## ASCII 맵 → 커맨드. 🔴 지형도 `apply()`를 지난다 — 외부 이벤트가 커맨드 문을 우회하면
##  나중에 붙는 부수효과(깨우기·통지)를 통째로 건너뛰어 **에러 없이 아무 일도 안 난다.**
##
## 🔴 **static인 이유**: 그물이 **실제로 도는 이 코드와 이 맵**을 세워 잰다.
##  그물이 맵을 복사해 들고 있으면 지형이 바뀔 때 같이 안 늙는다.
static func build_terrain_into(g: CellGrid) -> void:
	if MAP.size() != MAP_H:
		push_error("MAP 행 수가 %d다 — %d여야 한다" % [MAP.size(), MAP_H])
		return
	for ty in MAP.size():
		var row := MAP[ty]
		if row.length() != MAP_W:
			push_error("MAP %d행 폭이 %d다 — %d여야 한다" % [ty, row.length(), MAP_W])
			return
		var tx := 0
		while tx < MAP_W:
			var ch := row[tx]
			if not MAP_CHARS.has(ch):
				tx += 1
				continue
			# 같은 문자가 이어지는 만큼 한 커맨드로 묶는다 — 타일마다 부르면 커맨드가 2,304개다.
			var run := tx
			while run + 1 < MAP_W and row[run + 1] == ch:
				run += 1
			g.apply(CellGrid.cmd_fill(
				tx * Tuning.TILE_CELLS, ty * Tuning.TILE_CELLS,
				run * Tuning.TILE_CELLS + Tuning.TILE_CELLS - 1,
				ty * Tuning.TILE_CELLS + Tuning.TILE_CELLS - 1,
				int(MAP_CHARS[ch])))
			tx = run + 1


func _update_hud() -> void:
	# 🔴 **체력의 단일 소스는 캐릭터다.** 껍데기가 따로 세면 「깎였는데 숫자가 그대로」가 된다.
	# ⚠ 쓰러짐도 **같은 값에서 파생**시킨다 — 걸쇠를 따로 들면 「0인데 안 쓰러졌다」가 화면에 남는다.
	#  🔴 부활 방법을 같이 적는다. 혼자라 일으켜 줄 사람이 없어 **R이 유일한 길**인데,
	#   안 적으면 사용자가 「게임이 멈췄다」로 읽는다.
	_hp_label.text = "체력 %d / %d%s" % [
		_char.hp, Character.MAX_HP, "   쓰러짐 — R로 다시" if _char.downed else "",
	]
	_hud.text = "\n".join([
		"틱 %d · %d Hz (분주기 %d)" % [
			_grid.get_tick(), 60 / Tuning.TICK_DIVIDER, Tuning.TICK_DIVIDER,
		],
		# 🔴 나무가 줄고 「타는 셀」이 0으로 돌아가는 것이 판정 5의 숫자 쪽 증거다.
		"돌 %d · 나무 %d · 타는 셀 %d" % [
			_grid.count_material(Mat.STONE), _grid.count_material(Mat.WOOD),
			_grid.burning_count(),
		],
		"FPS %d" % Engine.get_frames_per_second(),
		"캐릭터 (%d,%d) %s" % [_char.x, _char.y, "접지" if _char.on_ground else "공중"],
		"발사 %d · 비행중 %d · 자취 %d" % [
			_world.fire_count(), _spell.active_count(), _spell_view.trail_count(),
		],
		# 🔴 밀린 수를 같이 찍는다 — **버려지지 않았다**를 사용자가 눈으로 확인하는 자리다.
		#  틱당 폭발 4발 상한에 걸리면 여기가 잠깐 오르고 다음 틱에 0으로 돌아가야 한다.
		"폭발 %d · 섬광 %d · 밀림 %d" % [
			_blast_count, _blast_fx.active_count(), _spell.pending_count(),
		],
		# 🔴 장착 줄은 **`_circle`이 실제로 든 것**에서 나온다. 프리셋 표에서 이름을 뽑으면
		#  조립창이 붙는 날 「그림은 바뀌었는데 HUD는 그대로」가 된다(위험 9).
		# 🔴🔴 **「못 쏜다」를 말하는 세 곳 중 하나다**(총구 · 조립창 · 여기). 좌클릭했는데
		#  아무 일도 안 나는 것을 **사용자가 고장으로 읽는 것**을 막는다.
		# 🔴 **번호를 뺐다.** 조립창이 문양을 손대는 순간부터 「장착 [4]」가 거짓말이 된다(계획 §1).
		#  ⇒ 이름을 **지금 상태에서만** 파생시킨다. 아래 도움말은 「어떤 키가 있나」라 번호가 맞다.
		"장착 %s%s   (%s)" % [
			_glyph_names(_circle.glyph_list()),
			"" if _circle.can_fire() else "  ⚠ 룬 없음 — 쏠 수 없다", _loadout_help(),
		],
		# 🔴 **Tab을 안 적으면 조립창이 「아무도 못 여는 기능」이 된다** — verify-look이 그렇게 적었다.
		"A/D 이동 · Space 점프 · 좌클릭 발사 · Tab 조립창 · R 무대 리셋",
	])


## 🔴 이름을 표에서 **파생**한다 — 손으로 적으면 문양을 늘릴 때 조용히 낡는다.
## 🔴 **장착 줄(지금 든 것)과 도움말 줄(프리셋 표)이 같은 이 함수를 지난다** — 각자 만들면
##  같은 조합이 두 이름으로 불리는 날이 온다.
static func _glyph_names(list: Array) -> String:
	if list.is_empty():
		return "없음 (진 + 룬만)"
	var parts: Array[String] = []
	for id: int in list:
		parts.append(String(Glyph.DEFS[id]["name"]))
	return " → ".join(parts)


static func _loadout_name(n: int) -> String:
	if not LOADOUTS.has(n):
		return "?"
	return _glyph_names(LOADOUTS[n])


## 지금 있는 조합 키만 보여 준다. ⚠ 없는 번호를 안내하면 「눌렀는데 안 먹는다」가 된다.
static func _loadout_help() -> String:
	var keys: Array = LOADOUTS.keys()
	keys.sort()
	var parts: Array[String] = []
	for n: int in keys:
		parts.append("%d %s" % [n, _loadout_name(n)])
	return " · ".join(parts)
