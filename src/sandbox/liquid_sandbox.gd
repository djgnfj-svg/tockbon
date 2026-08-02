extends Node2D
## 액체 셀 샌드박스 — **프로토타입 껍데기다. 본편에 안 남는다.**
##  시뮬 코어(`src/world/cells/`)와 섞지 마라. 그 경계가 이 폴더의 요점이다.
##
## 재는 것 셋: ① 4px 자유 확산이 픽셀 물처럼 보이나 ② 상태 상호작용의 **순서**가 손에 잡히나 ③ 성능이 나오나.
##
## 🔴 틱은 `_physics_process` + **정수 분주기**다. float 누산기를 쓰면 프레임 시간에 따라
##  틱 경계가 흔들려 클라마다 다르게 쪼개진다 — 멀티에서 틱 번호는 상태다(설계 §6·§8 ③).

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const CellRenderer := preload("res://src/world/cells/cell_renderer.gd")
const SandboxInput := preload("res://src/sandbox/sandbox_input.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const SpellSim := preload("res://src/world/spell/spell_sim.gd")
const SpellView := preload("res://src/world/spell/spell_view.gd")
const BlastFx := preload("res://src/world/spell/blast_fx.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")

## 1자 = 16px 지형 타일 = 4×4 셀. 🔴 16px 정렬이 그림에서 공짜로 나온다(GDD 「해상도」).
const TILE_CELLS := 4
const MAP_W := 64
const MAP_H := 36

## 60의 약수만 가능하다(정수 분주기의 대가). 1=60틱 … 6=10틱.
const DIVIDER_MIN := 1
const DIVIDER_MAX := 6

## 손으로 편집하는 초기 지형. `#` 돌 · `~` 물 · `.` 빈칸.
##
## 🔴🔴 **보이는 끝 = 타일열 59 · 타일행 33**(셀 x ≤ 239 · y ≤ 134).
##  격자는 256×144셀 = 64×36타일인데 **뷰포트는 960×540 = 240×135셀**이다.
##  오른쪽 4타일열·아래 2타일행은 **화면 밖 여백**이고, 여백 자체는 설계 확정이라 없애지 않는다.
##  ⚠ 처음엔 바닥 슬래브와 오른쪽 벽을 그 여백에 세워 놨다 — **바닥이 통째로 화면 밖**이라
##   가장자리로 떨어진 물이 안 보이는 데 고였고, 측정 ①을 보는 사람에게는 「물이 없어진다」로 읽힌다.
##  ⇒ **무대는 전부 보이는 끝 안에 있어야 한다.** 맵을 고칠 때 그 선을 넘지 마라.
## ⚠ 폭·행 수가 어긋나면 `build_terrain_into()`가 짖는다 — 조용히 밀리면 원인 찾기가 지옥이다.
const MAP: Array[String] = [
	"#..........................................................#....",
	"#.........................~~~~~~~~.........................#....",
	"#.........................~~~~~~~~.........................#....",
	"#.........................~~~~~~~~.........................#....",
	"#.........................~~~~~~~~.........................#....",
	"#..........................................................#....",
	"#......##############..................##############......#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"#..................##..................##..................#....",
	"#...................##................##...................#....",
	"#....................##..............##....................#....",
	"#.....................##............##.....................#....",
	"#......................##..........##......................#....",
	"#.......................##........##.......................#....",
	"#........................##......##........................#....",
	"#.........................##....##.........................#....",
	"#..........................##..##..........................#....",
	"#..........................##..##..........................#....",
	"#..........................##..##..........................#....",
	"#..........................##..##..........................#....",
	"############...............##..##..........................#....",
	"#..........................................................#....",
	"#....#................................................#....#....",
	"#....#.......############.............................#....#....",
	"#....#................................................#....#....",
	"#....#................................................#....#....",
	"#....##################################################....#....",
	"#..........................................................#....",
	"#..........................................................#....",
	"############################################################....",
	"############################################################....",
	"................................................................",
	"................................................................",
]

const MAP_CHARS: Dictionary = {"#": Mat.STONE, "~": Mat.WATER}

@onready var _renderer: CellRenderer = $CellRenderer
@onready var _input: SandboxInput = $SandboxInput
@onready var _hud: Label = $HUD/Stats
@onready var _view: SpellView = $SpellView
@onready var _fx: BlastFx = $BlastFx
## 🔴🔴 **카메라는 화면 흔들림 전용이다** — 줌도 추적도 없다. 위치가 뷰포트 한가운데(480,270)라
##  흔들리지 않을 때 캔버스 변환이 항등이고, 그래서 붙이기 전과 화면이 한 픽셀도 안 다르다.
##  ⚠ **그래도 `sandbox_input._to_cell()`은 바뀌어야 했다** — 카메라가 있는 한 뷰포트 좌표가
##   더는 월드 좌표가 아니다. 안 바꾸면 흔드는 동안 클릭이 조용히 엉뚱한 셀로 간다.
@onready var _camera: Camera2D = $Camera2D

var _grid := CellGrid.new()
var _spell := SpellSim.new()

## 🔴 커맨드는 **「어느 틱에 적용되나」를 달고** 큐에 앉는다(설계 §8 ③).
##  없으면 나중에 재조정(reconciliation)이 불가능하다. 싱글에서는 로컬 입력이 채우고,
##  멀티에서는 서버가 채운다 — `_grid.apply()` 호출부의 코드는 그대로다.
var _queue: Array[Dictionary] = []

var _phase := 0
var _divider := 3  # 60 / 3 = 20틱 (GDD 「20 안팎에서 시작」)
var _render_dirty := true

# 계측 — 🔴 무너지는 건 평균이 아니라 **최대**다. 둘 다 들고 있는다.
var _tick_usec := 0
var _tick_usec_max := 0
var _usec_window: Array[int] = []
var _last_processed := 0

# 번개 피드백 (M4) — 「닿았나」와 「마른 곳이었나」를 화면에서 가르기 위한 것.
var _strike_count := 0
var _last_strike := Vector2i(-1, -1)
var _last_strike_conducted := false

## 발사 피드백. 🔴 번개 피드백과 **같은 이유로 있다** — 화면에 흔적이 0이면
##  「좌클릭이 안 닿는다」(`mouse_filter`)와 「닿았는데 화면 밖에서 터졌다」를 가릴 수가 없다.
##  ⚠ 격자 256×144인데 보이는 건 240×135이라, 벽을 뚫은 뒤부터 투사체가 여백으로 나간다.
##   그때 사용자에게는 **「안 터졌다」로 보인다** — 이 줄이 유일한 구분자다.
var _fire_count := 0
var _blast_count := 0
var _last_blast := Vector2i(-1, -1)
var _last_blast_label := ""
## 🔴🔴 **「숫자는 두 배인데 화면은 그대로」를 사용자가 직접 대조하는 자리다.**
##  v1은 위력 78 → 157인데 화면에서 바뀐 게 0개였고, 그걸 아무도 숫자로 못 봤다.
## ⚠ `count_material`은 네이티브라 ~5μs다 — `count_flag`(GDScript 루프 ~520μs)를 여기 넣지 마라.
var _last_blast_cells := 0
## 위 줄과 대조할 기준값. 🔴 **문자열에 박지 않는다 — `SIM_TIERS`에서 파생한다.**
##  이 줄의 유일한 존재 이유가 「사용자가 화면과 숫자를 대조하는 것」인데, `rd`를 조이는 순간
##  (그게 이 프로토타입에서 가장 자주 할 일이다) 박아 둔 기준은 **옛 숫자로 조용히 거짓말**하고,
##  사용자는 그걸 「시뮬이 4배를 안 낸다」로 읽는다. 재는 도구가 낡는 게 제일 나쁘다(T5).
var _tier_reference := ""

# ⚠ 셀 세기는 36,864칸 GDScript 루프라 한 번에 ~520μs다. 둘을 같은 프레임에 돌리면
#  **재는 도구가 재는 대상을 오염시킨다**(최악 튐을 볼 때 1ms를 시뮬 스파이크로 오독한다).
#  ⇒ 20틱 주기로 **엇갈리게** 돌리고 값을 들고 있는다.
var _wet_cached := 0
var _charged_cached := 0


func _ready() -> void:
	_renderer.setup(_grid)
	_view.setup(_spell)
	# 총구는 이 프로토타입에만 있다(캐릭터가 없어서 고정점이다). 본편에서는 손이 총구다.
	_fx.muzzle_visible = true
	# 🔴 `_process`를 **`BlastFx`보다 뒤에** 돌린다 — 안 그러면 이번 프레임에 계산된 흔들림을
	#  카메라가 다음 프레임에 받아서 첫 프레임 하나를 놓친다(실측: 20프레임 중 19프레임만 움직였다).
	process_priority = 1
	_tier_reference = _build_tier_reference()
	_input.command_requested.connect(enqueue)
	_input.reset_requested.connect(_reset)
	_input.divider_nudged.connect(_nudge_divider)
	_input.hud_toggled.connect(_toggle_hud)
	_reset()


## 입력이 격자를 직접 만지는 걸 막는 유일한 문. 🔴 `_mat[i] = WATER`를 밖에서 하면 그게 재작성 자리다.
func enqueue(cmd: Dictionary) -> void:
	_queue.append({"tick": _grid.get_tick() + 1, "cmd": cmd})


func _physics_process(_delta: float) -> void:
	_phase += 1
	if _phase < _divider:
		return
	_phase = 0

	_drain_queue()

	# 🔴🔴 **틱 순서는 계약이다** — 바꾸면 결과가 달라지고, 멀티에서는 그게 곧 desync다.
	#   1. `_drain_queue()`  외부 커맨드(FIRE·PAINT·STRIKE·RESET)
	#   2. `_grid.step()`    셀이 움직인다
	#   3. `_spell.step()`   투사체가 **움직인 뒤의 격자**를 상대로 난다. 폭발도 여기서 적용된다
	#  ⚠ 3이 2 뒤라서 **구멍은 이번 틱에 보이고, 쏟아지는 물은 다음 틱에 흐르기 시작한다.**
	#   50ms 차이라 눈에 안 보이지만, 순서를 뒤집으면 폭발이 「한 틱 낡은 격자」를 보게 된다.
	# ⚠ 계측은 **둘을 합쳐** 잰다 — 프레임을 무너뜨리는 건 `_physics_process` 한 번의 총합이다.
	# 🔴 돌 개수를 **계측 창 밖에서** 먼저 재 둔다. `step()`은 돌을 만들지도 지우지도 않으므로
	#  이 값이 곧 「폭발 직전의 돌」이고, 차이가 이번 틱에 부순 칸 수다.
	#  ⚠ 창 안에 넣으면 재는 도구가 재는 대상을 오염시킨다(`_wet_cached` 주석과 같은 이유).
	var stone_before := _grid.count_material(Mat.STONE)
	var t0 := Time.get_ticks_usec()
	_last_processed = _grid.step()
	var blasts := _spell.step(_grid)
	_tick_usec = Time.get_ticks_usec() - t0
	# 🔴🔴 **폭발 통지가 `_view.on_tick()`보다 **앞이어야** 한다 — 이것도 계약이다.**
	#  터진 투사체는 이미 시뮬에서 사라졌고, 그 「마지막으로 보이던 자리」를 들고 있는 건
	#  `_view`의 자취뿐인데 `on_tick()`이 죽은 id의 자취를 지운다.
	#  ⇒ 순서를 뒤집으면 착탄 줄기가 **에러 없이 통째로 사라진다**(`Tuning.STREAK_FRAC` 주석).
	if not blasts.is_empty():
		_note_blasts(blasts, stone_before - _grid.count_material(Mat.STONE))
	# 🔴 자취는 시뮬이 **한 틱 돈 뒤에** 기록한다 — 앞에 두면 자취가 통째로 한 틱 낡는다.
	_view.on_tick()

	_tick_usec_max = maxi(_tick_usec_max, _tick_usec)
	_usec_window.append(_tick_usec)
	if _usec_window.size() > 60:
		_usec_window.remove_at(0)

	# 🔴 아무 청크도 안 돌았고 커맨드도 없었으면 업로드까지 건너뛴다 ⇒ 정지 상태 비용 ≈ 0.
	if _last_processed > 0 or _render_dirty:
		_renderer.refresh()
		_render_dirty = false

	_update_hud()


## 🔴🔴 **렌더 시계는 여기 하나다.** 시뮬은 20Hz인데 화면은 60fps라, 보간 없이는 투사체가
##  틱당 40px씩 순간이동한다 — 「세게 보이나」를 재는 프로토타입에서 그건 치명적이다.
##  ⚠ **시뮬에 시계를 하나 더 만들지 않는 게 요점이다.** `_phase`는 이미 있는 정수 분주기고,
##   여기서는 그걸 **읽기만** 한다. 뷰가 자기 `delta`를 누산하면 그 순간 시계가 둘이 된다.
## ⚠ 대가 = **렌더가 정확히 한 틱(50ms) 뒤에 있다.** 투사체에서는 안 보인다.
func _process(_dt: float) -> void:
	_view.set_render_alpha(float(_phase) / float(_divider))
	# 🔴 흔들림은 **카메라 offset**에만 얹는다. HUD는 `CanvasLayer`라 안 흔들린다(그게 맞다).
	#  ⚠ `_fx`도 자기 `_process`에서 흔들림을 갱신하므로 노드 순서에 따라 한 프레임 늦을 수 있다 —
	#   16ms짜리라 관측 불가다.
	_camera.offset = Vector2(_fx.shake_offset())
	# 총구가 **쏘기 전에** 고른 위력만큼 밝다 — v1이 죽은 항목(「총구가 위력을 안 따라간다」)의 자리.
	_fx.muzzle_px = _cell_center_px(_input.fire_origin.x, _input.fire_origin.y)
	_fx.muzzle_tier = _input.power_tier
	_fx.muzzle_element = _input.element


## 위력 단마다 「마른 돌이면 몇 칸이 사라지나」. 🔴 `SIM_TIERS`의 `rd`에서 **정수 원반 칸수를
##  세어** 만든다 — 부팅 1회고, P3(r=24)도 2,401회 루프라 공짜다.
## ⚠ 실제 파괴 칸수는 이 값보다 **약간 작다**(격자 가장자리 · 물 · 이미 빈 칸). 그래서 「기준」이다.
func _build_tier_reference() -> String:
	var out: Array[String] = []
	for t in Tuning.SIM_TIERS.size():
		var r := int(Tuning.SIM_TIERS[t]["rd"])
		var n := 0
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					n += 1
		out.append("P%d %d" % [t + 1, n])
	return "  ↳ 마른 돌 기준 %s칸 (단마다 ×4)" % " · ".join(out)


## 셀 좌표 → 그 셀의 **한가운데** 화면 px. 🔴 모서리를 쓰면 섬광이 반 칸씩 왼쪽 위로 쏠린다.
func _cell_center_px(x: int, y: int) -> Vector2:
	return Vector2(
		(float(x) + 0.5) * CellRenderer.CELL_PX,
		(float(y) + 0.5) * CellRenderer.CELL_PX)


## ⚠ **`keep` 갈래는 지금 소비자가 없다** — `enqueue`가 늘 `tick + 1`을 달고 `target`도 같아서
##  전부 이번 틱에 빠진다. 멀티(서버가 미래 틱 커맨드를 보낸다)를 위해 남겨둔 이음매이고,
##  그때까지는 **죽은 분기**라는 걸 알고 봐라(SKILL.md T3).
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
		#  같은 키를 쓰면 두 enum의 숫자가 겹쳐 `CellGrid.apply`가 엉뚱한 커맨드를 실행하고,
		#  값이 우연히 유효 범위면 **에러 하나 없이** 발사가 페인트가 된다.
		if cmd.has("spell_kind"):
			if _spell.fire(cmd):
				_fire_count += 1
				# 🔴 총구 섬광은 **커맨드가 아니다** — 발사가 받아들여진 그 자리에서 즉시
				#  로컬로 친다(설계 §9). 멀티에서도 이 줄은 선을 안 넘는다.
				_fx.add_muzzle(
					_cell_center_px(int(cmd["ox"]), int(cmd["oy"])),
					int(cmd["tier"]), int(cmd["element"]))
			continue
		_note_strike(cmd)
		_grid.apply(cmd)
		_render_dirty = true
	_queue = keep


## 🔴 마른 곳 번개는 규칙상 조용히 아무 일도 안 하는 게 맞다. **그런데 화면에 흔적이 0이면
##  「우클릭이 안 닿는다」와 「닿았는데 마른 곳이다」를 가릴 수가 없다** — `mouse_filter` 진단과
##  정면으로 얽히고, 측정 ②(「순서가 다르면 결과가 다르다」)도 헛침이 헛침으로 보여야 손에 잡힌다.
## ⚠ 전도 판정은 시뮬에 물어본다(`conducts_at`) — 껍데기가 다시 구현하면 규칙이 두 벌이 된다.
func _note_strike(cmd: Dictionary) -> void:
	if int(cmd.get("kind", -1)) != CellGrid.CMD_STRIKE:
		return
	_strike_count += 1
	_last_strike = Vector2i(int(cmd["x"]), int(cmd["y"]))
	_last_strike_conducted = _grid.conducts_at(_last_strike.x, _last_strike.y)


## 🔴 이번 틱에 실제로 터진 것만 온다 — 상한(틱당 4회)에 걸려 밀린 폭발은 다음 틱에 온다.
## ⚠ **`_render_dirty`를 여기서 켜야 한다.** 폭발이 격자를 바꿨는데 `_grid.step()`이 0청크를
##  돌려주면(잠든 격자에 쏜 경우) 렌더 업로드를 통째로 건너뛰어 **구멍이 화면에 안 뜬다.**
##  에러는 안 나고 「발사가 안 먹는다」로만 보인다.
## ⚠ `destroyed`는 **이번 틱 전체의 합**이다 — 한 틱에 4발까지 터질 수 있어서 라벨(마지막 하나)과
##  숫자의 주인이 다를 수 있다. 한 발씩 쏘면 일치한다.
func _note_blasts(blasts: Array[Dictionary], destroyed: int) -> void:
	_render_dirty = true
	_blast_count += blasts.size()
	var b: Dictionary = blasts[blasts.size() - 1]
	_last_blast = Vector2i(int(b["x"]), int(b["y"]))
	_last_blast_label = "P%d %s" % [int(b["tier"]) + 1, Tuning.ELEM_NAMES[int(b["element"])]]
	_last_blast_cells = destroyed
	# 🔴 연출은 **터진 것 전부**에 건다. 마지막 하나만 걸면 한 틱에 여러 발일 때
	#  「쏘는 것 ≠ 보이는 것」이 된다(T8) — 그리고 눈으로는 절대 못 가른다.
	for e: Dictionary in blasts:
		# 🔴 「마지막으로 보이던 자리」를 같이 넘겨 착탄 줄기를 잇는다. ⚠ `_view.on_tick()`이
		#  죽은 id의 자취를 지우기 전에 꺼내야 한다 — 위 `_physics_process`의 순서 주석이 그것이다.
		_fx.add_blast(
			_cell_center_px(int(e["x"]), int(e["y"])), int(e["tier"]), int(e["element"]),
			_view.last_trail_px(int(e["id"])))


func _reset() -> void:
	_grid.apply(CellGrid.cmd_reset())
	_spell.reset()
	# 🔴 뷰도 같이 비운다. 안 비우면 죽은 투사체의 자취 딕셔너리가 R을 누를 때마다 쌓인다 —
	#  id가 0부터 다시 시작하는데 옛 id가 남아 있으면 **없는 투사체의 자취가 그려진다.**
	_view.clear()
	_fx.clear()
	_queue.clear()
	_tick_usec_max = 0
	_usec_window.clear()
	_build_terrain()
	_render_dirty = true


func _build_terrain() -> void:
	build_terrain_into(_grid)


## ASCII 맵 → 커맨드. 🔴 지형도 `apply()`를 지난다 — 외부 이벤트가 커맨드 문을 우회하면
##  청크 깨우기를 건너뛰어 **에러 없이 아무 일도 안 난다**(설계 §5).
##
## 🔴 **static인 이유**: 그물(`test_cell_grid_auto.gd`)이 **실제로 도는 이 코드와 이 맵**을 세워
##  「씬이 잠드나」를 잰다. 그물이 맵을 복사해 들고 있으면 지형이 바뀔 때 같이 안 늙는다.
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
			var run := tx
			while run + 1 < MAP_W and row[run + 1] == ch:
				run += 1
			var mat := int(MAP_CHARS[ch])
			g.apply(CellGrid.cmd_fill(
				tx * TILE_CELLS, ty * TILE_CELLS,
				run * TILE_CELLS + TILE_CELLS - 1, ty * TILE_CELLS + TILE_CELLS - 1,
				mat))
			tx = run + 1


func _nudge_divider(delta: int) -> void:
	_divider = clampi(_divider + delta, DIVIDER_MIN, DIVIDER_MAX)
	_phase = 0
	_tick_usec_max = 0


func _toggle_hud() -> void:
	_hud.visible = not _hud.visible


func _update_hud() -> void:
	if not _hud.visible:
		return
	var phase := _grid.get_tick() % 20
	# 🔴 비싼 셋을 **같은 프레임에 몰지 않는다** — 위 `_wet_cached` 주석의 이유.
	if phase == 0:
		_wet_cached = _grid.count_flag(Mat.FLAG_WET)
	elif phase == 10:
		_charged_cached = _grid.count_flag(Mat.FLAG_CHARGED)
	if phase != 0 and phase != 10:
		return

	var avg := 0
	for v: int in _usec_window:
		avg += v
	if not _usec_window.is_empty():
		avg /= _usec_window.size()

	var strike := "없음"
	if _strike_count > 0:
		strike = "#%d (%d,%d) 전도=%s" % [
			_strike_count, _last_strike.x, _last_strike.y,
			"예" if _last_strike_conducted else "아니오(마른 곳)",
		]
	# 🔴 발사 수와 폭발 수를 **따로** 찍는다 — 둘이 갈라지는 게 곧 진단이다.
	#  발사 0 = 좌클릭이 안 닿는다(`mouse_filter`) · 발사 > 폭발 = 화면 밖으로 나가 소멸했다.
	# 🔴🔴 **파괴 칸 수가 「강한 마법이 세게 보이나」의 대조군이다.** 기준값 113 / 441 / 1,793을
	#  같이 찍어서, 숫자가 4배로 뛰는데 화면이 그대로인지를 사용자가 **직접** 볼 수 있게 한다.
	#  v1은 위력이 두 배가 되는데 화면에서 바뀐 게 0개였고, 그걸 숫자로 본 사람이 없었다.
	var blast := "없음"
	if _blast_count > 0:
		blast = "%s (%d,%d) 파괴 %d칸" % [
			_last_blast_label, _last_blast.x, _last_blast.y, _last_blast_cells,
		]
	_hud.text = "\n".join([
		"틱 %d · %d Hz (분주기 %d)" % [_grid.get_tick(), 60 / _divider, _divider],
		"활성 청크 %d / %d (다음 %d)" % [_last_processed, CellGrid.CHUNK_COUNT, _grid.awake_count()],
		"물 %d · 젖음 %d · 전하 %d" % [
			_grid.count_material(Mat.WATER), _wet_cached, _charged_cached,
		],
		"틱 %d μs (평균 %d · 최대 %d · 60fps 예산 16,700)" % [_tick_usec, avg, _tick_usec_max],
		"FPS %d · 마지막 번개 %s" % [Engine.get_frames_per_second(), strike],
		"발사 %d · 폭발 %d · 비행중 %d · 마지막 폭발 %s" % [
			_fire_count, _blast_count, _spell.active_count(), blast,
		],
		_tier_reference,
		"좌클릭 발사 · 우클릭 칠하기 · 중클릭 발사원점 · 1/2/3 위력 · Q물 E번개 · L 직접번개",
		"4물 5돌 6지우개 · [ ] 브러시 · - = 틱 · R 초기화 · ` HUD",
		"위력 P%d · 원소 %s · 원점 (%d,%d) · 브러시: %s r%d" % [
			_input.power_tier + 1, Tuning.ELEM_NAMES[_input.element],
			_input.fire_origin.x, _input.fire_origin.y,
			Mat.material_name(_input.selected_mat), _input.brush_radius,
		],
	])
