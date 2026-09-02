class_name Battle
extends RefCounted
## One island's fight. `step(dt)` drives all of it — targeting, movement, attacks,
## deaths and the clock — and nothing in this file is a Node, so a net builds one with `.new()` and
## drives it frame by frame with no tree at all.
##
## **The island is planned before it is fought, and the plan lives in `boats`.** `send` creates a boat
## sitting at its harbour with `t == 0.0`; `step` refuses to move anything until `commit` has been
## called. That is a RULE and not a calling habit: without `_committed` "planning" would exist only as
## the shell choosing not to call `step`, and every net, probe and future caller would break it in
## silence. `plan-then-watch` is where the reversal that produced this is recorded.
##
## **The phase order inside `step` is a contract, not an implementation detail.** Boats before
## landings means a boat that reaches the shore this sub-step unloads this sub-step instead of next.
## Attacks before deaths means two units that finish each other off both land their blow — the
## alternative silently gives whoever iterates first a free kill, and the free kill is invisible in
## final state. The clock last means an island cleared on the very sub-step the timer expires is a WIN.
## The first slice plan pins this under "The sim — shapes and entry points".
##
## **`step` has three guard lines and they are not interchangeable.** The null test and the `dt <= 0.0`
## test are per-CALL facts and stay outside the sub-step loop; the running test is answered per
## SUB-STEP, inside, as a `break`. Hoisted out, a WIN latched on sub-step 3 of 6 would let 4, 5 and 6
## keep attacking — and since `army` carries to the next island and death is permanent, a soldier
## could die AFTER the island was already won, at 6x and not at 1x.
##
## Distances are in TILES throughout, centre to centre, and positions carry tile centres on integers.
## The view multiplies by the tile size and nothing here knows what a pixel is.


## ⚠⚠ **`TRANSIT` STOOD BETWEEN THE TWO AND IT IS DELETED** (2026-08-29) with the boats — a soldier at
## sea, hittable and unable to hit back. **An enum member no code path can enter is a slot a future
## writer fills by accident**, which is the same reason a `LOADED` state was deleted before it.
enum SoldierState { RESERVE, ASHORE, DEAD }

## Where one of the beasts' boats is in its crossing.
##
## ⚠⚠ **THERE IS STILL NO `RETURNING`, AND `GONE` IS NOT ONE.** 티켓 41's 「배는 쌓인다. 그것은 원한
## 것이지 결함이 아니다」 was reversed by the user on 2026-09-01 — a hull that has put its 늑대 on the
## beach waits `Rules.BOAT_LINGER_SEC` and then **stops being there, in one step, without sailing
## anywhere.** There is no leg back to the horizon to travel and no position to move along it.
##
## ⚠⚠ **ALL THREE ARE ENTERED, WHICH IS THE ONLY REASON `GONE` IS ALLOWED TO EXIST.** `_phase_boats`
## writes every one of them. **An enum member no code path can enter is a slot a future writer fills by
## accident** — the reason `TRANSIT` and `LOADED` were both deleted before this.
enum BoatState { SAILING, ARRIVED, GONE }

## ⚠⚠ **`Event` STOOD HERE AND IT IS DELETED** (2026-08-29) with the fight, and it is NOT coming back
## with it. It was ATTACK · DEATH · LAND, an enum and never a string — `Battle.Event.ATTAK` is a parse
## error and `"ATTAK"` is a silent miss that draws nothing with every check about it green. **The view
## decided how long and in what colour**, because a duration in this file would be a rule that changes
## what happens. ⚠ **Nothing needs one this round**: 티켓 41's 목~일 slice builds the STATE of a fight
## and no new mark on screen, and the view reads state.

## **What separates a beast's reservation id from a 검사's**, so the two can never release each other's
## 조각. ⚠⚠ **RESTORED 2026-08-30 unchanged.** Without it 늑대 0 and 검사 0 hold one name, and the
## symptom is one body walking through another **with every reservation check still green.**
## ⚠ **It is a base and not a flag**: a reservation slot holds one int, and a body's reservation id is
## `ENEMY_UID_BASE + index` for a beast and its bare index for a 검사.
const ENEMY_UID_BASE := 1 << 20

## **The name the 성채's own 조각 are held under.**
##
## ⚠⚠ **NOTHING MARKS A BUILDING'S 조각 IMPASSABLE AND THAT COST A ROUND ONCE** — a body placed on the
## keep's 조각 stands INSIDE the house and the island reads as empty (measured 2026-08-27, `Run`'s own
## note). **Reserving them fixes it at the cause and for everyone**: the free-tile search skips them, so
## a 검사 mustering, a 늑대 stepping off a boat and a body walking past all refuse the house without any
## of the three carrying a rule about buildings.
## ⚠ **It is never released.** `release_all` is per-id and nothing in this file names this one.
const KEEP_UID := ENEMY_UID_BASE - 1

## What `soldier_target` and `enemy_target` hold when they are not naming a body.
##
## ⚠⚠ **`TARGET_KEEP` IS -2 AND NOT -1, AND THAT IS THE WHOLE OF WHY IT IS A CONSTANT.** 「I am hitting
## the 성채」 and 「I am hitting nothing」 collapsed onto one value would stop the 성채 burning with every
## count of living beasts still green — and the run would simply never be losable.
const TARGET_NONE := -1
const TARGET_KEEP := -2

## A flow field older than this is thrown away and rebuilt on the next request. The grid is 1536
## tiles (`boat-and-landing`'s 48 x 32), so one BFS is ~1536 operations and twenty units at 2 Hz is
## ~61k operations a second: the cache exists to stop the same field being rebuilt twenty times in
## one frame, not because the engine could not afford it.
const FIELD_TTL := 0.5

## Ceiling on tiles crossed in one `_walk` call. A unit at speed 6 with a 0.1 s frame moves 0.6
## tiles, so this is never reached in play — it exists so a `step_toward` that ever stops making
## progress ends the frame instead of hanging the round, because a hung net prints no verdict at all
## and that disarms mutation testing on the whole net.
const WALK_TILES_MAX := 64

## Position of a soldier that is not on the island. Deliberately off-grid: a view that draws reserve
## soldiers anyway puts them outside the viewport where it is obvious, rather than piling them all
## on tile (0,0) where it reads as one soldier.
const OFFMAP := Vector2(-1.0, -1.0)


var grid: Grid = null
var army: Army = null
## Seconds of simulated time this island has run.
## ⚠ **It STAYED when the time limit went** (2026-08-27) and again when the fight went (2026-08-29).
## It is not half of a deleted rule: **it is how a net proves the clock actually moved**, which is the
## difference between a sim the shell really stepped and one it silently never stepped at all.
var elapsed := 0.0

# --- the beasts ashore. Parallel columns, indexed by the order they stepped off a boat -------------
## ⚠⚠ **A ROW IS NEVER REMOVED.** `enemy_alive` flips to 0 and the row stays where it is forever, the
## same contract `Army` keeps and for the same reason: an index is an identity, and `grid.reserved`,
## `soldier_target` and the view all hold indices. **Compacting would renumber every one of them at
## once, silently.**
##
## ⚠⚠ **ELEVEN COLUMNS STOOD HERE BEFORE 2026-08-29 AND SEVEN COME BACK.** The four that do not are the
## telegraph's (`windup`, `windup_at`), the splash's, and `_enemy_home_level`. **The last one is a
## decision and not an omission**, and it is the one to read before anything is added here:
##
##  · **Only a body that STARTED high held its storey**, read off its spawn 조각 at setup. Enemies walk
##    at one thing and nothing else, so the ones posted on a plateau walked down their own stair and
##    died on the flat — **measured in play: most WON fights never sent anyone up the stairs, because
##    the defenders came down.** ⚠ Giving EVERY body a holding behaviour is the failure on the other
##    side: then the fight never comes to the player at all.
##  · ⚠⚠ **NOTHING STARTS HIGH THIS ROUND.** Every beast arrives by boat and steps off at the water's
##    edge, so the column would be 0 on every row and `keep_level` is passed as -1 at the one call site
##    that could use it. **A column that can only ever hold one value is a branch nobody can test**, so
##    it is written down here rather than built. The day something is posted on a plateau, this is the
##    paragraph to read first.
##  · **The telegraph was per-body STATE and not an event.** `enemy_windup` counted down for the whole
##    length the view had to draw, and an event plus a view-side clock is a second copy of that
##    countdown — **two clocks drift.** There is no heavy attack in this game yet.
var enemy_type := PackedInt32Array()
var enemy_hp := PackedFloat32Array()
var enemy_alive := PackedByteArray()
var enemy_pos: Array = []                 # Vector2, tile units
## A 검사's id, or `TARGET_KEEP`, or `TARGET_NONE`. **Re-chosen every sub-step** — see `_phase_targeting`.
var enemy_target := PackedInt32Array()
## Seconds until this body may swing again. **0 means ready**, and a body that has just landed is ready:
## the first blow does not wait a period. ⚠ 티켓 41's 「6 타 7.2 초」 column is the arithmetic for a body
## that waits one first, and the ticket marks that column as arithmetic rather than play.
var enemy_cool := PackedFloat32Array()
## Seconds until the swing this body is in the middle of LANDS. **0 means no swing is pending.** Set to
## `Rules.SWING_LAND_SEC` on the sub-step a swing begins (the same sub-step `enemy_cool` is wound), and
## the blow is dealt on the sub-step it reaches 0 — see `_phase_attacks`.
var enemy_swing := PackedFloat32Array()
## Whom the pending swing was thrown at: a 검사's id or `TARGET_KEEP`. **Locked at the start of the
## swing** — retargeting runs every sub-step and a swing that followed it would land on a body it was
## never thrown at. ⚠ **Not cleared when the swing lands**, so a reader one frame late still sees it.
var enemy_swing_at := PackedInt32Array()
## How many blows this body has LANDED, ever. **Only goes up**, and only on the sub-step the damage is
## dealt — a swing that finds its target dead or out of reach adds nothing. The view reads a rise here
## the way it reads a rise in `enemy_cool`: it is the one honest 「the blow landed」 the sim has.
var enemy_blows := PackedInt32Array()
var _enemy_goal: Array = []
var _enemy_stale := PackedByteArray()

# --- soldiers. Indexed by ARMY id, so index i is the same soldier here and in `army` --------------
var soldier_state := PackedInt32Array()
var soldier_pos: Array = []               # Vector2, tile units
## **Where the PLAYER sent this body, as a tile index, or -1 for「nowhere」.**
##
## ⚠⚠ **This is the first destination in the file that is not an enemy.** Until 2026-08-27 an allied
## body only ever walked at `enemy_pos[soldier_target[i]]`, so「go and stand there」could not be said
## at all. It is a SEPARATE column from `soldier_target` on purpose: an order and a target are two
## different sentences, and folding them into one index would make「walk to the stair」and「the stair
## is an enemy」the same value.
## ⚠ **Cleared on arrival.** It used to hand the body back to the fight; there is no fight, so it just stands.
var soldier_order := PackedInt32Array()   # tile index the player ordered, or -1
## **The straightened route the body is walking, one `PackedInt32Array` of 조각 per body**, and the index
## of the next 조각 in it. Empty means 「walk on the field alone」, which is what every body did before
## 티켓 37 and is still the always-valid fallback.
##
## ⚠⚠ **`_soldier_path_i` IS A PLAIN `Array` AND NOT A `PackedInt32Array`, DELIBERATELY.** It is written
## every sub-step, and this file already carries the measurement one column over: a `PackedInt32Array`
## written through a parameter lands in a copy-on-write copy — see `_settle`'s header, which records the
## same trap costing a whole-table rescan every frame.
## ⚠ **Cleared wherever the order is cleared.** A list left on a body after its order is gone sends it
## walking somewhere nobody asked.
var _soldier_path: Array = []
var _soldier_path_i: Array = []
var _soldier_goal: Array = []
var _soldier_stale := PackedByteArray()
## **A 검사's live HP, and it lives HERE and not on `Army`.**
##
## ⚠⚠ **THAT IS THE REVIVAL, NOT AN OVERSIGHT** (2026-08-30). A wound used to have to survive islands
## because death was permanent; **a body stands again at the 성채 after `Rules.REVIVE_SEC`**, so a wound
## cannot outlive the island it was taken on. `Army.max_hp_of` is what a body is born and healed to.
var soldier_hp := PackedFloat32Array()
## The beast index this body is hitting, or `TARGET_NONE`. ⚠ **Never `TARGET_KEEP`** — the 성채 is his.
var soldier_target := PackedInt32Array()
## Seconds until this body may swing again. See `enemy_cool` for why 0 means ready.
var soldier_cool := PackedFloat32Array()
## The 검사 side of `enemy_swing` · `enemy_swing_at` · `enemy_blows`. `soldier_swing_at` is a beast
## index or `TARGET_NONE`, never `TARGET_KEEP`.
var soldier_swing := PackedFloat32Array()
var soldier_swing_at := PackedInt32Array()
var soldier_blows := PackedInt32Array()
## Seconds until a DEAD body stands again at the 성채. **Only read while `soldier_state` is DEAD.**
var soldier_revive := PackedFloat32Array()

