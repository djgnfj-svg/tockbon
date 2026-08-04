extends RefCounted
## 진 표와 조립 상태. 🔴 **여기가 잡는 것은 전부 「에러 없이 조용히 틀리는」 종류다.**
##
##  · **빈 층 팩** — 빈 층을 그대로 팩하면 `GLYPH_NONE = 0`이 「목록 끝」이라 뒤 층의 문양이
##    **통째로 증발한다.** 화면에서는 「2층에만 넣으면 아무 일도 안 일어난다」로만 보인다
##  · **빈 룬이 불로 읽힌다** — `ELEM_FIRE = 0`이라 0을 빈 값으로 쓰면 조립창은 빈칸을 그리는데
##    발사는 불이 나간다. 아래 `_empty_rune_is_not_a_rune`이 그 함정을 계약으로 못박는다
##  · **규칙이 두 벌** — 조립창이 통과시킨 배치를 `fire()`가 거부하면
##    「눌러도 아무 일이 안 일어난다」가 된다. 아래 `_both_ways_agree`만이 이걸 잰다
##  · **상수 박기** — 층 수를 2로 박으면 진을 늘려도 안 늘어나고, 표만 늙는다
##
## ⚠ **조립창 그림은 이 그물이 원리적으로 못 잰다**(계획 §7). 그건 눈의 몫이다.
##  여기는 **모델과 규칙**만 본다.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Stage := preload("res://src/stage/stage.gd")
## 🔴 좌표 함수를 **실제로 부르는** 그물이 있어야 텍스트 스캔이 못 보는 거동이 잡힌다.
const Layout := preload("res://src/view/circle_layout.gd")
const Book := preload("res://src/view/book_layout.gd")
const Palette := preload("res://src/view/palette_layout.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## `Rect2` 가 값을 **32비트 float**으로 담는 데서 오는 여유. 🔴 「딱 붙어 있어야 하는」 경계를
##  64비트 산술과 맞댈 때만 쓴다 — 넓히면 진짜 겹침을 사면한다.
##
## ⚠ **얼마나 큰 여유인가**(실측 2026-08-04): 실제 오차는 **7.6e-6** 이고 이 값은 **0.01 — 1300배**다.
##  `1e-4` 로 줄여도 통과한다. 🔴 **넉넉한 쪽을 고른 이유는 「1px의 1/100이라 눈에 보이는 겹침을
##  못 숨긴다」**이고(1px 침범을 넣으면 다섯이 빨개진다), **오차가 창 크기마다 달라지기 때문**이다.
##  ⇒ 지금 위험은 아니지만 **여기서 더 키우면 그 근거가 죽는다.**
const RECT_EPS := 0.01
## 🔴 주석·문자열 스트리퍼를 **빌려 온다** — 소스 텍스트를 훑는 그물이 둘이라 스트리퍼는 하나여야 한다.
const NetDeterminism := preload("res://tests/nets/net_determinism.gd")

## 표를 읽어야 하는 접근자들. 🔴 `circle_defs`에 접근자가 늘면 여기 한 줄을 늘려라 —
##  안 늘리면 새 접근자만 상수를 돌려줘도 아무도 안 짖는다.
const ACCESSORS: Array[String] = ["layers", "rune_slots"]

## 🔴 파일 참조를 원문에서 찾을 때 쓰는 경로들. **한 곳에 둔다** — 흩어지면 파일을 옮기는 날
##  검사 하나만 낡고, 낡은 쪽은 「없다」로 통과해서 조용해진다.
const LAYOUT_PATH := "res://src/view/circle_layout.gd"
const WINDOW_PATH := "res://src/view/circle_window.gd"
const BOOK_PATH := "res://src/view/book_layout.gd"
const PALETTE_PATH := "res://src/view/palette_layout.gd"

## 마법진 지름의 **바닥값**. 🔴 연출 상수가 아니라 **검증 계약**이라 그물에 둔다 —
##  단계 3에서 눈이 통과시킨 크기이고, 여기 아래로 내려가면 그 판정을 다시 받아야 한다.
##
## ⚠ **실측이 두 번 바뀌었다:**
##
## | 언제 | 창 | 지름 | 바닥값 여유 |
## |---|---|---|---|
## | 단계 4a | 514×286 (28.4%) | 199.3 | **19.3px** — 빠듯했다 |
## | 단계 4b-1 | 864×486 (**90%**) | **363.8** | **183.8px** |
## | `character-damage` 단계 6 | 864×**372** (가로만 90%) | **280.1** | **100.1px** |
##
## 🔴 마지막 줄은 **캐릭터가 다칠 수 있게 되면서** 창이 세로로 줄어든 것이다(사용자 판정) —
##  조립 중에도 체력과 캐릭터가 보여야 한다. **가로는 그대로라 지름이 세로에 걸려 정해진다.**
##
## 🔴 **바닥값 180은 아직 「199px에서 눈이 통과시켰다」가 근거다** — 지금 지름과 두 배 차이지만
##  **아직 안 올렸다.** verify-look이 363.8px 화면을 통과시키면 **그때 그 새 관측을 근거로 올려라.**
##  ⚠ 지금 올리면 근거 없는 숫자가 된다 — 이 리포가 계속 잡아 온 바로 그 모양이다.
##
## ⚠ 이 값이 지키는 것은 「고리 둘·룬·문양 심볼이 서로 안 먹는 크기」다. 창을 줄이거나
##  여백(`CIRCLE_AREA_PAD_PX` · `BOOK_MARGIN_PX` · `BOOK_FOLD_PX`)을 키우면 여기가 먼저 빨개진다.
##  🔴 **원인이 이 상수가 아니라는 걸 알고 만나야** 「왜 갑자기 빨갛지」로 시간을 안 버린다.
const CIRCLE_DIAMETER_FLOOR_PX := 180.0


func run(t) -> void:
	_sizes_come_from_the_table(t)
	_unknown_circle_barks(t)
	_empty_rune_is_not_a_rune(t)
	_swapping_the_circle_resizes(t)
	_resize_is_table_driven(t)
	_accessors_read_the_table(t)
	_book_pages_are_one_source(t)
	_circle_layout_does_not_know_pages(t)
	_spawn_rays_are_not_horizontal(t)
	_palette_is_kind_by_item(t)
	_symbols_are_shared(t)
	_hit_tests_match_the_drawing(t)
	_palette_geometry_runs(t)
	_layout_geometry_runs(t)
	_axes_do_not_call_each_other(t)
	_cannot_fire_without_a_rune(t)
	_empty_layer_is_skipped(t)
	_round_trip(t)
	_cap_blocks_before_placing(t)
	_both_ways_agree(t)
	_presets_still_work(t)
	_preset_restores_everything(t)


# ══════════════════════════════════════════════════════════════════
#  진 표 — 층 수와 룬 자리 수가 여기 한 곳에서 나온다
# ══════════════════════════════════════════════════════════════════

## 🔴 **조립 상태가 표에서 파생되나.** 여기 2·1을 박으면 진을 늘려도 안 늘어나고,
##  그때 조립창은 옛 층 수를 그린다 — 에러는 안 난다.
func _sizes_come_from_the_table(t) -> void:
	t.eq(CircleDefs.ALL.size(), CircleDefs.DEFS.size(), "ALL과 DEFS가 같다")
	# ⚠ 이 줄이 없으면 표가 비었을 때 아래 루프가 한 번도 안 돌고 **초록으로 통과한다.**
	t.ok(CircleDefs.ALL.size() > 0, "진이 하나라도 있다 (%d개)" % CircleDefs.ALL.size())
	# 🔴 「없음」은 진이 아니다 — 팔레트가 `ALL`을 도는데 여기 있으면 「없음」이 항목으로 뜬다.
	t.ok(not CircleDefs.ALL.has(CircleDefs.CIRCLE_NONE), "CIRCLE_NONE은 ALL 안에 없다")
	t.ok(not CircleDefs.DEFS.has(CircleDefs.CIRCLE_NONE), "CIRCLE_NONE은 표에 없다 (예약값이다)")

	for id: int in CircleDefs.ALL:
		var c := SpellCircle.new(id)
		var nm: StringName = CircleDefs.DEFS[id]["name"]
		t.eq(c.circle_id(), id, "진 %s가 자기 id를 기억한다" % nm)
		t.eq(c.layer_count(), CircleDefs.layers(id), "진 %s의 층 수가 표에서 나온다" % nm)
		t.eq(c.rune_count(), CircleDefs.rune_slots(id), "진 %s의 룬 자리 수가 표에서 나온다" % nm)

		# 🔴 접근자를 **표와 직접** 맞댄다. 위 두 줄은 「모델이 접근자를 따라가나」만 본다.
		#  ⚠ **이 두 줄로는 `return 2` 뮤테이션을 못 잡는다** — 표의 값이 마침 2라서
		#   상수와 표가 같은 답을 낸다. 진이 1종인 한 **값으로는 원리적으로 못 가른다.**
		#   ⇒ 그 구멍은 아래 `_accessors_read_the_table`이 텍스트로 막는다.
		#   여기 두 줄이 잡는 것은 **표의 값과 다른 상수**(`return 5` 꼴)다.
		t.eq(CircleDefs.layers(id), int(CircleDefs.DEFS[id]["layers"]),
			"진 %s의 층 수 접근자가 표와 같은 값을 준다" % nm)
		t.eq(CircleDefs.rune_slots(id), int(CircleDefs.DEFS[id]["rune_slots"]),
			"진 %s의 룬 자리 접근자가 표와 같은 값을 준다" % nm)
		# 🔴 층이 목록 상한을 넘으면 `pack`이 짖는다 — 표만 늘리고 여기를 안 보면
		#  「층을 다 채우면 발사가 죽는다」가 된다.
		t.ok(c.layer_count() <= Tuning.GLYPH_MAX_LAYERS,
			"진 %s의 층 %d개가 목록 상한 %d 안이다" % [nm, c.layer_count(), Tuning.GLYPH_MAX_LAYERS])
		t.ok(c.rune_count() >= 1, "진 %s에 룬 자리가 하나는 있다" % nm)
		# 새 진의 층은 전부 비어 있다 — 안 비면 첫 발사가 아무도 안 놓은 문양을 실어 나른다.
		t.eq(c.packed_glyphs(), Glyph.GLYPH_NONE, "새 진 %s는 빈 목록이다" % nm)
		# 🔴 **시작 상태는 진·룬이 채워져 있다.** 빈 룬으로 켜지면 게임이 「못 쏘는」 상태로 시작한다.
		t.ok(c.can_fire(), "새 진 %s는 바로 쏠 수 있다 (룬이 채워져 있다)" % nm)

	# 🔴 GDD 확정값. 표가 조용히 바뀌면 이 줄이 먼저 빨개진다.
	var round_id := CircleDefs.CIRCLE_ROUND
	t.eq(CircleDefs.layers(round_id), 2, "동그라미 진은 2층이다 (GDD)")
	t.eq(CircleDefs.rune_slots(round_id), 1, "동그라미 진은 룬 1자리다 (GDD)")


## 🔴 표에 없는 진에 짖는다 — 진을 늘리면서 표에 안 넣으면 래퍼의 stderr 검사에 공짜로 걸린다.
## ⚠ **「진이 없다」는 짖지 않는다.** 그건 정상 상태다 — 둘을 한 갈래로 묶으면 진을 빼는
##  평범한 조작이 그물을 빨갛게 만든다.
func _unknown_circle_barks(t) -> void:
	t.eq(CircleDefs.layers(CircleDefs.CIRCLE_NONE), 0, "진이 없으면 층이 0이다 (조용히)")
	t.eq(CircleDefs.rune_slots(CircleDefs.CIRCLE_NONE), 0, "진이 없으면 룬 자리가 0이다 (조용히)")

	# ⚠ 선언에 파일 이름을 붙인다 — 사면이 **실행 전체**에 걸리므로 넓게 적으면
	#  다른 파일의 같은 문구까지 같이 사면된다(135줄 주석).
	t.expect_error("Circle: 모르는 진")
	var bad := SpellCircle.new(9999)
	t.eq(bad.layer_count(), 0, "모르는 진은 짖고 층이 0이다")
	t.eq(bad.packed_glyphs(), Glyph.GLYPH_NONE, "층이 0이면 빈 목록이다 (폭주하지 않는다)")


# ══════════════════════════════════════════════════════════════════
#  🔴🔴 빈 룬 — 0은 이미 불이다
# ══════════════════════════════════════════════════════════════════

## `sim_tuning.ELEM_FIRE = 0`이라 **룬은 0 규율을 못 쓴다.** 0을 빈 룬으로 쓰면
## 조립창은 빈칸을 그리는데 발사는 불이 나가고, **에러가 하나도 안 난다.**
## 🔴 이 한 줄이 그 함정을 계약으로 못박는다.
func _empty_rune_is_not_a_rune(t) -> void:
	t.ok(not Tuning.ELEM_ALL.has(SpellCircle.RUNE_EMPTY),
		"RUNE_EMPTY(%d)가 ELEM_ALL 안에 없다" % SpellCircle.RUNE_EMPTY)
	t.ok(SpellCircle.RUNE_EMPTY != Tuning.ELEM_FIRE, "RUNE_EMPTY가 불 룬이 아니다")
	# ⚠ 함정의 반대쪽 — 0이 실재 룬이라는 것 자체를 재 둔다. 이게 바뀌면 위 규율의 근거가 사라진다.
	t.eq(Tuning.ELEM_FIRE, 0, "불 룬이 0이다 (그래서 0을 빈 값으로 못 쓴다)")

	# 🔴 모르는 룬은 안 받는다 — 받으면 `can_fire()`가 통과시키고 `fire()`가 커맨드 경계에서 짖는다.
	var c := SpellCircle.new()
	t.expect_error("SpellCircle: 모르는 룬")
	t.ok(not c.set_rune(0, 777), "모르는 룬은 짖고 안 놓인다")
	t.eq(c.rune_at(0), Tuning.ELEM_FIRE, "거절된 룬이 자리를 안 건드린다")


## 🔴 룬을 빼면 못 쏜다. 기획 「극단값」이 「진+룬만으로도 마법은 성립한다」고 적은 문장에
##  **문양은 없어도 되고 룬은 있어야 한다**가 이미 들어 있다.
func _cannot_fire_without_a_rune(t) -> void:
	var c := SpellCircle.new()
	t.ok(c.can_fire(), "룬이 있으면 쏠 수 있다")

	t.ok(c.set_rune(0, SpellCircle.RUNE_EMPTY), "룬을 뺀다")
	t.eq(c.rune_at(0), SpellCircle.RUNE_EMPTY, "룬 자리가 비었다")
	t.ok(not c.can_fire(), "🔴 빈 룬 자리가 있으면 못 쏜다")

	t.ok(c.set_rune(0, Tuning.ELEM_FIRE), "룬을 다시 넣는다")
	t.ok(c.can_fire(), "다시 넣으면 쏠 수 있다")

	# 🔴 문양은 없어도 쏜다 — 룬과 문양의 규칙이 다르다는 것이 요점이다.
	var bare := SpellCircle.new()
	t.eq(bare.packed_glyphs(), Glyph.GLYPH_NONE, "문양이 하나도 없다")
	t.ok(bare.can_fire(), "문양이 없어도 쏠 수 있다 (진 + 룬만)")

	# 진이 없으면 못 쏜다.
	var gone := SpellCircle.new()
	gone.set_circle(CircleDefs.CIRCLE_NONE)
	t.ok(not gone.can_fire(), "진이 없으면 못 쏜다")

	# ⚠ 빈 룬은 커맨드를 **아예 안 만드는** 길로 가야 한다 — 만들면 `fire()`가 짖는다.
	#  껍데기가 `can_fire()`를 안 보면 정확히 이 짖음이 난다.
	#
	# 🔴🔴 **선언에 파일 이름을 붙인다.** 래퍼의 사면은 한 그물이 아니라 **실행 전체**에 걸리므로,
	#  그냥 `모르는 룬`이라고 적으면 `SpellCircle: 모르는 룬`까지 같이 사면된다 —
	#  그러면 위 `set_rune`이 **정상 입력(빈 룬)에도 짖게 되는 날 stderr가 깨끗하게 나온다.**
	#  ⚠ 실제로 그랬다(verify-read가 뮤테이션으로 실증했다). 사면은 늘 좁게 적는다.
	var sim := SpellSim.new()
	t.expect_error("SpellSim: 모르는 룬")
	t.ok(not sim.fire(SpellSim.cmd_fire(10, 70, 100, 0,
		SpellCircle.RUNE_EMPTY, Glyph.GLYPH_NONE)),
		"빈 룬으로 커맨드를 만들면 발사가 짖는다 (그래서 안 만든다)")


# ══════════════════════════════════════════════════════════════════
#  진 교체 — 배열 길이가 런타임에 바뀐다
# ══════════════════════════════════════════════════════════════════

## 🔴 진마다 층 수가 다르므로 `layers[]`는 **런타임에 길이가 변한다.** 진이 1종이라 지금은
##  안 드러나지만, 모델이 그걸 표현 못 하면 진이 둘이 되는 날 모델을 다시 만든다.
func _swapping_the_circle_resizes(t) -> void:
	var c := SpellCircle.new()
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "1층에 확산을 놓는다")
	t.ok(c.place_glyph(1, Glyph.GLYPH_BLAST), "2층에 폭발을 놓는다")

	# ⚠ **같은 진을 다시 놓는 것은 아무 일도 안 한다** — 안 그러면 실수로 한 번 더 클릭해서
	#  조립이 통째로 날아간다.
	var before := c.packed_glyphs()
	c.set_circle(CircleDefs.CIRCLE_ROUND)
	t.eq(c.packed_glyphs(), before, "같은 진을 다시 놓으면 조립이 안 날아간다")
	t.ok(c.can_fire(), "같은 진을 다시 놓아도 룬이 남는다")

	# 🔴 **진을 바꾸면 층과 룬 자리를 전부 비운다.** 앞에서부터 살리면 마지막 문양 하나가
	#  **조용히** 사라진다 — 통째로 비우면 그림이 통째로 바뀌어 눈에 보인다.
	c.set_circle(CircleDefs.CIRCLE_NONE)
	t.eq(c.layer_count(), 0, "진을 빼면 층이 0이다")
	t.eq(c.rune_count(), 0, "진을 빼면 룬 자리가 0이다")
	t.eq(c.packed_glyphs(), Glyph.GLYPH_NONE, "진을 빼면 문양이 남지 않는다")
	t.ok(not c.can_fire(), "진을 빼면 못 쏜다")
	t.ok(not c.place_glyph(0, Glyph.GLYPH_BLAST), "진이 없으면 문양을 못 놓는다")
	t.ok(not c.set_rune(0, Tuning.ELEM_FIRE), "진이 없으면 룬을 못 놓는다")

	# 🔴 다시 놓으면 길이가 표를 따라간다.
	c.set_circle(CircleDefs.CIRCLE_ROUND)
	t.eq(c.layer_count(), CircleDefs.layers(CircleDefs.CIRCLE_ROUND),
		"진을 다시 놓으면 층 수가 표를 따라간다")
	t.eq(c.rune_count(), CircleDefs.rune_slots(CircleDefs.CIRCLE_ROUND),
		"진을 다시 놓으면 룬 자리 수가 표를 따라간다")
	t.eq(c.packed_glyphs(), Glyph.GLYPH_NONE, "새로 놓은 진의 층은 비어 있다")
	# ⚠ **진을 놓으면 룬 자리도 빈다** — 시작 상태(생성자)만 룬을 채운다. 둘을 헷갈리면
	#  「진을 바꿨더니 룬이 저절로 생겼다」가 된다.
	t.eq(c.rune_at(0), SpellCircle.RUNE_EMPTY, "새로 놓은 진의 룬 자리는 비어 있다")
	t.ok(not c.can_fire(), "그래서 진을 새로 놓으면 룬을 넣기 전엔 못 쏜다")

	# 🔴 **두 길이가 서로 다른 수여야 한 상수로 둘 다 못 채운다.** 같은 수면
	#  `resize(2)`를 두 줄 박아 놓고도 이 그물이 초록이다.
	t.ok(c.layer_count() != c.rune_count(),
		"층 수(%d)와 룬 자리 수(%d)가 서로 다른 수다 (한 상수로 둘 다 못 채운다)" % [
			c.layer_count(), c.rune_count()])


