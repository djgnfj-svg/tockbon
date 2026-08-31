class_name Hand
extends RefCounted
## **What the player has hold of, and where it may go.**
##
## ⚠⚠ **THE WHOLE OF THE EXTENSION THE USER ASKED FOR IS THAT `ids` IS A LIST** (2026-08-31, the user:
## 「선택한게 캐릭터든 그룹이든 할 수 있게 확장성 있게 작업해 달라고」). Today the press puts ONE body in
## it. The day a 무리 exists the same press puts nine in it and **nothing below this line changes**:
## the reach is a union, the order is a loop, and the preview is one route per body. There is no
## 「one body」 branch anywhere in this file to find and fix later, because there is no 「one body」 case
## — there is a list whose length happens to be 1.
##
## ⚠ **Nothing here is a Node.** `.new()` builds it and a net drives 「pick → reach → order」 with no
## tree at all, which is the whole reason it sits in `sim/` and not in the shell that presses it.
##
## **The gesture this serves** (2026-08-31, the user: 「tab 없이 그냥 캐릭터를 누르면 이동할 수 있는
## 칸들이 뜨고 눌러서 이동하는거임」):
##
##  1. press a body   -> `pick`   — the reach lights up
##  2. press a lit 조각 -> `order` — everybody picked walks there
##  3. press anything else -> `clear`
##
## ⚠⚠ **THE TAB THE USER MENTIONED WAS ALREADY IN THE GAME AND IT IS NOT A COMMIT KEY.** It is
## `field_view.set_pads_revealed`, held to show the whole board. **No reservation step was added** —
## a walk order still fires the instant the destination is pressed, which is what 2026-08-25 settled
## (「손은 전투 중에도 움직인다」) and what `commit-before-the-fight-not-during` records.


## **The bodies under the player's command right now**, as soldier ids into `Battle`'s columns.
## Empty is 「nothing picked」 and is the resting state.
var ids := PackedInt32Array()

## **Every 조각 the picked bodies may stand on**, ascending. ⚠ **This is what lights up**, so it is a
## standing test and not a walking one: a stair is walked THROUGH and never stood on, and a 조각 whose
## 블록 already holds nine is not somewhere anybody may be sent.
var reach := PackedInt32Array()

## `reach` again as a set, so `can_reach` is one lookup instead of a scan. **Rebuilt with `reach` and
## never separately** — two containers that can disagree about the same fact is how a lit 조각 refuses
## a press.
var _in_reach := {}

## The 조각 `routes` last answered for, and what it answered. **A hover asks for the same route many
## frames running**, and a flow field per frame is the one cost in here worth not paying twice.
var _route_tile := -1
var _routes: Array = []


## **Lets go of everything.** ⚠ Called on any press that is neither a body nor a lit 조각, which is
## what makes 「press the sea to deselect」 true by construction rather than by a special case.
func clear() -> void:
	ids = PackedInt32Array()
	reach = PackedInt32Array()
	_in_reach = {}
	_forget_routes()


func is_empty() -> bool:
	return ids.is_empty()


func has(soldier_id: int) -> bool:
	return ids.has(soldier_id)


## **Picks one body.** The single-body door, and it is a one-line wrapper over the list door on
## purpose — see the header. A caller that wants a 무리 calls `pick_many` and gets the same behaviour.
func pick(battle: Battle, soldier_id: int) -> bool:
	var one := PackedInt32Array()
	one.append(soldier_id)
	return pick_many(battle, one)


## **Picks a whole list.** ⚠ **Ids that are not ashore are dropped rather than refused** — a 무리 with
## one dead member is still a 무리, and refusing the lot would make death a selection bug.
## **False only when nothing at all survived the filter**, in which case the hand is left empty.
func pick_many(battle: Battle, want: PackedInt32Array) -> bool:
	clear()
	if battle == null or battle.grid == null:
		return false
	var kept := PackedInt32Array()
	for k in want.size():
		var i := int(want[k])
		if i < 0 or i >= battle.soldier_state.size():
			continue
		if int(battle.soldier_state[i]) != Battle.SoldierState.ASHORE:
			continue
		if kept.has(i):
			continue
		kept.append(i)
	if kept.is_empty():
		return false
	ids = kept
	_build_reach(battle)
	return true


func can_reach(tile: int) -> bool:
	return _in_reach.has(tile)


