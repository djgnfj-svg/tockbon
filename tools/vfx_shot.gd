## VFX 스트립 스샷 도구 — 한 이펙트의 수명 전체를 격자 PNG 한 장으로 뽑아, Read 한 번으로
## "보이나 · 언제 끝나나 · 잘리나"를 스스로 판정하게 한다(헤드리스가 렌더를 못 봐서 생긴 도구다).
##
## 🔴 `--headless`를 쓰지 마라 — 렌더를 안 해서 **빈 이미지가 나온다**. 창이 잠깐 뜨는 게 정상이고,
##   헤드리스로 들어오면 `_init`이 막고 죽는다. `-s`라 세이브 뿌리도 격리된다.
## 🔴 오토로드 식별자(EventBus·Db)를 **컴파일 타임에 참조하지 마라** — `-s`는 오토로드 등록보다
##   먼저 컴파일된다(`Enums`는 `class_name` 전역이라 const에서 써도 안전하다).
##
## 사용:
##   ./Godot_v4.7.1-stable_win64.exe --path . -s res://tools/vfx_shot.gd -- <프리셋> <출력png> [배율] [프레임수] [열수] [크롭]
##   ... -- impact:water vfx_impact_water.png   /   ... -- list -   (프리셋 표만 찍는다)
## 🔴 `[크롭]`(월드 px)은 **변종이 크기를 바꾸는 프리셋** 때문에 있다 — 잘린 줄 모르고 판단하는 게
##   이 도구의 최악 실패다.
## 프리셋 이름 = `<이름>` 또는 `<이름>:<변종>`(`_`도 같은 구분자). 변종 = 룬·상태·구성(plain·mid·full)·적 id.
##   🔴 **새 이펙트 = 아래 `PRESETS`에 줄 하나** — 룬 6종을 6줄로 늘리지 말고 `:변종`으로 접는다.
## 🔴 최종 시트는 **가로 ~1200px 이내**여야 Read 한 번에 판단이 된다 — 중앙 크롭 + 격자 + 배율 자동계산.
## 🔴 샘플링은 프레임이 아니라 **시간**이다 — 프레임 기준이면 모니터 주사율에 따라 스트립이 통째로 어긋난다.
extends SceneTree

# ── 시트 기하 (연출·판독값 — 밸런스 아님) ──────────────────────────────────────────
const MAX_SHEET_W := 1200    ## 🔴 Read 한 번에 보이는 가로 상한. 배율 자동계산이 이 값을 지킨다
const GAP := 2               ## 칸 사이 구분선 두께(px)
const BG := Color(0.10, 0.09, 0.13)          ## 중립 배경 — 어두운 회보라(마을 TINT_RUINED 결)
const GRID := Color(0.02, 0.02, 0.04)        ## 격자 구분선
const TICK := Color(0.45, 0.80, 0.55, 1.0)   ## 각 칸 하단 진행 막대 = 수명 어디쯤인가
const EDGE := Color(0.40, 0.40, 0.50, 1.0)   ## 칸 네 변 중점의 3px 표식 = 월드 중심 기준선

## 🔴 `floor` 전용 — 시전이 끝난 뒤 **퍼지며 꺼지는** 마무리까지 볼 여유(초).
##   `floor_circle.RELEASE_TIME`(0.16)에서 나온 값이다 — 그걸 늘리면 여기도 늘려라.
const FLOOR_TAIL := 0.22
const WARMUP := 4            ## 무대·vfx가 자리잡을 여유 프레임 (여기까진 안 찍는다)
const TIMEOUT_SEC := 30.0

## 룬 이름표 — 🔴 값은 `Enums.RuneType` 정본을 그대로 참조한다(베끼면 「없는 룬」이 다시 난다).
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