## 🔴🔴 **진이 1종이라 「층 배열이 표를 따라가나」를 실행만으로는 끝까지 못 잰다**(계획 위험 16).
##  닿을 수 있는 층 수가 **2(동그라미)와 0(없음) 둘뿐**이라, `id == CIRCLE_NONE ? 0 : 2`라고
##  박아 놔도 위 검사가 전부 초록이다.
##
## ⚠ **계획은 「그물이 표를 손으로 하나 더 만들어 재라」고 했는데 그게 안 된다** —
##  `DEFS`가 `const`라 Godot이 읽기 전용으로 강제한다(실측: `DEFS.is_read_only()`가 true고,
##  줄을 넣으면 「Dictionary is in read-only state」가 뜬다).
##
## ⇒ **대신 소스 텍스트를 본다.** `net_determinism`이 같은 이유로 쓰는 장치다 —
##  실행으로 원리적으로 못 재는 계약은 **텍스트 스캔이 유일한 감지기**다.
##  🔴 재는 것은 좁다: **길이를 정하는 곳이 전부 진 표를 지나나.**
##
## 🔴🔴 **주석과 문자열을 먼저 걷어낸다.** 안 걷으면 주석에 `.resize(nl)` 한 줄만 적어도
##  빨개진다(verify-read 실측). ⚠ **거짓 양성이 거짓 음성보다 나쁠 수 있다** —
##  못 믿는 그물은 다음 사람이 지운다.
## ⚠ 스트리퍼는 `net_determinism`의 것을 **빌려 쓴다.** 베끼면 두 벌이 되고,
##  한쪽만 고쳐지는 날 두 그물이 서로 다른 텍스트를 본다(CLAUDE.md).
func _resize_is_table_driven(t) -> void:
	var raw := _read("res://src/actor/spell_circle.gd")
	# ⚠ `_strip`이 삼중 따옴표를 못 다룬다 — 그러면 파일 나머지가 통째로 스캔에서 빠지고
	#  **조용히 초록**이 된다. `net_determinism`이 같은 가정을 재는 자리다.
	t.ok(not raw.contains("\"\"\""), "spell_circle에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	var re := RegEx.new()
	t.eq(re.compile("\\.resize\\(([^)]*)\\)"), OK, "resize 패턴이 컴파일된다")
	var hits := re.search_all(src)
	# ⚠ 하나도 못 찾으면 이 검사는 **아무것도 안 재고 초록이 된다** — 그게 이 리포가 죽는 방식이다.
	t.ok(hits.size() >= 2,
		"spell_circle이 배열 길이를 정하는 곳이 %d군데다 (층 · 룬)" % hits.size())
	for m: RegExMatch in hits:
		var arg := m.get_string(1)
		t.ok(arg.contains("CircleDefs."),
			"길이 `%s`가 진 표에서 나온다 (상수 박기가 아니다)" % arg)
	_layout_reads_the_table(t)


## 🔴🔴 **모델만 스캔하면 그림에 박힌 2를 못 잡는다**(계획 §6.1).
##  그러면 「모델은 3층인데 **셋째 고리가 안 그려진다**」가 되고, 그건 층 수가 안 따라오는 것보다
##  **더 나쁘다** — 시뮬만 늘고 화면이 안 따라가는 것이 v1이 죽은 방식이다.
##  ⇒ 층 수·룬 자리 수를 읽는 곳이 **두 파일 통틀어** 전부 진 표를 지나야 한다.
##
## 🔴 재는 것 둘, 그리고 **각각이 어느 파일에 걸리는지가 다르다:**
##   ① 좌표 파일이 두 접근자를 **부르나** — `circle_layout.gd`만. 그림 파일은 모델(`layer_count()`)을
##      보므로 접근자를 부를 이유가 없다
##   ② 개수를 **숫자로 박은 순회가 없나** — 🔴 **두 파일 다.** 그림의 `for i in 2`도 고리 수를 얼린다
##  ⚠ **라벨을 코드보다 넓게 적지 마라.** 「두 파일 통틀어」라고 적고 한 파일만 훑으면
##   그 문장이 다음 사람에게 거짓 보증이 된다(실측으로 그랬다).
func _layout_reads_the_table(t) -> void:
	var layout := _stripped(t, "res://src/view/circle_layout.gd", "circle_layout")
	for fname: String in ACCESSORS:
		t.ok(layout.contains("CircleDefs.%s(" % fname),
			"좌표가 `CircleDefs.%s()` 를 부른다" % fname)

	# ⚠ `range(2)`가 우회로다 — `for i in 2`만 보면 한 글자로 빠져나간다.
	var re := RegEx.new()
	t.eq(re.compile("for\\s+\\w+\\s+in\\s+(?:range\\s*\\(\\s*)?\\d"), OK,
		"숫자 순회 패턴이 컴파일된다")
	var files := {
		"circle_layout": layout,
		"circle_window": _stripped(t, "res://src/view/circle_window.gd", "circle_window"),
	}
	for nm: String in files.keys():
		t.ok(re.search(files[nm]) == null, "%s 가 개수를 숫자로 박은 순회를 안 한다" % nm)


## 🔴🔴 **접근자 자신이 표를 읽나.** 위 `_sizes_come_from_the_table`은 이걸 **원리적으로 못 잰다** —
##  진이 1종이고 그 진의 층이 2라, `layers()`를 `return 2`로 바꿔도 표와 **같은 값**이 나온다.
##  ⚠ 실측했다: 그렇게 바꾸고 그물을 돌리니 **접근자 검사까지 포함해 전부 초록이었다.**
##
## ⇒ 값으로 못 가르므로 **텍스트로 가른다.** 위 `_resize_is_table_driven`과 같은 이유·같은 장치다.
## 🔴 재는 것은 좁다: **각 접근자 몸통이 `DEFS[`를 지나나.** `return 2`가 되면 그 줄이 사라진다.
##  ⚠ 표를 어떻게 읽든(중간 변수를 두든) `DEFS[`는 남으므로 정상 리팩터링에는 안 문다.
func _accessors_read_the_table(t) -> void:
	var raw := _read("res://src/sim/circle_defs.gd")
	t.ok(not raw.contains("\"\"\""), "circle_defs에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)")
	var src := NetDeterminism._strip(raw)
	# ⚠ 목록이 비면 아래가 한 번도 안 돌고 **초록이 된다.**
	t.ok(ACCESSORS.size() > 0, "재 볼 접근자가 %d개다" % ACCESSORS.size())
	for fname: String in ACCESSORS:
		var body := _func_body(src, fname)
		t.ok(body != "", "circle_defs에 %s()가 있다" % fname)
		t.ok(body.contains("DEFS["), "%s()가 표를 읽는다 (상수를 안 돌려준다)" % fname)


## 🔴🔴 **페이지 사각형이 한 곳에서 나오나 — 그리고 그게 실제로 책 모양인가.**
##  ⚠ 접힘은 장식이 아니라 **경계의 그림**이다. 보이는 경계와 (단계 4b의) 클릭 경계가 다르면
##   「이쪽을 눌렀는데 저쪽이 반응한다」가 되고 **에러가 안 난다**(위험 23).
##  ⇒ 접힘이 두 페이지를 **정확히** 가르는지를 잰다 — 틈이 있으면 그 틈이 어느 쪽도 아니게 된다.
func _book_pages_are_one_source(t) -> void:
	var win := Fx.WINDOW_RECT.size
	var pages := Book.pages(win)
	for key: String in ["left", "fold", "right"]:
		t.ok(pages.has(key), "페이지 표에 `%s` 가 있다" % key)
	if not (pages.has("left") and pages.has("fold") and pages.has("right")):
		return
	var l: Rect2 = pages["left"]
	var f: Rect2 = pages["fold"]
	var r: Rect2 = pages["right"]

	t.ok(l.size.x > 0.0 and l.size.y > 0.0, "왼쪽 페이지에 크기가 있다 (%dx%d)" % [
		int(l.size.x), int(l.size.y)])
	t.ok(r.size.x > 0.0 and r.size.y > 0.0, "오른쪽 페이지에 크기가 있다 (%dx%d)" % [
		int(r.size.x), int(r.size.y)])
	# ⚠ 폭이 다르면 「본문 + 곁다리」로 읽히고 책 펼침이 아니다.
	t.ok(is_equal_approx(l.size.x, r.size.x), "두 페이지 폭이 같다 (%.1f · %.1f)" % [
		l.size.x, r.size.x])
	t.ok(not l.intersects(r), "두 페이지가 안 겹친다")

	# 🔴 접힘이 **딱 붙어** 둘을 가른다. 틈이 생기면 그 띠가 어느 페이지도 아니게 된다.
	t.ok(is_equal_approx(l.end.x, f.position.x), "접힘이 왼쪽 페이지에 붙어 있다")
	t.ok(is_equal_approx(f.end.x, r.position.x), "접힘이 오른쪽 페이지에 붙어 있다")
	t.ok(f.size.x > 0.0, "접힘에 폭이 있다 (경계가 보인다)")

	# 창 안에 들어가나 · 제목 띠를 침범 안 하나.
	var win_rect := Rect2(Vector2.ZERO, win)
	for key: String in ["left", "fold", "right"]:
		var p: Rect2 = pages[key]
		t.ok(win_rect.encloses(p), "%s 가 창 안에 들어간다" % key)
		t.ok(p.position.y >= Fx.WINDOW_TITLE_BAND_PX, "%s 가 제목 띠 아래에서 시작한다" % key)

	# 🔴 **어느 페이지가 마법진인가를 그물도 `book_layout`에서 읽는다.** 여기 키를 박으면
	#  좌우를 뒤집는 날 **창만 뒤집히고 그물은 옛 페이지를 재면서 초록**이 된다.
	var circle_page := Book.circle_page(win)
	var palette_page := Book.palette_page(win)
	t.ok(not circle_page.intersects(palette_page), "마법진 페이지와 팔레트 페이지가 안 겹친다")
	# 🔴🔴 **사용자 판정을 핀으로 박는다** (2026-08-03: 「왼쪽에 마법진, 오른쪽에는 진·룬·문양」).
	#  ⚠ **동어반복이 아니다** — 상수와 맞대는 게 아니라 **판정을 고정한다.** 다시 뒤집는 날
	#   이 두 줄을 같이 고치는 것이 곧 「판정이 바뀌었다」의 기록이 된다.
	#   그게 없으면 좌우가 조용히 왔다 갔다 하고, 나중에 왜 이쪽인지 아무도 모른다.
	#  ⚠ spec의 처음 안은 **반대**였다(왼쪽 팔레트). 그래서 더 박아 둘 값어치가 있다.
	t.ok(circle_page == l, "마법진이 **왼쪽** 페이지다 (사용자 판정)")
	t.ok(palette_page == r, "팔레트가 **오른쪽** 페이지다 (사용자 판정)")
	# ⚠🔴 **「마법진이 바깥쪽이다」(§3.7 ③)는 여기서 못 잰다 — 재려다 동어반복을 만들었다.**
	#  `circle.position.x <= palette.position.x or circle.end.x >= palette.end.x` 로 적었더니
	#  **좌우를 완전히 반전해도 초록이었다**(실측). 페이지가 둘뿐이면 **둘 다 한쪽에서 바깥**이라
	#  그 술어가 늘 참이다.
	#  🔴🔴 **그리고 ③ 자체가 지금 코드에서 거짓이다.** `pages()` 가 창을 늘 정확히 반으로 가르므로
	#   마법진은 어느 쪽에 있든 **자기 절반 안에서 좁아질 뿐 바깥으로 자랄 수가 없다.**
	#   ⚠ 「룬 자리가 여럿인 진이 오면 잴 것이 생긴다」는 **절반만 맞았다** —
	#    **걸리는 것은 진의 종류가 아니라 분할 방식이다.** 진이 와도 `pages()` 가 지금 모양이면
	#    여전히 못 잰다. ⇒ `pages()` 가 **비대칭 분할**을 할 수 있게 되는 날 잴 것이 생긴다.

	# 🔴🔴 **계약: 마법진 페이지가 진 지름을 담는다.**
	#
	# ⚠ 처음엔 `지름 <= min(페이지)`로 적었는데 **그건 동어반복이었다** — 실측으로 확인했다:
	#  페이지를 반으로 줄여도 초록이었다. 반지름이 페이지에서 **파생**되므로 언제나 참이다.
	#  ⇒ 재야 하는 것은 「넘치나」가 아니라 **「쓸 만한 크기로 남나」**다.
	#
	# 🔴 바닥값의 근거: 단계 3에서 verify-look이 **지름 ~199px 마법진**으로 판정 3
	#  (층 번호와 명도차가 읽힌다)을 통과시켰다. 여기서 더 작아지면 **그 판정이 낡는다** —
	#  고리 둘·룬·문양 심볼이 그 안에 다 들어가야 하고, 작아지면 서로 먹는다.
	#  ⚠ 창을 줄이고 싶으면 이 줄을 낮추기 전에 **눈으로 다시 봐라.**
	var area := Layout.circle_area(circle_page.size)
	var fr: float = Layout.frame(area)["radius"]
	t.ok(fr > 0.0, "마법진 페이지에서 진 반지름이 나온다 (%.1f)" % fr)
	t.ok(fr * 2.0 >= CIRCLE_DIAMETER_FLOOR_PX,
		"진 지름(%.1f)이 바닥값 %d 이상이다 (페이지 %dx%d)" % [
			fr * 2.0, int(CIRCLE_DIAMETER_FLOOR_PX),
			int(circle_page.size.x), int(circle_page.size.y)])

	# 창이 화면 안에 있나. ⚠ 「몇 %냐」는 안 잰다 — 그 숫자는 낡는다(계획 §3.7).
	#  「캐릭터가 보이나」는 **눈이 판정한다.**
	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	t.ok(Rect2(0.0, 0.0, vw, vh).encloses(Fx.WINDOW_RECT), "창이 화면 안에 들어간다")


## 🔴🔴 **마법진이 페이지를 모르나.** 알게 되는 순간 창 모양이 바뀔 때마다 마법진 코드가 열린다 —
##  단계 3에서 층 축이 진 축에 매달렸던 것과 **똑같은 병이 한 층 위에서** 반복되는 것이다.
## 🔴 재는 것은 **참조 두 개**다: 창 축 파일을 부르나 · 창 상수를 읽나.
func _circle_layout_does_not_know_pages(t) -> void:
	# ⚠ **파일 참조는 원문으로 본다.** `preload` 경로가 문자열이라 스트리퍼가 지워 버리고,
	#  스트립한 소스로 재면 **진짜 결합을 못 보고 초록이 된다**(실측으로 그랬다).
	#  🔴 `net_layers`가 죽은 경로를 찾을 때 쓰는 것과 같은 방식이고 대가도 같다 —
	#   주석에 그 경로를 적어도 걸린다(거짓 양성이지만 **빨갛게** 틀리므로 조용히 새지 않는다).
	var raw := _read(LAYOUT_PATH)
	t.ok(not raw.contains(BOOK_PATH), "마법진 좌표가 창 축 파일을 안 부른다")
	var src := _stripped(t, LAYOUT_PATH, "circle_layout")
	t.ok(not src.contains("Fx.WINDOW_"), "마법진 좌표가 창 상수를 안 읽는다")

	# 🔴 반대쪽 — 창은 **둘 다** 알아야 한다. 아니면 위 둘이 「아무도 아무것도 안 쓴다」로 통과한다.
	# ⚠ **원문으로 보는 대가의 반대쪽**: `preload`를 지우고 **주석에 경로만 남겨도 통과한다.**
	#  지금 그 상황은 아니라 그대로 두지만, 이 두 줄을 「참조가 있다」로 읽지 마라 —
	#  참값은 「그 글자가 파일 어딘가에 있다」다.
	var wraw := _read(WINDOW_PATH)
	t.ok(wraw.contains(BOOK_PATH), "창이 창 축을 조립한다")
	t.ok(wraw.contains(LAYOUT_PATH), "창이 마법진 축을 조립한다")
	var win := _stripped(t, WINDOW_PATH, "circle_window")

	# ══ 🔴🔴 여기부터는 전부 **「창이 그 값을 쓰나」**다 ══════════════
	# ⚠ 위 검사들은 **「값이 맞나」**만 잰다. 값이 맞아도 창이 **다른 값을 쓰면** 화면이 틀리고,
	#  그 갈라짐은 전부 **에러가 안 난다.** 실측으로 넷이 통과했다(verify-read 뮤테이션).

	# 🔴 **결합의 셋째 길: 그냥 인자로 받으면 된다.**
	#  `circle_area(box, origin := Vector2.ZERO)` 로 고치고 창이 `page.position`을 넘기면
	#  `book_layout`도 `Fx.WINDOW_`도 안 건드린 채 **마법진이 자기 자리를 알게 된다.**
	#  ⚠ **거동으로는 원리적으로 못 잡는다** — 기본값이 ZERO라 그물이 인자 없이 부르면 답이 같다.
	#  ⇒ 시그니처를 못박는 수밖에 없다.
	t.ok(src.contains("func circle_area(box: Vector2) -> Rect2"),
		"마법진 자리 함수가 **크기만** 받는다 (자리를 안 받는다)")

	# 🔴 **팔레트도 같은 계약인데 핀이 없었다.** `section()`에 `origin` 인자를 붙여도 초록이었다
	#  (실측). ⚠ 같은 성격의 계약에 한쪽만 박아 두면 **안 박은 쪽이 조용히 깨진다.**
	var pal_src := _stripped(t, PALETTE_PATH, "palette_layout")
	t.ok(pal_src.contains("func section(page_size: Vector2, kind_index: int) -> Rect2"),
		"팔레트 구획 함수가 **크기만** 받는다 (자리를 안 받는다)")
	t.ok(pal_src.contains("func item_at(page_size: Vector2, p: Vector2) -> Dictionary"),
		"팔레트 히트테스트가 **크기와 점만** 받는다")
	t.ok(not pal_src.contains("Fx.WINDOW_"), "팔레트가 창 상수를 안 읽는다")
	t.ok(not _read(PALETTE_PATH).contains(BOOK_PATH), "팔레트가 창 축 파일을 안 부른다")

	var draw := _func_body(win, "_draw")
	t.ok(draw != "", "창의 `_draw()` 를 찾았다")
	# 🔴 창이 **페이지 크기**를 넘기나. `size`(창 전체)를 넘기면 반지름이 커져
	#  마법진이 접힘을 넘어 **왼쪽 페이지를 침범한다** — 그림만 틀리고 아무도 안 짖는다.
	t.ok(draw.contains("Layout.circle_area(page.size)"),
		"창이 마법진에 **페이지 크기**를 넘긴다 (창 크기가 아니다)")
	# 🔴 창이 페이지 키를 **직접 박지 않는다.** 박으면 좌우를 뒤집을 때 창만 뒤집히고
	#  그물은 옛 페이지를 재면서 **둘 다 초록**이다.
	#
	# ⚠🔴🔴 **「부르나」만 보고 「쓰나」는 안 보는 검사** — 이 리포에서 **세 번째 같은 형태**다:
	#   ① 단계 1   — 표를 **언급만** 해도 통과 (`resize` 스캔)
	#   ② 단계 4a  — `preload` 를 지우고 **주석에 경로만** 남겨도 통과
	#   ③ 여기     — `Book.circle_page(` 를 **부르기만 하고** 실제로는 `pages["right"]` 를 써도 통과
	#
	# 🔴 **텍스트 검사를 늘려서 이 구멍을 못 막는다.** 「그 값이 결과에 닿나」는 **거동**이고
	#  텍스트는 원리적으로 **문법**만 본다. 막는 것은 실행 검사뿐이며, 그건 진이 2종이 되어
	#  두 배치를 실제로 돌려 볼 수 있는 날 열린다.
	# ⚠ **그래서 일부러 안 좁혔다** — 좁히면 정상 리팩터링(중간 변수로 빼기 등)에 무는
	#  거짓 양성이 생기고, 못 믿는 그물은 다음 사람이 지운다.
	#
	# 🔴🔴 **이 줄의 값어치는 「제일 순진한 실수 하나」를 막는 데까지다. 보장으로 읽지 마라.**
	t.ok(draw.contains("Book.circle_page("),
		"창이 마법진 페이지를 `book_layout`에게 묻는다 (키를 안 박는다)")

	# ⚠ 그리기가 변환을 쓰면 **되돌리는 줄이 반드시 있어야 한다** — 없으면 뒤에 붙는 것이
	#  전부 페이지만큼 밀리고, 지금은 뒤에 아무것도 없어서 증상조차 없다.
	# 🔴 **개수만 세면 안 된다**(실측): 되돌리는 줄을 `draw_set_transform(page.position)` 으로
	#  바꿔도 개수는 2라 초록이고, 그러면 변환이 **영영 안 돌아온다** —
	#  4b에서 왼쪽 페이지 그림이 통째로 오른쪽으로 밀린다.
	# ⚠ 페이지가 둘이 되며 변환 쌍도 둘이 됐다(마법진 · 팔레트) — **개수를 박지 말고 짝을 잰다.**
	var xf_all := win.count("draw_set_transform")
	var xf_reset := win.count("draw_set_transform(Vector2.ZERO)")
	t.ok(xf_all > 0, "창이 좌표계를 옮겨 그린다 (%d곳)" % xf_all)
	t.eq(xf_reset * 2, xf_all, "건 만큼 **항등으로** 되돌린다 (걸기 %d · 되돌리기 %d)" % [
		xf_all - xf_reset, xf_reset])

	# 🔴 페이지 셋을 **페이지 표에서** 그리나. 따로 계산해 그리면 4b의 히트테스트는 `pages()`를
	#  읽으므로 **보이는 골과 반응하는 골이 어긋난다**(위험 23).
	#  ⚠ 문자열 키라 **원문**을 봐야 한다 — 스트리퍼가 따옴표 **안팎을 통째로** 지운다.
	var draw_raw := _func_body(wraw, "_draw")
	t.ok(draw_raw != "", "원문에서 창의 `_draw()` 를 찾았다")
	for key: String in ["left", "fold", "right"]:
		t.ok(draw_raw.contains("draw_rect(pages[\"%s\"]" % key),
			"창이 `%s` 를 페이지 표에서 그린다" % key)


## 🔴🔴 **팔레트는 「슬롯 종류 × 항목」이다. 「문양 팔레트」가 아니다.**
##  ⚠ 문양 전용으로 짜면 진·룬을 붙일 때 **통째로 다시 짠다** — 계획이 이 단계에서 제일 비싼
##   실수라고 🔴🔴로 박아 뒀다. 단계 5는 **칸 둘을 늘리는 일**이어야 한다.
##
## 🔴 그리고 **항목이 표에서 나오나** — 손으로 적으면 표를 늘렸는데 팔레트가 안 늘어도 조용하다.
func _palette_is_kind_by_item(t) -> void:
	t.eq(Palette.KINDS.size(), Palette.KIND_DEFS.size(), "슬롯 종류의 KINDS와 KIND_DEFS가 같다")
	# ⚠ 비면 아래가 한 번도 안 돌고 **초록이 된다.**
	t.ok(Palette.KINDS.size() > 0, "슬롯 종류가 %d개다" % Palette.KINDS.size())
	# 🔴 종류가 셋이라는 것이 팔레트 **구조**다 — 문양 하나만 있으면 문양 전용 팔레트다.
	t.ok(Palette.KINDS.has(Palette.KIND_CIRCLE), "진 칸이 있다")
	t.ok(Palette.KINDS.has(Palette.KIND_RUNE), "룬 칸이 있다")
	t.ok(Palette.KINDS.has(Palette.KIND_GLYPH), "문양 칸이 있다")

	# 🔴🔴 **항목이 표를 그대로 따라간다.**
	#  ⚠ 지금은 같은 값이지만 **동어반복이 아니다** — 누가 `[1, 2]` 라고 손으로 적으면
	#   표가 느는 날 여기가 빨개진다. 그게 이 검사가 사는 시점이다.
	# ⚠ **개수만 재면 손으로 적은 목록이 통과한다** — `[GLYPH_SPREAD, GLYPH_BLAST]` 라고
	#  적어도 개수가 2라 초록이었다(실측). ⇒ **값까지 맞댄다.**
	var want := {
		Palette.KIND_CIRCLE: CircleDefs.ALL,
		Palette.KIND_RUNE: Tuning.ELEM_ALL,
		Palette.KIND_GLYPH: Glyph.ALL,
	}
	for kind: int in Palette.KINDS:
		var nm: StringName = Palette.KIND_DEFS[kind]["name"]
		var items := Palette.items_of(kind)
		t.ok(items.size() > 0, "%s 칸에 항목이 있다 (%d개)" % [nm, items.size()])
		t.eq(Array(items), Array(want[kind] as Array), "%s 항목이 표와 **값까지** 같다" % nm)

	# 🔴 모르는 종류에 짖는다 — 종류를 늘리고 표를 안 이으면 그 칸이 **조용히 빈다.**
	t.expect_error("PaletteLayout: 모르는 슬롯 종류")
	t.eq(Palette.items_of(9999).size(), 0, "모르는 종류는 짖고 항목이 0이다")


## 🔴🔴 **히트테스트가 그림과 같은 좌표를 쓰나 — 그리고 실제로 맞나.**
##  ⚠ 좌표가 두 곳이면 「이걸 눌렀는데 저게 골라진다」가 되고 **에러가 안 난다**(위험 6).
## 🔴 여기는 텍스트가 아니라 **실행**으로 잰다 — 그린 자리를 그대로 눌러 본다.
func _hit_tests_match_the_drawing(t) -> void:
	var page := Book.circle_page(Fx.WINDOW_RECT.size)
	var area := Layout.circle_area(page.size)
	var id := CircleDefs.CIRCLE_ROUND

	# 🔴 **그린 자리를 누르면 그 층이 나온다.** 층마다 자기 번호가 나와야 한다.
	var slots := Layout.layer_slots(id, area)
	t.ok(slots.size() > 0, "누를 층이 %d개다" % slots.size())
	for i in slots.size():
		t.eq(Layout.layer_at(id, area, slots[i]), i, "%d층 심볼 자리를 누르면 %d층이다" % [i, i])

	# 🔴 **이웃을 안 먹는다.** 누르는 원이 너무 크면 1층을 눌렀는데 2층이 잡힌다.
	var clean := true
	for i in slots.size():
		for j in slots.size():
			if i != j and Layout.layer_at(id, area, slots[j]) == i:
				clean = false
	t.ok(clean, "층 누르는 자리가 서로 안 겹친다 (누르기 반경 ×%.1f)" % Fx.SLOT_HIT_RATIO)

	# 아무것도 없는 자리는 -1. ⚠ 안 그러면 배경 클릭이 엉뚱한 층을 만진다.
	t.eq(Layout.layer_at(id, area, Vector2.ZERO), -1, "구석을 누르면 아무 층도 아니다")
	t.eq(Layout.rune_slot_at(id, area, Layout.rune_slots(id, area)[0]), 0,
		"룬 자리를 누르면 0번이다")

	# ══ 🔴🔴 **종류를 가로질러 잰다** — 지금까지 층끼리만 쟀다 ══════
	# ⚠ 실측(verify-read): 1층 히트 원(37.7)과 룬 히트 원(55.7)이 **20.5px 겹친다**(거리 72.8).
	#  🔴 **겹침을 없애라는 게 아니다** — 겹치는 것은 그 사이 **빈 띠**뿐이고,
	#   **그려진 것을 누르면 그것이 잡히는 한 안전하다.** 그 안전 조건을 못박는다.
	var rune_c := Layout.rune_slots(id, area)[0]
	var rune_draw := Layout.rune_radius(area)
	var layer_hit := Layout.glyph_radius(area) * Fx.SLOT_HIT_RATIO
	for i in slots.size():
		var gap := rune_c.distance_to(slots[i]) - layer_hit
		t.ok(gap >= rune_draw,
			"그려진 룬 원반(%.1f)이 %d층 히트 영역 밖이다 (여유 %.1f)" % [
				rune_draw, i, gap - rune_draw])

	# 🔴🔴 **반대 방향은 기하가 아니라 「순서」가 지킨다.**
	#  그려진 문양 심볼은 룬 히트 원(%.1f) **안**이라, `_click_circle`이 층을 **먼저** 안 보면
	#  문양이 통째로 안 눌린다. ⇒ **우선순위가 계약이다.**
	var rune_hit := rune_draw * Fx.SLOT_HIT_RATIO
	var inside := false
	for i in slots.size():
		if rune_c.distance_to(slots[i]) <= rune_hit + Layout.glyph_radius(area):
			inside = true
	t.ok(inside, "문양 심볼이 룬 히트 영역에 걸친다 (그래서 순서가 계약이다)")
	var click := _func_body(_stripped(t, WINDOW_PATH, "circle_window"), "_click_circle")
	t.ok(click != "", "`_click_circle()` 를 찾았다")
	var i_layer := click.find("layer_at")
	var i_rune := click.find("rune_slot_at")
	var i_frame := click.find("frame_has_point")
	t.ok(i_layer >= 0 and i_rune > i_layer,
		"층을 룬보다 **먼저** 본다 (안 그러면 문양이 안 눌린다)")
	t.ok(i_frame > i_rune,
		"진을 맨 **나중에** 본다 (진 슬롯이 테두리 안 전체라 먼저 보면 다 먹는다)")

	# 🔴🔴 **「고를 수 있나」가 종류로 갈리면 안 된다.**
	#  ⚠ 실제 결함이 거기서 났다 — `_can_pick`이 문양에만 묻고 진·룬엔 늘 `true`를 줘서,
	#   진을 빼면 **룬이 밝게 남고 골라지는데 눌러도 아무 일이 없었다**(verify-look, 2026-08-04).
	#  🔴 종류마다 다른 것은 **슬롯을 세는 법**과 **받는 조건** 둘뿐이어야 하고, 물음은 하나다.
	#  ⚠ `Control` 메서드라 **부를 수는 없다** — 갈래가 다시 생기는 것만 텍스트로 막는다.
	var win_src := _stripped(t, WINDOW_PATH, "circle_window")
	var pick := _func_body(win_src, "_can_pick")
	t.ok(pick != "", "`_can_pick()` 를 찾았다")
	t.ok(not pick.contains("KIND_"),
		"「고를 수 있나」가 종류로 안 갈린다 (셋이 같은 물음을 지난다)")
	t.ok(pick.contains("_slot_count(") and pick.contains("_slot_accepts("),
		"「고를 수 있나」가 슬롯 수와 받는 조건으로만 갈린다")

	# ── 팔레트 ──
	var pal := Book.palette_page(Fx.WINDOW_RECT.size)
	var found := 0
	for ki in Palette.KINDS.size():
		var sec := Palette.section(pal.size, ki)
		var kind: int = Palette.KINDS[ki]
		var items := Palette.items_of(kind)
		for ii in items.size():
			var slot := Palette.item_slot(sec, ii, items.size())
			var hit := Palette.item_at(pal.size, slot.get_center())
			t.ok(not hit.is_empty(), "팔레트 항목 %d/%d을 누르면 뭔가 잡힌다" % [ki, ii])
			if hit.is_empty():
				continue
			found += 1
			t.eq(int(hit["kind"]), kind, "누른 칸의 종류가 맞다")
			t.eq(int(hit["item"]), items[ii], "누른 칸의 항목이 맞다")
	t.ok(found > 0, "팔레트에서 실제로 누른 항목이 %d개다" % found)
	# ⚠ 구획 밖(맨 위 여백)은 아무것도 아니다.
	t.ok(Palette.item_at(pal.size, Vector2.ZERO).is_empty(), "여백을 누르면 아무것도 아니다")


## 🔴🔴 **팔레트와 슬롯이 같은 심볼 함수를 쓰나.**
##  ⚠ 안 쓰면 「팔레트의 폭발과 진에 놓인 폭발이 다르게 보인다」가 되고, 그건 **조용하다** —
##   실측으로 팔레트 문양을 마젠타 원반으로 바꿔도 초록이었다(verify-read).
##  ⚠ 진이 실제로 갈라져 있었다: `_draw_frame` 이 `draw_circle` 을 직접 그리고
##   `_draw_circle_symbol` 이 똑같은 그림을 따로 그렸다. **룬·문양은 공유하는데 진만 안 했다.**
##
## 🔴 재는 것은 좁다: **슬롯 쪽과 팔레트 쪽이 둘 다 같은 이름을 부르나.**
##  ⚠ 「그 함수가 실제로 같은 그림을 그리나」는 텍스트가 못 본다(이 파일의 `contains` 한계와 같다).
func _symbols_are_shared(t) -> void:
	var win := _stripped(t, WINDOW_PATH, "circle_window")
	# [심볼 함수, 슬롯 쪽 함수, 팔레트 쪽 함수]
	var shared: Array[Array] = [
		["_draw_circle_symbol", "_draw_frame", "_draw_palette_item"],
		["_draw_rune_symbol", "_draw_rune_slot", "_draw_palette_item"],
		["_draw_glyph", "_draw_ring", "_draw_palette_item"],
	]
	t.ok(shared.size() > 0, "심볼 공유를 재 볼 자리가 %d군데다" % shared.size())
	for c: Array in shared:
		for caller: String in [c[1], c[2]]:
			var body := _func_body(win, caller)
			t.ok(body != "", "`%s()` 를 찾았다" % caller)
			t.ok(body.contains("%s(" % c[0]),
				"`%s()` 가 심볼을 `%s()` 로 그린다 (따로 안 그린다)" % [caller, c[0]])


## 🔴 구획과 항목 칸이 **한 곳에서 나오고 서로 안 겹치나.** 겹치면 「이걸 눌렀는데 저게
##  골라진다」가 되고 **에러가 안 난다**(위험 6의 팔레트 얼굴).
func _palette_geometry_runs(t) -> void:
	var page := Book.palette_page(Fx.WINDOW_RECT.size)
	t.ok(page.size.x > 0.0 and page.size.y > 0.0, "팔레트 페이지에 크기가 있다 (%dx%d)" % [
		int(page.size.x), int(page.size.y)])

	var page_box := Rect2(Vector2.ZERO, page.size)
	var secs: Array[Rect2] = []
	for ki in Palette.KINDS.size():
		var sec := Palette.section(page.size, ki)
		var nm: StringName = Palette.KIND_DEFS[Palette.KINDS[ki]]["name"]
		t.ok(sec.size.x > 0.0 and sec.size.y > 0.0, "%s 구획에 크기가 있다" % nm)
		t.ok(page_box.encloses(sec), "%s 구획이 페이지 안에 들어간다" % nm)
		for other: Rect2 in secs:
			t.ok(not sec.intersects(other), "%s 구획이 앞 구획과 안 겹친다" % nm)
		secs.append(sec)

		var items := Palette.items_of(Palette.KINDS[ki])
		var slots: Array[Rect2] = []
		for ii in items.size():
			var slot := Palette.item_slot(sec, ii, items.size())
			t.ok(sec.encloses(slot), "%s 항목 %d이 구획 안에 들어간다" % [nm, ii])
			# ⚠ 제목 띠를 침범하면 글자와 심볼이 서로를 먹는다.
			# 🔴 **여유 한 톨을 둔다.** 항목의 위 끝은 **정확히** 제목 띠의 끝이고, `Rect2`는
			#  값을 **32비트 float**으로 담는데 여기 비교는 64비트다 ⇒ 창 크기에 따라 마지막
			#  비트가 아래로 굴러 **같은 값인데 「침범했다」가 된다.**
			#  ⚠ 실측(2026-08-04, 창을 486 → 372로 줄이던 날): 구획 높이가 92.666…이 되면서
			#   룬 두 항목이 그렇게 빨개졌다. **배치가 아니라 비교가 틀렸던 것이다.**
			t.ok(slot.position.y >= sec.position.y + Fx.PALETTE_HEAD_PX - RECT_EPS,
				"%s 항목 %d이 제목 띠 아래에 있다" % [nm, ii])
			# 🔴 **심볼이 칸 안에 든다.** ⚠ `> 0` 만 보면 긴 변으로 바꿔도 통과한다 —
			#  그러면 항목 하나짜리 종류(진·룬)만 거대해져 칸을 넘고, 「진이 제일 중요한가」로
			#  잘못 읽힌다. 짧은 변이 정한다는 결정이 여기서 지켜진다.
			var sym := Palette.item_symbol_radius(slot)
			t.ok(sym > 0.0, "%s 항목 %d에 심볼 크기가 있다" % [nm, ii])
			t.ok(sym * 2.0 <= minf(slot.size.x, slot.size.y),
				"%s 항목 %d의 심볼(지름 %.1f)이 칸(%dx%d) 안에 든다" % [
					nm, ii, sym * 2.0, int(slot.size.x), int(slot.size.y)])
			for other: Rect2 in slots:
				t.ok(not slot.intersects(other), "%s 항목 %d이 앞 항목과 안 겹친다" % [nm, ii])
			slots.append(slot)

	# 🔴 **팔레트가 마법진 페이지를 안 침범한다.** 침범하면 두 페이지가 뜻을 잃는다.
	#  ⚠ 팔레트는 **자기 페이지 원점 기준**이라 창 좌표로 옮겨서 재야 한다.
	var circle_page := Book.circle_page(Fx.WINDOW_RECT.size)
	for sec: Rect2 in secs:
		t.ok(not Rect2(page.position + sec.position, sec.size).intersects(circle_page),
			"팔레트 구획이 마법진 페이지를 안 침범한다")


## 🔴🔴 **눈이 찾아낸 것을 지키는 게 없었다.**
##  단계 4a에서 확산 6갈래가 화면에 **4갈래 X자**로 보였다 — 심볼이 고리 위 12시에 앉아
##  그 점의 접선이 수평이고, **0°·180° 갈래가 고리 선에 포개져 사라진다.**
##  4b-1에서 반 칸 돌려 고쳤는데, ⚠ **`GLYPH_SPAWN_ANGLE_STEP_FRAC`을 0으로 되돌려도
##  908개가 전부 초록이었다**(verify-read 실측). 눈이 한 번 찾아낸 것이 무방비였다.
##
## 🔴 **순수 기하라 그물이 잴 수 있다.** 화면을 안 봐도 「수평 갈래가 있나」는 계산된다.
func _spawn_rays_are_not_horizontal(t) -> void:
	var n := Fx.GLYPH_SPAWN_RAYS
	# ⚠ 0이면 아래 루프가 안 돌고 **초록이 된다.**
	t.ok(n > 0, "확산 갈래가 %d개다" % n)

	# 🔴 **홀수면 반 칸을 돌려도 하나가 반드시 180°에 선다:**
	#  `360(k+0.5)/N = 180` ⟺ `k = (N-1)/2` 이고, 그게 정수인 것이 **N이 홀수**와 동치다.
	#  ⇒ 「설 수 있다」가 아니라 「반드시 선다」라서 짝수를 계약으로 못박는다.
	t.eq(n % 2, 0, "갈래 수(%d)가 짝수다 (홀수면 하나가 반드시 수평이다)" % n)

	for k in n:
		var a := TAU * (float(k) + Fx.GLYPH_SPAWN_ANGLE_STEP_FRAC) / float(n)
		# ⚠ `sin`이 0에 가까우면 그 갈래가 수평이고, 고리 접선과 겹쳐 **화면에서 사라진다.**
		#  0.1은 「눈에 띄게 기울었나」의 하한이다 — 5.7°쯤이면 아직 고리에 먹힌다.
		t.ok(absf(sin(a)) > 0.1, "갈래 %d가 수평이 아니다 (%.0f°)" % [k, rad_to_deg(a)])


## 🔴🔴 **좌표 함수를 실제로 부르는 그물이 하나도 없었다.**
##  ⚠ 그래서 `_radius()`가 0을 돌려줘도 초록이고, 마법진이 **점 하나로 무너져도** 아무도 안 짖는다.
##   텍스트 스캔은 **문법**을 볼 뿐 **거동**을 못 본다 — 여기가 그 반대쪽이다.
##
## 🔴 그리고 계획이 「`rune_slots != 1`이면 짖는다」를 **래퍼 stderr에 공짜로 걸리는 장치**라고 적었는데,
##  그 함수를 부르는 그물이 없어서 **공짜가 아니었다.** 아래가 그 함수를 실제로 부른다.
func _layout_geometry_runs(t) -> void:
	# 🔴 마법진은 **자기 페이지 안**에서 산다. 창 크기가 아니라 페이지 크기를 받는다.
	#  ⚠ 어느 쪽인지는 `book_layout`이 안다 — 여기 키를 박으면 좌우를 뒤집는 날 갈라진다.
	var page := Book.circle_page(Fx.WINDOW_RECT.size)
	var area := Layout.circle_area(page.size)
	t.ok(area.size.x > 0.0 and area.size.y > 0.0,
		"마법진 자리에 크기가 있다 (%dx%d)" % [int(area.size.x), int(area.size.y)])
	t.ok(area.end.x <= page.size.x and area.end.y <= page.size.y,
		"마법진 자리가 페이지 안에 들어간다")

	var f := Layout.frame(area)
	var fr: float = f["radius"]
	# 🔴 0이면 마법진이 **점 하나로 무너진다.** 텍스트 스캔이 원리적으로 못 보는 자리다.
	t.ok(fr > 0.0, "진 테두리 반지름이 0이 아니다 (%.1f)" % fr)
	t.ok(area.has_point(f["center"]), "진 중심이 마법진 자리 안에 있다")

	for id: int in CircleDefs.ALL:
		var nm: StringName = CircleDefs.DEFS[id]["name"]
		var rings := Layout.layer_rings(id, area)
		t.eq(rings.size(), CircleDefs.layers(id), "진 %s의 고리 수가 층 수와 같다" % nm)

		# 🔴 **안쪽부터 바깥으로 자란다.** 뒤집히면 「안쪽이 먼저」가 그림에서 거짓이 된다.
		var grows := rings.size() > 0
		for i in rings.size():
			if rings[i] <= 0.0 or (i > 0 and rings[i] <= rings[i - 1]):
				grows = false
		t.ok(grows, "진 %s의 고리가 안에서 밖으로 커진다 %s" % [nm, rings])
		if rings.size() > 0:
			t.ok(rings[rings.size() - 1] <= fr,
				"진 %s의 바깥 고리가 테두리를 안 넘는다 (%.1f ≤ %.1f)" % [
					nm, rings[rings.size() - 1], fr])
			# ⚠ 룬은 한가운데다 — 첫 고리가 룬보다 안쪽이면 둘이 겹쳐 그려진다.
			t.ok(rings[0] > Layout.rune_radius(area),
				"진 %s의 1층 고리가 룬 자리 바깥이다" % nm)

		var slots := Layout.layer_slots(id, area)
		t.eq(slots.size(), rings.size(), "진 %s의 문양 자리 수가 고리 수와 같다" % nm)
		var inside := true
		for p: Vector2 in slots:
			if p.distance_to(f["center"]) > fr:
				inside = false
		t.ok(inside, "진 %s의 문양 자리가 전부 테두리 안이다" % nm)

		t.eq(Layout.rune_slots(id, area).size(), CircleDefs.rune_slots(id),
			"진 %s의 룬 자리 수가 표와 같다" % nm)

	t.ok(Layout.rune_radius(area) > 0.0, "룬 자리 반지름이 0이 아니다")
	t.ok(Layout.glyph_radius(area) > 0.0, "문양 심볼 반지름이 0이 아니다")

	# 🔴 **층 번호가 반지름을 따라가나.** 상수로 박으면 진이 커질 때 번호만 얼어붙고,
	#  그건 「안쪽이 먼저」를 말하는 장치 **둘 중 하나가 약해지는** 방향이다(기획 판정 3).
	#  ⚠ 실측으로 그랬다 — 창이 28.4%→90%가 되며 지름이 199→364인데 번호는 12로 얼어 있었다.
	var small := Layout.circle_area(page.size * 0.5)
	t.ok(Layout.layer_num_size(area) > Layout.layer_num_size(small),
		"층 번호가 진이 커지면 같이 커진다 (%d > %d)" % [
			Layout.layer_num_size(area), Layout.layer_num_size(small)])
	# ⚠ 아무리 작아져도 안 읽히는 크기로는 안 내려간다.
	t.ok(Layout.layer_num_size(small) >= Fx.CIRCLE_LAYER_NUM_MIN, "층 번호에 하한이 있다")

	# 🔴🔴 **「진이 없다」는 정상이라 조용해야 한다.** 여기서 짖게 만들면 진을 빼는 평범한 조작이
	#  래퍼를 빨갛게 만든다. ⚠ `expect_error`를 **일부러 안 적었다** — 짖으면 그대로 실패다.
	t.eq(Layout.rune_slots(CircleDefs.CIRCLE_NONE, area).size(), 0,
		"진이 없으면 룬 자리가 0개다 (조용히)")
	t.eq(Layout.layer_rings(CircleDefs.CIRCLE_NONE, area).size(), 0,
		"진이 없으면 고리가 0개다 (조용히)")

	# 🔴 `rune_slots != 1`의 짖음 자체는 진이 1종이라 **실행으로 못 닿는다.**
	#  ⇒ 지워지지 않았는지만 텍스트로 지킨다(위 `_accessors_read_the_table`과 같은 이유).
	t.ok(_func_body(_stripped(t, "res://src/view/circle_layout.gd", "circle_layout"),
		"rune_slots").contains("push_error"),
		"룬 자리 배치가 안 정해진 진에 짖는 코드가 살아 있다")


## 🔴🔴 **이 단계가 존재한 이유가 이것 하나다** — 기획 「경계」가 요구한 것은 **축을 가르라**였다.
##  진 넷 중 셋(룬 2 융합 · 룬 3 병렬 · 문양이 룬마다)은 **그림이 통째로 다르고**, 한 덩어리로 짜면
##  그날 조립창을 다시 만든다.
##
## ⚠ **갈렸다는 걸 지키는 것이 주석뿐이면 안 갈린 것과 같다.** 실측이다 —
##  `_draw_ring`이 `Layout.frame(area)["center"]`를 다시 부르게 되돌려 놨더니 **833개가 전부 초록**이었다.
##  ⇒ 층 그림이 진 축에 매달린 채로 아무도 안 짖는다.
##
## 🔴 재는 것은 **한 방향뿐이다: 층·룬 축이 진 축(`frame`)을 안 부른다.**
##  ⚠ `layer_slots`가 `layer_rings`를 부르는 것은 **같은 축이라 결합이 아니다** — 잡으면 안 된다.
##   그래서 「아무 함수도 아무 함수를 안 부른다」로 넓히지 않았다.
func _axes_do_not_call_each_other(t) -> void:
	var layout := _stripped(t, "res://src/view/circle_layout.gd", "circle_layout")
	var window := _stripped(t, "res://src/view/circle_window.gd", "circle_window")

	# [파일, 함수, 있으면 안 되는 호출, 라벨]
	var cases: Array[Array] = [
		[layout, "layer_rings", "frame(", "층 좌표"],
		[layout, "layer_slots", "frame(", "층 좌표(자리)"],
		[layout, "rune_slots", "frame(", "룬 좌표"],
		[window, "_draw_ring", "Layout.frame(", "층 그림"],
		[window, "_draw_rune_slot", "Layout.frame(", "룬 그림"],
	]
	t.ok(cases.size() > 0, "축 결합을 재 볼 자리가 %d군데다" % cases.size())
	for c: Array in cases:
		var body := _func_body(c[0], c[1])
		# ⚠ 함수를 못 찾으면 아래가 **빈 문자열을 검사하고 초록이 된다.**
		t.ok(body != "", "`%s()` 를 찾았다" % c[1])
		t.ok(not body.contains(c[2]), "%s가 진 축(`%s`)을 안 부른다" % [c[3], c[2]])

	# 🔴 반대쪽 — 같은 축 안의 호출은 **살아 있어야 한다.** 이게 없으면 위 검사가
	#  「아무도 아무것도 안 부른다」로 통과해도 아무도 모른다.
	t.ok(_func_body(layout, "layer_slots").contains("layer_rings("),
		"층 자리는 층 반지름에서 나온다 (같은 축이라 결합이 아니다)")


## 주석·문자열을 걷어낸 소스. ⚠ 삼중 따옴표가 있으면 스트리퍼가 거기서 멈춰 **나머지가 통째로
##  스캔에서 빠지고 조용히 초록**이 되므로 그 가정을 같이 잰다.
func _stripped(t, path: String, nm: String) -> String:
	var raw := _read(path)
	t.ok(not raw.contains("\"\"\""), "%s 에 삼중 따옴표가 없다 (스트리퍼가 못 다룬다)" % nm)
	return NetDeterminism._strip(raw)


## `func <이름>(` 부터 **다음 함수 머리** 전까지. 못 찾으면 빈 문자열이다.
## ⚠ `static func`도 `func`를 품으므로 한 패턴이 둘 다 잡는다 — 그림 쪽(`circle_window`)은
##  static이 아니라서 이 성질이 필요하다.
func _func_body(src: String, fname: String) -> String:
	var head := src.find("func %s(" % fname)
	if head < 0:
		return ""
	# 다음 함수 머리는 **줄 첫머리의 `func`/`static func`**다. 안쪽 들여쓰기에는 안 걸린다.
	var tail := -1
	for marker: String in ["\nfunc ", "\nstatic func "]:
		var at := src.find(marker, head + 1)
		if at >= 0 and (tail < 0 or at < tail):
			tail = at
	var body := src.substr(head) if tail < 0 else src.substr(head, tail - head)
	# ⚠ **다음 함수의 문서 주석까지 딸려 온다.** 거기 적힌 말이 이 함수의 코드로 읽히면
	#  검사가 조용히 틀린다(있으면 안 될 호출을 옆 함수 주석이 「있다」로 만들 수 있다).
	#  ⇒ 줄 첫머리 `##` 에서 자른다. 함수 **안**에는 `##` 이 안 나온다.
	var doc := body.find("\n##")
	return body if doc < 0 else body.substr(0, doc)


# ══════════════════════════════════════════════════════════════════
#  🔴🔴 빈 층 — 이 계획에서 제일 조용한 함정
# ══════════════════════════════════════════════════════════════════

## 1층을 비우고 2층에만 문양을 놓는다.
##
## ```
## 그대로 팩하면  g = GLYPH_NONE | (BLAST << 4)
##                first(g) = 0 = 「목록 끝」  →  탄은 **빈 목록**을 들고 난다
## ```
## ⇒ 폭발이 사라진다. **에러가 하나도 안 난다.**
func _empty_layer_is_skipped(t) -> void:
	var c := SpellCircle.new()
	t.ok(c.place_glyph(1, Glyph.GLYPH_BLAST), "2층에만 폭발을 놓는다")
	t.eq(c.glyph_at(0), Glyph.GLYPH_NONE, "1층은 비어 있다")
	t.eq(c.glyph_at(1), Glyph.GLYPH_BLAST, "2층에 폭발이 있다")

	var g := c.packed_glyphs()
	t.eq(Glyph.first(g), Glyph.GLYPH_BLAST, "빈 1층을 건너뛰어 폭발이 **첫** 문양이 된다")
	t.eq(Glyph.rest(g), Glyph.GLYPH_NONE, "그 뒤는 목록 끝이다")

	# 🔴 함정 자체를 재 둔다 — 빈 층을 그대로 넣으면 어떤 값이 되는지.
	#  ⚠ 시프트를 그물에서만 한다. 소스에서 하면 `glyph_defs`의 세 함수 밖에 시프트가 생긴다.
	var naive := Glyph.GLYPH_BLAST << Tuning.GLYPH_BITS
	t.eq(Glyph.first(naive), Glyph.GLYPH_NONE,
		"그대로 팩하면 첫 문양이 「목록 끝」이 된다 (그래서 건너뛴다)")
	t.ok(g != naive, "조밀하게 팩한 값(%d)이 그대로 팩한 값(%d)과 다르다" % [g, naive])

	# 🔴🔴 **시뮬까지 이어 본다.** 팩만 맞고 실제로 안 터지면 아무 뜻이 없다 —
	#  「화면만 바뀌고 시뮬은 안 바뀌기」가 이 리포의 대표 가짜다.
	var grid := _wall_grid()
	var sim := SpellSim.new()
	t.ok(sim.fire(SpellSim.cmd_fire(10, 70, 100, 0, c.element(), g)),
		"2층에만 놓은 마법진이 발사된다")
	t.eq(_run_ticks(sim, grid, 12), 1, "그 폭발이 실제로 터진다 (증발하지 않는다)")

	# 🔴 대조군 — 두 층을 다 비우면 폭발이 없다. 없으면 위 초록이 「탄이 원래 터진다」일 수 있다.
	var empty := SpellCircle.new()
	t.eq(empty.packed_glyphs(), Glyph.GLYPH_NONE, "두 층을 다 비우면 빈 목록이다")
	var grid2 := _wall_grid()
	var sim2 := SpellSim.new()
	# 기획 「극단값」: 층을 다 비우고 쏘면 **쏴져야 한다.** 진+룬만으로도 마법은 성립한다.
	t.ok(sim2.fire(SpellSim.cmd_fire(10, 70, 100, 0, empty.element(), empty.packed_glyphs())),
		"층을 다 비워도 쏴진다 (진 + 룬만)")
	t.eq(_run_ticks(sim2, grid2, 12), 0, "문양이 없으면 폭발이 없다")


# ══════════════════════════════════════════════════════════════════
#  왕복 — 디버그 키가 들어오는 문
# ══════════════════════════════════════════════════════════════════

## 🔴 `set_from_packed(g)` 뒤 `packed_glyphs() == g`. 안 되면 키를 누를 때마다 장착이
##  조금씩 달라지고, 그 차이는 **횟수로만** 드러난다.
func _round_trip(t) -> void:
	var cases: Array[Array] = [
		[],
		[Glyph.GLYPH_BLAST],
		[Glyph.GLYPH_SPREAD],
		[Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST],
		[Glyph.GLYPH_BLAST, Glyph.GLYPH_SPREAD],   # 🔴 위와 같은 둘, 다른 순서
		[Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST],
	]
	for list: Array in cases:
		var typed: Array[int] = []
		typed.assign(list)
		var packed := Glyph.pack(typed)
		var c := SpellCircle.new()
		t.ok(c.set_from_packed(packed), "목록 %s가 진에 들어간다" % [typed])
		t.eq(c.packed_glyphs(), packed, "목록 %s가 왕복한다" % [typed])
		t.eq(c.glyph_list(), typed, "목록 %s의 층 순서가 살아남는다" % [typed])

	# ⚠ **앞 층부터 채운다.** 폭발 하나면 1층 폭발 · 2층 빈칸이다.
	var one: Array[int] = [Glyph.GLYPH_BLAST]
	var c1 := SpellCircle.new()
	c1.set_from_packed(Glyph.pack(one))
	t.eq(c1.glyph_at(0), Glyph.GLYPH_BLAST, "문양 하나는 안쪽 층(1층)에 앉는다")
	t.eq(c1.glyph_at(1), Glyph.GLYPH_NONE, "2층은 빈다")
	# ⚠ 프리셋은 **문양만** 바꾼다 — 진과 룬은 안 건드린다.
	t.eq(c1.circle_id(), CircleDefs.CIRCLE_ROUND, "프리셋이 진을 안 건드린다")
	t.ok(c1.can_fire(), "프리셋이 룬을 안 건드린다")

	# 🔴🔴 **덮어쓸 때 앞 상태가 안 남아야 한다.** 안 비우면 키 4(두 층) 뒤에 키 3(한 층)을
	#  눌렀을 때 2층에 앞 문양이 남아 「뺐는데 안 빠진다」가 된다 — 판정 1이 거기서 죽는다.
	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	var c2 := SpellCircle.new()
	c2.set_from_packed(Glyph.pack(two))
	c2.set_from_packed(Glyph.pack(one))
	t.eq(c2.glyph_list(), one, "두 층 뒤에 한 층을 넣으면 뒤 층이 비워진다")
	c2.set_from_packed(Glyph.GLYPH_NONE)
	t.eq(c2.packed_glyphs(), Glyph.GLYPH_NONE, "빈 목록을 넣으면 층이 전부 빈다")

	# ── 못 받는 것들 ──
	var three: Array[int] = [Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST, Glyph.GLYPH_BLAST]
	t.expect_error("층 진에 넣을 수 없다")
	t.ok(not c2.set_from_packed(Glyph.pack(three)), "3층 목록은 2층 진에 안 들어간다")

	var twice: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_SPREAD]
	t.expect_error("문양 제약에 걸린다")
	t.ok(not c2.set_from_packed(Glyph.pack(twice)),
		"클릭으로 못 놓는 배치는 프리셋으로도 안 들어간다")
	t.eq(c2.packed_glyphs(), Glyph.GLYPH_NONE, "거절된 목록이 상태를 안 건드린다")

	# 🔴 음수는 **영원히 돈다** — `rest`가 산술 시프트라 `-1 >> 4 == -1`이다.
	#  에러 없이 프레임이 얼어붙는 종류라 문에서 막는다.
	t.expect_error("음수 목록")
	t.ok(not c2.set_from_packed(-1), "음수 목록은 짖고 버린다")


