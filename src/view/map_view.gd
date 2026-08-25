class_name MapView
extends Node2D

## The node map: where the run has been, where it may go, and what each of those places pays.
##
## It READS `run` — `run.map` for the walk, `run.army` for the two numbers top left — and writes
## neither. Pressing is the shell's job: `node_at` answers "what is under this point" and
## `Run.enter_node` is called by `game.gd`. `src/view/` is the folder with no way to change what
## happens.
##
## ⚠⚠ **WHICH STATE EACH CIRCLE IS IN HAS TO READ WITHOUT TOUCHING ANYTHING.** The first build put
## the whole answer in the hover and in a pulse, and a player has to already know to hover — so at
## rest a node you could step onto and a node you could not were the same grey. `_look_of` now names
## four states and each one differs from its neighbours in **size AND brightness AND what is drawn on
## top**, so a still frame carries the whole of it. See `title-and-map`, the four-state table.
##
## ⚠ **`is_node_pressable` asks the SIM and does not answer for itself.** `RunMap.is_reachable` is the
## one source, so the offer on screen can never include a node the sim would refuse — and the shell
## asks the same function again before it acts, which is not duplication but the same question put to
## the same object.
##
## ⚠ **There are no floor numbers, no "3 nodes left", and no sentences on this screen.** What a node
## is, is its SHAPE, its COLOUR and its SIZE — all three, because Slay the Spire's map is criticised
## for symbols that differ in neither of the last two. What it PAYS is a glyph drawn inside it. Where
## the run has been is the thickness of the lines and the fill of the nodes it has walked. The only
## text is 「짐승 %d · 힘 %.0f」, and that exists because `hud_view._draw` returns on `battle == null`
## and would otherwise leave the screen with no data at all to answer "what am I short of".
##
## Its clock is its own (`_fx_step`), like `panel_view`'s and `title_view`'s: `game.gd::_process`
## reaches nothing here, and a view aged by the shell would be one clock living in two places.
##
## ⚠ **The 힘 number CHASES the army's pool rather than printing it.** Nothing tells this file that a
## `Reward.COUNT` node was won — it notices the pool moved and climbs to it over `NUMBER_CLIMB_SEC`. That is
## what makes a win visibly pay rather than merely returning to the same-looking map. A shell that had
## to remember to announce the change would eventually forget on one of the paths that can raise it.
##
## `_draw()` calls `_paint_*` hooks and nothing else; `net_draw_leaf` pins each hook's `draw_*` count
## and reddens any function here it does not name.


## The two numbers, and they are the only glyphs on this screen.
##
## ⚠⚠ **「병사」-> 「짐승」** (2026-08-25, the user, playing: 「이거 아직 부리를 달 병사를 고르세요 이게
## 남아있네? 이게 뭐지?」). **In this game 병사 are the ENEMY** — 창병 · 궁수 · 방패병 — so a map that
## counted the player's own force in 병사 was naming their horde after the people it is invading.
## ⚠ **The Korean string only.** `soldier` · `army` · `unit` are ruled species-neutral by the glossary
## and are deliberately NOT renamed; this is a word on a screen, not a symbol.
const ARMY_FORMAT := "짐승 %d · 힘 %.0f"

## **The four sentences a circle on this map can say**, and the whole reason this enum exists rather
## than three `if`s scattered through `_draw`: SIZE and BRIGHTNESS are decided from the same answer,
## so they cannot disagree about which state a node is in.
##
## ⚠ **HERE and OPEN are two states and not one.** They were folded together until this round —
## "where I am" was just "a node in `path`" — and the screen could not answer 「지금 내가 어디 있나」
## without the player already knowing to hover. The user named that separately from the reachability
## fix, so it is a separate state.
##
## Every number attached to these lives in `look.gd`'s node-map block, under group 3.
enum NodeLook { HERE, OPEN, PAST, LOCKED }

var run: Run = null

## The pulse clock. Free-running, so a reachable node breathes whether or not anything else is moving.
var _age := 0.0

## How long the map has been up. Both the floor-by-floor reveal and the scene fade read it — they are
## two views of one arrival and splitting the clock would let the picture arrive before the wash left.
var _reveal_age := 0.0

## The cursor's node and how long it has been there; the pressed node and how long ago. Same shape as
## `title_view`'s, and for the same reason: the cursor is in exactly one place and the dip ends by
## time rather than by a second event.
var _hover_node := -1
var _hover_age := 0.0
var _press_node := -1
var _press_age := 0.0

