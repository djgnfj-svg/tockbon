extends RefCounted
## `src/actor/progress.gd` and its award integration in `world_step.gd`'s death loop
## (`levelup-and-three-picks.md`, Stage B).
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
const Monster := preload("res://src/actor/monster.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const Progress := preload("res://src/actor/progress.gd")
const ThreePick := preload("res://src/actor/three_pick.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const CircleDefs := preload("res://src/sim/circle_defs.gd")

## Same lead `net_monster.gd`'s own `HIT_LEAD_PX` uses, so a fired bolt registers as a segment hit on the
## monster within a few ticks instead of tunnelling past or never reaching it.
const HIT_LEAD_PX := 24

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
	_reward_gate_starts_empty(t)
	_boss_death_sets_the_reward_gate_trash_mob_death_does_not(t)
	_clearing_the_reward_is_the_only_thing_that_un_pends_it(t)
	_reset_clears_the_reward_gate(t)
	_reward_gates_are_independent_per_kind(t)
	_owned_runes_start_at_the_fixed_kit(t)
	_grant_rune_is_the_only_door_in(t)
	_ownership_survives_unrelated_progress_state(t)
	_reset_reverts_ownership_to_the_starting_kit_not_to_empty(t)
	_material_is_the_one_thing_a_reset_does_not_take(t)
	# ── run-end-settlement, Stage A ──
	_run_ticks_moves_once_per_tick_not_per_frame(t)
	_burn_only_kill_moves_damage_dealt_with_no_spell_fired(t)
	_overkill_records_hp_actually_removed_not_the_raw_hit(t)
	_player_damage_does_not_move_damage_dealt(t)
	_reset_zeroes_run_counters_and_gems_this_run_but_not_gems(t)
	_two_runs_gems_this_run_is_only_the_second_roll(t)
	_direct_hit_killing_blow_is_drained_even_though_the_monster_is_removed_this_same_tick(t)
	# ── onboarding-and-palette-tabs, Stage 7 ──
	_owns_circle_starts_at_the_fixed_kit(t)
	_onboarding_seen_survives_reset_and_next_stage(t)


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
#  Stage I (`stage1-bosses.md`) — the boss reward gate
# ══════════════════════════════════════════════════════════════════

## Before anything has died, both questions read false/false — not an error, not a crash, just "nothing to
## report" (the same contract `is_pick_open()` holds before any level has ever happened).
func _reward_gate_starts_empty(t) -> void:
	var pr := Progress.new()
	t.ok(not pr.boss_died(MonsterDefs.KIND_BULL), "아직 아무도 안 죽었으면 boss_died()는 거짓이다")
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "그리고 대기 상태도 아니다")
	pr.clear_pending_boss_rewards()
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "아무것도 대기 중이 아닐 때 수령해도 아무 일도 안 난다")


## **A boss's death sets the reward-pending flag; a trash mob's does not.** White-boxed straight to `hp = 0`
## via `_kill()` — the mechanism under test is `world_step.gd`'s own death loop
## (`if BossAi.has_pattern(dying.kind): _progress.set_boss_reward_pending(dying.kind)`), the exact same door
## XP/money already go through for every kind (this file's own header), not a separate path reconstructed here.
## **Both a boss and a trash mob die in the same tick** — the negative half (the pig) is measured in the same
## pass as the positive half, not a separate, easier-to-satisfy setup, so a mutation that gated on "any death"
## instead of "a boss's death" cannot pass by accident.
func _boss_death_sets_the_reward_gate_trash_mob_death_does_not(t) -> void:
	var world := _new_world()
	var bull_mid := world.spawn_monster(MonsterDefs.KIND_BULL, 700,
		FLOOR_TOP - MonsterDefs.h_px(MonsterDefs.KIND_BULL))
	t.ok(bull_mid > 0, "황소 스폰됐다 (검사의 전제)")
	var pig_mid := world.spawn_monster(MonsterDefs.KIND_PIG, 900,
		FLOOR_TOP - MonsterDefs.h_px(MonsterDefs.KIND_PIG))
	t.ok(pig_mid > 0, "돼지 스폰됐다 (검사의 전제)")
	var pr := world.progress()
	t.ok(not pr.boss_died(MonsterDefs.KIND_BULL), "죽기 전엔 황소가 안 죽은 상태다 (검사의 전제)")

	# Both die on the same tick - `_kill()` itself only advances one monster's hp, so both are zeroed first
	# and one shared tick processes the pair, the same "measured together" discipline this test's own header names.
	world.monster_at(0).hp = 0
	world.monster_at(1).hp = 0
	_frames(world, Tuning.TICK_DIVIDER)

	t.ok(pr.boss_died(MonsterDefs.KIND_BULL), "황소가 죽으면 boss_died()가 참이 된다")
	t.ok(pr.is_reward_pending(MonsterDefs.KIND_BULL), "그리고 보상이 대기 상태가 된다")
	t.ok(not pr.boss_died(MonsterDefs.KIND_PIG), "돼지가 죽어도 boss_died()는 안 참이다 (패턴이 없다)")
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_PIG), "돼지 보상도 대기 상태가 아니다")