## 조립 「구성」 변종 — `floor` 프리셋이 **무엇을 조립했나**를 고른다.
## 왜 세 번째 변종 축인가: 발밑 마법진의 합격 기준이 「조립 구성이 눈으로 읽히나」라 **문양 3개짜리와
## 8개·2층짜리를 나란히 뽑아 비교**해야 판정이 된다(룬 변종으로는 안 된다). 값 = 세이브가 싣는 모양 그대로.
## 🔴 **점수는 여기 안 적는다** — `RingPower.assembled_score`가 런타임에 낸다(베끼면 시트가 조용히 거짓말한다).
const BUILD_BY_NAME := {
	# 맨 진 — 문양 0 · 1층 · 룬 하나. 설계 §0 표의 「위력 78」 자리다.
	&"plain": {
		"jin": &"jin_single", "runes": [Enums.RuneType.FIRE],
		"rings": [[-1, -1, -1, -1, -1, -1, -1, -1]],
	},
	# 문양 3 · 1층 — 흔한 중간 조립.
	&"mid": {
		"jin": &"jin_single", "runes": [Enums.RuneType.WATER],
		"rings": [[Enums.GlyphCode.RADIATE, Enums.GlyphCode.RADIATE, Enums.GlyphCode.RADIATE,
			-1, -1, -1, -1, -1]],
	},
	# 🔴 문양 8 · 2층 · **융합진(룬 둘)** — 설계 §0 표의 「위력 157」 자리. 층 1 = 발산 5,
	# 층 2 = 응집 3이라 **모티프가 층마다 다른 것**까지 한 장에서 보인다.
	&"full": {
		"jin": &"jin_fuse", "runes": [Enums.RuneType.FIRE, Enums.RuneType.WATER],
		"rings": [
			[Enums.GlyphCode.RADIATE, Enums.GlyphCode.RADIATE, Enums.GlyphCode.RADIATE,
				Enums.GlyphCode.RADIATE, Enums.GlyphCode.RADIATE, -1, -1, -1],
			[Enums.GlyphCode.GATHER, Enums.GlyphCode.GATHER, Enums.GlyphCode.GATHER,
				-1, -1, -1, -1, -1],
		],
	},
}

