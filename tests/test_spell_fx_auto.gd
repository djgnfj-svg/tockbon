extends SceneTree
## 연출 그물 — 🔴🔴 **여기서 잴 수 있는 건 「단이 화면에 갈리나」까지다. 「세게 보이나」가 아니다.**
##
## ⚠ 연출은 헤드리스로 거의 못 잰다 — 「보인다」와 「시간이 흐른다」는 실게임 전용이다(SKILL.md §3).
##  🔴 **그래서 이 그물을 완료 근거로 쓰지 마라.** 전 항목 초록이어도 화면이 밋밋할 수 있고,
##   그 판정은 전적으로 사용자 몫이다. 여기가 지키는 건 딱 하나다:
##
##   🔴🔴 **「위력이 3단인데 연출이 P1만 반영하는 것」 = v1이 죽은 방식(T8)을 기계가 막는다.**
##
## `test_spell_auto.gd`의 N8이 **표 안에서** 단조성을 재고, 여기 X1~X3은 **표 밖에서**
##  「그 표가 실제로 렌더에 도달하나」를 잰다. 둘 다 있어야 T8이 막힌다 —
##  N8만 있으면 표는 예쁜데 소비자가 없고, X만 있으면 표가 무너져도 「일관되게」 무너진다.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const SpellSim := preload("res://src/world/spell/spell_sim.gd")
const SpellView := preload("res://src/world/spell/spell_view.gd")
const BlastFx := preload("res://src/world/spell/blast_fx.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")
const CellRenderer := preload("res://src/world/cells/cell_renderer.gd")

const EPS := 0.0001

## 🔴 문턱을 **상수에서 파생시킨다.** 한 틱 도약이 「40px」인 건 `SPEED_CELLS`(10) × `CELL_PX`(4)의
##  결과지, 마법의 숫자가 아니다. 손으로 박으면 누가 속도를 15로 올리는 순간 그물이 **헛빨강**을 낸다.
const TICK_PX: float = 1.0 * Tuning.SPEED_CELLS * CellRenderer.CELL_PX

var _pass := 0
var _fail := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_x1_table_is_actually_consumed()
	_x2_blast_fx_differs_by_tier()
	_x3_projectile_fx_differs_by_tier()
	_x4_fx_lifetime_and_cap()
	_x5_trail_is_keyed_by_id()
	_x6_interpolation()
	_x7_shake_is_integer_and_bounded()
	_x8_muzzle_follows_tier()
	_x9_missing_element_screams()
	_x10_impact_streak()

	print("RESULT pass=%d fail=%d" % [_pass, _fail])
	if _fail == 0:
		print("TEST_SPELLFX_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_SPELLFX_FAIL — %d개 실패" % _fail)
		quit(1)


# ─── 도구 ─────────────────────────────────────────────────────────

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  ok  %s  %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL: %s  %s" % [label, detail])


## 🔴 **엄격 증가만 통과.** 같으면 「그 축을 안 쓴다」와 구별이 안 된다 — v1이 정확히 그 상태였다.
func _rising(label: String, vals: Array[float], detail: String = "") -> void:
	var ok := vals.size() >= 2
	for i in range(1, vals.size()):
		if vals[i] <= vals[i - 1] + EPS:
			ok = false
	_check(label, ok, "%s %s" % [str(vals), detail])