## **The gate genuinely blocks something and the debug key's own method genuinely clears it — the full
## sequence a real fight produces**, not the bookkeeping methods checked in isolation: die -> pending -> still
## pending after a delay -> cleared -> not pending, but "died" itself never un-happens.
func _clearing_the_reward_is_the_only_thing_that_un_pends_it(t) -> void:
	var world := _new_world()
	var bull_mid := world.spawn_monster(MonsterDefs.KIND_BULL, 700,
		FLOOR_TOP - MonsterDefs.h_px(MonsterDefs.KIND_BULL))
	t.ok(bull_mid > 0, "황소 스폰됐다 (검사의 전제)")
	_kill(world, 0)
	var pr := world.progress()
	t.ok(pr.is_reward_pending(MonsterDefs.KIND_BULL), "죽자마자 대기 상태다 (검사의 전제)")

	# Time passing alone does not clear it - only the explicit call does (acceptance 8b's own order: reward
	#  first, wall/water second - nothing in this file's own door lets water start on a timer instead).
	_frames(world, 200)
	t.ok(pr.is_reward_pending(MonsterDefs.KIND_BULL), "시간이 지나도 저절로 안 풀린다")

	pr.clear_pending_boss_rewards()
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "명시적으로 수령하면 그제서야 풀린다")
	t.ok(pr.boss_died(MonsterDefs.KIND_BULL), "죽었다는 사실 자체는 남아 있다 (boss_died는 그대로 참)")


## `reset()` reverts the gate along with everything else - leave it out and a stage reset (R) would let a
## previous session's cleared/pending reward ride into the new one, the same class of bug `_reset_clears_an_
## open_pick` already guards for the pick window.
func _reset_clears_the_reward_gate(t) -> void:
	var pr := Progress.new()
	pr.set_boss_reward_pending(MonsterDefs.KIND_BULL)
	t.ok(pr.boss_died(MonsterDefs.KIND_BULL) and pr.is_reward_pending(MonsterDefs.KIND_BULL),
		"보상 대기 상태를 심었다 (검사의 전제)")
	pr.reset()
	t.ok(not pr.boss_died(MonsterDefs.KIND_BULL), "reset() 뒤엔 죽은 적도 없는 상태로 돌아간다")
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "당연히 대기 상태도 아니다")


## **Independent per kind** - the bull's own room ① water and the rooster's own room ③ water must gate
## separately (`_reward_pending`'s own header, `progress.gd`) - killing one boss and clearing its reward must
## not touch the other's gate, in either direction.
func _reward_gates_are_independent_per_kind(t) -> void:
	var pr := Progress.new()
	pr.set_boss_reward_pending(MonsterDefs.KIND_BULL)
	t.ok(not pr.boss_died(MonsterDefs.KIND_ROOSTER), "황소만 죽였는데 거대 수탉이 죽은 걸로 뜨지 않는다")
	pr.set_boss_reward_pending(MonsterDefs.KIND_ROOSTER)
	pr.clear_pending_boss_rewards()
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_BULL), "황소 보상도 수령 처리된다 (한 번에 전부 수령)")
	t.ok(not pr.is_reward_pending(MonsterDefs.KIND_ROOSTER), "거대 수탉 보상도 마찬가지다")
	t.ok(pr.boss_died(MonsterDefs.KIND_BULL) and pr.boss_died(MonsterDefs.KIND_ROOSTER),
		"둘 다 죽었다는 사실은 각자 그대로 남는다")


