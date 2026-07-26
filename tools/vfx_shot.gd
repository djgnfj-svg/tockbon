## VFX 스트립 스샷 도구 (세94) — **VFX를 만든 에이전트가 자기 결과를 눈으로 보는 「눈」**.
##
## 왜: `takbon-art`는 `export_frame scale 8` → Read로 자기 그림을 보고 스스로 고치는데, VFX는
##   헤드리스가 렌더를 못 봐서 확인이 전부 리드의 F5/MCP로 몰렸다 — 반복 한 번에 사람이 끼는 게
##   「VFX 만드는 게 느리다」의 정체였다. 이 도구는 **한 이펙트의 수명 전체를 격자 PNG 한 장**으로
##   뽑아, Read 한 번으로 "보이나 · 언제 끝나나 · 잘리나"를 스스로 판정하게 한다.
##
## 🔴 `--headless`를 쓰지 마라 — 헤드리스는 렌더를 안 해서 **빈 이미지가 나온다**(tools/shot.gd와
##   같은 규율). 창이 잠깐 뜨는 게 정상이다. 헤드리스로 들어오면 아래 `_init`이 막고 죽는다.
## ✅ `-s`로 뜨므로 세이브 뿌리가 `user://save_test`로 격리된다(세59) — 실플레이 세이브 무해.
## 🔴 오토로드 식별자(EventBus·Db)를 **컴파일 타임에 참조하지 마라** — `-s`는 오토로드 등록보다
##   먼저 컴파일된다. 여기선 `root.get_node("/root/EventBus")` 런타임 조회 + 모듈은 `load()` 지연.
##   (⚠ `Enums`는 오토로드가 아니라 `class_name` 전역 클래스라 const에서 써도 안전하다 —
##    tests/test_gale_boss_auto.gd·test_glyph_data_auto.gd가 같은 방식이다. 그래서 룬·상태 값을
##    **베끼지 않고** 정본을 그대로 참조한다 = 감사 T5 회피.)
##
## 사용:
##   ./Godot_v4.7.1-stable_win64.exe --path . -s res://tools/vfx_shot.gd -- <프리셋> <출력png> [배율] [프레임수] [열수]
## 예:
##   ... -s res://tools/vfx_shot.gd -- impact:water vfx_impact_water.png
##   ... -s res://tools/vfx_shot.gd -- burst:shock  vfx_burst_shock.png
##   ... -s res://tools/vfx_shot.gd -- list          -        (프리셋 표만 찍고 끝)
##
## 프리셋 이름 = `<이름>` 또는 `<이름>:<변종>`(`_`도 같은 구분자로 받는다 — `impact_fire` OK).
##   변종 = 룬 이름(fire·water·wind·bolt·earth·grass) 또는 상태 이름(shock·steam·wet·burn…).
##   🔴 **새 이펙트 = 아래 `PRESETS`에 줄 하나** — 룬 6종을 6줄로 늘리지 말고 `:변종`으로 접는다.
##
## 🔴 크기 제약이 사양의 심장이다: 최종 시트는 **가로 ~1200px 이내**여야 Read 한 번에 판단이 된다.
##   그래서 ⓐ 중앙 **크롭**(이펙트는 중앙 작은 영역에서만 산다) ⓑ **격자**(일렬 금지 — 24장이면
##   13,000px가 된다) ⓒ 배율은 `MAX_SHEET_W`에 맞춰 **자동 계산**(인자로 덮을 수 있다).
##
## 🔴 샘플링은 **프레임 수가 아니라 시간**이다 — 창 모드 fps가 60이든 300이든 프리셋의 `dur`(초)
##   구간을 균등 분할해 찍는다. 프레임 기준으로 짜면 모니터 주사율에 따라 스트립이 통째로 어긋난다.
extends SceneTree

# ── 시트 기하 (연출·판독값 — 밸런스 아님) ──────────────────────────────────────────
const MAX_SHEET_W := 1200    ## 🔴 Read 한 번에 보이는 가로 상한. 배율 자동계산이 이 값을 지킨다
const GAP := 2               ## 칸 사이 구분선 두께(px)
const BG := Color(0.10, 0.09, 0.13)          ## 중립 배경 — 어두운 회보라(마을 TINT_RUINED 결)
const GRID := Color(0.02, 0.02, 0.04)        ## 격자 구분선
const TICK := Color(0.45, 0.80, 0.55, 1.0)   ## 각 칸 하단 진행 막대 = 수명 어디쯤인가
const EDGE := Color(0.40, 0.40, 0.50, 1.0)   ## 칸 네 변 중점의 3px 표식 = 월드 중심 기준선

