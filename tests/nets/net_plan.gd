extends RefCounted
## The planning state: an island that cannot be advanced until it is committed, a plan authored one
## press at a time and freely undone, and a fight that computes the same whatever rate it is watched
## at. **No Node, no view, no shell.** The design is `plan-then-watch`.
##
## ⚠⚠⚠ **THIS FILE HAS BEEN GUTTED AND THE HOLE IS REAL — READ THE BLOCK ABOVE
## `_the_plan_is_no_longer_authored_by_a_drag` BEFORE TRUSTING A GREEN ROUND ABOUT THE PLAN OR ABOUT
## `Battle.step`.** Every fixture here was authored with `Battle.send`, which put one dragged body on a
## boat departing from a HARBOUR. **The drag was deleted, `send` lost its last caller in `src/`, and
## `send` is now deleted too.** A plan cannot be authored in this file any more, so `commit()`, which
## refuses an empty plan, cannot be reached — and every row downstream of a commit went with it.
##
## ⚠⚠ **WHAT DIED IS NOT THE PLAN — IT IS THE ONLY WAY THIS FILE COULD BUILD ONE.** `commit`, `recall`,
## `committed` and `boats` are all still live; `Battle.summon` fills `boats` now. **Rebuilding these
## rows means re-authoring every fixture through `summon`, which needs a press point inside the band**
## (water, at least `Rules.SUMMON_BAND_MIN_TILES` hops from any shore, inside `summon_radius()`) rather
## than a landing tile on the coast. ⚠ **That is not a rename**: on this file's own 24x12 bay only two
## tiles satisfy it at the code's current minimum of 3, and NONE do at the 6 `net_summon` asserts — so
## the band's own constant has to stop moving before a fixture built on it can be trusted.
##
## ⚠⚠ **THE HEAVIEST LOSS IS NOT A PLANNING ROW.** The sub-step equivalence rows — the same simulated
## span cut into different numbers of `dt` pieces landing on identical state — are what keep
## `battle.step(delta)` honest, and they needed a committed fight to have anything to compare. They are
## recorded below in full, including the instrument that read them, because **that instrument was
## inverted on purpose and catching it was worth more than any row it served.**


func run(t) -> void:
	_the_substep_itself_is_pinned(t)
	_the_plan_is_no_longer_authored_by_a_drag(t)


# -- the sub-step, pinned by literals ---------------------------------------------------------------

## ⚠⚠ **The equivalence rows did NOT pin the sub-step's value, and that was measured.** Setting
## `SIM_SUBSTEP_SEC` to 1/20 left every one of them green — correctly, because additivity over `dt` is
## a property of the accumulator and holds for ANY sub-step size. What the value decides is the
## DISCRETISATION the whole fight is computed at, which is a rule, so it is pinned here as a literal
## with both of its ends written out.
##
## ⚠ **This is the one check in the file that survived the harbour deletion untouched**, because it
## never built a plan: it reads `Rules` and nothing else.
func _the_substep_itself_is_pinned(t) -> void:
	t.eq(Rules.SIM_SUBSTEP_SEC, 1.0 / 60.0, "서브스텝은 정확히 1/60초다 — 리터럴로 못 박는다")
	# Floor: the lion's 0.6 s telegraph has to be at least five sub-steps, or the one beat the player
	# is supposed to read is decided in fewer frames than this repo has measured anyone seeing.
	t.ok(Rules.LION_WINDUP_SEC / Rules.SIM_SUBSTEP_SEC >= 5.0,
			"사자의 예고가 서브스텝 다섯 번 이상이다 (%.1f번)"
			% (Rules.LION_WINDUP_SEC / Rules.SIM_SUBSTEP_SEC))
	# Ceiling: the fastest unit (the crow, 6 tiles/s) must not cross a quarter of a tile in one
	# sub-step, or reservation contention — which 「the order you press is the order」 rides on —
	# resolves by iteration order instead of by geometry.
	t.ok(Rules.speed_of(Rules.CROW) * Rules.SIM_SUBSTEP_SEC <= 0.25,
			"가장 빠른 놈도 한 서브스텝에 0.25칸을 못 넘는다 (%.3f칸)"
			% (Rules.speed_of(Rules.CROW) * Rules.SIM_SUBSTEP_SEC))