func _read_code(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var src := f.get_as_text()
	f.close()
	# 🔴 주석을 걷어낸다 — 안 그러면 「이 축을 쓴다」고 **주석에 적어 두는 것만으로** 통과한다.
	var out: Array[String] = []
	for line: String in src.split("\n"):
		var c := line.find("#")
		out.append(line if c < 0 else line.substr(0, c))
	return "\n".join(out)


# ─── X1. 🔴🔴 표의 축이 **실제로 렌더에 도달하나** ─────────────────
## 축을 늘려 놓고 소비자를 안 만들면 그건 **거짓 손잡이**다(T3) — 사용자가 값을 두 배로 때려도
##  화면이 그대로고, 아무 그물도 안 빨개진다. N8은 표 안만 보므로 이걸 원리적으로 못 잡는다.
##
## ⚠ **이 그물의 한계를 명시한다**: 「키 이름이 코드에 나온다」까지만 잰다.
##  누가 값을 코드에 복사해 박으면(`54.0`) 여전히 통과한다. 그 자리는 X2·X3의
##  **「표 값과 정확히 일치하나」**가 잡는다 — 두 그물이 같이 있어야 의미가 있다.
const VIEW_SOURCES: Array[String] = [
	"res://src/world/spell/spell_view.gd",
	"res://src/world/spell/blast_fx.gd",
]


func _x1_table_is_actually_consumed() -> void:
	var code := ""
	for path: String in VIEW_SOURCES:
		var c := _read_code(path)
		_check("1 %s 코드가 실재한다" % path.get_file(), c.strip_edges().length() > 400,
			"주석 뺀 길이 %d자" % c.strip_edges().length())
		code += c
	_check("1b 렌더가 FX 표를 실제로 읽는다", code.contains("FX_TIERS"),
		"두 소스 어디에도 FX_TIERS 참조가 없으면 표는 장식이다")

	var missing: Array[String] = []
	for key: String in Tuning.FX_TIERS[0].keys():
		if not code.contains(key):
			missing.append(key)
	_check("1c FX 표의 모든 축에 소비자가 있다", missing.is_empty(),
		"소비자 없는 축 %s — 축만 늘고 화면이 그대로면 그게 v1이다" % str(missing))


## 단 `t`의 폭발이 **실제로 몇 ms 사나.** `shake`면 흔들림이 멎을 때까지, 아니면 섬광이 사라질 때까지.
## 🔴 값을 읽지 않고 **시간을 흘려서** 재는 게 요점이다 — 그래야 「상수를 박았다」가 잡힌다.
func _time_until(tier: int, shake: bool) -> float:
	var fx := BlastFx.new()
	fx.add_blast(Vector2(400.0, 200.0), tier, Tuning.ELEM_BOLT)
	var ms := 0
	while ms < 100000:
		if (fx.shake_amp_px() <= 0) if shake else (fx.active_count() <= 0):
			break
		fx.advance(0.001)
		ms += 1
	fx.free()
	return float(ms)


# ─── X2. 폭발 연출이 단마다 갈리나 ────────────────────────────────
## 🔴 두 가지를 같이 잰다: ① **단마다 다르다**(고정하면 v1) ② **표 값과 정확히 같다**(하드코딩 방지).
func _x2_blast_fx_differs_by_tier() -> void:
	var n := Tuning.FX_TIERS.size()
	var radii: Array[float] = []
	var sparks: Array[float] = []
	var shakes: Array[float] = []
	var exact: Array[String] = []

	for t in n:
		var fx := BlastFx.new()
		fx.add_blast(Vector2(400.0, 200.0), t, Tuning.ELEM_BOLT)
		var tier: Dictionary = Tuning.FX_TIERS[t]

		radii.append(fx.flash_radius(0))
		sparks.append(float(fx.spark_count(0)))
		shakes.append(float(fx.shake_amp_px()))

		# 뜨는 순간(t=0)의 반경은 표의 `flash_px` × `FLASH_START`여야 한다.
		var want_r := float(int(tier["flash_px"])) * Tuning.FLASH_START
		if absf(fx.flash_radius(0) - want_r) > EPS:
			exact.append("단%d 섬광 %.2f (표 %.2f)" % [t + 1, fx.flash_radius(0), want_r])
		if fx.spark_count(0) != int(tier["sparks"]):
			exact.append("단%d 스파크 %d (표 %d)" % [t + 1, fx.spark_count(0), int(tier["sparks"])])
		if fx.shake_amp_px() != int(tier["shake_px"]):
			exact.append("단%d 흔들림 %d (표 %d)" % [t + 1, fx.shake_amp_px(), int(tier["shake_px"])])
		fx.free()

	_rising("2 섬광 반경이 단마다 커진다", radii)
	_rising("2b 스파크 수가 단마다 는다", sparks)
	_rising("2c 흔들림 진폭이 단마다 는다", shakes)
	_check("2d 연출값이 표에서 나온다(하드코딩 아님)", exact.is_empty(), str(exact))

	# 🔴🔴 **지속도 단마다 길어야 한다 — 이건 시간을 실제로 흘려야만 잰다.**
	#  ⚠ 위 셋(반경·개수·진폭)은 전부 `t = 0` 한 시점의 **값**이라 지속은 한 톨도 안 본다.
	#   그리고 X1c(키가 코드에 나오나)도 못 잡는다 — `add_muzzle`이 **같은 키를 또 써서**
	#   `add_blast`가 상수를 박아도 텍스트에는 키가 남는다. 리뷰 뮤테이션 둘이 그렇게 통과했다.
	#  🔴 설계가 히트스톱을 뺀 근거가 *"그 몫은 흔들림·섬광 지속이 갚는다"*였다 —
	#   **갚는 축 둘이 정확히 여기서 무방비였다.**
	var lives: Array[float] = []
	var shake_lives: Array[float] = []
	for t in n:
		# ⚠ 인스턴스를 따로 쓴다 — `_kick`이 「더 센 쪽이 이긴다」라 한 인스턴스에 두 번 걸면 섞인다.
		lives.append(_time_until(t, false))
		shake_lives.append(_time_until(t, true))
	_rising("2e 섬광 지속이 단마다 길다", lives, "(ms)")
	_rising("2f 흔들림 지속이 단마다 길다", shake_lives, "(ms)")


# ─── X3. 투사체 연출이 단마다 갈리나 ──────────────────────────────
## 🔴 **날아가는 0.3초 동안 사용자가 단을 알아볼 수 있어야 한다.** 폭발만 커지면 「맞기 전까지는
##  똑같다」가 되고, 그건 조립을 잘한 보람이 발사 순간에 안 온다는 뜻이다.
func _x3_projectile_fx_differs_by_tier() -> void:
	var n := Tuning.FX_TIERS.size()
	var g := CellGrid.new()
	var s := SpellSim.new()
	var v := SpellView.new()
	v.setup(s)
	# 단마다 한 발씩. 빈 격자라 아무것도 안 맞고 슬롯 순서 = 발사 순서다.
	for t in n:
		s.fire(SpellSim.cmd_fire(10, 20 + t * 20, 1, 0, t, Tuning.ELEM_BOLT))
	s.step(g)
	v.on_tick()

	var bolts: Array[float] = []
	var widths: Array[float] = []
	var exact: Array[String] = []
	for t in n:
		var tier: Dictionary = Tuning.FX_TIERS[t]
		bolts.append(v.bolt_radius(t))
		widths.append(v.trail_width(t))
		if absf(v.bolt_radius(t) - float(int(tier["bolt_px"]))) > EPS:
			exact.append("단%d 머리 %.2f (표 %d)" % [t + 1, v.bolt_radius(t), int(tier["bolt_px"])])
		if absf(v.trail_width(t) - float(int(tier["trail_px"]))) > EPS:
			exact.append("단%d 자취 %.2f (표 %d)" % [t + 1, v.trail_width(t), int(tier["trail_px"])])

	_rising("3 투사체 머리가 단마다 커진다", bolts)
	_rising("3b 자취 굵기가 단마다 는다", widths)
	_check("3c 투사체 연출값이 표에서 나온다", exact.is_empty(), str(exact))

	# 🔴 꼬리 길이(`trail_ticks`)도 소비되나 — 충분히 틱을 돌린 뒤 자취 점 수가 단마다 달라야 한다.
	for _i in 12:
		s.step(g)
		v.on_tick()
	var lens: Array[float] = []
	for t in n:
		lens.append(float(v.trail_points(t).size()))
	_rising("3d 자취 꼬리가 단마다 길다", lens, "(머리 1점 + trail_ticks-1)")

	v.free()


# ─── X4. 수명·상한 ────────────────────────────────────────────────
## ⚠ 노드를 안 만드는 설계라 `queue_free` 누수는 애초에 없다. **여기서 새는 건 배열이다.**
func _x4_fx_lifetime_and_cap() -> void:
	var last := Tuning.FX_TIERS.size() - 1
	var life := float(int(Tuning.FX_TIERS[last]["flash_ms"])) / 1000.0

	var fx := BlastFx.new()
	fx.add_blast(Vector2(100.0, 100.0), last, Tuning.ELEM_WATER)
	_check("4 폭발이 연출을 만든다", fx.active_count() == 1, "%d개" % fx.active_count())
	fx.advance(life * 0.5)
	_check("4b 수명 절반에는 살아 있다", fx.active_count() == 1, "%d개" % fx.active_count())
	fx.advance(life)
	_check("4c 수명이 지나면 사라진다", fx.active_count() == 0,
		"%d개 — 안 사라지면 배열이 영원히 자란다" % fx.active_count())
	_check("4d 흔들림도 같이 멎는다",
		fx.shake_amp_px() == 0 and fx.shake_offset() == Vector2i.ZERO,
		"진폭 %d · 오프셋 %s" % [fx.shake_amp_px(), str(fx.shake_offset())])

	# 상한 — 🔴 안 걸면 P3 연발에서 스파크가 수천 개가 된다.
	for _i in Tuning.FX_MAX * 4:
		fx.add_blast(Vector2(50.0, 50.0), last, Tuning.ELEM_BOLT)
	_check("4e 동시 연출 상한", fx.active_count() == Tuning.FX_MAX,
		"%d개 (상한 %d)" % [fx.active_count(), Tuning.FX_MAX])
	fx.clear()
	_check("4f 초기화가 전부 비운다", fx.active_count() == 0 and fx.shake_amp_px() == 0)
	fx.free()


# ─── X5. 🔴🔴 자취가 **id로** 짝지어지나 ──────────────────────────
## 소멸이 swap-remove라 **슬롯 인덱스가 틱마다 뒤바뀐다.** 자취를 인덱스로 들고 있으면
##  앞 투사체가 죽는 순간 **남의 자취가 뒤 투사체에 순간이동으로 달라붙는다.**
##  ⚠ 에러가 하나도 안 나고, 실게임에서도 「한 프레임 이상했다」로만 보여서 눈으로 못 잡는다.
func _x5_trail_is_keyed_by_id() -> void:
	var g := CellGrid.new()
	# 위쪽에만 벽. 아래로 쏜 투사체는 안 맞고 계속 난다.
	g.apply(CellGrid.cmd_fill(60, 16, 63, 40, Mat.STONE))
	var s := SpellSim.new()
	var v := SpellView.new()
	v.setup(s)

	s.fire(SpellSim.cmd_fire(10, 28, 1, 0, 0, Tuning.ELEM_BOLT))   # id 0 — 벽에 맞는다
	s.fire(SpellSim.cmd_fire(10, 100, 1, 0, 0, Tuning.ELEM_BOLT))  # id 1 — 계속 난다
	_check("5 두 발 다 떴다", s.active_count() == 2, "%d발" % s.active_count())

	# 셀 (x, 100)의 한가운데. 수평 발사라 세로 좌표는 **한 톨도** 안 변해야 한다.
	var survivor_y := 100.5 * 4.0
	var worst_gap := 0.0
	var worst_dy := 0.0
	var worst_ahead := 0.0
	var died := false
	# 🔴 알파 0 = 머리가 **직전 틱 자리**에 있다. 이 자리에서만 「자취가 머리를 앞지르나」가 보인다
	#  — 알파 1이면 머리가 이번 틱 자리라 앞지른 점과 겹쳐서 관측이 불가능해진다(실측: 이 줄이
	#  없을 때 자취가 한 칸 앞으로 튀어나가는 뮤테이션이 **전 항목 초록으로 통과했다**).
	v.set_render_alpha(0.0)
	for _i in 12:
		s.step(g)
		v.on_tick()
		if s.active_count() == 1:
			died = true
		# 살아남은 쪽(id 1)의 자취가 **연속**인지 — 남의 자취가 붙으면 여기서 튄다.
		for i in s.active_count():
			if s.get_id()[i] != 1:
				continue
			var pts := v.trail_points(i)
			for k in range(1, pts.size()):
				worst_gap = maxf(worst_gap, pts[k].distance_to(pts[k - 1]))
				# +x로 나는 중이므로 자취는 **전부 머리보다 왼쪽**이어야 한다.
				worst_ahead = maxf(worst_ahead, pts[k].x - pts[0].x)
			for p: Vector2 in pts:
				worst_dy = maxf(worst_dy, absf(p.y - survivor_y))

	# 한 틱 = 10셀 = 40px. 죽은 쪽은 y=28셀이라 288px 위다 — 붙으면 못 숨는다.
	_check("5b 하나가 벽에서 죽었다", died, "안 죽으면 이 그물이 아무것도 안 잰다")
	_check("5c 살아남은 자취가 연속이다", worst_gap < TICK_PX * 1.5,
		"최대 도약 %.1fpx (한 틱 %.0fpx)" % [worst_gap, TICK_PX])
	_check("5c-b 자취가 제 투사체 것이다", worst_dy < 1.0,
		"세로 이탈 %.1fpx — 남의 자취가 붙으면 288px 튄다" % worst_dy)
	_check("5c-c 자취가 머리를 앞지르지 않는다", worst_ahead < EPS,
		"%.1fpx 앞섰다 — 자취가 아직 도착 안 한 자리를 그리고 있다" % worst_ahead)

	# 🔴 누수 — 죽은 투사체의 자취가 남으면 딕셔너리가 영원히 자란다.
	for _i in 60:
		s.step(g)
		v.on_tick()
	_check("5d 전부 사라지면 자취도 0", s.active_count() == 0 and v.trail_count() == 0,
		"비행 %d · 자취 %d" % [s.active_count(), v.trail_count()])
	v.free()


# ─── X6. 보간 ─────────────────────────────────────────────────────
## 🔴 20Hz 시뮬을 60fps로 그리는 유일한 장치다. 빠지면 투사체가 **틱당 40px씩 순간이동한다.**
## ⚠ 「매끄러운가」는 실게임 전용이다 — 여기서는 **끝점이 맞나**까지만 잰다.
func _x6_interpolation() -> void:
	var g := CellGrid.new()
	var s := SpellSim.new()
	var v := SpellView.new()
	v.setup(s)
	s.fire(SpellSim.cmd_fire(10, 72, 1, 0, 1, Tuning.ELEM_WATER))
	s.step(g)
	s.step(g)
	v.on_tick()

	var prev := Vector2(
		float(s.get_prev_px()[0]) * SpellView.FP_TO_PX,
		float(s.get_prev_py()[0]) * SpellView.FP_TO_PX)
	var cur := Vector2(
		float(s.get_px()[0]) * SpellView.FP_TO_PX,
		float(s.get_py()[0]) * SpellView.FP_TO_PX)

	v.set_render_alpha(0.0)
	_check("6 알파 0 = 직전 틱 자리", v.head_px(0).distance_to(prev) < EPS,
		"%s vs %s" % [str(v.head_px(0)), str(prev)])
	v.set_render_alpha(1.0)
	_check("6b 알파 1 = 이번 틱 자리", v.head_px(0).distance_to(cur) < EPS,
		"%s vs %s" % [str(v.head_px(0)), str(cur)])
	v.set_render_alpha(0.5)
	var mid := v.head_px(0)
	_check("6c 알파 0.5 = 한가운데", mid.distance_to((prev + cur) * 0.5) < EPS, str(mid))
	# 🔴 한 틱이 40px 도약이라는 것 자체를 못 박는다 — 보간이 없으면 이 40px이 통째로 튄다.
	_check("6d 한 틱 도약이 실제로 크다", prev.distance_to(cur) > TICK_PX * 0.75,
		"%.1fpx (한 틱 %.0fpx)" % [prev.distance_to(cur), TICK_PX])
	v.free()


# ─── X7. 흔들림 ───────────────────────────────────────────────────
## 🔴 **정수 px여야 한다** — `snap_2d_transforms_to_pixel`이 켜져 있어 소수부는 버려진다.
##  float로 들고 있으면 「진폭을 0.5px로 줄였는데 아무 일도 안 난다」가 되고, 그건 손잡이가
##  거짓말을 한다는 뜻이다(사용자가 튜닝을 포기한다).
func _x7_shake_is_integer_and_bounded() -> void:
	var last := Tuning.FX_TIERS.size() - 1
	var amp := int(Tuning.FX_TIERS[last]["shake_px"])
	var fx := BlastFx.new()
	fx.add_blast(Vector2(0.0, 0.0), last, Tuning.ELEM_BOLT)

	var over := 0
	var moved := 0
	for _i in 12:
		fx.advance(0.008)
		var o := fx.shake_offset()
		if absi(o.x) > amp or absi(o.y) > amp:
			over += 1
		if o != Vector2i.ZERO:
			moved += 1
	_check("7 흔들림이 진폭 안에 있다", over == 0, "초과 %d회 (진폭 %d)" % [over, amp])
	_check("7b 실제로 흔들린다", moved > 0, "%d/12 프레임" % moved)
	# 진폭이 감쇠하는지 — 끝에 가까울수록 작아져야 한다.
	fx.advance(float(int(Tuning.FX_TIERS[last]["shake_ms"])) / 1000.0)
	_check("7c 지속이 끝나면 0으로 돌아온다", fx.shake_offset() == Vector2i.ZERO,
		str(fx.shake_offset()))
	fx.free()


# ─── X8. 총구 ─────────────────────────────────────────────────────
## 🔴🔴 **v1이 죽은 항목 중 하나가 「총구가 위력을 안 따라간다」였다.**
##  ⚠ 이 프로토타입엔 캐릭터가 없어 총구가 고정점이다 — 그래서 **v1의 그 항목을 그대로 재는 건
##   아니다.** 여기서 재는 건 「고른 단이 쏘기 전에 화면에 나타나나」뿐이다.
func _x8_muzzle_follows_tier() -> void:
	var fx := BlastFx.new()
	var radii: Array[float] = []
	for t in Tuning.FX_TIERS.size():
		fx.muzzle_tier = t
		radii.append(fx.muzzle_radius())
	_rising("8 총구가 고른 위력을 따라간다", radii, "(맥동은 세 단에 똑같이 걸린다)")
	fx.free()


# ─── X9. 원소를 늘리고 색을 잊으면 화면이 비명을 지르나 ───────────
## 🔴 `ELEM_FX_MISSING`(마젠타)은 `cell_materials.gd`의 `MISSING_COLOR`와 같은 장치다 —
##  **원소가 늘었는데 색이 안 따라오는 것**이 정확히 T8이고, 얌전한 검정으로 두면 조용히 지나간다.
## ⚠ 지금까지 **그 장치 자체를 아무도 안 쟀다.** 폴백이 죽어 있으면 T8 방어가 통째로 없는 것이다.
func _x9_missing_element_screams() -> void:
	var fx := BlastFx.new()
	var known := fx.elem_palette(Tuning.ELEM_BOLT)
	var unknown := fx.elem_palette(9999)
	_check("9 아는 원소는 제 색을 준다", known != Tuning.ELEM_FX_MISSING, str(known))
	_check("9b 모르는 원소는 마젠타로 비명을 지른다", unknown == Tuning.ELEM_FX_MISSING,
		"%s — 얌전한 색이면 원소를 늘리고 잊어도 아무도 모른다" % str(unknown))
	# 🔴 정의된 원소 **전부**에 색이 있나 — 원소 목록과 색 표가 갈라지는 걸 여기서 잡는다.
	var uncolored: Array[int] = []
	for e: int in Tuning.ELEM_ALL:
		if fx.elem_palette(e) == Tuning.ELEM_FX_MISSING:
			uncolored.append(e)
	_check("9c 모든 원소에 색이 있다", uncolored.is_empty(), "색 없는 원소 %s" % str(uncolored))
	fx.free()


# ─── X10. 🔴 착탄 줄기 — 투사체가 착탄점에 **도달하는 그림** ──────
## 시뮬이 투사체를 터진 그 틱에 제거해서, 마지막으로 그려진 머리는 착탄 셀보다 최대 한 틱 뒤에 있고
##  섬광은 착탄 셀에 뜬다 ⇒ **「탄이 벽에 닿기 직전에 사라지고 그 앞쪽에서 터진다」**.
## ⚠ **X5c-c와 같은 계열이다**(자취가 머리를 앞지르나) — 방향만 반대고, 둘 다 16ms짜리라 눈으로 못 본다.
func _x10_impact_streak() -> void:
	var fx := BlastFx.new()
	var from := Vector2(100.0, 100.0)
	var at := Vector2(140.0, 100.0)
	fx.add_blast(at, 1, Tuning.ELEM_BOLT, from)
	_check("10 폭발이 시작점을 들고 있다", fx.streak_from(0) == from,
		"%s (기대 %s)" % [str(fx.streak_from(0)), str(from)])
	fx.clear()
	fx.add_blast(at, 1, Tuning.ELEM_BOLT)
	_check("10b 시작점을 모르면 줄기가 없다", not fx.streak_from(0).is_finite(),
		"모르는데 그으면 마법이 엉뚱한 데서 튀어나온다")
	# 총구에는 줄기가 없어야 한다 — 총구는 「어디서 왔나」가 없다.
	fx.clear()
	fx.add_muzzle(at, 1, Tuning.ELEM_BOLT)
	_check("10c 총구에는 줄기가 없다", not fx.streak_from(0).is_finite())
	fx.free()

	# 🔴🔴 **`SpellView`가 죽은 투사체의 마지막 자리를 실제로 내주나** — 껍데기가 이걸 꺼내
	#  `add_blast`에 넘긴다. ⚠ **`on_tick()`이 죽은 id를 지우기 전에만** 꺼낼 수 있다(순서 계약).
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(60, 0, 63, CellGrid.H - 1, Mat.STONE))
	var s := SpellSim.new()
	var v := SpellView.new()
	v.setup(s)
	s.fire(SpellSim.cmd_fire(10, 72, 1, 0, 0, Tuning.ELEM_BOLT))
	var hit: Dictionary = {}
	for _i in 12:
		var blasts := s.step(g)
		if not blasts.is_empty():
			hit = blasts[0]
			break
		v.on_tick()
	_check("10d 벽에서 터졌다", not hit.is_empty(), str(hit))
	if not hit.is_empty():
		var last := v.last_trail_px(int(hit["id"]))
		var impact := Vector2(
			(float(int(hit["x"])) + 0.5) * CellRenderer.CELL_PX,
			(float(int(hit["y"])) + 0.5) * CellRenderer.CELL_PX)
		_check("10e 죽은 투사체의 마지막 자리를 꺼낼 수 있다", last.is_finite(), str(last))
		# 그 자리와 착탄점 사이가 **메워야 할 틈**이다. 한 틱보다 크면 뭔가 잘못된 것이다.
		_check("10f 그 자리가 착탄점 한 틱 안에 있다",
			last.is_finite() and last.distance_to(impact) <= TICK_PX + 1.0,
			"틈 %.1fpx (한 틱 %.0fpx)" % [last.distance_to(impact) if last.is_finite() else -1.0, TICK_PX])
		# 🔴 `on_tick()` 뒤에는 사라진다 — 껍데기의 호출 순서가 계약인 이유가 이것이다.
		v.on_tick()
		_check("10g on_tick 뒤에는 사라진다(순서가 계약이다)",
			not v.last_trail_px(int(hit["id"])).is_finite(),
			"안 사라지면 자취 딕셔너리가 누수다")
	v.free()