const WARMUP := 4            ## 무대·vfx가 자리잡을 여유 프레임 (여기까진 안 찍는다)
const TIMEOUT_SEC := 30.0

## 룬 이름표 — 🔴 값은 `Enums.RuneType` 정본을 그대로 참조한다(베끼면 세85 「없는 룬」이 다시 난다).
const RUNE_BY_NAME := {
	&"fire": Enums.RuneType.FIRE, &"water": Enums.RuneType.WATER, &"wind": Enums.RuneType.WIND,
	&"bolt": Enums.RuneType.BOLT, &"earth": Enums.RuneType.EARTH, &"grass": Enums.RuneType.GRASS,
}
## 상태 이름표 — `steam`은 NONE의 별명이다(증기 = 젖음+불의 산물이 「상태 없음」이라 흰 링만 뜬다).
const STATUS_BY_NAME := {
	&"none": Enums.Status.NONE, &"steam": Enums.Status.NONE,
	&"shock": Enums.Status.SHOCK, &"wet": Enums.Status.WET, &"burn": Enums.Status.BURN,
	&"blaze": Enums.Status.BLAZE, &"mud": Enums.Status.MUD, &"root": Enums.Status.ROOT,
	&"overgrowth": Enums.Status.OVERGROWTH, &"vulnerable": Enums.Status.VULNERABLE,
}

const GLYPH_NONE := -1   ## 빈 문양 칸 (RingAssembly.GLYPH_NONE — 캐리어에 「전개 없음」을 물린다)