## ⚠⚠ **Every deletion needs a check that the thing is GONE.** A green round after deleting a rule
## proves nothing about the deletion — the checks that drove it were deleted in the same edit, so
## "nothing red" is exactly what a deletion that never happened would also look like.
##
## ⚠⚠ **THE RECORD OF WHAT THIS FILE MEASURED, AND WHAT IS NOW UNMEASURED.**
##
## **A. The plan gate — every row needed a plan, and a plan needed `send`.**
##
##  · **`_uncommitted_step_touches_nothing`** — 600 frames pushed BEFORE `commit()` move nothing at
##    all: `elapsed` exactly 0.0, every boat's `t` exactly 0.0, no body moved, no enemy hit,
##    `substeps` 0. ⚠⚠ **ITS FLOOR IS THE SECOND HALF, NOT THE FIRST, AND THAT IS THE LESSON**: a
##    `Battle` built wrong — null grid, an army of nobody — is inert for reasons that have nothing to
##    do with `_committed`, and every "unchanged" assertion passes on it. So the SAME fixture and the
##    SAME loop were committed at the end and had to move. **`step()` still refuses everything while
##    `_committed` is false and nothing measures it now.**
##
##  · **`_commit_refuses_an_empty_plan`** — an empty plan is refused, a refused commit does not set
##    `committed()`, one boat is enough, and **a SECOND `commit()` is refused**.
##
##  · **`_the_plan_is_sealed_by_the_commit`** — after the commit nothing may be added and nothing may
##    be recalled, and **neither refusal changes `boats.size()`** — the half that stays green if a call
##    refuses AFTER touching state.
##
##  · **`_recall_puts_the_soldier_back`** — `recall(uid)` removes exactly that boat, returns the body
##    to RESERVE and its position to `OFFMAP`, **the remaining boat is a different one** (it did not
##    delete the wrong entry), the freed body can be pressed again and **gets a NEW uid** — a dead uid
##    is never reused, and recalling one is refused. **`recall` is live and this was its only net.**
##
##  · **`_one_drop_is_one_boat` / `_there_is_no_cap`** — one press, one boat, one body; thirteen of
##    them at once. ⚠ **`_there_is_no_cap` is the DEFERRED BRAKE as a check** (`plan-then-watch`,
##    OPEN 0): the user decided the brake is left out and added later — 「일단 빼고 만든 이후에
##    추가하자는 거임」 — so **a cap appearing is not a fix, it is a decision nobody made.** It asserted
##    13 succeeded, never "more than five".
##
##  · **`_send_refusals`** — six refusals from the plan's side, each also asserted not to grow `boats`.
##    `net_summon`'s `_seven_refusals` is the live successor for the summon half.
##
##  · **`_a_boat_leaves_from_its_own_harbour`** — ⚠ **a one-harbour fixture proved nothing here**:
##    `home`, `start_harbour` and 0 are the same number, so every side of every comparison read
##    `0 == 0`. It used three harbours with the landing's home harbour deliberately NOT the start one.
##    **That trap generalises: any fixture whose distinct values collapse to one number is a row that
##    cannot fail.**
##
##  · **`_drop_order_takes_the_front` / `_thirteen_aimed_at_one_tile_stand_on_thirteen`** — 「어느
##    순서로」 (`plan-then-watch`, 4.4): two boats aimed at the SAME tile from the same origin have
##    identical `dist` and identical speed, so they arrive on exactly the same sub-step, and
##    `_phase_landings`' ASCENDING pass is the only thing between them — **a single descending pass,
##    which is what shipped before that round, gives the front row to the boat pressed LAST.**
##    ⚠⚠ **The promise is only visible in the EVENT STREAM and the row had to be re-asserted when boats
##    became polylines**: final positions alone are also produced by a reversed pass whose boats
##    happened to arrive a sub-step apart, so it asserted the two `dist` values equal to 1e-5 and the
##    two LAND events on the same sub-step in press order. It also ran the whole thing TWICE with the
##    order swapped, because **one order alone cannot tell a rule from a coincidence.**
##    Thirteen aimed at one tile stood on thirteen distinct tiles — the row that reddens if
##    `_free_tiles_from` stops writing `grid.reserved`.
##
##  · **`_the_empty_boat_goes_home_and_vanishes`** — the emptied boat stays in `boats`, turns
##    RETURNING, **is really SAILED home** (one sub-step of `t > 0.0` is the floor, without which "boats
##    is empty at the end" is also satisfied by a boat deleted on the unload sub-step) and then leaves
##    the list. `net_summon`'s `_a_summoned_boat_goes_home_to_the_sea` is the live successor.
##
## **B. `Battle.step`'s SUB-STEP DECOMPOSITION — the heaviest loss, and none of it is about harbours.**
##
##  · ⚠⚠ **These rows already survived one deletion on purpose.** `speed-off-open-landing` deleted the
##    speed chips, the pause and every check that pressed one; **these pressed nothing.** What they
##    measured is that the same simulated span lands on identical state however many `dt` pieces it is
##    handed in — **the seam `battle.step(delta)` was kept taking a bare delta to preserve, and the only
##    guarantee that a restored multiplier would be arithmetically inert.**
##
##  · **`_one_slice_and_six_are_the_same_fight`** — 120 x `step(1/60)` against 20 x `step(6/60)`.
##  · **`_they_are_still_the_same_past_the_verdict`** — the same pair driven PAST the verdict. ⚠ **The
##    row above stops before it and stays green through the mutation this one catches**: a running test
##    hoisted out of the sub-step loop lets a WON island keep attacking, and `army` carries to the next
##    island, so a body can die after the fight is over.
##  · **`_uneven_frames_are_the_same_fight`** — ⚠⚠ **the `1/60` pair CANNOT fail the way this one can**:
##    `6 x (1.0/60.0) == 0.1` exactly in IEEE double and the quotient is exactly `6.0`, so that fixture
##    never leaves a remainder at all. This one fed 200 deltas that are never a multiple of the
##    sub-step (`0.0069 + 0.0007*(i%23) + 0.00013*(i%7)`, deterministic so a red round reproduces) and
##    compared them against the same totals in 2-, 3- and 6-frame chunks. **It is the only row that ever
##    measured `_substep_acc`.**
##  · **`_the_substep_count_itself_matches`** — ⚠⚠ **comparing final state catches *diverged*, never
##    *vanished*.** `substeps` is incremented INSIDE the loop, so this was the one row measuring the
##    PROCESS rather than the result: **a remainder pass adds a phase pass without adding a second of
##    simulated time**, and every state column is blind to it whenever the re-run phases happen to be
##    idempotent that frame.
##  · **`_zero_stops_the_clock`** — ⚠⚠ **this is what gave `if dt <= 0.0: return` a bite at all, and it
##    took measuring to find.** `step(0.0)` is ALREADY inert without that guard — the accumulator simply
##    never reaches a whole sub-step — so deleting the guard changes nothing about a zero frame. **A
##    NEGATIVE `dt` is the case only the guard catches**: it eats into `_substep_acc` and silently
##    delays the next sub-step, which reads as the fight stuttering with every check about `elapsed`
##    still green. The row proved it by asserting the very next frame runs EXACTLY one sub-step.
##
## **C. The instrument, and it is worth more than the rows it served.**
##
##  · **`_compare_arms` / `_columns_match` / `_the_comparison_itself`.** Six columns two arms can differ
##    in — clock, enemy HP, army HP, body positions, boat count, and each boat's `leg`/`t`/`pos` — and
##    **all six were asserted every time, because a comparison that reads one column proves the other
##    five were never looked at.** The last one was added with the polyline: two arms could agree on
##    every body while their hulls sat on different segments.
##  · ⚠⚠ **THE READER WAS SPLIT OUT SO IT COULD BE INVERTED, AND THIS IS THE FILE'S BEST LESSON.**
##    *"Twice in one night this repo shipped a check carrying the exact defect it existed to catch, and
##    neither was found by mutating the code — both were found by mutating the CHECK."* So
##    `_the_comparison_itself` fed the reader two arms that were deliberately NOT the same fight and
##    required every column to come back false. **A comparator that answered "same" about columns it
##    never looked at would make every equivalence row green for free, and no mutation of `battle.gd`
##    could ever find it — it is the instrument, not the subject.**
##  · ⚠ **Every equivalence row carried a FLOOR as well as a ceiling**, for the same reason: two runs
##    that both did nothing at all compare equal on every column.
func _the_plan_is_no_longer_authored_by_a_drag(t) -> void:
	var b := Battle.new()
	t.ok(not b.has_method("send"),
		"battle 에 send 가 없다 — 계획을 짜던 그 호출이고, 몸을 끌어 배에 태우는 손짓이었다")

	# The floor, and it is the whole point: the PLAN did not die with the drag. If these go missing the
	# row above becomes "battle has no methods" and stops meaning anything.
	t.ok(b.has_method("summon"), "계획은 이제 summon 으로 짠다 (자가 점검)")
	t.ok(b.has_method("recall"), "무르기는 그대로다 (자가 점검)")
	t.ok(b.has_method("commit"), "시작 버튼도 그대로다 (자가 점검)")
	t.ok(b.has_method("committed"), "확정 여부를 묻는 것도 그대로다 (자가 점검)")
	t.ok(not b.committed(), "새 battle 은 아직 확정 전이다")
	# ⚠⚠ **THIS ROW SAID 「빈 계획으로는 시작이 안 된다」 AND IT IS REVERSED** (2026-08-28). `commit`
	# refused an empty `boats` while the PLAYER authored the landing; the sides swapped, the beasts
	# arrive by boat, and `game._open_island` now commits an island that has — correctly — no boat on
	# it at all. Left as it was, the shell's commit was a no-op and the clock never started.
	t.ok(b.commit(), "배가 한 척도 없어도 시작이 받아들여진다 — 섬이 열리면 셸이 곧장 이걸 부른다")
	t.ok(b.committed(), "그리고 상태가 실제로 넘어갔다")
	t.ok(not b.commit(), "두 번째 시작은 거절된다 — 확정은 한 번뿐이다")
	t.eq(b.boats.size(), 0, "배 배열은 살아 있고, 비어 있다 (자가 점검)")

	var g := Grid.new()
	t.ok(not g.has_method("home_harbour_for"),
		"grid 에 home_harbour_for 가 없다 — 어느 항구에서 뜰지 고르던 규칙이다")
	t.ok(not g.has_method("water_route"), "grid 에 water_route 도 없다")
	t.ok(g.has_method("can_summon_at"), "대신 can_summon_at 이 있다 (자가 점검)")
