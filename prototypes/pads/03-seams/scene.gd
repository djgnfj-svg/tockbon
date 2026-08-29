# **Lines, not areas: the seams between 칸, drawn on the walkable ground.**
#
# **Where the mark comes from**: the EDGES of the grid. Nothing is filled and nothing is tinted — the
# ground keeps its own colour and the board is simply ruled, the way a boardgame's squares are told
# apart by the lines between them.
#
# ⚠ **The seams are on the 칸 (2x2 tiles), not on the 조각**, because the 칸 is what the cursor picks
# and what a body is commanded onto. A rule every metre would draw four times as many lines.
extends RefCounted

const WIDTH := 0.055     # how thick a seam is, in tiles
const COL := Color(1.0, 1.0, 1.0, 0.5)


static func build(lab) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for ty in lab.grid.h:
		for tx in lab.grid.w:
			if not lab.walkable(tx, ty):
				continue
			any = true
			var y: float = lab.tile_y(tx, ty)
			# The west seam of every 칸, plus the island's own western edge where the land starts.
			if tx % 2 == 0 or not lab.walkable(tx - 1, ty):
				lab.lay_quad(st, Vector3(float(tx), y, float(ty) + 0.5), WIDTH, 1.0, COL)
			# and its east edge, where the land stops.
			if not lab.walkable(tx + 1, ty):
				lab.lay_quad(st, Vector3(float(tx) + 1.0, y, float(ty) + 0.5), WIDTH, 1.0, COL)
			if ty % 2 == 0 or not lab.walkable(tx, ty - 1):
				lab.lay_quad(st, Vector3(float(tx) + 0.5, y, float(ty)), 1.0, WIDTH, COL)
			if not lab.walkable(tx, ty + 1):
				lab.lay_quad(st, Vector3(float(tx) + 0.5, y, float(ty) + 1.0), 1.0, WIDTH, COL)
	if not any:
		return null
	var holder := Node3D.new()
	holder.add_child(lab.one_mesh(st, lab.flat_mat(Color(1, 1, 1, 1))))
	return holder
