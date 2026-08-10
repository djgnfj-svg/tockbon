extends Control
## The magic circle assembly window — **this stage is the backing board and the title, nothing more.**
##  Concentric circles, layer rings, rune seats and the palette are **the work of stages 3 to 5. Do not build
##  them in advance.**
##
## **`mouse_filter` is this window's contract, and it is everything this stage measures.**
##
## ```
##  inside this node's rect  ->  STOP    the click does not leak into firing
##  outside it               ->  the same as this node not existing  ->  **you can shoot with the window open**
## ```
##
##  Being able to shoot from outside is the evidence for "the world does not stop" (design acceptance 4).
##   That is why **no full-screen `Control` is laid down while the run is live** — the moment the screen is
##   covered, `IGNORE` or `STOP` alike, that evidence disappears or firing dies.
##  **The one declared exception is `settlement_window.gd`** (`run-end-settlement.md`) — it
##   covers the whole 960x540 canvas and stops the world outright, and it is safe only because it exists
##   solely once the run is already over: there is nothing left to shoot. This sentence used to claim no
##   exception existed at all; that claim is dead, and this doc is where it died.
##  The value is written in `stage.tscn` and **is not overwritten at runtime here.** Overwrite it and the value
##   in the scene becomes a meaningless false knob, which quietly overturns it later when a modal does have to
##   block what is behind (the same comment in `stage.gd` — a v1 measurement).
##
## The window is under `HUD` (a `CanvasLayer`). As a `Node2D` **the window would shake along with the screen shake.**
##  That is why `stage_input._to_world` must not be used for click coordinates — a `CanvasLayer` does not take
##   the camera transform, so there is no transform to undo. Undo it and clicks go to the wrong place while shaking.
##
## **`focus_mode` must be NONE** (it is written in the scene). If a `Control` inside the window takes focus,
##  Tab is consumed by the GUI as `ui_focus_next` and **never reaches** `_unhandled_input` => "Tab does not work".
##  The symptom is identical to "the input map was not fixed", so diagnosis takes a long time — suspect focus first.

