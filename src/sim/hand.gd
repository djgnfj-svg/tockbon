class_name Hand
extends RefCounted
## **What the player has hold of, and where it may go.**
##
## ⚠⚠ **THE WHOLE OF THE EXTENSION THE USER ASKED FOR IS THAT `ids` IS A LIST** (2026-08-31, the user:
## 「선택한게 캐릭터든 그룹이든 할 수 있게 확장성 있게 작업해 달라고」). Today the press puts ONE body in
## it. The day a 부대 exists the same press puts nine in it and **nothing below this line changes**:
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
##  1. press a body  -> `pick`   — the reach lights up
##  2. press a lit 칸 -> `order` — everybody picked walks there
##  3. press anything else -> `clear`
##
## ⚠⚠ **STEP 2 WAS A 조각 UNTIL 2026-09-01** (the user: "let us do it by the block"). **`order`,
## `routes` and `route_points` take a 칸; `reach`, `can_reach` and the picture's mask are still 조각.**
## Both units are bare `int` and a 조각 index passed as a 칸 lands on a real place somewhere else on
## the board with nothing going red, so **every parameter and every local in here says which one it
## is** — that naming is the only guard there is.
##
## ⚠⚠ **THE TAB THE USER MENTIONED WAS ALREADY IN THE GAME AND IT IS NOT A COMMIT KEY.** It is
## `field_view.set_pads_revealed`, held to show the whole board. **No reservation step was added** —
## a walk order still fires the instant the destination is pressed, which is what 2026-08-25 settled
## (「손은 전투 중에도 움직인다」) and what `commit-before-the-fight-not-during` records.


## **The bodies under the player's command right now**, as soldier ids into `Battle`'s columns.
## Empty is 「nothing picked」 and is the resting state.
var ids := PackedInt32Array()

## **Every 조각 the picked bodies may be POINTED at**, ascending. ⚠ **This is what lights up**, and it
## asks two things only: the 조각 is passable, and it is not a stair — a stair is walked THROUGH and
## never stood on.
##
## ⚠⚠ **A FULL 칸 IS IN HERE, AND IT WAS NOT UNTIL 2026-09-01** (the user: "let's do it by block unit",
## and "the order goes out even when it is full, and if the 칸 holds enemies they fight"). **The old
## rule was written on this very line: 「a 조각 whose 블록 already holds nine is not somewhere anybody
## may be sent」**, and `_standable` enforced it by asking `Grid.can_hold`. A 칸 holding nine went dark,
## fell out of `reach_blocks`, and both `order` and the shell refused the press.
##
## ⚠⚠ **THIS IS 「WHERE MAY I POINT」 AND NOT 「WHERE MAY A BODY STAND」.** Those were one question until
## that day and they are two now: `Grid.can_hold` is still the walker's admission test, `_seats` still
## honours `Rules.BLOCK_CAPACITY`, and the surplus is seated in a neighbouring 칸 rather than the order
## being refused.
##
## ⚠ **The capacity answer that used to live here was stale anyway.** `_build_reach` runs once, at
## `pick_many`, and is never rebuilt — so the moment anybody walked, the lit set was answering a
## question about a board that had moved on. Capacity now decides nothing about what lights.
var reach := PackedInt32Array()

## `reach` again as a set, so `can_reach` is one lookup instead of a scan. **Rebuilt with `reach` and
## never separately** — two containers that can disagree about the same fact is how a lit 조각 refuses
## a press.
var _in_reach := {}

## **Every 칸 the picked bodies may be ORDERED onto**, ascending — `reach` collapsed through
## `Grid.block_of` and deduped.
##
## ⚠⚠ **TWO NAMES, TWO UNITS, AND MIXING THEM GOES NOWHERE NEAR RED.** `reach` is 조각 and stays 조각:
## the mask the picture reads (`field_view.set_reach`) is 조각-strided and the shader collapses four
## texels into a 칸 by itself. **A 칸 index handed to a 조각-keyed reader lands on a real 조각 somewhere
## else on the board** — a plausible number for the wrong place, which is this repo's own named false
## green.
##
## ⚠ **A 칸 is in here when ANY of its 조각 is in `reach`**, which is the same union `reach` already is
## across the picked bodies.
var reach_blocks := PackedInt32Array()

