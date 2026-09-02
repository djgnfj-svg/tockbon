class_name Store
extends RefCounted
## **The 창고 — one building, everything stacked by kind.** Ticket 05-08.
##
## (2026-09-02, asked whether the food store and the wood/rock/ore store are one building, the user:
## ***"The same building. The same building."*** 「같은 건물이지. 같은 건물이지」. Asked whether fish and
## crops stack as one 「food」: ***"They should stack separately by kind."*** 「종류별로 따로 쌓여야 될 거
## 같은데?」)
##
## ⚠⚠ **THIS IS THE FIRST NUMBER IN `src/sim/` THAT GOES UP WHEN SOMETHING IS GATHERED.** Measured
## 2026-09-02: 나무 · 돌 · 철 · 식량 returned zero hits across the whole simulation. **Nothing produces
## into it yet** — fishing is 05-09, the resource 칸 are 08-02, the barricade spends out of it in 09-02.
## What reads it today is 허기 (05-07), which eats.
##
## ⚠ **Nothing here is a Node**, and nothing here knows where the 창고 stands. **`Battle` owns the
## 조각** — a count that also held a position would have to be told when a building moved, and the
## count is the part that has to survive being asked about from anywhere.
##
## ⚠ **What it costs to build and whether it has a ceiling are NOT decided** (05-08's own 「not
## decided」 section). There is no capacity here on purpose: a ceiling invented by the builder is a
## number the player would meet on screen without anyone choosing it.


## **The six kinds, and the only place the six words live.** ⚠ **Order matters**: `EDIBLE` below
## indexes into this, and the panel will print them in this order when there is a panel for it.
const KINDS := ["fish", "potato", "wheat", "wood", "rock", "ore"]
## **What a hungry body may eat.** ⚠⚠ **Raw fish is already food** — 05-04's kitchen turns crops into
## meals, and until it exists a body eats what is stored. **Wood, rock and ore are never food**, which
## is the whole reason this list is separate from `KINDS`.
const EDIBLE := ["fish", "potato", "wheat"]


## One count per kind, in `KINDS` order. ⚠ **A `PackedInt32Array` and not a Dictionary**: the kinds are
## fixed at six and a dictionary would let a typo make a seventh pile that nothing ever spends.
var counts := PackedInt32Array()


func _init() -> void:
	counts.resize(KINDS.size())


## **The index of a kind, or -1 for a word that is not one.** ⚠ **-1 and never 0** — answering 0 would
## quietly pour a mistyped kind into the fish pile.
static func index_of(kind: String) -> int:
	return KINDS.find(kind)


## **Puts `n` of `kind` in.** Answers what was actually added, which is 0 for an unknown kind or a
## count that is not positive.
func add(kind: String, n: int = 1) -> int:
	if n <= 0:
		return 0
	var k := index_of(kind)
	if k < 0:
		return 0
	counts[k] = int(counts[k]) + n
	return n


## **Takes up to `n` of `kind` out, and answers how many actually came.**
##
## ⚠⚠ **IT TAKES WHAT IS THERE RATHER THAN REFUSING**, and the answer is the number that matters. A
## take that refused unless the whole amount was present would make the caller ask twice — 「how many
## are there」 then 「take them」 — and two questions about one pile is how a count goes negative.
func take(kind: String, n: int = 1) -> int:
	if n <= 0:
		return 0
	var k := index_of(kind)
	if k < 0:
		return 0
	var got: int = mini(n, int(counts[k]))
	counts[k] = int(counts[k]) - got
	return got


## How many of one kind are stacked. **0 for a kind that does not exist**, which is also the truth.
func count(kind: String) -> int:
	var k := index_of(kind)
	if k < 0:
		return 0
	return int(counts[k])


## Everything stacked, of every kind.
func total() -> int:
	var n := 0
	for k in counts.size():
		n += int(counts[k])
	return n


## **Takes one meal out and says which kind it was, or an empty string when there is nothing to eat.**
##
## ⚠ **The kinds are tried in `EDIBLE` order and that order is fish first** — which is what the user
## asked for when the store was settled (「처음에는 그냥 물고기 하나만 있어도 되겠다」). **Nobody chose
## what a body prefers when two kinds are stacked**; first-in-the-list is the builder's answer and it
## is the one thing here a screen could overturn.
func take_meal() -> String:
	for kind in EDIBLE:
		if take(kind, 1) > 0:
			return kind
	return ""


## Whether anything in here can be eaten. ⚠ **Not `total() > 0`** — a 창고 holding nothing but wood is
## full and starves the island.
func has_food() -> bool:
	for kind in EDIBLE:
		if count(kind) > 0:
			return true
	return false
