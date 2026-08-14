class_name Actives
extends RefCounted
## What can be bound to one of the three active slots. **The whole of the player's offense.**
##
## They live here and are held by `Swarm.bound` for this plan; they move onto the body in plan 3, which is
## why they are named as their own thing now — so that move is a re-parent rather than a discovery.
##
## `TITLE` is Korean because it is read on screen. Nothing else in this file is.

enum { NONE = 0, BITE = 1, DASH = 2 }

## What `space` (slot 2) will accept. Binding anything else there is refused rather than silently ignored —
## see `Swarm.bind()`. A key that quietly does nothing is the idle hand planning principle 1 forbids.
const MOVEMENT := [DASH]

const TITLE := {
	NONE: "빈 칸",
	BITE: "물기",
	DASH: "짧은 숨",
}