## 🔴🔴 **프리셋 표 — 새 이펙트 = 여기 줄 하나.**
##   sig      : EventBus 시그널 이름. 비면 `scene`을 인스턴스하는 노드형 프리셋이다.
##   scene    : 노드형일 때 띄울 씬 (setup 인자는 `_spawn_node`의 match가 안다)
##   variant  : &"rune"(룬) / &"status"(상태) / &"build"(조립 구성) / &"enemy"(적 id) — `:변종`이 가리키는 축
##   crop     : 중앙 크롭 한 변(**월드 px**). 이펙트 최대 반경 + 여유로 잡는다
##   cols·frames·dur : 격자 열 수 · 찍을 장수 · 덮을 시간(초, 이펙트 수명보다 살짝 길게)
##   bg       : (선택) 이 프리셋만의 배경색. 🔴 **바닥에 깔리는 연출은 어두운 중립 배경에서 판정하면
##              거짓말이 된다** — 실무대가 밝은 낮 풀밭이면 여기서도 그 위에 얹어 봐야 한다
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
	# 착탄 두 겹 — 바닥 데칼(DECAL_TIME 0.22) + 솟는 플레어. `score`가 시그널에 실려 크기를 판다(1.0 = 최대치).
	# 🔴 crop 104(±52)는 퍼펙트 세로 최대 ≈49px에서 나왔다 — 작으면 플레어 머리가 **잘린 채** 찍혀
	#   "충분히 커졌나" 판단이 거짓이 된다. 무난한 쪽을 보려면 `score`만 0.70으로 내려라.
	# ⚠ dur 0.24 — 데칼이 0.22에 끝나 그보다 길면 마지막 칸이 빈 화면이다.
	&"impact": {
		"sig": &"spell_impact", "variant": &"rune", "score": 1.0,
		"crop": 104, "cols": 5, "frames": 20, "dur": 0.24,
		"desc": "탄이 박혔다 — 바닥 데칼 + 솟는 플레어(등급이 크기를 판다)",
	},
	# 🔴 발밑 바닥 마법진 — **「내가 조립한 그 마법진」이 시전 동안 열린다.** 변종 = 구성 또는 룬.
	#   🔴 판정은 **나란히 뽑아** 한다: `floor:plain`과 `floor:full`이 한눈에 달라야 성공이다.
	# ⚠ crop 148은 퍼펙트 반경(FLOOR_RADIUS_PERFECT × RELEASE_SCALE ≈ 68)에서 나왔다 — 그 상수를
	#   키우면 여기도 키워라(안 키우면 퍼지는 순간이 잘린다). dur은 시전 시간(balance)이 쥔다.
	&"floor": {
		"sig": &"ring_cast_started", "variant": &"build", "build": &"full",
		"crop": 148, "cols": 4, "frames": 12, "dur": 0.90,
		"desc": "시전 중 발밑에 열리는 조립본 그대로의 마법진 (변종: plain·mid·full)",
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
	# 캐리어 트레일 — 진(볼)이 날며 Line2D 잔상을 남긴다. 🔴 유일하게 **움직이는** 프리셋이라
	# 왼쪽에서 출발해 오른쪽으로 지난다(카메라가 안 따라가 크롭은 고정이다).
	# ⚠ speed·dur·from은 **크롭 폭과 한 덩어리**다: 이동거리 + 볼 스프라이트 폭(꼬리가 그림에 박혀
	#   중심 왼쪽으로 ≈42px)이 crop 안에 들어야 한다. 안 그러면 볼이 잘리고 「트레일이 짧다」고 오판한다.
	&"carrier": {
		"scene": "res://src/spell/ring_carrier.tscn", "variant": &"rune",
		"from": Vector2(-24.0, 0.0), "speed": 120.0, "life": 0.6,
		"crop": 144, "cols": 4, "frames": 20, "dur": 0.50,
		"desc": "진(볼)이 날아가며 남기는 트레일 — 움직이는 프리셋(크롭 고정)",
	},
	# 🔴 늑대 돌진 **예고 범위** — 재는 문장은 하나다: "윈드업 동안 바닥에 닿을 범위가 뜨고,
	#   돌진이 시작되면 꺼지고, 몸이 그 범위 안을 쓸고 간다."
	# 🔴 **적 프리셋이라 시그널이 없다** — 몸을 세우고 스텁을 사거리 안에 두면 `_ai_charge`가 스스로
	#   APPROACH→WINDUP→CHARGE를 밟는다. 손으로 상태를 세우면 도구가 상태기계를 우회해 거짓말할 수 있다.
	# ⚠ 기하는 `hound.tres`와 한 덩어리다(from→target 110px < charge_trigger_range 120).
	#   `charge_speed`·`dash_sec`·`attack_range`를 키우면 **잘린다** — 키운 만큼 crop도 키워라.
	# 🔴 변종 = 적 id: 덩치 큰 몸에서 **범위가 같이 커지는지**가 드러난다(그려진 범위 ≠ 판정 범위 = 예고의 거짓말).
	&"charge": {
		"scene": "res://src/field/forest_enemy.tscn", "variant": &"enemy", "enemy": &"hound",
		"from": Vector2(-70.0, 0.0), "target": Vector2(40.0, 0.0),
		"bg": Color(0.29, 0.62, 0.22),
		"crop": 208, "cols": 4, "frames": 12, "dur": 1.05,
		"desc": "늑대 돌진 예고 — 윈드업 동안 바닥에 뜨는 「닿을 범위」 (변종: 적 id)",
	},
	# 🔴 죽음 = **몸이 마나로 터진다.** 재는 문장: "몸이 그 자리에서 푸르게 터지고, 파편이 사방으로·
	#   위로 흩어져 사라진다." 정본 문장은 `src/actors/mana_burst.gd` 머리말이다.
	# 🔴 **적 프리셋이라 시그널이 없다** — `take_hit`으로 **실제로 죽인다.** 죽음 경로를 통째로 지나므로
	#   드롭 굴리기·`enemy_died`까지 실무대와 같은 순서다(`_spawn_death_burst`만 부르면 도구가 거짓말한다).
	# 🔴 **드롭이 같은 시트에 찍히는 게 의도다** — 마나는 퍼지고 드롭은 모여 궤적이 정반대다.
	#   `target`을 자석 반경(72px)에 딱 둔 이유가 그 대비다. 스텁을 멀리 옮기면 대비가 사라진다.
	# 🔴 crop 288(±144)은 「이 도구가 만들 수 있는 가장 큰 몸」의 파편 최대 반경 ≈126px에서 나온 산수다
	#   (몸 한 변 × (SHARD_DIST_FRAC + SHARD_DRIFT_FRAC) × 보스 배수 × (1 + SHARD_SPREAD) + 파편 끝).
	#   🔴 그 넷 중 아무거나 키우면 여기도 키워라 — 안 키우면 파편이 **잘린 채** 찍히고
	#   **잘린 줄 모르고 「덜 흩어진다」고 오판**한다(도구의 최악 실패).
	# ⚠ 실게임 뱀 보스는 재현이 안 된다 — 여기선 `snake_boss.tscn`의 씬 scale 1.5가 안 실린다.
	# ⚠ 히트스톱이 여기엔 없다(무대에 `juice.gd`가 없다) — 실게임 처치의 체감은 F5가 판정한다.
	&"death": {
		"scene": "res://src/field/forest_enemy.tscn", "variant": &"enemy", "enemy": &"hound",
		"from": Vector2(0.0, 0.0), "target": Vector2(72.0, 0.0),
		"bg": Color(0.29, 0.62, 0.22),
		"crop": 288, "cols": 4, "frames": 16, "dur": 0.62,
		"desc": "적이 죽었다 — 몸이 마나로 터져 사방으로 흩어진다 (변종: 적 id)",
	},
}

