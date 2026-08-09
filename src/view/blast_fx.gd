extends Node2D
## Blast presentation — **flash + screen shake.** It touches the screen only. Not one value goes back into the sim.
##
## **There are no sparks.** The design's "screen" section explicitly cut them — they raise the sense of impact but
##  **carry none of the difference between combinations.** What this stage measures is not "is it pretty" but
##  "do the two combinations split".
##
## **Do not `add_child` a node per blast.** This design has not one physics node, so the
##  "`add_child` in the middle of a physics callback" trap and the "`queue_free` + group" trap are **both extinct.**
##  The moment you attach a node, both come back. => A flash is **one dictionary entry** and `_draw()` draws all of it.
##
## **There is no hitstop.** `Engine.time_scale` stops `_physics_process`, which stops sim ticks,
##  and in lockstep one client stopping alone is desync outright. That share is paid by **shake and flash duration.**

const SpellSim := preload("res://src/sim/spell_sim.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## Live flashes. At most `Fx.FLASH_MAX` of them, so `Array[Dictionary]` is plenty —
##  unlike `spell_sim`, which touches 32 every tick, here it is a few, rarely.
var _flashes: Array[Dictionary] = []

## Screen shake. The amplitude is **integer px** (the `Fx.SHAKE_PX` comment).
var _shake_px := 0
var _shake_left := 0.0
var _shake_full := 0.0
var _shake_offset := Vector2i.ZERO

## Did the previous `_draw()` actually draw anything. `CanvasItem` **keeps holding the last thing it drew**,
##  so not redrawing on the one frame the flashes hit 0 leaves a dead flash pinned on screen forever.
##  **Headless cannot measure this in principle** (it does not draw).
var _drew := false


func _ready() -> void:
	# Additive blending. The one line that makes it read as "light" over a dark background (same as `spell_view.gd`).
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


## The clock is **frame delta, not the sim tick.** Tie presentation to 20Hz and a 0.21-second flash becomes
##  a 4-frame blink, and then "the rhythm of eight" is not visible in the first place.
func _process(delta: float) -> void:
	advance(delta)
	if not _flashes.is_empty() or _drew:
		queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  Trigger — the only door the sim's blast notification comes in through
# ══════════════════════════════════════════════════════════════════

## The shell calls this **right after** `spell.step()`.
##
## The arguments are **cell coordinates** — the px conversion happens here, once. Let the shell convert and pass px
##  and the same conversion lives in two places, and when those diverge it only ever looks like
##  "the flash is slightly off the hole".
## Taking a `PackedInt32Array` as an argument is safe — **it is only read.** An `append` here would write to
##  a CoW copy and evaporate silently (that trap is on the writing side only).
func on_blasts(xs: PackedInt32Array, ys: PackedInt32Array,
		elems: PackedByteArray, gens: PackedByteArray) -> void:
	for k in xs.size():
		# Flash size and shake strength come **from the generation table.** Fix them and a small blast flashes big too,
		#  and then "small things are weak" disappears from the screen entirely — the way v1 died.
		var gen := int(gens[k])
		_add(
			Vector2((xs[k] + 0.5) * Tuning.CELL_PX, (ys[k] + 0.5) * Tuning.CELL_PX),
			Fx.flash_px(gen), int(elems[k]))
		# **The stronger one wins** (`_kick`) — even when one generation 0 and eight generation 1 detonate on
		#  the same tick, the screen shakes by the larger one.
		_kick(Fx.shake_px(gen), Fx.SHAKE_SEC)


func clear() -> void:
	_flashes.clear()
	_shake_px = 0
	_shake_left = 0.0
	_shake_full = 0.0
	_shake_offset = Vector2i.ZERO
	queue_redraw()


## **The same shake every blast raises**, opened to callers that are not a blast at all — stage 1's east wall
##  coming down (`stage-clear-sequence.md`, Beat 1). The player is 300-600px west of that
##  wall and usually not looking at it, so a flash there is a constant nobody can verify; **the shake is felt
##  wherever you are standing**, which is the whole reason that beat is a shake and not a picture.
##
##  Public for the same reason `advance()` below is: a net drives it with no scene. `_kick`'s "the stronger
##  one wins" rule, decay curve and circular offset all still apply — this adds no second shake path.
func kick(px: int, secs: float) -> void:
	_kick(px, secs)


## **The same function `_process` calls** — public so a net can pass time with no scene.
##  Were this private, "does it disappear when its life runs out" could not be measured headless at all.
func advance(dt: float) -> void:
	var i := _flashes.size() - 1
	while i >= 0:
		var e: Dictionary = _flashes[i]
		e["t"] = float(e["t"]) + dt
		if float(e["t"]) >= float(e["life"]):
			_flashes.remove_at(i)
		i -= 1
	_advance_shake(dt)


# ══════════════════════════════════════════════════════════════════
#  Queries — `_draw()` uses **only these functions**. So the value a net measures = the value actually drawn.
# ══════════════════════════════════════════════════════════════════

func active_count() -> int:
	return _flashes.size()


## The flash radius drawn right now. It starts at `FLASH_START` times on spawn and spreads to the final radius.
func flash_radius(i: int) -> float:
	if i < 0 or i >= _flashes.size():
		return 0.0
	var e: Dictionary = _flashes[i]
	return float(e["radius"]) * lerpf(Fx.FLASH_START, 1.0, _ease(_norm(e)))


## The brightness drawn right now. It dies quadratically, so it is **strong up front and short behind**
## (the sense of impact is front-loaded).
func flash_alpha(i: int) -> float:
	if i < 0 or i >= _flashes.size():
		return 0.0
	var k := 1.0 - _norm(_flashes[i])
	return k * k


## A value to lay straight onto the camera. **The shell puts it into `Camera2D.offset`** — the reason this node
##  does not hold the camera is that holding it would make it know the scene structure, and then a net could not
##  run with no scene.
func shake_offset() -> Vector2i:
	return _shake_offset


# ══════════════════════════════════════════════════════════════════
#  Drawing
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	_drew = not _flashes.is_empty()
	for i in _flashes.size():
		var e: Dictionary = _flashes[i]
		var pal := Fx.elem_fx(int(e["elem"]))
		var glow: Color = pal["glow"]
		var core: Color = pal["core"]
		var a := flash_alpha(i)
		var r := flash_radius(i)
		if r < Fx.MIN_DRAW_PX:
			continue
		var pos: Vector2 = e["pos"]
		draw_circle(pos, r, Color(glow.r, glow.g, glow.b, a * Fx.FLASH_GLOW_A), true)
		draw_circle(pos, r * Fx.FLASH_CORE_RATIO, Color(core.r, core.g, core.b, a), true)


# ══════════════════════════════════════════════════════════════════
#  Internals
# ══════════════════════════════════════════════════════════════════

func _add(px: Vector2, radius: float, element: int) -> void:
	_flashes.append({
		"pos": px, "elem": element, "t": 0.0,
		"life": Fx.FLASH_SEC, "radius": radius,
	})
	# Discard **the oldest first.** Discard the new one and the last blast silently goes unseen.
	while _flashes.size() > Fx.FLASH_MAX:
		_flashes.remove_at(0)


## Shake **does not stack — the stronger one wins.** Add them and the screen flies apart on eight detonations.
func _kick(px: int, secs: float) -> void:
	if px <= 0 or secs <= 0.0:
		return
	_shake_px = maxi(_shake_px, px)
	_shake_left = maxf(_shake_left, secs)
	_shake_full = maxf(_shake_full, _shake_left)


## **Everything goes back to 0 inside the very call that ends it.** Left as "clean up on the next call",
##  a state with the amplitude still present is observable for one frame, and the net cannot tell
##  "it never stops" from "it stops one tick late".
func _advance_shake(dt: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(0.0, _shake_left - dt)
	if _shake_left <= 0.0 or _shake_full <= 0.0:
		_shake_px = 0
		_shake_full = 0.0
		_shake_offset = Vector2i.ZERO
		return
	var u := _shake_left / _shake_full
	var amp := float(_shake_px) * pow(u, Fx.SHAKE_DECAY_POW)
	# Drawn **on a circle** — drawing from a uniform square kills the mean amplitude by half, giving
	#  "I raised it to 5px and it looks like 2px".
	# Why `randf()` is fine here: **presentation does not cross the line.** Even with the shake direction
	#  differing per client, not one grain of the world diverges — the exact opposite seat from
	#  "no randomness in the sim".
	var ang := randf() * TAU
	_shake_offset = Vector2i(roundi(cos(ang) * amp), roundi(sin(ang) * amp))


func _norm(e: Dictionary) -> float:
	return clampf(float(e["t"]) / float(e["life"]), 0.0, 1.0)


## Spreads fast, stops slow.
func _ease(u: float) -> float:
	var k := 1.0 - u
	return 1.0 - k * k
