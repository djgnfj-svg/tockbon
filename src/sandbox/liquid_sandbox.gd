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

var _grid := CellGrid.new()

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

# ⚠ 셀 세기는 36,864칸 GDScript 루프라 한 번에 ~520μs다. 둘을 같은 프레임에 돌리면
#  **재는 도구가 재는 대상을 오염시킨다**(최악 튐을 볼 때 1ms를 시뮬 스파이크로 오독한다).
#  ⇒ 20틱 주기로 **엇갈리게** 돌리고 값을 들고 있는다.
var _wet_cached := 0
var _charged_cached := 0


func _ready() -> void:
	_renderer.setup(_grid)
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

	var t0 := Time.get_ticks_usec()
	_last_processed = _grid.step()
	_tick_usec = Time.get_ticks_usec() - t0

	_tick_usec_max = maxi(_tick_usec_max, _tick_usec)
	_usec_window.append(_tick_usec)
	if _usec_window.size() > 60:
		_usec_window.remove_at(0)

	# 🔴 아무 청크도 안 돌았고 커맨드도 없었으면 업로드까지 건너뛴다 ⇒ 정지 상태 비용 ≈ 0.
	if _last_processed > 0 or _render_dirty:
		_renderer.refresh()
		_render_dirty = false

	_update_hud()


## ⚠ **`keep` 갈래는 지금 소비자가 없다** — `enqueue`가 늘 `tick + 1`을 달고 `target`도 같아서
##  전부 이번 틱에 빠진다. 멀티(서버가 미래 틱 커맨드를 보낸다)를 위해 남겨둔 이음매이고,
##  그때까지는 **죽은 분기**라는 걸 알고 봐라(SKILL.md T3).
func _drain_queue() -> void:
	if _queue.is_empty():
		return
	var target := _grid.get_tick() + 1
	var keep: Array[Dictionary] = []
	for e: Dictionary in _queue:
		if int(e["tick"]) <= target:
			_note_strike(e["cmd"])
			_grid.apply(e["cmd"])
			_render_dirty = true
		else:
			keep.append(e)
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


func _reset() -> void:
	_grid.apply(CellGrid.cmd_reset())
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
	_hud.text = "\n".join([
		"틱 %d · %d Hz (분주기 %d)" % [_grid.get_tick(), 60 / _divider, _divider],
		"활성 청크 %d / %d (다음 %d)" % [_last_processed, CellGrid.CHUNK_COUNT, _grid.awake_count()],
		"물 %d · 젖음 %d · 전하 %d" % [
			_grid.count_material(Mat.WATER), _wet_cached, _charged_cached,
		],
		"틱 %d μs (평균 %d · 최대 %d · 60fps 예산 16,700)" % [_tick_usec, avg, _tick_usec_max],
		"FPS %d · 마지막 번개 %s" % [Engine.get_frames_per_second(), strike],
		"좌클릭 칠하기 · 우클릭 번개 · 1물 2돌 3지우개 · [ ] 브러시 · - = 틱 · R 초기화 · ` HUD",
		"재료: %s · 브러시 %d" % [Mat.material_name(_input.selected_mat), _input.brush_radius],
	])