# ══════════════════════════════════════════════════════════════════
#  제약 — 놓기 **전에** 막는다
# ══════════════════════════════════════════════════════════════════

## 🔴 **쏘고 나서 실패하면 고장으로 읽힌다**(기획 「극단값」). 확산이 이미 있으면
##  두 번째 확산은 **놓이기 전에** 막혀야 한다.
func _cap_blocks_before_placing(t) -> void:
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_SPREAD]["max_per_circle"]), 1,
		"확산은 한 마법진에 하나까지다 (GDD)")
	t.eq(int(Glyph.DEFS[Glyph.GLYPH_BLAST]["max_per_circle"]), 0, "폭발은 무제한이다 (0)")

	var c := SpellCircle.new()
	t.ok(c.can_place_glyph(0, Glyph.GLYPH_SPREAD), "빈 진의 1층에 확산을 놓을 수 있다")
	t.ok(c.place_glyph(0, Glyph.GLYPH_SPREAD), "확산을 놓는다")
	t.ok(not c.can_place_glyph(1, Glyph.GLYPH_SPREAD), "🔴 두 번째 확산은 **놓기 전에** 막힌다")
	t.ok(not c.place_glyph(1, Glyph.GLYPH_SPREAD), "막힌 배치는 놓기도 실패한다")
	t.eq(c.glyph_at(1), Glyph.GLYPH_NONE, "막힌 놓기가 층을 안 건드린다")

	# 🔴 **같은 층에 덮어쓰는 것은 막히면 안 된다.** 「지금 몇 개인가」만 세면 자기 자신을
	#  한 번 더 세서 **놓을 수 있는 것을 막는다** — 그건 「이미 있는데 못 바꾼다」로 보인다.
	t.ok(c.can_place_glyph(0, Glyph.GLYPH_SPREAD), "확산이 있는 층에 확산을 덮어쓰는 것은 된다")
	t.ok(c.can_place_glyph(0, Glyph.GLYPH_BLAST), "확산이 있는 층을 폭발로 바꿀 수 있다")

	# 폭발은 무제한이라 두 층이 통과해야 한다 — 제약이 **모든 문양에 걸리면** 그건 다른 버그다.
	var b := SpellCircle.new()
	t.ok(b.place_glyph(0, Glyph.GLYPH_BLAST), "1층에 폭발")
	t.ok(b.place_glyph(1, Glyph.GLYPH_BLAST), "2층에도 폭발 (무제한이다)")

	# 빼기는 늘 된다. 그리고 빼면 확산을 다시 놓을 수 있다.
	t.ok(c.place_glyph(0, Glyph.GLYPH_NONE), "층을 비우는 것은 늘 된다")
	t.ok(c.can_place_glyph(1, Glyph.GLYPH_SPREAD), "빼고 나면 확산을 다시 놓을 수 있다")

	# 층 밖 · 표에 없는 문양. 🔴 히트테스트가 어긋나면 **에러 없이** 엉뚱한 층으로 간다.
	t.ok(not c.can_place_glyph(-1, Glyph.GLYPH_BLAST), "없는 층(-1)에는 못 놓는다")
	t.ok(not c.can_place_glyph(c.layer_count(), Glyph.GLYPH_BLAST), "층 수를 넘는 층에는 못 놓는다")
	t.ok(not c.can_place_glyph(0, Glyph.MASK), "표에 없는 문양은 못 놓는다")


