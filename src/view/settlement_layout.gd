extends RefCounted
## Run-end settlement screen coordinates and its two pure value functions — the three summary rows, the
## button, the hour-safe time string, and the count-up curve itself.
##
## **Static, so the nets read the same rects the drawing uses** — `research_layout.gd`'s own header states the
## reason this shape exists at all: `Control._draw()` cannot be measured headless, so judgment is pushed into
## a file the nets *can* call directly.
##
## **`time_text` and `count_value` live here too, not in the window node** — `docs/plans/3.done/
## run-end-settlement.md`'s own Stage B: "`count_value` is where the animation lives, not in the node — a pure
## `(total, frames) -> int` curve that a net can walk end to end." Both are ordinary `(int) -> ...` functions,
## nothing Control-shaped about either, so keeping them beside the rects rather than in `settlement_window.gd`
## means every acceptance about *what* the screen shows (not how it is drawn) is measurable without a scene.

const Fx := preload("res://src/view/fx_tuning.gd")

const TITLE_BAND_PX := 110.0
const ROW_H_PX := 44.0
const ROW_GAP_PX := 18.0
const BUTTON_W_PX := 220.0
const BUTTON_H_PX := 52.0
## Measured from the bottom, not stacked after the rows — the same reason `research_layout.rows` divides its
## own area instead of using a fixed row height: a future row added to the top must not creep the button down
## into a rect a net has already asserted clears it.
const BUTTON_BOTTOM_MARGIN_PX := 64.0


## The three summary rows — play time, damage dealt, 원석 — stacked below the title, left-aligned inside the
## screen's own padding. **Always exactly 3** — the doc's own "two numbers and a delta, and that is all"; a
## kind added later means widening this array, not letting callers assume a count.
static func rows(window_size: Vector2) -> Array[Rect2]:
	var pad := Fx.SETTLEMENT_PAD_PX
	var top := TITLE_BAND_PX
	var w := maxf(window_size.x - pad * 2.0, 0.0)
	var out: Array[Rect2] = []
	for i in 3:
		out.append(Rect2(pad, top + float(i) * (ROW_H_PX + ROW_GAP_PX), w, ROW_H_PX))
	return out


## **The one button.** No "retry", no "quit" (the doc's own Screen section) — centred, near the bottom,
## clear of the rows above it by construction (`BUTTON_BOTTOM_MARGIN_PX` measures from the bottom edge, not
## from the last row, so the two can never collide regardless of how many rows exist above).
static func button_rect(window_size: Vector2) -> Rect2:
	var y := window_size.y - Fx.SETTLEMENT_PAD_PX - BUTTON_H_PX
	var x := (window_size.x - BUTTON_W_PX) * 0.5
	return Rect2(x, y, BUTTON_W_PX, BUTTON_H_PX)


## **Play time, in whole seconds — the hour-safe form.** Bounds' own warning: "a very long run needs an hour
## form, or it reads `241분`". No zero-padding anywhere (`12분 41초`, not `12분 041초`) — the mockup's own
## style, and there is nothing here that needs to sort as text.
static func time_text(total_seconds: int) -> String:
	var s := maxi(total_seconds, 0)
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d시간 %d분 %d초" % [h, m, sec]
	if m > 0:
		return "%d분 %d초" % [m, sec]
	return "%d초" % sec


## **The count-up curve, and the whole of the screen's one animation** (the doc's own "the count-up is the
## whole animation... it is the only motion on the screen"). A pure `(total, frames elapsed since open) -> the
## value shown right now` function — the window calls this every `tick_countup()`, nothing here reads a clock.
##
## **`total <= 0` returns 0 for every `frames`** — 원석 0 is a real outcome (Bounds: "died before any level and
## before any boss... it must not be suppressed"), and a curve that ticks up from a negative or zero total
## would either show nothing meaningful or divide by a step that goes nowhere.
##
## **Never decreases, lands exactly on `total`, and does so within a bounded frame count** — integer division
## of a monotonically increasing `frames` by a fixed positive step is itself monotonic, and `clampi` is what
## makes "exactly `total`, not one past it" true for every `frames` at or beyond `total * step`.
static func count_value(total: int, frames: int) -> int:
	if total <= 0:
		return 0
	var step := maxi(Fx.SETTLEMENT_COUNT_FRAMES_PER_POINT, 1)
	return clampi(frames / step, 0, total)