# ══════════════════════════════════════════════════════════════════
#  Stage A (`rune-lock-and-receiving.md`) — rune ownership
# ══════════════════════════════════════════════════════════════════

## **A fresh `Progress` owns only none — not fire.** `_owned_runes` is not empty at boot (an owner with
## nothing owned could not even carry the rune the starting seat holds), but **fire is not in it** — this is
## Stage B's actual lock, and it is the line that would go from red to green if `_starting_runes()` were ever
## quietly widened back to `{none, fire}`.
func _owned_runes_start_at_the_fixed_kit(t) -> void:
	var pr := Progress.new()
	t.ok(pr.owns_rune(Tuning.ELEM_NONE), "시작할 때 이미 무속성 룬을 갖고 있다")
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "시작할 때는 불 룬이 없다 (이것이 잠금이다)")
	t.ok(not pr.owns_rune(Tuning.ELEM_WATER), "시작할 때 물 룬도 없다 (아무도 안 줬다)")


## **`grant_rune()` is the only thing that moves `owns_rune()`.** A redundant grant (the bull's reward, taken
## twice by a stray debug-key press) is a harmless no-op — the same Dictionary-assignment idiom
## `set_boss_reward_pending` already holds for a repeated call — and granting one rune must not disturb any
## other already-owned or still-unowned rune.
func _grant_rune_is_the_only_door_in(t) -> void:
	var pr := Progress.new()
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "주기 전에는 불 룬이 없다 (전제)")
	pr.grant_rune(Tuning.ELEM_FIRE)
	t.ok(pr.owns_rune(Tuning.ELEM_FIRE), "grant_rune() 이후에는 불 룬을 갖고 있다")

	pr.grant_rune(Tuning.ELEM_FIRE)
	t.ok(pr.owns_rune(Tuning.ELEM_FIRE), "이미 가진 룬을 다시 줘도 조용히 그대로 갖고 있다 (중복 수령이 안전하다)")
	t.ok(pr.owns_rune(Tuning.ELEM_NONE), "불을 줘도 원래 갖고 있던 무속성은 그대로다")
	t.ok(not pr.owns_rune(Tuning.ELEM_WATER), "불을 줘도 관계없는 물은 여전히 안 갖고 있다")


## **Ownership is not a side effect of anything else `Progress` does.** XP, money, level-ups and the
## three-pick door all move through the same object — this measures that none of them silently touch
## `_owned_runes`, the same "independent per kind" discipline `_reward_gates_are_independent_per_kind` above
## already holds for the boss-reward gate.
func _ownership_survives_unrelated_progress_state(t) -> void:
	var pr := Progress.new()
	pr.grant_rune(Tuning.ELEM_FIRE)
	pr.add_xp(500)
	pr.add_money(50)
	pr.pending_picks = 1
	t.ok(pr.open_pick([]), "다른 상태를 이것저것 움직여봤다 (전제)")
	pr.decline()

	t.ok(pr.owns_rune(Tuning.ELEM_FIRE), "불 룬 보유가 그대로다")
	t.ok(pr.owns_rune(Tuning.ELEM_NONE), "시작 키트(무속성)도 그대로다 (xp·레벨·뽑기 어느 것도 룬 보유를 건드리지 않는다)")
	t.ok(not pr.owns_rune(Tuning.ELEM_WATER), "안 준 물은 여전히 안 갖고 있다")


## **`reset()` reverts to the starting kit, not to an empty set.** A stage reset (R) is a fresh run — a fresh
## run boots owning only none, the same fixed kit the field default holds. Clearing to `{}` instead would
## brick the reset run's own starting rune, a different flavor of the bricking `circle_window.gd`'s own header
## already names ("the rune stays bright and pickable" — here the failure would run the other way: the seat's
## own rune would come back veiled). And a rune earned mid-run (fire) must **not** survive — a reset is a
## fresh run, not a checkpoint.
func _reset_reverts_ownership_to_the_starting_kit_not_to_empty(t) -> void:
	var pr := Progress.new()
	pr.grant_rune(Tuning.ELEM_FIRE)
	t.ok(pr.owns_rune(Tuning.ELEM_FIRE), "불 룬을 얻었다 (검사의 전제)")

	pr.reset()
	t.ok(not pr.owns_rune(Tuning.ELEM_FIRE), "reset은 얻은 룬(불)을 되돌린다")
	t.ok(pr.owns_rune(Tuning.ELEM_NONE),
		"그리고 시작 키트(무속성)는 reset 뒤에도 그대로 갖고 있다 (빈 사전으로 브릭되지 않는다)")