## `reach_blocks` again as a set, so `can_reach_block` is one lookup instead of a scan. **Rebuilt with
## it and never separately**, for the reason `_in_reach` gives.
var _in_reach_block := {}

## **What `routes` last answered, and the two lists the answer is a function of** — the seats it drew
## to, and the 조각 the bodies were standing on. **A hover asks for the same route many frames running**,
## and the walk down a flow field is the one cost in here worth not paying twice.
##
## ⚠⚠ **IT WAS KEYED ON THE 칸 ALONE UNTIL 2026-09-01 AND THAT CACHE WAS A LIAR** (measured that day,
## driving `Hand` headless with `.new()`). `_route_block` held the pressed 칸 and nothing else, so **the
## preview and the press disagreed the moment anything moved**: hover a 칸, let nine bodies fill it,
## hover again — the preview still ended on 조각 54 while `order` seated the 부대 on 조각 41. **Three
## bodies, three wrong lines, and nothing anywhere went red.**
##
## ⚠⚠ **WHY THE OLD KEY WAS SOUND AND STOPPED BEING SOUND.** `_spread` — deleted the same day, see
## `order` — read only `reach`, which is frozen at the pick, so its answer could not change while the
## hand was held. **`_seats` reads LIVE occupancy** through `Grid.hold_count` and `Grid.block_hold_count`,
## and that moves every frame: bodies walk, and `battle.gd` holds every 짐승 in `grid.reserved` too.
## **The 칸 was still a good name for the question; it stopped being a name for the answer.**
##
## ⚠⚠ **THESE TWO ARE THE WHOLE OF WHAT THE LINES DEPEND ON, AND THAT IS WHY THE KEY IS COMPLETE.**
## A line is `Grid.path_from` + `Grid.string_pull` over `Battle.field_to(dest)`, and a flow field reads
## passability, level and stairs — **never `reserved`** — so the ground is the only other input, and the
## ground does not move inside one island. **Seats plus starts pin the rest.**
##
## ⚠ **The starts are in here for a second staleness of the same cache.** Keyed on the 칸, a line built
## while a body stood at the door kept every 조각 he had since walked past, so the drawn line ran
## BACKWARDS from his feet to where he used to be. A moved start is now a miss, which is what it is.
##
## ⚠ **No sentinel, and none is needed.** `ids` is never empty when these are written, so a rested
## `_route_starts` is empty and cannot equal a live one.
var _route_seats := PackedInt32Array()
var _route_starts := PackedInt32Array()
var _routes: Array = []


## **Lets go of everything.** ⚠ Called on any press that is neither a body nor a lit 조각, which is
## what makes 「press the sea to deselect」 true by construction rather than by a special case.
func clear() -> void:
	ids = PackedInt32Array()
	reach = PackedInt32Array()
	_in_reach = {}
	reach_blocks = PackedInt32Array()
	_in_reach_block = {}
	_forget_routes()


func is_empty() -> bool:
	return ids.is_empty()


func has(soldier_id: int) -> bool:
	return ids.has(soldier_id)


## **Picks one body.** The single-body door, and it is a one-line wrapper over the list door on
## purpose — see the header. A caller that wants a 부대 calls `pick_many` and gets the same behaviour.
func pick(battle: Battle, soldier_id: int) -> bool:
	var one := PackedInt32Array()
	one.append(soldier_id)
	return pick_many(battle, one)


## **Picks a whole list.** ⚠ **Ids that are not ashore are dropped rather than refused** — a 부대 with
## one dead member is still a 부대, and refusing the lot would make death a selection bug.
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


