# **The CPU half of the Kelvin wake, and the only place its dials are written down.**
#
# All this does is remember where the boat was a few dozen times and hand the list to the shader. There
# is no buffer to allocate, no mesh to rebuild and nothing that has a resolution.
#
# ⚠⚠ **A CANDIDATE FOLDER IS ONE DICTIONARY.** `04x-name/wake.gd` extends this file and overrides
# `dials()` with the values it changes — nothing else. **Adding a sixth version is one file with one
# dictionary in it**, and a dial that is not in that dictionary is the one written in `BASE` below.
extends RefCounted

const Common := preload("res://.prototypes/wake/common.gd")

## ⚠⚠ **Must match `WAKE_MAX` in `kelvin.gdshaderinc`.** A GLSL array is a compile-time length, so the
## two cannot be derived from one place — **and that is the mechanism's ceiling written twice**, which
## is the honest thing to say about it rather than a thing to hide.
const MAX := 96

## The Kelvin half angle. **19.47° is not a taste value** — it is where the envelope of the rings a
## moving disturbance leaves falls out, at any speed, for deep water.
const HALF_ANGLE := 19.47

## **Every dial, at the value the first sheet was shot at.** A version says only what it changes.
const BASE := {
	# How long a mark lives, in seconds — the whole length of the tail.
	"life": 6.0,
	# The two arms: brightness, stroke HALF-width in 조각, and where the soft edge starts.
	"arm_amt": 1.0,
	"arm_w": 0.20,
	"arm_hard": 0.35,
	# The transverse crests: brightness, thickness in 조각, and one crest every this many seconds.
	"crest_amt": 0.75,
	"crest_w": 0.16,
	"crest_every": 0.50,
	# One line down the track instead of the V. **Off in every version but `04d-single`.**
	"centre_amt": 0.0,
	"centre_w": 0.16,
	# Overall opacity — the dial that quietens a picture without taking any shape out of it.
	"alpha": 0.85,
	# The noise that breaks the white up.
	"froth_scale": 2.2,
	"froth_amt": 0.35,
}

var _d := {}
var _hist := PackedVector4Array()
var _last := -1.0
## The moment the boat is at RIGHT NOW, handed over as one extra sample on top of the remembered ones.
## ⚠ Without it the newest sample can be a whole interval old and the V comes loose from the transom.
var _now := Vector4.ZERO


## **Overridden by each candidate folder.** The base values are what it does not mention.
func dials() -> Dictionary:
	return {}


func build(world: Node3D, boat: Node3D) -> void:
	_d = BASE.duplicate()
	var mine := dials()
	for k in mine:
		if not BASE.has(k):
			push_error("kelvin: %s is not a dial" % k)
		_d[k] = mine[k]
	reset()


## Seconds between two remembered moments. **One whole life across the array and no more.**
## ⚠⚠ **The arm is the segment between two samples' envelope points**, so this only has to be fine
## enough that a turn does not cut a corner — it is no longer what decides whether the arm is beaded.
func every() -> float:
	return float(_d["life"]) / float(MAX)


func reset() -> void:
	_hist = PackedVector4Array()
	_last = -1.0
	_now = Vector4.ZERO


func step(dt: float, t: float, pos: Vector2, head: Vector2) -> void:
	var here := Common.stern_of(pos, head)
	_now = Vector4(here.x, here.y, t, atan2(head.y, head.x))
	if _last >= 0.0 and t - _last < every():
		return
	_last = t
	_hist.append(_now)
	while _hist.size() > MAX:
		_hist.remove_at(0)


func present(t: float, mat: ShaderMaterial) -> void:
	if mat == null:
		return
	# The shader reads `wake_n` entries, so a short array is padded rather than left ragged.
	var pad := _hist.duplicate()
	var live := pad.size()
	if live < MAX and _now != Vector4.ZERO:
		pad.append(_now)
		live += 1
	while pad.size() < MAX:
		pad.append(Vector4.ZERO)
	mat.set_shader_parameter("wake_hist", pad)
	mat.set_shader_parameter("wake_n", live)
	mat.set_shader_parameter("wake_t", t)
	mat.set_shader_parameter("wake_speed", Common.SPEED)
	mat.set_shader_parameter("wake_sin", sin(deg_to_rad(HALF_ANGLE)))

	# ⚠ **Every dial goes over as `wake_<name>` except these two**, which the shader reads in another
	# shape: `alpha` rides in the colour and `crest_every` is turned into the two values below. Naming
	# them here rather than letting them fall through is deliberate — `set_shader_parameter` on a name
	# no uniform has is silently ignored, so a typo would simply never appear.
	for k in _d:
		if k == "alpha" or k == "crest_every":
			continue
		mat.set_shader_parameter("wake_" + str(k), _d[k])
	# **Derived from `crest_every`, so that one dial owns how often a crest comes.** Half a sample's
	# width of the cycle picks exactly one sample in `crest_every / every()`.
	var hz: float = 1.0 / maxf(float(_d["crest_every"]), 0.001)
	mat.set_shader_parameter("wake_crest_hz", hz)
	mat.set_shader_parameter("wake_crest_pick", every() * hz * 0.5)
	mat.set_shader_parameter("wake_col",
			Color(0.900, 0.940, 0.950, float(_d["alpha"])))


func teardown() -> void:
	_hist = PackedVector4Array()
	_now = Vector4.ZERO