var _out := ""
var _name := &""          ## 프리셋 기본 이름
var _p: Dictionary = {}   ## 고른 프리셋
var _rune: int = Enums.RuneType.FIRE
## 🔴 룬 변종을 **명시로 줬나** — `floor`는 구성(build)이 룬 목록을 쥐므로, 이게 없으면
## `floor:water`가 **조용히 무시**된다(도구가 거짓말하는 자리다). 참이면 구성은 두고 색만 바꾼다.
var _rune_given := false
var _status: int = Enums.Status.SHOCK
var _build := &"full"     ## 조립 구성 변종 (BUILD_BY_NAME 키) — `floor` 프리셋 전용
## 적 변종 — `charge` 프리셋 전용. 🔴 **이름표를 안 만든다**: `data/enemies/<id>.tres`를 그대로
## 받아 `Db`가 판정하게 둔다(모르는 id면 `forest_enemy._ready`가 push_warning으로 운다).
var _enemy_id := &"hound"
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
		push_error("[vfx_shot] 인자: <프리셋> <출력png> [배율] [프레임수] [열수] [크롭]")
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
	if args.size() >= 6:
		_crop = maxi(int(args[5]), 8)
	_resolve_geometry()
	# 🔴 무대는 여기서 못 짓는다 — `-s`의 `_init`은 **오토로드 등록보다 먼저** 돈다
	#   (`/root/EventBus`가 아직 없다). 그래서 `_process` 첫 프레임에 짓는다.


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
	_build = StringName(_p.get("build", &"full"))
	_enemy_id = StringName(_p.get("enemy", &"hound"))
	if variant.is_empty():
		return true
	var vn := StringName(variant)
	# 🔴 적 변종은 **표를 안 거친다** — 룬 이름표보다 먼저 가로챈다(적 id가 우연히 룬 이름과
	#   겹쳐도 프리셋이 쥔 축이 이긴다). 유효성은 `Db`가 판정한다.
	if StringName(_p.get("variant", &"")) == &"enemy":
		_enemy_id = vn
		return true
	if RUNE_BY_NAME.has(vn):
		_rune = int(RUNE_BY_NAME[vn])
		_rune_given = true
		return true
	if STATUS_BY_NAME.has(vn):
		_status = int(STATUS_BY_NAME[vn])
		return true
	if BUILD_BY_NAME.has(vn):
		_build = vn
		return true
	push_error("[vfx_shot] 모르는 변종: %s (룬 %s · 상태 %s · 구성 %s)"
		% [variant, str(RUNE_BY_NAME.keys()), str(STATUS_BY_NAME.keys()),
			str(BUILD_BY_NAME.keys())])
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
		# 🔴 프리셋이 배경을 덮을 수 있다 — 바닥에 깔리는 연출은 어두운 중립 위에서 늘 잘 보여서
		#   도구가 거짓말한다(실무대는 밝은 낮 풀밭이다).
		# ⚠ `charge`의 값은 실측 스샷에서 고른 화면색 근사다 — 풀색을 조이면 여기도 눈으로 맞춰라.
	bg.color = _p.get("bg", BG)
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
			# 🔴 3번째 인자 = 그 마법진의 조립 점수(0~1). 기본 1.0(퍼펙트) = **연출이 가장 커지는 값**이라
			#   `crop`이 잘리는지도 여기서 드러난다. 무난한 쪽은 프리셋의 `score`를 0.70 언저리로 내려라.
			_bus.spell_impact.emit(c, _rune, float(_p.get("score", 1.0)))
		&"ring_cast_started":
			_fire_floor_circle(c)
		&"reaction_burst":
			_bus.reaction_burst.emit(c, float(_p.get("radius", 40.0)), _status)
		&"reaction_chain":
			var f: Vector2 = _p.get("from", Vector2(-45.0, 0.0))
			var t: Vector2 = _p.get("to", Vector2(45.0, 0.0))
			_bus.reaction_chain.emit(c + f, c + t, _status)
		_:
			_spawn_node(c)


