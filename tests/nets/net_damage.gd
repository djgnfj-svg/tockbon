extends RefCounted
## 캐릭터가 다친다 — `docs/plans/3.done/character-damage-minimum.md`.
##
## **여섯 단계가 다 들어와 있다** — 틱 순서(0) · 체력·직격/폭발·무적(2) · 불 지속(3) ·
##  반동(5) · 쓰러짐(6). ⚠ **판정 4(맞으면 밀리나)는 기능째로 삭제됐다** — 아래 그 자리에 표시가 있다.
##
## 🔴🔴 **이 그물의 요점은 「그물도 `frame()` 을 부른다」이다.**
##  껍데기만 `frame()` 을 부르면 그물은 씬을 못 세워 순서를 **손으로 베끼고**, 그 순간
##  **그물이 게임과 다른 것을 재게 된다.** ⇒ 아래 거동 검사가 곧 그 두 번째 호출자다.
##
## 🔴🔴 **아래 검사들은 전부 「실제로 뚫린 뮤테이션」에서 나왔다.** 각각이 무엇을 막는지:
##
## | 뚫렸던 것 | 지금 무는 것 |
## |---|---|
## | `frame()` 본문 통째로 삭제 | 거동 검사 넷이 동시에 (틱 · 연료 · 탄 · 발사 수) |
## | 껍데기가 지역 별칭으로 순서를 다시 듦 | `.step(` 바늘 (이름이 아니라 **호출 모양**) |
## | `_world` 가 null 셋을 들고 태어남 | `_null_world_refuses` + `world_step._init` 의 짖음 |
## | **선언 순서만** 뒤집기(텍스트 불변) | 같음 — 🔴 텍스트로는 원리적으로 못 잡는다 |
## | 탄이 두 배 속도로 낢 | 첫 틱 변위를 **세대 표에서 유도해** 맞댄다 |
## | `grid.step()` ↔ `spell.step()` 맞바꾸기 | `_tick_order_is_grid_then_spell` (사라지는 칸 관문) |
## | `_drain_queue()` 를 뒤로 미루기 | 점화 커맨드의 연료 · 첫 틱 변위 |
## | `_broken` 이름 바꾸기 | `raw is bool` (🔴 **없어지는 대신 빨개진다**) |
## | `enqueue()` 가 가드 밖 | 부서진 세상에 커맨드를 넣어 본다 — ⚠ 「안 터진다」는 **래퍼가** 잡는다 |
##
## 🔴 **껍데기·세상의 사유 이름 셋에 묶여 있다**: `_world` · `_broken` · `_queue`.
##  이름을 바꾸면 이 그물이 빨개지고, **라벨이 무엇을 고칠지 한 줄로 말한다.** 감수한 결합이다.
##
## ⚠ **텍스트 검사가 원리적으로 못 보는 것**: `.step(` 이라고 안 쓰는 호출(`callv("step")` 따위).
##  그건 이 모양 검사의 한계고, 라벨을 거기까지 넓히지 마라.
## ⚠ **이 그물이 원리적으로 못 잴 것**: 껍데기가 `frame()` 을 **갖고 있으면서 안 부르는** 경우
##  (단락 평가 등). `_physics_process` 는 씬 트리라 헤드리스 밖이다 — 화면 검증이 메운다.

## 🔴 주석·문자열 스트리퍼를 **빌려 온다** — 소스 텍스트를 훑는 그물이 여럿이고 스트리퍼는 하나여야 한다.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Character := preload("res://src/actor/character.gd")
const WorldStep := preload("res://src/actor/world_step.gd")

const STAGE_SCRIPT := "res://src/stage/stage.gd"
const STAGE_SCENE := "res://src/stage/stage.tscn"
const WORLD_STEP_PATH := "res://src/actor/world_step.gd"

## 🔴 껍데기에 있으면 안 되는 호출. **`_grid.step(` 이 아니라 `.step(` 이다** —
##  이름을 좁게 박으면 `var g := _grid; g.step()` 두 줄로 우회되고, 그러면 격자가
##  **틱마다 두 번** 돌아도 이 검사는 초록이다(실측).
const ORDER_CALLS: Array[String] = [".step("]

## 🔴🔴 **감지기 자신을 재는 표본.** 바늘을 한 글자 틀리게 적으면 아래 검사는 **영원히 통과한다** —
##  없는 것을 찾으니 늘 「없다」다. 그게 이 모양 검사가 죽는 유일한 방식이라 먼저 재 둔다.
## ⚠ 뒤 둘이 **지역 별칭 우회**다. 이 둘이 여기 있는 것이 바늘을 넓게 잡은 이유다.
const MUST_CATCH: Array[String] = [
	"\t_grid.step()",
	"\t_spell.step(_grid)",
	"\t_char.step(_grid, delta, 0.0, false)",
	"\tg.step()",
	"\ts.step(g)",
]

## 🔴 반대쪽. 바늘이 너무 넓으면 껍데기가 정상적으로 하는 일까지 물어서, 그 압력이 결국
##  검사를 끄는 것으로 끝난다. ⚠ 마지막 줄은 **스트리퍼가 걸려 있나**를 같이 잰다.
const MUST_PASS: Array[String] = [
	"\t_grid.apply(CellGrid.cmd_reset())",
	"\tif _world.frame(delta, 0.0, false):",
	"\t_spell_view.on_tick()",
	"\t# _grid.step() 을 주석에 적는 것은 안 걸린다",
]

## 🔴 껍데기가 `WorldStep` 을 만드는 모양. **null 셋을 넘기면 화면이 통째로 멈추는데
##  그물은 전부 초록이었다**(실측) — 만드는 자리가 리포에 하나뿐이라 여기서 잰다.
##  ⚠ 재는 것은 **인자로 적힌 이름**이지 「런타임에 null이 아니다」가 아니다.
const NEW_CALL_RE := "WorldStep\\.new\\(\\s*_grid\\s*,\\s*_spell\\s*,\\s*_char\\s*\\)"

const DT := 1.0 / 60.0

## 🔴🔴 **아래 자리 상수는 32px 전환에서 전부 ×2 됐다. 이유가 미묘하니 여기 한 번만 적는다.**
##  셀은 **여전히 4px**인데 게임의 길이가 전부 2배가 됐다 — 상자(16→32px) · 발사 속도(10→20셀/틱) ·
##  폭발 반경(12→24셀). ⇒ **배치를 셀로 그대로 두면 상대 거리가 반으로 줄어** 이 그물이
##  재던 것이 통째로 달라진다. 실제로 났다:
##   · 「폭발 반경 **밖**에 서 있다」던 자리가 반경 **안**이 됐다
##   · 두 폭발이 서로의 발판을 부수게 돼 「같은 틱에 둘」이라는 전제가 깨졌다
##  ⇒ **자리는 ×2, 프레임/틱/개수는 그대로.** 방향(`AIM_DX`)도 거리가 아니라 그대로다.

## 바닥 윗면 셀. `net_character` 와 같은 자리다 — 캐릭터가 서는 높이를 같은 식으로 얻는다.
const FLOOR_CY := 200
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX
const STAND_X := 320

## 발사 원점(셀). 🔴 벽에서 멀어야 한다 — 착탄하면 탄이 사라져서 「나아갔나」를 못 잰다.
const FIRE_CX := 80
const FIRE_CY := 100
## 🔴 **축 정렬 조준이다.** 대각이면 `_launch`의 정수 제곱근 절삭이 끼어서 한 틱 변위를
##  세대 표만으로 못 유도한다 — 그러면 기대값을 손으로 박게 되고, 그게 값이 두 벌 되는 길이다.
const AIM_DX := 10
## 탄이 태어나는 자리(고정소수점). `_launch`가 셀 **한가운데**에서 낸다.
const FIRE_ORIGIN_FP := (FIRE_CX << SpellSim.FP_SHIFT) + SpellSim.FP_HALF

## 관문 칸이 발사 원점에서 몇 칸 오른쪽인가. 🔴 **첫 틱 도약 안**이어야 한다
##  (세대 0 속도 20셀 × 항력 ⇒ 18셀 남짓). 밖에 두면 관문을 안 지나고 검사가 헛돈다.
const GAUNTLET_DCX := 10

# ─── 판정 1·3의 무대 ──────────────────────────────────────────────
# 🔴🔴 **전부 「무속성 + 문양 없음」으로 잰다**(기획). 불 룬이면 착탄이 발판을 태우고
#  폭발 문양이면 지형이 바뀐다 ⇒ 「맞았다」와 「지형이 바뀌어서 그렇다」가 섞인다.
#  ⚠ 폭발 판정만 예외다(폭발 문양이 있어야 폭발이 난다).

## 캐릭터 **왼쪽 같은 높이**의 발사 원점. 상자보다 이만큼 왼쪽이다.
## 🔴 상자를 **첫 틱에** 지나는 자리여야 한다 — 두 틱 걸리면 중력이 끼어들어
##  「몇 틱째에 맞나」가 흔들리고, 판정 3-②의 틱 간격 제어가 통째로 무너진다.
##  (세대 0은 첫 틱에 75px 뛴다 ⇒ 36px 앞에서 쏘면 상자(32px)를 통째로 넘어간다)
## 🔴 **캐릭터 x에서 파생시킨다. 상수로 박지 마라** — 캐릭터가 움직인 뒤의 발사가 조용히 빗나가면
##  「두 번째 탄이 빗나가서」 무적 검사가 무의미해진다.
##  ⚠ 이 규율이 생긴 계기(넉백으로 캐릭터가 옆으로 밀려나 있었다)는 **넉백이 사라지며 없어졌다.**
##   규율은 남긴다 — 반동·중력·입력으로도 캐릭터는 여전히 움직인다.
const HIT_LEAD_PX := 36
const HIT_ORIGIN_CY := 194

## 반동만 재는 발사 원점(상자 **오른쪽 바깥**). 🔴 여기서 오른쪽으로 쏘면 탄이 상자를 안 지난다 —
##  ⚠ 이 자리를 고른 근거(「지나면 직격 밀림이 반동과 더해져 부호가 뒤집힌다」)는 **넉백이 사라지며
##   없어졌다.** 자리는 그대로 둔다 — 탄이 상자를 안 지나면 **반동만 남아** 배치가 여전히 제일 깨끗하다.
const RECOIL_CX := 88

## 폭발 판정 — 캐릭터 **옆 바닥**에 내리꽂는다.
## 🔴 탄이 상자를 **안 지나야** 한다. 지나면 직격과 폭발이 섞여 「무엇에 맞았나」를 못 가른다.
const BLAST_FROM_CY := 180

