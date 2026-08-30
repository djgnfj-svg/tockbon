# **04c-thin - the arms, thinner and shorter**
#
# Arms only, drawn as a **narrow hard stroke** rather than a soft band, and **dying in half the
# time** so the tail ends closer to the boat.
#
# ⚠ **One dictionary and nothing else.** Every dial not named here is the value in `kelvin.gd`'s `BASE`,
# which is what the first sheet was shot at.
extends "res://.prototypes/wake/kelvin.gd"


func dials() -> Dictionary:
	return {
		"crest_amt": 0.0,
		"arm_w": 0.10,
		"arm_hard": 0.60,
		"life": 3.0,
		"alpha": 0.75,
	}

