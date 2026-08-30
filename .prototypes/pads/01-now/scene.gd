# **What the game ships: a baked mark per 칸, all of them at once, while a key is held.**
#
# ⚠ **It builds nothing.** The 판 is an object inside `island.glb` and the only thing this version
# does is switch it on — which is the honest way to photograph it beside four things that are drawn.
extends RefCounted


static func build(lab) -> Node3D:
	lab.field.set_pads_revealed(true)
	return null