const Fx := preload("res://src/view/fx_tuning.gd")
const Layout := preload("res://src/view/circle_layout.gd")
## The window axis is **separate.** The window assembles the two, and `circle_layout` does not know `book_layout`.
const Book := preload("res://src/view/book_layout.gd")
## The palette is **"slot kind x item"** — write it for glyphs only and stage 5 rewrites it wholesale.
const Palette := preload("res://src/view/palette_layout.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const SpellCircle := preload("res://src/actor/spell_circle.gd")
const Progress := preload("res://src/actor/progress.gd")
## The value that **removes** a circle comes from here — pin `0` in the window and the reserved value lives
## in two places.
const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

## **Onboarding's own two events** (`onboarding-and-palette-tabs.md` Stage 7) — emitted only while
## `_onboarding` is true, so `stage.gd`'s listeners never have to re-check that flag themselves.
## `onboard_inserted` fires once per successful placement (the same hook `_click_fx` already has, whether
## the click landed via one-click insertion or pick-then-place); `onboard_confirmed` fires once, the
## instant 완성 is pressed. **The window advances the shell's step, not the reverse** — this window is the
## one object that actually sees the clicks.
signal onboard_inserted
signal onboard_confirmed

## **A reference, not a copy** — it reads **the same thing** as the muzzle (the plan's section 1 single source).
##  Pressing debug keys 4 and 5 flipping the drawing is the evidence for that, and a copy would destroy it.
## **It only reads.** At this stage **nothing can be placed by clicking** (stage 4).
var _circle: SpellCircle = null

## **A reference too, the same reason `_circle` is one** — `rune-lock-and-receiving.md`, Stage A. The bull's
## reward (Stage C) calls `grant_rune()` on the one live `Progress` the rest of the game reads; a copy here
## would never see it, and the palette would keep veiling fire forever after the reward.
var _progress: Progress = null

## The palette item currently picked. `_picked_kind < 0` means nothing is picked.
## **It holds the kind too** — circles, runes and glyphs are all pickable, so an item id alone does not say which.
##  Why two integers rather than a dictionary: key typos are impossible in principle and there is no allocation.
var _picked_kind := -1
var _picked_item := -1
## **Stage 8 — which layer a picked glyph actually came from.** `-1` for a circle/rune pick, or for a
## glyph pick before the layer was resolved. Every glyph in the palette is a *seated* one (there is no
## stash), so picking one always means picking a layer to move, and this is the one piece of information
## `_picked_item` (a value, ambiguous between duplicate dummies) cannot carry.
var _picked_layer := -1

## **Which tab is open — an index into `Palette.KINDS`.** `palette_layout` stays stateless and takes this
## as an argument (the same discipline `circle_layout` holds for not knowing its own page); this window is
## the one object with a reason to remember it across frames. **Starts on 진** (design §1: "처음엔 진 탭"),
## and `toggle()` resets it back there on every close — the tab does not survive a close, the same rule
## `_clear_pick()` already holds for the picked item.
var _open_tab := 0

## **찰칵 — motion, not sound** (this repo has none; `onboarding-and-palette-tabs.md`'s own Blockers).
## Counts down from `Fx.CLICK_FRAMES`, ticked once per **frame** in `_process` — the window already redraws
## every frame while visible, so this is frame-counted like the glow below, not tick-counted (the 60Hz/20Hz
## trap does not reach either counter). `_click_seat`/`_click_radius` are captured once, at the moment of
## insertion (`_seat_of`) — recomputing them lazily in `_draw()` from `_click_kind`/`_click_slot` would also
## work, but a stored seat is what a net can assert against without re-deriving the geometry itself.
var _click_frames := 0
var _click_seat := Vector2.ZERO
var _click_radius := 0.0

## **완성 — one glow, then the window closes** (design §5). `_process` closes the window itself once this
## reaches 0, so `toggle()` has exactly one caller for both "pressed 완성" and "pressed Tab" — firing must
## read identically either way, and there being one close path is what keeps that true by construction.
var _glow_frames := 0

## **Onboarding-only auto-advance** (design §8: "Auto-advance is onboarding-only. Outside it, pressing
## 일반진 seats it and the 진 tab stays open."). Set by the shell (`stage.gd`), read only here — the window
## does not decide *when* onboarding runs, only *what happens to the tab* while it does.
var _onboarding := false


## **The shell's one door onto this window's onboarding behavior.** While `true`, every successful
## placement (`_click_fx`'s own hook) both advances the open tab and emits `onboard_inserted`; while
## `false`, placing something seats it and the tab stays exactly where it was — the ordinary, permanent
## behavior this whole feature ships as its baseline.
func set_onboarding(active: bool) -> void:
	_onboarding = active


## **Socket glyph art, loaded once** — the same idiom as `spell_view._bolt_tex`: read every path in
##  `Fx.SOCKET_GLYPH_TEX` here in `_ready()`, bark once per bad path and move on, rather than calling
##  `load()` from `_draw()` every frame (that would both re-hit the cache 60 times a second and, on a bad
##  path, bury the log at 60 lines a second). Only ids that actually loaded end up in here — a glyph id with
##  no entry (twelve ids total, six with art, six — the dummy and condense families — without) is the normal
##  case `_draw_ring` falls back on, not an error.
var _socket_glyph_tex: Dictionary = {}
## The ring and rune art, loaded once beside the socket glyphs and for the same reason.
var _ring_tex: Dictionary = {}
var _rune_tex: Dictionary = {}
## The palette card art (`Fx.ICON_TEX`), loaded the same way. **It is a third map and not a reuse of
## `_ring_tex`** — that constant's own box carries why a ring cannot be a card.
var _icon_tex: Dictionary = {}


func setup(progress: Progress, circle: SpellCircle) -> void:
	_progress = progress
	_circle = circle
	queue_redraw()


## There is no separate **moment** when the assembly state changes (debug keys and the assembly window both
##  touch the model directly).
##  => Redraw every frame while it is open. The same way `character_view` does it for the muzzle.
##  It does nothing while closed — the window is closed most of the time.
func _process(_dt: float) -> void:
	if not visible:
		return
	if _click_frames > 0:
		_click_frames -= 1
	if _glow_frames > 0:
		_glow_frames -= 1
		if _glow_frames == 0:
			# **Closes after the glow, not during it** (the plan's own TBD, decided that way — "after" is
			#  the one where the glow is actually visible at all). `toggle()` is the window's one door onto
			#  `visible`, the same discipline `stage.gd`'s own comment holds for not touching it directly.
			toggle()
			return
	queue_redraw()


func _ready() -> void:
	# **This rectangle is the interaction area** — `mouse_filter` only bites here.
	#  `fx_tuning` is the single source for the dimensions (write offsets in the scene and there are two places).
	position = Fx.WINDOW_RECT.position
	size = Fx.WINDOW_RECT.size
	_socket_glyph_tex = load_socket_glyph_tex()
	_ring_tex = _load_tex_map(Fx.RING_TEX)
	_rune_tex = _load_tex_map(Fx.RUNE_TEX)
	_icon_tex = _load_tex_map(Fx.ICON_TEX)


## **Pulled out of `_ready()` so a second `_draw()`-owning node can load the same art without a second copy
## of the loading loop** (`docs/design/...` three-pick card art — `three_pick_window.gd` calls this too, the
## same "one shared loader, redrawn separately" split `monster_view._draw_flipped(canvas, ...)` already set
## the precedent for: `CanvasItem.draw_*` only runs inside the calling node's own `_draw()`, so the *drawing*
## cannot be shared, but the *art* and the *rule for which shape to draw* can).
static func load_socket_glyph_tex() -> Dictionary:
	var out: Dictionary = {}
	for glyph_id: int in Fx.SOCKET_GLYPH_TEX:
		var path: String = Fx.SOCKET_GLYPH_TEX[glyph_id]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("CircleWindow: cannot read the socket glyph image - %s" % path)
			continue
		out[glyph_id] = tex
	return out


## Tab. Only one door is kept so the shell does not touch `visible` directly — later, when opening and closing
##  grow more to do (focus, animation), that attaches here in one place.
func toggle() -> void:
	visible = not visible
	# Drop the pick when closing — without it, reopening looks like **nobody has picked anything** while
	#  the next slot click places the old item.
	_clear_pick()
	# **The tab does not survive a close either** (design's own TBD, decided in the plan: "no — `toggle()`
	#  resets it to 진"). `Palette.KINDS.find(...)` rather than a bare `0` so this line still says what it
	#  means if `KINDS`' order ever changes.
	_open_tab = Palette.KINDS.find(Palette.KIND_CIRCLE)
	# A stale flash or glow from the session just closed must not carry into the next open.
	_click_frames = 0
	_glow_frames = 0


# ══════════════════════════════════════════════════════════════════
#  Clicking — **pick then place. Press what is placed and it is removed**
#
#  **This claimed nets could not call the functions below — that was wrong, the same shape CLAUDE.md warns
#   against ("'It can't be driven headless' was claimed three times and was wrong three times").**
#   `net_pick.gd` already proves the sibling window: `ThreePickWindow.new()` untreed, `setup()` called
#   directly, then `_gui_input()` driven with a hand-built `InputEventMouseButton` via `.call()`. Ordinary
#   methods (`_can_pick` · `_slot_accepts` · `_gui_input` itself) do not need the tree.
#   `net_circle._owns_rune_gates_can_pick_on_an_untreed_window` drives `_can_pick` this same way.
#  **A second, later claim on this same line was also wrong**: "only `_draw()` resists, because
#   `get_theme_default_font()` returns null untreed" — measured false (`net_frame_runner.gd`'s own header,
#   harness-manager): the font is never null, even untreed. `_draw()`'s real requirement is a live draw
#   context, which comes from being **treed and frame-pumped**, not from a font. `net_circle.
#   _draw_actually_runs_headless` does exactly that (`t.root.add_child(win)` + `await t.pump_frames(n)`) and
#   drives this file's `_draw()` for real. **Pixel-level appearance is still verify-look's alone** — a net can
#   confirm the code runs without error, never that a ring looks right.
# ══════════════════════════════════════════════════════════════════

## **Being `_gui_input`, the coordinates are already relative to the window's inside.** Take it through
##  `_unhandled_input` and they are screen coordinates, so the window position has to be subtracted again,
##  and the moment that subtracted value lives in two places they drift.
##  And the window is `STOP`, so not taking it here means **the click goes nowhere** — it does not leak into firing.
##
## **Risk 22 — draw inside the transform and take clicks outside it and they diverge silently.**
##  Below is the answer: the `page.position` the drawing added is **subtracted here.** The value to subtract
##  comes from the same function in `book_layout`, so the two cannot diverge.
##  The repo has the same measurement — when `stage_input._to_world` fails to undo the canvas transform,
##   "aim goes to the wrong cell while shaking" (no error).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# A click inside the window is **not firing.** Not accepting it means magic goes off while assembling.
	accept_event()
	if _circle == null:
		return

	var pal := Book.palette_page(size)
	if pal.has_point(mb.position):
		_click_palette(pal, mb.position - pal.position)
		return
	var page := Book.circle_page(size)
	if page.has_point(mb.position):
		_click_circle(page, mb.position - page.position)


## Pick from the palette. Pressing the same one again drops the pick.
##
## **Order: tab strip, then the 완성 band, then an item cell** (`onboarding-and-palette-tabs.md` Stage 1).
##  Both the tab strip and the 완성 band eat vertical space out of the same page `Palette.section()` also
##  occupies, so checking them first is what keeps a click on the strip from also being read as a click
##  on whatever cell used to sit at that pixel.
func _click_palette(pal: Rect2, local: Vector2) -> void:
	var tab := Palette.tab_at(pal.size, local)
	if tab >= 0:
		_open_tab = tab
		# A tab switch is not a pick — carrying the old pick across kinds could let a rune get "placed"
		#  through a glyph seat the moment the tabs change under it.
		_clear_pick()
		return
	if Palette.done_rect(pal.size).has_point(local):
		# **It confirms, it does not apply** (design §5) — every click already wrote into the live
		#  `SpellCircle`. The circle glows once and **then** the window closes — `_process` counts
		#  `_glow_frames` down and calls `toggle()` itself the instant it reaches 0, so there is exactly
		#  one door onto `visible` regardless of how the window ends up closing.
		_glow_frames = Fx.DONE_GLOW_FRAMES
		if _onboarding:
			onboard_confirmed.emit()
		return

	var hit := Palette.item_at(pal.size, local, _open_tab, _progress, _circle)
	if hit.is_empty():
		return
	var kind := int(hit["kind"])
	var item := int(hit["item"])
	# **What cannot be placed cannot be picked in the first place.** Get it picked and then have the slot
	#  refuse it and it becomes "I pressed it and nothing happened", which reads as a malfunction (design).
	if not _can_pick(kind, item):
		return
	# **One click inserts, when there is only one seat** (design §4). The rule is "how many seats does
	#  this kind have", read from `_slot_count(kind)` — write it as "which kind is it" instead and 삼각's
	#  three rune sockets silently collapse to socket 0 with sockets 1 and 2 unreachable.
	#  진 always has exactly one seat (the frame, slot 0); 룬 has one on 동그라미 and three on 삼각.
	if _slot_count(kind) == 1:
		_put(kind, 0, item)
		_click_fx(kind, 0)
		_clear_pick()
		return

	# **Stage 8 — every 문양 card is a seated glyph, never an unseated one** (there is no stash;
	#  `items_of(KIND_GLYPH)` reads `_circle.glyph_list()` directly). Picking one is picking *which layer to
	#  move*, not *which value to place* — two seated dummies (the one family with no cap) share one id and
	#  are only told apart by which cell was actually clicked (`hit["index"]`, mapped through
	#  `_circle.seated_layers()` into a real layer index).
	var from_layer := -1
	if kind == Palette.KIND_GLYPH:
		var layers := _circle.seated_layers()
		var idx := int(hit["index"])
		from_layer = layers[idx] if idx >= 0 and idx < layers.size() else -1

	if _picked_kind == kind and _picked_item == item:
		# **Clicking the same value does not always mean the same instance** — with duplicate dummies,
		#  pressing the *other* one switches the pick to that layer instead of dropping it.
		if kind == Palette.KIND_GLYPH and from_layer != _picked_layer:
			_picked_layer = from_layer
			return
		_clear_pick()
		return
	_picked_kind = kind
	_picked_item = item
	_picked_layer = from_layer


## Press a slot. With something picked it **places**, with nothing picked it **removes** (plan section 9-1).
##
## **The three kinds follow the same rule** — except what "removes" leaves behind at the rune seat. Glyphs and
##  the circle stay genuinely emptiable (`Glyph.GLYPH_NONE` · `CircleDefs.CIRCLE_NONE` — optional layers, and a
##  frame you may legitimately want to pull). A rune seat clearing to `SpellCircle.RUNE_EMPTY` instead of
##  `Tuning.ELEM_NONE` was a self-inflicted disarm (`rune-lock-and-receiving.md`, found by verify-run): click a
##  **veiled, unowned** rune in the palette — `_can_pick` refuses it, nothing gets picked — then click the seat
##  expecting nothing to happen, and `_place_or_clear`'s "nothing picked -> clear" branch fires anyway, dropping
##  a working circle to `can_fire() == false`. **The rune seat cannot go fully empty through this window** —
##  clearing it always leaves `ELEM_NONE`, never `RUNE_EMPTY`. `spell_circle`'s own model still can (`set_rune`,
##  `set_circle`'s resize on a circle swap) — that is a different, already-tested door, not this one.
## **Look from the inside out** — the circle slot is the whole inside of the frame, so without checking the
##  layer and rune seats first it eats all of them.
func _click_circle(page: Rect2, local: Vector2) -> void:
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()

	var layer := Layout.layer_at(id, area, local)
	if layer >= 0:
		# **Stage 8 — a move, not a place.** `place_glyph` here would either duplicate the glyph (an
		#  unlimited family, e.g. dummy) or be rejected outright (a capped family already holding it on a
		#  different layer) — `move_glyph` swaps the two layers' contents instead, so the multiset seated
		#  never changes and neither failure mode is reachable.
		if _picked_kind == Palette.KIND_GLYPH and _picked_layer >= 0:
			_circle.move_glyph(_picked_layer, layer)
			_click_fx(Palette.KIND_GLYPH, layer)
			_clear_pick()
			return
		_place_or_clear(Palette.KIND_GLYPH, layer, Glyph.GLYPH_NONE)
		return

	var slot := Layout.rune_slot_at(id, area, local)
	if slot >= 0:
		_place_or_clear(Palette.KIND_RUNE, slot, Tuning.ELEM_NONE)
		return

	if Layout.frame_has_point(area, local):
		# The circle slot has no index of its own — it is the single frame seat, so it is written at 0,
		#  the same slot `_slot_count(KIND_CIRCLE)` always answers `1` for (one-click insertion's own
		#  premise in `_click_palette`).
		_place_or_clear(Palette.KIND_CIRCLE, 0, CircleDefs.CIRCLE_NONE)


## **The rule for placing and removing lives here in one place.** Write it per kind and there are three copies,
##  and the day only one is fixed you get "glyphs come out but runes do not".
##  If what is picked is a **different kind**, nothing happens — picking a rune and placing it on a layer
##  has no meaning.
## **찰칵 fires only on the placing branch, never the clearing one** — `empty` (`Tuning.ELEM_NONE` for
##  runes) is itself a legitimate rune, so `_put` alone cannot tell "placed 무속성" from "cleared back to
##  무속성" apart; only this function, which already knows which branch it took, can.
func _place_or_clear(kind: int, slot: int, empty: int) -> void:
	if _picked_kind < 0:
		_put(kind, slot, empty)
		return
	if _picked_kind != kind:
		return
	_put(kind, slot, _picked_item)
	_click_fx(kind, slot)
	# Pick then place is one action. Once placed, the hand is emptied.
	_clear_pick()


## **What placing means, in one place** (`onboarding-and-palette-tabs.md` Stage 4). `_click_circle`'s
## pick-then-place and `_click_palette`'s one-click insertion both write through here — two copies is how
## `set_circle`-clears-the-layers stops happening on one path only (a mis-click through the copy that
## forgot the order would silently keep stale glyphs after a circle swap).
func _put(kind: int, slot: int, value: int) -> void:
	if kind == Palette.KIND_GLYPH:
		_circle.place_glyph(slot, value)
	elif kind == Palette.KIND_RUNE:
		_circle.set_rune(slot, value)
	elif kind == Palette.KIND_CIRCLE:
		_circle.set_circle(value)
	else:
		push_error("CircleWindow: unknown slot kind %d - not placing it" % kind)


## **Starts the 찰칵 flash at the item's own seat on the circle page** — captured once, here, rather than
## re-derived every frame in `_draw()`. **The same seat regardless of which page the click landed on**:
## pick-then-place clicks the circle page directly, but one-click insertion (Stage 4) clicks a palette
## cell on the *other* page — without resolving the seat explicitly, a naive "flash where the click
## happened" would flash the palette cell instead of the circle the item actually landed on.
func _click_fx(kind: int, slot: int) -> void:
	var seat := _seat_of(kind, slot)
	if seat.is_empty():
		return
	_click_seat = seat["at"]
	_click_radius = float(seat["r"])
	_click_frames = Fx.CLICK_FRAMES
	# **Onboarding-only** (design §8) — outside a walkthrough, placing 일반진 seats it and the 진 tab
	#  stays open. `_advance_onboard_tab()` only ever moves forward one kind at a time, so it does nothing
	#  once the 문양 tab (the last one) is already open.
	if _onboarding:
		_advance_onboard_tab()
		onboard_inserted.emit()


## Moves the open tab one kind forward — 진 → 룬 → 문양 — and drops whatever was picked, the same reason a
## tab switch always clears the pick (`_click_palette`'s own comment: carrying a pick across kinds could
## let a rune get "placed" through a glyph seat). Does nothing once the last kind is already open.
func _advance_onboard_tab() -> void:
	var next := _open_tab + 1
	if next < Palette.KINDS.size():
		_open_tab = next
		_clear_pick()


## Where slot `slot` of kind `kind` actually sits on the circle page, right now. **Read after the
## placement**, not before — for `KIND_CIRCLE` the frame's own center/radius do not move with which
## circle is equipped, but for `KIND_RUNE`/`KIND_GLYPH` the seat comes from the *now-current* `_circle`.
func _seat_of(kind: int, slot: int) -> Dictionary:
	var page := Book.circle_page(size)
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()
	if kind == Palette.KIND_CIRCLE:
		var f := Layout.frame(area)
		return {"at": f["center"], "r": f["radius"]}
	if kind == Palette.KIND_RUNE:
		var slots := Layout.rune_slots(id, area)
		if slot < 0 or slot >= slots.size():
			return {}
		return {"at": slots[slot], "r": Layout.rune_radius(id, area)}
	if kind == Palette.KIND_GLYPH:
		var bands := Layout.layer_bands(id, area)
		if slot < 0 or slot >= bands.size():
			return {}
		return {"at": bands[slot]["seat"], "r": Layout.glyph_radius(area)}
	return {}


func _clear_pick() -> void:
	_picked_kind = -1
	_picked_item = -1
	_picked_layer = -1


## **All three pass through the same question: "is there even one slot that would take this item".**
##
## **A real defect happened here** (verify-look). This function was asking **only about glyphs**
##  and always giving `true` for circles and runes => remove the circle and there are 0 rune seats while
##  **the rune stays bright and pickable, and after picking it, pressing anywhere did nothing.**
##  That is the "it is pressable and nothing happens" the design warned about.
##
## **The cause was the rule being split per kind** — the same reason `_place_or_clear` was gathered into
##  one place. "Glyphs are blocked but runes are not" is the same disease as "glyphs come out but runes do not".
##  => What differs per kind is only **how slots are counted** and **the accepting condition**; the question is one.
func _can_pick(kind: int, item_id: int) -> bool:
	for i in _slot_count(kind):
		if _slot_accepts(kind, i, item_id):
			return true
	return false


## How many slots that kind has. **All of it comes from the model** — remove the circle and both layers and
## rune seats become 0, and then the question above falls to "there is nowhere to place it" on its own.
func _slot_count(kind: int) -> int:
	if kind == Palette.KIND_CIRCLE:
		# The circle slot is the **single** frame seat and **it exists even with no circle**
		#  (`circle_layout.frame_has_point`). That is what lets a user who removed the circle put one back —
		#  leave it at 0 and they are **trapped.**
		return 1
	if kind == Palette.KIND_RUNE:
		return _circle.rune_count()
	if kind == Palette.KIND_GLYPH:
		return _circle.layer_count()
	push_error("CircleWindow: unknown slot kind %d - treating the slot count as 0" % kind)
	return 0


## Does that slot take this item. **Only glyphs have a constraint; circles and runes do not.**
## The glyph constraint comes from `glyph_defs.DEFS` and is **not written again here** (`can_place_glyph` is
##  called) — write it and the rule has two copies and what `net_circle`'s bidirectional agreement was
##  measuring becomes meaningless.
## **Only empty layers count.** Overwriting layer 1 while spread is on layer 1 is allowed by the rules, but
##  allowing it looks like "spread is there and spread gets blocked". => Moving means removing first, as one rule.
##
## **Rune ownership is not asked here any more** (`onboarding-and-palette-tabs.md` §2, reversing
##  `rune-lock-and-receiving.md`'s "the gate lives here, not in `palette_layout.items_of()`"). An unowned
##  rune now has no cell at all — `Palette.items_of()` filters it out before this function is ever reached
##  through a real click, so asking `_progress.owns_rune()` again here would be a second copy of a question
##  that is already answered by the item simply not existing. This function's only remaining job is "can it
##  be placed right now", which for a circle or a rune is unconditionally yes.
func _slot_accepts(kind: int, index: int, item_id: int) -> bool:
	if kind != Palette.KIND_GLYPH:
		return true
	# **Stage 8** (`onboarding-and-palette-tabs.md`) — every 문양 card is a *seated* glyph now (there is no
	#  stash to place a fresh one from), so picking one is always picking a layer to *move*, never a value
	#  to place. A move is a swap between two layers' contents, which can never violate `max_per_circle`
	#  (the multiset seated is unchanged, only the order) — the only real question left is whether another
	#  layer even exists to swap with. `item_id`/`index` are unused here on purpose: the question "can this
	#  be picked at all" no longer depends on which value or which specific layer, only on there being more
	#  than one.
	return _circle.layer_count() > 1


func _draw() -> void:
	# The coordinates are **relative to the window's inside** (a `Control`'s `_draw` uses its own rect origin).
	#  Use screen coordinates and only the drawing fails to follow when the window moves.
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Fx.WINDOW_BG, true)
	draw_rect(r, Fx.WINDOW_EDGE, false, Fx.WINDOW_EDGE_PX)

	# If there is no font it **does not draw.** Passing `null` makes the engine bark every frame, and since
	#  the wrapper counts stderr as failure, the nets go red wholesale at that moment.
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(font,
		Vector2(Fx.WINDOW_PAD_PX, Fx.WINDOW_PAD_PX + float(Fx.WINDOW_TITLE_SIZE)),
		Fx.WINDOW_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.WINDOW_TITLE_SIZE, Fx.WINDOW_TITLE_COLOR)

	# -- the opened book --
	# The page rectangles come from `book_layout` alone — the drawing and (stage 4b's) clicking read them together.
	#  Draw the fold separately here and **the visible boundary and the click boundary diverge** (risk 23).
	var pages := Book.pages(size)
	draw_rect(pages["left"], Fx.BOOK_PAGE, true)
	draw_rect(pages["right"], Fx.BOOK_PAGE, true)
	draw_rect(pages["fold"], Fx.BOOK_FOLD, true)
	# The left page is **deliberately empty** — the palette is stages 4b and 5.

	if _circle == null:
		return

	# **Moving the magic circle onto the right page is a coordinate-system transform.** The page position is not
	#  added to the magic circle's coordinates — add it and `circle_layout` learns where it sits, and the day
	#  the window shape changes the magic circle's code opens with it (section 3.7).
	#  **The price is that stage 4b must undo this transform to take clicks** (risk 22).
	#   The value to subtract is `pages()["right"].position` — **the same value used here.**
	# **Which page is the magic circle is decided by `book_layout`.** Pin the key here and the day left and right
	#  flip, the window and the nets flip separately and it stays **green with only one side moved**
	#  (section 3.7 — it has already flipped once).
	var page := Book.circle_page(size)
	draw_set_transform(page.position)

	# **Every coordinate comes from `circle_layout`.** Compute even one here and stage 4b's hit test uses
	#  different coordinates, and that goes to the wrong layer with no error.
	var area := Layout.circle_area(page.size)
	var id := _circle.circle_id()
	_draw_frame(area, id)
	_draw_rune_slot(area, id)
	# **The layer count here comes from the model (`layer_count()`) while the ring radii inside `_draw_ring`
	#  come from the table (`layer_bands()`) — there are two sources.** Today both derive from `circle_defs`
	#  and give the same number, but the day they drift, `_draw_ring`'s `layer >= bands.size()` guard
	#  **draws less without barking** (if the model has more) or **loops less** (if the table has more).
	#  On screen it only reads as "one layer is missing". If they are to be merged, merge toward **the table** —
	#   the drawing must get its seats from the table, and the model only knows what is placed on those seats.
	for i in _circle.layer_count():
		_draw_ring(area, id, i, font)

	# **찰칵 — falling `t`, drawn at the seat captured when the click landed** (`_click_fx`), not
	#  recomputed here. `t` reaches 0 exactly when `_click_frames` does, so the flash and the counter
	#  agree by construction.
	if _click_frames > 0:
		_draw_click_fx(_click_seat, _click_radius, float(_click_frames) / float(Fx.CLICK_FRAMES))

	# **완성's glow — one flash over the circle**, the same falling-`t` shape as the click above.
	if _glow_frames > 0:
		var f := Layout.frame(area)
		_draw_done_glow(f["center"], f["radius"], float(_glow_frames) / float(Fx.DONE_GLOW_FRAMES))

	# **It must be restored.** Without restoring, everything drawn afterwards is shifted by the page —
	#  and the palette below is exactly that "everything drawn afterwards".
	draw_set_transform(Vector2.ZERO)

	# The palette also draws **inside its own page**, relative to its origin. The same discipline as the magic circle.
	var pal := Book.palette_page(size)
	draw_set_transform(pal.position)
	_draw_palette(pal, font)
	draw_set_transform(Vector2.ZERO)


