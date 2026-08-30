# **04e-ghost - the whole shape, much fainter**
#
# **The same geometry as `04a-full` and only the opacity moved.** This is the row that asks
# whether 「simpler」 means less shape or less loud.
#
# ⚠ **One dictionary and nothing else.** Every dial not named here is the value in `kelvin.gd`'s `BASE`,
# which is what the first sheet was shot at.
extends "res://prototypes/wake/kelvin.gd"


func dials() -> Dictionary:
	return {
		"alpha": 0.30,
	}