# ══════════════════════════════════════════════════════════════════
#  🔴🔴 양방향 일치 — 규칙이 두 벌이 아닌 것을 **이것만이** 잰다
# ══════════════════════════════════════════════════════════════════

## `can_place_glyph`가 통과시킨 배치는 `spell_sim.fire()`도 **받아들이고**,
## 막은 배치는 `fire()`도 **거부한다.**
##
## 🔴 한쪽만 재면 갈라지는 걸 못 본다:
##  · 조립창이 느슨하면 → 쏴도 아무 일이 안 일어난다(「고장」으로 읽힌다)
##  · 조립창이 빡빡하면 → 만들 수 있는 마법을 못 만든다(아무도 모른다)
##
## ⚠ **가능한 배치를 전부 돈다** — 층마다 「빈칸 + 모든 문양」이다. 표본을 손으로 고르면
##  문양이 늘 때 새 조합이 검사에서 빠지고, 빠진 걸 아무도 모른다.
func _both_ways_agree(t) -> void:
	var options: Array[int] = [Glyph.GLYPH_NONE]
	options.append_array(Glyph.ALL)
	var slots := SpellCircle.new().layer_count()
	var cases := _all_arrangements(options, slots)
	t.ok(cases.size() > 1, "돌아 볼 배치가 %d가지다 (문양 %d종 · %d층)" % [
		cases.size(), Glyph.ALL.size(), slots])

	# 🔴 막힌 배치를 `fire()`에 그대로 던지므로 거기서 짖는다 — 그게 「거부했다」의 증거다.
	t.expect_error("한 마법진에")

	var allowed_n := 0
	var blocked_n := 0
	var agree := true
	var packs_agree := true
	for arrangement: Array in cases:
		var c := SpellCircle.new()
		var allowed := true
		for i in arrangement.size():
			if not c.place_glyph(i, arrangement[i]):
				allowed = false
				break

		# 그 배치가 **쏘려 했을** 목록. 빈 층은 건너뛴다(조립 상태와 같은 규칙이다).
		var dense: Array[int] = []
		for id: int in arrangement:
			if id != Glyph.GLYPH_NONE:
				dense.append(id)
		var packed := Glyph.pack(dense)

		var sim := SpellSim.new()
		var accepted := sim.fire(
			SpellSim.cmd_fire(10, 70, 100, 0, Tuning.ELEM_FIRE, packed))
		if allowed != accepted:
			agree = false
			t.ok(false, "배치 %s — 조립은 %s인데 발사는 %s다" % [
				dense, "통과" if allowed else "거부", "통과" if accepted else "거부"])
		if allowed:
			allowed_n += 1
			if c.packed_glyphs() != packed:
				packs_agree = false
		else:
			blocked_n += 1

	t.ok(agree, "🔴 조립이 통과시킨 것은 발사도 받고, 막은 것은 발사도 거부한다")
	t.ok(packs_agree, "통과한 배치의 팩된 목록이 발사에 넘긴 것과 같다")
	# 🔴🔴 **양쪽이 실제로 있어야 위 초록이 뜻을 가진다.** 전부 통과면 「아무것도 안 막는다」와
	#  구별이 안 되고, 전부 거부면 「아무것도 못 만든다」와 구별이 안 된다.
	t.ok(allowed_n > 0, "통과한 배치가 있다 (%d가지)" % allowed_n)
	t.ok(blocked_n > 0, "막힌 배치가 있다 (%d가지)" % blocked_n)