## The you-are-here ring walking an edge. `_travel_from` is -1 for the very first node of a run, where
## there is nothing to walk from and the ring simply appears.
var _travel_from := -1
var _travel_to := -1
var _travel_age := 0.0

## The node that was just won, filling in. -1 when nothing is filling.
var _cleared_node := -1
var _cleared_age := 0.0

## The 힘 readout's chase. `_force_to` is **-1 until the first frame with a run**, which is the
## sentinel that stops a fresh run's opening pool from being drawn as a climb out of nowhere.
var _force_from := 0.0
var _force_to := -1.0
var _force_age := 0.0


## Points the map at a run, or at nothing. Called by the shell every time the map screen is entered,
## which is what restarts the reveal and the scene fade — the map arriving is a beat, not a state.
##
## ⚠ **The force chase is reset only for a DIFFERENT run object.** Re-binding the same run must leave
## `_force_to` where it was, or a `Reward.COUNT` win — applied inside `Run.take_count_reward`, before
## the shell re-binds — would be snapped to instead of climbed to, and a win would look like nothing had
## changed.
func bind(r: Run) -> void:
	var fresh := r != run
	run = r
	if fresh:
		_force_to = -1.0
		_force_from = 0.0
		_force_age = 0.0
	_reveal_age = 0.0
	_hover_node = -1
	_hover_age = 0.0
	_press_node = -1
	_press_age = 0.0
	_travel_from = -1
	_travel_to = -1
	_travel_age = 0.0
	queue_redraw()


## The node under `point`, or -1. The CLOSEST match wins rather than the first: the hit circles are
## laid out so they cannot overlap (centres at least 120 px apart against a 96 px sum of radii), and
## this is what decides the answer if that ever loosens.
func node_at(point: Vector2) -> int:
	# ⚠ `nearest` and not `best_gap`: `net_draw_leaf`'s pixel sweep matches any name ending in `_gap`
	# assigned a number, over the whole of `src/`, and a local holding a distance would redden the
	# round as a loose layout constant. The name says what it holds either way.
	var best := -1
	var nearest := 0.0
	for n in Rules.map_node_count():
		var reach := node_centre_of(n).distance_to(point)
		if reach > node_hit_radius_of(n):
			continue
		if best < 0 or reach < nearest:
			best = n
			nearest = reach
	return best


## Node `n`'s centre in viewport px. It does not move: the pulse changes the RADIUS, so a node's hit
## circle and its drawn one always share a centre and a press cannot land where nothing is.
func node_centre_of(n: int) -> Vector2:
	return Look.map_node_pos_px(n)


func node_hit_radius_of(n: int) -> float:
	return Look.map_node_hit_radius_px(Rules.map_kind_of(n))


## ⚠ **Asked of the sim, every time.** The picture and the shell's own hit test both come out of
## `RunMap.is_reachable`, so there is no second rule here to disagree with it — and a node that is
## drawn as an offer is by construction one the sim will accept.
func is_node_pressable(n: int) -> bool:
	if run == null or run.state() != Run.State.MAP:
		return false
	return run.map.is_reachable(n)


func set_hover(point: Vector2) -> void:
	var found := node_at(point)
	if not is_node_pressable(found):
		found = -1
	if found == _hover_node:
		return
	_hover_node = found
	_hover_age = 0.0


## The shell calls this on an ACCEPTED press, and it starts BOTH beats the press owns: the node dips,
## and the you-are-here ring sets off along the edge toward it.
##
## ⚠ The shell then holds for `MAP_TRAVEL_SEC` before opening the island. **Cutting straight to the
## island makes the map's work invisible** — the walk IS the progress readout, and it is the reason
## this function knows where the run is standing rather than being handed a pair of node ids.
func note_press(n: int) -> void:
	if not is_node_pressable(n):
		return
	_press_node = n
	_press_age = 0.0
	_travel_from = run.map.at()
	_travel_to = n
	_travel_age = 0.0


## The node just won starts filling in. -1 is a no-op, which is what a run entering the map for the
## first time hands over.
func note_cleared(n: int) -> void:
	if n < 0:
		return
	_cleared_node = n
	_cleared_age = 0.0


func _hover_of(n: int) -> float:
	if n != _hover_node:
		return 0.0
	return clampf(_hover_age / Look.PRESS_HOVER_SEC, 0.0, 1.0)


func _press_of(n: int) -> float:
	if n != _press_node:
		return 0.0
	return clampf(1.0 - _press_age / Look.PRESS_DOWN_SEC, 0.0, 1.0)