## 🔴🔴 **프리셋 표 — 새 이펙트 = 여기 줄 하나.**
##   sig      : EventBus 시그널 이름. 비면 `scene`을 인스턴스하는 노드형 프리셋이다.
##   scene    : 노드형일 때 띄울 씬 (setup 인자는 `_spawn_node`의 match가 안다)
##   variant  : &"rune"(룬 변종을 받는다) / &"status"(상태 변종) — `:변종` 접미사가 무엇을 가리키나
##   crop     : 중앙 크롭 한 변(**월드 px**). 이펙트 최대 반경 + 여유로 잡는다
##   cols·frames·dur : 격자 열 수 · 찍을 장수 · 덮을 시간(초, 이펙트 수명보다 살짝 길게)
## ⚠ `dur`은 `src/actors/vfx.gd`·`blast.gd`의 연출 상수(RING_TIME·DECAL_TIME·FLASH_SEC…)에서
##    나온 값이다 — 그 상수를 늘리면 여기도 늘려야 마지막 칸이 「이미 끝난 뒤」로 남는다.
const PRESETS := {
	# 발사 순간 총구 — 작은 진 링(MUZZLE_RADIUS 12) + 조준 부채 틱(DIST 10 + LEN 9, ×END_SCALE 1.4
	# ≈ 27px). crop 64 = ±32이라 틱이 다 든다. MUZZLE_TIME 0.10 → dur 0.14로 「꺼진 뒤」까지 본다.
	&"muzzle": {
		"sig": &"ring_cast_requested", "variant": &"rune",
		"crop": 64, "cols": 6, "frames": 12, "dur": 0.14,
		"desc": "발사 순간 총구 — 작은 진 링 + 조준(→) 부채 틱",
	},
	# 착탄 두 겹 — 바닥 데칼(DECAL_TIME 0.22 · r20 · 세로 0.4 눌림) + 솟는 플레어
	# (FLARE_H 24 + FLARE_RISE 10 = 위로 34px). 세로가 최대치라 crop 76 = ±38(여유 4px)으로 잡았다.
	&"impact": {
		"sig": &"spell_impact", "variant": &"rune",
		"crop": 76, "cols": 5, "frames": 20, "dur": 0.26,
		"desc": "탄이 박혔다 — 바닥 데칼 + 솟는 플레어(오블리크 두 겹)",
	},
	# 반응 버스트 — 팽창 링(RING_TIME 0.28). SHOCK이면 중심 스파크가 얹히고 NONE(증기)은 흰 링만.
	# ⚠ `radius`는 **시트 판독용 값**이지 게임 반경이 아니다(실게임 감전 연쇄는 balance가 쥔다) —
	#   실반경으로 찍고 싶으면 crop을 함께 키워라(안 키우면 링이 잘려 「반경 밖」 판단이 거짓이 된다).
	&"burst": {
		"sig": &"reaction_burst", "variant": &"status", "radius": 40.0,
		"crop": 96, "cols": 5, "frames": 20, "dur": 0.32,
		"desc": "반응이 한 자리에서 터졌다 — 팽창 링(+SHOCK 중심 스파크)",
	},
	# 연쇄 아크 — from→to 지그재그 번개(ARC_TIME 0.15, 스케일 트윈 없이 알파만 꺼진다).
	# 두 끝점이 ±45라 crop 104 = ±52. ⚠ 지그재그는 스폰 때 한 번만 굴려 스트립 내내 모양이 같다.
	&"chain": {
		"sig": &"reaction_chain", "variant": &"status",
		"from": Vector2(-45.0, 12.0), "to": Vector2(45.0, -12.0),
		"crop": 104, "cols": 4, "frames": 12, "dur": 0.18,
		"desc": "상태가 A→B로 튀었다 — 두 점을 잇는 지그재그 아크",
	},
	# 폭발 (변형형 문양 EXPLODE의 결과물) — 코어 섬광 + 팽창 링, FLASH_SEC 0.30. 링이 r45까지 자란다.
	&"blast": {
		"scene": "res://src/spell/blast.tscn", "variant": &"rune", "radius": 45.0,
		"crop": 104, "cols": 4, "frames": 20, "dur": 0.34,
		"desc": "폭발 — 안쪽 코어 섬광이 먼저 꺼지고 링이 파문으로 남는다",
	},
	# 캐리어 트레일 — 진(볼)이 날며 뒤에 Line2D 잔상을 남긴다. 🔴 유일하게 **움직이는** 프리셋이라
	# 왼쪽(-30)에서 출발해 오른쪽으로 지난다. 크롭은 고정이다(카메라가 안 따라간다).
	# ⚠ speed·dur·from은 **크롭 폭과 한 덩어리**다: 이동거리(speed×dur=60)에 볼 스프라이트 폭
	#   (오블리크 파이어볼은 꼬리가 그림에 박혀 있어 **중심 왼쪽으로 ≈42px**)을 더한 값이 crop 안에
	#   들어야 한다. 늘릴 땐 셋을 같이 만져라 — 안 그러면 첫/끝 칸에서 볼이 잘리고,
	#   **잘린 줄 모르고 「트레일이 짧다」고 오판하게 된다**(실제로 -50·160에서 밟았다).
	&"carrier": {
		"scene": "res://src/spell/ring_carrier.tscn", "variant": &"rune",
		"from": Vector2(-24.0, 0.0), "speed": 120.0, "life": 0.6,
		"crop": 144, "cols": 4, "frames": 20, "dur": 0.50,
		"desc": "진(볼)이 날아가며 남기는 트레일 — 움직이는 프리셋(크롭 고정)",
	},
}

var _out := ""
var _name := &""          ## 프리셋 기본 이름
var _p: Dictionary = {}   ## 고른 프리셋
var _rune: int = Enums.RuneType.FIRE
var _status: int = Enums.Status.SHOCK
var _crop := 96           ## 중앙 크롭 한 변(월드 px)
var _cols := 6
var _frames := 18
var _dur := 0.26
var _zoom := 0            ## 월드 px → 출력 px 배율 (0 = 자동)
var _cell := 0            ## 칸 한 변(출력 px) = _crop * _zoom

var _stage: Node2D = null
## ⚠ 오토로드·모듈 인스턴스는 **의도적으로 동적 타입**이다 — 타입을 적으면 컴파일 타임에
##   그 스크립트를 참조하게 되어 `-s` 오토로드 함정을 밟는다(tests/*_auto.gd와 같은 관행).
var _bus = null

