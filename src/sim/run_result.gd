class_name RunResult
extends RefCounted
## A snapshot of one run's numbers, taken the moment the run ends (`Run._snapshot()`). The ending screen
## reads this, never `World` — `Run.to_title()` drops the world, and the screen would then be holding a
## dead reference.
##
## The unit is 경험치, never 세포 (`hunting-and-the-boss`, newer than the word and the GDD that used it).

var outcome: int = Run.Outcome.NONE
var elapsed: float = 0.0
var experience: int = 0             ## everything eaten this run — see Swarm.eaten, rounded once, here
var cargo_lost: int = 0             ## what died out in the field with the clones carrying it
var species: PackedStringArray = [] ## names of species eaten at least once, in first-eaten order. Empty
                                     ## until plan 4 fills World.species_eaten
var peak_swarm: int = 0
var clones_lost: int = 0

## ELEVEN entries, "" for empty, written by `Run._snapshot()` from `Body.slot_part`. The count is
## `Parts.Slot` and nowhere else — the two view files that each held the literal read it from there.
var body_slots: PackedStringArray = []