## **Where the picked bodies stand right now**, one 조각 each and in `ids` order. ⚠ **A body whose
## position is off the board answers -1 rather than being dropped**, so this list and `ids` are always
## the same length and index the same body.
func from_tiles(battle: Battle) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in ids.size():
		out.append(_tile_of(battle, int(ids[k])))
	return out


## **Which body a press landed on, or -1.** ⚠ **Nearest wins and the radius is a real distance**, not
## 「the body whose 조각 you pressed」: bodies stand three to a 조각 and off its centre, so a 조각 test
## would refuse a press that visibly hit somebody.
##
## ⚠ **The press point is in tile units**, which is what `soldier_pos` is in. The shell converts.
func body_at(battle: Battle, at_tiles: Vector2, radius: float) -> int:
	if battle == null:
		return -1
	var who := -1
	var best := radius
	for raw_id in battle.ashore_ids():
		var i := int(raw_id)
		var d: float = (battle.soldier_pos[i] as Vector2).distance_to(at_tiles)
		if d <= best:
			best = d
			who = i
	return who


## **Sends everybody picked to `tile`, and answers how many actually went.**
##
## ⚠⚠ **ONE BODY GETS THE PRESSED 조각; MANY GET ONE 조각 EACH.** Nine bodies ordered onto the same
## 조각 would be nine walk orders onto three slots, and six of them would stall against a full 조각
## with no way for the player to see why. **`_spread` is the seam the 무리's own formation plugs into**
## — the roadmap has 「아홉이 서는 모양」 already chosen as shape 6, and when it is built it replaces the
## body of that one function and nothing else here.
func order(battle: Battle, tile: int) -> int:
	if battle == null or battle.grid == null or ids.is_empty():
		return 0
	if not can_reach(tile):
		return 0
	var seats := _spread(battle, tile, ids.size())
	var sent := 0
	for k in ids.size():
		if k >= seats.size():
			break
		if battle.order_walk(int(ids[k]), int(seats[k])):
			sent += 1
	_forget_routes()
	return sent


## **The line each picked body would walk to `tile`** — one 조각 list per body, in `ids` order, and the
## whole of the 이동선 the user asked to see before committing to it (2026-08-31: 「이동할때 이동선이
## 미리 보였으면 좋겠네」).
##
## ⚠ **It is the SAME route the walk will take and not a straight line drawn between two points.** It
## is built from `Grid.flow_field` and `Grid.string_pull`, which is what `Battle.order_walk` itself
## calls — a preview drawn any other way is a promise the walk does not keep.
## ⚠ **An empty list for a body means 「it is already there」**, not 「it cannot get there」; `order`
## refuses an unreachable 조각 before this is ever asked.
func routes(battle: Battle, tile: int) -> Array:
	if battle == null or battle.grid == null or ids.is_empty():
		return []
	if not can_reach(tile):
		_forget_routes()
		return []
	if tile == _route_tile:
		return _routes
	var seats := _spread(battle, tile, ids.size())
	var out: Array = []
	for k in ids.size():
		var line := PackedInt32Array()
		if k < seats.size():
			var here := _tile_of(battle, int(ids[k]))
			var dest := int(seats[k])
			if here >= 0 and here != dest:
				var raw := battle.grid.path_from(battle.grid.flow_field(dest), here, dest)
				if raw.size() > 1:
					line = battle.grid.string_pull(raw)
		out.append(line)
	_route_tile = tile
	_routes = out
	return out


## **The same routes as POINTS in tile units**, one list per picked body, and what the view draws.
##
## ⚠⚠ **THE FIRST POINT IS THE BODY'S OWN POSITION AND NOT ITS 조각's CENTRE.** Bodies stand three to
## a 조각 and off its middle, so a line starting at the centre visibly leaves from beside the feet it
## belongs to — with nine of them that reads as nine lines starting nowhere in particular.
##
## ⚠ **A list of one point draws nothing**, which is exactly right for a body already standing on its
## destination.
func route_points(battle: Battle, tile: int) -> Array:
	var lines := routes(battle, tile)
	if lines.is_empty():
		return []
	var w := battle.grid.w
	var out: Array = []
	for k in ids.size():
		var pts := PackedVector2Array()
		pts.append(battle.soldier_pos[int(ids[k])] as Vector2)
		if k < lines.size():
			var line: PackedInt32Array = lines[k]
			for j in range(1, line.size()):
				var t := int(line[j])
				pts.append(Vector2(float(t % w) + 0.5, float(t / w) + 0.5))
		out.append(pts)
	return out