## 🔴🔴 **폭발 자리를 반경에서 파생시킨다. 셀 번호를 박으면 반드시 낡는다.**
##  ⚠ 여기 `BLAST_CX 104`·`BLAST_L_CX 62`·`FAR_STAND_X 192` 가 박혀 있었고,
##   `rd` 를 24 → 12로 내린 날(2026-08-04) 「반경 안에 서 있다」던 두 자리가 **밖으로 나가**
##   폭발 검사 셋이 빨개졌다.
##  🔴 **빨개진 것은 운이 좋았던 방향이다.** 반대로 반경을 **키우면** 「밖에 서 있다」던 자리가
##   조용히 안으로 들어오고, 그러면 뒤집어 보기 ①이 **아무도 안 짖는 채로 무의미해진다.**
##   ⚠ 32px 전환에서 `FAR_STAND_X` 가 정확히 그 방향으로 뚫렸다 — 그때는 빨개져서 잡혔지만
##    그건 자리가 마침 경계에 가까웠기 때문이지 구조가 막은 것이 아니었다.
##
## 가까운 자리는 상자 옆면에서 반경의 **60%**, 「멀리」는 폭발 중심에서 반경의 **1.5배**다.
##  · 0%에 붙이면 탄이 상자를 지나 **직격과 폭발이 섞인다**
##  · 100% 언저리에 두면 셀 내림 한 칸에 「안/밖」이 뒤집혀 검사가 아슬아슬해진다
const BLAST_NEAR_RATIO := 0.6
const BLAST_FAR_RATIO := 1.5

## 발사 원점과 상자 **사이**의 돌 한 칸. 🔴 상자에는 안 닿는 자리여야 한다 —
##  닿으면 「벽에 막혔다」와 「상자에 맞았다」가 섞인다.
const WALL_CX := 76

## 수직 직격 — 상자 **바로 위**에서 곧장 아래로. 🔴 `_slab` 의 축평행 갈래를 지나는 유일한 배치다.
const VERT_CX := 80
const VERT_FROM_CY := 170

## 지팡이 끝이 아래를 볼 때의 자리(상자 **아래**). 중심에서 36px 아래라 셀로는 바닥 속이다 —
## 🔴 게임에서 「발밑을 쏜다」가 실제로 나가는 자리다.
## ⚠ **+5는 유도값이지 ×2가 아니다.** 중심 `FLOOR_TOP − H_PX/2` = 784px · `+ STAFF_LEN_PX 36`
##  = 820px · `÷ CELL_PX 4` = 205 = `FLOOR_CY + 5`. 16px 때의 `+2` 도 같은 유도였다(410/4 = 102).
##  🔴 내림 결과를 기계적으로 ×2 하면 **+4**가 나오는데, 그러면 위 「중심에서 36px 아래」가
##   실제로는 34px이 되어 **주석이 거짓**이 된다. ⚠ 그물은 이걸 못 가른다(+4도 초록이었다).
const FEET_CY := FLOOR_CY + 5

## 🔴 발밑 나무. 캐릭터가 선 자리의 셀은 **빈칸이라 연료가 0**이고 불은 여기 붙는다.
##  ⚠ 아래에 돌을 깔아 둔다 — 나무가 다 타면 **빈칸이 되어 바닥이 사라지므로**,
##   안 깔면 「불이 꺼져서 안 깎인다」와 「떨어져서 안 깎인다」가 섞인다(계획 뒤집기).
const WOOD_CY := FLOOR_CY
const WOOD_CX0 := 78
const WOOD_CX1 := 90

## 「시간에 비례하나」를 재는 창(프레임). 🔴 **두 창 + 앞의 탐색이 나무 수명(2초) 안**이어야 한다.
const BURN_WINDOW := 50

## 한 번 밟는 길이(프레임). 🔴 **1점이 쌓이는 6프레임보다 짧아야** 「톡톡 밟기」가 된다.
const TAP_FRAMES := 5

## 반동을 재는 창(프레임) = 0.5초. 🔴 **입력은 영원히 들어오고 반동은 감쇠하므로** 창이 길면
##  반드시 되돌아온다 — 재는 것은 「반동이 도는 동안 입력을 이기나」다.
const RECOIL_WINDOW := 30

## `fire()` 가 거부하는 문양 목록. 🔴 표에 없는 id라 `_valid_glyphs` 가 짖고 버린다.
const BAD_GLYPHS := 15

## 쓰러진 캐릭터를 떨어뜨릴 구덩이의 바닥. 🔴 좌우는 **캐릭터 자리에서 파생**시킨다 —
##  박아 두면 캐릭터가 조금만 움직여도 구덩이가 엉뚱한 데 생긴다.
##  ⚠ 이 규율의 계기(넉백으로 열 대 맞는 동안 한참 밀려났다)는 **넉백이 사라지며 없어졌다.**
const PIT_BOTTOM_CY := 220

## 반동 잔량이 잦아들기를 기다리는 프레임. 🔴 지수 감쇠라 **완전히 0이 되지 않는다** —
##  30프레임으로는 6px이 흘러서 행동불능 검사가 빨개졌다(실측 — 넉백이 있던 때의 값이다).
const SETTLE_FRAMES := 120


func run(t) -> void:
	_stage_does_not_own_the_order(t)
	_null_world_refuses(t)
	_stage_world_actually_runs(t)
	_divider_and_phase(t)
	_grid_lives_one_tick_per_tick(t)
	_enqueue_becomes_a_projectile(t)
	_queue_lands_before_the_grid_lives(t)
	_tick_order_is_grid_then_spell(t)
	_character_moves_every_frame(t)
	_reset_clears_the_queue(t)
	_direct_hit_costs_hp(t)
	_vertical_hit_costs_hp(t)
	_wall_stops_the_segment(t)
	_place_revives(t)
	_blast_hit_costs_hp(t)
	_same_tick_two_blasts_cost_one(t)
	_invuln_ticks_down_once_per_tick(t)
	_invuln_lasts_four_ticks(t)
	_spread_hit_count_is_recorded(t)
	_fire_burns_through_invuln(t)
	_burnout_stops_the_damage(t)
	_burn_acc_survives_tapping(t)
	_firing_pushes_me_back(t)
	_recoil_decays(t)
	_firing_down_does_not_lift_me(t)
	_rejected_fire_has_no_recoil(t)
	_zero_hp_downs_me(t)
	_downed_cannot_fire(t)
	_ten_hp_still_walks(t)


# ── 껍데기가 순서를 안 든다 (텍스트) ────────────────────────────────

