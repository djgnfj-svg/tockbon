extends RefCounted
## What a boat does.
##
## ⚠⚠⚠ **THIS FILE HAS BEEN GUTTED AND THE HOLE IS REAL — READ THE BLOCK ABOVE
## `_the_drag_is_really_gone` BEFORE TRUSTING A GREEN ROUND ABOUT BOATS.** Every crossing check here
## was driven through `Battle.send`, which put one dragged body on a boat departing from a HARBOUR.
## **The drag was deleted, `send` lost its last caller in `src/`, and `send` is now deleted too.** The
## checks went with their driver, because a check whose driver does not exist cannot be rewritten to
## pass without inventing a subject.
##
## ⚠⚠ **The behaviour they measured is STILL LIVE, and most of it is now UNMEASURED.** `_phase_boats`,
## `_phase_landings`, `_try_unload`, `_free_tiles_from`, `leg`, `cum` and the return leg all still run —
## `Battle.summon` fills `boats` and the whole crossing machinery reads from there. **Nothing in this
## file measures any of it any more.** `net_summon` covers the route, the refusals, the return to sea
## and a two-tile unload; it does not cover the crossing arithmetic, `leg` monotonicity, the hull being
## over water on every sub-step, or the reversal bookkeeping. That list is written out in full below so
## the gap is a thing somebody can pick up, not a silence.
##
## ⚠ **Rebuilding those rows on `summon` needs new fixtures and every literal re-derived**, because a
## summoned boat starts on open water inside a band rather than at a harbour tile. **That is not a
## rename.** It also needs `Rules.SUMMON_BAND_MIN_TILES` to hold still first — the code says 3 and
## `net_summon` asserts 6, so the band's own numbers are in motion.


func run(t) -> void:
	_the_one_surviving_number(t)
	_the_drag_is_really_gone(t)


# -- the one number left of the old table ------------------------------------------------------------

## `Rules.BOATS` and its four accessors were deleted whole (`plan-then-watch`, 3.1): with unlimited
## boats there is no capacity column, no name column and no count. **The literal is written out, never
## read back off the constant it checks.**
##
## ⚠ **It survived the harbour deletion untouched** because it never went near a harbour: a summoned
## boat sails at exactly this speed and `_phase_boats` reads it from the same place.
func _the_one_surviving_number(t) -> void:
	t.eq(Rules.BOAT_SPEED, 4.0, "배 속력은 4.0 이다")


