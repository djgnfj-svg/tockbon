extends RefCounted
## Proves `tests/run_nets.gd`'s own new capability: a treed node's `_draw()` actually runs headless once
## real engine frames are pumped. This is the regression guard and the reference example a future net
## should copy when it needs a real frame — see `run_nets.gd`'s own header for why `net_render`/`net_pick`/
## `net_settlement` believed `_draw()` unmeasurable headless (a runner that quit before a frame ever
## turned, not an engine limit — and, measured below, not a font limit either; that half of their reasoning
## does not hold up under a direct probe).
##
## **Inversion (harness-manager, hand-reverted and re-verified, not shipped broken)**: swapped
## `_run_net`'s `await net.run(self)` back to the old `net.call("run", self)` (the load-bearing half —
## reverting only the outer `await _run_net(...)` and leaving this one alone was tried too and made no
## difference). Reran this net alone: **`[net] 0 passed`, exit code 0.** Not red — gone. `.call()` starts
## the coroutine, hits `pump_frames`'s `await process_frame`, and returns immediately with nothing to
## resume it, so `_run_net`'s own next line (the elapsed-time print) fires 1ms later as if `run()` had
## finished — and every `t.ok()` after that first `await` simply never executes. This is exactly the
## shape CLAUDE.md warns about ("a check does not fail, it disappears") and it survives even the
## `checkpoints == 3` guard below, because that assertion lives inside the same abandoned coroutine —
## **the only thing that caught it was watching the pass count itself drop (5 -> 0).** Reverted back;
## confirmed byte-identical to the working file and green again (5 passed) before moving on.

## A minimal Control that counts its own `_draw()` calls — the only way to tell "drew" from "didn't" without
## a real screen (CanvasItem still runs `_draw()` headless once treed; nothing pixel-level is checked here).
class _CountingBox extends Control:
	var draw_count := 0
	func _draw() -> void:
		draw_count += 1


func run(t) -> void:
	var checkpoints := 0
	await _untreed_control_never_draws(t)
	checkpoints += 1
	await _treed_control_draws_once_pumped(t)
	checkpoints += 1
	await _theme_default_font_is_available_with_no_tree_at_all(t)
	checkpoints += 1
	# **Does not catch the inversion below on its own** — verified by testing it: an abandoned coroutine
	# takes this assertion down with it, since it lives in the same `run()` that never resumes. Kept anyway
	# as a real check (a helper silently returning early some other way, unrelated to the await bug, would
	# still show up here as < 3), with the actual regression guard being the pass *count itself* (5 vs 0).
	t.ok(checkpoints == 3, "세 단계 모두 끝까지 돌았다 (%d/3)" % checkpoints)


## The half of the old claim that stays true: an untreed `CanvasItem` cannot draw, pumped frames or not —
## `queue_redraw()` on a node with no viewport reaches nothing. Without this half the net only proves
## "treed is different", not "untreed genuinely can't", and that difference is the whole point of the fix.
func _untreed_control_never_draws(t) -> void:
	var box := _CountingBox.new()
	box.queue_redraw()
	await t.pump_frames(3)
	t.ok(box.draw_count == 0, "트리 밖 Control은 프레임을 3번 돌려도 _draw()가 안 돈다 (%d회)" % box.draw_count)
	box.queue_free()


## The actual fix, measured directly: add the same node to `root`, pump real frames, and its own `_draw()`
## runs — counted by the override above, not guessed from "no error was thrown". Pumped twice (two separate
## `queue_redraw()` + `pump_frames` rounds) so one call at `add_child` time (an unrelated internal
## notification) cannot be mistaken for "frames actually drive drawing".
func _treed_control_draws_once_pumped(t) -> void:
	var box := _CountingBox.new()
	t.root.add_child(box)
	box.queue_redraw()
	await t.pump_frames(3)
	var first := box.draw_count
	t.ok(first > 0, "트리에 넣고 프레임을 돌리면 _draw()가 돈다 (%d회)" % first)

	box.queue_redraw()
	await t.pump_frames(3)
	t.ok(box.draw_count > first, "다시 queue_redraw()하면 다시 돈다 (%d -> %d, 최초 1회 우연이 아니다)" % [first, box.draw_count])

	t.root.remove_child(box)
	box.queue_free()


## **Checked and corrected, not just repeated.** `net_pick.gd`/`net_settlement.gd`'s own headers give
## `get_theme_default_font()` returning null untreed as *the* reason `_draw()` needs a live draw context.
## Measured directly (harness-manager, probed a bare `Control` and the real `CircleWindow`, both untreed):
## **it is never null — Godot 4.7.1 falls back to the global default theme with no tree involved at all.**
## The font was never the blocker. `_draw()` looked unmeasurable for exactly one reason, the one this whole
## file is about: zero frames ever turned. This check pins that down so the false half of the old claim
## cannot quietly come back — it would need the engine's own default-theme fallback to change first.
func _theme_default_font_is_available_with_no_tree_at_all(t) -> void:
	var box := Control.new()
	t.ok(box.get_theme_default_font() != null, "트리 밖 Control도 get_theme_default_font()가 null이 아니다 (엔진 기본 테마)")
	box.queue_free()