## **Whether the picked bodies may be ordered onto this 칸.** ⚠ **The 칸 twin of `can_reach`, not its
## replacement** — the two take different units and both are live. See `reach_blocks`.
func can_reach_block(block: int) -> bool:
	return _in_reach_block.has(block)


## **Where the picked bodies stand right now**, one 조각 each and in `ids` order. ⚠ **A body whose
## position is off the board answers -1 rather than being dropped**, so this list and `ids` are always
## the same length and index the same body.
func from_tiles(battle: Battle) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in ids.size():
		out.append(_tile_of(battle, int(ids[k])))
	return out


## ⚠⚠ **`body_at` STOOD HERE AND IT IS DELETED** (2026-09-02, the user: 「몸은 화면에서 잡자」 —
## *"let us pick the body on the glass"*, ticket 03-16). It answered 「which body did a press land on」
## as the nearest `soldier_pos` within a radius of a ground point in 조각 units, and its header said
## 「the shell converts」 — **the shell converted into the other 조각 convention, half a 조각 off, and
## nothing measured it** (this function appeared in no net at all). A body is drawn standing UP from its
## feet, so the ground under a press on the chest is behind the feet by `h / tan(pitch)` 조각 in a
## direction that turns with the board — **no radius on the ground answers a head at pitch 20°.**
## ⇒ `FieldView.body_at_px` answers from the drawn picture. **`pick` stays**: the pick is still a sim
## fact; only 「which body is under the finger」 moved to the glass.


## **Sends everybody picked onto `block`, and answers how many actually went.**
##
## ⚠⚠ **`block` IS A 칸 AND IT WAS A 조각 UNTIL 2026-09-01** (the user: "let us do it by the block").
## **A 조각 index handed in here compiles, runs, and seats the 부대 on the wrong quarter of the board.**
## Callers convert with `Grid.block_of` before they get here, and the shell gates on `can_reach_block`
## with the same converted number it passes.
##
## ⚠ **WHAT GOES OUT IS STILL 조각.** `Battle.order_walk` takes one square metre per body and is
## untouched by this — `_seats` is the only thing in the game that crosses from the aimed 칸 to the
## 조각 a body actually stands in.
##
## ⚠⚠ **ONE BODY DOES NOT GET 「THE PRESSED 조각」 ANY MORE, BECAUSE THERE ISN'T ONE.** With the ground
## marks one per 칸 the press carries no sub-칸 information at all, so even a single body is seated by
## `_seats` inside the 칸 rather than dropped on a square the player picked out.
##
## ⚠⚠ **`_spread` STOOD HERE AND IT IS DELETED** (2026-09-01). It handed out one DISTINCT 조각 per
## body, spreading outward from the pressed 조각 — a contract a 칸 cannot use, because a 칸 is four
## 조각 and holds nine bodies, so three of them share a 조각 and no distinct-조각 list can say so.
## **`_seats` is the seam the 부대's own formation plugs into now** — the roadmap has the shape for
## nine standing bodies already chosen as shape 6, and when it is built it replaces the body of that
## one function and nothing else here.
##
## ⚠⚠ **AND THE ORDER WRITES WHICH WAY THAT SHAPE FACES** (2026-09-02, the user: 「격자는 명령
## 방향으로」, ticket 03-17). `Battle.block_face[block]` becomes the unit vector from the centroid of the
## ordered bodies' positions — where they stood when the press landed — to the 칸's middle. **Written
## before the walks go out and from positions read at this instant**, so nine bodies streaming in over
## two seconds all arrive onto one lattice. A centroid already AT the middle (a 부대 spread over the
## 칸 and told to stay) leaves the facing as it was rather than writing a zero.
## ⚠ **The 칸's middle is the mean of its 조각 asked of the grid**, never `block + 0.5`: a truncated
## 칸 at the board's edge has two 조각, and its middle is the middle of those two.
func order(battle: Battle, block: int) -> int:
	if battle == null or battle.grid == null or ids.is_empty():
		return 0
	if not can_reach_block(block):
		return 0
	var seats := _seats(battle, block, ids.size())
	var centroid := Vector2.ZERO
	for k in ids.size():
		centroid += battle.soldier_pos[int(ids[k])] as Vector2
	centroid /= float(ids.size())
	var toward := _block_middle(battle.grid, block) - centroid
	if toward.length() > Rules.EPS:
		battle.block_face[block] = toward.normalized()
	var sent := 0
	for k in ids.size():
		if k >= seats.size():
			break
		if battle.order_walk(int(ids[k]), int(seats[k])):
			sent += 1
	_forget_routes()
	return sent