# ══════════════════════════════════════════════════════════════════
#  **The three axes — they do not call each other**
#   The day runes become two, the only thing that opens is `_draw_rune_slot`.
# ══════════════════════════════════════════════════════════════════

## Circle axis — the vessel's rim. Even with no circle **the seat is drawn.** That is what "an empty slot" is,
##  and it is why the magic circle visibly shrinking to a single slot is seen when the circle is removed (stage 5).
##
## **`PIC_TRIANGLE` gets its own frame here — the wrapping ring, the link bands, the center ornament.**
##  This is the one place `_draw_frame` is allowed to branch on picture (`circle_layout.layer_bands`'s own
##  header exempts exactly this function: "the picture is decided at the circle axis, and only there").
## `CircleDefs.picture(CircleDefs.CIRCLE_NONE)` answers `PIC_ROUND` quietly, so "no circle" still falls
##  through to the plain vessel rim below — unchanged from before this branch existed.
func _draw_frame(area: Rect2, circle_id: int) -> void:
	var f := Layout.frame(area)
	if CircleDefs.picture(circle_id) == CircleDefs.PIC_TRIANGLE:
		_draw_triangle_frame(area, f, circle_id)
		return
	# **It uses the same function as the palette's circle.** Draw it separately here and the day the circle's
	#  frame changes, **only the palette's circle fails to follow** — runes and glyphs already shared functions
	#  and only the circle did not.
	_draw_circle_symbol(f["center"], f["radius"])