# --- the 성채, and the only way this island is lost ------------------------------------------------
## Every 조각 the 성채 covers, handed in by `setup` from the island file. **Empty is a real board**: a
## fixture with no house cannot be lost and nothing musters on it.
var keep_tiles := PackedInt32Array()
var keep_hp := 0.0
## **Where a 검사 appears — at the opening and again after he dies.** -1 for a board with no 성채.
##
## ⚠⚠ **IT IS THE DOORSTEP AND NOT THE HOUSE, AND IT IS ONE FIELD BECAUSE THE TWO EVENTS ARE ONE RULE.**
## The opening watch used to be stood by `Run` off the island file and a revival would have been stood
## here off `keep_tiles`, which is **two answers to 「where does a 검사 appear」** — and they would have
## disagreed the first time the 성채 moved off level ground, one body on the plateau and one below it.
var muster_tile := -1
## **The island's verdict, and this week there is exactly one.** 티켓 41: 「이기는 조건 — 이번 주에
## 없다」, so there is no `Outcome` enum and no WON. ⚠ **A one-member enum every reader compares against
## is a branch that always takes the same arm**, which is the shape `Run` was caught carrying twice.
var lost := false
## False until `commit()`. **`step()` refuses to do anything at all while it is false.**
## Whole sub-steps only: `step` adds `dt` here and consumes `Rules.SIM_SUBSTEP_SEC` at a time, so the
## decomposition is additive over ANY sequence of `dt`s and a 6x run lands on the same state as a 1x
## run. Consuming a remainder pass instead would hand `_phase_targeting`, `_phase_landings` and
## `_phase_deaths` — which take no `dt` at all — a free extra retarget and death latch on every frame
## whose `dt` is not a multiple of the sub-step, which in the shipped shell is every frame.
var _substep_acc := 0.0

## How many whole sub-steps this island has run, counted **inside** the loop. It is an instrument and
## nothing in `src/` reads it: comparing final state across a 1x arm and a 6x arm catches *diverged*
## and never *vanished*, so the equivalence rows need the process itself to compare, and a pass count
## derived from `elapsed` would be blind to exactly the defect they exist to catch — a remainder pass
## adds a phase pass without adding a second of simulated time. `plan-then-watch`, the net row
## 「서브스텝 횟수 자체가 같다」.
var substeps := 0

# --- the beasts' boats. Parallel columns, indexed by the order they were born ---------------------
## ⚠⚠ **A BOAT'S POSITION IS FLAT AND THE BOB IS NOT HERE.** The hull rises and falls on screen, and
## that motion is `look.gd`'s — a net driving this file must not be able to see it. Height at sea is
## presentation all the way down: nothing about a crossing is decided by it.
##
## ⚠⚠ **A HULL LEAVES BY FLIPPING TO `GONE` AND NOTHING IS EVER ERASED**, so these arrays only ever
## grow across one island — exactly the contract `enemy_alive` and `Army.alive` keep, and for the same
## reason: **an index is an identity** and the view holds indices. An erase renumbers every one of them,
## and the second boat would wear the first one's hull, its trail and its bob.
var boat_pos: Array = []                  # Vector2, tile units, tile centres on integers
## The 조각 each boat is aimed at — always a member of `grid.beach_ring`.
var boat_beach := PackedInt32Array()
## Where each boat comes to rest, in 조각 units. **Frozen at launch, deliberately.**
##
## ⚠ **It is eight neighbour lookups and it could be derived every sub-step, and it is not.** The board
## cannot change during an island, so the answer cannot either — and the day the bearing grows a line
## test (see `Grid.seaward_at`'s own note on inland water) that derivation stops being eight lookups
## and starts being thousands a frame. **One call per boat, ever.** `net_boats` rebuilds the point from
## the board rather than reading this back, so the stored copy is still measured against its own
## derivation.
var boat_stop: Array = []                 # Vector2, tile units
var boat_state := PackedInt32Array()      # BoatState
## **How many are still aboard.** ⚠ **A COUNT AND NOT BODIES**: a rider is nowhere in `grid.reserved`
## until it steps off, and `_phase_landings` is what turns one into a row of the beast columns. **It
## only ever goes down**, and a hull that reaches 0 keeps sitting where it stopped.
var boat_riders := PackedInt32Array()
## **How long each ARRIVED hull still has before it is gone**, in seconds. Meaningless while a hull is
## SAILING — `_phase_boats` writes it at the arrival flip and nowhere else reads it before then.
var boat_linger := PackedFloat32Array()

## Where in `grid.beach_ring` the NEXT boat's 조각 comes from, already taken modulo the ring size.
## ⚠ **`Rules.beach_stride_for` is what advances it** — see that function for why the stride is derived
## from the ring's own size rather than written down.
var _beach_cursor := 0
## How many launches this island has had, including ones a coastless board refused. **It and `elapsed`
## are the whole clock**: a second countdown of its own would be a second clock, and the seams between
## two clocks are where this project's defects have come from.
var _boats_launched := 0

var _fields := {}                         # target tile -> PackedInt32Array
var _field_age := {}                      # target tile -> seconds since it was built

## **Which way the seat lattice on each 칸 faces** — 칸 index -> unit `Vector2`, in `soldier_pos` axes.
## Ticket 03-17 (2026-09-02, the user: 「격자는 명령 방향으로」 — *"the lattice faces the order's
## direction"*).
##
## ⚠⚠ **`Hand.order` IS THE ONLY WRITER AND THE VIEW IS THE ONLY READER.** The facing is the 칸's middle
## minus the centroid of the ordered bodies' positions at the moment of the order, normalised; an order
## whose centroid IS the middle (under `Rules.EPS`) leaves the entry as it was. **A 칸 with no entry
## faces `(0, 1)`** — the nine mustered at the 성채 and every 짐승 stand on an unturned lattice.
## ⚠ **Nothing in the sim reads this.** Where a body stands, walks and fights is `soldier_pos`; this is
## where the view DRAWS a body at rest inside its 칸, and it lives here rather than in the view because
## it is written by a sim call and has to survive the view being rebuilt.
## ⚠ **A later order onto a 칸 with bodies already standing turns the lattice under them** — they glide
## to the new points. That is the accepted cost of the user's answer, not a defect.
## ⚠ **Reset in `setup`**, like every other per-island table here.
var block_face := {}


## Builds one island's fight. **`grid.load_rows` must already have run** — this writes tile
## reservations for every enemy, and `load_rows` clears the reservation table, so calling it
## afterwards would leave every enemy standing on a tile anyone may walk into.
##
## `spawns` is `islands.gd`'s `spawns_of` output: `[{"type_id": int, "tile": int}]`.
##
## ⚠⚠ **`keep` AND `muster` BOTH DEFAULT TO 「there is none」, AND THAT IS A REAL BOARD RATHER THAN A
## CONVENIENCE.** Every net fixture in this repo but one hands this file a hand-drawn rectangle with no
## house on it; **an island with no 성채 cannot be lost and musters nobody**, which is what those
## fixtures are entitled to. `Run` is the caller that has both, and it reads them off the island file.
@warning_ignore("shadowed_variable")
func setup(grid: Grid, army: Army, spawns: Array,
		keep: PackedInt32Array = PackedInt32Array(), muster: int = -1) -> void:
	self.grid = grid
	self.army = army
	elapsed = 0.0
	lost = false
	_fields = {}
	_field_age = {}
	# Every time: a reused `Battle` carrying the previous island's facings would turn the first 부대 of
	# the next island to an order nobody gave there.
	block_face = {}
	# Every time. A `Battle` is reused across islands, and a leftover `_substep_acc` is a fraction of
	# the previous island's clock. `setup` exists to make a reused Battle indistinguishable from a
	# fresh one.
	_substep_acc = 0.0
	substeps = 0

	# Every time, for the same reason `_substep_acc` is: a reused `Battle` carrying the previous
	# island's hulls would open the next island with boats already ashore.
	boat_pos = []
	boat_beach = PackedInt32Array()
	boat_stop = []
	boat_state = PackedInt32Array()
	boat_riders = PackedInt32Array()
	boat_linger = PackedFloat32Array()
	_beach_cursor = 0
	_boats_launched = 0

	# Every time, for the same reason the hulls are: a reused `Battle` carrying the previous island's
	# beasts would open the next one with the last one's 늑대 already ashore.
	enemy_type = PackedInt32Array()
	enemy_hp = PackedFloat32Array()
	enemy_alive = PackedByteArray()
	enemy_pos = []
	enemy_target = PackedInt32Array()
	enemy_cool = PackedFloat32Array()
	enemy_swing = PackedFloat32Array()
	enemy_swing_at = PackedInt32Array()
	enemy_blows = PackedInt32Array()
	_enemy_goal = []
	_enemy_stale = PackedByteArray()

	keep_tiles = keep
	muster_tile = muster
	keep_hp = 0.0 if keep.is_empty() else Rules.KEEP_MAX_HP
	# ⚠ **No muster clock is reset here any more** — the 성채's twenty-second clock was deleted on
	# 2026-09-02 (the user: 「자동 병사 생성 지워줘」). The opening roster is `add_starting_force`'s.

	if grid == null or grid.w <= 0 or grid.h <= 0:
		# Not swallowed: a battle on an unloaded grid has no tiles, so every unit would stand still
		# for the whole island and the round would read as "nothing happened" with nothing to point
		# at. A net that builds this case on purpose forgives this exact substring.
		push_error("battle.setup: 격자가 비어 있다 — grid.load_rows 를 먼저 불러야 한다")
		return

	# ⚠⚠ **THE SPAWN LOOP STOOD HERE AND IT IS DELETED** (2026-08-29) with the fight. It built every
	# enemy column off `spawns` and claimed each spawn 조각 in `grid.reserved` under a uid offset by
	# `ENEMY_UID_BASE`, so an enemy and a soldier could never release each other's 조각.
	# ⚠ **`spawns` is still a parameter and it is still read for its SIZE by nothing** — the argument
	# is kept because `Islands.spawns()` and the board's spawn letters are untouched, and the day
	# bodies come back this is where they land.

	# ⚠⚠ **THE HOUSE HOLDS ITS OWN 조각, AND THAT IS WHAT KEEPS EVERYTHING OUT OF IT.** Nothing marks a
	# building impassable, so without this a mustering 검사, a 늑대 stepping off a boat and a body
	# walking past all have to carry their own rule about buildings — three copies, and the island opens
	# looking empty the first time one of them is forgotten. **See `KEEP_UID`.**
	# ⚠ **After the boat and enemy resets and before anything is placed**: `load_rows` clears the
	# reservation table, so this must not run before whoever called it.
	# ⚠⚠ **`grid.fill` AND NOT `grid.hold`, SINCE 2026-08-30.** A 조각 admits `Rules.TILE_CAPACITY`
	# bodies now, so a house holding ONE slot would leave the rest free and every body on the island
	# would walk into it — **a building takes the whole 조각 or it is not a wall.**
	if not keep_tiles.is_empty():
		for k in keep_tiles.size():
			grid.fill(KEEP_UID, int(keep_tiles[k]))

	var roster := army.type_id.size()
	soldier_state = PackedInt32Array()
	soldier_state.resize(roster)
	soldier_order = PackedInt32Array()
	soldier_order.resize(roster)
	_soldier_stale = PackedByteArray()
	_soldier_stale.resize(roster)
	soldier_hp = PackedFloat32Array()
	soldier_hp.resize(roster)
	soldier_target = PackedInt32Array()
	soldier_target.resize(roster)
	soldier_cool = PackedFloat32Array()
	soldier_cool.resize(roster)
	soldier_swing = PackedFloat32Array()
	soldier_swing.resize(roster)
	soldier_swing_at = PackedInt32Array()
	soldier_swing_at.resize(roster)
	soldier_blows = PackedInt32Array()
	soldier_blows.resize(roster)
	soldier_revive = PackedFloat32Array()
	soldier_revive.resize(roster)
	# resize on a fresh array zero-fills, so nobody has charged yet. **Per island for free**: a
	# `Battle` is new every island, so 「몸당 섬당 한 번」 needs no reset anywhere else.
	soldier_pos = []
	_soldier_goal = []
	_soldier_path = []
	_soldier_path_i = []
	for i in roster:
		# ⚠ **A soldier who died on an earlier island is DEAD here, never RESERVE.** Nothing kills a
		# body any more, so no corpse can reach this line today — the rule is kept because the roster
		# is what carries across islands and a body left RESERVE would be deployed again.
		soldier_state[i] = SoldierState.RESERVE if army.alive[i] != 0 else SoldierState.DEAD
		soldier_order[i] = -1
		_soldier_stale[i] = 0
		# ⚠ **Zero until he stands.** `place_ashore` is the one writer of a full bar — see its header:
		# a body that stands on the island stands whole, and there is exactly one door onto the island.
		soldier_hp[i] = 0.0
		soldier_target[i] = TARGET_NONE
		soldier_cool[i] = 0.0
		soldier_swing[i] = 0.0
		soldier_swing_at[i] = TARGET_NONE
		soldier_blows[i] = 0
		soldier_revive[i] = 0.0
		soldier_pos.append(OFFMAP)
		_soldier_goal.append(OFFMAP)
		_soldier_path.append(PackedInt32Array())
		_soldier_path_i.append(0)


