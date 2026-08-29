class_name IntHeap
extends RefCounted
## **A min-heap of `(cost, value)` pairs of integers.** Pure data — no Node, no tree, `.new()` is the whole
## construction. Its one caller today is `Grid.flow_field`, which pops the cheapest 조각 first.
##
## ⚠⚠ **IT IS HERE FOR SPEED AND NOT FOR CORRECTNESS, AND THE FIRST DRAFT OF THIS HEADER HAD THAT WRONG**
## (티켓 37). `Grid.flow_field` re-pushes a 조각 every time its value improves, so it converges under
## weighted edges whatever order it pops in — **measured 2026-08-29: a plain first-in-first-out queue
## leaves all 288 조각 of the empty-board field exact.** What cheapest-first buys is that a 조각 is
## expanded once instead of several times: Dijkstra where it would otherwise be Bellman-Ford.
## ⚠ **So nothing about the field can redden if this file breaks.** The only thing that can is
## `net_walk._the_heap_orders`, which drives this class directly — which is exactly why it is a file.
##
## ⚠ **A binary heap and not a bucket queue.** Dial's bucket queue is O(1) per operation, but the number of
## buckets it needs is the largest edge weight, so it breaks silently the day a third weight is added. A
## heap is correct under any weights. The field is built once per target 조각 and cached for
## `Battle.FIELD_TTL`, so the log-factor is paid a handful of times a second at most.
##
## ⚠⚠ **IT IS ITS OWN FILE RATHER THAN PRIVATE TO `grid.gd` SO A NET CAN DRIVE IT.** Ordering is exactly
## what a 「did the body arrive」 check cannot see, and the only way to see it is to push out of order and
## read what comes back.
##
## ⚠ **There is no decrease-key.** A cheaper route to an already-queued value is pushed as a second pair,
## and the caller drops the stale one by comparing `last_cost` against what it has recorded. That is the
## standard lazy-deletion heap, and `Grid.flow_field` says so where it does it.


## The pairs, flat: `[cost0, value0, cost1, value1, ...]`. **One array and not two** — two arrays are two
## things to keep in step through every sift, and a sift that swapped one and not the other would hand back
## some other pair's value with the right cost.
##
## ⚠ A plain `PackedInt32Array` field, not a `const` — `const X := PackedInt32Array([...])` is a parse error
## on 4.7, which is why every flat table in this repo is written the long way.
var _pairs := PackedInt32Array()

## **The cost of the pair `pop_value()` last returned**, or 0 before the first pop.
##
## ⚠ **The caller needs it and the popped value alone cannot supply it.** Lazy deletion is「was this pair
## already beaten」, which is a question about the cost it was queued at, not about the cost it has now.
var last_cost := 0


func is_empty() -> bool:
	return _pairs.is_empty()


## How many pairs are waiting. For a net; nothing in `src/` reads it.
func size() -> int:
	return _pairs.size() / 2


## Queues `value` at `cost`. The same value may be queued more than once — see the header.
func push(cost: int, value: int) -> void:
	var i := _pairs.size() / 2
	_pairs.append(cost)
	_pairs.append(value)
	while i > 0:
		var parent := (i - 1) / 2
		if _pairs[parent * 2] <= _pairs[i * 2]:
			break
		_swap(i, parent)
		i = parent


## The value of the cheapest pair, with its cost left in `last_cost`. **-1 on an empty heap**, and
## `last_cost` is left where it was — a caller that pops without asking `is_empty` first gets a value no
## 조각 index can be rather than a plausible one.
func pop_value() -> int:
	if _pairs.is_empty():
		return -1
	last_cost = _pairs[0]
	var out := _pairs[1]
	var last := _pairs.size() / 2 - 1
	_swap(0, last)
	_pairs.resize(_pairs.size() - 2)
	var n := _pairs.size() / 2
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var small := i
		if l < n and _pairs[l * 2] < _pairs[small * 2]:
			small = l
		if r < n and _pairs[r * 2] < _pairs[small * 2]:
			small = r
		if small == i:
			break
		_swap(i, small)
		i = small
	return out


func _swap(a: int, b: int) -> void:
	if a == b:
		return
	var ac := _pairs[a * 2]
	var av := _pairs[a * 2 + 1]
	_pairs[a * 2] = _pairs[b * 2]
	_pairs[a * 2 + 1] = _pairs[b * 2 + 1]
	_pairs[b * 2] = ac
	_pairs[b * 2 + 1] = av
