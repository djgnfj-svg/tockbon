extends Node2D
## 무대 — **껍데기다. 본편에 안 남는다.**
##  시뮬(`src/sim/`)·캐릭터(`src/actor/`)·화면(`src/view/`)과 섞지 마라. 그 경계가 폴더의 요점이다.
##
## 🔴 틱은 `_physics_process` + **정수 분주기**다(`Tuning.TICK_DIVIDER`). float 누산기를 쓰면
##  프레임 시간에 따라 틱 경계가 흔들려 클라마다 다르게 쪼개진다 — 멀티에서 틱 번호는 상태다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const CellRenderer := preload("res://src/view/cell_renderer.gd")
const CharacterView := preload("res://src/view/character_view.gd")
const SpellView := preload("res://src/view/spell_view.gd")
const BlastFx := preload("res://src/view/blast_fx.gd")
const Character := preload("res://src/actor/character.gd")
const Aim := preload("res://src/actor/aim.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const StageInput := preload("res://src/stage/stage_input.gd")

const MAP_W := 64
const MAP_H := 36

## 캐릭터 시작 자리(타일). 왼쪽 빈 바닥 — 기둥·나무 구역·돌 벽이 **오른쪽에 차례로 보이는** 자리다.
const SPAWN_TILE := Vector2i(3, 30)

## 손으로 편집하는 초기 지형. `#` 돌 · `=` 나무 · `.` 빈칸. 타일 하나 = 4×4 셀 = 16px.
##
## 🔴🔴 **보이는 끝 = 타일열 59 · 타일행 33**(셀 x ≤ 239 · y ≤ 134).
##  격자는 256×144셀 = 64×36타일인데 **뷰포트는 960×540 = 240×135셀**이다.
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
##    룬 흔적 3셀 · 세대 1 폭발의 점화 9셀 ⇒ 칸막이 **3타일 = 12셀**이면 둘 다 못 건넌다.
##    ⚠ 세대 0 폭발의 점화 18셀은 **일부러** 건너간다 — 「큰 폭발은 넓게 지른다」가 그 조합의 성격이다.
##  🔴 `net_tables`가 덩어리 수와 이 간격을 잰다. 맵을 손보면 거기가 먼저 빨개진다.
##
## 🔴🔴 **지형 높이가 캐릭터의 점프(54px = 3.4타일)를 기준으로 갈린다.** 이게 무대 설계의 전부다:
##   · 기둥 3타일(48px) · 나무 2타일(32px)  → **걸어서/뛰어서 넘는다.** 무대를 돌아다닐 수 있다
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
## 🔴 카메라는 **화면 흔들림 전용**이다 — 줌도 추적도 없다. 위치가 뷰포트 한가운데(480,270)라
##  흔들리지 않을 때 캔버스 변환이 항등이고, 그래서 붙이기 전과 화면이 한 픽셀도 안 다르다.
##  ⚠ 그래도 뷰포트 좌표 → 월드 좌표 변환은 **반드시** 캔버스 변환을 되돌려야 한다
##   (`stage_input._to_world`). 안 하면 흔드는 동안 조준이 조용히 엉뚱한 데로 간다.
@onready var _camera: Camera2D = $Camera2D
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

## 마지막으로 누른 프리셋 번호. 🔴 **장착 내용이 여기 없는 게 요점이다** — 위 `_circle`이 든다.
##  ⚠ 조립창이 붙으면 이 번호는 거짓말이 된다(계획 §1 · 위험 9). 그때 HUD에서 뺀다.
var _loadout := 1

## 🔴 커맨드는 **「어느 틱에 적용되나」를 달고** 큐에 앉는다. 없으면 나중에 재조정이 불가능하다.
##  싱글에서는 로컬 입력이 채우고 멀티에서는 서버가 채운다 — 적용부 코드는 그대로다.
var _queue: Array[Dictionary] = []

var _phase := 0
## 🔴 발사 수와 착탄 수를 **따로** 찍는다 — 둘이 갈라지는 게 곧 진단이다(HUD).
##  발사 0 = 좌클릭이 안 닿는다(`mouse_filter`) · 발사 > 착탄 = 격자 밖으로 나가 소멸했다.
var _fire_count := 0
## 🔴🔴 **판정 2의 그물 대리치가 이 숫자다** — 확산→폭발은 8회, 폭발→확산은 1회여야 한다.
##  화면에서 안 갈리는데 이 숫자만 맞으면 그게 이 단계가 멈춰야 하는 신호다.
var _blast_count := 0


func _ready() -> void:
	_renderer.setup(_grid)
	# 🔴 총구가 조립 상태를 **읽는다.** 사본을 밀어 넣으면 밀어 넣기를 한 번 깜빡하는 순간
	#  「조합을 바꿨는데 화면이 그대로다」가 되고, 그게 v1이 죽은 방식이다.
	_char_view.setup(_char, _circle)
	_spell_view.setup(_spell)
	_input.fire_requested.connect(_fire_at)
	_input.reset_requested.connect(reset_stage)
	_input.loadout_requested.connect(_set_loadout)
	_set_loadout(_loadout)
	reset_stage()


## 🔴🔴 **float이 시뮬로 들어가는 유일한 문이고, `Aim.fire_cmd`가 그걸 딱 한 번 닫는다.**
##  지팡이 끝도 마우스도 여기서는 아직 float px다.
## 🔴 룬도 문양도 **조립 상태에서 나온다.** 껍데기가 `ELEM_FIRE`를 따로 박으면 룬 자리가
##  거짓 손잡이가 되고, 룬을 바꿀 수 있게 되는 날 발사만 조용히 안 따라온다.
func _fire_at(world_px: Vector2) -> void:
	# 🔴🔴 **못 쏘면 커맨드를 아예 안 만든다.** 만들면 빈 룬이 `fire()`의 룬 검사에 걸려 짖고,
	#  래퍼가 stderr를 실패로 치니 **평소 조작이 그물을 빨갛게 만든다.**
	#  ⚠ 여기서도 짖지 마라 — 빈 룬으로 클릭하는 것은 **정상 입력**이다.
	#   「못 쏜다」는 총구가 꺼지는 것으로 말한다(`character_view`).
	if not _circle.can_fire():
		return
	_enqueue(Aim.fire_cmd(
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
	_loadout = n
	_circle.set_from_packed(Glyph.pack(list))


func _enqueue(cmd: Dictionary) -> void:
	_queue.append({"tick": _grid.get_tick() + 1, "cmd": cmd})


func _physics_process(delta: float) -> void:
	# 🔴🔴 **캐릭터는 60Hz, 시뮬은 20Hz다.** 캐릭터를 틱에 묶으면 조작이 뚝뚝 끊겨
	#  재는 것 3(「손에 붙나」)이 통째로 깨진다. 호스트 권위라 틱에 묶일 이유가 없다(GDD 멀티 표).
	# ⚠ 틱 **뒤에** 도는 이유: 방금 폭발이 바꾼 지형 위를 이번 프레임에 걷는다.
	_tick_sim()
	_char.step(_grid, delta, _input.move_axis(), _input.jump_pressed())
	_update_hud()


func _tick_sim() -> void:
	_phase += 1
	if _phase < Tuning.TICK_DIVIDER:
		return
	_phase = 0

	# 🔴🔴 **틱 순서는 계약이다** — 바꾸면 결과가 달라지고, 멀티에서는 그게 곧 desync다.
	#   1. `_drain_queue()`   외부 커맨드(발사)
	#   2. `_grid.step()`     격자가 한 틱 산다(불)
	#   3. `_spell.step()`    투사체가 **움직인 뒤의 격자**를 상대로 난다
	#   4. `_spell_view.on_tick()`  자취 기록 — 🔴 시뮬이 **돈 뒤**여야 한 틱 낡지 않는다
	_drain_queue()
	_grid.step()
	_spell.step(_grid)
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
##  ⚠ **시뮬에 시계를 하나 더 만들지 않는 게 요점이다.** `_phase`는 이미 있는 정수 분주기고,
##   여기서는 그걸 **읽기만** 한다. 뷰가 자기 `delta`를 누산하면 그 순간 시계가 둘이 된다.
func _process(_dt: float) -> void:
	_spell_view.set_render_alpha(float(_phase) / float(Tuning.TICK_DIVIDER))
	# 🔴 흔들림은 **카메라 offset**이다. `stage_input._to_world`가 캔버스 변환을 되돌리므로
	#  흔드는 동안에도 조준이 안 어긋난다 — 안 되돌리면 에러 없이 클릭이 엉뚱한 셀로 간다.
	# ⚠ 이 노드의 `_process`와 `blast_fx`의 `_process` 순서는 보장이 없어 **한 프레임 늦을 수 있다** —
	#  0.2초짜리 흔들림에서는 관측 불가다.
	_camera.offset = Vector2(_blast_fx.shake_offset())


## ⚠ **`keep` 갈래는 지금 소비자가 없다** — `_enqueue`가 늘 `tick + 1`을 달고 `target`도 같아서
##  전부 이번 틱에 빠진다. 멀티(서버가 미래 틱 커맨드를 보낸다)를 위한 이음매이고,
##  그때까지는 **죽은 분기**라는 걸 알고 봐라.
func _drain_queue() -> void:
	if _queue.is_empty():
		return
	var target := _grid.get_tick() + 1
	var keep: Array[Dictionary] = []
	for e: Dictionary in _queue:
		if int(e["tick"]) > target:
			keep.append(e)
			continue
		var cmd: Dictionary = e["cmd"]
		# 🔴 커맨드가 두 시뮬로 갈린다. **`kind` 키를 공유하지 않는 게 이 분기의 안전장치다** —
		#  같은 키를 쓰면 두 enum의 숫자가 겹쳐 엉뚱한 커맨드가 실행되고, 값이 우연히 유효
		#  범위면 **에러 하나 없이** 발사가 채우기가 된다.
		if cmd.has("spell_kind"):
			if _spell.fire(cmd):
				_fire_count += 1
			continue
		_grid.apply(cmd)
	_queue = keep


## R. 🔴🔴 **장식이 아니다** — 지형 자국이 이 단계의 주 증거인데, 앞 실험의 구멍이 남아 있으면
##  두 조합을 비교할 수가 없다. 리셋 없이는 판정 1·2가 성립하지 않는다.
func reset_stage() -> void:
	_grid.apply(CellGrid.cmd_reset())
	_spell.reset()
	# 🔴 뷰도 같이 비운다. 안 비우면 죽은 투사체의 자취와 섬광이 R을 누를 때마다 쌓인다.
	_spell_view.clear()
	_blast_fx.clear()
	_camera.offset = Vector2.ZERO
	_queue.clear()
	# 🔴 **계수기를 전부 되돌린다.** 하나만 남기면 위 「발사 > 착탄 = 격자 밖 소멸」 진단이
	#  R 한 번에 영영 거짓이 된다 — R은 이 단계의 주 측정 장치라 그 진단이 곧 눈이다.
	_fire_count = 0
	_blast_count = 0
	build_terrain_into(_grid)
	_char.place(
		SPAWN_TILE.x * Tuning.TILE_CELLS * Tuning.CELL_PX,
		SPAWN_TILE.y * Tuning.TILE_CELLS * Tuning.CELL_PX)


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
			_fire_count, _spell.active_count(), _spell_view.trail_count(),
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
		"장착 [%d] %s%s   (%s)" % [
			_loadout, _glyph_names(_circle.glyph_list()),
			"" if _circle.can_fire() else "  ⚠ 룬 없음 — 쏠 수 없다", _loadout_help(),
		],
		"A/D 이동 · Space 점프 · 좌클릭 발사 · R 무대 리셋",
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
