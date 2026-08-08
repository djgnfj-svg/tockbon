extends RefCounted
## `src/actor/progress.gd` and its award integration in `world_step.gd`'s death loop
## (`docs/plans/3.done/levelup-and-three-picks.md`, Stage B).
##
## **Everything here that touches `WorldStep` builds a bare pig kill by writing `hp = 0` directly and running
## one tick** — combat itself (does a bolt connect, does invulnerability hold) is already `net_damage`'s and
## `net_monster`'s job. What this file measures is only the award: does XP/money/level/`pending_picks` move
## the right amount, in the right place, exactly once.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const Progress := preload("res://src/actor/progress.gd")
const ThreePick := preload("res://src/actor/three_pick.gd")

const DT := 1.0 / 60.0
const FLOOR_CY := 100
const FLOOR_TOP := FLOOR_CY * Tuning.CELL_PX


func run(t) -> void:
	_kill_raises_xp_and_money_by_the_table_value(t)
	_xp_crossing_the_threshold_levels_up_with_remainder(t)
	_two_levels_in_one_award_grant_two_pending_picks(t)
	_reset_reverts_all_four_fields(t)
	_award_happens_once_per_death_not_per_tick(t)
	_add_xp_guards_against_a_nonpositive_threshold(t)
	_leveling_rate_measured_by_value(t)
	_open_pick_and_decline(t)
	_drawn_is_a_copy_not_the_live_array(t)
	_open_pick_actually_uses_progress_owned_rng(t)
	_reset_clears_an_open_pick(t)
	_dice_left_is_zero_and_inert(t)
	_take_consumes_a_pending_pick_and_rejects_unknown_ids(t)


# ══════════════════════════════════════════════════════════════════
#  Acceptance 1 — killing raises XP (and money), read from the table
# ══════════════════════════════════════════════════════════════════

