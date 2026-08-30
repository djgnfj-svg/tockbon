# **01-bake — the CPU half: a world-space buffer the stern writes into.**
#
# ⚠ **A throwaway.** The brush is a box scan in GDScript, which is the slowest possible way to do this
# and exactly fast enough to reach a picture.
extends RefCounted

const Common := preload("res://prototypes/wake/common.gd")

## How much sea the buffer covers, in 조각, square and centred on the origin — **and this is the whole
## limit of the mechanism.** The game's sea plane is 400 조각 across.
const SPAN := 48.0
## Texels per 조각. ⚠ **8 means one texel is 0.125 조각**; a trail edge finer than that cannot exist.
const SUBDIV := 8

## How fast the half-width opens, in 조각 per second. **`Common.SPREAD` per 조각 astern at
## `Common.SPEED`** — written as a rate because the buffer knows ages, not distances.
const OPEN := Common.SPREAD * Common.SPEED
const ALPHA := 0.80
const FROTH_SCALE := 2.2
const FROTH_AMT := 0.45

## What an UNPAINTED texel's offset says. ⚠⚠ **It is not zero, and the reason is the sampler.** The
## field is read with `filter_linear`, so a texel on the boundary of the painted region blends a painted
## value with an unpainted one — and with 0 there the blend produces *a small offset with a middling
## age*, which is the brightest thing the shader can draw. **The whole trail wore a bright rectangle
## around it for one round.** A large number blends to a large number and draws nothing.
const UNPAINTED := 99.0

var _w := 0
var _h := 0
var _org := Vector2.ZERO
## **One array, two floats per texel** — `r` is the moment the stern passed, `g` is how far off the
## track that texel was. Interleaved rather than two arrays because it is uploaded as bytes and
## interleaving 300k texels in GDScript once a frame is slower than the brush itself.
var _buf := PackedFloat32Array()
var _tex: ImageTexture = null
var _reach := 0.0


func build(world: Node3D, boat: Node3D) -> void:
	_w = int(SPAN * float(SUBDIV))
	_h = _w
	_org = Vector2(-SPAN * 0.5, -SPAN * 0.5)
	_buf.resize(_w * _h * 2)
	_reach = Common.HALF_W + OPEN * Common.LIFE
	reset()


func reset() -> void:
	for i in range(0, _buf.size(), 2):
		_buf[i] = 0.0
		_buf[i + 1] = UNPAINTED
	_tex = null


## **The brush.** Every texel behind the stern and within the widest the trail will ever get is stamped
## with now and with its own offset from the track. ⚠ **Only behind**: a disc would paint the water in
## front of the bow, and the bow wave is a different candidate's job.
func step(dt: float, t: float, pos: Vector2, head: Vector2) -> void:
	var stern := Common.stern_of(pos, head)
	var perp := Vector2(-head.y, head.x)
	var sub := float(SUBDIV)
	var x0 := maxi(0, int((stern.x - _reach - _org.x) * sub))
	var x1 := mini(_w - 1, int((stern.x + _reach - _org.x) * sub))
	var y0 := maxi(0, int((stern.y - _reach - _org.y) * sub))
	var y1 := mini(_h - 1, int((stern.y + _reach - _org.y) * sub))
	for py in range(y0, y1 + 1):
		var wy: float = _org.y + (float(py) + 0.5) / sub
		var row := py * _w
		for px in range(x0, x1 + 1):
			var wx: float = _org.x + (float(px) + 0.5) / sub
			var d := Vector2(wx, wy) - stern
			if d.dot(head) > 0.0:
				continue
			var off: float = absf(d.dot(perp))
			if off > _reach:
				continue
			var k := (row + px) * 2
			_buf[k] = t
			_buf[k + 1] = off


func present(t: float, mat: ShaderMaterial) -> void:
	if mat == null:
		return
	var img := Image.create_from_data(_w, _h, false, Image.FORMAT_RGF, _buf.to_byte_array())
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	mat.set_shader_parameter("wake_field", _tex)
	mat.set_shader_parameter("wake_org", _org)
	mat.set_shader_parameter("wake_size", Vector2(SPAN, SPAN))
	mat.set_shader_parameter("wake_t", t)
	mat.set_shader_parameter("wake_life", Common.LIFE)
	mat.set_shader_parameter("wake_half_w", Common.HALF_W)
	mat.set_shader_parameter("wake_open", OPEN)
	mat.set_shader_parameter("wake_froth_scale", FROTH_SCALE)
	mat.set_shader_parameter("wake_froth_amt", FROTH_AMT)
	mat.set_shader_parameter("wake_col", Color(0.900, 0.940, 0.950, ALPHA))


func teardown() -> void:
	_buf = PackedFloat32Array()
	_tex = null