## **The middle of a 칸 in `soldier_pos` units** — the mean of the 조각 the grid names for it. ⚠ Asked
## of `Grid.tiles_of_block` rather than decoded here, for the reason that function's header gives: the
## low-corner decode has been hand-copied three times outside `src/` and every copy could disagree.
func _block_middle(grid: Grid, block: int) -> Vector2:
	var tiles := grid.tiles_of_block(block)
	if tiles.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for k in tiles.size():
		var t := int(tiles[k])
		sum += Vector2(float(t % grid.w), float(t / grid.w))
	return sum / float(tiles.size())


## **The line each picked body would walk onto `block`** — one 조각 list per body, in `ids` order, and
## the whole of the 이동선 the user asked to see before committing to it (2026-08-31: "when moving, I
## would like the movement line to be shown in advance").
##
## ⚠⚠ **THE INVARIANT, AND IT IS THE ONLY REASON THIS FUNCTION EXISTS: the last 조각 of body `k`'s line
## is the 조각 `order` would send body `k` to, for the board as it stands at the moment of the call.**
## Both go through one `_seats`, and **`routes` recomputes it every call rather than remembering it** —
## so a press one frame after a hover reads the same occupancy the hover read. **A preview built any
## other way is a promise the walk does not keep.**
##
## ⚠⚠ **`block` IS A 칸; THE LISTS THAT COME BACK ARE 조각.** The aim and the walk are in different
## units and always were — this only moved the aim. See `order` for what a 조각 passed in here does.
##
## ⚠ **It is the SAME route the walk will take and not a straight line drawn between two points.** It
## is built from `Battle.field_to` and `Grid.string_pull`, which is what `Battle.order_walk` itself
## calls — **the same cached field, not a second one that happens to be equal.**
## ⚠ **An empty list for a body means 「it is already there」**, not 「it cannot get there」; `order`
## refuses an unreachable 칸 before this is ever asked.
##
## ⚠⚠ **THE CACHE IS KEYED ON THE SEATS AND THE STARTS AND NOT ON THE 칸** (2026-09-01 — the 칸 key is
## the defect this rewrite closes; the measurement and the wrong numbers are on `_route_seats`).
## **Measured on the real island, 30x26 with 284 land 조각 and a 부대 of nine:**
##
## - `Grid.flow_field` **3.72 ms**, so nine bodies building their own is **37.6 ms a frame** — the old
##   miss, and 2.2 frames of a 60 Hz budget. **Dropping the cache outright costs exactly that**, every
##   frame, because `game.gd` asks for this line from `_process` and not only on a motion.
## - Sharing `Battle.field_to` takes the field out of the miss: a rebuild is **9 x 0.43 ms = 3.9 ms**.
## - A hit is `_seats` **0.030 ms** plus nine `_tile_of` **0.006 ms** — **0.04 ms**, and it is now
##   honest, where the 0.0004 ms it used to cost was the price of the wrong answer.
func routes(battle: Battle, block: int) -> Array:
	if battle == null or battle.grid == null or ids.is_empty():
		return []
	if not can_reach_block(block):
		_forget_routes()
		return []
	# ⚠⚠ **LIVE, BOTH OF THEM, BEFORE ANY CACHE IS CONSULTED.** These two ARE the key — computing them
	# is what makes the key true, and skipping straight to a remembered answer is the whole bug.
	var seats := _seats(battle, block, ids.size())
	var starts := from_tiles(battle)
	if seats == _route_seats and starts == _route_starts:
		return _routes
	var out: Array = []
	for k in ids.size():
		var line := PackedInt32Array()
		if k < seats.size():
			var here := int(starts[k])
			var dest := int(seats[k])
			if here >= 0 and here != dest:
				var raw := battle.grid.path_from(battle.field_to(dest), here, dest)
				if raw.size() > 1:
					line = battle.grid.string_pull(raw)
		out.append(line)
	_route_seats = seats
	_route_starts = starts
	_routes = out
	return out