## **Read from the table, not the literal** — hardcoding `12`/`5` here would still pass the day someone
## changes the provisional values in `monster_defs.DEFS` without updating this file, and that is exactly the
## "two copies of a number" trap this whole codebase avoids elsewhere.
func _kill_raises_xp_and_money_by_the_table_value(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var world := _new_world()
	var pr := world.progress()
	t.eq(pr.xp, 0, "스폰 전에는 xp가 0이다 (전제)")

	var mid := world.spawn_monster(kind, 600, FLOOR_TOP - MonsterDefs.h_px(kind))
	t.ok(mid > 0, "돼지가 스폰됐다 (전제)")
	_kill(world, 0)

	t.eq(world.monster_count(), 0, "죽은 돼지가 목록에서 빠졌다 (전제)")
	t.eq(pr.xp, MonsterDefs.xp_of(kind),
		"얻은 xp가 표의 값과 정확히 같다 (%d)" % MonsterDefs.xp_of(kind))
	t.eq(pr.money, MonsterDefs.money_of(kind),
		"돈도 표의 값과 정확히 같다 (%d)" % MonsterDefs.money_of(kind))

	# The hen is a different value — a check passing on one kind alone could be a coincidence
	# (`GLYPH_SPREAD`'s common-rarity trap from Stage A, the same shape: right for the wrong reason).
	var world2 := _new_world()
	var pr2 := world2.progress()
	world2.spawn_monster(MonsterDefs.KIND_HEN, 600, FLOOR_TOP - MonsterDefs.h_px(MonsterDefs.KIND_HEN))
	_kill(world2, 0)
	t.eq(pr2.xp, MonsterDefs.xp_of(MonsterDefs.KIND_HEN), "닭도 자기 표 값만큼 xp를 준다 (%d)" % MonsterDefs.xp_of(MonsterDefs.KIND_HEN))
	t.ok(MonsterDefs.xp_of(MonsterDefs.KIND_HEN) != MonsterDefs.xp_of(kind),
		"돼지와 닭의 xp가 실제로 다르다 (한쪽만 재고 우연히 맞은 게 아니다)")


# ══════════════════════════════════════════════════════════════════
#  Leveling — the threshold, the remainder, and stacking
# ══════════════════════════════════════════════════════════════════

func _xp_crossing_the_threshold_levels_up_with_remainder(t) -> void:
	var pr := Progress.new()
	var need := Progress.xp_for_level(0)
	pr.add_xp(need + 15)
	t.eq(pr.level, 1, "문턱을 넘으면 레벨이 정확히 1 오른다")
	t.eq(pr.xp, 15, "나머지가 그대로 이월된다 (문턱 %d + 15 → xp 15)" % need)
	t.eq(pr.pending_picks, 1, "대기 중인 세 장 뽑기가 하나 생겼다")

	# Negative control — falling short of the threshold must not level at all.
	var pr2 := Progress.new()
	pr2.add_xp(need - 1)
	t.eq(pr2.level, 0, "문턱에 하나 못 미치면 레벨이 그대로다")
	t.eq(pr2.xp, need - 1, "xp도 준 만큼만 그대로 쌓인다")


## **The doc's own TBD, decided as "stacking"** — the only option that cannot silently eat a reward.
func _two_levels_in_one_award_grant_two_pending_picks(t) -> void:
	var pr := Progress.new()
	var first := Progress.xp_for_level(0)
	var second := Progress.xp_for_level(1)
	pr.add_xp(first + second + 7)
	t.eq(pr.level, 2, "한 번의 xp 획득으로 레벨이 둘 오른다")
	t.eq(pr.pending_picks, 2, "대기 중인 뽑기도 둘이다 (하나로 뭉개지지 않는다)")
	t.eq(pr.xp, 7, "나머지가 정확히 이월된다")


# ══════════════════════════════════════════════════════════════════
#  Reset
# ══════════════════════════════════════════════════════════════════

## **`WorldStep.reset()` is the actual owner** — `stage.gd`'s `reset_stage()` calls it unconditionally
## already, the same one place `_queue`/`_fire_count`/`_monsters` all revert through. Testing headless means
## testing `WorldStep.reset()` directly; the scene-side wiring is structural (one call, already there) and
## not a second thing to re-derive here.
func _reset_reverts_all_four_fields(t) -> void:
	var world := _new_world()
	var pr := world.progress()
	pr.add_xp(Progress.xp_for_level(0) + Progress.xp_for_level(1) + 5)
	pr.add_money(99)
	t.ok(pr.level > 0 and pr.xp > 0 and pr.money > 0 and pr.pending_picks > 0,
		"넷 다 0이 아니게 채웠다 (검사의 전제)")

	world.reset()
	t.eq(pr.xp, 0, "reset이 xp를 되돌린다")
	t.eq(pr.level, 0, "reset이 레벨을 되돌린다")
	t.eq(pr.money, 0, "reset이 돈을 되돌린다")
	t.eq(pr.pending_picks, 0, "reset이 대기 중인 뽑기도 되돌린다")


# ══════════════════════════════════════════════════════════════════
#  Once per death, not once per tick
# ══════════════════════════════════════════════════════════════════

## **Inversion**: tie the award to "is any monster sitting at `hp <= 0`" (checked independently of removal)
## instead of the removal pass itself, and a corpse that has not yet been swept would pay again every tick.
## In the actual code this cannot happen **because removal is immediate, in the same pass** — measured here
## by running many more ticks after the kill and confirming xp does not move again.
func _award_happens_once_per_death_not_per_tick(t) -> void:
	var kind := MonsterDefs.KIND_PIG
	var world := _new_world()
	var pr := world.progress()
	world.spawn_monster(kind, 600, FLOOR_TOP - MonsterDefs.h_px(kind))
	_kill(world, 0)

	t.eq(world.monster_count(), 0, "그 틱에 죽어서 목록에서 빠졌다 (전제)")
	var once := pr.xp
	t.eq(once, MonsterDefs.xp_of(kind), "죽은 그 틱에 정확히 한 번어치 xp를 받았다 (전제)")

	_frames(world, Tuning.TICK_DIVIDER * 20)
	t.eq(pr.xp, once, "그 뒤로 20틱이 더 지나도 xp가 그대로다 (죽을 때 한 번뿐, 틱마다가 아니다)")
	t.eq(pr.money, MonsterDefs.money_of(kind), "돈도 마찬가지로 그대로다")


# ══════════════════════════════════════════════════════════════════
#  The loop guard — not a scenario that happens today
# ══════════════════════════════════════════════════════════════════

## **A guard against a future retune, pinned by value.** `xp_for_level` cannot return 0 or negative today
## (`80 + 40*level` for `level >= 0`), so this cannot spin in principle right now — but nothing asserted that
## fact until this check, and a hung frame is the failure mode this harness handles worst: the net **process
## times out** instead of a `t.eq` going red, so the usual "read the failure line" diagnosis does not fire.
##
## **`level` is set directly, not reached through `add_xp`** — a negative level is not producible by normal
## play, but the field is public, and this is exactly the shape a future non-monotonic formula would present
## to `add_xp` from the inside. Reaching the line after the call **is** the assertion (the same idiom
## `net_spell._list_is_finite` uses for "does the loop actually end") — a hang has nothing left to time out on
## if this file's own harness call already returned.
func _add_xp_guards_against_a_nonpositive_threshold(t) -> void:
	var pr := Progress.new()
	pr.level = -3
	t.ok(Progress.xp_for_level(pr.level) <= 0, "이 레벨에서 문턱이 0 이하다 (검사의 전제)")
	t.expect_error("xp_for_level")
	pr.add_xp(10)
	t.ok(true, "문턱이 0 이하여도 add_xp가 멈추지 않고 돌아온다 (이 줄에 닿은 것 자체가 증거다)")
	t.eq(pr.level, -3, "레벨이 그 자리에서 멈춘다 (더 깎을 값이 없는데 오르지 않는다)")


# ══════════════════════════════════════════════════════════════════
#  Stage C — open_pick() / decline(), the stateful door onto three_pick.draw
# ══════════════════════════════════════════════════════════════════

## The draw rule itself (`ThreePick.draw`) is `net_three_pick`'s job — this measures only the **door**:
## does it refuse to open with nothing pending, does it refuse to open twice, and does declining close
## without spending the pick.
func _open_pick_and_decline(t) -> void:
	var pr := Progress.new()
	t.ok(not pr.is_pick_open(), "시작할 때 열려 있지 않다 (전제)")
	t.ok(not pr.open_pick([]), "대기 중인 뽑기가 없으면 안 열린다")
	t.eq(pr.drawn().size(), 0, "안 열렸으니 뽑힌 것도 없다")

	pr.pending_picks = 1
	t.ok(pr.open_pick([]), "대기가 있으면 열린다")
	t.ok(pr.is_pick_open(), "열린 상태로 표시된다")
	t.eq(pr.drawn().size(), 3, "세 장이 뽑혔다 (빈 서고 기준)")
	t.ok(not pr.open_pick([]), "이미 열려 있으면 다시 안 연다 (두 번 뽑지 않는다)")

	var picks_before := pr.pending_picks
	var drawn_before := pr.drawn().duplicate()
	pr.decline()
	t.ok(not pr.is_pick_open(), "취소하면 닫힌다")
	t.eq(pr.drawn().size(), 0, "취소하면 뽑힌 목록이 비워진다")
	t.eq(pr.pending_picks, picks_before,
		"취소해도 대기 수는 그대로다 (%s를 봤지만 하나도 안 썼다)" % [drawn_before])


## **`drawn()` must hand out a copy, not the live array.** `_drawn` *is* the open/closed flag
## (`is_pick_open()` reads its own emptiness), so a caller that mutates what `drawn()` returned would
## silently corrupt pick state from the outside — a four-card window, or a pick nothing can ever close.
## Stages D and E are exactly the kind of consumer that would hold this array while the player clicks.
func _drawn_is_a_copy_not_the_live_array(t) -> void:
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.open_pick([])
	t.eq(pr.drawn().size(), 3, "세 장이 뽑혔다 (전제)")

	var got := pr.drawn()
	got.append(-999)
	got.clear()
	t.eq(pr.drawn().size(), 3, "밖에서 받은 목록을 건드려도 내부 상태는 그대로다 (아직 세 장이다)")
	t.ok(pr.is_pick_open(), "그리고 여전히 열린 상태다 (건드린 사본이 닫힌 것으로 안 읽힌다)")


## **`open_pick()` must actually thread `_rng` through** — replacing it with a fresh, unseeded
## `RandomNumberGenerator.new()` per call passed every other Stage-C check, because the nets that call
## `ThreePick.draw()` directly seed their *own* generator and never touch `Progress._rng` at all — the door is
## measured, the stream through the door is not.
## **Proof, not inference**: seed `_rng` by hand, then confirm `open_pick()`'s output matches `ThreePick.draw()`
## called directly against an independently-seeded generator with the **same** seed, call for call across
## several open/decline cycles. A bypassed `_rng` could not reproduce this — the odds of a fresh unseeded
## stream matching by chance across even one draw of 9-choose-3 are negligible, let alone three in a row.
func _open_pick_actually_uses_progress_owned_rng(t) -> void:
	var pr := Progress.new()
	pr._rng.seed = 42
	pr.pending_picks = 5

	var mirror := RandomNumberGenerator.new()
	mirror.seed = 42

	for i in 3:
		t.ok(pr.open_pick([]), "%d번째 뽑기가 열렸다 (전제)" % (i + 1))
		var want := ThreePick.draw([], mirror)
		t.eq(pr.drawn(), want,
			"%d번째 뽑기가 Progress 자신의 rng 흐름과 정확히 일치한다 (씨앗을 넣었더니 그대로 나온다)" % (i + 1))
		pr.decline()


func _reset_clears_an_open_pick(t) -> void:
	var pr := Progress.new()
	pr.pending_picks = 1
	pr.open_pick([])
	t.ok(pr.is_pick_open(), "전제 — 열려 있다")
	pr.reset()
	t.ok(not pr.is_pick_open(), "reset이 열린 뽑기도 닫는다")
	t.eq(pr.drawn().size(), 0, "reset 뒤에는 뽑힌 목록도 비어 있다")
	t.eq(pr.pending_picks, 0, "reset이 대기 수도 되돌린다 (기존 계약)")


# ══════════════════════════════════════════════════════════════════
#  Stage E — take(), the bookkeeping half of a placement
# ══════════════════════════════════════════════════════════════════

## **`take()` never touches a circle** (its own header) — placement itself is `three_pick_window`'s job,
## calling `spell_circle.place_glyph()` directly, *before* `take()` is ever reached. This measures only the
## bookkeeping: does a call for an id that was actually drawn close the pick and spend exactly one pending
## pick, and does a call for an id that was **not** drawn (the stale-click guard) change nothing at all.
func _take_consumes_a_pending_pick_and_rejects_unknown_ids(t) -> void:
	var pr := Progress.new()
	pr.pending_picks = 2
	pr.open_pick([])
	var drawn := pr.drawn()
	t.eq(drawn.size(), 3, "세 장이 뽑혔다 (전제)")

	# -- an id that was never drawn does nothing --
	var foreign := -999
	t.ok(not drawn.has(foreign), "-999는 뽑힌 목록에 없다 (전제)")
	t.ok(not pr.take(foreign), "뽑히지 않은 id는 take()가 거절한다")
	t.ok(pr.is_pick_open(), "거절돼도 뽑기는 그대로 열려 있다")
	t.eq(pr.pending_picks, 2, "거절되면 대기 수도 그대로다")

	# -- an id that was actually drawn closes the pick and spends one --
	var glyph_id: int = drawn[0]
	t.ok(pr.take(glyph_id), "실제로 뽑힌 id는 take()가 받아들인다")
	t.ok(not pr.is_pick_open(), "받아들이면 뽑기가 닫힌다")
	t.eq(pr.drawn().size(), 0, "받아들이면 뽑힌 목록도 비워진다")
	t.eq(pr.pending_picks, 1, "대기 수가 정확히 하나 줄었다 (2 -> 1)")

	# -- and now nothing is open, so a second take() (even for the same id) has nothing to take --
	t.ok(not pr.take(glyph_id), "닫힌 뒤에는 같은 id라도 take()가 더 이상 받지 않는다")
	t.eq(pr.pending_picks, 1, "그리고 대기 수도 더 줄지 않는다")


## **A slot, not a knob** — the doc's own words. `dice_left` starts at 0 and this file greps its own source
## tree for any assignment to it, so a future PR that quietly wires a "+1 dice" path without also updating
## this check is the only way this could ever go unnoticed otherwise.
## **Widened from a one-file version whose comment overstated it.** That version read only `progress.gd`, so
## a **different** file writing `pr.dice_left = 1` — exactly the shape Stage D's window is about to be —
## would have passed silently. It also missed `set("dice_left", ...)` **even inside the one file it did
## read**, demonstrated: `pr.set("dice_left", 1)` moved `pr.dice_left` to 1 while the old text scan stayed
## green, because that line contains no literal `=` next to the word.
## **This version scans every `.gd` under `src/`** and catches both the direct-assignment form
## (`dice_left\s*=(?!=)`, a lookahead so `==`/`!=`/`<=`/`>=` comparisons do not false-positive) and
## `set("dice_left", ...)` / `set('dice_left', ...)`.
func _dice_left_is_zero_and_inert(t) -> void:
	var pr := Progress.new()
	t.eq(pr.dice_left, 0, "dice_left가 0에서 시작한다")

	var files := _scan_gd_files("res://src")
	t.ok(files.size() > 0, "src/ 아래에서 .gd 파일을 찾았다 (%d개 — 전제)" % files.size())

	var re_assign := RegEx.new()
	t.eq(re_assign.compile("dice_left\\s*=(?!=)"), OK, "대입 패턴이 컴파일된다 (전제)")
	var re_set := RegEx.new()
	t.eq(re_set.compile("set\\(\\s*[\"']dice_left[\"']"), OK, "set() 패턴이 컴파일된다 (전제)")

	# **Both patterns are proven to actually bite first** — an uninverted check proves "it runs", not "it
	#  measures" (CLAUDE.md). Without this, a typo in either pattern would leave the whole function green
	#  forever with nothing to catch.
	t.ok(re_assign.search("\tdice_left = 1") != null, "대입 패턴이 실제 대입을 문다 (전제)")
	t.ok(re_assign.search("\tif dice_left == 0:") == null,
		"대입 패턴이 비교(==)는 안 문다 (오탐이 아니다 — 전제)")
	t.ok(re_set.search("\tpr.set(\"dice_left\", 1)") != null, "set() 패턴이 실제 set()을 문다 (전제)")

	var hits: Array[String] = []
	for path: String in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		for line: String in src.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("var dice_left"):
				continue
			if re_assign.search(code) != null or re_set.search(code) != null:
				hits.append("%s: %s" % [path, code])
	t.eq(hits, [] as Array[String],
		"src/ 트리 전체에서 선언 말고는 dice_left에 값을 쓰는 줄이 없다")


# ══════════════════════════════════════════════════════════════════
#  Acceptance 9 — measured by value, not forced to a range
# ══════════════════════════════════════════════════════════════════

## **Measured, not asserted as a target** — the same idiom `net_damage._spread_hit_count_is_recorded` already
## holds for this repo ("a record, not a target number"). `xp_for_level = 60 + 30*level` was chosen against
## the doc's actual grounds ("20-30 trash mobs -> three level-ups per run"), not the "7-10 kills per level"
## phrasing alone — the threshold grows linearly while a kill's XP does not, so no fixed formula holds that
## ratio flat forever, and only "kills by level 3" was ever the real target.
##
## **Two populations, because "pure pig" is the fast bound, not the typical case.** A real run mixes pig
## (12 XP) and hen (6 XP) kills; alternating between them levels slower than pure pig. Both are recorded so a
## future retune of `xp_for_level` or the pig/hen XP columns is checked against the range's two ends, not one:
##   pure pig            level 3 by kill **23**
##   alternating pig/hen level 3 by kill **30** — the doc's number, landing on the realistic population
## Any future retune should restamp both arrays, not delete the check.
func _leveling_rate_measured_by_value(t) -> void:
	var pig := MonsterDefs.KIND_PIG
	var hen := MonsterDefs.KIND_HEN
	var pure_pig := _measure_leveling(t, [pig])
	t.eq(pure_pig, [5, 13, 23, 35, 50, 68],
		"돼지만 잡을 때 레벨업까지 누적 마릿수 기록이 그대로다 (표 값이 바뀌면 여기가 먼저 움직인다) — 3레벨이 23마리째")

	var mixed := _measure_leveling(t, [pig, hen])
	t.eq(mixed, [7, 17, 30, 47, 67, 90],
		"돼지·닭을 번갈아 잡을 때 기록이 그대로다 — 3레벨이 30마리째 (문서의 실제 근거 숫자)")


## Kills monsters cycling through `kinds` (e.g. `[pig, hen]` alternates) until level 6 or 500 kills, and
## returns the cumulative kill count at each level-up. Shared by both populations above so the loop itself is
## not duplicated — only the kind cycle differs.
func _measure_leveling(t, kinds: Array[int]) -> Array[int]:
	var world := _new_world()
	var pr := world.progress()
	var kills := 0
	var last_level := 0
	var cumulative_at_level: Array[int] = []
	while pr.level < 6 and kills < 500:
		var kind: int = kinds[kills % kinds.size()]
		var mid := world.spawn_monster(kind, 600, FLOOR_TOP - MonsterDefs.h_px(kind))
		t.ok(mid > 0, "몬스터 %d번째가 스폰됐다 (전제)" % (kills + 1))
		_kill(world, world.monster_count() - 1)
		kills += 1
		if pr.level != last_level:
			cumulative_at_level.append(kills)
			last_level = pr.level
	t.ok(cumulative_at_level.size() >= 3, "적어도 세 레벨은 올랐다 (%s — 기록)" % [cumulative_at_level])
	return cumulative_at_level


# ══════════════════════════════════════════════════════════════════
#  Tools
# ══════════════════════════════════════════════════════════════════

func _new_world() -> WorldStep:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(600, FLOOR_TOP - Character.H_PX)
	return WorldStep.new(g, spell, ch)


## Kills the monster at `index` by writing `hp = 0` directly and running one tick — see this file's header
## for why combat itself is not re-derived here.
func _kill(world: WorldStep, index: int) -> void:
	world.monster_at(index).hp = 0
	_frames(world, Tuning.TICK_DIVIDER)


func _frames(w: WorldStep, n: int) -> void:
	for _i in n:
		w.frame(DT, 0.0, false, false)


func _floor_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, FLOOR_CY, CellGrid.W - 1, FLOOR_CY + 8 - 1, Mat.STONE))
	return g


func _scan_gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_scan_gd_files(dir.path_join(sub)))
	return out