## 층마다 `options` 중 하나를 고른 모든 배치. 🔴 문양이나 층이 늘면 **저절로** 늘어난다.
func _all_arrangements(options: Array[int], slots: int) -> Array:
	var out: Array = []
	var total := 1
	for _i in slots:
		total *= options.size()
	for k in total:
		var one: Array[int] = []
		var rest := k
		for _i in slots:
			one.append(options[rest % options.size()])
			rest /= options.size()
		out.append(one)
	return out


# ══════════════════════════════════════════════════════════════════
#  디버그 키 — A를 깨지 않았나
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **키 1~5가 전과 똑같이 동작해야 한다.** 달라지면 A(`spell-pipeline-minimum`)를 깬 것이고,
##  그 조합들이 판정 1·2의 측정 장치다(기획 「비교 조작」).
## ⚠ `stage.gd`의 실제 표를 읽는다 — 그물이 사본을 들면 표가 바뀔 때 같이 안 늙는다.
func _presets_still_work(t) -> void:
	var keys: Array = Stage.LOADOUTS.keys()
	keys.sort()
	t.ok(keys.size() > 0, "프리셋이 있다 (%d개)" % keys.size())
	for n: int in keys:
		var list: Array[int] = []
		list.assign(Stage.LOADOUTS[n])
		var packed := Glyph.pack(list)
		var c := SpellCircle.new()
		t.ok(c.set_from_packed(packed), "키 %d의 프리셋이 진에 들어간다" % n)
		t.eq(c.glyph_list(), list, "키 %d가 같은 목록을 같은 순서로 내놓는다" % n)
		t.eq(c.packed_glyphs(), packed, "키 %d가 같은 정수로 팩된다" % n)
		t.ok(c.can_fire(), "키 %d를 누른 뒤에도 쏠 수 있다" % n)
		var sim := SpellSim.new()
		t.ok(sim.fire(SpellSim.cmd_fire(10, 70, 100, 0, c.element(), c.packed_glyphs())),
			"키 %d의 마법진이 발사된다" % n)

	# 🔴 시작 상태의 룬이 불이다. 여기가 바뀌면 발사의 룬이 조용히 바뀐다.
	t.eq(SpellCircle.new().element(), Tuning.ELEM_FIRE, "새 진의 룬 자리에 불이 들어 있다")

	# 🔴🔴 **시작 상태와 프리셋이 같은 두 상수에서 나온다**(계획 §8). 두 곳에 적으면
	#  「새로 켜면 불인데 키 1을 누르면 다른 룬」이 **에러 없이** 생긴다.
	t.eq(SpellCircle.new().circle_id(), SpellCircle.DEFAULT_CIRCLE, "시작 진이 기본 지급이다")
	t.eq(SpellCircle.new().rune_at(0), SpellCircle.DEFAULT_RUNE, "시작 룬이 기본 지급이다")
	# ⚠ 껍데기가 프리셋을 **한 함수로** 넣나 — 세 줄로 풀면 순서를 거기서 다시 정하게 된다.
	t.ok(_read("res://src/stage/stage.gd").contains("apply_preset("),
		"디버그 키가 `apply_preset()` 으로 들어간다")