var _frame := 0
var _armed := false
var _pending := false
var _done := false
var _elapsed := 0.0
var _px_scale := 0.0      ## 이미지 px / 월드 px (창 1920 ÷ 뷰포트 960 = 2.0)
var _shots: Array[Image] = []
var _times: Array[float] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "list":
		_print_table()
		quit(0)
		return
	if args.size() < 2:
		push_error("[vfx_shot] 인자: <프리셋> <출력png> [배율] [프레임수] [열수]")
		_print_table()
		quit(1)
		return

	# 🔴 1번 실패 = 헤드리스로 돌려 **빈 이미지**를 얻고 "돌아간다"고 믿는 것. 여기서 끊는다.
	if DisplayServer.get_name() == "headless":
		push_error("[vfx_shot] --headless로는 렌더가 없어 빈 이미지가 나온다. 옵션을 빼고 다시 돌려라.")
		quit(1)
		return

	if not _select_preset(args[0]):
		quit(1)
		return
	_out = args[1]
	if args.size() >= 3:
		_zoom = maxi(int(args[2]), 0)
	if args.size() >= 4:
		_frames = maxi(int(args[3]), 1)
	if args.size() >= 5:
		_cols = maxi(int(args[4]), 1)
	_resolve_geometry()
	# 🔴 무대는 여기서 못 짓는다 — `-s`의 `_init`은 **오토로드 등록보다 먼저** 돈다
	#   (`/root/EventBus`가 아직 없고 `get_node`는 "active scene tree 밖"으로 에러난다).
	#   그래서 `_process` 첫 프레임에 짓는다 — tests/*_auto.gd가 `await process_frame`으로 하는 것과 같다.


## `impact:water` / `impact_water` / `impact` 를 모두 받는다 — 표를 룬마다 늘리지 않기 위한 접기.
func _select_preset(raw: String) -> bool:
	var base := raw
	var variant := ""
	for sep in [":", "_"]:
		var i := raw.find(sep)
		if i > 0:
			base = raw.substr(0, i)
			variant = raw.substr(i + 1)
			break
	_name = StringName(base)
	if not PRESETS.has(_name):
		push_error("[vfx_shot] 모르는 프리셋: %s" % raw)
		_print_table()
		return false
	_p = PRESETS[_name]
	_crop = int(_p.get("crop", 96))
	_cols = int(_p.get("cols", 6))
	_frames = int(_p.get("frames", 18))
	_dur = float(_p.get("dur", 0.26))
	if variant.is_empty():
		return true
	var vn := StringName(variant)
	if RUNE_BY_NAME.has(vn):
		_rune = int(RUNE_BY_NAME[vn])
		return true
	if STATUS_BY_NAME.has(vn):
		_status = int(STATUS_BY_NAME[vn])
		return true
	push_error("[vfx_shot] 모르는 변종: %s (룬 %s · 상태 %s)"
		% [variant, str(RUNE_BY_NAME.keys()), str(STATUS_BY_NAME.keys())])
	return false


## 🔴 배율 자동계산 — `cols * (crop*zoom + GAP) + GAP <= MAX_SHEET_W`를 만족하는 최대 정수 배율.
## 인자로 배율을 주면 그대로 쓰되 상한을 넘으면 경고만 하고 진행한다(의도적으로 크게 뽑을 때가 있다).
func _resolve_geometry() -> void:
	if _zoom <= 0:
		var budget := (MAX_SHEET_W - GAP) / _cols - GAP
		_zoom = clampi(budget / _crop, 1, 16)
	_cell = _crop * _zoom
	var w := _cols * (_cell + GAP) + GAP
	if w > MAX_SHEET_W:
		push_warning("[vfx_shot] 시트 가로 %dpx > 권장 %dpx — Read 한 번에 안 보일 수 있다"
			% [w, MAX_SHEET_W])


## 무대 = 중립 배경 한 장 + `src/actors/vfx.gd` 하나.
## 🔴 `vfx.gd`의 핸들러는 전부 `get_tree().current_scene`에 add_child한다 — **current_scene이
##   비어 있으면 `if scene == null: return`으로 조용히 아무것도 안 그려진다.** 여기가 1번 함정이라
##   무대를 root에 붙인 뒤 반드시 `current_scene`으로 지정한다(아래 검산도 함께 둔다).
func _build_stage() -> void:
	# 🔴 vsync를 끄고 fps 상한을 푼다 — 시간 기준 샘플링이라 프레임이 촘촘할수록 스트립이 정확해진다
	# (muzzle은 0.14초에 12장이라 60fps로는 같은 프레임이 겹쳐 찍힌다).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	create_timer(TIMEOUT_SEC).timeout.connect(func() -> void:
		push_error("[vfx_shot] %.0f초 초과 — %d/%d장에서 멈췄다" % [TIMEOUT_SEC, _shots.size(), _frames])
		quit(1))

	_stage = Node2D.new()
	_stage.name = "VfxStage"
	root.add_child(_stage)
	current_scene = _stage
	if current_scene != _stage:
		push_error("[vfx_shot] current_scene 지정 실패 — vfx가 아무것도 안 그린다")
		quit(1)
		return

	var rect := root.get_visible_rect()
	var bg := ColorRect.new()
	bg.color = BG
	bg.position = rect.position
	bg.size = rect.size
	bg.z_index = -100
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 게임이 아니라 도구지만 규약을 따른다
	_stage.add_child(bg)

	_bus = root.get_node_or_null(^"/root/EventBus")
	if _bus == null:
		push_error("[vfx_shot] EventBus 오토로드 없음 — --path .로 프로젝트를 지정했나?")
		quit(1)
		return

	# 🔴 모듈 스크립트는 컴파일 타임이 아니라 여기서 load() — 오토로드 등록 뒤라 안전하다.
	var vfx_script := load("res://src/actors/vfx.gd") as GDScript
	var vfx := vfx_script.new() as Node2D
	vfx.name = "Vfx"
	_stage.add_child(vfx)