# --- the plan ------------------------------------------------------------------------------------

## ⚠⚠ **`send(soldier_id, tile)` STOOD HERE AND IT IS DELETED — THE HARBOUR WENT WITH IT.** It put one
## soldier on one boat aimed at `tile` and returned that boat's uid, or -1 with nothing at all changed.
## **What killed it: the player used to DRAG a body onto a boat that departed from a harbour, and that
## drag was deleted.** From that moment this function had zero callers in `src/`, and every harbour
## table in `grid.gd` it was the last consumer of went with it — see the deletion block on
## `Grid.harbour_tiles`. `summon()` below is the replacement, whole: **the player presses on the water
## inside a band and a boat is BORN there**, so there is no harbour to depart from and no soldier named
## by the caller — a slot spends a body of its own.
##
## **The knowledge it carried that outlives it:**
##
##  · ⚠⚠ **THE RETURN IS AN INT AND UID 0 IS THE FIRST BOAT OF EVERY ISLAND**, so `if battle.summon(...)`
##    is a bug that refuses the common case exactly as `if battle.send(...)` was. **Every caller
##    compares `>= 0`.** `summon` repeats this on its own header because it is the one that is live.
##  · ⚠ **ONE predicate decided both the refusal and the route, deliberately** — here `grid.home_harbour_for`,
##    in `summon` it is `grid.can_summon_at`. The shell's refusal mark is drawn off the call's OWN -1,
##    which is what makes it impossible for the screen to deny a tile the sim allows.
##  · ⚠ **A route of fewer than two points was a SEPARATE refusal line and not an assumption**, and
##    `summon` still carries that line. The two predicates agree by construction today; the day one of
##    them grows a case the other has not, a one-point path divides by a zero-length crossing instead of
##    barking.
##  · ⚠ **It refused anything that was not `RESERVE`** — dead, already sent, or already ashore — which
##    is why `setup` puts a soldier who died on an earlier island straight into `DEAD` rather than
##    `RESERVE`. **That line in `setup` still says so**, and it is now the only place that rule is
##    written; do not "simplify" it because the function that used to refuse a corpse is gone.
##  · ⚠ It refused while `_committed`, and `summon` refuses on the same flag. **Planning is before the
##    start button and nothing may be added after it.**


## The bodies slot `slot` may still put on a boat: living, of that slot's type, and still RESERVE.
## Empty for an unbound or out-of-range slot, which is what lets the shell test "unbound OR dry" with
## one call.
##
## ⚠⚠ **MOST HURT FIRST, and it used to be healthiest first.** The user, asked which body a slot spends
## when a key is pressed: ***"다친놈부터"***. **It is a rule and not a preference**, and what it does is
## bigger than an ordering: a slot spends damaged bodies first, so **「which of these is nearly gone」
## stops being something the player has to read** — which is exactly the picture that died with the
## reserve stack (`sea-summon` §6, Open 4: per-soldier HP has no home).
## ⚠ **It MAY close that hole by removing the need for it. Nobody has measured whether it does**, and
## this comment does not claim it — a rule that makes a readout unnecessary and a rule that makes it
## invisible look identical until somebody plays it.
##
## ⚠⚠ **`army.living_ids_of_type` IS NOT REORDERED, and that was checked rather than assumed.** It has
## three other readers: `hud_view` and `net_run` take only `.size()` (order-blind), but
## **`tools/probe/run_run.gd` used to read `ids[0]` to put the beak on the HEALTHIEST living body** —
## the beak reward is deleted (2026-08-25) but the ORDER is still this function's contract. Its own
## comment says so. Flipping that function would silently invert the probe's reward policy, which is a
## design instrument, not a caller. So the summon gets its own ordering here and `army` keeps its
## documented one.
##
## ⚠ **Ties break on the LOWER ID**, the same tie-break `army._hp_desc` already carries and for the
## same reason: `sort_custom` is not stable, so two bodies on equal HP would otherwise board in
## whatever order the sort happened to produce and two runs from identical state would diverge with
## every check about them green. The tie is exact `==` and not `is_equal_approx` — an approximate tie
## is not transitive, and a comparator that is not a strict weak ordering lets `sort_custom` return
## anything at all.
##
## **There is deliberately no second `slot_reserve_count`.** The HUD calls `.size()`; a count written
## twice diverges.
##
## ⚠⚠ **Filtered by `army.slot_id[i] == slot`, NOT by `army.type_id[i] == want`.** The two agree today
## (one slot per type), and they stop agreeing the day two slots bind to the same type — which is what
## ⚠⚠ **THE WHOLE PLANNING HALF STOOD HERE AND IT IS DELETED** (2026-08-29). `send` went on
## 2026-08-28 with the harbour; `slot_reserve_ids`, `_hp_asc`, `summon`, `_arc_lengths` and `recall`
## go now, because the gesture that called `summon` was deleted the same day and nothing has called it
## since. **`commit` and `committed` below are NOT part of this** — see their own header.
##
## ⚠⚠ **WHAT THE SUMMON KNEW, for the day the beasts get boats:**
##
##  · **A slot spent its MOST HURT body first**, not its healthiest — the user, asked which one a key
##    press spends: ***"다친농부터"***. It is a rule, not a preference: it makes 「어느 게 거의
##    갔나」 something the player stops having to read.
##  · **Ties broke on the LOWER id, with an exact `==`.** `sort_custom` is not stable and an
##    approximate tie is not transitive, so a comparator without both lets the sort return anything.
##  · **The return was an int and uid 0 was the first boat of every island**, so `if battle.summon(...)`
##    refused the common case. Every caller compared `>= 0`.
##  · **ONE predicate decided both the refusal and the route**, and the screen's refusal mark was drawn
##    off the call's own -1 — which is what made it impossible for the view to deny a tile the sim allowed.
##  · **A route shorter than two points was its own refusal line**, never an assumption: the two
##    predicates agreed by construction, and the day one grew a case the other had not, a one-point path
##    would divide by a zero-length crossing instead of barking.
##  · **A soldier who died on an earlier island was put straight into `DEAD` by `setup`, never RESERVE.**
##    That line is still there and it is now the only place the rule is written.


## back with it is a plan for the player to author, and there is none.
func step(dt: float) -> void:
	# Per-CALL facts, answered once. See the header for why the running test is NOT one of them.
	if grid == null or army == null:
		return
	if dt <= 0.0:
		return
	# ⚠⚠ **A LOST ISLAND STOPS ACCUMULATING, AND THIS IS A PER-CALL FACT LIKE THE TWO ABOVE IT.** The
	# sub-step loop below breaks on the same flag, and the two are NOT a duplicate: that one stops the
	# five phases after the 성채 falls **within the frame it fell in**, this one stops `_substep_acc`
	# growing without bound for the rest of the session. Delete this and the clock stays still while the
	# leftover creeps up, so a later change that clears `lost` would run a hundred sub-steps at once.
	if lost:
		return
	_substep_acc += dt
	while _substep_acc >= Rules.SIM_SUBSTEP_SEC:
		_substep_acc -= Rules.SIM_SUBSTEP_SEC
		substeps += 1
		# ⚠⚠ **THE CLOCK MOVED HERE ON 2026-08-29**, out of the deleted `_phase_clock`. It is not
		# half of a deleted rule: **it is the only thing that can tell a sim the shell really stepped
		# from one it silently never stepped at all**, and `net_shell` reads it for exactly that.
		# ⚠ **Advanced by the SUB-STEP and never by `dt`** — the whole point of the decomposition is
		# that the same simulated second costs the same number of passes whatever `dt` arrives.
		elapsed += Rules.SIM_SUBSTEP_SEC
		# ⚠⚠ **THE ORDER IS A CONTRACT AND NOT AN IMPLEMENTATION DETAIL**, and every line of it was
		# paid for once:
		#
		#  · **Orders before movement, and movement skips whoever orders moved** — falling through
		#    walks one body twice in a sub-step, at double speed and toward two different places.
		#  · **Boats before landings**, so a hull that reaches the shore on this sub-step unloads on
		#    this sub-step rather than on the next one.
		#  · **Landings before targeting**, so a 늑대 that steps off is in the fight the moment it is
		#    standing rather than a sub-step behind everything else.
		#  · **Targeting before movement**, because 「something is in reach」 is what stops a body
		#    walking. Chosen at the position it is standing in, and re-checked in `_phase_attacks`
		#    against the position it ends the sub-step in — **the choice and the blow are different
		#    questions and a body may move between them.**
		#  · ⚠⚠ **ATTACKS BEFORE DEATHS.** Two bodies that finish each other off both land their blow;
		#    resolved together, whichever the loop reaches first gets a **free kill, and a free kill is
		#    invisible in final state.**
		#  · **The muster last**, so a body that died this sub-step starts its own clock this sub-step
		#    and not on the next one.
		_phase_orders(Rules.SIM_SUBSTEP_SEC)
		_phase_boats(Rules.SIM_SUBSTEP_SEC)
		_phase_landings()
		_phase_targeting()
		_phase_movement(Rules.SIM_SUBSTEP_SEC)
		_phase_attacks(Rules.SIM_SUBSTEP_SEC)
		_phase_deaths()
		_phase_muster(Rules.SIM_SUBSTEP_SEC)
		# ⚠⚠ **THE VERDICT IS LAST AND IT BREAKS.** Hoisted out of the loop, a 성채 that fell on
		# sub-step 3 of 6 would let 4, 5 and 6 keep swinging — bodies dying after the run was already
		# over, and only at a big `dt`. ⚠ **The floor is `keep_tiles`, not `keep_hp`**: a board with no
		# house sits at 0 HP forever and would otherwise be lost on its first frame.
		if not keep_tiles.is_empty() and keep_hp <= 0.0:
			keep_hp = 0.0
			lost = true
			break


## **Stands one body on the island with no boat and no crossing.** Returns the tile it took, or -1.
##
## ⚠⚠ **Every path onto the island used to run through a boat** — `send` and `summon` both, and
## `_try_unload` was the ONE writer of `ASHORE` in `src/`. That was right while the player was the
## side that arrives by sea; the sides were swapped 2026-08-26 and **the company already lives here**,
## so a body that starts on its own island must not have to sail to it.
##
## ⚠ **The four writes are one unit and the nets already say so** (`net_battle`'s `_ashore` fixture,
## whose header states all four are required): state, position, GOAL, and the reservation. Leaving the
## goal at `OFFMAP` makes the body drift back toward (-1,-1) at walking speed — measured in
## `tools/probe/tier_stair_reach.gd`, whose comment records exactly that.
##
## ⚠ `near_tile` is a WISH, not a demand: the body takes the nearest free walkable tile at that tile's
## own level, through the same search a landing uses, so a keep standing on the wish still lands
## somebody beside it.
func place_ashore(soldier_id: int, near_tile: int) -> int:
	if grid == null or army == null:
		return -1
	if soldier_id < 0 or soldier_id >= soldier_state.size():
		return -1
	if int(soldier_state[soldier_id]) != SoldierState.RESERVE:
		return -1
	var spots := _free_tiles_from(near_tile, 1)
	if spots.is_empty():
		return -1
	var tile := int(spots[0])
	var here := _point_of_tile(tile)
	soldier_state[soldier_id] = SoldierState.ASHORE
	soldier_pos[soldier_id] = here
	_soldier_goal[soldier_id] = here
	_soldier_stale[soldier_id] = 0
	# ⚠⚠ **A BODY THAT STANDS ON THE ISLAND STANDS WHOLE, AND THIS IS THE ONE PLACE THAT IS TRUE.**
	# The opening watch and a revival are the same call, so a wound healed in one and not the other is
	# not a shape this file can have. **`soldier_hp` is 0 until this line runs** — see `setup`.
	soldier_hp[soldier_id] = army.max_hp_of(soldier_id)
	soldier_target[soldier_id] = TARGET_NONE
	soldier_cool[soldier_id] = 0.0
	# ⚠ **A swing a body died in the middle of does not land on its next life.** `soldier_blows` is
	# left alone: it only ever rises, and a reader diffing it wants no false rise here.
	soldier_swing[soldier_id] = 0.0
	soldier_swing_at[soldier_id] = TARGET_NONE
	soldier_revive[soldier_id] = 0.0
	_clear_path(soldier_id)
	grid.hold(soldier_id, tile)
	return tile


## **Stands one 검사 at the 성채's doorstep** — the opening watch and every revival, through one call.
## Returns the 조각 he took, or -1.
##
## ⚠ **-1 is a real answer and not an error.** A board with no 성채 has no doorstep, and a doorstep with
## nothing free beside it is a house nobody can come out of — both are boards, and both are silent here
## on purpose. `_phase_muster` retries on the next sub-step rather than losing the body.
func stand_at_keep(soldier_id: int) -> int:
	if muster_tile < 0:
		return -1
	return place_ashore(soldier_id, muster_tile)


## **How many 검사 the run still has** — a body waiting out `Rules.REVIVE_SEC` included, because he is
## coming back and the ceiling has to count him.
##
## ⚠ **Not `army.type_id.size()`**: that is the roster's history and never shrinks (see `Army`'s header
## — a dead row is never removed), so a body killed for good would keep occupying one of the nine.
func living_soldier_count() -> int:
	if army == null:
		return 0
	var n := 0
	for i in army.alive.size():
		if army.alive[i] != 0:
			n += 1
	return n


