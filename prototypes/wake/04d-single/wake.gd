# **04d-single - one line straight behind the boat**
#
# **No V at all.** One fading trail down the track the hull took — the simplest thing that still
# says something passed here.
#
# ⚠ **One dictionary and nothing else.** Every dial not named here is the value in `kelvin.gd`'s `BASE`,
# which is what the first sheet was shot at.
extends "res://prototypes/wake/kelvin.gd"


func dials() -> Dictionary:
	return {
		"arm_amt": 0.0,
		"crest_amt": 0.0,
		"centre_amt": 1.0,
		"centre_w": 0.16,
		"life": 4.0,
	}