## How far node `n` has faded in, 0..1. Floor by floor from the bottom, `MAP_REVEAL_STEP_SEC` apart,
## each one taking `MAP_NODE_FADE_SEC`. **This is what teaches the map's direction**, and it is what
## the design ships instead of a sentence saying "you go upward".
func _reveal_alpha_of(n: int) -> float:
	var start := Rules.map_floor_of(n) * Look.MAP_REVEAL_STEP_SEC
	return clampf((_reveal_age - start) / Look.MAP_NODE_FADE_SEC, 0.0, 1.0)


## Extra radius, in px, for a node you may step onto. 0 for every other node, and it swings across the
## whole of `MAP_PULSE_R_PX` rather than a fraction of it — on a still screen this is the only motion
## that says "here", so it is pinned both at 0 (it must not be flat) and at the constant.
func _pulse_scale_of(n: int) -> float:
	if not is_node_pressable(n):
		return 0.0
	var phase := TAU * _age / Look.MAP_PULSE_SEC
	return Look.MAP_PULSE_R_PX * 0.5 * (1.0 - cos(phase))


## Where the you-are-here ring is. During a press it walks the edge from the node the run is standing
## on to the node just chosen; the rest of the time it sits on `map.at()`.
##
## Returns `Vector2.ZERO` when there is nowhere to be — a run that has landed on nothing yet — and
## `_draw` is what refuses to paint a ring in that case. A sentinel position would be a ring drawn in
## the top-left corner, which is worse than none.
func _here_centre() -> Vector2:
	if run == null:
		return Vector2.ZERO
	if _travel_to >= 0:
		var to := node_centre_of(_travel_to)
		if _travel_from < 0:
			return to
		var p := clampf(_travel_age / Look.MAP_TRAVEL_SEC, 0.0, 1.0)
		return node_centre_of(_travel_from).lerp(to, p)
	var here := run.map.at()
	if here < 0:
		return Vector2.ZERO
	return node_centre_of(here)


## **Which of the four sentences node `n` is saying.** One function, asked by both the colour and the
## radius, so the two channels can never disagree — that is the whole reason it is not two `if`
## chains one beside the other.
##
## ⚠ **The order is HERE, then OPEN, and it is not arbitrary.** `RunMap.is_reachable` needs an edge
## out of `at()` and the table has no self-edges, so the two can never both be true today; asking
## HERE first is what keeps that from mattering the day a self-edge is authored.
##
## ⚠ **PAST is `RunMap.is_cleared` and not `path.has`.** `path` includes the node the run is standing
## on, so `path.has` would put HERE and PAST on the same node and the you-are-here mark would land on
## something drawn as finished with.
func _look_of(n: int) -> int:
	if run == null:
		return NodeLook.LOCKED
	if run.map.at() == n:
		return NodeLook.HERE
	if is_node_pressable(n):
		return NodeLook.OPEN
	if run.map.is_cleared(n):
		return NodeLook.PAST
	return NodeLook.LOCKED


## The radius node `n` is actually DRAWN at — **the size half of telling the four states apart.**
##
## HERE and OPEN are drawn at the full radius and there is deliberately no `1.0` written here for
## them: a scale above 1.0 would push a node's visible rim outside the circle you can press, which is
## the trap `Look.map_node_hit_radius_px` spells out.
##
## The pulse rides on top and only OPEN has one, so a node on offer is the only thing on the screen
## that moves — but it is no longer the ONLY thing telling you it is on offer, which was the defect:
## motion is invisible in a still frame, and the player reads a still frame first.
func _node_radius_of(n: int) -> float:
	var drawn := Look.map_node_radius_px(Rules.map_kind_of(n))
	match _look_of(n):
		NodeLook.PAST:
			drawn *= Look.MAP_NODE_PAST_SCALE
		NodeLook.LOCKED:
			drawn *= Look.MAP_NODE_LOCKED_SCALE
	return drawn + _pulse_scale_of(n)