## **Turns out one more 검사 at the 성채's doorstep, mid-island.** Returns his roster id, or **-1 with
## nothing at all changed** — not a row on the roster, not an element on any column.
##
## Refused when: there is no board · there is no doorstep · the run already holds `Rules.MUSTER_CAP`
## 검사 · the slot fields nobody · **there is nowhere beside the 성채 to stand.**
##
## ⚠⚠ **THE FREE-TILE SEARCH RUNS BEFORE ANYTHING IS APPENDED, AND THAT ORDER IS THE REFUSAL.** `Army`
## rows are identities and are never removed (its header says so), so a row appended and then found
## nowhere to stand could not be taken back: it would sit RESERVE, invisible, counted against the
## ceiling, for the rest of the run. **Ask first, append second.**
##
## ⚠⚠ **EVERY COLUMN THIS FILE INDEXES BY SOLDIER GROWS HERE, AND `setup` IS THE LIST.** A column left
## short is not a wrong number, it is an out-of-range read on the first sub-step that touches the new
## body — and the roster row would already exist.
##
## ⚠ **The 성채's own 블록 admits eight, not `Rules.BLOCK_CAPACITY`**: `setup` fills the house's 조각
## whole, so the search walks outward past it and the ninth body stands further out rather than not
## standing. **`net_fight` measures that rather than assuming it.**
func recruit(slot: int) -> int:
	if grid == null or army == null:
		return -1
	if muster_tile < 0:
		return -1
	if living_soldier_count() >= Rules.MUSTER_CAP:
		return -1
	if _free_tiles_from(muster_tile, 1).is_empty():
		return -1
	var id := army.recruit(slot)
	if id < 0:
		return -1
	# ⚠ **RESERVE and empty, exactly as `setup` opens a row** — `place_ashore` refuses anything that is
	# not RESERVE, and it is the one writer of a full HP bar. A body born ASHORE here would stand with
	# no 조각 reserved and no position.
	soldier_state.append(SoldierState.RESERVE)
	soldier_order.append(-1)
	_soldier_stale.append(0)
	soldier_hp.append(0.0)
	soldier_target.append(TARGET_NONE)
	soldier_cool.append(0.0)
	soldier_swing.append(0.0)
	soldier_swing_at.append(TARGET_NONE)
	soldier_blows.append(0)
	soldier_revive.append(0.0)
	soldier_pos.append(OFFMAP)
	_soldier_goal.append(OFFMAP)
	_soldier_path.append(PackedInt32Array())
	_soldier_path_i.append(0)
	# The search above already answered 「there is room」, so this cannot refuse. **Not assumed
	# silently**: a body left RESERVE here is on the roster, counted, and never on the board — the one
	# outcome this function's whole ordering exists to make impossible.
	if stand_at_keep(id) < 0:
		push_error("battle.recruit: 자리를 찾아 놓고 못 세웠다 — 뽑기와 배치가 서로 다른 것을 묻고 있다")
	return id


## **Puts one beast on the island at the nearest free 조각 to `near_tile`.** Returns its index, or -1
## when there is nowhere to stand. ⚠ **The index is an identity for the rest of the island** — rows are
## never removed, see the column block above.
##
## ⚠ **The same search a 검사 lands through**, so a house standing on the aimed 조각 puts the body
## beside it rather than inside it, and two beasts can never take one 조각: each reserves before the
## next one searches.
func land_beast(type_id: int, near_tile: int) -> int:
	if grid == null:
		return -1
	if type_id < 0 or type_id >= Rules.UNITS.size():
		return -1
	var spots := _free_tiles_from(near_tile, 1)
	if spots.is_empty():
		return -1
	var tile := int(spots[0])
	var here := _point_of_tile(tile)
	var e := enemy_type.size()
	enemy_type.append(type_id)
	enemy_hp.append(Rules.hp_of(type_id))
	enemy_alive.append(1)
	enemy_pos.append(here)
	enemy_target.append(TARGET_NONE)
	enemy_cool.append(0.0)
	enemy_swing.append(0.0)
	enemy_swing_at.append(TARGET_NONE)
	enemy_blows.append(0)
	_enemy_goal.append(here)
	_enemy_stale.append(0)
	grid.hold(ENEMY_UID_BASE + e, tile)
	return e


## **The player tells one body to go and stand on a tile.** Returns false and changes nothing if the
## body cannot be ordered or the tile cannot be stood on.
##
## ⚠ **It does not check that a route exists.** `flow_field` answers `UNREACHABLE` for a tile no walk
## can reach, and `_walk` then simply fails to find a better neighbour and the body stays put — which
## is the same thing that already happens at a blocked neck. **A reachability test here would be a
## second copy of the walking rule**, and the two would drift.
## ⚠ **Not gated on the commit.** The commit is what starts the FIGHT; a body walking where it was
## told is what the player does before one — see `step`.
##
## ⚠⚠ **THE STRAIGHTENED ROUTE IS BUILT HERE, ONCE, AND NEVER REBUILT MID-ORDER** (티켓 37). A body stuck
## at a neck would otherwise rebuild it every sub-step for no change, and the field underneath is already
## correct. **An empty result is not an error** — the body then walks on the field alone, exactly as every
## body did before this ticket.
func order_walk(soldier_id: int, tile: int) -> bool:
	if grid == null:
		return false
	if soldier_id < 0 or soldier_id >= soldier_state.size():
		return false
	if int(soldier_state[soldier_id]) != SoldierState.ASHORE:
		return false
	if tile < 0 or tile >= grid.passable.size() or grid.passable[tile] == 0:
		return false
	soldier_order[soldier_id] = tile
	_clear_path(soldier_id)
	var here := _tile_of(soldier_pos[soldier_id])
	if here >= 0:
		var raw := grid.path_from(field_to(tile), here, tile)
		if raw.size() > 1:
			_soldier_path[soldier_id] = grid.string_pull(raw)
			# Index 1: index 0 is the 조각 the body already stands on.
			_soldier_path_i[soldier_id] = 1
	return true


## Soldiers standing on the island right now. The view draws these and nothing else on the ground.
func ashore_ids() -> Array:
	var out := []
	for i in soldier_state.size():
		if soldier_state[i] == SoldierState.ASHORE:
			out.append(i)
	return out


## Beasts standing on the island right now, as indices. **The dead rows stay in the columns and are not
## in here** — the view draws this and nothing else, so a corpse cannot be left on screen.
func living_enemy_ids() -> Array:
	var out := []
	for e in enemy_alive.size():
		if enemy_alive[e] != 0:
			out.append(e)
	return out


## **How far `p` is from the nearest 조각 of the 성채 a body standing there may actually strike, height
## included.** `INF` for a board with none — and `INF` now also for a body the 눈금 rule shuts out.
##
## ⚠⚠ **THE NEAREST 조각 AND NOT THE LOW CORNER.** A house is a footprint, and a reach measured to one
## corner lets a body stand against the far wall swinging at nothing — the same 「a mean is not a place
## anybody stands」 trap `_dist`'s own header records.
##
## ⚠⚠ **A 조각 OUT OF THE STRIKER'S 눈금 REACH IS SKIPPED, NOT MEASURED FARTHER** (2026-09-01, the user
## on what stops the 성채 burning from 눈금 0). The house stands on 눈금 2 and every flat 조각 hugging
## the plateau is 1.414 away from it — inside a 늑대's reach, so **all eight of them burned it without
## anything ever climbing**, and a board where the 계단 can be walked past is a board with no reason to
## defend anything. ⚠ **It is not that height was ignored**: `_dist` squares the rise in and reports
## 1.414 correctly. **The reach is simply longer than that**, and `Grid.can_strike` carries why the
## fix cannot be the reach number.
##
## ⚠⚠ **SKIPPING AND NOT RETURNING EARLY.** The 성채 covers four 조각 at possibly different 눈금, so a
## body may be shut out of the near one and still be level with the far one. **Asking the footprint as
## a whole would answer for a 조각 nobody is beside.**
##
## ⚠ **Both readers get the change from here.** `_phase_targeting` chooses the 성채 through this and
## `_phase_attacks` re-checks the blow through it, so choosing and landing cannot disagree.
func keep_gap(p: Vector2) -> float:
	var from_tile := _tile_of(p)
	if from_tile < 0:
		return INF
	var best := INF
	for k in keep_tiles.size():
		var tile := int(keep_tiles[k])
		if not grid.can_strike(from_tile, tile):
			continue
		best = minf(best, _dist(p, _point_of_tile(tile)))
	return best



# --- phases --------------------------------------------------------------------------------------

## Boat crossings, both legs. Soldiers aboard an OUTBOUND boat are dragged along with it so an enemy
## on the coast can target them where the boat actually is; a RETURNING boat carries nobody, so the
## ⚠⚠ **THE PLAYER'S CROSSING WAS DELETED 2026-08-29 AND THE BEASTS' WAS BUILT 2026-08-30**, not
## resurrected — the user, 2026-08-29: 그때 만드는 게 맞을듯. `_phase_boats` and `_phase_landings` above
## are the beasts', and `boats`, `_next_boat_uid`, `Phase` and `SoldierState.TRANSIT` are still gone.
##
## ⚠⚠ **WHAT THE PLAYER'S CROSSING KNEW, each line a defect that was paid for once:**
##
##  · **A soldier aboard an outbound boat was `is_hittable` and shared the boat's position**, so a
##    crow could already hit one and the tracer had somewhere to land. A crossing that is untargetable
##    is a crossing with no tension in it.
##  · **`TRANSIT` counted as 「still in the fight」 for the verdict.** Collapsing that to ASHORE threw
##    away the last crossing on an island where everything ashore had just died — one sub-step before
##    it resolved.
##  · **Arrival was tested on the arc length, never on proximity to the target**, so a hull that
##    overshot a beach still unloaded.
##  · **Unloading took the nearest FREE walkable tile at the landing's own level**, through the same
##    search `place_ashore` still uses — a keep standing on the aimed tile still lands somebody beside it.
##  · **The append order was the press order**, and two boats aimed at one tile arrived on the same
##    sub-step: whoever unloaded first took the target tile.


func _phase_orders(dt: float) -> void:
	for i in soldier_order.size():
		var dest_tile := int(soldier_order[i])
		if dest_tile < 0:
			continue
		if int(soldier_state[i]) != SoldierState.ASHORE:
			soldier_order[i] = -1
			_clear_path(i)
			continue
		var dest := _point_of_tile(dest_tile)
		var was: Vector2 = soldier_pos[i]
		if was.distance_to(dest) <= Rules.EPS:
			soldier_order[i] = -1
			_clear_path(i)
			if _soldier_stale[i] != 0:
				_settle(i, dest)
				_soldier_stale[i] = 0
			continue
		soldier_pos[i] = _walk(i, was, _soldier_goal, i, army.speed_of(i) * dt,
				field_to(dest_tile), dest, 0.0, _soldier_path, _soldier_path_i, -1, dest_tile)
		_soldier_stale[i] = 1
		# Stuck: it did not move AND it is not part-way across a tile it still has to finish.
		if soldier_pos[i].distance_to(was) <= Rules.EPS 				and was.distance_to(_soldier_goal[i]) <= Rules.EPS:
			soldier_order[i] = -1
			_clear_path(i)


## **The beasts' crossing.** Every sailing hull closes on its resting point, then a new one is born if
## the clock says so.
##
## ⚠⚠ **MOVING COMES BEFORE LAUNCHING, AND THAT IS WHAT MAKES `BOAT_START_DIST_TILES` TRUE.** A boat
## launched first and moved in the same pass is one sub-step nearer the shore than the constant says on
## the very sub-step it is born, so 「배가 24조각 떨어진 데서 뜬다」 would be off by 0.067 조각 with every
## check about the crossing still green. **Born, then still for one sub-step, then sailing.**
##
## ⚠ **The step is clamped to what is left, never overshot.** The old crossing tested arrival on the arc
## length rather than on proximity, and a hull that overshot its beach unloaded anyway; a clamp cannot
## overshoot, so there is no second arrival test to keep in step with the movement.
##
## ⚠⚠ **AND AN EMPTIED HULL COUNTS ITSELF OUT.** `Rules.BOAT_LINGER_SEC` is the wait; at the end of it
## the hull flips to `GONE` where it stands. **Nothing moves and nothing is erased** — see `boat_pos`.
func _phase_boats(dt: float) -> void:
	var step_len := Rules.BOAT_SPEED_TILES * dt
	for i in boat_pos.size():
		var state := int(boat_state[i])
		if state == BoatState.ARRIVED:
			_count_out(i, dt)
			continue
		if state != BoatState.SAILING:
			continue
		var stop: Vector2 = boat_stop[i]
		var here: Vector2 = boat_pos[i]
		var left := here.distance_to(stop)
		if left <= step_len:
			boat_pos[i] = stop
			boat_state[i] = BoatState.ARRIVED
			# Opened here and nowhere else, so 「three seconds」 is three seconds of SITTING and not
			# three seconds that started somewhere out at sea.
			boat_linger[i] = Rules.BOAT_LINGER_SEC
			continue
		boat_pos[i] = here + (stop - here) / left * step_len
	_launch_if_due()