func _process(delta: float) -> bool:
	if _done:
		return true
	_frame += 1
	if _frame == 1:
		_build_stage()   # 🔴 오토로드는 첫 프레임부터 살아 있다 (`_init`엔 아직 없다)
		return false
	if not _armed:
		if _frame < WARMUP:
			return false
		_armed = true
		_elapsed = 0.0
		_fire_preset()
		_want_shot()   # t=0 = 터진 그 프레임
		return false

	_elapsed += delta
	var have := _shots.size()
	if not _pending and have < _frames and _elapsed >= _sample_t(have):
		_want_shot()

	if _shots.size() >= _frames:
		_done = true
		_compose()
		quit(0)
	return false


## i번째 샘플의 목표 시각 — [0, dur]을 균등 분할한다.
func _sample_t(i: int) -> float:
	if _frames <= 1:
		return 0.0
	return _dur * float(i) / float(_frames - 1)


## 프리셋을 화면 중앙에 터뜨린다. 시그널형이면 EventBus emit, 노드형이면 씬 인스턴스.
func _fire_preset() -> void:
	var c := root.get_visible_rect().get_center()
	var sig := StringName(_p.get("sig", &""))
	match sig:
		&"ring_cast_requested":
			# 🔴 조립 사전을 직접 만들지만 **발사가 아니라 연출 재생**이다 — 여기엔
			#   ring_spell_system이 없어 아무것도 안 쏜다(to_assembly 계약과 무관).
			_bus.ring_cast_requested.emit({"rune": _rune}, c, Vector2.RIGHT)
		&"spell_impact":
			_bus.spell_impact.emit(c, _rune)
		&"reaction_burst":
			_bus.reaction_burst.emit(c, float(_p.get("radius", 40.0)), _status)
		&"reaction_chain":
			var f: Vector2 = _p.get("from", Vector2(-45.0, 0.0))
			var t: Vector2 = _p.get("to", Vector2(45.0, 0.0))
			_bus.reaction_chain.emit(c + f, c + t, _status)
		_:
			_spawn_node(c)


func _spawn_node(c: Vector2) -> void:
	var path := str(_p.get("scene", ""))
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("[vfx_shot] 씬 로드 실패: %s" % path)
		quit(1)
		return
	var n := ps.instantiate() as Node2D
	_stage.add_child(n)
	var off: Vector2 = _p.get("from", Vector2.ZERO)
	n.global_position = c + off
	match _name:
		# blast.setup(피해, 룬, 상태, 상태세기, 반경) — 피해 0이라 무대에 적이 없어도 무해하다
		&"blast":
			n.setup(0.0, _rune, Enums.Status.NONE, 0.0, float(_p.get("radius", 45.0)))
		# carrier.setup(문양칸, 각도, 속도, 수명, 피해, 룬, 상태, 상태세기) — 문양 없음(전개 0)
		&"carrier":
			var ring: Array = []
			for _i in 8:
				ring.append(GLYPH_NONE)
			n.setup(ring, 0.0, float(_p.get("speed", 220.0)), float(_p.get("life", 0.6)),
				0.0, _rune, Enums.Status.NONE, 0.0)
		_:
			push_error("[vfx_shot] 노드형 프리셋 %s의 setup 배선이 없다" % _name)


## 🔴 그린 직후에 읽어야 한다 — 이 시그널 없이 읽으면 **한 프레임 전(또는 빈) 화면**이 나온다.
func _want_shot() -> void:
	_pending = true
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)