## What colour node `n` is drawn, before the reveal is applied. **The brightness half**, off the same
## `_look_of` the radius reads.
##
## **HERE** and **OPEN** are both at `PRESS_ALPHA_ON` in their own hue — they are the two places the
## eye is meant to go — and are told apart by what is drawn ON them: HERE gets the ring, OPEN gets the
## border and the pulse. **PAST** keeps its hue at `MAP_NODE_PAST_ALPHA` so the route you came through
## stays readable as what it was. **LOCKED** has its colour taken away entirely and sits at
## `PRESS_ALPHA_OFF`. The node just won crosses from LOCKED's tone up to HERE's over
## `MAP_CLEAR_FILL_SEC`, which is the only place two of the four meet.
func _node_fill(n: int) -> Color:
	var base := Look.map_node_colour_of(Rules.map_kind_of(n))
	match _look_of(n):
		NodeLook.OPEN:
			base.a = Look.PRESS_ALPHA_ON
			return Look.press_dipped(Look.hover_lit(base, _hover_of(n)), _press_of(n))
		NodeLook.HERE:
			base.a = Look.PRESS_ALPHA_ON
			if n == _cleared_node:
				var p := clampf(_cleared_age / Look.MAP_CLEAR_FILL_SEC, 0.0, 1.0)
				return Look.dimmed(base).lerp(base, p)
			return base
		NodeLook.PAST:
			base.a = Look.MAP_NODE_PAST_ALPHA
			return base
	return Look.dimmed(base)


## Edge `e`'s weight and alpha, as `(width, alpha)`.
##
## A line says exactly one of three things and each has its own pair: **walked** (thickest, opaque),
## **choosable from where the run is standing** (thinner, nearly opaque), **neither** (thin and faint,
## but never invisible — the whole map is visible from the first frame, which is what makes the route
## a decision rather than a reveal).
func _edge_style(e: int) -> Vector2:
	if run != null and run.map.edge_is_travelled(e):
		return Vector2(Look.MAP_LINE_PAST_WIDTH_PX, Look.MAP_LINE_PAST_ALPHA)
	if run != null and Rules.map_edge_from(e) == run.map.at() \
			and is_node_pressable(Rules.map_edge_to(e)):
		return Vector2(Look.MAP_LINE_OPEN_WIDTH_PX, Look.MAP_LINE_OPEN_ALPHA)
	return Vector2(Look.MAP_LINE_DIM_WIDTH_PX, Look.MAP_LINE_DIM_ALPHA)


