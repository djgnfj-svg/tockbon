extends RefCounted
## The boss entrance and its bar — `boss_bar_view.gd`, `monster_placement.gd`'s `trigger_tx` column,
## `world_step.spawn_monster`'s `entrance` argument, `boss_ai.ENTRANCE_IDLE_TICKS`, and `stage.gd`'s entrance
## clock and the two camera lines it folds into — `boss-entrance-and-hp-bar.md`, the whole Implementation plan.
##
## **Not `net_gate`** — that net is 24.3s of a ~28s round already and is `harness-manager`'s to shorten, not
## a place to add to (the plan's own Cost section).
##
## **Three subjects, and none of them alone is enough**:
##  · **A synthetic `MonsterPlacement`/`WorldStep`, no scene at all** — the trigger arithmetic and the
##    `entrance` flag, driven directly against `wake_scan`/`spawn_monster` with no terrain to build.
##  · **(a) an untreed real stage root** (`_wired_root`, copied from `net_gate.gd`'s own idiom, not shared —
##    "each net runs in its own process" is this repo's policy against a shared base class) — the real
##    materialise, the real `_on_ticked()` handoff, `visible` read after a hand-called `_process`.
##    **Never trees this root** — the same reason `net_gate._wired_root()` refuses to: this file's own
##    exact-frame checks (`_the_entrance_fires_exactly_once...`) would break under uncounted engine frames.
##  · **(b) a bare `BossBarView` treed under `t.root`, and once a full stage root treed under it too** — the
##    first proves something was actually painted (`_paint_*` hooks, the `notice_rect()` precedent); the
##    second is the one check (the zoom returning) that genuinely needs a real `Viewport`
##    (`get_viewport_rect()` barks "Condition !is_inside_tree()" on an untreed node — measured directly,
##    not assumed, the same way `net_render.gd`'s own camera check already trees its root for exactly this).
##
## **Ship only (b) and the bar is beautiful and never appears; ship only (a) and it appears at zero size.**

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const Stage1Monsters := preload("res://src/stage/stage1_monsters.gd")
const MonsterPlacement := preload("res://src/actor/monster_placement.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")
const WorldStep := preload("res://src/actor/world_step.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const Character := preload("res://src/actor/character.gd")
const Monster := preload("res://src/actor/monster.gd")
const BossAi := preload("res://src/actor/boss_ai.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const BossBarView := preload("res://src/view/boss_bar_view.gd")

const STAGE_SCENE := "res://src/stage/stage.tscn"
const DT := 1.0 / 60.0
const SYN_FLOOR_CY := 200


func run(t) -> void:
	# ── Stage A — the trigger column and the entrance flag, no scene at all ──
	_a_boss_row_wakes_on_its_trigger_not_on_materialize_px(t)
	_the_trigger_fires_once_even_walking_back_and_forth(t)
	_a_row_with_no_trigger_tx_is_unchanged(t)
	_woke_boss_id_reports_the_boss_row_and_clears_next_scan(t)
	_woke_boss_id_is_zero_for_a_trash_row(t)
	_entrance_true_gives_a_boss_its_idle_window_but_not_a_trash_mob(t)

	# ── Stage B — the bar's own pure statics and paint hooks ──
	_frame_rect_and_bar_rect_sit_inside_the_panel_with_the_inset(t)
	_fill_frac_drains_all_the_way(t)
	_fade_alpha_ramps_then_holds_at_one(t)
	_every_boss_kind_has_a_non_empty_title_row(t)
	await _the_painted_hooks_receive_exactly_what_the_pure_functions_return(t)
	await _invert_the_capturing_view_a_never_called_paint_fill_must_read_zero(t)

	# ── Stage C — the real stage: visible, the entrance count, the zoom, the roar window, the rooster ──
	_visible_is_false_before_the_trigger_true_after_and_false_once_dead(t)
	_the_entrance_fires_exactly_once_even_walking_back_over_it(t)
	await _the_zoom_comes_back_and_is_a_multiplier_on_the_debug_step(t)
	_the_roar_lands_strictly_inside_the_entrance_hold(t)
	_every_beat_constant_has_a_floor(t)
	_the_rooster_runs_the_same_path_as_the_bull(t)


# ══════════════════════════════════════════════════════════════════
#  Stage A — the trigger column (`monster_placement.gd`) and the entrance flag (`world_step.gd`)
# ══════════════════════════════════════════════════════════════════

func _flat_grid() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, SYN_FLOOR_CY - 4, 4000, SYN_FLOOR_CY, Mat.STONE))
	return g