func _grab() -> void:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	if _px_scale <= 0.0:
		# 창 1920 ÷ 뷰포트 960 = 2.0 (stretch canvas_items). 크롭을 **월드 px**으로 재기 위한 환산.
		_px_scale = float(img.get_width()) / maxf(root.get_visible_rect().size.x, 1.0)
	var src := maxi(int(round(float(_crop) * _px_scale)), 1)
	src = mini(src, mini(img.get_width(), img.get_height()))
	var x := (img.get_width() - src) / 2
	var y := (img.get_height() - src) / 2
	var cell := img.get_region(Rect2i(x, y, src, src))
	if cell.get_width() != _cell:
		cell.resize(_cell, _cell, Image.INTERPOLATE_NEAREST)
	_shots.append(cell)
	_times.append(_elapsed)
	_pending = false


## 격자로 이어붙인다 — 읽는 순서는 **왼→오, 위→아래**. 각 칸 하단의 초록 막대가 수명 진행도다.
func _compose() -> void:
	var n := _shots.size()
	var rows := int(ceil(float(n) / float(_cols)))
	var stride := _cell + GAP
	var w := _cols * stride + GAP
	var h := rows * stride + GAP
	var sheet := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(GRID)
	for i in n:
		var col := i % _cols
		var row := i / _cols
		var x := GAP + col * stride
		var y := GAP + row * stride
		sheet.blit_rect(_shots[i], Rect2i(0, 0, _cell, _cell), Vector2i(x, y))
		_draw_center_marks(sheet, x, y)
		# 진행 막대 — 이 칸이 수명의 몇 %인가 (첫 칸에 이미 끝났나 / 끝까지 안 꺼지나를 즉시 읽는다)
		var bar := int(round(float(i + 1) / float(n) * float(_cell)))
		for px in bar:
			sheet.set_pixel(x + px, y + _cell - 2, TICK)
			sheet.set_pixel(x + px, y + _cell - 1, TICK)
	var e := sheet.save_png(_out)
	if e != OK:
		push_error("[vfx_shot] 저장 실패 %s (err %d)" % [_out, e])
		return
	print("[vfx_shot] saved %s  %dx%d" % [_out, w, h])
	print("[vfx_shot] preset=%s%s  crop=%d월드px  zoom=x%d  cell=%dpx  cols=%d rows=%d  frames=%d  dur=%.2fs"
		% [_name, _variant_label(), _crop, _zoom, _cell, _cols, rows, n, _dur])
	var ts := PackedStringArray()
	for t in _times:
		ts.append("%.3f" % t)
	print("[vfx_shot] 샘플 시각(s): " + ", ".join(ts))


## 칸 네 변 중점에 3px 표식 — 월드 중심 기준선(이펙트가 중앙에 있나·크롭에 잘리나를 눈으로 잰다).
## 🔴 이펙트 위에 안 그린다(변에만) — 가이드가 연출로 오독되면 도구가 거짓말을 하게 된다.
func _draw_center_marks(sheet: Image, x: int, y: int) -> void:
	var m := _cell / 2
	for k in 3:
		sheet.set_pixel(x + m, y + k, EDGE)
		sheet.set_pixel(x + m, y + _cell - 3 - k, EDGE)
		sheet.set_pixel(x + k, y + m, EDGE)
		sheet.set_pixel(x + _cell - 1 - k, y + m, EDGE)


func _variant_label() -> String:
	if StringName(_p.get("variant", &"")) == &"status":
		return ":status=%d" % _status
	return ":rune=%d" % _rune


func _print_table() -> void:
	print("[vfx_shot] 프리셋 (이름[:변종]):")
	for k: StringName in PRESETS:
		var p: Dictionary = PRESETS[k]
		print("  %-9s %-6s crop=%d cols=%d frames=%d dur=%.2fs  — %s"
			% [k, "(%s)" % str(p.get("variant", "")), int(p.get("crop", 0)),
				int(p.get("cols", 0)), int(p.get("frames", 0)), float(p.get("dur", 0.0)),
				str(p.get("desc", ""))])
	print("  변종 — 룬: %s" % ", ".join(PackedStringArray(RUNE_BY_NAME.keys())))
	print("  변종 — 상태: %s" % ", ".join(PackedStringArray(STATUS_BY_NAME.keys())))