## **The triangle's own frame — belongs to the circle axis, not the rune axis.** It reads
##  `Layout._socket_centers` directly, the same shared helper `rune_slots()`/`layer_bands()` both read —
##  **not** `Layout.rune_slots()`. Reading the rune axis's own function here would hang the circle axis off
##  the rune axis, exactly the coupling `circle_layout.gd`'s header argues against (one level up into this file).
##
## Three pieces, in the order `docs/design/circle-art.md`/`tools/pixel/draw_circle.py:123` describe them —
##  split into their own named functions **so each is independently drivable** (verify-read: a mutation that
##  made this whole function return before drawing anything left every net in this file green, because
##  nothing here called it in a way that could observe "drew nothing" versus "drew the real thing" — counting
##  calls to the three pieces below closes that).
##  (1) the wrapping ring at `TRI_RING`/512 of the frame radius — **not the full radius**, the sockets punch
##      through it (a user request recorded there)
##  (2) the three link bands between socket centers, half-width `TRI_LINK_HALF`
##  (3) the center ornament, two circles at `TRI_CENTER_R` and `TRI_CENTER_R - TRI_BAND`.
##      **It is not a glyph seat** — nothing anchors a `+` or a symbol here, on purpose
## Still the procedural line-and-circle vocabulary (`_draw_circle_symbol`'s own family) — the socket glyph
##  art is step 6.
##
## **Invariant, not re-checked here**: `centers.size()` comes from `CircleDefs.rune_slots(circle_id)`, the
##  same count `circle_layout.layer_bands()` independently uses to build `n` bands. The two agree today only
##  because the triangle row's own `layers` and `rune_slots` columns are both 3 — if a future picture ever
##  gave those two columns different values, this file's link topology and that file's band count would
##  quietly draw a different number of sockets each, with nothing raising an index error unless one runs
##  past the other's array length.
func _draw_triangle_frame(area: Rect2, f: Dictionary, circle_id: int) -> void:
	var radius: float = f["radius"]
	var center: Vector2 = f["center"]
	var basis := radius / float(Fx.TRI_CANVAS_R)

	_draw_triangle_wrap_ring(center, float(Fx.TRI_RING) * basis)

	var n := CircleDefs.rune_slots(circle_id)
	var centers := Layout._socket_centers(area, n)
	_draw_triangle_links(centers, float(Fx.TRI_LINK_HALF) * basis * 2.0)

	_draw_triangle_ornament(center, float(Fx.TRI_CENTER_R) * basis, float(Fx.TRI_BAND) * basis)


