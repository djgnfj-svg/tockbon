# **04b-arms - the two arms, and nothing inside them**
#
# **The crests are gone.** They are the busiest part of the picture and the first thing
# 「simpler」 would mean, so this takes them out and changes nothing else.
#
# ⚠ **One dictionary and nothing else.** Every dial not named here is the value in `kelvin.gd`'s `BASE`,
# which is what the first sheet was shot at.
extends "res://.prototypes/wake/kelvin.gd"


func dials() -> Dictionary:
	return {
		"crest_amt": 0.0,
	}

