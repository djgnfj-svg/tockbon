extends Node2D
## The gate's arch on screen — stage 1's ending (`docs/design/gate-ending.md`,
## `docs/plans/3.done/gate-ending-to-game.md`, Stage C).
##
## **It touches the screen only.** Whether the gate is open at all is `Progress.boss_died()`; whether the
##  player is standing at it is `StageGate.at()` — this file reads the first to decide `visible` and draws
##  the second's own seat. The same split `town_view.gd` already holds against `Fixtures.at()`.
##
## **The picture is the town's own arch, read from the town's own table** (`Fx.TOWN_FIXTURES[KIND_GATE]`).
##  One png, one size, one place — a second picture and a second table would be two things to keep in sync
##  for one arch. `net_town` already measures that the file loads and the table matches the png; this reuse
##  costs zero new constants and cannot drift from it. The day the gate gets its own art (design TBD), one
##  row changes here and in the town's table both.

const StageGate := preload("res://src/actor/stage_gate.gd")
const Fixtures := preload("res://src/actor/fixtures.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const Progress := preload("res://src/actor/progress.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")

var _progress: Progress = null

## Loaded once, at construction — the same reason `town_view._sprites` is (`load()` is engine-cached, but
##  relying on that cache silently is relying on something no net can see).
var _tex: Texture2D = load(Fx.TOWN_FIXTURES[Fixtures.KIND_GATE]["path"])

## **Physics frames, both of them** (`stage-clear-sequence.md`, Beats 2 and 3). `_lit`
##  counts since the rooster's flag went true; `_take` counts since the player first stood in the band.
##
## **Neither may live on `_process()`.** That runs at the monitor refresh rate — 24 frames is 0.4s on a 60Hz
##  panel and 0.167s on a 144Hz one, so the same animation would run 2.4x fast on a better monitor with
##  nothing barking. `three_pick_window.tick_confirm()`'s own header records the same lesson for a screen
##  clock. `tick_gate()` is called from `stage._sync_settlement()`, which is physics.
var _lit := 0
var _take := 0


func setup(pr: Progress) -> void:
	_progress = pr
	queue_redraw()


## **`visible` derived every frame, never latched** — the same discipline `_sync_settlement()`'s own header
##  holds: hold a second flag here and the arch can go stale the instant `boss_died()` and this node's own
##  copy disagree. `net_gate` measures `visible` directly, not a helper — the settlement panel sat behind
##  5,576 green checks with `visible` never actually set, and this is the same trap.
func _process(_dt: float) -> void:
	visible = _progress != null and _progress.boss_died(MonsterDefs.KIND_ROOSTER)
	if visible:
		queue_redraw()


## **One call, both clocks** — called once per physics frame from `stage._sync_settlement()`, with the same
##  `at_gate` term that function already computes. Two call sites would be two clocks to keep in step.
##
## **`_take` latches once begun.** `MOVE_SPEED_PX` is 260 and the band is `REACH_PX * 2` = 96px, so a running
##  player crosses it in ~22 physics frames — a hold that resets when you leave is outrunnable, and then the
##  ending is a thing that never happens (CLAUDE.md's own named failure). Once one frame inside the band has
##  been counted, the count runs to completion wherever the player goes. It strands nothing: the only state it
##  can reach is *the panel opens*, and `reset_gate()` plus `Progress.reset()` both collapse it.
##
## **Increment first, then test** — `stage._sync_settlement()` reads `take_done()` after this call, so the
##  first frame inside the band counts as 1 and the panel opens on the `GATE_TAKE_FRAMES`-th frame.
func tick_gate(at_gate: bool) -> void:
	if _progress != null and _progress.boss_died(MonsterDefs.KIND_ROOSTER):
		_lit += 1
	if at_gate or _take > 0:
		_take += 1


## Called from `stage.reset_stage()`, beside `_settlement.close()`.
##
## **It zeroes both counters.** Clearing only `_take` leaves `_lit` past `GATE_ARCH_FADE_FRAMES`, and on the
##  second run the arch pops fully opaque in one frame — beat 2 silently gone, with every other check green.
func reset_gate() -> void:
	_lit = 0
	_take = 0
	queue_redraw()


func take_done() -> bool:
	return _take >= Fx.GATE_TAKE_FRAMES


func take_frames() -> int:
	return _take


func lit_frames() -> int:
	return _lit


## **The whole of beats 2 and 3 as one value, pure and static** — the same reason `rect()` is: a net measures
##  the colour without a scene, and `_draw()` has no second copy of the curve to drift from.
##
## Alpha ramps 0 -> 1 over `GATE_ARCH_FADE_FRAMES` (the arch arrives instead of popping), then the whole
## colour lerps toward `GATE_TAKE_TINT` over `GATE_TAKE_FRAMES` (the arch brightens as it takes you).
##
## **The `maxf` guards are against the constants, not the counters.** Both are tuning values a user may edit;
##  set to 0 the plain division is NaN, and a NaN colour reaches `draw_texture_rect` without an error anywhere.
static func tint(lit_frames_now: int, take_frames_now: int) -> Color:
	var a := clampf(float(lit_frames_now) / maxf(float(Fx.GATE_ARCH_FADE_FRAMES), 1.0), 0.0, 1.0)
	var u := clampf(float(take_frames_now) / maxf(float(Fx.GATE_TAKE_FRAMES), 1.0), 0.0, 1.0)
	return Color(1.0, 1.0, 1.0, a).lerp(Fx.GATE_TAKE_TINT, u)


## Where the arch is drawn. **Pure static, so a net can call it with no scene** — the same idiom
##  `town_view.fixture_rect` already holds. Centred on the seat, standing on the ground line — never
##  derived from `StageGate.at()`'s band, which is a feel value and not the art's own size.
static func rect() -> Rect2:
	var row: Dictionary = Fx.TOWN_FIXTURES[Fixtures.KIND_GATE]
	var w := float(row["w"]) * Fx.TOWN_FIXTURE_ZOOM
	var h := float(row["h"]) * Fx.TOWN_FIXTURE_ZOOM
	return Rect2(StageGate.seat_px() - w * 0.5, StageGate.floor_y_px() - h, w, h)


func _draw() -> void:
	if _tex == null:
		return
	_paint_arch(_tex, rect(), tint(_lit, _take))


## **Split out of `_draw()` so a net can verify the arch actually gets painted, not merely that `_draw()` ran**
## (verify-read, H2). GDScript refuses to let a script override a *native* `CanvasItem` method like
## `draw_texture_rect` — that is a hard parse error here, not a warning, so a test subclass cannot intercept
## the native call directly. `_paint` is an ordinary script method instead, freely overridable: a test
## subclass overrides this one hook and catches exactly the texture, rect **and modulate** `_draw()` decided
## to use — the modulate being the entire visible result of beats 2 and 3.
##
## **Named `_paint_arch`, not `_paint`.** `monster_view.gd:196` already owns `_paint` with a different
##  signature; two hooks sharing a name across a signature change is one rename away from a silent mismatch.
##
## **`false` for `tile`** — the same reason `town_view._draw` gives: this is an integer upscale of a
##  pixel-art sprite (`TOWN_FIXTURE_ZOOM` is an integer, `net_town` measures that), not a stretch.
func _paint_arch(tex: Texture2D, r: Rect2, arch_tint: Color) -> void:
	draw_texture_rect(tex, r, false, arch_tint)
