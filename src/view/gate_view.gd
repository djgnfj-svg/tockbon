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
	_paint(_tex, rect())


## **Split out of `_draw()` so a net can verify the arch actually gets painted, not merely that `_draw()` ran**
## (verify-read, H2). GDScript refuses to let a script override a *native* `CanvasItem` method like
## `draw_texture_rect` — that is a hard parse error here, not a warning, so a test subclass cannot intercept
## the native call directly. `_paint` is an ordinary script method instead, freely overridable: a test
## subclass overrides this one hook and catches exactly the texture and rect `_draw()` decided to use.
##
## **`false` for `tile`** — the same reason `town_view._draw` gives: this is an integer upscale of a
##  pixel-art sprite (`TOWN_FIXTURE_ZOOM` is an integer, `net_town` measures that), not a stretch.
func _paint(tex: Texture2D, r: Rect2) -> void:
	draw_texture_rect(tex, r, false)
