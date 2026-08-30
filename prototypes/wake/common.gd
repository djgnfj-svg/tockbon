# **What all five candidates share, so the only difference on the sheet is the mechanism.**
#
# The same sea, the same boat, the same two crossings, the same white. ⚠ **A throwaway.** The winner
# gets rebuilt properly under `src/`; the losers are deleted.
#
# ⚠⚠ **The two crossings are FUNCTIONS OF TIME, not of frame count.** Every candidate is driven from
# t = 0 with the same fixed step and photographed at the same t, so two pictures differ by the
# mechanism and by nothing else. A wake driven off the real frame delta would put a different length of
# trail in every picture and the sheet would be measuring the machine's mood.
extends RefCounted

const DIR := "res://prototypes/wake"

# --- the boat's two crossings ---------------------------------------------------------------------
## Tiles per second. **`Rules.BOAT_SPEED_TILES`, copied rather than read** — another builder is in
## `src/` right now and a prototype that goes down when the game does not parse is not a prototype.
const SPEED := 4.0
## The straight run: due east, through the middle of the frame.
const START_STRAIGHT := Vector2(-24.0, 0.0)
## The turning run: due east, then hard left onto due north.
const START_TURN := Vector2(-16.0, 4.0)
## When the wheel goes over, and how fast it goes over.
##
## ⚠⚠ **A quarter turn in one second is the whole point of the second run.** At `SPEED` that is a turn
## radius of 2.55 조각 against a hull 5.2 조각 long — sharper than the boat could really turn, and
## deliberately so. **Two of the five mechanisms fail here and nowhere else**, and a sheet shot only on
## the straight would show five pictures that all look fine.
const TURN_AT := 4.0
const TURN_RATE := PI * 0.5

## The moments the sheet is shot at. **Chosen so the hull sits off-centre with its trail across the
## frame**, not so a particular candidate looks good.
const T_STRAIGHT := 7.25
const T_TURN := 6.4

# --- what a wake is made of, shared by every candidate --------------------------------------------
## How long a mark on the water lives, in seconds. **One number, read by all five** — a candidate that
## chose its own would be a candidate photographed with a longer tail.
const LIFE := 6.0
## Half the trail's width where it leaves the stern, and how much wider it gets per 조각 astern.
const HALF_W := 0.50
const SPREAD := 0.085
## Where the trail is born: the hull's own transom. **Read off `boat.glb`** — the bounds run
## −2.60 .. +2.60 along local x with the sharp end positive.
const STERN_X := -2.45

# --- the numbers copied out of `look.gd`, because a prototype must not import the game ------------
const SEA_Y := 0.075
const BOAT_BOB_TILES := 0.06
const BOAT_BOB_SEC := 2.2
const BOAT_ROLL_DEG := 3.0
const BOAT_ROLL_SEC := 3.1

## How far the wake sits above the water plane, in 조각. ⚠ **Geometry candidates only.** Coplanar with
## the sea is z-fighting; far enough to see is a sheet of paper hovering over the water at this pitch.
const LIFT := 0.012


## **Where the boat is, and which way it is pointing, at time `t`.** Returns `[Vector2 pos, Vector2 head]`
## in 조각, `head` unit length. The XZ plane; y is the sea.
static func boat_at(t: float, turning: bool) -> Array:
	if not turning:
		return [START_STRAIGHT + Vector2(SPEED * t, 0.0), Vector2(1.0, 0.0)]
	var dur := (PI * 0.5) / TURN_RATE
	var corner := START_TURN + Vector2(SPEED * TURN_AT, 0.0)
	if t <= TURN_AT:
		return [START_TURN + Vector2(SPEED * t, 0.0), Vector2(1.0, 0.0)]
	var r := SPEED / TURN_RATE
	if t <= TURN_AT + dur:
		var s := t - TURN_AT
		var a := TURN_RATE * s
		# The arc leaves `corner` heading east and rolls onto north; see the derivation in the header
		# of this file's turn constants — u(0) = (0,1) so the centre sits one radius to the north.
		var p: Vector2 = corner + Vector2(sin(a), cos(a) - 1.0) * r
		return [p, Vector2(cos(a), -sin(a))]
	var end: Vector2 = corner + Vector2(1.0, -1.0) * r
	var head := Vector2(0.0, -1.0)
	return [end + head * (SPEED * (t - TURN_AT - dur)), head]


## The hull's yaw for a tile-space heading. **`rotation.y = θ` sends local +X to `(cos θ, 0, −sin θ)`**,
## and the model's bow is +X — so a yaw written for Godot's own −Z convention sails it broadside on.
static func yaw_of(head: Vector2) -> float:
	return atan2(-head.y, head.x)


## Where the trail is born, in world 조각 — the transom, not the middle of the hull.
static func stern_of(pos: Vector2, head: Vector2) -> Vector2:
	return pos + head * STERN_X


## **The hull, read straight out of `assets/props/boat.glb`.** The game's own file, unmodified.
static func boat_node() -> Node3D:
	var packed := load("res://assets/props/boat.glb") as PackedScene
	if packed == null:
		push_error("wake: assets/props/boat.glb will not load")
		return null
	return packed.instantiate() as Node3D


## A material for a candidate that draws its own geometry. Unshaded and blended, so the white it puts
## on the water is the white `look.gd` chose and not that white under this sun.
static func fx_material(shader_path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	return m


## One layer node for a candidate's own geometry, with everything a flat sheet on water needs turned
## off. ⚠ **No shadow**: a wake that casts one is a wake made of cardboard.
static func fx_layer(world: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = SEA_Y + LIFT
	world.add_child(mi)
	return mi