## **Floods out from the picked bodies and keeps every 조각 they may STAND on.**
##
## ⚠⚠ **THE FLOOD AND THE FILTER ARE TWO DIFFERENT TESTS AND THAT IS DELIBERATE.** A stair is walked
## across, so it stays in the flood and lets the way past it open; it is not stood on, so it is not in
## `reach`. Folding the two into one test would wall off every upper storey, because a stair is the
## only door there is.
##
## ⚠ **The union, for a 무리.** A 조각 one member can reach lights even if another cannot — the order
## then seats that member elsewhere, which `_spread` already does.
func _build_reach(battle: Battle) -> void:
	var grid := battle.grid
	var n := grid.w * grid.h
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	var queue := PackedInt32Array()
	for k in ids.size():
		var t := _tile_of(battle, int(ids[k]))
		if t >= 0 and seen[t] == 0:
			seen[t] = 1
			queue.append(t)
	var head := 0
	while head < queue.size():
		var cur := int(queue[head])
		head += 1
		var cx := cur % grid.w
		var cy := cur / grid.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = cx + int(dx)
				var ny: int = cy + int(dy)
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var nt := ny * grid.w + nx
				if seen[nt] != 0:
					continue
				if not grid.can_step(cur, nt):
					continue
				seen[nt] = 1
				queue.append(nt)
	var lit := PackedInt32Array()
	for t in n:
		if seen[t] == 0:
			continue
		if not _standable(battle, t):
			continue
		lit.append(t)
	reach = lit
	_in_reach = {}
	for k in reach.size():
		_in_reach[int(reach[k])] = true


## **Whether anybody picked may end a walk on this 조각.** ⚠ **`can_hold` is asked per picked body and
## not once**, because a body already standing there is admitted by a 조각 that is otherwise full —
## and a hand holding that body must still see its own 조각 lit.
func _standable(battle: Battle, tile: int) -> bool:
	var grid := battle.grid
	if grid.passable[tile] != 1:
		return false
	if Grid.is_stair_level(grid.level_of(tile)):
		return false
	for k in ids.size():
		if grid.can_hold(tile, int(ids[k])):
			return true
	return false


## **One seat per picked body, `ids`-aligned**, nearest the pressed 조각 first.
##
## ⚠⚠ **THIS IS THE 무리's FORMATION SEAM AND IT IS DELIBERATELY THE DUMBEST ONE THAT WORKS.** It
## takes the nearest standable 조각 outward from the press and hands them out in `ids` order. **The
## shape the roadmap already chose (아홉이 서는 모양, 6번) replaces the body of this function** — every
## caller above asks it the same question and none of them will need touching.
##
## ⚠ **With one body it returns exactly the pressed 조각**, which is why the common case has no
## rounding, no offset and no surprise: a single body goes precisely where it was told.
func _spread(battle: Battle, tile: int, want: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if want <= 0:
		return out
	out.append(tile)
	if want == 1:
		return out
	var grid := battle.grid
	var taken := {tile: true}
	var queue := PackedInt32Array()
	queue.append(tile)
	var head := 0
	while head < queue.size() and out.size() < want:
		var cur := int(queue[head])
		head += 1
		var cx := cur % grid.w
		var cy := cur / grid.w
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = cx + int(dx)
				var ny: int = cy + int(dy)
				if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
					continue
				var nt := ny * grid.w + nx
				if taken.has(nt):
					continue
				if not can_reach(nt):
					continue
				taken[nt] = true
				queue.append(nt)
				if out.size() < want:
					out.append(nt)
	# ⚠ **A hand bigger than the room around the press is not an error.** The bodies with no seat
	# simply keep the one they have — `order` stops at `seats.size()` and reports the smaller number.
	return out


## The 조각 a body stands on, or -1 when it is off the board.
func _tile_of(battle: Battle, soldier_id: int) -> int:
	if battle == null or battle.grid == null:
		return -1
	if soldier_id < 0 or soldier_id >= battle.soldier_pos.size():
		return -1
	var p: Vector2 = battle.soldier_pos[soldier_id]
	var tx := int(floor(p.x))
	var ty := int(floor(p.y))
	if tx < 0 or ty < 0 or tx >= battle.grid.w or ty >= battle.grid.h:
		return -1
	return ty * battle.grid.w + tx


func _forget_routes() -> void:
	_route_tile = -1
	_routes = []