# ══════════════════════════════════════════════════════════════════
#  `run-end-settlement.md`, Stage A — the settlement screen's three numbers
# ══════════════════════════════════════════════════════════════════

## `run_ticks` must move at 20Hz (once per tick), not at 60Hz (once per frame) — the same "drive by frame
## count, read by tick count" idiom `net_water`'s "exactly N cells per tick" already holds. Driving exactly
## `TICK_DIVIDER * n` frames and reading `n` back is what a mutation moving `advance_tick()` outside the tick
## branch (called every frame) cannot pass — it would read `TICK_DIVIDER * n`, not `n`.
func _run_ticks_moves_once_per_tick_not_per_frame(t) -> void:
	var world := _new_world()
	var pr := world.progress()
	t.eq(pr.run_ticks, 0, "시작할 때 0이다 (전제)")

	var n := 7
	_frames(world, Tuning.TICK_DIVIDER * n)
	t.eq(pr.run_ticks, n, "틱 나누개만큼 프레임을 돌리면 정확히 그 틱 수만큼만 오른다 (프레임마다가 아니다)")

	# One more lone frame lands inside the next tick's window without crossing it - run_ticks must not move.
	_frames(world, 1)
	t.eq(pr.run_ticks, n, "틱 경계 사이의 낱장 프레임 하나로는 틱이 늘지 않는다")


## **Acceptance 4 — kill something with fire alone, never landing a direct hit, and the damage is still
## non-zero.** This is the check the first draft would have failed (`monster.gd`'s own header: before
## `_apply_damage()` existed, `_burn()` wrote `hp` directly on its own, and only the direct-hit/blast path fed
## the sum, so a fire-only kill read 0 damage dealt).
##
## **No spell is ever fired** — `world.enqueue()` is never called here, so this cannot pass by accident through
## the other path. The character is pinned at the hen's own spawn centre (the same `_still_ch` trap
## `net_monster`'s own burn test names: put the character elsewhere and the hen walks toward it, off the
## burning tile, and the fire that was supposed to kill it goes out from under its feet with nothing measured).
func _burn_only_kill_moves_damage_dealt_with_no_spell_fired(t) -> void:
	var kind := MonsterDefs.KIND_HEN
	var g := _floor_grid()
	var stand_x := 600
	var stand_y := FLOOR_TOP - MonsterDefs.h_px(kind)
	var cx0 := floori(stand_x / float(Tuning.CELL_PX))
	var cx1 := floori((stand_x + MonsterDefs.w_px(kind) - 1) / float(Tuning.CELL_PX))
	g.apply(CellGrid.cmd_fill(cx0 - 2, FLOOR_CY, cx1 + 2, FLOOR_CY, Mat.WOOD))

	var spell := SpellSim.new()
	var ch := _still_ch(stand_x, kind)
	var world := WorldStep.new(g, spell, ch)
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "닭이 스폰됐다 (전제)")
	var pr := world.progress()
	t.eq(pr.damage_dealt, 0, "불 붙기 전엔 준 피해가 0이다 (전제)")

	var lit := 0
	for cx in range(cx0, cx1 + 1):
		if g.ignite(cx, FLOOR_CY):
			lit += 1
	t.ok(lit > 0, "발밑 나무에 불이 붙었다 (전제)")

	# 닭 최대 체력 10, 불 DPS 10 => 1초(20틱)면 죽는다. 나무 연료는 40틱을 버티므로 넉넉하다.
	_frames(world, Tuning.TICK_DIVIDER * 100)
	t.eq(world.monster_count(), 0, "마법을 한 번도 안 쐈는데 불만으로 죽었다 (전제)")
	t.eq(pr.damage_dealt, MonsterDefs.max_hp(kind),
		"직격이 한 번도 없었는데 준 피해가 정확히 최대 체력만큼 찍힌다")