## One ARRIVED hull's wait, one sub-step of it.
##
## ⚠⚠ **THE CLOCK DOES NOT RUN WHILE ANYBODY IS STILL ABOARD, AND WITHOUT THAT THE WAIT IS A LEAK.**
## `_phase_landings` unloads a full deck in one sub-step **only when the beach has room for it** — it
## walks over occupied 조각 and takes what is free, so a crowded shore unloads over several sub-steps
## and a shore with nothing free at all unloads nobody. A hull that timed out in the middle of that
## would take the rest of its 늑대 with it: eight riders paid for, five delivered, **and the count that
## would show it is the one that just disappeared.** ⇒ the wait measures an EMPTY deck sitting there.
func _count_out(i: int, dt: float) -> void:
	if int(boat_riders[i]) > 0:
		return
	var left := float(boat_linger[i]) - dt
	if left <= 0.0:
		boat_linger[i] = 0.0
		boat_state[i] = BoatState.GONE
		return
	boat_linger[i] = left


## Births one boat when the clock has reached the next launch.
##
## ⚠⚠ **THE DUE TIME IS COUNTED OFF `_boats_launched` AND NOT OFF A COUNTDOWN.** `elapsed` is the only
## clock in this file and a countdown beside it would be a second one; worse, a countdown reset by
## subtraction drifts, so the tenth boat would arrive at a time nobody chose.
##
## ⚠ **Half a sub-step of slack, and it is not a fudge.** `elapsed` is a sum of `SIM_SUBSTEP_SEC`, so
## whether it lands a hair above or a hair below an exact 5.0 is decided by the last bit of a 300-term
## float sum. The slack makes the launch happen on the sub-step NEAREST the due time, on every board and
## at every frame rate.
func _launch_if_due() -> void:
	var due := Rules.BOAT_FIRST_SEC + float(_boats_launched) * Rules.BOAT_INTERVAL_SEC
	if elapsed < due - Rules.SIM_SUBSTEP_SEC * 0.5:
		return
	# ⚠ **Counted whether or not a hull is born.** A board with no coast would otherwise be due on every
	# sub-step for the rest of the island.
	_boats_launched += 1
	var ring := grid.beach_ring(Rules.BOAT_START_DIST_TILES)
	if ring.is_empty():
		# **Not swallowed and not an error.** A board with no coast a boat can come to is a board
		# nothing can sail to; barking here would have to be forgiven by every net that hands this file
		# a landlocked fixture, and `net_boats` builds one on purpose.
		return
	var beach := int(ring[_beach_cursor % ring.size()])
	# ⚠ **Asked of the ring's own size, every launch.** A stride stored at `setup` would be right until
	# somebody moved `BOAT_START_DIST_TILES`, which changes how many 조각 the sea can reach and so
	# changes the ring — see `Rules.beach_stride_for`, which records that going wrong twice.
	_beach_cursor = (_beach_cursor + Rules.beach_stride_for(ring.size())) % ring.size()
	# ⚠⚠ **ONE bearing call decides both ends of the crossing**, so the birth point, the resting point
	# and the whole line between them are one straight line by construction rather than by two sums
	# that happen to agree.
	var out := grid.seaward_at(beach)
	var centre := _point_of_tile(beach)
	# ⚠⚠ **THE STOP IS MEASURED FROM THE WATER'S EDGE ON THE APPROACH LINE, NOT FROM THE BEACH 조각.**
	# A standoff taken from the target alone is blind to any other coastline that lies nearer along the
	# same line, and **two arrivals in four put the bow on the grass** — 0.38 조각 over on one straight
	# approach, 0.80 on a diagonal. `Grid.land_reach_along` answers how far the land juts seaward of the
	# beach's own centre; adding the standoff to it leaves exactly the same gap on every side.
	# ⚠ **0 for a clean straight approach**, so the two beaches that were already right do not move.
	# ⚠⚠ **THE HULL'S FORWARD FOOTPRINT AGAINST THE DRAWN SHORE, WITH THE 조각 RULE AS A FLOOR.** A stop
	# measured along the centre line still put the forward SHOULDER on the grass — seen on screen at the
	# five worst beaches, four of them overlapping, every one diagonal or near it. `Grid.hull_stop_along`
	# sweeps the beam; `land_reach_along` is the 조각 answer and is what a board with no outline has.
	# ⚠ **The larger of the two, always.** The outline can ask for more than the 조각 grid and does; it
	# must never be allowed to ask for less.
	# ⚠ **The 조각 rule is the FLOOR the drawn search starts from, not a rival answer to be maxed with.**
	# Maxing them let a hull take the 조각 answer at a beach where the outline had already said that
	# position was on the grass. See `Grid.hull_stop_along`.
	var floor_d := grid.land_reach_along(beach, out, Rules.BOAT_START_DIST_TILES) 			+ Rules.BOAT_STANDOFF_TILES
	var stop_d := grid.hull_stop_along(beach, out, Rules.BOAT_HULL_HALF_TILES,
			Rules.BOAT_HULL_BEAM_TILES * 0.5, Rules.BOAT_BEACH_GAP_TILES, floor_d)
	if stop_d == -INF:
		stop_d = floor_d
	boat_beach.append(beach)
	boat_pos.append(centre + out * Rules.BOAT_START_DIST_TILES)
	boat_stop.append(centre + out * stop_d)
	boat_state.append(BoatState.SAILING)
	boat_riders.append(Rules.BOAT_CAPACITY)
	# ⚠ **0 and not the wait.** A hull at sea has no wait left to spend; the number it will spend is
	# written the moment it stops, so there is exactly one place the wait is opened from.
	boat_linger.append(0.0)


## **An arrived boat puts its riders on the beach.**
##
## ⚠⚠ **ONE AT A TIME THROUGH `land_beast`, AND THAT IS WHAT MAKES 「한 조각에 하나」 STRUCTURAL.** Each
## body reserves the 조각 it takes before the next one searches, so two riders cannot be handed the same
## answer — there is no separate rule saying they must not, and so no rule to forget.
##
## ⚠ **A full beach leaves the rest aboard rather than piling them up or dropping them.** The search
## walks over occupied 조각 and collects free ones, so a crowded shore unloads over several sub-steps;
## a beach with nothing free at all keeps its riders, and they come off when something moves.
##
## ⚠⚠ **ONLY AN `ARRIVED` HULL UNLOADS, WHICH IS WHAT REFUSES A `GONE` ONE.** A hull that has counted
## itself out is not a hull that is still standing off the beach with a deck to walk down; landing off
## one would put 늑대 ashore out of nothing the frame after the picture said the boat was no longer
## there. ⚠ **Written as `!= ARRIVED` and not as `== GONE`**, so a fourth state cannot land bodies by
## default the day somebody adds one.
func _phase_landings() -> void:
	for i in boat_pos.size():
		if int(boat_state[i]) != BoatState.ARRIVED:
			continue
		while int(boat_riders[i]) > 0:
			if land_beast(Rules.BOAT_RIDER_TYPE, int(boat_beach[i])) < 0:
				break
			boat_riders[i] = int(boat_riders[i]) - 1


## **Who each body is hitting, decided fresh every sub-step.**
##
## ⚠⚠ **RE-CHOSEN AND NOT KEPT, WHICH IS A SIMPLIFICATION OF THE DELETED RULE AND IS WRITTEN DOWN AS
## ONE.** The old fight kept a target while it was alive AND in reach, and re-chose the moment either
## failed. **Re-choosing every sub-step is the same answer** — the predicate is exactly 「alive and in
## reach」 and nothing here is sticky — and it is one rule instead of two that have to agree. ⚠ It stops
## being the same answer the day a blow has a wind-up: a declaration has to survive the body drifting
## out of reach, and that is the paragraph to read when the lion's telegraph comes back.
##
## ⚠⚠ **A 검사 IN REACH BEATS THE 성채.** A 늑대 walks at the house and swings at whatever gets between,
## so a defender who has closed is what it is fighting — and without this order eight 늑대 would stand
## in a line of swordsmen hammering the wall behind them.
##
## ⚠⚠ **TWO TIERS SINCE 2026-09-02, AND THE REACH TIER IS THE OLD RULE UNCHANGED** (ticket 07-01, the
## user watching a 검사 and a 늑대 pass within two 조각 of each other and walk on). **A body it can
## strike inside `reach_of` beats everything; for a 늑대 the 성채 inside `reach_of` comes next; and only
## then — new — the nearest body inside `detect_of`**, which is aim and walk and never a blow.
## ⚠⚠ **THE DETECT TIER SITS BELOW THE WALL, AND THAT IS THE USER'S ANSWER** (2026-09-02, answer 1 on
## 07-01: 「추천댜로 ㅇㅇ」 — *"as recommended, yes"*): a 늑대 that can already hit the house keeps
## hitting it, and a defender three 조각 off is seen only by a 늑대 still walking. Written 검사-first
## the loss condition leaves the board — one defender near the house stops every wave — and
## `net_fight`'s 「늑대가 벽에 붙었으면 벽을 지킨다」 is the tripwire that reddens on it.
## ⚠ **`Grid.can_strike` guards the reach tier ONLY, through `_can_hit`.** Without it a body aims at
## the nearer thing it cannot hit and never swings at the further thing it can — a 검사 on the plateau
## with a 늑대 below at 1.414 and one on the 계단 at 1.5 would stand aiming down forever. The detect
## tier does NOT carry it: a body it cannot strike is still a body it notices, walks at and faces.
##
## ⚠ **A 검사 never targets the 성채.** It is his.
## ⚠ **Reach is read per BODY (`army.reach_of(i)`) and detect per TYPE (`Rules.detect_of`).** Harmless
## while no per-body detect exists — 07-01 refused a new column — but the day 장비칸 gives a body its
## own radius, the detect read below is the one that has to move to `Army`, or a body's own number is
## silently the type's.
func _phase_targeting() -> void:
	for i in soldier_state.size():
		if int(soldier_state[i]) != SoldierState.ASHORE:
			soldier_target[i] = TARGET_NONE
			continue
		var hit := _nearest_enemy(soldier_pos[i], army.reach_of(i), true)
		if hit >= 0:
			soldier_target[i] = hit
		else:
			soldier_target[i] = _nearest_enemy(soldier_pos[i], Rules.detect_of(int(army.type_id[i])), false)

	for e in enemy_type.size():
		if enemy_alive[e] == 0:
			enemy_target[e] = TARGET_NONE
			continue
		var ty := int(enemy_type[e])
		var reach := Rules.reach_of(ty)
		var who := _nearest_soldier(enemy_pos[e], reach, true)
		if who >= 0:
			enemy_target[e] = who
		elif keep_gap(enemy_pos[e]) <= reach + Rules.EPS:
			enemy_target[e] = TARGET_KEEP
		else:
			# `TARGET_NONE` when nobody is inside the radius — the scan's own answer.
			enemy_target[e] = _nearest_soldier(enemy_pos[e], Rules.detect_of(ty), false)