## The glyph inside node `n`, as **point PAIRS** for one `draw_multiline` — three little squares for a
## node that pays bodies. Empty for the boss, which is told apart by size and by its nested rings.
##
## ⚠⚠ **A SECOND GLYPH — a triangle for the beak node — was deleted with the reward** (2026-08-25,
## the user: 「부리 보상 없지 끝나면 카드보상으로 통일했잖아」). **So every fight node now draws the
## same glyph**, and the `match` below has one arm. That is the honest picture of a map whose seven
## nodes pay one thing; it is written down rather than hidden behind a `match` that looks like a fork.
##
## ⚠ **Built here and handed to the leaf as an argument**, the `_spark_points` precedent: geometry
## built INSIDE a leaf never leaves it, and `net_draw_leaf` skips the unused-argument check on any
## function whose draw count is 0 — so a leaf holding `draw_multiline(PackedVector2Array(), ...)`
## would read as one draw call with every argument used, and draw nothing at all.
func _glyph_points(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := node_centre_of(n)
	var r := Look.MAP_GLYPH_R_PX
	match Rules.map_reward_of(n):
		Rules.Reward.COUNT:
			# ⚠ The pitch has to exceed twice the half-width or the three squares merge into a bar and
			# the glyph stops saying "three". 0.80 against 2 x 0.28 = 0.56 leaves 0.24 r = 5.0 px of
			# daylight, against a 3 px stroke that eats 3.0 of it — 2.0 px of visible gap, which is
			# this repo's own snap floor. Widen the pitch before widening the stroke.
			var half := r * 0.28
			for k in 3:
				var mid := c + Vector2((float(k) - 1.0) * r * 0.80, 0.0)
				var corner: Array[Vector2] = [
					mid + Vector2(-half, -half), mid + Vector2(half, -half),
					mid + Vector2(half, half), mid + Vector2(-half, half)]
				for i in 4:
					out.append(corner[i])
					out.append(corner[(i + 1) % 4])
	return out


## A closed ring of `segments` points around `centre`, starting at `turn` radians. **One function for
## every circle on this screen** — the node outlines, the boss's nested rings and the diamond of the
## chest are the same construction at three segment counts, and a second copy would be free to be
## smooth in one place and faceted in another.
##
## It is not in the design's function table and was added by the build: the alternative was building
## the same loop inline in `_draw` three times, which is the geometry written three times.
func _ring_points(centre: Vector2, radius: float, segments: int, turn: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(segments + 1):
		var a := turn + TAU * float(i) / float(segments)
		out.append(centre + Vector2(cos(a), sin(a)) * radius)
	return out


## Ages everything this screen owns, and notices the army's pool moving.
##
## ⚠ The pool is compared against `_force_to` and not against what is on screen: comparing against the
## drawn value would restart the climb every frame it was still climbing, and the number would crawl
## toward the target forever without arriving.
func _fx_step(delta: float) -> void:
	_age += delta
	_reveal_age += delta
	if _hover_node >= 0:
		_hover_age += delta
	if _press_node >= 0:
		_press_age += delta
		if _press_age >= Look.PRESS_DOWN_SEC:
			_press_node = -1
	if _travel_to >= 0:
		_travel_age += delta
	if _cleared_node >= 0:
		_cleared_age += delta
	if _force_age < Look.NUMBER_CLIMB_SEC:
		_force_age += delta
	if run == null or run.army == null:
		return
	var pool := 0.0
	for i in run.army.hp.size():
		if run.army.alive[i] != 0:
			pool += run.army.hp[i]
	if is_equal_approx(pool, _force_to):
		return
	# The first frame of a run has nothing to climb out of, so it lands on the number rather than
	# rising to it. Every later change is a climb, whether it came from a chest or from a fight.
	_force_from = _force_to if _force_to >= 0.0 else pool
	_force_to = pool
	_force_age = 0.0


func _process(delta: float) -> void:
	_fx_step(delta)
	queue_redraw()


func _draw() -> void:
	if run == null or run.state() != Run.State.MAP:
		return
	var face := HudView.default_font()
	if face == null:
		return

	# Edges first, so a line never crosses the node it ends on. An edge fades in with the DIMMER of
	# its two ends, or a line would arrive before the node it points at.
	for e in Rules.map_edge_count():
		var a := Rules.map_edge_from(e)
		var b := Rules.map_edge_to(e)
		var style := _edge_style(e)
		var tone := Look.COL_HUD_TEXT
		tone.a = style.y * minf(_reveal_alpha_of(a), _reveal_alpha_of(b))
		_paint_edge(node_centre_of(a), node_centre_of(b), tone, style.x)

	for n in Rules.map_node_count():
		var kind := Rules.map_kind_of(n)
		var centre := node_centre_of(n)
		var reveal := _reveal_alpha_of(n)
		# ⚠ The radius carries the STATE, not just the kind — see `_node_radius_of`. It is read once
		# here and used for the shape, the fill polygon, the border and the boss's rings, so a node
		# cannot be drawn at one size and bordered at another.
		var radius := _node_radius_of(n)
		var sides := Look.map_node_sides_of(kind)
		var segments: int = sides if sides > 0 else Look.MAP_RING_SEGMENTS
		# A diamond is a four-segment ring turned a quarter turn, so its vertex is at the top. Written
		# as a turn rather than as a second point table, which is how the elite would cost no view edit.
		var turn := -PI * 0.5 if sides > 0 else 0.0
		var shape := _ring_points(centre, radius, segments, turn)
		var fill := _node_fill(n)
		fill.a *= reveal
		# ⚠ The POLYGON gets the ring without its closing point. `draw_colored_polygon` triangulates,
		# and a repeated vertex can make that fail — which would draw nothing at all, silently, while
		# the border beside it kept drawing and the round stayed green.
		_paint_node(sides, centre, radius, fill, shape.slice(0, segments))

		# The border is the "this presses" mark, and it is drawn for nothing else. A walked node keeps
		# its fill and loses its border, so the only bordered things on screen are the choices.
		if is_node_pressable(n):
			var edge := Look.COL_HUD_TEXT
			edge.a = reveal
			_paint_node_border(shape, edge,
				lerpf(Look.PRESS_BORDER_WIDTH_PX, Look.PRESS_HOVER_BORDER_WIDTH_PX, _hover_of(n)))

		# The boss: nested rings inside its own disc, in the backdrop tone so they read as rings cut
		# out of it. Drawn whether or not it can be pressed — what a node IS must be readable from the
		# first frame, and the boss is the one node the whole route is aimed at.
		if kind == Rules.NodeKind.BOSS:
			var inner := Look.COL_PANEL_BG
			inner.a = Look.COL_PANEL_BG.a * reveal
			for k in range(1, Look.MAP_BOSS_RINGS):
				var ring_r := radius - float(k) * Look.MAP_BOSS_RING_STEP_PX
				_paint_node_border(_ring_points(centre, ring_r, Look.MAP_RING_SEGMENTS, 0.0), inner,
					Look.MAP_BOSS_RING_WIDTH_PX)

		# What the node PAYS. Without it the two nodes on a floor are identical to the pixel and the
		# fork has nothing to choose between.
		var glyph := _glyph_points(n)
		if glyph.size() > 0:
			var ink := Look.COL_PANEL_BG
			# The glyph rides the SAME `_look_of` the fill and the radius read — one state machine —
			# but on the INK's own alphas, which is not the same rule written twice.
			# ⚠ **It used to reuse the fill's numbers and that is what shipped the defect**: the ink is
			# dark and the fill gets dimmer as the state gets colder, so dimming both together moves
			# the two toward each other instead of apart. LOCKED measured 1.3 : 1 with six of the seven
			# nodes locked on the opening frame. See `MAP_GLYPH_LOCKED_ALPHA` for the arithmetic.
			var lit := Look.PRESS_ALPHA_ON
			match _look_of(n):
				NodeLook.PAST:
					lit = Look.MAP_GLYPH_PAST_ALPHA
				NodeLook.LOCKED:
					lit = Look.MAP_GLYPH_LOCKED_ALPHA
			ink.a = Look.COL_PANEL_BG.a * lit * reveal
			_paint_glyph(glyph, ink, Look.MAP_GLYPH_WIDTH_PX)

	# The you-are-here ring, on top of the nodes because it is bigger than the one it marks.
	if run.map.at() >= 0 or _travel_to >= 0:
		var mark := Look.COL_HUD_TEXT
		mark.a = Look.PRESS_ALPHA_ON
		_paint_here_ring(_here_centre(), Look.MAP_HERE_RING_R_PX, mark,
			Look.MAP_HERE_RING_WIDTH_PX)

	# The only two numbers on this screen. 힘 is the CHASED value, so a chest visibly pays.
	var shown := _force_to
	if _force_to >= 0.0:
		shown = lerpf(_force_from, _force_to, clampf(_force_age / Look.NUMBER_CLIMB_SEC, 0.0, 1.0))
	var text := ARMY_FORMAT % [run.army.living_count(), maxf(shown, 0.0)]
	var ink_army := Look.COL_HUD_TEXT
	ink_army.a = clampf(_reveal_age / Look.MAP_NODE_FADE_SEC, 0.0, 1.0)
	_paint_army(face, Look.MAP_ARMY_POS_PX, text, Look.MAP_ARMY_FONT_SIZE_PX, ink_army)

	# The scene wash, last and over everything: the map arrives OUT of the background rather than
	# cutting to it. A hard cut reads as a glitch, which is the one thing this beat exists to remove.
	var wash := clampf(1.0 - _reveal_age / Look.SCENE_FADE_SEC, 0.0, 1.0)
	if wash > 0.0:
		_paint_fade(Rect2(Vector2.ZERO, Look.viewport_size_px()), Look.scene_fade_colour(wash))


# --- hooks. Each one's draw_* count is pinned by net_draw_leaf's `_table()`, and every parameter is
# used in the body: a leaf that quietly drops one of its arguments is invisible on screen and green in
# the round.

func _paint_edge(from_px: Vector2, to_px: Vector2, col: Color, line_width: float) -> void:
	draw_line(from_px, to_px, col, line_width)


## 2 calls, one per branch, and exactly one of them runs per call — `net_draw_leaf` counts call SITES
## textually. A circle is `draw_circle` and anything with sides is a polygon; writing 1 here reddens
## the round.
func _paint_node(sides: int, centre: Vector2, radius: float, col: Color,
		points: PackedVector2Array) -> void:
	if sides <= 0:
		draw_circle(centre, radius, col)
	else:
		draw_colored_polygon(points, col)


func _paint_node_border(points: PackedVector2Array, col: Color, line_width: float) -> void:
	draw_polyline(points, col, line_width)


func _paint_glyph(points: PackedVector2Array, col: Color, line_width: float) -> void:
	draw_multiline(points, col, line_width)


func _paint_here_ring(centre: Vector2, radius: float, col: Color, line_width: float) -> void:
	draw_arc(centre, radius, 0.0, TAU, Look.MAP_RING_SEGMENTS, col, line_width)


func _paint_army(face: Font, at: Vector2, text: String, fsize: int, col: Color) -> void:
	draw_string(face, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _paint_fade(rect: Rect2, col: Color) -> void:
	draw_rect(rect, col, true)
