extends RefCounted
## Pairwise horizontal separation — pure, over plain values. **`BossAi.advance`'s own precedent, verbatim**:
## a pure function over plain values, not over `Monster`, so a net drives it with no world and the inversion
## is trivial (`monster-ai-jump-and-separation.md`, Stage C).
##
## **Horizontal only** — vertical separation fights gravity and grounding every frame, and mobs are not
## solid to each other in the first place, only *separated* (the plan's own Bounds).
##
## **Order-independent by construction, not by luck.** Every pair's push (sign and magnitude) is a function
## of the two mobs' own `x`/`w` values alone — never of their array index — so the total accumulated for any
## one mob is the same sum of the same integers no matter what order the array holding it is in. Reversing
## the array relabels which index is `i` and which is `j` for a given unordered pair, but the pair's own
## contribution to each side is unchanged, and integer addition does not care what order it is summed in.
## **This is why every accumulator here is `int`, never `float`** — the plan's own named hazard: summing up
## to 19 partners' worth of correction as a `float` is not associative, so reversing the array can move the
## last bit and flip which side of a rounding tie the integer px lands on. `Body.x` is an integer anyway, so
## nothing is lost by staying in `int` end to end.
##
## **Measured, honestly: no net in this file can currently prove that hazard bites.** A float accumulator
## with fractional (`d * 0.5`) terms was tried by hand against a 19-mob dense pack (`net_monster`'s own
## stress check) — every check stayed green. IEEE-754 double precision has far more headroom than this
## domain's magnitudes (single-digit-to-low-hundreds px, a few dozen terms) ever exhaust, so float summation
## is, in practice, associative here — the same finding verify-read independently reported. Staying in `int`
## remains the right discipline (it removes the question rather than relying on a magnitude nobody has
## measured staying safe forever), but it is a precaution, not something a failing test backs today.

## Below this overlap (px), nothing moves — resolving all the way to zero overlap is what makes a pack
## oscillate around the boundary forever (the plan's own Bounds: "a small permitted overlap is invisible and
## stable"). **A screen value, not decided by the user yet.**
const OVERLAP_THRESHOLD_PX := 4

## The largest total correction one mob can receive in a single frame (px), after summing every partner it
## overlaps. Caps how hard one frame can push a mob buried in the middle of a crowded pile — without this, a
## mob touching many overlapping partners at once could be asked to move father in one frame than
## `try_shift_x`'s own single-attempt `box_free` check was ever meant to arbitrate. **A screen value.**
const MAX_CORRECTION_PX := 8


## `xs[i]`/`ws[i]` are mob `i`'s left edge and width (px, both `int`). Returns one `int` correction per index
## — the sum of every pairwise push that mob should receive this frame, clamped to `MAX_CORRECTION_PX`.
## **A pure snapshot in, a pure array out** — nothing here mutates `xs`/`ws`, and nothing here touches a
## grid or a `Monster`; applying the result (`Monster.try_shift_x`) is Stage C's other half, in `world_step.gd`.
static func corrections(xs: Array[int], ws: Array[int]) -> Array[int]:
	var n := xs.size()
	var out: Array[int] = []
	out.resize(n)
	for i in n:
		out[i] = 0
	for i in n:
		for j in range(i + 1, n):
			var d := _overlap_px(xs[i], ws[i], xs[j], ws[j])
			if d <= OVERLAP_THRESHOLD_PX:
				continue
			# **The push side is decided from position alone, never from `i`/`j`** — `ci`/`cj` are each
			#  mob's own centre (doubled, so the comparison needs no float). A dead-even tie (exactly
			#  stacked) resolves to a fixed direction — arbitrary, but the same arbitrary answer regardless
			#  of which of the two happened to be index `i` this pass.
			var ci := xs[i] * 2 + ws[i]
			var cj := xs[j] * 2 + ws[j]
			var push := d / 2  # floor — under-corrects by at most 1px on an odd overlap, never overshoots
			var sign_i := -1 if ci <= cj else 1
			out[i] += sign_i * push
			out[j] += -sign_i * push
	for i in n:
		out[i] = clampi(out[i], -MAX_CORRECTION_PX, MAX_CORRECTION_PX)
	return out


## Two 1-D spans' overlap in px, 0 or negative meaning "not touching".
static func _overlap_px(x0: int, w0: int, x1: int, w1: int) -> int:
	return mini(x0 + w0, x1 + w1) - maxi(x0, x1)