## **The same routes as POINTS in 조각 units**, one list per picked body, and what the view draws.
##
## ⚠⚠ **`block` IS A 칸 GOING IN AND THE POINTS ARE 조각 COMING OUT**, which is `routes`' own split and
## not a second one. **Nothing about the output changed on 2026-09-01** — only what is aimed at.
##
## ⚠⚠ **THE UNITS ARE `soldier_pos`'s OWN**, corner-anchored, so a caller turns one into world px with
## `Look.tile_point_px` exactly as it does for a body. **Anything that half-tiles them here instead
## puts the line half a 조각 off the bodies walking it.**
##
## ⚠⚠ **THE FIRST POINT IS THE BODY'S OWN POSITION AND NOT ITS 조각's CENTRE.** Bodies stand three to
## a 조각 and off its middle, so a line starting at the centre visibly leaves from beside the feet it
## belongs to — with nine of them that reads as nine lines starting nowhere in particular.
##
## ⚠ **A list of one point draws nothing**, which is exactly right for a body already standing on its
## destination.
func route_points(battle: Battle, block: int) -> Array:
	var lines := routes(battle, block)
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
				# ⚠⚠ **NO `+ 0.5` HERE, AND IT WAS THERE FOR ONE ROUND** (2026-08-31, the user at the
				# screen: 「지금은 블록 가운데서 오는듯한데?」). These points are in the SAME units
				# `soldier_pos` is in — a 조각 index, corner-anchored — and the half that turns one into
				# a centre belongs to `Look.tile_point_px`, which every body and every shadow already
				# goes through. **Adding it here made the first point (a real `soldier_pos`) and the
				# rest disagree by half a 조각**, so the line left from beside the body instead of from
				# under him.
				pts.append(Vector2(float(t % w), float(t / w)))
		out.append(pts)
	return out


## **Floods out from the picked bodies and keeps every 조각 they may be POINTED at.**
##
## ⚠ **It said 「may STAND on」 until 2026-09-01**, when the capacity clause left `_standable` — a full
## 칸 is now pointed at and ordered onto, and where those bodies end up standing is `_seats`' answer,
## not this one.
##
## ⚠⚠ **THE FLOOD AND THE FILTER ARE TWO DIFFERENT TESTS AND THAT IS DELIBERATE.** A stair is walked
## across, so it stays in the flood and lets the way past it open; it is not stood on, so it is not in
## `reach`. Folding the two into one test would wall off every upper storey, because a stair is the
## only door there is.
##
## ⚠ **The union, for a 부대 — and it is the FLOOD that is the union now.** A 조각 one member can walk
## to lights even if another cannot; the order then seats that member elsewhere, which `_seats` already
## does. **The filter stopped being a union the day it stopped asking about bodies at all.**
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
	# ⚠ **The 칸 view of the same flood, built HERE and nowhere else.** Two containers that can
	# disagree about the same fact is how a lit 칸 refuses a press — see `reach_blocks`.
	reach_blocks = PackedInt32Array()
	_in_reach_block = {}
	for k in reach.size():
		var bk := grid.block_of(int(reach[k]))
		if bk < 0 or _in_reach_block.has(bk):
			continue
		_in_reach_block[bk] = true
		reach_blocks.append(bk)
	# ⚠ **Sorted rather than trusted to come out ascending.** Row-major 조각 order happens to hand back
	# ascending 칸 today; that is a property of the loop above and not of the promise the field makes.
	reach_blocks.sort()