## 🔴🔴 **프리셋의 순서 계약 — 진 → 룬 → 문양.**
##
## ⚠ **진이 그대로면 순서가 뒤집혀도 안 보인다**(`set_circle`이 같은 진에 no-op이라 층을 안 비운다).
##  ⇒ **진을 뺀 상태에서 재야** 드러난다. 실측으로 그랬다 — 순서를 뒤집어 놓고 그물을 돌렸더니
##   프리셋 검사 스물이 전부 초록이었다(전부 `set_from_packed`만 부르고 있었다).
##
## 🔴 그리고 이게 **「진을 뺀 사용자가 갇히지 않는다」**를 재는 자리이기도 하다 —
##  프리셋이 진까지 놓으므로 **키 1이 곧 조립 리셋**이다.
func _preset_restores_everything(t) -> void:
	var c := SpellCircle.new()
	c.set_circle(CircleDefs.CIRCLE_NONE)
	t.eq(c.layer_count(), 0, "진을 빼면 층이 0이다")
	t.ok(not c.can_fire(), "진을 빼면 못 쏜다")

	var two: Array[int] = [Glyph.GLYPH_SPREAD, Glyph.GLYPH_BLAST]
	t.ok(c.apply_preset(SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE,
		Glyph.pack(two)), "진이 없는 상태에서도 프리셋이 들어간다")
	t.eq(c.circle_id(), SpellCircle.DEFAULT_CIRCLE, "프리셋이 진을 되돌린다")
	t.eq(c.rune_at(0), SpellCircle.DEFAULT_RUNE, "프리셋이 룬을 되돌린다")
	# 🔴 **순서가 뒤집히면 여기가 빈다** — 문양을 먼저 넣으면 층이 0이라 못 들어가고,
	#  그 뒤에 진이 놓여도 문양은 이미 버려졌다.
	t.eq(c.glyph_list(), two, "프리셋이 문양까지 놓는다 (순서가 진 → 룬 → 문양이다)")
	t.ok(c.can_fire(), "프리셋 뒤에 쏠 수 있다 (키 1이 곧 조립 리셋이다)")

	# 룬만 빠진 상태에서도 되돌린다.
	c.set_rune(0, SpellCircle.RUNE_EMPTY)
	t.ok(not c.can_fire(), "룬을 빼면 못 쏜다")
	c.apply_preset(SpellCircle.DEFAULT_CIRCLE, SpellCircle.DEFAULT_RUNE, Glyph.GLYPH_NONE)
	t.ok(c.can_fire(), "프리셋이 빈 룬을 되돌린다")
	t.eq(c.glyph_list(), [] as Array[int], "빈 프리셋은 문양을 비운다")


# ══════════════════════════════════════════════════════════════════
#  도구
# ══════════════════════════════════════════════════════════════════

## 한 타일(4셀) 두께의 돌 벽. 탄이 여기서 착탄한다.
func _wall_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(40, 0, 43, CellGrid.H - 1, Mat.STONE))
	return g


## `ticks`틱을 돌리고 그동안의 **폭발 총 횟수**를 돌려준다.
## ⚠ 통지는 틱마다 지워지므로 매 틱 걷어야 한다.
func _run_ticks(sim: SpellSim, grid: CellGrid, ticks: int) -> int:
	var n := 0
	for _i in ticks:
		sim.step(grid)
		n += sim.blast_count()
	return n


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("net_circle: %s 를 못 읽었다" % path)
		return ""
	return f.get_as_text()