## Acceptance 6 — **it does not fire early.** The trigger tile sits well inside `MATERIALIZE_PX` of the
## row's own seat (asserted as a premise below), so a row still reading distance would already be live at
## `trigger_px - 1`. *Inversion: delete the `_trigger_tx[i] >= 0` branch in `wake_scan()` and the second
## assert goes red* — the row would already be primed/spawned from the first `wake_scan` call.
func _a_boss_row_wakes_on_its_trigger_not_on_materialize_px(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	var tx := 100
	var trigger_tx := 105
	mp.set_rows([{"tx": tx, "kind": MonsterDefs.KIND_BULL, "trigger_tx": trigger_tx}], SYN_FLOOR_CY)
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 1
	var trigger_px := trigger_tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	var half_w := float(MonsterDefs.w_px(MonsterDefs.KIND_BULL)) * 0.5
	var row_center_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX + int(half_w)
	t.ok(absf(float(trigger_px - 1) - float(row_center_x)) < MonsterPlacement.MATERIALIZE_PX,
		"전제 — 트리거 한 칸 앞은 구현거리(720px) 훨씬 안쪽이다 (거리 %.0f)"
			% absf(float(trigger_px - 1) - float(row_center_x)))

	mp.wake_scan(g, trigger_px - 1, spy)
	t.ok(not mp.is_live(0),
		"구현거리 안인데도 트리거를 한 픽셀 못 미치면 안 깬다 (트리거 분기가 지워지면 여기가 빨개진다)")

	mp.wake_scan(g, trigger_px, spy)
	t.ok(mp.is_live(0), "정확히 트리거에 닿으면 깬다")


## Acceptance 5 — walking back over the trigger cannot fire it twice, driven at the `MonsterPlacement` level.
func _the_trigger_fires_once_even_walking_back_and_forth(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	var tx := 100
	var trigger_tx := 105
	mp.set_rows([{"tx": tx, "kind": MonsterDefs.KIND_BULL, "trigger_tx": trigger_tx}], SYN_FLOOR_CY)
	var made := [0]
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		made[0] += 1
		return made[0]
	var trigger_px := trigger_tx * Tuning.TILE_CELLS * Tuning.CELL_PX

	mp.wake_scan(g, trigger_px + 50, spy)
	t.eq(made[0], 1, "동쪽으로 넘으면 한 번 깬다")
	mp.wake_scan(g, trigger_px - 500, spy)
	t.eq(made[0], 1, "다시 서쪽으로 돌아가도 늘지 않는다")
	mp.wake_scan(g, trigger_px + 50, spy)
	t.eq(made[0], 1, "다시 동쪽으로 가도 늘지 않는다 (한 번 살아있으면 그 뒤론 건너뛴다)")


## Acceptance 13 — a row with no `trigger_tx` column keeps `MATERIALIZE_PX` byte-for-byte.
func _a_row_with_no_trigger_tx_is_unchanged(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	var tx := 100
	mp.set_rows([{"tx": tx, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 1
	var half_w := float(MonsterDefs.w_px(MonsterDefs.KIND_PIG)) * 0.5
	var center_x := tx * Tuning.TILE_CELLS * Tuning.CELL_PX + int(half_w)

	mp.wake_scan(g, center_x + int(MonsterPlacement.MATERIALIZE_PX) + 10, spy)
	t.ok(not mp.is_live(0), "구현거리 밖에서는 여전히 안 깬다 (전제)")
	mp.wake_scan(g, center_x + int(MonsterPlacement.MATERIALIZE_PX) - 10, spy)
	t.ok(mp.is_live(0), "trigger_tx 없는 행은 여전히 720px 구현거리를 그대로 쓴다")


func _woke_boss_id_reports_the_boss_row_and_clears_next_scan(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	var tx := 100
	var trigger_tx := 100
	mp.set_rows([{"tx": tx, "kind": MonsterDefs.KIND_BULL, "trigger_tx": trigger_tx}], SYN_FLOOR_CY)
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 42
	var trigger_px := trigger_tx * Tuning.TILE_CELLS * Tuning.CELL_PX
	t.eq(mp.woke_boss_id(), 0, "전제 — 아직 아무도 안 깼다")
	mp.wake_scan(g, trigger_px, spy)
	t.eq(mp.woke_boss_id(), 42, "보스 행이 깨는 바로 그 스캔에서 그 몬스터의 id를 보고한다")
	mp.wake_scan(g, trigger_px, spy)
	t.eq(mp.woke_boss_id(), 0, "다음 스캔엔 지워진다 (한 스캔만 산다)")


func _woke_boss_id_is_zero_for_a_trash_row(t) -> void:
	var g := _flat_grid()
	var mp := MonsterPlacement.new()
	mp.set_rows([{"tx": 100, "kind": MonsterDefs.KIND_PIG}], SYN_FLOOR_CY)
	var spy := func(_kind: int, _px: int, _py: int, _entrance: bool) -> int:
		return 5
	var half_w := float(MonsterDefs.w_px(MonsterDefs.KIND_PIG)) * 0.5
	var center_x := 100 * Tuning.TILE_CELLS * Tuning.CELL_PX + int(half_w)
	mp.wake_scan(g, center_x, spy)
	t.ok(mp.is_live(0), "전제 — 잡몹 행이 깼다")
	t.eq(mp.woke_boss_id(), 0, "잡몹이 깨어도 보스 알림은 0이다")


## `spawn_monster`'s 4th argument (`world_step.gd`) — **the default is the whole point** (that function's
## own comment): a bull made with the default (`entrance` unspecified) must not get the idle window, or
## every existing boss-pattern net's first `WINDUP` shifts.
func _entrance_true_gives_a_boss_its_idle_window_but_not_a_trash_mob(t) -> void:
	var g := _flat_grid()
	var ch := Character.new()
	ch.place(0, SYN_FLOOR_CY * Tuning.CELL_PX - Character.H_PX)
	var world := WorldStep.new(g, SpellSim.new(), ch)

	var bull_id := world.spawn_monster(MonsterDefs.KIND_BULL, 2000,
		SYN_FLOOR_CY * Tuning.CELL_PX - MonsterDefs.h_px(MonsterDefs.KIND_BULL), true)
	t.ok(bull_id > 0, "전제 — 황소가 만들어졌다")
	t.eq(world.monster_by_id(bull_id).pattern_left, BossAi.ENTRANCE_IDLE_TICKS,
		"entrance=true로 만든 보스는 곧바로 등장용 대기 시간을 받는다")

	var pig_id := world.spawn_monster(MonsterDefs.KIND_PIG, 2200,
		SYN_FLOOR_CY * Tuning.CELL_PX - MonsterDefs.h_px(MonsterDefs.KIND_PIG), true)
	t.ok(pig_id > 0, "전제 — 돼지도 만들어졌다")
	t.eq(world.monster_by_id(pig_id).pattern_left, 0,
		"entrance=true라도 잡몹은 대기 시간을 받지 않는다 (has_pattern이 없다)")

	var bull_id2 := world.spawn_monster(MonsterDefs.KIND_BULL, 2400,
		SYN_FLOOR_CY * Tuning.CELL_PX - MonsterDefs.h_px(MonsterDefs.KIND_BULL))
	t.ok(bull_id2 > 0, "전제 — 황소를 entrance 없이도(기본값 false) 만들 수 있다")
	t.eq(world.monster_by_id(bull_id2).pattern_left, 0,
		"entrance 기본값(false)으로 만들면 대기 시간이 없다 — 기존 보스 네트들이 이 값에 기댄다")


# ══════════════════════════════════════════════════════════════════
#  Stage B — the bar's own pure statics and paint hooks (`boss_bar_view.gd`)
# ══════════════════════════════════════════════════════════════════

func _frame_rect_and_bar_rect_sit_inside_the_panel_with_the_inset(t) -> void:
	var panel := Fx.BOSS_BAR_RECT.size
	var fr := BossBarView.frame_rect(panel)
	t.eq(fr.size.y, Fx.BOSS_BAR_FRAME_H_PX, "프레임 높이가 딱 hp_frame.png 높이다")
	t.eq(fr.end.y, panel.y, "프레임의 아랫변이 패널의 아랫변과 같다 (바닥에 붙는다)")
	t.eq(fr.size.x, panel.x, "프레임 너비가 패널 전체 너비다")

	var br := BossBarView.bar_rect(panel)
	var i := Fx.BOSS_BAR_INSET_PX
	t.eq(br, Rect2(fr.position.x + i, fr.position.y + i, fr.size.x - i * 2.0, fr.size.y - i * 2.0),
		"채우기 사각형이 프레임 사각형을 정확히 inset만큼 파고든다")


## Acceptance 4 — the fill drains, three probes, not one.
func _fill_frac_drains_all_the_way(t) -> void:
	var kind := MonsterDefs.KIND_BULL
	var max_hp := MonsterDefs.max_hp(kind)
	t.eq(BossBarView.fill_frac(max_hp, kind), 1.0, "풀피면 1.0이다")
	t.eq(BossBarView.fill_frac(max_hp / 2, kind), 0.5, "절반이면 0.5다")
	t.eq(BossBarView.fill_frac(0, kind), 0.0, "0이면 0.0이다")
	t.eq(BossBarView.fill_frac(-5, kind), 0.0, "음수여도 0.0으로 clamp된다 (방어)")


func _fade_alpha_ramps_then_holds_at_one(t) -> void:
	t.eq(BossBarView.fade_alpha(-1), 0.0, "등장 전(-1)엔 완전히 투명하다")
	t.eq(BossBarView.fade_alpha(0), 0.0, "0프레임째도 투명하다")
	t.eq(BossBarView.fade_alpha(Fx.BOSS_BAR_FADE_FRAMES), 1.0, "떠오르기가 끝나면 완전히 불투명하다")
	var mid := BossBarView.fade_alpha(Fx.BOSS_BAR_FADE_FRAMES / 2)
	t.ok(mid > 0.0 and mid < 1.0, "중간엔 중간값이다 (한 프레임에 건너뛰지 않는다)")
	t.eq(BossBarView.fade_alpha(Fx.BOSS_BAR_FADE_FRAMES * 10), 1.0, "한참 지나도 1.0에 머문다 (넘어가지 않는다)")


## Acceptance 12 — a data check, not a source-text scan. Catches a third boss shipping with no title row.
## **The rooster's row is a placeholder now, not blank** (session correction) — the in-game kind name
## ("거대 수탉") stands in for a real title until the user decides one (`fx_tuning.BOSS_TITLES`'s own comment
## records the unconfirmed "문을 지키는 석상" the user has floated). This only pins that every boss kind has
## *a* non-empty row — it does not (and must not) pin the rooster's exact string, which is expected to change.
func _every_boss_kind_has_a_non_empty_title_row(t) -> void:
	for kind: int in BossAi.MOVES.keys():
		t.ok(Fx.BOSS_TITLES.has(kind),
			"kind %d가 BOSS_TITLES에 행이 있다 (없으면 세 번째 보스가 이름 없이 나갈 자리)" % kind)
		t.ok(not String(Fx.BOSS_TITLES[kind]).is_empty(),
			"kind %d의 이름이 비어 있지 않다 (%s)" % [kind, Fx.BOSS_TITLES[kind]])
	t.eq(Fx.BOSS_TITLES[MonsterDefs.KIND_BULL], "불의 룬을 삼킨 소", "황소 이름은 사용자의 말 그대로다")


## **A `BossBarView` that catches its own paint hooks** — the `net_gate._CapturingGateView` technique,
## applied to this class. `super()` still runs, so the real drawing is not replaced by the measurement.
class _CapturingBossBarView extends BossBarView:
	var frame_calls := 0
	var last_frame_tex: Texture2D = null
	var last_frame_rect := Rect2()
	var fill_calls := 0
	var last_fill_rect := Rect2()
	var last_fill_frac := -1.0
	var name_calls := 0
	var last_name_pos := Vector2()
	var last_name_text := ""
	var last_name_size := 0
	var last_name_color := Color()

	func _paint_frame(tex: Texture2D, r: Rect2, tint: Color) -> void:
		frame_calls += 1
		last_frame_tex = tex
		last_frame_rect = r
		super(tex, r, tint)

	func _paint_fill(r: Rect2, frac: float) -> void:
		fill_calls += 1
		last_fill_rect = r
		last_fill_frac = frac
		super(r, frac)

	func _paint_name(font: Font, pos: Vector2, text: String, name_size: int, color: Color) -> void:
		name_calls += 1
		last_name_pos = pos
		last_name_text = text
		last_name_size = name_size
		last_name_color = color
		super(font, pos, text, name_size, color)


## **"`_draw()` ran" is not "anything was drawn"** (CLAUDE.md) — this asserts the exact arguments
## `_draw()` hands each hook, and that they equal what the pure functions above return. `notice_rect()`'s own
## precedent is why the pure-function checks above are not treated as covering this: a correct pure function
## and a `_draw()` that hands the painter a bare `Rect2()` are two different bugs, and only this one catches
## the second.
func _the_painted_hooks_receive_exactly_what_the_pure_functions_return(t) -> void:
	var view := _CapturingBossBarView.new()
	t.root.add_child(view)
	await t.pump_frames(1)
	var m := Monster.new(1, MonsterDefs.KIND_BULL, 0, 0)
	view.show_boss(m)
	# **Fully faded in on purpose** — a fade in progress would still leave `modulate.a` short of 1.0, but the
	#  colour *arguments* handed to each hook are not baked with the fade (`boss_bar_view.gd`'s own header:
	#  the whole node fades as one unit through `modulate`), so this is only to keep `visible` derivation
	#  unambiguous, not because the fade would otherwise corrupt the captured colour.
	view.set_entrance_frames(Fx.BOSS_BAR_FADE_FRAMES)
	await t.pump_frames(3)

	t.ok(view.frame_calls > 0, "_paint_frame이 실제로 불렸다 (전제)")
	t.eq(view.last_frame_rect, BossBarView.frame_rect(view.size), "프레임 rect가 frame_rect()와 같다")
	t.ok(view.last_frame_tex != null, "그리고 실제 텍스처를 넘긴다 (null이 아니다)")

	t.ok(view.fill_calls > 0, "_paint_fill이 실제로 불렸다 (전제)")
	t.eq(view.last_fill_rect, BossBarView.bar_rect(view.size), "채우기 rect가 bar_rect()와 같다")
	t.eq(view.last_fill_frac, BossBarView.fill_frac(m.hp, m.kind), "채움 비율이 fill_frac()과 같다")

	t.ok(view.name_calls > 0, "_paint_name이 실제로 불렸다 (전제)")
	t.eq(view.last_name_text, BossBarView.title_of(m.kind), "이름 문자열이 title_of(kind)와 같다")
	t.eq(view.last_name_size, Fx.BOSS_NAME_SIZE, "글자 크기가 BOSS_NAME_SIZE다")
	t.eq(view.last_name_color, Fx.BOSS_NAME_COLOR, "색이 BOSS_NAME_COLOR다")
	var panel := Rect2(Vector2.ZERO, view.size)
	t.ok(panel.has_point(view.last_name_pos), "이름 위치가 노드 자기 사각형 안이다")
	t.ok(view.last_name_pos.y < BossBarView.frame_rect(view.size).position.y,
		"그리고 프레임보다 위쪽이다 (이름 밴드 안)")

	t.root.remove_child(view)
	view.queue_free()


## **A `_draw()` that deliberately never calls `_paint_fill`** — the mutation the check above exists to
## catch. If this stayed green (`fill_calls` nonzero), the positive check above would be proven not to
## measure what it claims — CLAUDE.md's "invert every new check", applied to this file's own instrument.
class _NeverPaintsFillBossBarView extends BossBarView:
	var fill_calls := 0
	func _draw() -> void:
		if _boss == null:
			return
		_paint_frame(_frame_tex, frame_rect(size), Fx.HP_FRAME_TINT)
		# `_paint_fill` deliberately never called.
		var font: Font = ThemeDB.fallback_font
		if font != null:
			_paint_name(font, name_baseline(size, font), title_of(_boss.kind),
				Fx.BOSS_NAME_SIZE, Fx.BOSS_NAME_COLOR)
	func _paint_fill(r: Rect2, frac: float) -> void:
		fill_calls += 1
		super(r, frac)


func _invert_the_capturing_view_a_never_called_paint_fill_must_read_zero(t) -> void:
	var view := _NeverPaintsFillBossBarView.new()
	t.root.add_child(view)
	var m := Monster.new(1, MonsterDefs.KIND_BULL, 0, 0)
	view.show_boss(m)
	await t.pump_frames(3)
	t.eq(view.fill_calls, 0,
		"_paint_fill을 안 부르는 가짜 _draw()에서는 실제로 0번이다 (이 계측이 차이를 잡아낸다는 증거)")
	t.root.remove_child(view)
	view.queue_free()


# ══════════════════════════════════════════════════════════════════
#  Stage C — the real stage: `_on_ticked()`'s handoff, `visible`, the camera, the roar window
# ══════════════════════════════════════════════════════════════════

func _row_of(kind: int) -> Dictionary:
	for row: Dictionary in Stage1Monsters.ROWS:
		if int(row["kind"]) == kind:
			return row
	return {}


## **A standing y derived from `resolve()`, not a literal tile guess** — the bull's own row already tells us
## exactly which floor it stands on; the character only needs to share it, not re-derive it by hand.
func _stand_y_for(g: CellGrid, row: Dictionary) -> int:
	var res := MonsterPlacement.resolve(g, int(row["tx"]), int(row["kind"]), Stage1Monsters.FLOOR_CY)
	return int(res["py"]) + MonsterDefs.h_px(int(row["kind"])) - Character.H_PX


## **The same wiring `net_gate._wired_root` does, copied rather than shared** — each net runs in its own
## process, so there is no shared base class (`net_gate.gd`'s own header states the policy).
func _wired_root(t) -> Node:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return null
	var root := scene.instantiate()
	for pair: Array in [["_hud", "HUD/Stats"], ["_hp_view", "HUD/HpBar"],
			["_levelup_label", "HUD/LevelUp"],
			["_spell_view", "SpellView"], ["_blast_fx", "BlastFx"],
			["_circle_window", "HUD/CircleWindow"], ["_pick_window", "HUD/ThreePickWindow"],
			["_camera", "Camera2D"], ["_monster_view", "MonsterView"],
			["_renderer", "CellRenderer"], ["_town_view", "TownView"], ["_input", "StageInput"],
			["_sky", "SkyBackground"],
			["_research_window", "HUD/ResearchWindow"],
			["_gate_view", "GateView"],
			# **`_boss_bar`** (`boss-entrance-and-hp-bar.md` Stage C). Left out, every check below dies on a
			#  null mid-call and disappears rather than fails — `net_gate.gd`'s own comment names this exact
			#  risk for `_gate_view`.
			["_boss_bar", "HUD/BossBar"],
			# **`_onboard_view`** (`onboarding-and-palette-tabs.md` Stage 7) — `_physics_process()` reaches
			#  `_tick_onboard()` unconditionally, which writes `_onboard_view.visible` every frame. The same
			#  sentence as `_boss_bar` right above, from the other feature that landed the same day: an
			#  unwired null here does not fail a check, it barks on **every** physics frame this file drives,
			#  and the wrapper counts stderr as failure while the count stays green.
			["_onboard_view", "HUD/OnboardView"],
			# **`_rune_grant_view`** (the fire-rune-obtained banner) — `_take_boss_reward()` calls
			#  `.trigger()` on it unconditionally once the bull is confirmed dead. The same sentence as
			#  `_boss_bar`/`_onboard_view` above: an unwired null here does not fail a check, it crashes the
			#  reward path itself the first time this file's own boss-death drive reaches it.
			["_rune_grant_view", "HUD/RuneGrantView"],
			["_settlement", "HUD/SettlementWindow"],
			# **`_char_view`** (the hit-flash/shake feature) — `reset_stage()` (via `_rebuild()`) now calls
			#  `_char_view.clear()` unconditionally. The same sentence as `_boss_bar`/`_onboard_view` above:
			#  an unwired null here crashes `reset_stage()` itself, before this file measures anything.
			["_char_view", "CharacterView"]]:
		var n := root.get_node_or_null(NodePath(pair[1]))
		t.ok(n != null, "씬에 %s 가 있다 (전제)" % pair[1])
		if n == null:
			root.free()
			return null
		root.set(pair[0], n)
	root.get_node("CellRenderer").call("setup", root.get("_grid"))
	root.get_node("TownView").call("setup", root.get("_char"))
	root.get_node("SkyBackground").call("setup", root.get_node("Camera2D"))
	var pr0: Variant = (root.get("_world") as Object).call("progress")
	root.get_node("HUD/ResearchWindow").call("setup", pr0)
	root.get_node("GateView").call("setup", pr0)
	root.call("reset_stage")
	return root


## Acceptance 3 — `visible` read directly, false before the trigger, true after, false again once `hp <= 0`.
## **In (a), the net must drive the trigger, never hand-set `_boss_bar._boss`** — placing the character east
## of `trigger_tx` and pumping ticks is what exercises `_on_ticked()`'s own handoff line; hand-setting the
## field would hide it (`net_gate.gd`'s own warning, verbatim, for the same shape of hole).
func _visible_is_false_before_the_trigger_true_after_and_false_once_dead(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var boss_bar: Variant = root.get("_boss_bar")
	boss_bar.call("_process", 0.0)
	t.ok(not bool(boss_bar.visible), "트리거 전엔 바가 안 보인다")

	var bull_row := _row_of(MonsterDefs.KIND_BULL)
	t.ok(not bull_row.is_empty(), "전제 — 표에서 황소 행을 찾았다")
	var g: Variant = root.get("_grid")
	var stand_y := _stand_y_for(g, bull_row)
	var trigger_px := int(bull_row["trigger_tx"]) * Tuning.TILE_CELLS * Tuning.CELL_PX

	var ch: Variant = root.get("_char")
	ch.place(trigger_px, stand_y)
	# **`TICK_DIVIDER * 2`, never one** — `wake_scan` is on the tick, and one physics frame crosses a tick
	#  boundary at most one time in three (CLAUDE.md, the `net_gate.gd`'s "pump well past one" rule this file's header repeats).
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	boss_bar.call("_process", 0.0)
	t.ok(bool(boss_bar.visible), "트리거를 넘으면 바가 보인다")

	var boss: Variant = root.get("_boss")
	t.ok(boss != null, "전제 — _boss 참조가 실제로 채워졌다 (_on_ticked()의 핸드오프)")
	if boss != null:
		boss.hp = 0
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	boss_bar.call("_process", 0.0)
	t.ok(not bool(boss_bar.visible), "죽으면 다시 안 보인다")
	root.free()


## Acceptance 5, through the real stage. Place east, pump; place west, pump; place east, pump — the count
## has not moved past the first wake.
func _the_entrance_fires_exactly_once_even_walking_back_over_it(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var bull_row := _row_of(MonsterDefs.KIND_BULL)
	var g: Variant = root.get("_grid")
	var stand_y := _stand_y_for(g, bull_row)
	var trigger_px := int(bull_row["trigger_tx"]) * Tuning.TILE_CELLS * Tuning.CELL_PX
	var ch: Variant = root.get("_char")
	var world: Variant = root.get("_world")

	ch.place(trigger_px + 50, stand_y)
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	var count_after_east: int = world.monster_count()
	t.ok(count_after_east > 0, "동쪽을 넘으면 황소가 깬다 (전제)")

	# **Only 300px west, staying inside room ① (`x130-159`)** — the trigger check that ran before this one
	#  learned the hard way that a farther retreat (2000px) lands back among the pre-① clumps and wakes
	#  unrelated pig/hen rows, which is a defect in the test's own placement, not in production code.
	ch.place(trigger_px - 300, stand_y)
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	t.eq(world.monster_count(), count_after_east, "다시 서쪽으로 가도 숫자가 안 늘어난다")

	ch.place(trigger_px + 50, stand_y)
	for _i in Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	t.eq(world.monster_count(), count_after_east, "다시 동쪽으로 가도 여전히 안 늘어난다 (한 번뿐이다)")
	root.free()


## Acceptance 7/8 — **needs a real `Viewport`**, so unlike every other check in this file it trees the whole
## stage (`net_render.gd`'s own precedent for exactly this — `_the_camera_sits_on_whole_screen_pixels`).
## Measured directly: calling `_process()` on the untreed `_wired_root()` barks
## `Condition "!is_inside_tree()" is true` from `get_viewport_rect()` and returns an empty rect — this check
## cannot live on subject (a).
func _the_zoom_comes_back_and_is_a_multiplier_on_the_debug_step(t) -> void:
	var scene: PackedScene = load(STAGE_SCENE)
	t.ok(scene != null and scene.can_instantiate(), "무대 씬을 세웠다 (전제)")
	if scene == null or not scene.can_instantiate():
		return
	var root := scene.instantiate()
	t.root.add_child(root)
	# **One settle-pump for `_ready()`, then hand-drive every frame afterward** — `net_render.gd`'s own
	#  precedent for a treed root. **Measured, not assumed**: pumping `process_frame` further and hoping
	#  enough real physics ticks rode along read `_camera.zoom` at `(0.8, 0.8)` — still mid-hold — because
	#  headless has no reason to run physics 1:1 with render frames. Hand-calling `_physics_process` a known
	#  number of times, then `_process` once, is exact regardless of the engine's own frame pacing.
	await t.pump_frames(2)
	root.call("_leave_town")

	# **Step the debug zoom off its default** — acceptance 8: the entrance's zoom is a *multiplier*, not a
	#  set value, so this is the case a bare `_camera.zoom = Vector2(1,1)` return would fail.
	root.call("_step_zoom", -1)
	var zoom_step: int = int(root.get("_zoom_step"))
	t.ok(zoom_step != 0, "전제 — 디버그 줌이 기본값에서 벗어났다")

	var bull_row := _row_of(MonsterDefs.KIND_BULL)
	var g: Variant = root.get("_grid")
	var stand_y := _stand_y_for(g, bull_row)
	var trigger_px := int(bull_row["trigger_tx"]) * Tuning.TILE_CELLS * Tuning.CELL_PX
	var ch: Variant = root.get("_char")
	ch.place(trigger_px + 50, stand_y)

	for _i in Fx.boss_entrance_total_frames() + Tuning.TICK_DIVIDER * 2:
		root.call("_physics_process", 1.0 / 60.0)
	root.call("_process", 0.0)
	# **`Fx.PLAY_ZOOM_MULT` folds in here too** (user request, 「좀 더 확대」) — `stage.gd`'s one zoom line now
	#  multiplies the debug step by it before `entrance_zoom()`, so "back to identity" means the debug step
	#  times that constant, not the bare step. `Stage.ZOOM_STEPS[zoom_step]` alone would be exactly the value
	#  it was before that constant existed — this line has to track the same formula `stage.gd._process` does.
	var expect_zoom: float = Stage.ZOOM_STEPS[zoom_step] * Fx.PLAY_ZOOM_MULT
	var cam: Camera2D = root.get_node("Camera2D")
	t.eq(cam.zoom, Vector2(expect_zoom, expect_zoom),
		"등장이 끝나면 줌이 선택된 디버그 단계(%.3fx)로 정확히 돌아온다 — 1.0이 아니다" % expect_zoom)

	root.queue_free()


## Acceptance 10 — the cross-clock constraint, asserted as the inequality itself, not trusted by inspection.
## *Inversion: any of the four constants drifting out of alignment (a longer `ENTRANCE_IDLE_TICKS`, a
## shorter `BOSS_ENTRANCE_HOLD_FRAMES`, ...) turns this red — the symptom on screen would be silent
## (CLAUDE.md's "a thing that never happens"), which is exactly why it needs a value, not an eye.*
func _the_roar_lands_strictly_inside_the_entrance_hold(t) -> void:
	var roar_frame := BossAi.ENTRANCE_IDLE_TICKS * Tuning.TICK_DIVIDER
	var lo := Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES
	var hi := Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES + Fx.BOSS_ENTRANCE_HOLD_FRAMES
	t.ok(roar_frame > lo and roar_frame < hi,
		("포효 프레임(%d)이 카메라가 보스를 붙잡고 있는 구간(%d~%d) 안에 정확히 있다 — " +
			"벗어나면 카메라가 이미 돌아간 뒤에 포효한다") % [roar_frame, lo, hi])


## Acceptance 9 — every beat constant gets a floor probe. `GATE_ARCH_FADE_FRAMES` carried a floor on one end
## only and 2-11 were green while its own fade collapsed to a pop (CLAUDE.md) — this is the same floor,
## applied to all four new lengths plus the entrance idle, so none of the five can quietly shrink to a pop.
func _every_beat_constant_has_a_floor(t) -> void:
	t.ok(Fx.BOSS_BAR_FADE_FRAMES >= 12,
		"바 떠오르기가 최소 12프레임(0.2초)은 된다 (얻은 값 %d)" % Fx.BOSS_BAR_FADE_FRAMES)
	t.ok(Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES >= 12,
		"줌인 길이가 최소 12프레임이다 (얻은 값 %d)" % Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES)
	t.ok(Fx.BOSS_ENTRANCE_HOLD_FRAMES >= 12,
		"홀드 길이가 최소 12프레임이다 (얻은 값 %d)" % Fx.BOSS_ENTRANCE_HOLD_FRAMES)
	t.ok(Fx.BOSS_ENTRANCE_OUT_FRAMES >= 12,
		"줌아웃 길이가 최소 12프레임이다 (얻은 값 %d)" % Fx.BOSS_ENTRANCE_OUT_FRAMES)
	t.ok(BossAi.ENTRANCE_IDLE_TICKS >= 4,
		"등장 대기 틱이 최소 4틱은 된다 — 0이면 포효가 등장 즉시 터진다 (얻은 값 %d)" % BossAi.ENTRANCE_IDLE_TICKS)
	# **The ceiling** — `_the_roar_lands_strictly_inside_the_entrance_hold` above is the real one (any of
	#  the four constants drifting breaks it); this only pins that the idle window alone does not already
	#  overrun the hold, independent of that inequality.
	t.ok(BossAi.ENTRANCE_IDLE_TICKS * Tuning.TICK_DIVIDER < Fx.BOSS_ENTRANCE_ZOOM_IN_FRAMES + Fx.BOSS_ENTRANCE_HOLD_FRAMES,
		"등장 대기 틱을 프레임으로 바꾼 값이 줌인+홀드 구간의 천장 아래다")


## Acceptance 11 — **driven, not asserted by reading the table.** The rooster has no walk-out
## (`stage1_monsters.gd`'s own header: room ③'s trigger buys the bar/name/camera, not a walk-out), so this
## drives exactly the parts of the path that apply to it: `trigger_tx` fires the row, `_boss_bar` shows it,
## and the entrance clock starts the same way it does for the bull.
func _the_rooster_runs_the_same_path_as_the_bull(t) -> void:
	var root := _wired_root(t)
	if root == null:
		return
	root.call("_leave_town")
	var rooster_row := _row_of(MonsterDefs.KIND_ROOSTER)
	t.ok(not rooster_row.is_empty(), "전제 — 표에서 수탉 행을 찾았다")
	var g: Variant = root.get("_grid")
	var stand_y := _stand_y_for(g, rooster_row)
	var trigger_px := int(rooster_row["trigger_tx"]) * Tuning.TILE_CELLS * Tuning.CELL_PX

	var boss_bar: Variant = root.get("_boss_bar")
	boss_bar.call("_process", 0.0)
	t.ok(not bool(boss_bar.visible), "수탉 방에 닿기 전엔 바가 안 보인다 (전제)")

	var ch: Variant = root.get("_char")
	ch.place(trigger_px, stand_y)
	# **Exactly `TICK_DIVIDER` (3), not `* 2`.** `_wired_root()` never trees the node, so nothing has ever
	#  advanced `_phase` before this loop — it starts at exactly 0, and 3 consecutive physics frames from a
	#  phase of 0 always cross exactly one tick boundary, never two. That precision matters *here* and only
	#  here: the freshly-spawned rooster is not in `_monsters` yet when `on_tick()`'s own loop runs each
	#  tick (`wake_scan` adds it afterward, `world_step.frame()`'s own order), so its `pattern_left` is
	#  untouched by `on_tick` on the tick it is born — one tick further and a second `on_tick` would already
	#  have shaved it to 13, which is exactly the failure this comment exists to explain.
	for _i in Tuning.TICK_DIVIDER:
		root.call("_physics_process", 1.0 / 60.0)
	boss_bar.call("_process", 0.0)
	t.ok(bool(boss_bar.visible), "수탉의 트리거를 넘으면 바가 보인다 (황소와 같은 경로)")

	var world: Variant = root.get("_world")
	var rooster_id := 0
	for i in world.monster_count():
		if world.monster_at(i).kind == MonsterDefs.KIND_ROOSTER:
			rooster_id = world.monster_at(i).id
	t.ok(rooster_id > 0, "전제 — 수탉이 실제로 구현됐다")
	if rooster_id > 0:
		t.eq(world.monster_by_id(rooster_id).pattern_left, BossAi.ENTRANCE_IDLE_TICKS,
			"수탉도 황소와 똑같이 entrance=true로 만들어져 등장 대기 시간을 받는다")

	t.ok(int(root.get("_entrance_frames")) >= 0, "등장 시계도 황소와 같은 필드에서 돈다")
	root.free()
