extends Node2D
## Projectile heads and trails. **It touches the screen only — it never changes the sim.**
##
## == **This file's contract is the exact opposite of `spell_sim.gd`'s** ==========
##  The sim is "integers only" and here float is **free**. It fits because the reasons are opposite —
##  cells are discrete so there is no in-between position, but **a projectile is a continuum, so in-between
##  positions actually exist.**
##  => Cell rendering is right to **not** interpolate, and this side is right to interpolate.
##  Drop the interpolation and, at a 20Hz sim, projectiles **teleport 40px per tick.**
##  Conversely, **the moment a value from here goes back into the sim, lockstep breaks.**
## ==================================================================
##
## **There are 0 nodes per projectile.** One `_draw()` draws all of them => the physics-callback `add_child`
##  trap and the `queue_free` + group trap are **both extinct.** Switch to nodes and both come back.

const SpellSim := preload("res://src/sim/spell_sim.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## Fixed-point cell coordinates -> screen px.
## The `1.0 *` is there to avoid integer division — drop it and 4/256 **becomes 0** and every projectile is
## drawn at the origin (no error is raised).
const FP_TO_PX: float = 1.0 * Tuning.CELL_PX / SpellSim.FP_ONE

var _sim: SpellSim = null

## Rune -> bolt head texture. **Read once in `_ready`** — call `load()` in `_draw()` and it digs the cache every
## frame, and when the path is wrong it **barks every frame** and the log becomes useless.
## **Do not fill in missing runes here.** Left empty, `_draw_head` below screams in magenta —
##  the same idiom as `ELEM_FX_MISSING`, and **better than quietly not drawing.**
var _bolt_tex: Dictionary = {}

## Where this frame is between two ticks (0 = previous tick, 1 = this tick). The shell pushes it in every frame.
## The clock belongs to the sim's owner — accumulate `delta` here and there are two clocks.
var _alpha := 0.0

## Projectile id -> past tick positions (screen px). **The key being the id and not the slot index is the point.**
##  Destruction is a swap-remove so slots shuffle every tick, and holding them by index makes
##  **somebody else's trail teleport** the moment a projectile dies — with not one error, only a strange screen.
var _trails: Dictionary = {}

## Did the previous `_draw()` actually draw anything. The latch described in the `set_render_alpha` comment below.
var _drew := false


func _ready() -> void:
	# Additive blending. The one line that makes it read as "something glowing" over a dark background.
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	# If it cannot be read it **barks on the spot.** Pass over it quietly and it only shows up on screen as
	#  magenta, and magenta cannot tell "not written in the table" from "the file is missing".
	for elem: int in Fx.BOLT_SHEETS:
		var path: String = Fx.BOLT_SHEETS[elem]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("SpellView: cannot read the bolt head image - %s" % path)
			continue
		_bolt_tex[elem] = tex


func setup(sim: SpellSim) -> void:
	_sim = sim
	_trails.clear()
	queue_redraw()


## The interpolated position between two ticks. The shell calls it every `_process`.
##
## **Using only `if active_count() > 0` is not enough — that is the seat that breaks silently.**
##  `CanvasItem` **keeps holding the last thing it drew.** Skip `queue_redraw` on the frame a projectile
##  disappeared and **the dead projectile stays pinned on screen forever** — with not one error.
##  => Hold "did the previous pass draw anything" as a latch, and **redraw that one time it becomes 0.**
##  **Headless cannot measure this in principle** (it does not draw). Without the latch it only shows up
##  in the real game.
func set_render_alpha(a: float) -> void:
	_alpha = clampf(a, 0.0, 1.0)
	if (_sim != null and _sim.active_count() > 0) or _drew:
		queue_redraw()


## Called **after the sim has run one tick.** Reverse the order and the trail is one tick stale.
func on_tick() -> void:
	if _sim == null:
		return
	var n := _sim.active_count()
	var ids := _sim.get_id()
	var px := _sim.get_px()
	var py := _sim.get_py()
	var gens := _sim.get_gen()
	var live: Dictionary = {}
	for i in n:
		var id := ids[i]
		live[id] = true
		# `PackedVector2Array` is a CoW value type — take it out, use it, and **it must be put back.**
		#  Without putting it back the append evaporates with no error.
		var hist: PackedVector2Array = _trails.get(id, PackedVector2Array())
		hist.append(Vector2(float(px[i]) * FP_TO_PX, float(py[i]) * FP_TO_PX))
		# Trail length **differs per generation** — a small bolt needs a short tail to read as "weak".
		var keep := Fx.trail_ticks(int(gens[i]))
		while hist.size() > keep:
			hist.remove_at(0)
		_trails[id] = hist
	# Not erasing dead projectiles' trails here makes the dictionary **grow forever.** There is no destruction
	#  notification, so comparing against "the set of living ids" is the only way.
	for id: int in _trails.keys():
		if not live.has(id):
			_trails.erase(id)


func clear() -> void:
	_trails.clear()
	queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  Queries — `_draw()` uses **only these functions**. So the value a net measures = the value actually drawn.
# ══════════════════════════════════════════════════════════════════

## The head position drawn on screen right now. `_alpha` 0 is the previous tick's seat, 1 is this tick's.
func head_px(i: int) -> Vector2:
	if not _live(i):
		return Vector2.ZERO
	var px := _sim.get_px()
	var py := _sim.get_py()
	var qx := _sim.get_prev_px()
	var qy := _sim.get_prev_py()
	return Vector2(
		lerpf(float(qx[i]), float(px[i]), _alpha) * FP_TO_PX,
		lerpf(float(qy[i]), float(py[i]), _alpha) * FP_TO_PX)


## Head to tail. **The trail's last record is this tick's arrival point and is deliberately excluded** —
##  the head has not arrived there yet, so including it makes the trail stick out ahead of the head.
func trail_points(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _live(i):
		return out
	out.append(head_px(i))
	var hist: PackedVector2Array = _trails.get(_sim.get_id()[i], PackedVector2Array())
	var k := hist.size() - 2
	while k >= 0:
		out.append(hist[k])
		k -= 1
	return out


## Number of trails being tracked. This is the seat where a net measures a **leak** — if dead projectiles
## linger, this does not go down.
func trail_count() -> int:
	return _trails.size()


# ══════════════════════════════════════════════════════════════════
#  Drawing
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _sim == null:
		_drew = false
		return
	var n := _sim.active_count()
	_drew = n > 0
	# Draw **all the trails first** and the heads afterwards. Drawing one projectile at a time lets a later
	#  projectile's trail cover an earlier projectile's head — additive blending makes it less obvious, but
	#  heads look washed out where they overlap.
	for i in n:
		_draw_trail(i)
	for i in n:
		_draw_head(i)


func _draw_trail(i: int) -> void:
	var pts := trail_points(i)
	if pts.size() < 2:
		return
	# **It is `glow` — `core` is the same brightness as the head sprite's core, so the tail beats the head**
	#  (the user: "the tail is so much brighter than the bolt that it is hard to see").
	#  The `fx_tuning.TRAIL_USES_GLOW` box holds that story and the way back.
	var col: Color = _elem(i)["glow" if Fx.TRAIL_USES_GLOW else "core"]
	# Trail thickness follows head size too — otherwise generation 1 becomes "a thin bolt with a thick tail".
	var w := Fx.TRAIL_PX * Fx.bolt_px(_gen(i)) / Fx.bolt_px(0)
	var segs := pts.size() - 1
	for k in segs:
		# 1.0 at the head end -> 0.0 at the tail end. Thickness and alpha must shrink together to read as
		#  "a tail being sucked in".
		var f := 1.0 - float(k) / float(segs)
		draw_line(
			pts[k], pts[k + 1],
			# The head end is **not 1.0** — with additive blending, 1.0 burns that spot to white.
			Color(col.r, col.g, col.b, lerpf(Fx.TRAIL_TAIL_A, Fx.TRAIL_HEAD_A, f)),
			maxf(Fx.MIN_DRAW_PX, w * f))


func _draw_head(i: int) -> void:
	var p := head_px(i)
	var e := _elem(i)
	var glow: Color = e["glow"]
	# **Head size carries the generation.** It is the only axis by which "small things" is visible while flying.
	var r := Fx.bolt_px(_gen(i))
	# The glow is drawn here rather than in the art — the `fx_tuning.BOLT_SHEETS` comment holds the reason.
	#
	# **It is several layers, not one** (verify-look caught it on screen).
	#  **It was one filled circle and read as "a dark brown disc with a hard edge"** —
	#   lowering alpha 0.45 -> 0.12 **fixed the brightness but left the edge**, so the "one circle" the user
	#   pointed at was still there, just fainter. **It reads as an object, not as light.**
	#  **The cause was the shape, not the alpha** — the same mistake was made with the fire on monster bodies.
	#   => Shrink the radius while stacking, **blurring the edge.** Further inside, more layers pile up and it is brighter.
	# **The alpha is divided by the layer count** — without dividing, total brightness scales with the layer
	#  count and the judgment that picked 0.12 dies.
	var layers := Fx.BOLT_GLOW_LAYERS
	var a := Fx.BOLT_GLOW_A / float(layers)
	for k in layers:
		# Outer layer inward. The last layer sits against the head size so "the light comes from the bolt".
		var t := float(layers - k) / float(layers)
		draw_circle(p, r * (1.0 + (Fx.BOLT_GLOW_RATIO - 1.0) * t),
			Color(glow.r, glow.g, glow.b, a), true)
	# **The sprite is drawn at exactly diameter 2r.** At generation 0 that is 1:1 with the 16px original and at
	#  generation 1 it is half (`bolt_px` 8 -> 4). Do not pin the sprite size as a constant — the table and the
	#   sprite become two places, and when they diverge you get **the generation shrinking while the sprite stays**,
	#   with no error.
	var tex: Texture2D = _bolt_tex.get(_elem_id(i), null)
	if tex == null:
		# **A rune missing from the table screams in magenta.** Quietly not drawing reads as "the bolt does not
		#  come out", and that sends people hunting for a bug on the firing side (the same reason as `ELEM_FX_MISSING`).
		draw_rect(Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), Color(1.0, 0.0, 1.0), true)
		return
	_paint_bolt(tex, p, r, heading(i))


## **The bolt sprite faces where it is going.** Every `bolt_*.png` is a comet — a bright head with a tail
##  behind it — drawn pointing **+x**, so a bolt fired left used to fly tail-first. `draw_texture_rect` takes
##  an axis-aligned `Rect2` and **has no angle argument at all**, which is why this was not a tuning miss but
##  a structural one: there was nowhere to put the angle.
##
## ⇒ `draw_set_transform(origin, rotation, scale)` rotates everything drawn after it, so the rect is written
##  **around the origin** (`-r, -r, 2r, 2r`) and the transform carries it to `p`.
##
## **The transform must be restored.** Everything drawn afterwards — the next bolt, the next frame — inherits
##  it otherwise, and **nothing raises an error**; `character_view._draw` records the same trap costing a
##  whole flipped coordinate system.
##
## **Cut out of `_draw_head()` as its own method so a net can override it and read the angle** — CLAUDE.md:
##  counting `_draw()` calls measures the engine, not the picture, and Godot refuses to let a script override
##  a native `draw_texture_rect`. **Not named `_paint`** — that name is taken twice already with different
##  signatures (`gate_view`, `monster_view`).
func _paint_bolt(tex: Texture2D, p: Vector2, r: float, rot: float) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Which way bolt `i` is pointing, in radians.
##
## **Read off the sim's velocity, which it already exposes** (`get_vx`/`get_vy`) — no sim change, and none
##  would be right: an angle needs `atan2` and a float, and `src/sim/` is integer-deterministic. **The heading
##  is presentation; the velocity is the fact.** The fixed-point scale cancels in the ratio, so no conversion
##  is needed here.
##
## **A standing bolt keeps the sprite's own orientation (0).** `atan2(0, 0)` is 0 anyway, but relying on that
##  would make "what does a zero-velocity bolt look like" an accident of the C library rather than a decision.
func heading(i: int) -> float:
	if not _live(i):
		return 0.0
	var vx := float(_sim.get_vx()[i])
	var vy := float(_sim.get_vy()[i])
	if vx == 0.0 and vy == 0.0:
		return 0.0
	return atan2(vy, vx)


func _gen(i: int) -> int:
	if not _live(i):
		return 0
	return int(_sim.get_gen()[i])


func _live(i: int) -> bool:
	return _sim != null and i >= 0 and i < _sim.active_count()


func _elem(i: int) -> Dictionary:
	if not _live(i):
		return Fx.ELEM_FX_MISSING
	return Fx.elem_fx(_elem_id(i))


## A dead slot being **-1** is deliberate — falling to 0 (`ELEM_FIRE`) would nearly draw a nonexistent
##  projectile as fire, and that makes it impossible for anyone to measure whether the `_live` guard runs.
func _elem_id(i: int) -> int:
	if not _live(i):
		return -1
	return int(_sim.get_element()[i])