## Everyone walks toward their target and **stops the instant it is in reach**. Without that one
## rule a range-4 soldier walks all the way into melee and the ranged type stops existing; the plan
## measured it moving island 3's damage taken by 30%.
func _phase_movement(dt: float) -> void:
	_age_fields(dt)

	for i in soldier_state.size():
		if soldier_state[i] != SoldierState.ASHORE:
			continue
		# ⚠ **`_phase_orders` already moved this one.** Falling through would walk it twice in one
		# sub-step — at double speed, and toward two different places.
		if int(soldier_order[i]) >= 0:
			continue
		# ⚠⚠ **THE CHASE STOOD HERE AND IT IS DELETED** (2026-08-29) with the fight. A body with no
		# order read `soldier_target`, walked at that enemy's position and stopped inside its reach.
		# **Nothing walks on its own now** — an unordered body finishes the 조각 it already reserved and
		# stands.
		#
		# ⚠ **Finishing the reserved 조각 is not tidiness.** Stopping mid-조각 leaves the body holding
		# BOTH for the rest of the island, which halves a doorway's throughput with nothing on screen to
		# explain it.
		var goal: Vector2 = _soldier_goal[i]
		if soldier_pos[i].distance_to(goal) > Rules.EPS:
			soldier_pos[i] = _glide(soldier_pos[i], goal, army.speed_of(i) * dt)
		elif _soldier_stale[i] != 0:
			_settle(i, goal)
			_soldier_stale[i] = 0

	# ⚠⚠ **THE BEASTS WALK AT THE 성채, OR AT THE 검사 THEY NOTICED** (ticket 07-01, 2026-09-02). Until
	# then this said 「at the 성채 and at nothing else … there is no detect radius in this path, and
	# `UNITS`' detect column has no reader」 — 티켓 41's 「늑대가 무엇을 향해 걷나 — 성채」 whole. The
	# user watched a 늑대 walk past a 검사 two 조각 off and reversed it; `Rules.detect_of` is the
	# reader now and `_phase_targeting` is where the choice is made. **This phase only obeys the column.**
	# ⚠⚠ **THE TARGET CHOICE AND THIS GATE CHANGED IN ONE EDIT, AND THE GAME DOES NOT RUN BETWEEN THE
	# TWO HALVES.** Before, ANY target but `TARGET_NONE` was 「stand」. Widening the choice alone would
	# freeze every 늑대 six 조각 short of the 검사 it just noticed — and stop it walking at the 성채 too.
	# ⚠ **`keep_level` is -1 for every one of them.** Nothing starts high this round — see the column
	# block at the top of this file for why that is a decision rather than a gap.
	var anchor := -1 if keep_tiles.is_empty() else int(keep_tiles[0])
	for e in enemy_type.size():
		if enemy_alive[e] == 0:
			continue
		var ty := int(enemy_type[e])
		var reach := Rules.reach_of(ty)
		var speed := Rules.speed_of(ty) * dt
		var here: Vector2 = enemy_pos[e]
		var e_goal: Vector2 = _enemy_goal[e]
		var tgt := int(enemy_target[e])
		# **Where this body walks, as a 조각 and the point it stops short of** — or -1 for 「stand」.
		#  · `TARGET_KEEP`: it is at the wall. Stand.
		#  · a 검사 already inside `reach_of`: stand — strikable or not, which is what keeps a 늑대 under
		#    a plateau standing at 1.732 rather than pacing (`net_fight`, the [stands] row of 07-01).
		#  · a 검사 further off: walk at him, the same `_walk` the 성채 path takes, his 조각 as the key.
		#    ⚠ A route that passes the house stops at the house — the next targeting pass finds the
		#    wall in reach and the wall outranks the detect tier. That is answer 1's consequence.
		#  · nothing, with a 성채 on the board: walk at the 성채 — the rule before this ticket.
		#  · nothing, and no 성채: stand. ⚠⚠ **`anchor < 0` alone is no longer 「stand」** — a board
		#    with no house is exactly the board the complaint was measured on, and a careless edit that
		#    keeps the old test freezes the 늑대 there with its target set.
		var to_tile := -1
		var to_pt := OFFMAP
		if tgt >= 0:
			if _dist(here, soldier_pos[tgt]) > reach + Rules.EPS:
				to_pt = soldier_pos[tgt]
				to_tile = _tile_of(to_pt)
		elif tgt == TARGET_NONE and anchor >= 0:
			to_tile = anchor
			to_pt = _point_of_tile(anchor)
		# **Standing**: finish the 조각 already reserved, then stand. ⚠ **Finishing it is not tidiness**
		# — stopping mid-조각 holds BOTH for the rest of the island, which halves a doorway with nothing
		# on screen to explain it.
		if to_tile < 0:
			if here.distance_to(e_goal) > Rules.EPS:
				enemy_pos[e] = _glide(here, e_goal, speed)
			elif _enemy_stale[e] != 0:
				_settle(ENEMY_UID_BASE + e, e_goal)
				_enemy_stale[e] = 0
			continue
		# ⚠ **Empty route columns.** A beast is never ordered, so it has no straightened route to walk —
		# it descends the field, which is what `_next_goal` falls back to.
		# ⚠ **A field to a 조각 this body cannot reach is `UNREACHABLE` everywhere but the seed**, so
		# `step_toward` finds no cheaper neighbour and the body stands — the queue at a neck, not a spin.
		enemy_pos[e] = _walk(ENEMY_UID_BASE + e, here, _enemy_goal, e, speed,
				field_to(to_tile), to_pt, reach, [], [], -1, to_tile)
		_enemy_stale[e] = 1


## --- THE FIGHT --------------------------------------------------------------------------------------
## ⚠⚠ **DELETED 2026-08-29, REBUILT 2026-08-30** (티켓 41's 목~일 slice). The user deleted it because
## nothing could reach it — ***"그냥 지워도됨 아직 전투 전혀 없어"*** — and what reaches it now is a boat
## that lands 늑대.
##
## **Four of the lessons the deleted block carried are honoured in the code above and below**: damage
## and death in different phases, deaths latching in the SAME sub-step as the blow, nothing holding a
## storey it did not start on, and a verdict that needs a 성채 to be about. **Three are NOT built and are
## kept here rather than pretended:**
##
##  · **The heavy attack was TELEGRAPHED** — the lion declared its blow 0.6 s ahead, as per-body state
##    the view drew for its whole length. **A dead attacker's declaration dies with it**, or the view
##    keeps drawing a telegraph over a corpse. **There is no wind-up in this game today**: a body swings
##    the sub-step it comes into reach.
##  · **A blow's victims were resolved ONCE** — the primary and the splash list — and every effect read
##    that one list. **There is no splash today**: `UNITS`' area column has no reader, and the two rows
##    that carry one (곰 · 사자) are not in this fight.
##  · **WON was checked before either loss.** 티켓 41: 「이기는 조건 — 이번 주에 없다」, so there is one
##    verdict and nothing to order it against.


## **The blows, and the cooldown that spaces them.**
##
## ⚠⚠ **REACH IS RE-CHECKED HERE AND NOT INHERITED FROM `_phase_targeting`.** Movement runs between the
## two, so a body may have finished a 조각 and drifted out of the reach the choice was made in — landing
## the blow anyway is a hit from further than the rule allows, on every frame, invisibly.
##
## ⚠⚠ **0 IS READY AND A BODY THAT HAS JUST ARRIVED IS READY.** The alternative is a period of dead time
## at every contact, and 「붙어서 가만히 있으면 재미가 죽는다」 is the user's line about exactly that.
## ⚠ **The ready test carries `EPS` rather than being `<= 0.0`.** The clock is a sum of sub-steps against
## a period that divides it exactly, so the last bit decides whether a blow lands on the 60th sub-step or
## the 61st — and a bare comparison there is a coin flip that changes an outcome.
##
## ⚠⚠ **A BLOW IS TWO SUB-STEPS APART: THE SWING, THEN THE LANDING** (2026-09-02). A ready body with a
## target in reach STARTS a swing — winds its cooldown to the whole period and its `*_swing` clock to
## `Rules.SWING_LAND_SEC`, and locks the target in `*_swing_at`. **The damage is dealt on the sub-step
## that clock runs out**, against the locked target, and only if it is still alive, still standing and
## still in reach — a body that walked off, or died under someone else's sword, is not hit by a blow
## thrown at where it was. **A swing that finds nothing costs the period all the same**: the body swung.
## ⚠ **The reach re-check moved from the start of the swing to its landing** and is checked at BOTH — a
## swing is not thrown at a body out of reach, and does not land on one that left.
## ⚠ **A body in the middle of a swing does not start another**, whatever its cooldown says — the two
## clocks are wound together and the period is longer than the swing, so this cannot happen today; the
## test is here so that the day a period is shortened under 0.4 s it still cannot.
## ⚠⚠ **BOTH BODY BLOWS GO THROUGH `_can_hit` SINCE 2026-09-02** (ticket 07-01, the user's answer 2) —
## the 눈금 guard the 성채 blow got in 02-01 through `keep_gap`, brought to the body blow. Until then a
## 늑대 on the flat hit a 검사 on 눈금 2 at 1.414, and the gap was unreachable in play only because a
## beast never walked at a body; **the chase is what walks it there**, so the guard lands in the same
## edit as the chase or 눈금 2 stops being safe ground. ⚠ **The 성채 blow is untouched** — `keep_gap`
## already carries `can_strike`.
func _phase_attacks(dt: float) -> void:
	for i in soldier_state.size():
		if int(soldier_state[i]) != SoldierState.ASHORE:
			continue
		soldier_cool[i] = maxf(float(soldier_cool[i]) - dt, 0.0)
		if float(soldier_swing[i]) > 0.0:
			soldier_swing[i] = maxf(float(soldier_swing[i]) - dt, 0.0)
			if float(soldier_swing[i]) <= Rules.EPS:
				soldier_swing[i] = 0.0
				_land_soldier_blow(i)
			continue
		var tgt := int(soldier_target[i])
		if tgt < 0 or float(soldier_cool[i]) > Rules.EPS:
			continue
		if enemy_alive[tgt] == 0:
			continue
		if not _can_hit(soldier_pos[i], enemy_pos[tgt], army.reach_of(i)):
			continue
		soldier_swing[i] = Rules.SWING_LAND_SEC
		soldier_swing_at[i] = tgt
		soldier_cool[i] = army.period_of(i)

	for e in enemy_type.size():
		if enemy_alive[e] == 0:
			continue
		enemy_cool[e] = maxf(float(enemy_cool[e]) - dt, 0.0)
		if float(enemy_swing[e]) > 0.0:
			enemy_swing[e] = maxf(float(enemy_swing[e]) - dt, 0.0)
			if float(enemy_swing[e]) <= Rules.EPS:
				enemy_swing[e] = 0.0
				_land_enemy_blow(e)
			continue
		var etgt := int(enemy_target[e])
		if etgt == TARGET_NONE or float(enemy_cool[e]) > Rules.EPS:
			continue
		var ty := int(enemy_type[e])
		var reach := Rules.reach_of(ty)
		if etgt == TARGET_KEEP:
			if keep_gap(enemy_pos[e]) > reach + Rules.EPS:
				continue
		else:
			if int(soldier_state[etgt]) != SoldierState.ASHORE:
				continue
			if not _can_hit(enemy_pos[e], soldier_pos[etgt], reach):
				continue
		enemy_swing[e] = Rules.SWING_LAND_SEC
		enemy_swing_at[e] = etgt
		enemy_cool[e] = Rules.period_of(ty)


## **The landing of a 검사's swing** — the damage, if the beast it was thrown at is still there to take
## it. `soldier_blows` rises only on the line the health falls.
## ⚠ **The landing re-check is `_can_hit`, not `_dist`** — the 눈금 guard 07-01 put on the body blow
## (merged 2026-09-03) has to hold at the landing too, or a body that climbed a stair during the 0.4 s is
## hit across a gap the rule forbids.
func _land_soldier_blow(i: int) -> void:
	var tgt := int(soldier_swing_at[i])
	if tgt < 0 or tgt >= enemy_alive.size() or enemy_alive[tgt] == 0:
		return
	if not _can_hit(soldier_pos[i], enemy_pos[tgt], army.reach_of(i)):
		return
	enemy_hp[tgt] = float(enemy_hp[tgt]) - army.damage_of(i)
	soldier_blows[i] = int(soldier_blows[i]) + 1


## **The landing of a beast's swing**, on the 성채 or on the 검사 it was thrown at.
func _land_enemy_blow(e: int) -> void:
	var etgt := int(enemy_swing_at[e])
	var ty := int(enemy_type[e])
	var reach := Rules.reach_of(ty)
	if etgt == TARGET_KEEP:
		if keep_gap(enemy_pos[e]) > reach + Rules.EPS:
			return
		keep_hp -= Rules.damage_of(ty)
	else:
		if etgt < 0 or etgt >= soldier_state.size():
			return
		if int(soldier_state[etgt]) != SoldierState.ASHORE:
			return
		if not _can_hit(enemy_pos[e], soldier_pos[etgt], reach):
			return
		soldier_hp[etgt] = float(soldier_hp[etgt]) - Rules.damage_of(ty)
	enemy_blows[e] = int(enemy_blows[e]) + 1


## **Everything at or below 0 HP dies, in the sub-step the blow landed and in a phase of its own.**
##
## ⚠⚠ **THE ROW STAYS.** `enemy_alive` flips to 0 and the index keeps naming the same body forever —
## `grid.reserved`, the target columns and the view all hold indices, and compacting renumbers every one
## of them with nothing to bark about it.
##
## ⚠⚠ **A CORPSE LETS GO OF ITS 조각 AND EVERY POINTER AT IT IS CLEARED IN THE SAME PLACE.** Four things
## move together here and three of them are invisible: the reservation, the target columns naming the
## dead body, the drifting goal, and the position. **Leaving the goal set is what makes a body slide
## toward (-1,-1) at walking speed** — measured once, and `place_ashore`'s header still records it.
func _phase_deaths() -> void:
	for e in enemy_type.size():
		if enemy_alive[e] == 0 or float(enemy_hp[e]) > 0.0:
			continue
		enemy_alive[e] = 0
		enemy_hp[e] = 0.0
		enemy_target[e] = TARGET_NONE
		_enemy_stale[e] = 0
		grid.release_all(ENEMY_UID_BASE + e)
		enemy_pos[e] = OFFMAP
		_enemy_goal[e] = OFFMAP
		for i in soldier_target.size():
			if int(soldier_target[i]) == e:
				soldier_target[i] = TARGET_NONE

	for i in soldier_state.size():
		if int(soldier_state[i]) != SoldierState.ASHORE or float(soldier_hp[i]) > 0.0:
			continue
		soldier_hp[i] = 0.0
		soldier_state[i] = SoldierState.DEAD
		soldier_order[i] = -1
		soldier_target[i] = TARGET_NONE
		_soldier_stale[i] = 0
		_clear_path(i)
		grid.release_all(i)
		soldier_pos[i] = OFFMAP
		_soldier_goal[i] = OFFMAP
		soldier_revive[i] = Rules.REVIVE_SEC
		for e2 in enemy_target.size():
			if int(enemy_target[e2]) == i:
				enemy_target[e2] = TARGET_NONE