## 🔴 발밑 마법진 한 판 — **시전 시작 → duration → 발사**까지 한 장에 담는다.
## 조립 사전을 손으로 만들지만 **발사가 아니라 연출 재생**이다(무대에 `ring_spell_system`이 없다).
## 🔴 **점수·시전 시간은 `RingPower` 정본이 낸다** — 여기 숫자를 적으면 balance를 조일 때 시트가 거짓말한다.
## 🔴 `-s` 오토로드 함정 회피 — `RingPower`는 `class_name`이 없어 여기서 **런타임 load()**로 문다.
func _fire_floor_circle(c: Vector2) -> void:
	var b: Dictionary = BUILD_BY_NAME.get(_build, BUILD_BY_NAME[&"full"])
	var rings: Array = b.get("rings", [])
	var runes: Array = b.get("runes", [Enums.RuneType.FIRE])
	if _rune_given:
		runes = [_rune]   # 룬 변종을 주면 **구성은 그대로 두고 색만** 바꾼다(무시하면 도구가 거짓말한다)
	var rp := load("res://src/core/ring_power.gd")
	var layers: Array = RingDesign.layers_of(rings)
	var glyphs := 0
	for layer_v in layers:
		for g in (layer_v as Array):
			if int(g) != GLYPH_NONE:
				glyphs += 1
	var score: float = rp.assembled_score(glyphs, layers.size())
	var dur: float = rp.cast_time_of(score)
	# 🔴 차징이 0이면 `dur`도 0이고 `vfx`의 `duration <= 0` 가드가 발밑 원을 아예 안 연다
	#   ⇒ **시트가 통째로 빈 화면인데 에러가 0이다**(도구가 조용히 거짓말하는 자리).
	# 🔴 프리셋을 지우지 않는 이유 = 스위치 대칭이다. balance의 `cast_time_*`을 되돌리면 그대로 산다.
	if dur <= 0.0:
		push_warning("[vfx_shot] floor 프리셋이 잠들었다 — 차징이 0이라 발밑 원이 안 열린다(세112). "
			+ "보려면 balance의 cast_time_plain_sec/cast_time_perfect_sec를 0.15/0.75로 되돌려라.")
		printerr("[vfx_shot] floor: 차징 0 → 빈 시트가 나온다. 위 경고를 봐라.")
	var asm := {
		"rune": int(runes[0]), "runes": runes, "jin": b.get("jin", &"jin_single"),
		"rings": rings, "score": score,
	}
	# 🔴 수명이 등급마다 다른 유일한 프리셋이라 `dur`을 **실측으로 덮는다** — 고정값이면 시전이 짧을 때
	#   시트의 3/4이 빈 칸이 되고, balance를 조일 때마다 프리셋이 낡는다.
	_dur = dur + FLOOR_TAIL
	_bus.ring_cast_started.emit(asm, c, dur)
	# 🔴 시전이 끝나면 실제로 탄이 나간다 — **퍼지며 꺼지는 마무리**까지 한 장에 담기게 예약한다.
	#   (안 쏘면 마지막 칸들이 「열린 채 멈춘 원」이라 릴리스 연출을 영영 못 본다.)
	create_timer(dur).timeout.connect(func() -> void:
		_bus.ring_cast_requested.emit(asm, c, Vector2.RIGHT))
	print("[vfx_shot] build=%s  문양 %d · %d층 → score %.3f · 시전 %.2fs"
		% [_build, glyphs, layers.size(), score, dur])