func _stage_does_not_own_the_order(t) -> void:
	_detector_self_test(t)

	var raw := _read(STAGE_SCRIPT)
	# 🔴🔴 **못 읽으면 `src`가 빈 문자열이고 아래 「없다」가 전부 공짜로 통과한다.**
	#  폴더 스캔 그물의 첫 줄과 같은 장치다.
	t.ok(raw.length() > 0, "stage.gd 를 읽었다 (%d바이트)" % raw.length())
	t.ok(not raw.contains("\"\"\""), "stage.gd 에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	# 🔴 스트리퍼가 파일을 통째로 먹어도 아래가 전부 통과한다. 코드가 남아 있는지 먼저 본다.
	t.ok(src.contains("func _physics_process("),
		"스트립 뒤에도 stage.gd 에 코드가 남아 있다 (아래 검사의 전제)")

	for needle: String in ORDER_CALLS:
		t.ok(not src.contains(needle), "stage.gd 에 `%s` 호출이 하나도 없다" % needle)

	# ⚠ **문자열이라 스트립 뒤에는 사라진다** — preload 경로는 원문으로 잰다.
	t.ok(raw.contains(WORLD_STEP_PATH), "stage.gd 가 `%s` 를 preload 한다" % WORLD_STEP_PATH)
	# 🔴 「안 든다」만 재면 **아무도 안 미는 껍데기**도 초록이다. 미는 쪽을 같이 잰다.
	t.ok(src.contains("_world.frame("), "stage.gd 가 `_world.frame(` 으로 세상을 민다")

	var re := RegEx.new()
	t.eq(re.compile(NEW_CALL_RE), OK, "생성 패턴이 컴파일된다")
	t.ok(re.search("var _world := WorldStep.new(_grid, _spell, _char)") != null,
		"감지기가 정상 생성을 통과시킨다")
	t.ok(re.search("var _world := WorldStep.new(null, null, null)") == null,
		"감지기가 null 셋을 안 통과시킨다")
	t.ok(re.search(src) != null,
		"stage.gd 가 `WorldStep.new()` 에 `_grid`·`_spell`·`_char` 를 넘긴다")


## 표본을 **스트리퍼에 통과시켜** 잰다. 실제 검사가 보는 텍스트와 같은 텍스트여야 뜻이 있다.
func _detector_self_test(t) -> void:
	for sample: String in MUST_CATCH:
		t.ok(_hits(NetDeterminism._strip(sample)), "감지기가 문다: %s" % sample.strip_edges())
	for sample: String in MUST_PASS:
		t.ok(not _hits(NetDeterminism._strip(sample)), "감지기가 안 문다: %s" % sample.strip_edges())


func _hits(line: String) -> bool:
	for needle: String in ORDER_CALLS:
		if line.contains(needle):
			return true
	return false


# ── 세상이 실제로 도나 (거동) ──────────────────────────────────────
# 🔴🔴 **텍스트 검사로는 여기를 못 대신한다**(CLAUDE.md 「부르나만 보고 쓰나는 안 본다」).
#  아래가 `frame()` · `enqueue()` · `reset()` · `phase()` · `fire_count()` 의 유일한 자동 검사다.

## 분주기대로 틱이 오르나 · 위상이 프레임마다 오르나.
func _divider_and_phase(t) -> void:
	var g := _floor_grid()
	var w := _world(g)

	var early := 0
	for _i in Tuning.TICK_DIVIDER - 1:
		if w.frame(DT, 0.0, false, false):
			early += 1
	t.eq(early, 0, "분주기 직전 %d프레임은 틱이 아니다" % (Tuning.TICK_DIVIDER - 1))
	t.eq(g.get_tick(), 0, "그동안 격자 틱이 0 그대로다")
	t.eq(w.phase(), Tuning.TICK_DIVIDER - 1, "위상이 프레임마다 하나씩 오른다")

	t.ok(w.frame(DT, 0.0, false, false), "%d번째 프레임에 frame()이 참을 준다" % Tuning.TICK_DIVIDER)
	t.eq(g.get_tick(), 1, "그 프레임에 격자 틱이 1 올랐다")
	t.eq(w.phase(), 0, "틱 프레임에 위상이 0으로 돌아온다")

	# 🔴 한 번은 우연일 수 있다 — 열 주기를 더 돌려 **비율**을 잰다.
	var more := 0
	for _i in Tuning.TICK_DIVIDER * 10:
		if w.frame(DT, 0.0, false, false):
			more += 1
	t.eq(more, 10, "%d프레임에 틱이 정확히 10번이다" % (Tuning.TICK_DIVIDER * 10))
	t.eq(g.get_tick(), 11, "격자 틱이 11이다 (프레임을 세는 게 아니다)")


## 🔴 **틱 계수기가 아니라 연료로 잰다.** 계수기만 보면 「격자가 살았나」가 아니라
##  「누가 숫자를 올렸나」를 재는 것이고, 둘은 다르다.
func _grid_lives_one_tick_per_tick(t) -> void:
	var g := _floor_grid()
	var wx := 10
	var wy := FLOOR_CY - 1
	g.apply(CellGrid.cmd_fill(wx, wy, wx, wy, Mat.WOOD))
	t.ok(g.ignite(wx, wy), "나무 한 칸에 불이 붙었다 (검사의 전제)")
	var fuel0 := g.fuel_at(wx, wy)
	t.ok(fuel0 > Tuning.FIRE_BURN_PER_TICK,
		"연료가 한 틱치보다 많다 (%d > %d — 검사의 전제)" % [fuel0, Tuning.FIRE_BURN_PER_TICK])

	var w := _world(g)
	for _i in Tuning.TICK_DIVIDER - 1:
		w.frame(DT, 0.0, false, false)
	t.eq(g.fuel_at(wx, wy), fuel0, "틱이 아닌 프레임에는 불이 한 톨도 안 탄다")
	w.frame(DT, 0.0, false, false)
	t.eq(g.fuel_at(wx, wy), fuel0 - Tuning.FIRE_BURN_PER_TICK,
		"틱 프레임에 연료가 딱 한 틱만큼 준다 (두 번 돌지 않는다)")


## 큐에 넣은 커맨드가 다음 틱에 탄이 되고, 그 탄이 **얼마나** 움직이나.
##
## 🔴🔴 **「나아갔다」로 끝내면 탄이 두 배 속도로 날아도 초록이다**(실측: `spell.step()` 을 두 번
##  부르는 뮤테이션이 그냥 통과했다). 격자 축은 연료로 **양**을 재는데 투사체 축만 방향이면
##  같은 파일 안에서 비대칭이다. ⇒ 세대 표에서 유도한 값과 **맞댄다.**
## 🔴 그리고 이 변위가 곧 **「커맨드가 `spell.step()` 보다 먼저 빠졌다」**이기도 하다 —
##  뒤로 밀리면 태어난 탄이 그 틱에 안 움직여 변위가 0이다.
func _enqueue_becomes_a_projectile(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var w := WorldStep.new(g, spell, _stander())
	w.enqueue(_fire_cmd())
	t.eq(spell.active_count(), 0, "큐에 넣은 것만으로는 탄이 안 난다")
	t.eq(w.fire_count(), 0, "큐에 넣은 것만으로는 발사 수가 안 오른다")

	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(spell.active_count(), 1, "다음 틱에 탄이 실제로 났다")
	t.eq(w.fire_count(), 1, "발사 수가 1 올랐다")

	# ⚠ 탄이 없으면 아래 `[0]` 이 터져서 **검사가 빨개지는 게 아니라 없어진다.** 전제를 먼저 건다.
	if spell.active_count() != 1:
		t.ok(false, "탄이 없어서 변위를 **하나도 못 쟀다**")
		return
	var vx1 := _drag(_speed_fp())
	t.eq(spell.get_px()[0] - FIRE_ORIGIN_FP, vx1,
		"첫 틱 변위가 세대 0 속도에 항력을 한 번 먹인 값이다 (%d)" % vx1)

	var x1 := spell.get_px()[0]
	var vx2 := _drag(vx1)
	_frames(w, Tuning.TICK_DIVIDER)
	if spell.active_count() != 1:
		t.ok(false, "탄이 사라져서 다음 틱 변위를 **못 쟀다**")
		return
	t.eq(spell.get_px()[0] - x1, vx2, "다음 틱 변위는 항력을 한 번 더 먹은 값이다 (%d)" % vx2)


## 🔴 **커맨드가 격자보다 먼저다.** 큐에서 이번 틱에 나온 점화는 **이번 틱에 이미 한 번 탄다.**
##  뒤로 밀리면 불은 붙는데 **연료가 그대로**라, 「붙었나」만 보면 안 걸린다.
## ⚠ `_drain_queue` 의 **격자 갈래**를 재는 유일한 자리이기도 하다(발사 갈래는 위에서 잰다).
func _queue_lands_before_the_grid_lives(t) -> void:
	var g := _floor_grid()
	var wx := 20
	var wy := FLOOR_CY - 1
	g.apply(CellGrid.cmd_fill(wx, wy, wx, wy, Mat.WOOD))
	var w := _world(g)

	w.enqueue(CellGrid.cmd_ignite(wx, wy, 1))
	t.eq(g.burning_count(), 0, "큐에 넣은 것만으로는 불이 안 붙는다")

	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(g.burning_count(), 1, "다음 틱에 점화 커맨드가 실제로 걸렸다")
	# ⚠ 없는 키를 바로 파면 **검사가 없어진다.** 기본값으로 받고 전제를 건다.
	var fuel := int(Mat.DEFS[Mat.WOOD].get("fuel", -1))
	t.ok(fuel > 0, "나무 표에 연료가 있다 (%d — 전제)" % fuel)
	t.eq(g.fuel_at(wx, wy), fuel - Tuning.FIRE_BURN_PER_TICK,
		"붙은 그 틱에 이미 한 틱치가 탔다 (커맨드가 격자보다 먼저다)")


## 🔴🔴 **투사체는 「움직인 뒤의 격자」를 상대로 난다** — `world_step.gd` 가 계약이라고 적은 순서다.
##  ⚠ 옮겨만 놓고 안 재면 **옮긴 값어치의 절반이 아직 안 온 것이다**(실측: 둘을 맞바꿔도 초록이었다).
##
## 배치: 탄의 첫 틱 경로에 **이 틱에 연료가 다해 사라질 나무 한 칸**을 둔다.
##   순서가 맞으면  `grid.step()` 이 그 칸을 지우고 ⇒ 탄이 지나간다
##   뒤집히면       아직 고체인 칸에 부딪혀    ⇒ 탄이 죽는다
## 🔴 **대조군이 없으면 이 배치가 관문인지도 모르는 채로 초록이 난다.** 한 틱 일찍 쏘면 막혀야 한다.
func _tick_order_is_grid_then_spell(t) -> void:
	t.eq(_run_gauntlet(t, "대조군", true), 0, "아직 안 사라진 칸은 탄을 막는다 (관문이 관문이다)")
	t.eq(_run_gauntlet(t, "본검사", false), 1, "사라지는 틱에 쏜 탄은 그 자리를 지나간다")


## 관문을 세우고 한 발 쏜다. 살아남은 탄 수를 돌려준다.
## `early` 면 **사라지기 한 틱 전**에 쏜다(대조군).
func _run_gauntlet(t, tag: String, early: bool) -> int:
	var g := _floor_grid()
	var wx := FIRE_CX + GAUNTLET_DCX
	var wy := FIRE_CY
	# 🔴🔴 **관문이 두 칸이다. 32px 전환에서 한 칸으로는 안 막혔다**(실측).
	#  `GRAVITY_FP` 가 ×2 되며 탄이 **첫 틱 안에 한 행 내려간다**(0.5셀/틱²) ⇒ Bresenham 경로가
	#  발사 행 아래로 넘어가고, 한 칸짜리 관문은 그 아래로 **비껴간다.**
	#  ⚠ 그러면 대조군이 「막혔다」가 아니라 「지나갔다」가 되어 **관문이 관문이 아니게 된다.**
	#  ⚠ 두 칸은 연료가 같아 **같은 틱에 같이 꺼진다** — 「사라지는 틱」은 여전히 하나다.
	g.apply(CellGrid.cmd_fill(wx, wy, wx, wy + 1, Mat.WOOD))
	t.ok(g.ignite(wx, wy) and g.ignite(wx, wy + 1), "%s: 관문 두 칸에 불이 붙었다 (전제)" % tag)

	# 🔴 틱 수를 박지 않는다 — **연료와 틱당 소모에서 나온다.** `last` 틱까지는 살아 있고
	#  그 다음 틱에 연료가 0이 되어 칸이 사라진다.
	var last := (g.fuel_at(wx, wy) - 1) / Tuning.FIRE_BURN_PER_TICK
	var spell := SpellSim.new()
	var w := WorldStep.new(g, spell, _stander())
	_frames(w, Tuning.TICK_DIVIDER * (last - 1 if early else last))
	t.ok(g.is_solid(wx, wy), "%s: 쏘기 직전까지 관문이 고체다 (전제)" % tag)

	w.enqueue(_fire_cmd())
	_frames(w, Tuning.TICK_DIVIDER)
	# 🔴 관문이 **그 틱에** 사라졌나 / 아직 있나. 이 줄이 없으면 탄이 왜 살거나 죽었는지 모른다.
	t.eq(g.is_solid(wx, wy), early, "%s: 쏜 틱이 끝난 뒤 관문 상태가 배치대로다" % tag)
	return spell.active_count()


## 🔴 캐릭터는 **틱이 아닌 프레임에도** 움직인다(60Hz). 틱 갈래 안으로 들어가면 여기가 빨개진다.
func _character_moves_every_frame(t) -> void:
	var g := _floor_grid()
	var ch := _stander()
	var w := WorldStep.new(g, SpellSim.new(), ch)
	var x0 := ch.x

	t.ok(not w.frame(DT, 1.0, false, false), "첫 프레임은 틱이 아니다 (검사의 전제)")
	t.ok(ch.x > x0, "그 프레임에도 캐릭터가 오른쪽으로 갔다 (%d → %d)" % [x0, ch.x])

	# 뒤집기 — 「무조건 민다」가 아니다.
	var x1 := ch.x
	_frames(w, 10)
	t.eq(ch.x, x1, "입력이 0이면 안 움직인다")


## `reset()` 이 큐와 발사 수를 되돌리나.
func _reset_clears_the_queue(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var w := WorldStep.new(g, spell, _stander())
	var cmd := _fire_cmd()

	w.enqueue(cmd)
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 1, "먼저 한 발이 나갔다 (검사의 전제)")
	var live := spell.active_count()

	w.enqueue(cmd)
	w.reset()
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 0, "reset() 이 발사 수를 0으로 되돌린다")
	t.eq(spell.active_count(), live, "reset() 뒤에는 큐에 있던 발사가 안 나간다 (탄이 안 는다)")


## 🔴 `_init` 이 null 셋을 받으면 짖고 멈추나.
##
## ⚠ **`expect_error` 만으로는 아무것도 안 재는 검사가 된다** — 러너는 stderr를 못 보고
##  선언은 사면일 뿐이라, 짖음이 사라져도 빨개지는 것이 없다.
##  ⇒ 짖음의 **흔적**을 값으로 잰다.
## 🔴 이 검사가 막는 것은 껍데기에서 **선언 순서가 뒤집히는 사고**다. 텍스트로는 못 잡는다 —
##  `WorldStep.new(_grid, _spell, _char)` 는 한 글자도 안 바뀌고 멤버 초기화 순서만 바뀐다.
##
## ⚠ **`frame()` 부터 부르지 않는다.** 가드가 없으면 그 호출이 엔진 에러를 뿜는데,
##  그때 러너는 **단언을 전부 통과시키고**(중단된 호출이 null → 거짓으로 읽힌다) 래퍼만 빨개진다.
##  실측으로 그 모양이 났다 — 「통과 57개」 + 「침묵사 8줄」. ⇒ **표시를 먼저 값으로 잰다.**
## 🔴🔴 **`get()` 을 타입 있는 변수에 바로 대입하지 마라.** 이름이 바뀌면 `get()` 이 null을 주고
##  **대입이 터져 함수가 중단된다** — 그러면 아래 단언들이 **빨개지는 게 아니라 없어진다**
##  (실측: `_broken` → `_brkn` 으로 1101 → 1099 · 실패 0개). ⇒ `Variant` 로 받아 **타입을 먼저 잰다.**
func _null_world_refuses(t) -> void:
	t.expect_error("WorldStep: 세상 셋 중에 null이 있다")
	var w := WorldStep.new(null, null, null)
	var raw: Variant = w.get("_broken")
	t.ok(raw is bool, "world_step 이 `_broken` 표시를 든다")
	t.ok(raw == true, "null 세상이 스스로 「부서졌다」로 표시한다")
	if raw != true:
		return
	t.ok(not w.frame(DT, 1.0, false, false), "그리고 프레임을 안 돈다")

	# 🔴 `enqueue()` 도 **같은 문**을 지나나. 여기만 열려 있으면 부서진 세상이 좌클릭에서 터진다.
	# ⚠ **「안 터진다」쪽은 단언이 못 잰다** — 가드가 없으면 `enqueue()` 안에서 엔진 에러가 나고
	#  호출만 중단돼 큐는 **어차피 비어 있다.** 그 갈래를 잡는 것은 **래퍼의 stderr뿐**이고
	#  실측으로 확인했다. 아래 단언이 재는 것은 「커맨드가 안 앉는다」까지다.
	w.enqueue(_fire_cmd())
	var q: Variant = w.get("_queue")
	t.ok(q is Array, "world_step 이 `_queue` 를 든다")
	if q is Array:
		t.eq((q as Array).size(), 0, "부서진 세상은 커맨드를 안 받는다")


## 🔴🔴 **껍데기가 만든 세상이 실제로 도나.** 위 검사는 그물이 만든 세상만 본다.
##
## ⚠ **짖음으로는 못 잡는다** — `expect_error` 사면은 **도는 내내** 유효해서, `net_render` 가
##  씬을 세울 때 나는 같은 짖음까지 같이 사면된다. 실측: 선언 순서를 뒤집었더니
##  **1098개가 전부 초록**이었다(짖음은 났는데 사면됐고, 아무도 값을 안 봤다).
## ⇒ **껍데기가 만든 그 객체를 직접 굴린다.** 선언 순서가 뒤집히면 여기서 틱이 0이다.
## ⚠ 씬을 세우기만 한다(`_ready`는 안 돈다) — 지형도 스폰도 없는 빈 세상이지만
##  「분주기대로 도나」를 재는 데는 그걸로 충분하다.
func _stage_world_actually_runs(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	if scene == null or not scene.can_instantiate():
		# 🔴🔴 여기서 그냥 `return` 하면 검사가 「실패」가 아니라 **없어진다** — 통과 수만 줄고
		#  아무도 안 짖는다. 「없어진 검사」는 로그에서 「통과한 검사」와 구별이 안 된다.
		t.ok(false, "무대 씬을 못 세워서 껍데기의 세상을 **하나도 못 쟀다**")
		return
	var root := scene.instantiate()
	# ⚠ `Variant` 로 받아 **타입을 먼저 잰다** — 이름이 바뀌면 빨개져야지 없어지면 안 된다.
	var w: Variant = root.get("_world")
	t.ok(w is WorldStep, "껍데기가 `_world` 로 WorldStep 을 든다")
	if w is WorldStep:
		var ticked := 0
		for _i in Tuning.TICK_DIVIDER:
			if w.call("frame", DT, 0.0, false, false):
				ticked += 1
		t.eq(ticked, 1, "껍데기가 만든 세상이 분주기대로 틱을 돈다")
	# ⚠ 트리 밖이라 `queue_free`가 아니라 `free`다.
	root.free()


# ── 판정 1 — 내 마법에 내가 맞나 ───────────────────────────────────

## 직격. 🔴 **터널링 반증이 이 검사의 절반이다** — 40px 도약이 16px 상자를 넘는 배치를
##  일부러 만들고, **그 배치가 정말 도약 배치인 것을 그물이 스스로 단언한다.**
##  ⚠ 안 하면 이 검사는 「함수를 부르나」만 재는 것이 된다(기획 판정 1이 경계한 그대로).
func _direct_hit_costs_hp(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	t.eq(ch.hp, Character.MAX_HP, "시작 체력이 가득이다 (%d)" % Character.MAX_HP)
	# 🔴 오염 0의 기준선. 여기서 계수기를 0으로 맞춰야 「지형을 판 것」이 안 섞인다.
	g.consume_changed()

	# 🔴 **판정이 돈 시점의 상자**를 들고 있어야 한다 — 프레임이 끝날 때 캐릭터가 이미 움직여 있으면
	#  지금 자리로 잰 도약 단언이 거짓으로 빨개진다.
	#  ⚠ 계기였던 「맞으면 밀린다」는 **넉백이 사라지며 없어졌다.** 규율은 남긴다.
	var box_x := ch.x
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)

	# 🔴🔴 **배치가 도약 배치인가** — 구간의 **양 끝이 둘 다 상자 밖**이어야 한다.
	#  ⚠ 이 줄이 없으면 배치가 우연히 상자 위에 걸쳐도 초록이고, 그러면 선분 검사가 아니라
	#   점 검사로 짜도 통과한다.
	t.eq(spell.seg_count(), 1, "이 틱에 구간이 하나다 (배치를 읽을 수 있다)")
	if spell.seg_count() == 1:
		var ax := Character._fp_px(spell.get_seg_x0()[0])
		var bx := Character._fp_px(spell.get_seg_x1()[0])
		t.ok(_outside_box(box_x, ax) and _outside_box(box_x, bx),
			"구간 양 끝(%.1f → %.1f)이 둘 다 상자[%d,%d] 밖이다 (도약 배치다)"
				% [ax, bx, box_x, box_x + Character.W_PX])

	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT,
		"그 도약 구간에 맞아 체력이 %d 깎였다" % Character.DAMAGE_HIT)
	# ⚠ **라벨을 「N틱」으로 적지 마라** — 양쪽이 같은 상수라 `INVULN_TICKS = 0` 으로 바꿔도
	#  `0 == 0` 으로 통과하면서 라벨만 「0틱 켜진다」가 된다(CLAUDE.md 「값 단언이 우연히 맞는다」).
	#  🔴 이 줄이 재는 것은 **「무적을 켜기는 하나」**뿐이고, **길이는 아래 3틱/5틱 쌍이 위아래로 가둔다.**
	t.ok(ch.invuln_left == Character.INVULN_TICKS, "맞은 틱에 무적이 켜진다")
	# 🔴 **오염이 0인 것을 그물이 스스로 증명한다** — 무속성 + 문양 없음이라 격자가 안 변한다.
	t.eq(g.consume_changed(), 0, "격자가 한 칸도 안 변했다 (직격만 잰 것이다)")


## 🔴🔴 **머리 위에서 수직으로 떨어지는 탄도 맞힌다.**
##  ⚠ 실측: `_slab` 의 축평행 갈래(`d ≈ 0`)를 **「늘 빗나간다」로 바꿔도 1170개가 전부 초록**이었다 —
##   「빗나가야 할 때 빗나간다」는 재는데 **「맞아야 할 때 맞는다」를 아무도 안 재고 있었다.**
##  🔴 도달 가능한 상황이다 — 기획이 「**발밑을 쏘면 탄이 나를 통과한다**」를 확정으로 적었다.
##   그 갈래가 깨지면 **조용히 안 아프다.**
func _vertical_hit_costs_hp(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	# 상자 **바로 위**에서 곧장 아래로. 🔴 `adx = 0` 이라 x축이 축평행 갈래를 지난다.
	w.enqueue(SpellSim.cmd_fire(
		VERT_CX, VERT_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	var cx := Character._cell_px(VERT_CX)
	t.ok(cx >= float(ch.x) and cx <= float(ch.x + Character.W_PX),
		"발사선(x=%.1f)이 상자[%d,%d] 안이다 (배치의 전제)" % [cx, ch.x, ch.x + Character.W_PX])

	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(ch.hp, Character.MAX_HP, "첫 틱은 아직 머리 위다 (안 맞는다)")
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT, "둘째 틱에 수직 직격으로 깎인다")


## 🔴🔴 **벽 뒤의 캐릭터는 안 맞는다.** 구간 끝점을 `x1`(안 잘린 도달점)으로 두면 착탄한 탄이
##  **벽 너머까지** 선을 긋고 그 뒤의 캐릭터를 때린다(계획 §6 위험 2).
##  ⚠ 실측: 그 뮤테이션이 **1163개 전부 초록**이었다 — 아무도 안 재고 있었다.
## 🔴 「안 맞았다」만 재면 **탄이 아예 안 나가도 초록**이다 ⇒ 탄이 벽에서 죽은 것과
##  구간이 착탄점에서 잘린 것을 **같이** 단언한다.
func _wall_stops_the_segment(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var row := _aim_row(ch)
	g.apply(CellGrid.cmd_fill(WALL_CX, row, WALL_CX, row, Mat.STONE))
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)

	t.eq(spell.active_count(), 0, "탄이 벽에서 죽었다 (배치의 전제)")
	t.eq(spell.seg_count(), 1, "죽은 탄도 이번 틱 구간을 하나 남긴다")
	if spell.seg_count() == 1:
		var bx := Character._fp_px(spell.get_seg_x1()[0])
		t.ok(bx < float(ch.x),
			"구간 끝(%.1f)이 상자 왼쪽(%d)에 못 미친다 (착탄점에서 잘렸다)" % [bx, ch.x])
	t.eq(ch.hp, Character.MAX_HP, "벽 뒤의 캐릭터는 안 맞는다")


## 🔴 **R(무대 리셋)이 유일한 부활이다** — 혼자라 일으켜 줄 사람이 없다(계획 §4).
##  `place()` 가 체력·무적을 안 되돌리면 쓰러진 채로 영영 남는다(계획 §6 위험 11).
func _place_revives(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)
	t.ok(ch.hp < Character.MAX_HP and ch.invuln_left > 0, "먼저 맞았다 (검사의 전제)")

	ch.place(STAND_X, FLOOR_TOP - Character.H_PX)
	t.eq(ch.hp, Character.MAX_HP, "place()가 체력을 되돌린다 (R로 부활한다)")
	t.eq(ch.invuln_left, 0, "place()가 무적도 되돌린다")


## 폭발. 🔴 탄은 상자를 안 지나고 **바닥에서 터진 폭발**만 닿는다.
## **뒤집어 보기 ①**: 같은 폭발을 반경 **밖**에서 맞으면 체력이 그대로다.
func _blast_hit_costs_hp(t) -> void:
	var right_cx := _blast_cx_beside(STAND_X, 1)
	var near := _blast_shot(t, STAND_X, right_cx, "오른쪽")
	t.eq(near, Character.MAX_HP - Character.DAMAGE_HIT,
		"폭발 반경 안에 서 있으면 체력이 %d 깎인다" % Character.DAMAGE_HIT)
	var far := _blast_shot(t, _far_stand_x(right_cx), right_cx, "멀리")
	t.eq(far, Character.MAX_HP, "폭발 반경 밖에 서 있으면 체력이 그대로다")
	# 🔴 판정 3-①의 전제다 — **왼쪽 자리도 혼자서 때린다.** 안 재면 「폭발 둘 = 한 대」가
	#  「사실은 하나만 닿았다」와 구별이 안 되고, 그러면 그 검사는 아무것도 안 잰다.
	var left := _blast_shot(t, STAND_X, _blast_cx_beside(STAND_X, -1), "왼쪽")
	t.eq(left, Character.MAX_HP - Character.DAMAGE_HIT,
		"왼쪽 자리의 폭발도 혼자서 %d 깎는다 (3-①의 전제)" % Character.DAMAGE_HIT)


## 캐릭터 옆 바닥에 폭발 한 발. 남은 체력을 돌려준다.
func _blast_shot(t, stand_x: int, cx: int, tag: String) -> int:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander_at(stand_x)
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_blast_cmd(cx))

	var blasts := 0
	for _i in 12:
		_frames(w, Tuning.TICK_DIVIDER)
		blasts += spell.blast_count()
	# 🔴 **폭발이 정말 났나** — 안 재면 「아무 일도 안 나서 체력이 그대로」가 뒤집어 보기 ①의
	#  초록이 된다. 두 갈래가 **같은 폭발**을 쓴다는 것이 이 줄로 성립한다.
	t.eq(blasts, 1, "%s: 폭발이 정확히 한 번 났다" % tag)
	return ch.hp


# ── 판정 3 — 무적 ─────────────────────────────────────────────────

## 3-① 같은 틱에 폭발 둘 → **한 대**.
## 🔴 **「폭발이 그 틱에 둘이었다」를 같이 단언한다** — 안 하면 폭발이 하나만 난 상황에서도
##  「한 대」가 나와서 검사가 헛돈다.
##
## 🔴🔴 **이 검사가 재는 것은 무적이 아니라 `on_tick` 의 「첫 히트에서 끝내는」 구조다.**
##  ⚠ 기획 문서의 뒤집기(「무적을 0으로 두면 두 번 깎인다」)는 **실측으로 거짓이었다** —
##   무적을 0으로 둬도 같은 틱 안에서는 여전히 10만 깎인다. **무적이 막는 것은 틱 사이**다.
##   ⇒ 이 라벨을 「무적이 같은 틱을 막는다」로 읽지 마라.
func _same_tick_two_blasts_cost_one(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	# 🔴 **상자 양옆에 한 발씩.** 같은 자리에 두 발을 쏘면 **먼저 터진 폭발이 두 번째 탄의
	#  바닥을 부숴서** 그 탄이 크레이터로 빠지고 **다음 틱에** 터진다(실측) — 그러면
	#  「같은 틱에 둘」이라는 전제 자체가 성립하지 않는다.
	#  ⚠ 양옆이라 **왼쪽 폭발의 파괴 원반이 오른쪽 탄의 바닥에 못 닿는다**: 반경의 60%씩
	#   벌어져 있으므로 두 자리의 간격이 반경의 1.2배 + 상자 폭이다.
	w.enqueue(_blast_cmd(_blast_cx_beside(STAND_X, -1)))
	w.enqueue(_blast_cmd(_blast_cx_beside(STAND_X, 1)))

	var twin_tick := false
	for _i in 12:
		_frames(w, Tuning.TICK_DIVIDER)
		if spell.blast_count() == 2:
			twin_tick = true
	t.ok(twin_tick, "한 틱에 폭발이 둘 난 틱이 실제로 있었다 (배치의 전제)")
	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT,
		"같은 틱에 폭발 둘을 맞아도 한 대만 깎인다")


## 🔴🔴 **무적이 「틱마다 하나씩」 준다** — 계획 §6 위험 1(60Hz에서 통지를 읽으면 한 대가 세 대)을
##  **직접 무는 검사다.**
##  ⚠ 위험 1은 「한 대가 세 대」로는 **안 나타난다** — 무적이 나머지 둘을 먹어서 피해는 한 대
##   그대로이고, **무적이 3배 빨리 닳는 것으로만** 드러난다. 그걸 여기서 센다.
##  ⚠ 아래 3틱/5틱 쌍도 같은 뮤테이션을 물지만, 그 검사의 간격 상수를 누가 손대면
##   두 위험이 **동시에** 안 보이게 된다 ⇒ 감지기를 둘로 나눠 둔다.
func _invuln_ticks_down_once_per_tick(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)
	t.ok(ch.invuln_left > 0, "먼저 맞아 무적이 켜졌다 (검사의 전제)")

	var want := ch.invuln_left
	while want > 0:
		want -= 1
		_frames(w, Tuning.TICK_DIVIDER)
		t.eq(ch.invuln_left, want, "한 틱 지나 무적이 %d 남는다 (틱마다 하나씩)" % want)


## 3-② 무적이 **4틱**인가. 🔴 직격으로 잰다 — 커맨드를 넣으면 **다음 틱**에 나가 그 틱에
##  상자를 지나므로 틱 간격을 정확히 제어할 수 있다.
func _invuln_lasts_four_ticks(t) -> void:
	t.eq(_two_shots_hp(3), Character.MAX_HP - Character.DAMAGE_HIT,
		"3틱 간격 두 발은 **한 대**다 (무적 안이다)")
	t.eq(_two_shots_hp(5), Character.MAX_HP - Character.DAMAGE_HIT * 2,
		"5틱 간격 두 발은 **두 대**다 (무적이 풀렸다)")


## 첫 발이 맞은 틱으로부터 `gap` 틱 뒤에 두 번째 발이 상자를 지나게 한다. 남은 체력을 돌려준다.
func _two_shots_hp(gap: int) -> int:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)          # 이 틱에 첫 발이 나고 그대로 상자를 지난다
	_frames(w, Tuning.TICK_DIVIDER * (gap - 1))
	w.enqueue(_hit_cmd_at(ch))
	_frames(w, Tuning.TICK_DIVIDER)          # 첫 발로부터 gap 틱째
	return ch.hp


## 3-③ 확산 8발에 **몇 대인가** — 🔴 **기록이다. 목표 숫자를 단언하지 마라.**
##  상황을 하나 고정하고 세어서 라벨에 숫자를 찍는다. 그 값을 보고 0.2초를 조일지 정한다.
func _spread_hit_count_is_recorded(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	g.consume_changed()
	var one: Array[int] = [Glyph.GLYPH_SPREAD]
	# 캐릭터 바로 오른쪽 바닥에 내리꽂아 여덟이 그 자리에서 흩어지게 한다.
	# ⚠ 전에는 `BLAST_CX - 12`(폭발 자리에서 12칸 왼쪽)였다 — **폭발 반경에 묶여 있었다.**
	#  반경이 절반이 되면 그 식이 상자 안으로 들어와 직격이 섞인다. ⇒ 상자에서 파생시킨다.
	w.enqueue(SpellSim.cmd_fire(
		_spread_cx(STAND_X), BLAST_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.pack(one)))
	_frames(w, Tuning.TICK_DIVIDER * 20)

	var hits := (Character.MAX_HP - ch.hp) / Character.DAMAGE_HIT
	# ⚠ 단언은 「셌다」까지다. 🔴 숫자는 **라벨에 기록**이고 목표가 아니다.
	t.ok(hits >= 0, "확산 8발 상황에서 **%d대** 맞았다 (기록 — 목표 숫자가 아니다)" % hits)
	t.eq(g.consume_changed(), 0, "그 동안 격자가 한 칸도 안 변했다 (무속성 + 확산뿐이다)")


# ── 판정 2 — 불 위에 서 있으면 깎이나 ─────────────────────────────

## 🔴🔴 **「무적과 무관하게」를 재는 유일한 방법**: 탄으로 먼저 맞혀 **무적을 켠 상태에서**
##  불 위에 세운다. ⚠ 무적을 안 켜고 재면 「그냥 불 피해」를 재는 것이고 **틀린 구현도 통과한다.**
## 🔴 그리고 **시간에 비례**하는지까지 본다 — 「한 번 깎인다」면 상수를 박아도 통과한다.
func _fire_burns_through_invuln(t) -> void:
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)

	# 🔴 **수직 직격으로 무적을 켠다.** ⚠ 이 배치를 고른 근거(「수평으로 맞히면 밀려서 발밑 나무를
	#  벗어난다」)는 **넉백이 사라지며 없어졌다.** 배치는 그대로 둔다 — 캐릭터가 제자리에 있는 것이
	#  「발밑 한 줄만 탄다」를 재는 데 여전히 제일 깨끗하다.
	# 🔴🔴 **큐를 안 지난다.** 큐로 넣으면 `world_step` 이 **반동**을 걸어서(아래로 쐈으니 위로)
	#  캐릭터가 떠올랐다가 20프레임 뒤에 내려앉고, 그 사이 무적이 다 닳는다(실측).
	#  ⚠ 여기서 재는 것은 **불이 무적과 무관한가**지 커맨드 경로가 아니다 — 반동은 판정 5가 잰다.
	#
	# 🔴🔴 **이 리포에서 「그물이 게임과 다른 길을 지나는」 첫 사례다. 값을 정확히 적어 둔다:**
	#  이 배치는 **게임이 만들 수 없는 상태**(반동 없는 자기 피격)를 세운다 ⇒ 그 대가로
	#  **「불 위에서 발밑을 쏘면 반동으로 떠서 불에서 벗어난다」가 아무도 안 재는 거동이 됐다.**
	#  ⚠ 그게 버그인지 사양인지는 **기획 문서에도 없다.** 무적·불의 성질은 경로와 무관해서
	#   이 맞바꿈을 받아들였지만, **다음에 같은 우회를 할 때는 이 줄을 먼저 읽어라.**
	t.ok(spell.fire(SpellSim.cmd_fire(
		VERT_CX, VERT_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.GLYPH_NONE)),
		"맞힐 탄을 시뮬에 직접 넣었다 (반동을 안 만든다)")
	_frames(w, Tuning.TICK_DIVIDER * 2)
	t.eq(ch.hp, Character.MAX_HP - Character.DAMAGE_HIT, "탄으로 먼저 맞았다 (검사의 전제)")
	t.ok(ch.invuln_left > 0, "그래서 무적이 켜져 있다 (검사의 전제)")
	_ignite_under(t, g, ch)

	# 🔴 **첫 불 피해가 들어온 순간의 무적 잔량**을 본다. 그게 「무적과 무관하다」의 전부다.
	var invuln_at_first := -1
	var before := ch.hp
	for _i in 30:
		w.frame(DT, 0.0, false, false)
		if ch.hp < before:
			invuln_at_first = ch.invuln_left
			break
	t.ok(invuln_at_first > 0,
		"**무적이 %d틱 남은 채로** 첫 불 피해가 들어왔다 (무적에 안 걸린다)" % invuln_at_first)
	t.ok(ch.burning, "그 동안 캐릭터가 「불붙음」으로 표시된다 (화면이 읽는 값)")

	# 시간에 비례하나 — 같은 길이의 두 창을 맞댄다.
	# ⚠ **두 창이 나무 수명(연료 200 / 틱당 5 = 40틱 = 2초) 안에 끝나야 한다** —
	#  넘으면 「불이 꺼져서 덜 깎였다」가 「비례가 깨졌다」로 읽힌다(실측으로 한 번 그랬다).
	var a := ch.hp
	_frames(w, BURN_WINDOW)
	var d1 := a - ch.hp
	var b := ch.hp
	_frames(w, BURN_WINDOW)
	var d2 := b - ch.hp
	t.ok(g.burning_count() > 0, "두 창 내내 불이 살아 있었다 (검사의 전제)")
	# 🔴 기대값을 박지 않는다 — 초당 피해와 창 길이에서 나온다. 절삭 때문에 +1까지 허용한다.
	var want := int(Character.BURN_DPS * BURN_WINDOW / 60.0)
	t.ok(d1 >= want and d1 <= want + 1,
		"%d프레임에 %d 깎인다 (초당 %d에서 나온 %d~%d)"
			% [BURN_WINDOW, d1, int(Character.BURN_DPS), want, want + 1])
	t.ok(absi(d2 - d1) <= 1, "다음 창도 같은 만큼 깎인다 (%d vs %d — 시간에 비례한다)" % [d1, d2])


## **뒤집어 보기**: 연료가 다해 불이 꺼지면 깎임이 멈춘다.
## 🔴 「안 깎인다」만 재면 **애초에 안 붙은 것과 구별이 안 된다** ⇒ 먼저 깎인 것과
##  불이 실제로 꺼진 것을 **같이** 단언한다.
func _burnout_stops_the_damage(t) -> void:
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	_ignite_under(t, g, ch)

	var start := ch.hp
	# 나무 연료 200 / 틱당 5 = 40틱이면 다 탄다. 넉넉히 돌린다.
	_frames(w, Tuning.TICK_DIVIDER * 60)
	t.ok(ch.hp < start, "불이 도는 동안 깎였다 (%d → %d)" % [start, ch.hp])
	t.eq(g.burning_count(), 0, "연료가 다해 불이 꺼졌다 (배치의 전제)")
	t.ok(not ch.burning, "캐릭터의 「불붙음」 표시도 꺼진다")

	var after := ch.hp
	_frames(w, 120)
	t.eq(ch.hp, after, "불이 꺼진 뒤에는 한 톨도 안 깎인다")


## 🔴🔴 **불을 톡톡 밟고 지나가는 것이 공짜가 아니다.**
##  `10dps × 1/60` 이라 1점 쌓는 데 **6프레임**이 걸린다 ⇒ 누산기를 불에서 나올 때 비우면
##  **0.1초 미만 접촉이 영원히 공짜**가 되고 그걸 무한히 반복할 수 있다.
##  ⚠ 계획에 없는 결정이라 **「정리」한다고 비우는 사람이 나오면 아무도 안 짖는다** —
##   실측: 비우든 안 비우든 그물 1193개가 그대로였다. 그래서 이 검사가 있다.
## ⚠ 불을 끄고 켜는 것으로 「밟았다 뗐다」를 만든다 — 캐릭터를 옮기면 `place()`가 체력을 되돌린다.
func _burn_acc_survives_tapping(t) -> void:
	var g := _wood_floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var cx0 := floori(ch.x / float(Tuning.CELL_PX))
	var cx1 := floori((ch.x + Character.W_PX - 1) / float(Tuning.CELL_PX))

	var contacts := 4
	for _i in contacts:
		for cx in range(cx0, cx1 + 1):
			g.ignite(cx, WOOD_CY)
		t.ok(g.burning_count() > 0, "발밑에 불이 붙었다 (전제)")
		_frames(w, TAP_FRAMES)
		# 나무를 다시 깔면 깃발이 지워진다(`_write_cell`이 파면에서도 뺀다) = 불에서 나온 것과 같다.
		g.apply(CellGrid.cmd_fill(WOOD_CX0, WOOD_CY, WOOD_CX1, WOOD_CY, Mat.WOOD))
		t.eq(g.burning_count(), 0, "불에서 나왔다 (전제)")
		_frames(w, 2)

	# 🔴 한 번에 %d프레임씩이라 **접촉 하나로는 절대 1점이 안 쌓인다**(6프레임 필요).
	t.ok(TAP_FRAMES * Character.BURN_DPS / 60.0 < 1.0,
		"한 번 접촉(%d프레임)만으로는 1점이 안 쌓인다 (배치의 전제)" % TAP_FRAMES)
	t.ok(ch.hp < Character.MAX_HP,
		"그래도 %d번 밟으면 결국 깎인다 (%d) — 누산기가 접촉 사이를 넘어 산다"
			% [contacts, ch.hp])


## 발밑 나무에 불을 붙인다. 🔴 **상자 아래 한 줄**이라 상자 안에는 타는 셀이 하나도 없다 —
##  그게 계획이 못 박은 「발밑 한 줄을 빠뜨리면 게임에서만 아무 일이 안 난다」를 재는 배치다.
func _ignite_under(t, g: CellGrid, ch: Character) -> void:
	var cx0 := floori(ch.x / float(Tuning.CELL_PX))
	var cx1 := floori((ch.x + Character.W_PX - 1) / float(Tuning.CELL_PX))
	var lit := 0
	for cx in range(cx0, cx1 + 1):
		if g.ignite(cx, WOOD_CY):
			lit += 1
	t.ok(lit > 0, "발밑 나무 %d칸에 불이 붙었다 (검사의 전제)" % lit)
	# 🔴 **상자 안에는 불이 없다**는 것을 단언한다. 이게 참이어야 「발밑 한 줄」을 재는 것이다.
	var top := floori(ch.y / float(Tuning.CELL_PX))
	var bottom := floori((ch.y + Character.H_PX - 1) / float(Tuning.CELL_PX))
	var inside := 0
	for cy in range(top, bottom + 1):
		for cx in range(cx0, cx1 + 1):
			if g.is_burning(cx, cy):
				inside += 1
	t.eq(inside, 0, "상자가 덮는 셀에는 타는 칸이 하나도 없다 (발밑 한 줄만 탄다)")


# ── 판정 4 — **삭제됨** ───────────────────────────────────────────
# 🔴 **「맞으면 밀리나」(넉백)가 사라졌다**(사용자 결정, 2026-08-04) ⇒ 그걸 재던 검사 여섯과
#  그 배치 상수들을 같이 지웠다. **없는 기능을 재는 검사는 가짜 그물이다.**
#  ⚠ 되살리려면 `character.gd` 의 `recoil_vx` 옆 주석부터 읽어라 — 무엇을 같이 되살려야 하는지 적혀 있다.

# ── 판정 5 — 쏘면 반동으로 밀리나 ─────────────────────────────────

## 🔴 **거는 자리가 함정이다** — 발사는 큐를 지나므로 큐에 넣는 시점에 걸면
##  **거부된 발사에도 밀린다**. 아래 뒤집기가 그 자리를 지킨다.
func _firing_pushes_me_back(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var x0 := ch.x
	# 오른쪽으로 쏜다 ⇒ 왼쪽으로 밀려야 한다.
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, HIT_ORIGIN_CY, AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 1, "발사가 받아들여졌다 (검사의 전제)")
	t.ok(ch.recoil_vx < 0.0, "쏜 반대쪽(-x)으로 반동이 걸렸다 (%.0f px/s)" % ch.recoil_vx)
	_frames(w, RECOIL_WINDOW)
	t.ok(ch.x < x0, "%d프레임 뒤 왼쪽으로 밀려 있다 (%d → %d)" % [RECOIL_WINDOW, x0, ch.x])


## 🔴🔴 **반동이 시간에 따라 잦아드나.**
##  ⚠ **실측(2026-08-04): 감쇠를 `*= 1.0` 으로 지워도 그물 1280개가 전부 초록이었다** —
##   쏜 캐릭터가 **영원히 미끄러지는데** 아무도 안 봤다(화면에서는 1초면 보이는 고장이다).
##  🔴 그 구멍은 **넉백을 지우며 `_knockback_decays` 가 같이 사라져서** 생겼다.
##   **감쇠는 반동 쪽에 남았으므로 검사도 남는다** — 없는 기능을 재는 것이 아니다.
##
## 🔴 **변위가 아니라 속도로 잰다.** 변위로 재면 감쇠를 지웠을 때 캐릭터가 격자 왼쪽 끝에 막혀
##  둘째 창이 저절로 짧아지고, 그러면 **뒤집기가 통과해 버린다**(계산으로 확인했다: 200px → 120px).
## ⚠ 「그래서 실제로 안 움직이나」는 위 `_firing_pushes_me_back` 이 x로 잰다. 둘이 짝이다.
func _recoil_decays(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, HIT_ORIGIN_CY, AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w, Tuning.TICK_DIVIDER)
	var v1 := absf(ch.recoil_vx)
	t.ok(v1 > 0.0, "쏘아서 반동이 걸렸다 (%.0f px/s — 검사의 전제)" % v1)

	_frames(w, RECOIL_WINDOW)
	var v2 := absf(ch.recoil_vx)
	# 🔴 기대값을 박지 않는다 — 감쇠 상수와 창 길이에서 나온다. 0.5초면 `0.02^0.5` = 0.14배다.
	#  ⚠ 절반으로 느슨하게 잡은 것은 **프레임 수를 조금 바꿔도 안 흔들리게** 하려는 것이지
	#   재는 것을 넓히려는 게 아니다 — 감쇠가 없으면 비율이 **1.0**이라 한참 넘는다.
	t.ok(v2 < v1 * 0.5,
		"%d프레임 뒤 반동이 절반 아래로 잦아든다 (%.0f → %.0f px/s)" % [RECOIL_WINDOW, v1, v2])


## 🔴🔴 **로켓점프는 삭제됐다**(사용자 결정, 2026-08-04). 반동이 1D라 아래로 쏴도 안 뜬다.
##  전에는 이 함수가 **정반대**(`top < y0`, 「아래로 쏘면 떠오른다」)를 단언했다.
##
## 🔴🔴 **「안 뜬다」만 재면 이 검사는 아무것도 안 잰다** — 발사가 거부돼도, `recoil()` 이
##  통째로 안 불려도, 반동 상수가 0이어도 **전부 초록**이다. 없는 것을 재는 검사는 가짜 그물이다.
##  ⇒ **대각선으로 쏴서 「가로는 걸리는데 세로만 0」을 한 배치에서 같이 잰다.**
##   그 짝이 있어야 라벨(「세로를 지웠다」)과 재는 것이 같아진다.
##  ⚠ 수직(0,10)으로 쏘면 `d.x` 가 0이라 **가로도 0**이고, 그러면 대조군을 못 세운다.
func _firing_down_does_not_lift_me(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var y0 := ch.y
	var x0 := ch.x
	# 🔴 **지팡이 끝 자리에서 쏜다 — 상자 *아래*다.** 게임에서 아래로 조준하면 총구가 몸 아래
	#  (중심 + `STAFF_LEN_PX`)라 탄이 상자를 안 지난다 — 배치를 거기 맞춘다.
	#  ⚠ 오른쪽 **아래** 대각선이라 세로 성분이 살아 있다 — 로켓점프가 있었다면 이 배치에서도 떴다.
	w.enqueue(SpellSim.cmd_fire(
		VERT_CX, FEET_CY, 10, 10, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	var top := y0
	for _i in RECOIL_WINDOW:
		w.frame(DT, 0.0, false, false)
		top = mini(top, ch.y)
	t.eq(w.fire_count(), 1, "발사가 받아들여졌다 (검사의 전제)")
	t.eq(top, y0, "아래로 쏴도 한 픽셀도 안 뜬다 (로켓점프 삭제 · y %d)" % y0)
	# 🔴 **대조군.** 같은 발사에서 가로는 걸린다 ⇒ 위 줄이 「반동이 통째로 죽었다」로
	#  초록이 되는 길이 막힌다.
	t.ok(ch.x < x0,
		"같은 발사의 가로 반동은 살아 있다 (%d → %d) — 세로만 지운 것이다" % [x0, ch.x])


## 🔴🔴 **거부된 발사는 반동을 안 만든다.**
##  ⚠ 라벨을 「빈 룬」이라고 적지 마라 — 그 경로는 껍데기(`_fire_at` 의 `can_fire()`)에 있어
##   그물이 못 부른다. 여기서 재는 것은 **`fire()` 가 거부하는 커맨드**다.
func _rejected_fire_has_no_recoil(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	var x0 := ch.x
	t.expect_error("SpellSim: 모르는 문양 id")
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, HIT_ORIGIN_CY, AIM_DX, 0, Tuning.ELEM_NONE, BAD_GLYPHS))
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), 0, "그 발사는 거부됐다 (검사의 전제)")
	t.eq(spell.active_count(), 0, "탄도 안 났다 (검사의 전제)")
	t.eq(ch.recoil_vx, 0.0, "거부된 발사는 반동을 안 만든다")
	_frames(w, RECOIL_WINDOW)
	t.eq(ch.x, x0, "그래서 한 픽셀도 안 밀린다")


# ── 판정 6 — 100 → 0 이면 쓰러지나 ────────────────────────────────

## 🔴🔴 **즉사가 아니다** — 중력을 계속 받는 것으로 잰다(공중에서 쓰러지면 떨어져 지표면에 붙는다).
## 🔴 **행동불능을 같이 잰다.** ⚠ 안 재면 **「플래그만 켜고 아무 일도 안 하는」 구현이 통과한다.**
##  ⚠ **잔여 속도가 남아 있으면 x가 변한다** ⇒ 쓰러뜨린 뒤 **재우고** 잰다.
func _zero_hp_downs_me(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	t.ok(not ch.downed, "시작은 안 쓰러진 상태다 (검사의 전제)")
	_beat_down(t, w, spell, ch, Character.MAX_HP / Character.DAMAGE_HIT)
	t.eq(ch.hp, 0, "열 대를 맞고 체력이 0이다")
	t.ok(ch.downed, "그래서 쓰러졌다")

	# 🔴 **잔여 속도를 재운 뒤에** 행동불능을 잰다 — 남아 있으면 x가 변해서 「입력이 먹었다」로 읽힌다.
	#  ⚠ 30프레임으로는 **실측으로 모자랐다**(6px 흘렀다 — 넉백이 있던 때의 값이다). 지수 감쇠라
	#   완전히 0이 되진 않으므로 넉넉히 기다린다: 초당 ×0.02면 2초 뒤 0.16px/s다.
	_frames(w, SETTLE_FRAMES)
	var x0 := ch.x
	_frames(w, 60, 1.0)
	t.eq(ch.x, x0, "입력을 계속 넣어도 x가 안 변한다 (행동불능)")
	# ⚠ 점프도 같이 막힌다 — 안 막으면 「누워서 뛴다」가 된다.
	var y0 := ch.y
	for _i in 60:
		w.frame(DT, 1.0, true, true)
	t.eq(ch.y, y0, "점프 입력도 안 먹는다")

	# 🔴🔴 **즉사가 아님 = 중력을 계속 받는다.** 발밑을 파서 떨어뜨린다.
	# ⚠ **「자기 폭발로 판다」는 이제 거짓이다** — 쓰러지면 못 쏜다(`world_step._drain_queue`).
	#  게임에서 이 상태가 되는 길은 셋이다: ① 쓰러지기 **전에** 판 구멍 ② 불에 타 죽는 동안
	#  발판이 타서 없어짐 ③ 멀티에서 남이 쏨. ⇒ **여기 배치는 그 결과만 같게 만든 것**이고,
	#  그 맞바꿈은 위 `_beat_down` 주석에 적어 뒀다.
	# ⚠ 구덩이도 **지금 캐릭터 자리에서** 판다 — 박아 두면 캐릭터가 움직인 날 엉뚱한 데 생긴다.
	var pit0 := floori(ch.x / float(Tuning.CELL_PX)) - 2
	var pit1 := floori((ch.x + Character.W_PX - 1) / float(Tuning.CELL_PX)) + 2
	g.apply(CellGrid.cmd_fill(pit0, FLOOR_CY, pit1, PIT_BOTTOM_CY, Mat.EMPTY))
	_frames(w, 120)
	t.ok(ch.y > y0, "쓰러진 채로 떨어진다 (y %d → %d — 중력을 계속 받는다)" % [y0, ch.y])
	t.ok(ch.on_ground, "그리고 구덩이 바닥에 닿는다")
	t.eq(ch.y, (PIT_BOTTOM_CY + 1) * Tuning.CELL_PX - Character.H_PX,
		"지표면에 정확히 붙는다 (튀거나 파묻히지 않는다)")


## `n`대를 맞힌다. 🔴 무적이 4틱이라 **5틱 간격**이어야 매번 들어간다.
## ⚠ 큐를 안 지난다 — 반동이 섞이면 캐릭터가 뜨고 다음 발이 빗나간다(위 불 검사와 같은 이유).
##
## 🔴🔴 **잃는 것 — 우회 셋째 사례이고 이게 제일 크다.** 게임에서 자기를 쓰러뜨리는 것은
##  **반동이 붙은 자기 탄**인데 그 경로로는 한 번도 안 재진다 ⇒ **판정 6이 통째로 우회 경로에
##  얹혀 있다.**
## ⚠ **우회가 셋이 되면 다음 사람은 그걸 기본값으로 읽는다.** 넷째를 만들기 전에 멈추고,
##  「이 성질이 정말 경로와 무관한가」를 먼저 답해라.
##
## 🔴🔴 **그리고 이 우회는 이미 한 번 결과를 가렸다 — 이 리포의 첫 사례다.**
##  아래 「쓰러진 채 중력을 받나」의 도달 근거를 처음엔 **「자기 폭발로 발밑을 판다」**로 적었는데,
##  **같은 날 「쓰러지면 못 쏜다」를 넣으면서 그 길이 닫혔다.** 실제 게임 경로로 재던 프로브는
##  그 자리가 `y 308 → 308` 로 빨개졌는데 **그물은 1288개 그대로 통과했다** —
##  `spell.fire()` 를 직접 불러 **새 문을 안 지나기 때문**이다.
## 🔴 **지금 게임에서 쓰러진 채 떨어지는 길은 셋뿐이다:**
##  ① 쓰러지기 **전에** 판 구멍 ② 불에 타 죽는 동안 발판이 타서 없어짐 ③ **멀티에서 남이 쏨.**
##  ⇒ 아래 검사가 세우는 「쓰러진 뒤에 발밑을 판다」는 **그물만의 상황**이다. 성질(중력을 계속
##   받나)은 경로와 무관해서 그대로 두지만, **도달 근거로 「자기 폭발」을 다시 적지 마라.**
func _beat_down(t, w: WorldStep, spell: SpellSim, ch: Character, n: int) -> void:
	for _i in n:
		t.ok(spell.fire(_hit_cmd_at(ch)), "때릴 탄이 났다 (검사의 전제)")
		_frames(w, Tuning.TICK_DIVIDER * 5)


## 🔴🔴 **쓰러지면 못 쏜다.** 안 막으면 지팡이도 총구도 안 그려지는데 **마법이 나가고
##  그 반동으로 시체가 날아다닌다**(실측: 발사 10 → 11 · 위로 59px).
## 🔴 **커맨드가 큐를 지나는 길로 잰다** — 막는 자리가 거기이기도 하고, 그 길이 멀티에서
##  서버가 쓰는 길이다.
func _downed_cannot_fire(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	# 먼저 쓰러뜨린다. ⚠ 여기서는 큐를 안 쓴다(반동이 섞이면 배치가 무너진다 — 위 `_beat_down`).
	_beat_down(t, w, spell, ch, Character.MAX_HP / Character.DAMAGE_HIT)
	t.ok(ch.downed, "쓰러졌다 (검사의 전제)")
	_frames(w, SETTLE_FRAMES)

	var fired := w.fire_count()
	var kb := ch.recoil_vx
	var vy := ch.vy
	w.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, _aim_row(ch), AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w, Tuning.TICK_DIVIDER)
	t.eq(w.fire_count(), fired, "쓰러진 채로는 발사 수가 안 오른다")
	t.eq(spell.active_count(), 0, "탄도 안 난다")
	# ⚠ **같은 값을 기대하지 마라** — 그 세 프레임에도 감쇠가 돈다. 반동이 붙었다면 **커진다**.
	t.ok(absf(ch.recoil_vx) <= absf(kb), "그러니 가로 반동도 안 붙는다 (잔량이 줄기만 했다)")
	# 🔴🔴 **라벨을 좁혔다. 옛 라벨(「세로도 중력 말고는 안 붙는다」)이 재는 것보다 넓었다.**
	#  ⚠ 이 커맨드는 **수평**(ady = 0)이라 `recoil()` 의 세로 성분이 **원래 0**이었다 —
	#   쓰러짐 가드가 없어도 vy는 안 변한다. ⇒ **이 축은 원리적으로 못 무는 자리다.**
	#  🔴🔴 **그리고 2026-08-04에 세로 반동 자체가 삭제되어(`character.recoil()`)
	#   이제는 어떤 커맨드로도 못 문다.** 「아래로 쏘는 커맨드로 다시 짜면 된다」고 적혀 있었는데
	#   **그 길이 없어졌다** — 재려는 거동이 사라진 것이지 검사가 게을러진 게 아니다.
	#  ⚠ 그리고 옛 기대식(`vy + GRAVITY_PX*DT`)은 **반올림 위상에 우연히 맞던 값**이다:
	#   중력이 ×2 되며 프레임마다 1px이 실제로 소모되어 `_move_y` 가 매번 막고 vy를 0으로 만든다.
	#  🔴 지금 재는 것은 **「접지한 채 위로 안 떴다」**까지다.
	t.eq(ch.vy, 0.0, "접지 상태의 세로 속도 0 그대로다 (위로 안 떴다)")

	# 🔴 **뒤집기 — 안 쓰러졌으면 같은 커맨드가 나간다.** 안 재면 「커맨드가 애초에 틀렸다」와
	#  구별이 안 된다.
	var g2 := _floor_grid()
	var spell2 := SpellSim.new()
	var ch2 := _stander()
	var w2 := WorldStep.new(g2, spell2, ch2)
	w2.enqueue(SpellSim.cmd_fire(
		RECOIL_CX, _aim_row(ch2), AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(w2, Tuning.TICK_DIVIDER)
	t.eq(w2.fire_count(), 1, "안 쓰러졌으면 같은 커맨드가 나간다 (대조군)")


## **뒤집어 보기**: 안 쓰러진 체력에서는 **같은 입력에 x가 변한다.**
## ⚠ 기획 문서는 「체력 1」이라 적었지만 기준 피해가 10이라 1이 안 나온다 — 실제 값은 **10**이다.
func _ten_hp_still_walks(t) -> void:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := _stander()
	var w := WorldStep.new(g, spell, ch)
	_beat_down(t, w, spell, ch, Character.MAX_HP / Character.DAMAGE_HIT - 1)
	t.eq(ch.hp, Character.DAMAGE_HIT, "체력이 %d 남았다 (한 대 남은 상태)" % Character.DAMAGE_HIT)
	t.ok(not ch.downed, "아직 안 쓰러졌다")

	_frames(w, SETTLE_FRAMES)
	var x0 := ch.x
	_frames(w, 60, 1.0)
	t.ok(ch.x > x0, "체력 %d에서는 같은 입력에 x가 변한다 (%d → %d)"
		% [Character.DAMAGE_HIT, x0, ch.x])


# ── 세상 만들기 ────────────────────────────────────────────────────

## 캐릭터가 서는 줄만 **나무**, 그 아래는 돌.
func _wood_floor_grid() -> CellGrid:
	var g := _floor_grid()
	g.apply(CellGrid.cmd_fill(WOOD_CX0, WOOD_CY, WOOD_CX1, WOOD_CY, Mat.WOOD))
	return g


## 캐릭터 상자를 **첫 틱에** 지나는 수평 한 발. 무속성 + 문양 없음이다.
## 🔴 원점을 **지금 캐릭터 자리에서** 낸다 — 위 `HIT_LEAD_PX` 주석.
func _hit_cmd_at(ch: Character) -> Dictionary:
	var cx := floori((ch.x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	return SpellSim.cmd_fire(cx, _aim_row(ch), AIM_DX, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE)


## 상자 **한가운데**를 지나는 줄. 🔴 x와 같은 이유로 **캐릭터에서 파생시킨다** —
##  박아 두면 캐릭터가 위아래로 움직인 뒤의 발사가 조용히 빗나간다.
func _aim_row(ch: Character) -> int:
	return floori((ch.y + Character.H_PX * 0.5) / float(Tuning.CELL_PX))


## 세대 0 폭발의 반경(px). 🔴 **표에서 뽑는다** — 박으면 값이 두 벌이 되고, 갈라진 쪽은
##  「반경 안/밖」이라는 라벨만 남고 실제로는 아무 데도 안 재게 된다.
static func _blast_r_px() -> float:
	return float(Tuning.blast_rd(0) * Tuning.CELL_PX)


## 상자 `side`(+1 오른쪽 · −1 왼쪽) 바깥, 반경 **안**에 폭발을 놓을 셀.
## 🔴 `_circle_hits_box` 는 상자에서 원 중심까지의 **최단 거리**로 판정하므로 기준점이
##  상자 중심이 아니라 **옆면**이다. 중심에서 재면 상자 폭 절반만큼 조용히 어긋난다.
static func _blast_cx_beside(stand_x: int, side: int) -> int:
	var edge := stand_x + Character.W_PX if side > 0 else stand_x
	return floori((float(edge) + side * _blast_r_px() * BLAST_NEAR_RATIO) / float(Tuning.CELL_PX))


## 폭발 반경 **밖**에 상자를 세울 왼쪽 위 x(뒤집어 보기 ①).
## ⚠ 상자의 **오른쪽 끝**이 반경 밖이어야 하므로 상자 폭을 빼서 왼쪽 위를 돌려준다 —
##  안 빼면 상자 오른쪽 모서리가 원 안에 걸린 채 「밖에 세웠다」고 믿게 된다.
static func _far_stand_x(blast_cx: int) -> int:
	return int(Character._cell_px(blast_cx) - _blast_r_px() * BLAST_FAR_RATIO) - Character.W_PX


## 확산 배치 — 캐릭터 **바로 오른쪽 바닥**(상자 옆면에서 반 칸).
## 🔴 **폭발 반경에서 파생시키지 않는다.** 여기서 재는 것은 「확산 여덟이 그 자리에서 흩어질 때
##  몇 대인가」라 자리의 기준이 상자다 — 반경으로 묶으면 반경이 작아지는 날 이 자리가
##  **상자 안**으로 들어와 직격이 섞이고, 그러면 세는 대상이 조용히 달라진다.
static func _spread_cx(stand_x: int) -> int:
	return floori(float(stand_x + Character.W_PX + Character.W_PX / 2) / float(Tuning.CELL_PX))


## 셀 `cx` 바닥에 내리꽂는 폭발 한 발. 무속성이라 **불이 안 붙는다** — 폭발만 잰다.
func _blast_cmd(cx: int) -> Dictionary:
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	return SpellSim.cmd_fire(cx, BLAST_FROM_CY, 0, 10, Tuning.ELEM_NONE, Glyph.pack(one))


## 🔴 **변환은 실제 코드의 것을 쓴다**(`Character._fp_px`). 그물이 제 변환을 따로 두면
##  두 벌이 되고, 그때 이 검사는 게임과 **다른 상자**를 재게 된다.
func _outside_box(box_x: int, px: float) -> bool:
	return px < float(box_x) or px > float(box_x + Character.W_PX)


func _fire_cmd() -> Dictionary:
	return SpellSim.cmd_fire(FIRE_CX, FIRE_CY, AIM_DX, 0, Tuning.ELEM_FIRE, Glyph.GLYPH_NONE)


## 세대 0의 발사 속도(고정소수점). 🔴 **표에서 뽑는다** — 박으면 값이 두 벌이 된다.
func _speed_fp() -> int:
	return Tuning.speed_cells(0) << SpellSim.FP_SHIFT


## 항력 한 번. ⚠ `spell_sim._advance` 와 **같은 차례**여야 한다 — 거기는 항력을 먼저 곱하고
##  위치를 더하므로, 한 틱 변위는 「항력을 먹인 뒤의 속도」다.
func _drag(v: int) -> int:
	return v * Tuning.DRAG_NUM / Tuning.DRAG_DEN


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	return g


func _stander() -> Character:
	return _stander_at(STAND_X)


func _stander_at(px: int) -> Character:
	var ch := Character.new()
	ch.place(px, FLOOR_TOP - Character.H_PX)
	return ch


func _world(g: CellGrid) -> WorldStep:
	return WorldStep.new(g, SpellSim.new(), _stander())


func _frames(w: WorldStep, n: int, axis := 0.0) -> void:
	for _i in n:
		w.frame(DT, axis, false, false)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_damage: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