func _draw_triangle_wrap_ring(center: Vector2, r: float) -> void:
	draw_circle(center, r, Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)


func _draw_triangle_links(centers: PackedVector2Array, width: float) -> void:
	for i in centers.size():
		var j := (i + 1) % centers.size()
		draw_line(centers[i], centers[j], Fx.CIRCLE_FRAME, width)


func _draw_triangle_ornament(center: Vector2, outer_r: float, band: float) -> void:
	draw_circle(center, outer_r, Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)
	draw_circle(center, outer_r - band, Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)


## Rune axis — the rune seats. Both the **number** of seats and their **positions** come from the circle table.
## An empty rune is **the same grey** as a dead staff tip — same meaning, so the same color is what connects
##  the two screens at a glance.
##  Writing out "why can it not fire" in text is stage 5. This stage goes as far as **drawing the state honestly.**
##
## **`RUNE_EMPTY` no longer reaches here by clicking** (`_click_circle`'s own comment) — only by swapping the
##  circle out and back (`spell_circle.set_circle()` resizes and fills every rune slot with `RUNE_EMPTY`). This
##  branch stays for that path; it is not dead code.
##
## **The bark raised here is "every frame", not "once per event".**
##  `Layout.rune_slots()` barks on `rune_slots != 1` and this function is called **60 times a second** while
##  the window is open => the day a 2-rune-seat circle arrives, the log is buried at 60 lines a second and the
##  wrapper's stderr check gets just as noisy.
##  **It does not bite today** (there is 1 rune seat). Whoever grows the runes must move the bark out of the
##   frame **then** — `spell_sim._run_glyph`'s bark is once per impact, an entirely different cost.
##   The same goes for `_draw_glyph` below.
func _draw_rune_slot(area: Rect2, circle_id: int) -> void:
	var r := Layout.rune_radius(circle_id, area)
	var slots := Layout.rune_slots(circle_id, area)
	for i in slots.size():
		var rune_id := _circle.rune_at(i)
		if rune_id == SpellCircle.RUNE_EMPTY:
			# **This is the third device saying "it cannot fire"** (section 3.5 — the staff tip and the HUD
			#  already stood up in stage 1).
			#  An empty rune seat is a **warning**, not an invitation saying "you may place here" —
			#   it **means something different from a layer's empty seat (`+`), so it is drawn differently.**
			#   It is **the same grey** as a dead staff tip so the two screens say the same thing.
			#   The constant names were `MUZZLE_DEAD` and `MUZZLE_DEAD_WIDTH_PX` — they became
			#    `DEAD_TINT` and `DEAD_RING_PX` when the muzzle bead disappeared. **Value and meaning are unchanged.**
			draw_circle(slots[i], r, Fx.DEAD_TINT, false, Fx.DEAD_RING_PX)
			continue
		# **The rune's own picture** (`Fx.RUNE_TEX`); the two beads stay as the fallback.
		if _rune_tex.has(rune_id):
			# **`RUNE_ART_FRAC` — the picture sits inside the ring's hole** (that constant's own box carries
			#  the pixel measurements). The seat and `r` are untouched: `r` still sizes the click target and
			#  the empty-seat ring, and only the drawn picture shrinks.
			_paint_art(_rune_tex[rune_id], _square_at(slots[i], r * Fx.RUNE_ART_FRAC), Fx.CIRCLE_ART_TINT)
		else:
			_draw_rune_symbol(slots[i], r, rune_id)