## **A dead 검사 counts down and stands again at the 성채.**
##
## ⚠⚠ **THE 성채 NO LONGER TURNS OUT NEW ONES HERE** (2026-09-02, the user: 「자동 병사 생성 지워줘」).
## The twenty-second clock that followed this loop is deleted with `Rules.MUSTER_PERIOD_SEC`; a new
## body stands only when something calls `recruit`, and nothing in `src/` does today.
##
## ⚠⚠ **「죽으면 영영 죽는다」 WAS OVERTURNED 2026-08-30** — the user weighed both and chose revival.
## **Death is a loss of TIME now**, and `Rules.REVIVE_SEC` is the whole of what it costs.
##
## ⚠⚠ **`army.alive` IS STILL READ AND IT IS NOT THE SAME QUESTION.** A body the ROSTER killed is dead
## across islands and is not coming back; `setup` puts one straight into DEAD, and without this line it
## would muster itself on the first sub-step of every island afterwards.
##
## ⚠ **Nowhere to stand is a retry, not a loss.** `stand_at_keep` answers -1 for a board with no 성채 and
## for a doorstep with nothing free beside it — the second is temporary, so the body stays DEAD at zero
## on the clock and tries again next sub-step.
func _phase_muster(dt: float) -> void:
	for i in soldier_state.size():
		if int(soldier_state[i]) != SoldierState.DEAD:
			continue
		if army.alive[i] == 0:
			continue
		soldier_revive[i] = maxf(float(soldier_revive[i]) - dt, 0.0)
		if float(soldier_revive[i]) > Rules.EPS:
			continue
		soldier_state[i] = SoldierState.RESERVE
		if stand_at_keep(i) < 0:
			soldier_state[i] = SoldierState.DEAD


## --- THE SHOVE AND THE CHARGE: DELETED 2026-08-27 --------------------------------------------------
## `_shove_victims`, `_shove` and the `_charged` column are gone with `Rules.SPECIES_SHOVE`. The table
## had been `[]` since 2026-08-26: its two rows were 다람쥐's pull and 소's charge, and both species
## left `UNITS` with the side swap. **`shove_tiles_of` therefore returned 0.0 on every blow**, so every
## attack in the game ran the guard and then returned, one lookup per hit, forever.
##
## ⚠⚠ **THREE THINGS IT KNEW ARE WORTH MORE THAN THE CODE, AND THE FIRST IS A USER DECISION.**
##
## 1. **A body never changes tier by being pushed** (티켓 19, the user: 「높은 데서 밀리면 안 떨어져.
##    안 떨어지는 걸로」). Before that was written in, 소's charge shoved enemies UP onto a plateau and
##    다람쥐's pull dragged them DOWN off one — the decision inverted, by the same omission that once
##    put landed bodies on top of a wall: placement that never consulted the tier. **A shove is not a
##    step and may not use a stair either**, because a body flung a tier up a staircase is the falling
##    rule wearing a different hat. ⇒ **Anything that moves a body without it walking inherits this.**
##
## 2. **Four things move together and three of them are invisible.** Writing `enemy_pos` alone reads as
##    a shove for exactly one sub-step and then undoes itself: `_phase_movement`'s standing branch
##    glides the body back toward `_enemy_goal`, `_walk` re-picks that same stale goal, and
##    `grid.reserved` still holds the tile the body LEFT — so two bodies hold one tile and a doorway is
##    half as wide with nothing on screen to explain it. ⇒ `enemy_pos`, `_enemy_goal`, `_settle` and
##    `_enemy_stale` all had to move in one place.
##
## 3. **A once-per-island charge is spent by the MOVE, never by the attempt.** Setting the flag first
##    spent 소's whole island on a target with its back to a wall: the shove refused to place a body on
##    a blocked tile, the charge was consumed by a blow that moved nobody, and every later blow was
##    refused for a charge that never happened.
##
## ⚠ **It walked tile by tile rather than jumping to the endpoint** — a jump can land past a wall, past
## a body, or on top of the attacker, and stopping at the last legal tile is what made 「지나쳐 넘어가지
## 않는다」 a property of the search instead of a rule somebody has to remember.


## --- STATUSES: DELETED 2026-08-29 -----------------------------------------------------------------
## ⚠⚠ **`_status_at` · `status_left` · `status_mag_of` · `_apply_statuses` · `_put_status` ·
## `_phase_status` · `_slow_mul_of` STOOD HERE AND ALL SEVEN ARE GONE**, with `status_time` and
## `status_mag` above them and the whole status half of `rules.gd`. **They went because no blow could
## light one.** Every tier came from `army.loadout.tag_count(...)`, the refit screen that fitted an
## item was deleted 2026-08-28, and an unfitted board answers 0 — so **bleed and slow never fired once
## in a fight the player played**, while `field_view` faithfully tinted a body by a clock that was
## always zero.
##
## ⚠⚠ **WHAT TO KEEP WHEN IT COMES BACK, because each line is a measured defect and not a preference:**
##
##  · **A status is a TABLE ROW plus one generic walk here, never bleed-shaped code.** The day poison
##    arrives it is one `Status` entry and one tier row and this file stays shut.
##  · **The clocks were FLAT and indexed `s * enemy_count + e` through one accessor.** A view that
##    re-derived that arithmetic is how the wrong enemy gets read the day a status is appended.
##  · **Writing a status was an OVERWRITE, never an accumulate.** Folding a magnitude onto itself lets
##    six fast blows rebuild a mine that was measured and rejected.
##  · **EVERY SOURCE FOR ONE BLOW WAS RESOLVED BEFORE ANYTHING WAS WRITTEN, AND THE STRONGEST WON.**
##    Written one after the other, a 까마귀 in a full bleed set bit for 0.5 s where a 늑대 in the same
##    set bit for 1.5 — **the crow was penalised by its own passive.**
##  · **What a blow leaves rode ONE line with the same victims** — the primary and the splash list,
##    resolved once, never walked a second time per effect.
##  · **Only the allied blow left anything.** `_hit_soldiers` had no twin, so an enemy could never
##    leave a status on a soldier.


## Everything at or below 0 HP dies, and the row stays. `army.kill` keeps the roster's history so a
## soldier's id names the same soldier for the whole run — the plan's "permanent death".
# --- movement helpers ----------------------------------------------------------------------------

## Walks up to `step_len` tiles down `field`, tile by tile, stopping the moment it comes within
## `stop_dist` of `stop_at`.
##
## The per-tile loop is not an optimisation: with one tile per call a 0.5 s frame caps every unit at
## 2 tiles/s regardless of its speed row, so the ranged types and the crow would quietly lose their
## speed advantage the moment a probe stepped in anything but tiny increments.
##
## `goals` is a plain Array on purpose — a `PackedVector2Array` is copy-on-write and a write through
## a parameter would land in a copy, leaving every unit re-requesting the same first step forever.
## `keep_level` is passed straight to `grid.step_toward` — -1 for everybody except a defender holding
## high ground. See `_enemy_home_level`.
## `target_tile` is the 조각 `field` was built from; it reaches `step_toward`'s tie-break so an equal-cost
## step goes along the line to the goal rather than off it.
## ⚠⚠ **`paths` AND `path_is` ARE PARAMETERS AND THEY USED TO BE READ STRAIGHT OFF `_soldier_path`**
## (fixed 2026-08-30). `goals` was already an argument because a `PackedVector2Array` written through one
## lands in a copy — but the ROUTE was reached for by name, so this function only worked for a 검사.
## **The first beast that walked indexed the 검사 columns and went out of bounds**, and it did it inside
## `_phase_movement` where a `push_error` is not a stop: the round filled with backtraces and timed out.
## ⇒ **A caller with no straightened route hands in empty arrays**, and 「no route」 is then a fact about
## the argument rather than about which side is calling.
func _walk(uid: int, pos: Vector2, goals: Array, gi: int, step_len: float,
		field: PackedInt32Array, stop_at: Vector2, stop_dist: float,
		paths: Array, path_is: Array,
		keep_level: int = -1, target_tile: int = -1) -> Vector2:
	var remaining := step_len
	var guard := 0
	var here := pos
	while remaining > Rules.EPS:
		guard += 1
		if guard > WALK_TILES_MAX:
			break
		# ⚠⚠ **`_dist` AND NOT `distance_to`, AND THIS ONE LINE FROZE THE GAME.** Everything else that
		# asks "how far" moved onto the height-aware distance and this arrival test did not, which left
		# a BAND at every tier boundary: a low tile inside a body's PLANAR reach of something standing a
		# tier up. A body told to walk exits here on the first iteration, cannot attack because the real
		# distance is 2.236, and never moves again — **12 seconds, zero pixels, nothing logged, and no
		# time limit left to end the island on.** Measured with three wolves against a plateau lion.
		# ⇒ **The stop test and the reach test have to be the same question**, or "arrived" and "in
		# reach" disagree and the gap between them is a body standing still forever.
		if _dist(here, stop_at) <= stop_dist + Rules.EPS:
			break
		var goal: Vector2 = goals[gi]
		if here.distance_to(goal) <= Rules.EPS:
			goal = _next_goal(uid, gi, here, field, paths, path_is, keep_level, target_tile)
			goals[gi] = goal
			if here.distance_to(goal) <= Rules.EPS:
				# Every neighbour is taken or none is closer: the unit stands. That is the queue at
				# a two-tile neck, and it is the whole reason reservation exists.
				break
		var to_go := here.distance_to(goal)
		if to_go <= remaining:
			here = goal
			remaining -= to_go
		else:
			here += (goal - here) / to_go * remaining
			remaining = 0.0
	return here


## **The next 조각 this body should walk to: the straightened route if it is still on it, the field
## otherwise.** Returns `here` unchanged when nothing is open, which is the queue at a neck.
##
## ⚠ **`gi` addresses the per-body columns and `uid` is the reservation id.** They are the same soldier at
## the only call site; the two names are kept apart because one is an index and one is an identity.
##
## The three steps, in this order:
##
## 1. ⚠⚠ **RESYNC FIRST, EVERY TIME, AND IT IS THE ADJACENCY GUARANTEE RATHER THAN TIDINESS.**
##    `order_walk` builds the list from the 조각 the body's position rounds to, but the body may be
##    half-way across a 조각 it already reserved — `_soldier_goal` points forward and `_walk` glides there
##    first — so the stored index can be pointing at a neighbour of a 조각 the body has already left, up
##    to two 조각 away and possibly behind it. **`step_along` refuses a non-adjacent 조각**, so without
##    this the straightened route would simply stop working, quietly. Consecutive entries in the list are
##    8-neighbours by construction, so resyncing makes the argument adjacent by construction too.
##    ⚠ **The search starts one entry BEHIND the index and never earlier.** The index names the NEXT 조각,
##    so the body is normally standing on the one before it — starting at the index itself would fail to
##    find the body on its very first step and throw the route away before it was used. Starting one
##    behind, the new index is never lower than the old one, which is what stops a body shuffling between
##    two 조각 forever.
##    ⚠ **Not found means the route is dropped**, not rebuilt: the field underneath is already correct.
## 2. **The route**, through `step_along`.
## 3. **Otherwise the field**, exactly as before this ticket. The next sub-step's resync decides whether
##    the straightened route is rejoined — which is what makes the field the always-valid fallback.
func _next_goal(uid: int, gi: int, here: Vector2, field: PackedInt32Array,
		paths: Array, path_is: Array, keep_level: int, target_tile: int) -> Vector2:
	# ⚠ **An empty list is a body that walks on the field alone**, which is what every body did before
	# 티켓 37 and is still the always-valid fallback — and it is now also every beast.
	var path: PackedInt32Array = paths[gi] if gi < paths.size() else PackedInt32Array()
	if not path.is_empty():
		var tile := _tile_of(here)
		var idx := int(path_is[gi])
		var at := -1
		for m in range(maxi(idx - 1, 0), path.size()):
			if int(path[m]) == tile:
				at = m
				break
		if at < 0:
			# ⚠ **Reachable only for a body that HAS a route, and only a 검사 ever has one** — a beast
			# hands in empty columns and never enters this branch. `_clear_path` stays the one owner of
			# 「throw the route away」 rather than these two writes being spelled out a second time here.
			_clear_path(gi)
		else:
			idx = at + 1
			path_is[gi] = idx
			if idx < path.size():
				var moved := grid.step_along(uid, here, int(path[idx]), keep_level)
				if here.distance_to(moved) > Rules.EPS:
					path_is[gi] = idx + 1
					return moved
	return grid.step_toward(uid, here, field, keep_level, target_tile)


## Throws the straightened route away. **Called at every site that clears an order** — a route that
## outlives its order walks a body somewhere nobody asked.
func _clear_path(i: int) -> void:
	if i < 0 or i >= _soldier_path.size():
		return
	_soldier_path[i] = PackedInt32Array()
	_soldier_path_i[i] = 0