## **Overkill, decided**: `_apply_damage` records `mini(hp, n)` — hp actually removed, not the raw hit. A
## monster at 5 hp taking a 100-point hit must add exactly 5 to the drained total, not 100.
## Driven directly at the `Monster` level (`_apply_damage`/`take_dealt` are this file's own subject here,
## same as `net_monster`'s own direct pokes at `_burn_acc`) — combat itself (does a bolt connect) is not
## re-derived, this file's own header names that as `net_damage`'s and `net_monster`'s job.
func _overkill_records_hp_actually_removed_not_the_raw_hit(t) -> void:
	var world := _new_world()
	var kind := MonsterDefs.KIND_PIG
	var mid := world.spawn_monster(kind, 600, FLOOR_TOP - MonsterDefs.h_px(kind))
	t.ok(mid > 0, "스폰됐다 (전제)")
	var m: Monster = world.monster_at(0)
	m.hp = 5
	m._apply_damage(100)
	t.eq(m.hp, 0, "체력이 0에서 멈춘다 (전제 — 음수로 안 내려간다)")
	t.eq(m.take_dealt(), 5, "100을 맞아도 실제로 깎인 건 5뿐이니 5만 기록된다 (과잉 타격이 그대로 새지 않는다)")


## **Bounds — "damage dealt" counts damage to monsters only.** The GDD's "magic hits the player too" means the
## player's own bolts can hurt the player, and that must never appear in this figure.
func _player_damage_does_not_move_damage_dealt(t) -> void:
	var ch := Character.new()
	ch.place(600, FLOOR_TOP - Character.H_PX)
	var world := WorldStep.new(_floor_grid(), SpellSim.new(), ch)
	var pr := world.progress()
	t.eq(pr.damage_dealt, 0, "전제")

	ch.take_hit(50, true)
	_frames(world, Tuning.TICK_DIVIDER)
	t.eq(pr.damage_dealt, 0, "플레이어 자신이 입은 피해는 준 피해에 안 잡힌다 (몬스터에게 준 것만 센다)")


## `reset()` zeroes the two new run counters and re-snapshots `_gems_at_run_start`, so `gems_this_run()` reads
## 0 right after — while `gems` itself, the one permanent thing, survives untouched (the same "material is the
## one thing a reset does not take" contract `_material_is_the_one_thing_a_reset_does_not_take` already holds,
## extended to the delta that reads off of it).
func _reset_zeroes_run_counters_and_gems_this_run_but_not_gems(t) -> void:
	var pr := Progress.new()
	pr.run_ticks = 50
	pr.damage_dealt = 77
	var got := pr.add_boss_gems()
	t.ok(got > 0, "원석을 얻었다 (전제)")
	t.eq(pr.gems_this_run(), got, "리셋 전엔 '이번 런' 몫이 얻은 만큼이다 (전제)")

	pr.reset()
	t.eq(pr.run_ticks, 0, "reset이 플레이 시간 카운터를 되돌린다")
	t.eq(pr.damage_dealt, 0, "reset이 준 피해 카운터도 되돌린다")
	t.eq(pr.gems, got, "원석 총량은 reset 뒤에도 그대로다 (달리기를 넘어 남는 유일한 것)")
	t.eq(pr.gems_this_run(), 0, "하지만 '이번 런' 몫은 0이다 (스냅샷이 reset 안에서 다시 찍혔다)")