## Layer axis — one ring, the layer number, and the glyph placed on it.
##
## **Two devices hang on "inner comes first"** (design acceptance 3):
##   (1) **The layer number** 1 and 2 written beside the ring
##   (2) **A brightness difference** — bright inside, darker outward. It divides by the layer count, so a
##     3-layer circle is automatic
##  A concentric circle alone says only that an order **exists**, never **which side comes first.**
## **No picture branch — that is the whole point of `edges`/`seat` on `layer_bands()`'s dict.** A concentric
##  band's `edges` holds one radius and strokes one ring, exactly as before; a socket band's `edges` holds two
##  and strokes the full annulus (outer and inner rim) at the **same** center. Whichever picture this circle
##  is, this function never asks — a window with an `if picture ==` in it here would be the coupling
##  `circle_layout.gd`'s header argues against, one level up (`_draw_frame`/`_draw_triangle_frame` above is
##  the one place that split is allowed to live, because the frame genuinely differs shape to shape).
func _draw_ring(area: Rect2, circle_id: int, layer: int, font: Font) -> void:
	var bands := Layout.layer_bands(circle_id, area)
	if layer < 0 or layer >= bands.size():
		return
	var n := bands.size()
	var band: Dictionary = bands[layer]
	var center: Vector2 = band["center"]
	var edges: PackedFloat32Array = band["edges"]
	# With only 1 layer there is nothing to divide — dividing by 0 makes the drawing disappear wholesale.
	var t := 0.0 if n <= 1 else float(layer) / float(n - 1)
	var col := Fx.CIRCLE_RING_INNER.lerp(Fx.CIRCLE_RING_OUTER, t)
	# **One call per edge, through a named seat** (verify-read: `for e in [edges[0]]` — dropping the inner
	#  rim of a socket band — passed every net in this file, because nothing recorded which radii were
	#  actually stroked). `_draw_ring_edge` exists so a test can override it and record.
	for e in edges:
		_draw_ring_edge(center, e, col)
	# **The ring's own picture, laid over the rim rather than replacing it** (`Fx.RING_TEX`).
	#  **Replacing the stroke was tried first and is wrong**: `_draw_ring_edge` is what
	#  `net_circle`'s edge checks count, and they exist because dropping a socket band's inner rim once
	#  passed every check in that file. Swapping the stroke for art would have silently retired that guard
	#  to draw a picture. ⇒ The rim keeps its contract, and the art sits on it.
	#  A layer with no glyph, or a glyph with no art, is byte-for-byte what it was before.
	var ring_glyph := _circle.glyph_at(layer)
	if _ring_tex.has(ring_glyph):
		_paint_art(_ring_tex[ring_glyph], _square_at(center, edges[0]), Fx.CIRCLE_ART_TINT)

	# `edges[0]` is always the outer edge (`edges` is outer-first) — the one radius to hang the layer number
	#  beside regardless of how many edges this band owns.
	var outer: float = edges[0]
	if font != null:
		# **Whether the socket number (1·2·3) belongs on the triangle picture is still an open user
		#  question** (`triangle-circle-to-game.md`, decision C) — this is not a decision, just what falls
		#  out of not special-casing it: `_draw_ring` already wrote the layer number for every band before
		#  the triangle existed, and nothing here filters it back out. Judged on screen, not before.
		# The 9 o'clock direction (relative to `center`). The glyph symbol sits at 12 o'clock (`seat`,
		#  round) or dead center (`seat`, triangle), so writing the number there would overlap either way.
		# Both the text size and the offset distance **derive from the radius** — grow only the size and keep
		# the offset in px and the text sinks into the ring as it grows.
		var num := Layout.layer_num_size(area)
		draw_string(font, center + Vector2(
				-outer + float(num) * Fx.CIRCLE_LAYER_NUM_INSET_FRAC,
				-float(num) * Fx.CIRCLE_LAYER_NUM_LIFT_FRAC),
			str(layer + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, num, Fx.CIRCLE_LAYER_NUM)

	var seat: Vector2 = band["seat"]
	var glyph_id := _circle.glyph_at(layer)
	# **Empty seats are drawn too — "you can place here" has to be in the picture.**
	#  Without drawing it, "a blocked seat" and "an empty seat" look the same, and in stage 4b-2b where to press
	#   is not on the screen (the first of the three slot states — the `fx_tuning.SLOT_EMPTY` comment).
	if glyph_id == Glyph.GLYPH_NONE:
		_draw_empty_slot(seat, Layout.glyph_radius(area))
		return
	# **A socket band's own glyph art (step 6) — reached only when the band owns more than one edge.**
	#  A concentric band (`PIC_ROUND`, and any future picture built the same way) always has exactly one
	#  edge (`layer_bands`' own header), so this line never fires for the round circle without asking
	#  `CircleDefs.picture()` — `_draw_ring` stays picture-agnostic in code even though the two pictures end
	#  up drawn differently. **A glyph missing from `Fx.SOCKET_GLYPH_TEX` (six of twelve ids today —
	#  `DUMMY_C`/`R`/`U` and `CONDENSE_C`/`R`/`U`, that map's own header) falls straight through to the same
	#  procedural symbol the round circle and the palette both use — it must not draw nothing**, that is this repo's signature fake
	#  with the sim and screen roles swapped (the model already holds a real glyph here; drawing nothing
	#  would be the screen quietly failing to say so).
	if edges.size() > 1 and _socket_glyph_tex.has(glyph_id):
		_draw_socket_glyph_texture(seat, edges[0], _socket_glyph_tex[glyph_id], glyph_id)
		return
	_draw_glyph(seat, Layout.glyph_radius(area), glyph_id)


func _draw_ring_edge(center: Vector2, r: float, col: Color) -> void:
	draw_circle(center, r, col, false, Fx.CIRCLE_RING_PX)


## **Fills the socket's bounding square** — side length is the socket's own diameter (`edges[0]`, the outer
##  radius, doubled). Whatever inner hole the art has (spread 72 · blast 75, `triangle-circle-art.md`) is
##  **baked into the art itself**, so filling the full square does not mask it — cropping to a smaller rect
##  here would.
##
## **A rarity ring is drawn here now** (`RARITY_TINT`, the one decided device for rarity — "Rarity must
##  separate by color", `levelup-and-three-picks.md`) — verify-read found the first version skipped it
##  entirely, leaving common/rare/unique of the same family **pixel-identical** on a socket band, a real
##  regression against that decided rule (`_draw_glyph`'s own rarity ring already holds it for the round
##  circle and the palette). **Placed at the socket's own outer radius (`r`), not `RARITY_RING_RATIO` beyond
##  it** — that ratio sizes the round circle's small glyph symbol floating in open space, but a socket's
##  outer edge is already the picture's own boundary, and pushing further out lands past `TRI_RING`, the
##  wrapping ring the socket already punches through. **Unverified on screen**: whether the ring still reads
##  against the art, or blurs into `_draw_ring_edge`'s own stroke at the same radius — a place for the eye.
## **For verify-look: the procedural fallback and the empty-slot `+` draw on top of the rune bead, not
## inside the band** (verify-read, measured on today's `Fx.WINDOW_RECT`; not fixed — a screen judgment, not
## a bug this file can resolve): frame radius **140.06** · socket center distance from the circle's own
## center **100.67** · socket outer radius **39.39** · this band's inner edge **26.26**, which is also
## `rune_radius()`'s own answer — `_draw_rune_slot` draws its rune bead as a **filled** disc of that same
## radius at the socket center, and `_draw_ring`'s `seat` for this band **is that same point**, so the
## procedural symbol (radius `glyph_radius()` **16.11**, rarity ring to **20.9**) and the empty-slot `+`
## both land centered *inside* the rune bead, not spread across the band the way a concentric round-circle
## layer's own drawing is. **The texture path is the only one that actually fills the band** — and even it
## does not clear the rune: the art's own inner hole (spread **~72**, blast **~75**, on the 512 basis
## `triangle-circle-art.md` measured) scales to **~19.7** viewport px here, smaller than the rune bead's
## **26.26**, so the art covers roughly **6.5px** of the rune — the "48 band intrudes on the rune's 96" risk
## the plan's own art doc flagged, now visible for the first time with a real rune drawn underneath it.
## **Tinted, not raw** — measured: the art is a transparent field with strokes at RGB(26,24,22), so drawn
## untinted on this window's dark panel **nothing appears**. The socket showed a bare rarity ring and the
## glyph read as absent while the model held it. Same `GLYPH_TINT` the palette and the procedural fallback
## use, so the three drawing paths stay one color axis (`three_pick_window._draw_pick_card_texture` too).
## **The one seat every ring and rune picture is painted through, and it exists to be overridden.**
## `_draw()` running is not the same as a picture reaching the screen — the art in `assets/circle/` sat on
## disk unreferenced until now, which is that failure in its purest form. A test subclass overrides this and
## records the **texture and the rect**, so "the ring stopped being drawn" cannot pass as green.
##
## **Not named `_paint`** — `monster_view.gd` already owns that name with a different signature, and
##  `gate_view` had to be renamed once already for exactly this collision.
func _paint_art(tex: Texture2D, r: Rect2, tint: Color) -> void:
	draw_texture_rect(tex, r, false, tint)


## The bounding square of a circle of radius `r` at `at` — the same framing `_draw_socket_glyph_texture`
## uses, kept in one place now that three callers want it.
func _square_at(at: Vector2, r: float) -> Rect2:
	return Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)