## Gives back the tile behind a unit that has stopped for good, keeping only the one it stands on.
## `step_toward` is what normally swaps the two-tile hold, so a unit that never steps again would
## keep the tile behind it forever and a queue at a neck would be half as wide as the neck.
##
## The caller clears the stale flag so this runs once per stop and not every frame: `release_all`
## rescans the whole reservation table, and doing that for every idle unit every frame is 690k
## operations a second for no change at all.
##
## The flag itself is NOT passed in. A `PackedByteArray` parameter is a copy-on-write copy, so
## clearing it here would land in the copy and this would run again every single frame — measurably
## slower with every check about it still green.
func _settle(uid: int, goal: Vector2) -> void:
	grid.release_all(uid)
	var tile := _tile_of(goal)
	if tile < 0:
		return
	grid.hold(uid, tile)


func _glide(pos: Vector2, goal: Vector2, step_len: float) -> Vector2:
	var to_go := pos.distance_to(goal)
	if to_go <= Rules.EPS or step_len >= to_go:
		return goal
	return pos + (goal - pos) / to_go * step_len


## **How far apart two points are, height included — and the ONLY place this file measures a distance
## between bodies.** 티켓 19.
##
## Bodies keep 2D positions: height is a property of the 조각, not of the body, so nothing about
## `soldier_pos`, the screen or three thousand existing net literals had to move to bring the axis in.
## The ground's own height is looked up and folded in here.
##
## ⚠⚠ **IT SURVIVED THE FIGHT'S DELETION BECAUSE `_walk` STOPS ON IT** (2026-08-29). Reach, target
## choice and the pack radius all went through it too and all three are gone; **the arrival test is
## what is left**, and it is the caller that mattered most.
##
## ⚠⚠ **`_walk` USING `distance_to` HERE INSTEAD FROZE THE GAME ONCE.** Everything else that asked
## 「how far」 moved onto this and the arrival test did not, which left a BAND at every storey boundary:
## a low 조각 inside a body's PLANAR reach of something standing a storey up. A body told to walk exits
## on the first iteration, cannot act because the real distance is 2.236, and never moves again —
## **12 seconds, zero pixels, nothing logged.** ⇒ **The stop test and whatever asks 「am I there」 have
## to be the same question**, or the gap between them is a body standing still forever.
##
## ⚠ **The equal-height branch returns `distance_to` unchanged** rather than a square root of a sum
## with a zero in it. Most boards are flat, and taking the same expression as before on those boards
## is what makes 「no existing literal moves」 a property of the code instead of a hope about floats.
##
## ⚠⚠ **ANYTHING THAT EVER MEASURES FROM A POINT NOBODY STANDS ON must carry its own height** — a
## mean, a formation anchor, a cursor — rather than let this function round one off the ground. It is
## written down because it was paid for: three wolves on the flat with one packmate on a plateau
## averaged onto a plateau 조각, so all four measured from **one storey up**, preferred the enemy
## above, and walked into the wall.
func _dist(a: Vector2, b: Vector2) -> float:
	var dh := grid.height_at(a) - grid.height_at(b)
	if absf(dh) <= Rules.EPS:
		return a.distance_to(b)
	return sqrt(a.distance_squared_to(b) + dh * dh)


# --- targeting helpers -----------------------------------------------------------------------------
## ⚠⚠ **`_soldier_reach` · `_enemy_reach` · `_within` STOOD HERE AND ARE NOT COMING BACK AS FUNCTIONS.**
## Reach is `range + REACH_BONUS` and **`Rules.reach_of` is the one place that sum is written** — two
## per-side wrappers over one rule is the second copy this file has paid for elsewhere.
##
## **What the deleted pair knew and what the two below keep:**
##
##  · **Distance is 3D and the height comes from the LEVEL, never from the drawn mesh** — `_dist`, which
##    survived the deletion because `_walk` stops on it.
##  · **The comparison carries an epsilon.** A diagonal is exactly sqrt(2); a bare `<=` on that boundary
##    is a coin flip that changes which bodies can fight from frame to frame.
##  · **Nearest is Euclidean and ties go to the SMALLER index.** A tie broken by iteration order makes
##    two runs from identical state diverge with every check about them green.
##  · ⚠ **An enemy's movement scan and its target scan were different sets, and here they are different
##    QUESTIONS.** ⚠⚠ **This line said 「a beast walks at the 성채 and never at a body, so nothing can
##    ask the flow field for a path to something unreachable」 — and since 2026-09-02 (ticket 07-01)
##    THAT IS NO LONGER TRUE.** A 늑대 on the beach walks at a 검사 it noticed, who may stand on a 눈금
##    it cannot climb to. What keeps that from freezing the island: a field to an unreachable 조각 is
##    `UNREACHABLE` everywhere but the seed, `step_toward` finds no cheaper neighbour, and `_walk`
##    returns `here` — the body stands where it is, which is the queue at a neck and not a spin.
##    `net_fight`'s [stands] row of 07-01 measures it rather than argues it.

## **Whether a body at `a` can land a blow on a body at `b` with `reach`**: the 눈금 gap through
## `Grid.can_strike` on the two 조각, and the 3D distance through `_dist`, in one place.
##
## ⚠⚠ **ONE PLACE, FOR THE REASON `Rules.reach_of` IS ONE PLACE** (ticket 07-01, the user's answer 2,
## 2026-09-02). The reach tier of both target scans and both body blows in `_phase_attacks` read this,
## so choosing and landing cannot disagree — the shape `keep_gap` already gave the 성채 blow in 02-01.
## Two copies of the strike rule drift, and the drift is a body aiming at what it cannot hit.
## ⚠ **`can_strike` is an absolute gap**, so a 검사 above cannot hit down either — 02-01's 「위에서
## 아래로도 못 때린다」 holds body against body.
func _can_hit(a: Vector2, b: Vector2, reach: float) -> bool:
	return grid.can_strike(_tile_of(a), _tile_of(b)) and _dist(a, b) <= reach + Rules.EPS


## **The nearest living beast within `reach` of `p`, or `TARGET_NONE`.** Ties go to the lower index.
##
## ⚠ **`< best` and never `<= best`**, which is the whole of the tie-break: the loop runs upward, so a
## later body has to be strictly nearer to displace an earlier one.
## ⚠ **`must_strike` is the reach tier's flag** — admission through `_can_hit`, the 눈금 included —
## and off it is the detect tier's bare distance. A flag and not a twin function, so the tie-break and
## the loop are written once.
func _nearest_enemy(p: Vector2, reach: float, must_strike: bool) -> int:
	var who := TARGET_NONE
	var best := INF
	for e in enemy_type.size():
		if enemy_alive[e] == 0:
			continue
		var q: Vector2 = enemy_pos[e]
		var d := _dist(p, q)
		if must_strike:
			if not _can_hit(p, q, reach):
				continue
		elif d > reach + Rules.EPS:
			continue
		if d < best:
			best = d
			who = e
	return who


## **The nearest 검사 standing on the island within `reach` of `p`, or `TARGET_NONE`.** Same tie-break
## and same flag, and it is the same rule rather than a mirror of one: see `_nearest_enemy`.
func _nearest_soldier(p: Vector2, reach: float, must_strike: bool) -> int:
	var who := TARGET_NONE
	var best := INF
	for i in soldier_state.size():
		if int(soldier_state[i]) != SoldierState.ASHORE:
			continue
		var q: Vector2 = soldier_pos[i]
		var d := _dist(p, q)
		if must_strike:
			if not _can_hit(p, q, reach):
				continue
		elif d > reach + Rules.EPS:
			continue
		if d < best:
			best = d
			who = i
	return who
# --- field cache ---------------------------------------------------------------------------------

func _age_fields(dt: float) -> void:
	var expired := []
	for key in _field_age:
		var age := float(_field_age[key]) + dt
		if age >= FIELD_TTL:
			expired.append(key)
		else:
			_field_age[key] = age
	for key in expired:
		_fields.erase(key)
		_field_age.erase(key)


## **The flow field that walks a body onto `tile`, built once and handed to everybody who asks.**
##
## ⚠⚠ **PUBLIC SINCE 2026-09-01, AND THE READER THAT MADE IT PUBLIC IS `Hand.routes`.** The 이동선 has
## to be the SAME route the walk will take, so the preview and `order_walk` now descend the SAME field
## rather than two fields that happen to be equal. **Measured on the real island: one field is 3.72 ms**
## — a nine-body preview that built its own would spend 33 ms of a 16.7 ms frame.
##
## ⚠ **A field is a function of the ground and of nothing else.** `Grid.can_step` reads passability,
## level and stairs, never `reserved` — so a field stays true however the bodies shuffle, which is what
## makes caching it across frames sound while caching a SEAT across frames is not (see `Hand.routes`).
## **`setup` empties this and `_age_fields` retires an entry after `FIELD_TTL`**, which is the whole of
## its lifetime.
func field_to(tile: int) -> PackedInt32Array:
	if _fields.has(tile):
		var cached: PackedInt32Array = _fields[tile]
		return cached
	var built := grid.flow_field(tile)
	_fields[tile] = built
	_field_age[tile] = 0.0
	return built


# --- tiles ---------------------------------------------------------------------------------------

func _point_of_tile(tile: int) -> Vector2:
	if grid == null or grid.w <= 0:
		return OFFMAP
	return Vector2(tile % grid.w, tile / grid.w)


func _tile_of(pos: Vector2) -> int:
	if grid == null or grid.w <= 0:
		return -1
	var tx := clampi(int(round(pos.x)), 0, grid.w - 1)
	var ty := clampi(int(round(pos.y)), 0, grid.h - 1)
	return ty * grid.w + tx


## Free tiles nearest `target_tile`, breadth-first, in visit order — so the landing tile itself comes
## first when it is free.
##
## ⚠ **This is where the drop order becomes a picture.** A boat is one soldier now, so with several
## boats aimed at one beach every call after the first finds the target 조각 fuller than it left it, and
## once it is full walks one ring out. Combined with `_phase_landings`' ascending pass that makes "the
## first dropped stands in front" a property of the search order rather than of a rule someone
## maintains — and it is the ONLY thing the drop order decides, since every boat departs on the commit
## sub-step.
## ⚠⚠ **THE BEACH NOW FILLS DEEP BEFORE IT FILLS WIDE** (2026-08-30). While a 조각 admitted one body
## the landing 조각 was taken by the first body ashore and everyone after it stepped out a ring; with
## `Rules.TILE_CAPACITY` slots the same 조각 comes back until it is full. **That is the several bodies
## standing on one 조각 the user asked for**, and it is a property of this search rather than of a rule
## anybody maintains.
##
## The search WALKS OVER full tiles and only COLLECTS ones with room. A search that refused to
## cross an occupied tile would be sealed in by the first soldier to land, and the boat behind it
## would wait out the island at a coast with an empty beach two tiles away.
func _free_tiles_from(target_tile: int, wanted: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := grid.w * grid.h
	if n == 0 or target_tile < 0 or target_tile >= n or wanted <= 0:
		return out
	var seen := PackedByteArray()
	seen.resize(n)
	var queue := PackedInt32Array()
	queue.append(target_tile)
	seen[target_tile] = 1
	var head := 0
	# ⚠⚠ **THE LANDING'S OWN TIER, AND WITHOUT IT A BOAT PUT BODIES ON TOP OF THE WALL.** Measured on
	# the real first island: asking this for four standing tiles from an approved landing handed back a
	# tile ON THE PLATEAU — a place nothing can walk to and nothing can walk from. Worse than a
	# misplaced body: `step_toward` reads a body's tier off the tile it stands on, so one dropped up
	# there **becomes a legitimate plateau resident**, unreachable by every enemy, and the island can
	# never end.
	var want_level := grid.level_of(target_tile)
	while head < queue.size() and out.size() < wanted:
		var t := queue[head]
		head += 1
		# Collect only at the landing's own height. A body walks off a boat; it does not climb on the
		# way out, so a full beach must NOT spill up the stair.
		if grid.passable[t] != 0 and grid.has_room(t) and grid.level_of(t) == want_level:
			out.append(t)
		var tx := t % grid.w
		var ty := t / grid.w
		for k in Grid.NEIGHBOURS.size():
			var nx := tx + int(Grid.NEIGHBOURS[k][0])
			var ny := ty + int(Grid.NEIGHBOURS[k][1])
			if nx < 0 or ny < 0 or nx >= grid.w or ny >= grid.h:
				continue
			var nt := ny * grid.w + nx
			# ⚠ **`can_step` and not `passable`** — the SEARCH may not cross a wall either, so a beach
			# cannot borrow free tiles from a strip of land that is only reachable through the plateau.
			# ⚠⚠ **THE TWO GUARDS OVERLAP AND THAT WAS MEASURED, NOT ASSUMED.** Removing either one
			# alone reddens NOTHING on today's islands: this one already refuses to enqueue a plateau
			# tile, and the collect test already refuses to hand one back. **Each covers the other for
			# level 2.** What they do not share is at the edges — the collect test alone stops a body
			# standing on a STAIR (level 1, which this one is right to walk through), and this one alone
			# stops a search reaching land it cannot walk to. `net_tiers` carries a case for each, on
			# boards built so the other guard cannot answer.
			if seen[nt] != 0 or not grid.can_step(t, nt):
				continue
			seen[nt] = 1
			queue.append(nt)
	return out


# --- bookkeeping ---------------------------------------------------------------------------------

