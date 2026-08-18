class_name RunMap
extends RefCounted
## Where the run has been on the node map, and where it may go next. The map's SHAPE — which nodes
## exist, what each pays, which may follow which — is `rules.gd`'s `MAP_NODES` and `MAP_EDGES`; this
## file holds only the walk over it.
##
## **`Run` today has no representation of "where you are" other than an integer that only ever counts
## up.** A branching route is not a bigger integer: it is an ordered set with a predecessor relation,
## and `island_index + 1` cannot express "either of two". That is the whole reason this class exists
## rather than a field on `Run` — see `title-and-map`, the structure section.
##
## No `Node`, no `_draw`, no `Input`, no `get_node`, no `$`: constructible and drivable by a net with
## `.new()` and nothing else, like every other file under `src/sim/`.
##
## Every value that changes what happens lives in `rules.gd`, reached through its global `Rules` class
## name. Nothing here holds a second copy of the node table.


## The route walked so far, in order, as node ids. **THIS IS THE WHOLE OF THE STATE.**
##
## ⚠ There is deliberately no `cleared` array and no `at` field: "where I am" is the last entry and
## "what I have cleared" is membership, so the picture the view draws (the travelled lines) and the
## sim's own progress are READ OFF THE SAME ARRAY and cannot diverge. A second array would be the same
## fact written twice, which is how a soldier ends up standing on a node the line does not reach.
##
## A flat packed array for the same reason `Army`'s columns are: the derived facts below have no
## bookkeeping to forget.
var path := PackedInt32Array()


func _init() -> void:
	reset()


## Back to "landed nowhere". Shared by `_init` and `Run.restart` for the same reason `Run._reset` is
## shared: a field added to one path and forgotten in the other would make the second run start
## somewhere the first did not, with nothing to bark about it.
func reset() -> void:
	path.clear()


## The node the run is standing on, or **-1** before the first one is entered.
##
## -1 means "the run has landed nowhere yet" and is not an error: it is the state a fresh `Run` is in
## while the map screen waits for the first press, and `is_reachable` reads it as such.
func at() -> int:
	if path.is_empty():
		return -1
	return path[path.size() - 1]


## Walked past and finished with.
##
## ⚠ **`at()` is NOT cleared.** The run is standing on it, and while the island it opened is still
## being fought it has not been won. This is the one place "visited" and "cleared" differ, and folding
## them into plain membership would light the node the player is currently losing on.
func is_cleared(n: int) -> bool:
	return path.has(n) and n != at()


## May the run step onto this node right now.
##
## The empty case is not an edge case bolted on: floor 0 has no predecessor by construction, so
## "nothing walked yet" and "an edge leads here" are the same question asked of two different maps.
func is_reachable(n: int) -> bool:
	if n < 0 or n >= Rules.map_node_count():
		return false
	if path.is_empty():
		return Rules.map_floor_of(n) == 0
	var here := at()
	for e in range(Rules.map_edge_count()):
		if Rules.map_edge_from(e) == here and Rules.map_edge_to(e) == n:
			return true
	return false


## Every node `is_reachable` says yes to. The view draws its offer from this and the shell hit-tests
## against it, so the picture can never offer a node the sim refuses.
func reachable_nodes() -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in range(Rules.map_node_count()):
		if is_reachable(n):
			out.append(n)
	return out


## Steps onto a node. Returns false and **changes nothing** when the node is not reachable.
##
## It does not bark, matching `grid.load_rows`: validating a click is the caller's job, and a
## `push_error` here would have to be forgiven by every net that pokes at the map.
func enter(n: int) -> bool:
	if not is_reachable(n):
		return false
	path.append(n)
	return true


## Has the run actually walked this edge — both endpoints consecutive in `path`, in the edge's own
## direction. Derived, never stored: it is the same fact as `path` and a stored copy would be free to
## disagree with the route the run took.
func edge_is_travelled(e: int) -> bool:
	if e < 0 or e >= Rules.map_edge_count():
		return false
	var a := Rules.map_edge_from(e)
	var b := Rules.map_edge_to(e)
	for i in range(path.size() - 1):
		if path[i] == a and path[i + 1] == b:
			return true
	return false


## The run is standing on the boss node. It says nothing about whether that fight was WON — `Run` is
## what decides that, and it asks this only after a win.
func is_finished() -> bool:
	var here := at()
	return here >= 0 and Rules.map_kind_of(here) == Rules.NodeKind.BOSS