func _spawn_node(c: Vector2) -> void:
	var path := str(_p.get("scene", ""))
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("[vfx_shot] 씬 로드 실패: %s" % path)
		quit(1)
		return
	var n := ps.instantiate() as Node2D
	# 🔴 적은 `enemy_id`를 **add_child 전에** 세워야 한다 — `_ready`가 그 id로 `_def`를 잡는다
	#   (뒤에 세우면 조용히 기본 몸으로 선다).
	# 🔴 조건이 프리셋 이름이 아니라 **변종 축**인 게 의도다 — 이름을 덧대면 한 줄 빠뜨린 프리셋이 기본 몸으로 선다.
	if StringName(_p.get("variant", &"")) == &"enemy":
		n.enemy_id = _enemy_id
		_spawn_player_stub(c + Vector2(_p.get("target", Vector2.ZERO)))
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
		# 🔴 적은 `setup`이 없다 — 수치·행동을 전부 `.tres`가 쥐고(「새 적 = .tres 한 장」),
		#   상태기계는 스텁을 보고 **스스로** 돈다. 여기서 손댈 게 없는 것이 정상이다.
		&"charge":
			pass
		# 🔴 죽음은 **공개 계약으로** 죽인다 — `_die`·`_spawn_death_burst`를 직접 부르면 도구가 죽음
		#   경로를 **우회**해 「드롭이 같이 떨어지나」·「죽음 1회 보장」을 못 보게 된다.
		# ⚠ 위치를 잡은 **뒤에** 죽인다 — 먼저 죽이면 연출이 원점에서 터져 시트 한가운데가 빈다.
		&"death":
			n.take_hit(1.0e9, _rune, Enums.Status.NONE, 0.0)
		_:
			push_error("[vfx_shot] 노드형 프리셋 %s의 setup 배선이 없다" % _name)


## 「플레이어」 스텁 — 그룹 `"player"`가 적의 **유일한 조준 경로**다.
## 🔴 Node2D 맨몸이라 `is_rolling`이 없다 = 늘 안 구른다 → 접촉 피해가 그대로 든다.
## 🔴 **몸을 그린다** — 안 그리면 바닥 예고가 플레이어 **위로** 덮이는지를 판정 못 한다.
##  실무대에서 적은 런타임에 add_child돼 씬 자식보다 나중에 그려지므로 적 연출이 플레이어 위에 얹힌다.
##  눈에 보이는 몸이 없으면 그 사고가 시트에 안 찍히고 도구가 「괜찮아 보인다」고 거짓말한다.
## ⚠ `player.tscn`을 통째로 안 띄운다 — 카메라·HUD·오토로드가 딸려 와 무대가 게임이 된다.
const PLAYER_SHEET := "res://assets/sprites/player/player_hood_sheet.png"
const PLAYER_FRAME := Rect2(0.0, 0.0, 64.0, 64.0)   ## idle 0번 (player.tscn의 at_idle0과 같은 자리)

## 🔴 그룹 `"player"`가 유일한 조준 경로다(적·연출이 그걸로 찾는다).
func _spawn_player_stub(pos: Vector2) -> Node2D:
	var stub := Node2D.new()
	stub.name = "PlayerStub"
	stub.add_to_group("player")
	_stage.add_child(stub)
	stub.global_position = pos
	var tex := load(PLAYER_SHEET) as Texture2D
	if tex == null:
		return stub
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = PLAYER_FRAME
	var spr := Sprite2D.new()
	spr.texture = at
	stub.add_child(spr)
	return stub


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
	match StringName(_p.get("variant", &"")):
		&"status":
			return ":status=%d" % _status
		&"build":
			return ":build=%s%s" % [_build, (":rune=%d" % _rune) if _rune_given else ""]
		&"enemy":
			return ":enemy=%s" % _enemy_id
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
	print("  변종 — 구성(floor): %s" % ", ".join(PackedStringArray(BUILD_BY_NAME.keys())))
	print("  변종 — 적(charge): data/enemies/*.tres의 id를 그대로 (예: charge:hound_alpha)")