## **Acceptance 7 — a second run's count-up shows only that run's earnings, not the running total.** Kill a
## boss, reset (the gate home), kill a boss again in the same process - `gems_this_run()` must track only the
## second roll, never the accumulated pool (`gems` itself, read raw, would start the count-up at the first
## run's total and tick up from there instead of from 0).
##
## **The bull's own kill also crosses level thresholds** (200 xp against `xp_for_level`'s table) and each
## crossing pays `GEMS_PER_LEVEL` too - the boss door and the level door are not the same roll, and both fire
## off one kill. The expected range is computed from the table, not hardcoded to the boss roll alone, or a
## future retune of either table would make this function read a range the code no longer produces.
func _two_runs_gems_this_run_is_only_the_second_roll(t) -> void:
	var kind := MonsterDefs.KIND_BULL
	var level_gems := _levels_crossed_from_zero(MonsterDefs.xp_of(kind)) * Progress.GEMS_PER_LEVEL
	var lo := Progress.GEMS_PER_BOSS_MIN + level_gems
	var hi := Progress.GEMS_PER_BOSS_MAX + level_gems

	var world := _new_world()
	var pr := world.progress()
	world.spawn_monster(kind, 700, FLOOR_TOP - MonsterDefs.h_px(kind))
	_kill(world, 0)
	var first_run := pr.gems_this_run()
	t.ok(first_run >= lo and first_run <= hi,
		"1차 런의 '이번 런' 몫이 (보스 굴림 + 레벨 보상) 범위 안이다 (%d, 범위 %d~%d)" % [first_run, lo, hi])
	t.eq(pr.gems, first_run, "리셋 전이라 총량과 '이번 런' 몫이 같다 (전제)")

	world.reset()
	t.eq(pr.gems_this_run(), 0, "리셋 직후엔 '이번 런' 몫이 0이다 (전제)")
	t.eq(pr.gems, first_run, "원석 총량은 리셋으로 안 지워진다 (전제)")

	world.spawn_monster(kind, 700, FLOOR_TOP - MonsterDefs.h_px(kind))
	_kill(world, 0)
	var second_run := pr.gems_this_run()
	t.ok(second_run >= lo and second_run <= hi,
		"2차 런의 몫도 같은 범위 안이다 (%d, 범위 %d~%d)" % [second_run, lo, hi])
	t.eq(pr.gems, first_run + second_run, "총량은 두 런의 합이다")
	t.ok(pr.gems_this_run() < pr.gems,
		"'이번 런' 몫이 누적 총량보다 작다 (총량을 그대로 읽었다면 두 런 합이 그대로 새는 자리다)")


## How many times a fresh (`level == 0`) `Progress` would cross a level threshold on a single `xp_gained`
## award - mirrors `add_xp`'s own loop exactly, read-only, so the two-run gem-range check above stays correct
## even if `xp_for_level` or a kind's xp column is retuned later.
static func _levels_crossed_from_zero(xp_gained: int) -> int:
	var level := 0
	var xp := xp_gained
	while xp >= Progress.xp_for_level(level):
		xp -= Progress.xp_for_level(level)
		level += 1
	return level


## **The killing blow itself must be drained.** A monster killed by a direct hit is removed inside the tick
## branch's own death loop, immediately after `on_tick()` runs and *before* the 60Hz `step()` loop runs this
## same frame. If the drain moved to the 60Hz loop instead (this doc's own Risk 4 - "the signature fake for
## this feature"), that loop would never see this monster again: the tick branch already removed it earlier in
## this same `frame()` call, so the killing blow's damage would be lost outright, not merely delayed.
##
## **A burn-only kill cannot exercise this risk** - `_burn()` runs every 60Hz frame, so draining in the 60Hz
## loop still catches it there before the next tick's removal. Only a direct-hit kill, where the damage and the
## removal both live in the tick branch, actually depends on the drain sitting in that same branch.
func _direct_hit_killing_blow_is_drained_even_though_the_monster_is_removed_this_same_tick(t) -> void:
	var kind := MonsterDefs.KIND_HEN
	var stand_x := 600
	var stand_y := FLOOR_TOP - MonsterDefs.h_px(kind)
	var world := _new_world()
	var pr := world.progress()
	var mid := world.spawn_monster(kind, stand_x, stand_y)
	t.ok(mid > 0, "닭이 스폰됐다 (전제)")
	var m: Monster = world.monster_at(0)
	m.hp = Character.DAMAGE_HIT  # 정확히 한 방 분량 - 죽인 그 한 방이 곧 막타다

	var row_cy := floori((stand_y + MonsterDefs.h_px(kind) * 0.5) / float(Tuning.CELL_PX))
	var origin_cx := floori((stand_x - HIT_LEAD_PX) / float(Tuning.CELL_PX))
	world.enqueue(SpellSim.cmd_fire(origin_cx, row_cy, 10, 0, Tuning.ELEM_NONE, Glyph.GLYPH_NONE))
	_frames(world, Tuning.TICK_DIVIDER * 5)

	t.eq(world.monster_count(), 0, "한 방에 죽어서 그 틱에 목록에서 빠졌다 (전제)")
	t.eq(pr.damage_dealt, Character.DAMAGE_HIT,
		"죽은 그 틱의 막타도 준 피해에 잡힌다 (몬스터가 사라지며 함께 새지 않는다)")