## Path map -> loaded map, dropping anything that fails to load. **A failed load must leave the id absent**,
## not present-and-null, so the caller's `has()` falls through to the procedural drawing.
static func _load_tex_map(paths: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: int in paths:
		var tex: Texture2D = load(paths[id]) as Texture2D
		if tex != null:
			out[id] = tex
	return out


func _draw_socket_glyph_texture(at: Vector2, r: float, tex: Texture2D, glyph_id: int) -> void:
	var tint: Color = Fx.GLYPH_TINT.get(glyph_id, Fx.GLYPH_TINT_MISSING)
	draw_texture_rect(tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)
	_draw_socket_rarity_ring(at, r, glyph_id)


## Split out of `_draw_socket_glyph_texture` so a test can record which glyph id the rarity colour was
## actually read for — a call-count on the parent function alone cannot tell "drew the right rarity" from
## "drew common's colour for everything".
func _draw_socket_rarity_ring(at: Vector2, r: float, glyph_id: int) -> void:
	var rarity_col: Color = Fx.RARITY_TINT.get(Glyph.rarity_of(glyph_id), Fx.GLYPH_TINT_MISSING)
	draw_circle(at, r, rarity_col, false, Fx.RARITY_RING_PX)


## **Shape from `family` (via `Fx.GLYPH_SYMBOL`), color from the glyph id, rarity from a ring around it.**
##  Give each glyph its own drawing and that becomes **a fourth place to fix**, and `glyph_defs.gd` itself
##  wrote "if a fourth place appears the structure is wrong, so stop".
##  => A new family gets its shape **for free**, by adding one row to `GLYPH_SYMBOL`.
## **By `family`, not by `kind`** (`glyph-condense.md` §11.5) — two families (blast, condense) share
##  `KIND_TERMINAL` now, and dispatching on `kind` alone would draw them identically: a condense card showed
##  blast's exact filled disc until this line changed. `family` is **the whole of the pipeline** for `kind`
##  (design doc) and now for the picture too, so **the drawing still teaches the rule.**
func _draw_glyph(at: Vector2, r: float, glyph_id: int) -> void:
	if not Glyph.DEFS.has(glyph_id):
		push_error("CircleWindow: glyph %d is not in the table - cannot draw it" % glyph_id)
		return
	var tint: Color = Fx.GLYPH_TINT.get(glyph_id, Fx.GLYPH_TINT_MISSING)
	_draw_glyph_rarity_ring(at, r, glyph_id)

	var family := Glyph.family_of(glyph_id)
	var sym: int = Fx.GLYPH_SYMBOL.get(family, -1)
	if sym == Fx.SYM_SPAWN_RAYS:
		# Branches reaching outward — "it makes new bolts" is in the shape.
		for k in Fx.GLYPH_SPAWN_RAYS:
			# Rotated by half a step — without rotating, the horizontal rays lie on top of the ring line and
			#  **disappear** (the `fx_tuning.GLYPH_SPAWN_ANGLE_STEP_FRAC` comment holds the measurement).
			var a := TAU * (float(k) + Fx.GLYPH_SPAWN_ANGLE_STEP_FRAC) / float(Fx.GLYPH_SPAWN_RAYS)
			var d := Vector2(cos(a), sin(a))
			draw_line(at + d * (r * Fx.GLYPH_SPAWN_INNER_RATIO), at + d * r,
				tint, Fx.GLYPH_SYMBOL_PX)
		return
	if sym == Fx.SYM_TERMINAL_DISC:
		# A filled disc — "it ends right there" is in the shape.
		draw_circle(at, r * Fx.GLYPH_TERMINAL_RATIO, tint, true)
		return
	if sym == Fx.SYM_MODIFY_DIAMOND:
		# A hollow diamond — outline only, so "touches neither trajectory nor list" does not read as either
		#  of the other two shapes (`fx_tuning.GLYPH_MODIFY_RATIO`'s comment).
		var d := r * Fx.GLYPH_MODIFY_RATIO
		var pts: Array[Vector2] = [
			at + Vector2(0.0, -d), at + Vector2(d, 0.0), at + Vector2(0.0, d), at + Vector2(-d, 0.0),
		]
		for k in pts.size():
			draw_line(pts[k], pts[(k + 1) % pts.size()], tint, Fx.GLYPH_MODIFY_PX)
		return
	if sym == Fx.SYM_PILLAR_UP:
		# **A filled spike — "it rises" is in the shape.** Base to apex, the apex always at the symbol's own
		#  top edge (`fx_tuning.GLYPH_PILLAR_*`'s own comment: every family's symbol fills the same circle).
		var half_w := r * Fx.GLYPH_PILLAR_WIDTH_RATIO
		var base_y := r * Fx.GLYPH_PILLAR_BASE_RATIO
		var tip_base_y := -r * Fx.GLYPH_PILLAR_TIP_RATIO
		var pts: Array[Vector2] = [
			at + Vector2(-half_w, base_y), at + Vector2(half_w, base_y),
			at + Vector2(half_w, tip_base_y), at + Vector2(0.0, -r), at + Vector2(-half_w, tip_base_y),
		]
		draw_polygon(pts, [tint])
		return
	# It barks on an unknown symbol — grow the family table without growing this map and it gets caught here.
	push_error("CircleWindow: glyph family %d has no symbol (glyph %d)" % [family, glyph_id])


## **A second, independent device — the same "two devices" idiom `_draw_ring` already uses for
##  "innermost first"** (layer number + brightness). Rarity sits **outside** the symbol's own radius so it
##  never fights `GLYPH_TINT`'s color for the same pixels.
##
## **It is its own function because the picture path needs it too.** A palette card drawn from `ICON_TEX`
##  skips `_draw_glyph` entirely, and rarity is the one thing the art deliberately does not carry
##  (`Fx.ICON_TEX`'s box) — inline this back into `_draw_glyph` and **every card loses its tier the day the
##  icon loads**, with the model still holding it and nothing barking. Distinct from
##  `_draw_socket_rarity_ring`, which strokes at `r` rather than `RARITY_RING_RATIO * r`: a socket band's
##  radius is already the outer rim.
func _draw_glyph_rarity_ring(at: Vector2, r: float, glyph_id: int) -> void:
	var rarity_col: Color = Fx.RARITY_TINT.get(Glyph.rarity_of(glyph_id), Fx.GLYPH_TINT_MISSING)
	draw_circle(at, r * Fx.RARITY_RING_RATIO, rarity_col, false, Fx.RARITY_RING_PX)


## Rune symbol — a glowing bead. **The palette and the slot use this same function.**
##  Draw them separately and it becomes "the palette's fire looks different from the fire placed in the circle",
##  and that is quiet.
func _draw_rune_symbol(at: Vector2, r: float, rune_id: int) -> void:
	var fx := Fx.elem_fx(rune_id)
	draw_circle(at, r, fx["glow"], true)
	draw_circle(at, r * Fx.CIRCLE_RUNE_CORE_RATIO, fx["core"], true)


## Circle symbol — the vessel's rim. A circle is a **frame**, so being hollow inside is its meaning.
func _draw_circle_symbol(at: Vector2, r: float) -> void:
	draw_circle(at, r, Fx.CIRCLE_FRAME, false, Fx.CIRCLE_FRAME_PX)


## **An empty seat — "you can place here".**
##  **The plus is gone — the user: "문양이 도넛 모양으로 껴져야 되는데 위쪽에 플러스 표시가 왜 있는지
##  잘 모르겠어."** This overturns what this function used to argue (a ring alone reads only as "a seat",
##  not as an invitation to place). With the rune grown and the two layer rings pushed outward around it
##  (`Fx.CIRCLE_RING_GAP_FRAC`), an empty layer's ring now sits nested against the rune's own disc and the
##  frame — a donut stack, not a lone circle — so the ring alone reads as "you can put something here"
##  with no mark drawn inside it.
##  Fill it and it is confused with the TERMINAL disc — being empty is part of the meaning.
func _draw_empty_slot(at: Vector2, r: float) -> void:
	_draw_slot_ring(at, r)


## **Split out of `_draw_empty_slot` so a recording subclass can assert the ring itself painted, with the
##  arguments it was actually given** — the `notice_rect` lesson (CLAUDE.md): asserting a pure geometry
##  function alone lets `_draw()` hand it something else entirely, and 320 checks stayed green over exactly
##  that hole once already. `net_circle` captures this call's `at`/`r` and compares them to
##  `circle_layout.layer_bands()`'s own `seat` and `Layout.glyph_radius(area)`.
##
## **Dashed, not a solid circle — decided by the user, a second time** (`fx_tuning.SLOT_EMPTY_DASH_COUNT`'s
## own comment: a solid empty ring reads the same as a *filled* layer's own solid ring, differing only by
## color/thickness). The angles come from `slot_dash_arcs()` below (pure, so a net drives the count and gap
## with no window) — this function's own job shrinks to "paint whatever that answers".
func _draw_slot_ring(at: Vector2, r: float) -> void:
	for arc in slot_dash_arcs():
		_paint_slot_dash(at, r, arc.x, arc.y)


## **Pure and static** — the same seat `stage.camera_center`/`entrance_zoom` already hold in `stage.gd`: a
## net calls this directly with no window and no circle, and `_draw_slot_ring` above is the *only* caller so
## the drawn ring can never quietly diverge from what this returns.
## Each `Vector2` is one dash's `(start_rad, end_rad)`. `n <= 0` answers no dashes at all rather than
## dividing by zero — an empty ring config draws nothing sooner than it crashes.
static func slot_dash_arcs() -> Array[Vector2]:
	var arcs: Array[Vector2] = []
	var n := Fx.SLOT_EMPTY_DASH_COUNT
	if n <= 0:
		return arcs
	var step := TAU / float(n)
	var dash := step * (1.0 - Fx.SLOT_EMPTY_DASH_GAP_FRAC)
	for i in n:
		var start := step * float(i)
		arcs.append(Vector2(start, start + dash))
	return arcs


## **The hook a net overrides to prove a dash actually reached the screen** — the same reason
## `_paint_pillar`/`_paint_dust` already exist: `draw_arc` is native, Godot refuses to let a script override
## it, so an ordinary method is the only seam available (CLAUDE.md's own warning on this exact shape).
func _paint_slot_dash(at: Vector2, r: float, from_rad: float, to_rad: float) -> void:
	draw_arc(at, r, from_rad, to_rad, Fx.SLOT_EMPTY_DASH_POINTS, Fx.SLOT_EMPTY, Fx.SLOT_EMPTY_PX)


## 찰칵 — a ring that widens and fades as `t` falls from 1 to 0. Named so a net can record the argument
## at the hook (`settlement_layout.notice_rect`'s own lesson: a pure counter asserted alone is the hole —
## the seat and the falling value both have to be captured at the call, not re-derived).
func _draw_click_fx(at: Vector2, r: float, t: float) -> void:
	var col := Fx.CLICK_COLOR
	col.a *= t
	draw_circle(at, r * (1.0 + (1.0 - t) * 0.4), col, false, Fx.CIRCLE_FRAME_PX * 1.5)


## 완성's glow — one flash filling the circle's own frame, fading as `t` falls from 1 to 0.
func _draw_done_glow(at: Vector2, r: float, t: float) -> void:
	var col := Fx.PALETTE_DONE_GLOW_COLOR
	col.a *= t
	draw_circle(at, r, col, true)


# ══════════════════════════════════════════════════════════════════
#  Palette — **"slot kind x item".** Not glyph-only. One tab open at a time
# ══════════════════════════════════════════════════════════════════

## Every coordinate comes from `palette_layout` — the hit test must be able to call **the same functions.**
## **Three named seats below the tab strip and the open section** — `_draw_palette_tab`/`_draw_palette_done`/
##  `_draw_palette_empty_note` exist so a net can override them and record what actually reached the
##  screen (`settlement_layout.notice_rect`'s own lesson: a pure function asserted alone let `_draw()` hand
##  it a bare `Rect2()` under 320 green checks).
func _draw_palette(page: Rect2, font: Font) -> void:
	var tab_rects := Palette.tabs(page.size)
	for i in tab_rects.size():
		_draw_palette_tab(tab_rects[i], Palette.KINDS[i], i == _open_tab)

	var sec := Palette.section(page.size)
	var kind: int = Palette.KINDS[_open_tab]
	_draw_palette_section(sec, kind, font)
	# Items come from **iterating the table, filtered by ownership** — write them by hand and the table
	#  grows while the palette does not; fold ownership into `_can_pick` instead of `items_of` and a placed
	#  glyph vanishes from its own tab the instant it lands (design §2's worked example).
	var items := Palette.items_of(kind, _progress, _circle)
	if items.is_empty() and kind == Palette.KIND_GLYPH:
		# **문양 starts empty, and says so** (design §3) — a line of text where the row of cells would be,
		#  not a blank rectangle (the same reason `_draw_palette_section` always draws a frame and a title:
		#  an empty box with neither reads as unfinished, not as "there is nothing here yet").
		_draw_palette_empty_note(sec, font)
	for ii in items.size():
		var slot := Palette.item_slot(sec, ii, items.size())
		_draw_palette_item(slot, kind, items[ii])

	_draw_palette_done(Palette.done_rect(page.size), font)


## One tab. **Background and text color both flip on open/closed** — which tab is open reads even before
##  the label is read.
func _draw_palette_tab(rect: Rect2, kind: int, is_open: bool) -> void:
	draw_rect(rect, Fx.PALETTE_TAB_OPEN_BG if is_open else Fx.PALETTE_TAB_CLOSED_BG, true)
	draw_rect(rect, Fx.PALETTE_TAB_EDGE, false, Fx.PALETTE_TAB_EDGE_PX)
	var font := get_theme_default_font()
	if font == null or not Palette.KIND_DEFS.has(kind):
		return
	var nm: StringName = Palette.KIND_DEFS[kind]["name"]
	draw_string(font,
		rect.position + Vector2(0.0, rect.size.y * Fx.PALETTE_HEAD_BASELINE_FRAC),
		String(nm), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, Fx.PALETTE_TAB_SIZE,
		Fx.PALETTE_TAB_OPEN_TEXT if is_open else Fx.PALETTE_TAB_CLOSED_TEXT)


## The "마법진 완성" band — always present, in every tab (design §5: it confirms, it does not apply).
func _draw_palette_done(rect: Rect2, font: Font) -> void:
	draw_rect(rect, Fx.PALETTE_DONE_BG, true)
	draw_rect(rect, Fx.PALETTE_DONE_EDGE, false, Fx.PALETTE_DONE_EDGE_PX)
	if font == null:
		return
	draw_string(font,
		rect.position + Vector2(0.0, rect.size.y * Fx.PALETTE_HEAD_BASELINE_FRAC),
		Fx.PALETTE_DONE_TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, Fx.PALETTE_DONE_SIZE,
		Fx.PALETTE_DONE_TEXT_COLOR)


## The 문양 tab's empty note. **Only when there are no seated glyphs** — `_draw_palette` guards the call,
##  this function only draws.
func _draw_palette_empty_note(rect: Rect2, font: Font) -> void:
	if font == null:
		return
	draw_string(font,
		rect.position + Vector2(Fx.PALETTE_PAD_PX, rect.size.y * 0.5),
		Fx.PALETTE_EMPTY_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.PALETTE_EMPTY_SIZE, Fx.PALETTE_EMPTY_COLOR)


## A section — **it makes the empty space read as "a seat for what is coming".** With only four items the page
##  is largely empty, and without a frame and a title the same screen simply reads as **unfinished.**
func _draw_palette_section(sec: Rect2, kind: int, font: Font) -> void:
	draw_rect(sec, Fx.PALETTE_SECTION_BG, true)
	draw_rect(sec, Fx.PALETTE_SECTION_EDGE, false, Fx.PALETTE_SECTION_EDGE_PX)
	if font == null:
		return
	if not Palette.KIND_DEFS.has(kind):
		push_error("CircleWindow: unknown slot kind %d - it has no title" % kind)
		return
	var nm: StringName = Palette.KIND_DEFS[kind]["name"]
	draw_string(font, sec.position + Vector2(
			Fx.PALETTE_PAD_PX, Fx.PALETTE_HEAD_PX * Fx.PALETTE_HEAD_BASELINE_FRAC),
		String(nm), HORIZONTAL_ALIGNMENT_LEFT, -1,
		Fx.PALETTE_HEAD_SIZE, Fx.PALETTE_HEAD_COLOR)


## One item. **It uses the same symbol functions as drawing into a slot** — draw them separately and it becomes
##  "the palette's blast looks different from the blast placed in the circle", and that is quiet.
func _draw_palette_item(slot: Rect2, kind: int, item_id: int) -> void:
	var at := slot.get_center()
	var r := Palette.item_symbol_radius(slot)

	if kind == Palette.KIND_CIRCLE:
		# **The one kind with no picture, and it is not an oversight** — `circle-art.md` records that circles
		#  are drawn from coordinates and never generated, and there is no `assets/circle/circle_*.png` to
		#  point at. The frame stroke stays until one exists.
		_draw_circle_symbol(at, r)
	elif kind == Palette.KIND_RUNE:
		# **The same file the slot inside the circle draws** (`_draw_rune_slot`). Point the card at a
		#  different picture and it becomes "the palette's fire is not the fire I placed", which is the exact
		#  divergence `_draw_rune_symbol`'s own header was written against — the sharing moves from the
		#  procedural bead to the art, it does not end.
		#  **`RUNE_ART_FRAC` is deliberately absent here**: that fraction exists to fit the bead inside the
		#  ring's hole, and a card has no ring around it.
		if _rune_tex.has(item_id):
			_paint_art(_rune_tex[item_id], _square_at(at, r), Fx.CIRCLE_ART_TINT)
		else:
			_draw_rune_symbol(at, r, item_id)
	elif kind == Palette.KIND_GLYPH:
		# **The card gets `ICON_TEX`, never `RING_TEX`** — the ring belongs to the layer band and reads as
		#  mush at this size (that constant's box). Rarity is stroked separately because the three tiers
		#  share one picture on purpose.
		if _icon_tex.has(item_id):
			_paint_art(_icon_tex[item_id], _square_at(at, r * Fx.PALETTE_ICON_FRAC), Fx.CIRCLE_ART_TINT)
			_draw_glyph_rarity_ring(at, r, item_id)
		else:
			_draw_glyph(at, r, item_id)
	else:
		push_error("CircleWindow: slot kind %d has no item drawing" % kind)
		return

	# **What cannot be placed is dimmed** — with spread already in place, a second spread **cannot be pressed
	#  in the first place** (design).
	#  If it is pressable and nothing happens, that reads as a malfunction. Blocking it one step earlier is the point.
	#  **`modulate` must not be used** — it applies to the whole node and lingers into the next frame.
	#   => A **veil** is laid over that cell alone.
	# All three kinds go the same way — that the constraint exists only for glyphs is what `_can_pick` knows.
	if not _can_pick(kind, item_id):
		draw_rect(slot, Color(Fx.PALETTE_SECTION_BG, Fx.PALETTE_BLOCKED_VEIL_A), true)
		return
	# An outline on what is picked. **Not presentation but half of the action** —
	#  without seeing what was picked, the first half of "pick then place" is not on screen.
	if _picked_kind == kind and _picked_item == item_id:
		draw_rect(slot, Fx.PALETTE_PICK, false, Fx.PALETTE_PICK_PX)
