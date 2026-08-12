class_name Look
extends RefCounted
## Every presentation constant, in exactly one file.
##
## This is the one folder rule from the deleted game that survived on its own merit, and it survived
## because the failure was measured: a value was doubled and **nothing changed on screen**, since the
## number that would have shown it lived in six places and only one of them moved.
##
## Nothing here changes what happens. Sizes and colours only — if a constant would alter the simulation,
## it belongs in `rules.gd`.

const BG := Color(0.09, 0.06, 0.05)

const HOST_COLOR := Color(0.95, 0.85, 0.45)
const HOST_HURT_COLOR := Color(1.0, 0.45, 0.35)
const HOST_RADIUS := 14.0

const CLONE_COLOR := Color(0.62, 0.82, 0.55)
const CLONE_LOADED_COLOR := Color(0.98, 0.92, 0.35)
const CLONE_RADIUS := 7.0
## A loaded clone is visibly bigger. **The only readability requirement in this build**: telling a loaded
## clone from an empty one across the screen is what makes an abandoned harvest legible as a loss.
const CLONE_LOAD_GROWTH := 1.6
const CLONE_LOAD_FULL := 8.0

const FOOD_COLOR := Color(0.45, 0.65, 0.85)
const FOOD_RADIUS := 3.0

const PREDATOR_COLOR := Color(0.75, 0.25, 0.28)
const PREDATOR_RADIUS := 16.0

const RALLY_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const RALLY_RADIUS := 22.0