# ══════════════════════════════════════════════════════════════════
#  Tools
# ══════════════════════════════════════════════════════════════════

func _new_world() -> WorldStep:
	var g := _floor_grid()
	var spell := SpellSim.new()
	var ch := Character.new()
	ch.place(600, FLOOR_TOP - Character.H_PX)
	return WorldStep.new(g, spell, ch)


## **The trap `net_monster`'s own burn test names** (`_still_ch`, duplicated here rather than imported - the
## same per-file self-containment `net_town.gd`'s own duplicated `_wired_root` already justifies): from stage 2
## on, every monster walks toward the player. Put the character away from the monster's spawn point and it
## walks off the burning tile mid-measurement, and the fire that was supposed to kill it goes out from under
## its feet with nothing measured. Placing the character at the monster's own centre pins the walk axis to 0.
func _still_ch(stand_x: int, kind: int) -> Character:
	var ch := Character.new()
	var monster_center_x := float(stand_x) + MonsterDefs.w_px(kind) * 0.5
	ch.place(roundi(monster_center_x - Character.W_PX * 0.5), FLOOR_TOP - Character.H_PX)
	return ch


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


## **Material survives `reset()`, and nothing else does.**
##
## `docs/design/town.md`'s whole reason to exist is that something outlives a run ("what is permanent is a
## pool, not an object", GDD). `Progress.reset()` reverts every other field, and **the danger is that someone
## tidies the list and adds this one** — it would look consistent and would quietly delete permanence, with
## no other check in the suite noticing.
##
## **The negative half is measured in the same breath**: xp, level, money and pending picks must still be
## cleared. Without it, a `reset()` that had become a no-op would pass this function.
func _material_is_the_one_thing_a_reset_does_not_take(t) -> void:
	var pr := Progress.new()
	t.eq(pr.gems, 0, "원석은 0에서 시작한다")

	# **The boss door — a roll, so the range is what is measured, not one number.**
	var got := pr.add_boss_gems()
	t.ok(got >= Progress.GEMS_PER_BOSS_MIN and got <= Progress.GEMS_PER_BOSS_MAX,
		"보스가 %d~%d개를 준다 (%d개)" % [Progress.GEMS_PER_BOSS_MIN, Progress.GEMS_PER_BOSS_MAX, got])
	t.eq(pr.gems, got, "준 만큼 들어왔다")
	var got2 := pr.add_boss_gems()
	t.eq(pr.gems, got + got2, "원석은 쌓인다 (덮어쓰지 않는다)")
	# **Rolled many times, so "it always returns the minimum" cannot pass** — the range is the decision.
	var seen: Dictionary = {}
	for _i in 60:
		seen[pr.add_boss_gems()] = true
	for n: int in seen:
		t.ok(n >= Progress.GEMS_PER_BOSS_MIN and n <= Progress.GEMS_PER_BOSS_MAX,
			"예순 번 굴려도 %d개는 범위 안이다" % n)
	t.eq(seen.size(), Progress.GEMS_PER_BOSS_MAX - Progress.GEMS_PER_BOSS_MIN + 1,
		"범위 안의 값이 실제로 전부 나온다 (한 값에 고정돼 있지 않다)")

	# **The level door.** A trash mob never pays out directly; it reaches 원석 only this way.
	var lv := Progress.new()
	t.eq(lv.gems, 0, "전제")
	lv.add_xp(Progress.xp_for_level(0))
	t.eq(lv.level, 1, "한 레벨 올랐다 (전제)")
	t.eq(lv.gems, Progress.GEMS_PER_LEVEL, "레벨 하나에 원석 %d개" % Progress.GEMS_PER_LEVEL)
	# **One award crossing two thresholds pays both** — the same loop `pending_picks` rides.
	var big := Progress.new()
	big.add_xp(Progress.xp_for_level(0) + Progress.xp_for_level(1))
	t.eq(big.level, 2, "한 번에 두 레벨 올랐다 (전제)")
	t.eq(big.gems, Progress.GEMS_PER_LEVEL * 2, "두 번 다 준다 (뽑기와 같은 수만큼)")
	t.eq(big.gems, big.pending_picks * Progress.GEMS_PER_LEVEL, "원석 수와 대기 뽑기 수가 어긋나지 않는다")

	pr.add_xp(500)
	pr.add_money(40)
	t.ok(pr.level > 0 and pr.money > 0 and pr.pending_picks > 0, "달리기 안의 것들도 쌓였다 (전제)")

	var kept := pr.gems
	pr.reset()
	t.eq(pr.gems, kept, "리셋해도 원석은 그대로다 (달리기를 넘어 남는 유일한 것)")
	t.eq(pr.level, 0, "레벨은 지워진다")
	t.eq(pr.money, 0, "돈은 지워진다")
	t.eq(pr.xp, 0, "경험치도 지워진다")
	t.eq(pr.pending_picks, 0, "대기 중인 뽑기도 지워진다")