## **Whether this 조각 may be pointed at: passable, and not a stair.** Two questions, and there is no
## third one.
##
## ⚠⚠ **IT ASKED CAPACITY UNTIL 2026-09-01 AND THE USER TOOK THAT AWAY** ("let's do it by block unit",
## and "the order goes out even when it is full, and if the 칸 holds enemies they fight"). **What stood
## here was a `grid.can_hold(tile, id)` union over `ids`** — true when ANY picked body would be
## admitted, so that a hand holding a body still saw its own otherwise-full 조각 lit. `Grid.can_hold`
## folds in `block_has_room`, so that one clause is what made a 칸 holding nine go dark and the press
## bounce.
##
## ⚠⚠ **THE CEILING DID NOT MOVE — THE LIGHTING DID.** `Rules.BLOCK_CAPACITY` is still nine,
## `Grid.can_hold` is still what admits a walker at every step, and `_seats` is what decides who fits
## and pushes the surplus into a neighbouring 칸. **Deleting this clause here without `_seats` in place
## would have sent an order into a full 칸 that seated nobody and was then eaten by the stall-clear.**
##
## ⚠ **`battle` is still the parameter and not `grid`**, because `_build_reach` is the only caller and
## the rest of this file passes `battle` — a second convention for one file is how a reader stops
## trusting either.
func _standable(battle: Battle, tile: int) -> bool:
	var grid := battle.grid
	if grid.passable[tile] != 1:
		return false
	if Grid.is_stair_level(grid.level_of(tile)):
		return false
	return true