## ⚠⚠ **Every deletion needs a check that the thing is GONE.** A green round after deleting a rule
## proves nothing about the deletion — the checks that drove it were deleted in the same edit, so
## "nothing red" is exactly what a deletion that never happened would also look like.
##
## ⚠⚠ **THE RECORD OF WHAT THIS FILE MEASURED, AND WHAT IS NOW UNMEASURED.** Each entry names the LIVE
## behaviour it was the only reader of. `plan-then-watch`'s 결정 14R had already deleted the boat table
## whole — a boat is created by one press, carries one body, sails, unloads and sails home to nothing —
## so none of this was ever about capacity or fleet identity.
##
##  · **`_crossing_arithmetic_is_literal`** — ⚠⚠ **THE ONLY CHECK IN THE FILE WHOSE NUMBERS WERE BARE
##    LITERALS, and its own comment said why every other one was weaker**: they computed their
##    expectation from `boats[0]["dist"]`, the thing under test, so **doubling `dist` at creation,
##    arriving at half the real distance, or halving the lerp rate in `_phase_boats` were all invisible
##    to them.** It hand-computed the hull's position 30 sub-steps in: 0.5 s at speed 4.0 is 2.0 tiles
##    along a route whose vertices sit at 0, 3.16227766, 4.57649122, so 2.0 falls inside segment 0 at
##    `f = 2.0/sqrt(10) = 0.63245553`, giving `(2,5).lerp((5,4), f) = (3.8973666, 4.3675445)`.
##    **`_phase_boats`'s arc-length walk has no other literal check anywhere in the repo.**
##
##  · ⚠⚠ **THE STORY OF `BAY_DIST`, AND IT IS THE MOST EXPENSIVE THING ON THIS PAGE.** A hop-count BFS
##    does not produce the straight line even where one exists: over the open bay the descent gave
##    `(2,5) (3,4) (4,3) (5,4) (6,5)` — four diagonal steps, `4 x sqrt(2) = 5.656854` tiles against a
##    **4.0-tile straight line**. Verify-look photographed the same shape on island 1's bay and named
##    it: **a boat that does not know the way.** String-pulling fixed it — `(2,5) (5,4) (6,5)`, 3
##    points, `sqrt(10) + sqrt(2) = 4.57649122`, arriving on sub-step **69** rather than 85. ⚠ **It is
##    still not the 4.0 straight line and that is NOT a smoothing failure**: the route's last water
##    tile is the CHEAPEST water neighbour of the landing, ties to the earliest `NEIGHBOURS` entry —
##    (5,4) rather than (5,5) — so the final hop is a one-tile dogleg onto the beach. **Which water
##    tile a boat beaches FROM is a different rule from smoothing, and `summon_landing` decides it now.**
##    ⚠ **The literals were re-measured twice and never relaxed.** The far bay went the same way:
##    `13 + 2*sqrt(2) = 15.656854` over 15 points, arriving on 235, became `sqrt(170) + sqrt(2) =
##    14.45261837` over 3 points, arriving on **217**.
##
##  · **`_crossing_scales_with_distance`** — arrival time is proportional to route length, there being
##    one speed. ⚠⚠ **Its tolerance carries a fake-green lesson worth more than the row.** It was 0.01
##    and it held only because the two crossings happened to round the same way; the smoother exposed
##    that (217/69 = 3.1449 against 14.452618/4.576491 = 3.1580, a gap of 0.0131). **The replacement
##    0.05 was DERIVED, not nudged until it passed**: both counts are whole sub-steps ceiling'd off a
##    real crossing time, so each carries up to one sub-step of rounding and the error on the ratio is
##    bounded by `ratio / near_steps = 3.158 / 69 = 0.046`.
##
##  · **`_the_boat_really_sails_on_water`** — 「배가 도착했다」는 「배가 물 위로 갔다」가 아니다.
##    ⚠⚠ **Endpoint-only checks pass a boat that teleports across the island**, which is `how-nets-lie`'s
##    *a ceiling with no floor* in its exact shape. It drove one sub-step at a time and read the hull's
##    rounded tile on every one, with **the LANDING tile exempt and nothing else** — the route's last
##    waypoint IS the beach, so the final segment legitimately carries the hull over it. ⚠ **The
##    exemption was one tile wide rather than "the last few sub-steps"** precisely so a route cutting a
##    corner across the island two sub-steps earlier still reddened. Its two floors: **`still == 0`** (a
##    boat parked at its origin satisfies "every position was water" perfectly) and **more than 2
##    distinct tiles visited** (2 tiles is the origin and the destination, which is a straight line).
##
##  · **`_leg_only_goes_forward`** — `leg` is the sim's bookmark into `path` and the VIEW draws the
##    remaining route off it, so a `leg` that never advances leaves the hull on segment 0 while `t` runs
##    out, and one that jumps back redraws water already crossed. ⚠⚠ **Only OUTBOUND sub-steps could be
##    read**: `_phase_boats` runs BEFORE `_phase_landings` inside one sub-step, so on the arrival
##    sub-step `leg` reaches its last segment and is then reset to 0 by the turn to RETURNING — reading
##    past that point measures the return leg's fresh bookmark and reports it as `leg` going backwards.
##    Its ceiling was `top_leg == path.size() - 2` (it does not index past the end) and its floor was
##    `top_leg > 0` (it actually advanced).
##
##  · **`_return_leg_is_the_outbound_path_reversed`** — 돌아가는 배는 왔던 항로를 그대로 뒤집는다,
##    다시 계산하지 않는다. Point-by-point reversal, `dist` unchanged (a reversed polyline is exactly as
##    long), `t` and `leg` both back to 0, and **`cum` REBUILT** — a prefix sum is not symmetric under
##    reversal unless every segment is. Its last row is the one that matters: `cum[cum.size()-1] ==
##    dist`, because **a prefix sum that does not match its route makes the boat teleport.**
##
##  · **`_return_leg_is_simulated`** — the empty boat SAILS home and is removed on arrival. ⚠ **Its
##    floor was one sub-step of `t > 0.0`**: without it, "boats is empty at the end" is also satisfied by
##    a boat deleted on the unload sub-step.
##
##  · **`_boats_do_not_share`** — thirteen boats, one body each, thirteen distinct uids.
##
##  · **`_unload_placement`** — four boats aimed at ONE tile arrive on the same sub-step and each asks
##    `_free_tiles_from` after the one before it has reserved its own; **the first one placed takes the
##    target tile** and the rest take neighbours, each reserved under its own id. ⚠ **Positions were
##    rounded to the tile, never compared as a raw `Vector2`**: `_phase_movement` runs in the SAME
##    sub-step as `_phase_landings`, so a body has already taken its first fraction of a step by the
##    time the row reads it, and an exact comparison measures walk speed rather than the landing.
##
##  · **`_boat_waits_for_shore`** — three free tiles, four boats: three land and the fourth **stays
##    OUTBOUND on the water rather than standing on somebody**, because landing part of a load would
##    silently reorder the deployment the player chose. Its floor was the three that DID land.
##
##  · **`_cargo_rides_the_boat`** — a body aboard shares the hull's position exactly, **is hit and
##    cannot hit back**: the crow's HP is untouched after 18 sub-steps in range while the body's is not.
##
##  · **`_send_refusals` / `_a_refused_drop_makes_no_boat`** — six refusals measured from the BOAT's
##    side (`boats` never grew), which is **the half that stays green if the call refuses AFTER
##    appending**. `net_plan` measured the same six from the plan's side. `net_summon`'s
##    `_seven_refusals` is the live successor.
##
##  · **`_reach_is_per_harbour` / `_relocation_sends_the_boat_to_the_right_harbour`** — ⚠⚠ **BOTH HAD
##    ALREADY GONE GREEN WHILE MEASURING NOTHING ONCE, AND THE FIX IS THE LESSON.** Their fixture was a
##    one-tile `#` peninsula, and it worked only because a STRAIGHT line was blocked by it; once routes
##    became 8-connected water a boat sails around any peninsula, so every harbour reached every shore
##    and both rows passed for the wrong reason. **What still separates two water origins is a land BAR
##    that makes one route long, or genuinely disconnected water** — never a peninsula. Fixture that
##    replaced it, for the beach at (2,3): harbour (10,0) straight **8.544** / **7 hops**, harbour (2,6)
##    straight **3.000** / **24 hops** — so the nearest one is the wrong one.
func _the_drag_is_really_gone(t) -> void:
	var b := Battle.new()
	t.ok(not b.has_method("send"),
		"battle 에 send 가 없다 — 몸을 끌어다 배에 태우던 그 호출이고, 항구가 거기 딸려 있었다")
	t.ok(not b.has_method("harbour_count"), "battle 에 harbour_count 도 없다")
	t.ok(not b.has_method("harbour_tile"), "battle 에 harbour_tile 도 없다")

	# The floor, and it is the whole point: boats did not die with the drag. If these go missing the
	# three rows above become "nothing has any methods" and stop meaning anything.
	t.ok(b.has_method("summon"), "배를 만드는 건 이제 summon 이다 (자가 점검)")
	t.ok(b.has_method("recall"), "물러 무르기도 그대로다 (자가 점검)")
	t.ok(b.has_method("commit"), "시작 버튼도 그대로다 (자가 점검)")
	t.eq(b.boats.size(), 0, "새 battle 의 boats 는 비어 있다 (자가 점검 — 배 배열 자체는 살아 있다)")

	var g := Grid.new()
	t.ok(not g.has_method("water_route"),
		"grid 에 water_route 도 없다 — 항구에서 해안까지 배를 태워 보내던 그 항로다")
	t.ok(not g.has_method("home_harbour_for"), "grid 에 home_harbour_for 도 없다")
	t.ok(g.has_method("summon_route"), "대신 summon_route 가 있다 (자가 점검)")