# ══════════════════════════════════════════════════════════════════
#  onboarding-and-palette-tabs.md, Stage 2/7
# ══════════════════════════════════════════════════════════════════

## **삼각 is not owned at boot — the user confirmed it explicitly** ("삼각진은 일단 안 가지고 있어야 되고").
## The same `_owned_runes_start_at_the_fixed_kit` shape, one axis over.
func _owns_circle_starts_at_the_fixed_kit(t) -> void:
	var pr := Progress.new()
	t.ok(pr.owns_circle(CircleDefs.CIRCLE_ROUND), "시작할 때 이미 동그라미 진을 갖고 있다")
	t.ok(not pr.owns_circle(CircleDefs.CIRCLE_TRIANGLE), "시작할 때는 삼각 진이 없다 (사용자가 명시적으로 확인했다)")

	pr.grant_circle(CircleDefs.CIRCLE_TRIANGLE)
	t.ok(pr.owns_circle(CircleDefs.CIRCLE_TRIANGLE), "grant_circle() 이후에는 삼각을 갖고 있다")
	t.ok(pr.owns_circle(CircleDefs.CIRCLE_ROUND), "삼각을 줘도 원래 갖고 있던 동그라미는 그대로다")

	pr.reset()
	t.ok(not pr.owns_circle(CircleDefs.CIRCLE_TRIANGLE), "reset은 얻은 삼각을 되돌린다")
	t.ok(pr.owns_circle(CircleDefs.CIRCLE_ROUND),
		"그리고 시작 키트(동그라미)는 reset 뒤에도 그대로 갖고 있다 (빈 사전으로 브릭되지 않는다)")


## **The single fact that makes the walkthrough run once ever, not once per reset.** `reset()` (R, going
## home) and `next_stage()` (the departure gate mid-run) both must leave it untouched — the same "survives
## a reset" contract `_unlocked`/`gems` already hold one level up, now for a `bool` instead of a set.
##
## **What goes red when inverted**: add `_onboarding_seen = false` to either `reset()` or `next_stage()`.
func _onboarding_seen_survives_reset_and_next_stage(t) -> void:
	var pr := Progress.new()
	t.ok(not pr.has_seen_onboarding(), "시작할 때는 아직 온보딩을 안 봤다 (전제)")
	pr.mark_onboarding_seen()
	t.ok(pr.has_seen_onboarding(), "mark_onboarding_seen() 이후에는 봤다고 기억한다")

	pr.reset()
	t.ok(pr.has_seen_onboarding(), "reset(R) 뒤에도 온보딩을 봤다는 사실은 남는다 (그래서 또 안 뜬다)")

	pr.next_stage()
	t.ok(pr.has_seen_onboarding(), "스테이지를 넘어가도 남는다")

	# **A fresh `Progress` starts unseen** — the flag is not a global, and a second instance (a second run
	#  net drives in the same process) must not inherit the first one's history.
	var fresh := Progress.new()
	t.ok(not fresh.has_seen_onboarding(), "새 Progress 객체는 온보딩을 안 본 상태로 시작한다")