## **One seat per picked body, `ids`-aligned: inside the pressed 칸 first, spilling into a
## neighbouring 칸 only once the ceilings are used up.**
##
## ⚠⚠ **A SEAT MAY REPEAT A 조각, AND THAT IS THE WHOLE REASON `_spread` COULD NOT BE KEPT.** That
## function — deleted 2026-09-01, see `order` — handed out DISTINCT 조각, one per body. A 칸 is four
## 조각 and holds nine bodies (`Rules.BLOCK_CAPACITY`), so
## nine distinct 조각 inside one 칸 do not exist — three bodies stand in one 조각
## (`Rules.TILE_CAPACITY`) and this returns that 조각 three times.
##
## ⚠⚠ **THE HAND'S OWN BODIES ARE NOT COUNTED AS OCCUPANTS.** Everybody picked is being re-seated by
## this very call, so a 부대 of nine standing on a 칸 and ordered onto that same 칸 has to find nine
## seats there. Counting them would read the 칸 as full and push the whole 부대 out into the
## neighbours — **the press would EVACUATE the 칸 it aimed at.** `Grid.can_hold` already admits a body
## to the 조각 it is standing in for the same reason, seen from the walker's side.
##
## ⚠⚠ **THE SEATING INSIDE THE 칸 DOES NOT HONOUR WHICH QUARTER WAS PRESSED, AND THAT IS DELIBERATE.**
## Once the ground marks are one per 칸 the player cannot aim below a 칸, so a press carries no sub-칸
## information; reading the pressed 조각 here would make the destination depend on something the screen
## has stopped showing.
##
## ⚠⚠ **THE WALK OUTWARD ASKS `Grid.can_step`, AND IT DID NOT UNTIL 2026-09-01.** It gated a spill on
## `can_reach` alone — 「is that 조각 lit」 — and **two 조각 either side of a cliff are 8-way neighbours BY
## NUMBER while no body may cross between them.** Measured that day, driving `Grid`/`Battle`/`Hand`
## headless with `.new()`: a 12x6 board, columns 0-5 at level 0 and columns 6-11 at level 2 with one
## stair 조각 at (6,2); twelve bodies ordered onto the upper 칸 3 seated nine upstairs and dropped the
## surplus three on **조각 5, which is DOWNSTAIRS across the cliff edge**. The order went out, nothing
## went red, and the three walked the long way round through the stair to a place nobody aimed at.
##
## ⚠⚠ **`can_step` IS THE WALKER'S OWN QUESTION AND NOT A SECOND ONE.** `Grid.flow_field`,
## `Grid.path_from`, `Grid.string_pull` and `_build_reach`'s own flood all ask exactly it, so the spill
## cannot come to disagree with the route drawn for it — **a second reachability rule that drifts from
## the walker's is the named failure in `how-nets-lie`, not a hypothetical one.**
##
## ⚠ **The flood and the seating are two tests here, exactly as they are in `_build_reach`.** A stair is
## walked THROUGH and never stood on, so it rides the queue and hands the walk on without ever taking a
## body — folding the two into one test would seal the spill inside its own storey, because a stair is
## the only door there is.
##
## ⚠ **WHICH neighbouring 칸 takes the overflow is BFS discovery order, and nobody has chosen it.** The
## walk is the 8-way 조각 one `_spread` used, whose `dy`/`dx` table is an arbitrary tie-break inherited
## rather than picked. ⚠ **The cliff gate narrows that walk; it does not choose inside it.**
## **The 성채's 칸 seats eight and not nine** — `Grid.block_hold_count` counts the house as one body —
## so the ninth body's destination is on screen every time.
##
## ⚠ **Fewer seats than bodies is not an error.** The bodies with no seat keep the one they have; the
## caller stops at `seats.size()` and reports the smaller number.
func _seats(battle: Battle, block: int, want: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if want <= 0 or battle == null or battle.grid == null:
		return out
	var grid := battle.grid
	# Room left AS SEATS ARE HANDED OUT, so two 조각 of one 칸 cannot each spend the whole 칸 ceiling.
	var tile_room := {}
	var block_room := {}
	var queue := PackedInt32Array()
	var seen := {}
	# ⚠ **Every 조각 of the pressed 칸 is a seed, so all four are served before anything outside it.**
	# They sit at the head of the queue before the walk starts, which is what makes that true.
	# ⚠ **A seed is not asked `can_step` — there is nothing to step FROM.** The 칸 is what the player
	# aimed at, and `order` and `routes` both refused it already unless `can_reach_block` was true.
	for raw in grid.tiles_of_block(block):
		var t := int(raw)
		if not _walk_holds(grid, t):
			continue
		seen[t] = true
		queue.append(t)
	# ⚠⚠ **THE PRESSED 칸 IS SERVED ROUND-ROBIN OVER ITS 조각, AND IT WAS DRAINED ONE 조각 AT A TIME
	# UNTIL 2026-09-02** (ticket 03-17; the user at the screen: 「the characters ought to fill in
	# starting from the centre and that is not really working」). The loop below fills each 조각 to
	# `Rules.TILE_CAPACITY` before moving on, and `Grid.tiles_of_block` hands the 조각 back north-west
	# first — so three bodies all took the north-west 조각 and the pile stood in one corner of the 칸.
	# **Here one seat goes to each 조각 in turn** while any has room and the 칸 has room, so three
	# bodies land in three quarters and the seat lattice `Grid` hands them on arrival is the centre and
	# two edges rather than one 조각's three. ⚠ **Only the pressed 칸.** A spill 칸 below is still
	# drained in discovery order — which neighbouring 칸 takes the surplus was never chosen (see the
	# header) and this does not choose it either.
	var pressed_room := _room_in_block(grid, block)
	block_room[block] = pressed_room
	var served := true
	while out.size() < want and int(block_room[block]) > 0 and served:
		served = false
		for k in queue.size():
			var t := int(queue[k])
			if out.size() >= want or int(block_room[block]) <= 0:
				break
			# A stair 조각 inside the 칸 rides the queue and takes nobody — the same split as below.
			if not can_reach(t):
				continue
			if not tile_room.has(t):
				tile_room[t] = _room_in_tile(grid, t)
			if int(tile_room[t]) <= 0:
				continue
			out.append(t)
			tile_room[t] = int(tile_room[t]) - 1
			block_room[block] = int(block_room[block]) - 1
			served = true
	var head := 0
	while head < queue.size() and out.size() < want:
		var cur := int(queue[head])
		head += 1
		# ⚠ **A stair rides the queue and takes nobody.** It is in here to hand the walk on, which is
		# the same split `_build_reach` makes between its flood and its filter.
		if can_reach(cur):
			var bk := grid.block_of(cur)
			if not tile_room.has(cur):
				tile_room[cur] = _room_in_tile(grid, cur)
			if not block_room.has(bk):
				block_room[bk] = _room_in_block(grid, bk)
			while out.size() < want and int(tile_room[cur]) > 0 and int(block_room[bk]) > 0:
				out.append(cur)
				tile_room[cur] = int(tile_room[cur]) - 1
				block_room[bk] = int(block_room[bk]) - 1
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
				if seen.has(nt):
					continue
				# ⚠⚠ **THE CLIFF GATE, AND IT IS THE WALKER'S OWN.** Without it a 조각 over a tier
				# edge is a neighbour by arithmetic and the surplus lands where no body may go.
				if not grid.can_step(cur, nt):
					continue
				if not _walk_holds(grid, nt):
					continue
				seen[nt] = true
				queue.append(nt)
	return out


## **Whether the spill's walk may hold this 조각 at all** — it is somewhere a picked body may be
## pointed, or it is a stair the walk crosses to get somewhere that is.
##
## ⚠ **`can_reach` carries the flood from the bodies with it**, so a 조각 in a component none of them
## can enter is refused here and never seated. **A stair is the one thing outside `reach` that is let
## through**, for the reason `_build_reach`'s own header gives: it is the only door between storeys.
func _walk_holds(grid: Grid, tile: int) -> bool:
	if can_reach(tile):
		return true
	return grid.passable[tile] == 1 and Grid.is_stair_level(grid.level_of(tile))


## **How many more bodies this 조각 would take, the hand's own not counted.** See `_seats` for why they
## are not counted; `Rules.TILE_CAPACITY` is the ceiling.
func _room_in_tile(grid: Grid, tile: int) -> int:
	var n := grid.hold_count(tile)
	for k in ids.size():
		if grid.slot_of(tile, int(ids[k])) >= 0:
			n -= 1
	return Rules.TILE_CAPACITY - n


## **How many more bodies this 칸 would take, the hand's own not counted.**
##
## ⚠ **A body mid-step holds two 조각 and must still count ONCE**, which is why the id is looked for
## across the whole 칸 and the search stops at the first 조각 holding it — the same distinct-id contract
## `Grid.block_hold_count` keeps on the other side of the subtraction.
func _room_in_block(grid: Grid, block: int) -> int:
	var n := grid.block_hold_count(block)
	var tiles := grid.tiles_of_block(block)
	for k in ids.size():
		var who := int(ids[k])
		for raw in tiles:
			if grid.slot_of(int(raw), who) >= 0:
				n -= 1
				break
	return Rules.BLOCK_CAPACITY - n


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


## **Throws the remembered answer away.** ⚠ **Both lists together** — a kept `_route_starts` beside an
## emptied `_route_seats` is a key that can half-match, and half a key is no key.
func _forget_routes() -> void:
	_route_seats = PackedInt32Array()
	_route_starts = PackedInt32Array()
	_routes = []
