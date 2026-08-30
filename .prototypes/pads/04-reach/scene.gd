# **Only where THIS body can get to, and how far away it is.**
#
# **Where the mark comes from**: a walk of the rules outward from the body — the game's own
# `can_step`, so what lights up is exactly what a step is allowed to do. The board says nothing until
# a body is picked, and then it answers one question: where can this one go.
#
# ⚠ This is XCOM 2's move preview, and it is a shipped answer to 「못 가는 데를 어떻게 알리나」: the
# tiles a soldier can reach light up and the rest of the floor stays floor. **No mark ever has to say
# 「no」** — the absence of one does it.
#
# ⚠⚠ **ONE 판 PER 칸, AND THE SAME ONE RISES** (2026-08-29, the user: 「조각에 판을 올리고 왜 뜨는 판은
# 또 다른데 뜨네... 개념이 좀 잘못된듯?」). A round drew a mark on every 조각 and then lifted a 칸-sized
# plate on top of four of them — **two units on one board**, and the lifted thing was not the thing
# that had been lying there. **The 판 is a 칸.** It rests as a 칸 and it rises as that same 칸.
extends RefCounted

## How many steps out the preview runs. **A body is not given a move budget yet** (there is no
## command in the code at all), so this stands in for one.
const STEPS := 11
const NEAR := Color(1.0, 1.0, 1.0, 0.62)
const FAR := Color(0.72, 0.86, 1.0, 0.16)
## ⚠ **Rounded like the shipped 판** (2026-08-29, the user: 「4번 칸을 기존처럼 약간 동그랗게」). A hard
## square reads as a tile laid ON the ground; the corner is what makes it read as a mark.
const FULL_SIZE := 1.90       # a whole 칸, with a hair of ground left around it
const FULL_RADIUS := 0.42
## What one 조각 of a 칸 gets when the rest of that 칸 is cliff or water. **Same colour, same lift** —
## it is a piece of the same 판, not a mark of its own.
const PART_SIZE := 0.92
const PART_RADIUS := 0.22

# --- the 칸 under the cursor -----------------------------------------------------------------------
# ⚠⚠ **THE HOVERED 판 STANDS OFF THE GROUND** (2026-08-29, the user: 「판이 떠야함」). Brighter is not
# lifted: under this camera what says 「떠 있다」 is the wall you can see under the plate's edge.
const HOVER := Color(1.0, 1.0, 0.88, 0.97)
const HOVER_SIDE := Color(0.80, 0.78, 0.62, 0.97)
const HOVER_LIFT := 0.18      # ⚠ **3x the shipped 판's own lift.** Under 0.12 the plate reads as flat
const HOVER_THICK := 0.08


static func build(lab) -> Node3D:
	var from: Vector2i = lab.body_tile()
	var seen: Dictionary = lab.reach(from, STEPS)
	if seen.is_empty():
		return null

	# **Gather the walk into 칸 first.** Nothing is drawn per 조각 until it is known what the 칸 it
	# belongs to looks like.
	var lumps := {}      # 칸 -> [tile, ...]
	var cost := {}       # 칸 -> the fewest steps to anywhere in it
	for t in seen.keys():
		var tx: int = int(t) % lab.grid.w
		var ty: int = int(t) / lab.grid.w
		var blk: int = lab.block_of(tx, ty)
		if not lumps.has(blk):
			lumps[blk] = []
			cost[blk] = int(seen[t])
		lumps[blk].append(int(t))
		cost[blk] = mini(int(cost[blk]), int(seen[t]))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: int = Look.WASH_BLOCK_TILES
	var whole: int = span * span
	for blk in lumps.keys():
		var tiles: Array = lumps[blk]
		var lifted: bool = int(blk) == lab.hover_block
		var col: Color = NEAR.lerp(FAR, float(cost[blk]) / float(STEPS))
		# **One height for the whole 칸.** Its 조각 can sit at different levels only where a cliff runs
		# through it, and a plate bent in the middle is not a plate.
		var y := -1e9
		for t in tiles:
			y = maxf(y, lab.tile_y(int(t) % lab.grid.w, int(t) / lab.grid.w))
		if lifted:
			y += HOVER_LIFT
		if tiles.size() == whole:
			var o: Vector2i = lab.block_origin(int(blk))
			var c := Vector3(float(o.x) + float(span) * 0.5, y, float(o.y) + float(span) * 0.5)
			_one(lab, st, c, FULL_SIZE, FULL_RADIUS, col, lifted)
		else:
			# A 칸 the land does not fill: the 판 is only the part that is ground.
			for t in tiles:
				var tx2: int = int(t) % lab.grid.w
				var ty2: int = int(t) / lab.grid.w
				var c2 := Vector3(float(tx2) + 0.5, y, float(ty2) + 0.5)
				_one(lab, st, c2, PART_SIZE, PART_RADIUS, col, lifted)
	var holder := Node3D.new()
	holder.add_child(lab.one_mesh(st, lab.flat_mat(Color(1, 1, 1, 1))))
	return holder


## One piece of 판 — lying flat, or standing off the ground with a side under it.
static func _one(lab, st: SurfaceTool, c: Vector3, size: float, radius: float,
				 col: Color, lifted: bool) -> void:
	if lifted:
		lab.lay_round_slab(st, c, size, radius, HOVER_THICK, HOVER, HOVER_SIDE)
	else:
		lab.lay_round_quad(st, c, size, radius, col)
