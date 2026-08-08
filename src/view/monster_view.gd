extends Node2D
## Monsters, chicken bolts, and death sites. It touches the screen only — the world is **read** from `WorldStep`.
##
## Having no interpolation is correct — monsters run at 60Hz (the same clock as rendering), so there is nothing
##  between ticks (the same reason as `character_view.gd`'s first line).
##
## **Death notifications (`world.died_*`) are valid only within that tick** (the next tick clears them — the same
##  contract as blast notifications, `world_step.gd` header). => **Corpses are caught in `on_tick()`, not in
##  `_process()`** (the same door as `blast_fx.on_blasts()` — `stage.gd`'s `_on_ticked()` calls it).
##  Otherwise it is read only after the next tick has cleared the notification, so corpses cannot exist in principle.
##
## **Flashes and damage numbers do not add a new notification to the actor — the view observes hp every frame
##  and makes them.** hp is already a public field, and **ids are never reused**
##  (`world_step._next_monster_id` comment), so **keying by id makes the diff safe** — the same idiom as
##  `character_view._prev_x` (comparing against the previous frame). **It is different from diffing an id list to
##  find "who died"** — that is a problem `world_step` already solved with notification arrays (the trap under
##  "behavior (10)" above), and what is diffed here is only "did a living monster of the same id lose hp",
##  so the reuse and teleport traps do not bite.
## **One seat it cannot catch**: the last damage on the very tick a monster dies is not seen by this diff,
##  because the monster is already out of the array — on that frame the corpse appears with no flash and no
##  number. A place of no certainty (reported below).

const WorldStep := preload("res://src/actor/world_step.gd")
const Monster := preload("res://src/actor/monster.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
## **It is held for `CELL_PX` alone** — fire attached to a body has to snap to the cell grid for its vocabulary
##  to match the ground fire (the `_draw_body_flames` box). This is the only place the view reads a sim constant.
const Tuning := preload("res://src/sim/sim_tuning.gd")

## The name the shader receives. **Kept as a constant** — pin the string and one wrong letter means
##  **nothing happens at all and there is no error** (`net_render`'s "false knob" section is that story).
const FLASH_COLOR_PARAM := "flash_color"

## **Layer names — the nets find them by these. Do not find them by child index.**
##  **Measured**: a net was grabbing the flash layer with `get_child(0)`, and putting the outline layer in
##   front of it made it **quietly start measuring the wrong node.**
##   => Order is a drawing contract, **not a name tag.** A net must not break every time a layer is added.
const LAYER_OUTLINE := "Outline"
const LAYER_FLASH := "Flash"
const LAYER_NUMBER := "Number"

var _world: WorldStep = null

## id -> previous frame's hp. `_scan_hp_changes()` fills and clears it (the header above).
var _prev_hp: Dictionary = {}
## id -> remaining flash frames.
var _flash_left: Dictionary = {}

## Damage numbers and corpses — **independent entities** (they stay on screen for a while after the monster is gone).
##  The same idiom as `blast_fx._flashes`: `Array[Dictionary]` plus an age in frames.
var _dmg_numbers: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []
## The ring that pops at the moment of death. **It is born from the same notification as the corpse but has a
##  different lifetime** (shorter) — so the two cannot share one array (`_prune` takes a lifetime per array).
var _death_pops: Array[Dictionary] = []

## Kind -> body sprite. Built from `Defs.ALL` — growing the kinds (one line in `monster_defs.gd` plus one line
## in `fx_tuning.MONSTER_SHEETS`) needs no edit here.
## **No `null` check is attached — instead the reading side substitutes with `.get()`** (`_draw_monster_body`).
##  A different discipline from `character_view._body_tex`: there is only one character, so barking when it
##  breaks is fine, but monsters always have several kinds and the rest must still show when one breaks
##  (the `MONSTER_FILL` box above).
var _sheets: Dictionary = _load_sheets()

## Frame counter — the clock for the wobble of fire attached to a body.
## **`Time.` is not used.** This is `src/view/` so it is outside the determinism contract, but as a frame counter
##  a net can call `advance()` N times and **reproduce the same picture** (a wall clock cannot).
var _frame: int = 0

## **A child node dedicated to the flash.** The shader material is **per node**, so everything drawn here
##  becomes a white silhouette => **it cannot sit on the same node as the body.**
##  Being a child, it is drawn **after** the parent = laid on top of the body. That is the order needed.
var _flash_layer: Node2D = null
## Damage numbers go above even the flash — otherwise the flash covers the numbers (both being whitish is
## the worst case).
var _number_layer: Node2D = null
## **The outline goes "below" the body — it is a child pushed behind with `show_behind_parent`.**
##  A child is above the parent by default, and an outline covering the body makes **the whole silhouette cream.**
##  It hangs **the same shader with a different color** as the flash — the color is a per-node uniform, so the
##   nodes have to be split.
var _outline_layer: Node2D = null


## A shell delegating drawing to child nodes. **The point is to avoid making a script file per child** —
##  more files scatter "what does this node do" across three places.
##
## **It is `fn.call(self)` — it passes itself. That is half this class's reason to exist.**
##  **A real bug happened when it was called with no argument**: the delegated function drew onto
##   **the implicit `self` (= the parent MonsterView)**, and the parent was not drawing, so
##   **that command was silently discarded.** Damage numbers disappeared from the screen wholesale with
##   **no error and every net green** (nets read arrays, not the canvas).
##  => Forcing the canvas as an argument makes **the receiving side not using it visible.**
class _Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## static — so a net can verify the values even before `_init` runs (`net_monster_sprite`).
static func _load_sheets() -> Dictionary:
	var out: Dictionary = {}
	for kind: int in Defs.ALL:
		out[kind] = load(Fx.MONSTER_SHEETS[kind]) as Texture2D
	return out


## **The layers are created here — not put in the scene file.**
##  A net sometimes stands this node up with `new()` and no scene and only pushes `advance()` through
##   (the reason those are public functions), and then `_ready` does not run and the layers **live as null.**
##   => **The drawing side must tolerate null.**
##  Pin them in the scene file and those two worlds diverge, and the divergent symptom shows up **on screen only.**
func _ready() -> void:
	var sh := load(Fx.MONSTER_FLASH_SHADER) as Shader
	# **The outline is created first** — child order is drawing order, and this is the only one with
	# `show_behind_parent`.
	_outline_layer = _make_layer(_draw_outlines, LAYER_OUTLINE)
	_outline_layer.show_behind_parent = true
	_paint(_outline_layer, sh, Fx.MONSTER_OUTLINE_COLOR)
	_flash_layer = _make_layer(_draw_flashes, LAYER_FLASH)
	_paint(_flash_layer, sh, Fx.MONSTER_FLASH_COLOR)
	# **With no shader it goes without a material** — then the flash becomes its old shape (a white rectangle)
	#  and the outline is **the body sprite itself laid down eight times**, smeared. **It still does not bark**:
	#  this file's discipline is "on the monster side, substitute and do not bark" (`_load_sheets`).
	_number_layer = _make_layer(_draw_numbers, LAYER_NUMBER)


## Hangs the silhouette shader on a layer and puts the color in.
## **The color is a per-node uniform, so putting it in once here is enough** — every monster is the same color.
##  **The strength cannot go in** (it differs per monster) — the drawing side passes it as modulate alpha.
func _paint(layer: Node2D, sh: Shader, color: Color) -> void:
	if sh == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter(FLASH_COLOR_PARAM, color)
	layer.material = mat


func _make_layer(fn: Callable, nm: String) -> Node2D:
	var n := _Layer.new()
	n.fn = fn
	n.name = nm   # the nets find it by this name (the box above) — indices drift as layers are added
	add_child(n)
	return n


func setup(world: WorldStep) -> void:
	_world = world
	queue_redraw()


func _process(_dt: float) -> void:
	advance()
	queue_redraw()
	# Children **do not receive** the parent's `queue_redraw()`. Without calling it, the flash and the numbers
	#  freeze on the first frame, and the only symptom is "it does not flash when hit".
	for layer: Node2D in [_outline_layer, _flash_layer, _number_layer]:
		if layer != null:
			layer.queue_redraw()


## One frame's update — reads hp changes to make flashes and damage numbers, and ages the living presentations.
## **The same function `_process` calls** (the same idiom as `blast_fx.advance()`) — public so a net can push
## frames through with no scene.
##
## **Aging comes first and reading hp comes second.** Reverse the order and a flash or damage number created
##  this frame **loses one frame's worth inside the same call** — it was caught by measurement as a
##  `MONSTER_FLASH_FRAMES` (6) flash already going out after 5 frames (net failure).
func advance() -> void:
	_frame += 1
	_decay_flashes()
	_prune(_dmg_numbers, Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	_prune(_corpses, Fx.MONSTER_CORPSE_LIFE_FRAMES)
	_prune(_death_pops, Fx.MONSTER_DEATH_POP_FRAMES)
	if _world != null:
		_scan_hp_changes()


## **Death notifications are read only here.** `stage.gd`'s `_on_ticked()` calls it — call it every frame and
##  the notification is still alive by the next `frame()`'s tick branch, so corpses get created several times
##  (the same seat as the "one hit becomes three" trap in `world_step.frame()`).
func on_tick() -> void:
	if _world == null:
		return
	for i in _world.died_count():
		var d := {
			"x": _world.died_x(i), "y": _world.died_y(i), "kind": _world.died_kind(i), "age": 0,
		}
		_corpses.append(d)
		# **It pops at the moment of death — this is the chicken's only hit feedback**
		#  (`fx_tuning.MONSTER_DEATH_POP_FRAMES`).
		#  A chicken dies in one hit, so what `_scan_hp_changes`'s hp diff would look at is **already out of
		#   the array.** => Neither flash nor number shows for even one frame. **Only the death notification
		#   knows that moment.**
		#  **It is created from the same notification as the corpse** — hang it separately and a combination of
		#   "there is a corpse but no pop" can appear, which means the two paths diverged and it is visible
		#   on screen only.
		_death_pops.append(d.duplicate())


## Puts up a flash and a damage number for each monster whose hp dropped. Diffed by id (the header above).
func _scan_hp_changes() -> void:
	var seen: Dictionary = {}
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		seen[m.id] = true
		if _prev_hp.has(m.id):
			var prev: int = _prev_hp[m.id]
			if m.hp < prev:
				_flash_left[m.id] = Fx.MONSTER_FLASH_FRAMES
				_add_dmg_number(m, prev - m.hp)
		_prev_hp[m.id] = m.hp
	# ids that no longer live are cleaned up — without erasing them, dead ids pile up in the dictionary forever
	#  (the cap of 20 applies only to living monsters, and this dictionary is outside that cap).
	for id in _prev_hp.keys().duplicate():
		if not seen.has(id):
			_prev_hp.erase(id)
			_flash_left.erase(id)


## **If there is a recent number for the same monster, add to it — do not make a new one** (decided by the user).
##
## **On screen three `-10`s overlapped and looked like `-1000`, covering the hp bar too.** The problem was not
##  that there were three numbers but **that the three overlapped in the same spot** — the seat is `m.center()`,
##  so on rapid hits the coordinates are nearly identical.
##
## **The age is rewound to 0 and the seat is refreshed.** Without rewinding, the merged number **disappears
##  soon after**, making it look as if the last hit landed with no display. The seat is refreshed because the
##  monster may have moved in the meantime (pigs push their way in).
## **The rewind is itself the risk of "it never ages"** — which is why the `MONSTER_DMG_NUM_MERGE_FRAMES`
##  comment pinned down "it must be shorter than the lifetime". **The number not disappearing while it keeps
##  getting hit is intended.**
##
## **It searches by id.** Search by coordinates and, when two monsters stand overlapping, someone else's damage
##  gets merged in.
func _add_dmg_number(m: Monster, amount: int) -> void:
	for n: Dictionary in _dmg_numbers:
		if n["id"] == m.id and int(n["age"]) < Fx.MONSTER_DMG_NUM_MERGE_FRAMES:
			n["amount"] = int(n["amount"]) + amount
			n["age"] = 0
			n["x"] = m.center().x
			n["y"] = float(m.y)
			return
	_dmg_numbers.append({
		"id": m.id, "x": m.center().x, "y": float(m.y), "amount": amount, "age": 0,
	})


func _decay_flashes() -> void:
	for id in _flash_left.keys().duplicate():
		var left := int(_flash_left[id]) - 1
		if left <= 0:
			_flash_left.erase(id)
		else:
			_flash_left[id] = left


func _prune(list: Array[Dictionary], max_age: int) -> void:
	var i := list.size() - 1
	while i >= 0:
		var age := int(list[i]["age"]) + 1
		if age >= max_age:
			list.remove_at(i)
		else:
			list[i]["age"] = age
		i -= 1


## The stage reset (R) calls this. The same door as `spell_view.clear()` and `blast_fx.clear()` —
##  without emptying, dead ids from the old session remain in the dictionary after R, and instead of the new
##  session's corpses and numbers mixing in, old traces can briefly sit on screen (it is emptied for safety).
func clear() -> void:
	_prev_hp.clear()
	_flash_left.clear()
	_dmg_numbers.clear()
	_corpses.clear()
	_death_pops.clear()
	queue_redraw()


# ══════════════════════════════════════════════════════════════════
#  Queries — the nets read only here (the same idiom as `blast_fx`'s "queries" section)
# ══════════════════════════════════════════════════════════════════

func corpse_count() -> int:
	return _corpses.size()


func corpse_kind(i: int) -> int:
	return _corpses[i]["kind"]


func is_flashing(id: int) -> bool:
	return _flash_left.has(id)


func death_pop_count() -> int:
	return _death_pops.size()


func dmg_number_count() -> int:
	return _dmg_numbers.size()


func dmg_number_amount(i: int) -> int:
	return _dmg_numbers[i]["amount"]


# ══════════════════════════════════════════════════════════════════
#  Drawing
# ══════════════════════════════════════════════════════════════════

func _draw() -> void:
	if _world == null:
		return
	# Corpses are drawn before living monsters — a living monster (newly standing in the same spot) must cover
	#  the corpse for "it is gone" to feel natural. Overlap is rare (when the next spawn is in the same spot),
	#  but the order follows the same rule as scene child order (above terrain, below the character) —
	#  what is drawn first is below.
	for c: Dictionary in _corpses:
		_draw_corpse(c)
	for i in _world.monster_count():
		_draw_monster(_world.monster_at(i))
	# Chicken bolts. `MonsterBolts` does not pass a direction (its public API is only `x(i)` and `y(i)`), so they
	# are drawn as dots — acceptance 13's requirement ("a small dot / short line") is met with a dot.
	# **It is two layers — the same grammar as a magic bolt (glow + core), a different color.** Changing only
	#  the color did not split them: the old pink and the none purple were 85 degrees apart and still got
	#  confused (the `fx_tuning.MONSTER_BOLT_COLOR` box).
	for i in _world.bolt_count():
		var p := Vector2(_world.bolt_x(i), _world.bolt_y(i))
		draw_circle(p, Fx.MONSTER_BOLT_R_PX, Fx.MONSTER_BOLT_COLOR)
		draw_circle(p, Fx.MONSTER_BOLT_R_PX * Fx.MONSTER_BOLT_CORE_FRAC, Fx.MONSTER_BOLT_CORE)
	# The pop at the moment of death — **above corpses and monsters, below the flash.**
	for p: Dictionary in _death_pops:
		_draw_death_pop(p)
	# If the layers are missing (a net stood this up with no scene), they are drawn here instead — otherwise
	#  two worlds appear, "visible in the scene but absent in the net".
	if _flash_layer == null:
		_draw_flashes(self)
	if _number_layer == null:
		_draw_numbers(self)
	# The outline is not drawn here — with no layer it would be laid **on top of the body** and cover the
	#  silhouette wholesale.
	#  This is the case where a net stands it up with no scene, so there is no screen, and "absent is better
	#  than wrong".


## The flash layer calls this (`_flash_layer`). **The same coordinate system as this node** — a child inherits
## the parent's transform.
##
## **It takes `canvas` as an argument. Without this one line, damage numbers disappeared from the screen wholesale.**
##  verify-look caught it — the array had `-40`, the font was there, the layer was visible, and yet
##   **nothing was on screen.** The cause was the **asymmetry** between this function and `_draw_numbers`:
##   the flash took `canvas` properly while the numbers drew onto **the implicit `self` (= MonsterView)**,
##   and that function is called **inside a child layer's `_draw()`**, so MonsterView is not drawing
##   => **that draw command is silently discarded.**
##  **The nets could not catch it in principle** — nets read arrays, not the canvas.
##  => **Now `_Layer` passes the canvas as an argument** (that class's box) — the seat for the mistake was
##   removed at the syntax level.
func _draw_flashes(canvas: CanvasItem) -> void:
	if _world == null:
		return
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		if not _flash_left.has(m.id):
			continue
		var r := box_rect(m.kind, m.x, m.y)
		var frac := float(_flash_left[m.id]) / float(Fx.MONSTER_FLASH_FRAMES)
		var a := Fx.MONSTER_FLASH_COLOR.a * frac
		var tex: Texture2D = _sheets.get(m.kind)
		if tex == null:
			# Fallback — even with the shader hung, `TEXTURE` is a white 1x1 so the result is
			#  "white rectangle x strength" (the head of `monster_silhouette.gdshader`). That is
			#  **the old behavior exactly.**
			var c := Fx.MONSTER_FLASH_COLOR
			canvas.draw_rect(r, Color(c.r, c.g, c.b, a))
			continue
		_draw_flipped(canvas, tex, r, m.facing < 0, Color(1.0, 1.0, 1.0, a))


## **The outline — the body sprite laid down in eight directions, with the body covering it on top.**
##
## **Why it exists**: verify-look stood a pig against **a black sky** and **its legs and belly melted away**
##  (the `fx_tuning.MONSTER_OUTLINE_COLOR` box holds that story).
##
## **The shader paints in a flat color, so the eight offset copies become the border directly** — only alpha
##  survives and the color is a uniform, so dark pixels of the body sprite never get laid down dark.
##  **`modulate` multiplication cannot do this** — multiplying only darkens the original, it **never brightens.**
##   So this presentation is **impossible in principle without a shader** (the user chose that axis).
##
## **It is drawn around corpses too** — a corpse melting into the background makes "where it died" invisible.
##  The same problem as a living body.
func _draw_outlines(canvas: CanvasItem) -> void:
	if _world == null:
		return
	for c: Dictionary in _corpses:
		var age: int = c["age"]
		var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
		# A corpse fades, so its outline has to fade with it — otherwise, after the body is gone,
		#  **only a cream outline is left floating.**
		_outline_one(canvas, c["kind"], c["x"], c["y"], false, alpha)
	for i in _world.monster_count():
		var m: Monster = _world.monster_at(i)
		_outline_one(canvas, m.kind, m.x, m.y, m.facing < 0, 1.0)


func _outline_one(canvas: CanvasItem, kind: int, x: int, y: int, flip: bool, alpha: float) -> void:
	var tex: Texture2D = _sheets.get(kind)
	if tex == null:
		return   # the fallback is a flat rectangle, so an outline would carry no meaning
	var r := box_rect(kind, x, y)
	var col := Color(1.0, 1.0, 1.0, alpha)
	for d: Vector2 in Fx.MONSTER_OUTLINE_DIRS:
		_draw_flipped(canvas, tex, Rect2(r.position + d * Fx.MONSTER_OUTLINE_PX, r.size), flip, col)


## **`canvas` must be passed down** — the `_draw_flashes` box above holds that story.
func _draw_numbers(canvas: CanvasItem) -> void:
	for n: Dictionary in _dmg_numbers:
		_draw_dmg_number(canvas, n)


func _draw_monster(m: Monster) -> void:
	var r := box_rect(m.kind, m.x, m.y)
	_draw_monster_body(m, r)
	# **The flash is not here** — the shader being per node sent it out to `_flash_layer` (the box above).
	if m.burning:
		_draw_body_flames(self, r, m.id)
	_draw_hp_bar(m.kind, m.x, m.y, m.hp)


## **Fire attached to a body — in several places.** It was originally one box outline and read on screen as
##  **"an orange selection box"** (acceptance 13). The ground fire on the same screen is real pixel fire, so
##  the contrast was brutal — the `fx_tuning.MONSTER_BURN_FLAMES` box holds that story.
##
## **The seats are fixed by monster id** — draw them again each frame and the flames **teleport every frame**,
##  and that is noise, not fire. What moves is **size only**, with the phases offset so they do not all jump together.
## **The flames spill a little outside the box** — the body outline is unknown (alpha is not read), so keeping
##  them strictly inside makes the fire look cut off at the silhouette's edge. Spilling reads as "it wraps the body".
##
## **They are square pixels snapped to the cell grid, not circles** (verify-look caught it on screen).
##  **It was two layers of `draw_circle` and, being "a red rim with a yellow inside", it read as "five targets".**
##   The ground fire right next to it is an irregular pixel clump that anyone reads as fire => **the contrast
##   was unchanged.** "An orange selection box" had merely become "five orange targets" — **still a shape.**
##
## **The fix went at the vocabulary, not the color — it is drawn with the same grammar as the ground fire.**
##  Ground fire is pixels painted on the `CELL_PX` (4px) grid => body fire is drawn as **4px-aligned square
##  pixel clumps** too.
##  **A perfect circle is a shape that does not exist on this game's screen** — terrain, fire and water are all cells.
##   So a circle reads as "UI" no matter how well the color is matched. The same mistake was made with the bolt glow.
##
## **The clump shapes are fixed by id and i too** — draw them again each frame and it becomes sizzling noise.
##  What moves is **the height (the tongue licking upward)** only.
func _draw_body_flames(canvas: CanvasItem, r: Rect2, id: int) -> void:
	var cell := float(Tuning.CELL_PX)
	for i in Fx.MONSTER_BURN_FLAMES:
		var p := flame_pos(r, id, i)
		# The phase is offset per flame — otherwise the five jump as one body.
		var phase := float(i) * TAU / float(Fx.MONSTER_BURN_FLAMES)
		var wob := sin(float(_frame) / Fx.MONSTER_BURN_PERIOD_FRAMES * TAU + phase)
		# **Snapped to the cell.** Drop the snap and the fire is misaligned with the cell grid, becoming
		#  "something floating on top".
		var bx := floorf(p.x / cell) * cell
		var by := floorf(p.y / cell) * cell
		# Tongue height — 1 to 3 cells. `wob` shakes the **height**, not the size (fire grows upward).
		var tall := 1 + int(roundf((wob * 0.5 + 0.5) * (Fx.MONSTER_BURN_TALL_CELLS - 1)))
		for k in tall:
			# Narrower and brighter toward the top — that is the whole of "a flame tongue".
			var w := cell * float(tall - k)
			var col: Color = Fx.FIRE_LO if k < tall - 1 else Fx.FIRE_HI
			canvas.draw_rect(Rect2(bx - w * 0.5, by - cell * float(k + 1), w, cell), col)


## The ring that pops at the moment of death — **the chicken's only hit feedback**
##  (`fx_tuning.MONSTER_DEATH_POP_FRAMES`).
##  It fades as it opens. Opening alone reads as "a ring was left behind", fading alone reads as "it blinked".
func _draw_death_pop(p: Dictionary) -> void:
	var r := box_rect(p["kind"], p["x"], p["y"])
	var t := float(p["age"]) / float(Fx.MONSTER_DEATH_POP_FRAMES)
	var radius := maxf(r.size.x, r.size.y) * 0.5 * lerpf(1.0, Fx.MONSTER_DEATH_POP_SCALE, t)
	var c := Fx.MONSTER_DEATH_POP_COLOR
	draw_arc(r.get_center(), radius, 0.0, TAU, 24, Color(c.r, c.g, c.b, c.a * (1.0 - t)),
		Fx.MONSTER_DEATH_POP_PX)


## **The sprite is drawn to fit `r` (= the box coming from `Defs`) — the texture's own pixel size is not trusted.**
##  `draw_texture_rect` stretches or shrinks to the destination size, so even if the art diverges from the box,
##  **the screen is still box-sized** (`net_monster_sprite` measures "they are the same today" as a value —
##  if they diverge, that goes red first).
##
## **If the texture is missing (load failure) it substitutes a `MONSTER_FILL` rectangle.** The
##  `fx_tuning.MONSTER_FILL` box above wrote the reason — monsters always have several kinds, so the rest
##  must still show when one breaks.
##
## **Monster art faces right — it is flipped when going left** (the same idiom as `character_view._draw`,
##  flipping the horizontal scale with `draw_set_transform`). **Do not forget to restore it** —
##  without restoring, everything drawn afterwards (flash, burn outline, hp bar) is drawn in a flipped
##  coordinate system.
func _draw_monster_body(m: Monster, r: Rect2) -> void:
	var tex: Texture2D = _sheets.get(m.kind)
	if tex == null:
		draw_rect(r, Fx.MONSTER_FILL)
		return
	_draw_flipped(self, tex, r, m.facing < 0, Color.WHITE)


## Draws the body sprite to fit the box. Flipped when facing left.
##  **Do not forget to restore it** — without restoring, everything drawn afterwards goes into a flipped
##  coordinate system.
##  **That is why it was gathered into this one function.** Write the same flip separately for the body and
##   the flash and **the day the two diverge**, a hit pig's white silhouette alone stands the wrong way,
##   and that is visible on screen only.
## Why it takes `canvas`: the flash is drawn onto **a child node** (the shader is per node).
func _draw_flipped(canvas: CanvasItem, tex: Texture2D, r: Rect2, flip: bool, modulate: Color) -> void:
	canvas.draw_set_transform(Vector2(r.position.x + (r.size.x if flip else 0.0), r.position.y),
		0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size), false, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hp_bar(kind: int, x: int, y: int, hp: int) -> void:
	var bar := hp_bar_rect(kind, x, y)
	draw_rect(bar, Fx.MONSTER_HP_BAR_BG)
	var frac := hp_bar_fill_frac(hp, Defs.max_hp(kind))
	if frac <= 0.0:
		return
	var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
	draw_rect(fill, Fx.MONSTER_HP_BAR_FULL.lerp(Fx.MONSTER_HP_BAR_EMPTY, 1.0 - frac))


## **A corpse is a body sprite too — laid down dark and faded** (acceptance 13 failed right here).
##  **It was originally a purple rectangle and read on screen as "is that a leftover UI fragment"** — bodies on
##   the same screen are sprites while only corpses were shapes, so **the value of having attached sprites was
##   cut in half.**
## **Darkening is `modulate` multiplication** — the alpha channel survives intact so the silhouette is exact.
##  Being multiplication it **cannot brighten.** That matches the direction of "it darkens when it dies",
##  so it is right here.
##
## **The direction is unknown — it always faces right.** The death notification (`world.died_*`) does not pass
##  `facing`.
##  **Die while walking left and the corpse snaps around.** Adding one field to the notification fixes it,
##   but that touches the `src/actor/` contract so it is **outside this scope.** Do it when it becomes noticeable.
func _draw_corpse(c: Dictionary) -> void:
	var kind: int = c["kind"]
	var r := box_rect(kind, c["x"], c["y"])
	var age: int = c["age"]
	var alpha := 1.0 - float(age) / float(Fx.MONSTER_CORPSE_LIFE_FRAMES)
	var tex: Texture2D = _sheets.get(kind)
	if tex == null:
		# Fallback — the same discipline as `_draw_monster_body` (substitute, do not bark).
		var col := Fx.MONSTER_CORPSE_COLOR
		draw_rect(r, Color(col.r, col.g, col.b, col.a * alpha))
		return
	var d := Fx.MONSTER_CORPSE_DIM
	draw_texture_rect(tex, r, false, Color(d, d, d, alpha))


## **It is `canvas.draw_string` — not a bare `draw_string`.**
##  **This is that seat** (the `_draw_flashes` box above). A bare `draw_string` hangs it on MonsterView itself,
##   and this function is called **while a child layer is drawing**, so **that command is silently discarded.
##   No error is raised either.**
##  `net_monster` measures this rule **in the source** — headless cannot catch it by behavior.
func _draw_dmg_number(canvas: CanvasItem, n: Dictionary) -> void:
	# If there is no font it does not draw — passing `null` barks every frame, and since the wrapper counts
	#  stderr as failure, an ordinary screen turns the nets red (the same discipline as `circle_window._draw`).
	# **It is not `get_theme_default_font()`** — this node is a `Node2D`, not a `Control`, so that function
	#  does not exist (`circle_window` is a `Control` so it could use it). The only way to get the default font
	#  from a `Node2D` is `ThemeDB`.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var age: int = n["age"]
	var t := float(age) / float(Fx.MONSTER_DMG_NUM_LIFE_FRAMES)
	var alpha := 1.0 - t
	# **It starts above the hp bar** — put it up straight from `m.y` and it covers the hp bar
	#  (verify-look saw it on screen. The `MONSTER_DMG_NUM_LIFT_PX` box).
	var y := float(n["y"]) - Fx.MONSTER_DMG_NUM_LIFT_PX - Fx.MONSTER_DMG_NUM_RISE_PX * t
	var col := Fx.MONSTER_DMG_NUM_COLOR
	var text := "-%d" % int(n["amount"])
	# Centered — everything in the `circle_window` family is LEFT, so the width is measured directly and it is
	# shifted left by half.
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE).x
	canvas.draw_string(font, Vector2(float(n["x"]) - w * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, Fx.MONSTER_DMG_NUM_SIZE,
		Color(col.r, col.g, col.b, col.a * alpha))


# ══════════════════════════════════════════════════════════════════
#  Pure static — the nets call these directly (the same idiom as `character_view.pick_state`)
# ══════════════════════════════════════════════════════════════════

## **Pure static, so the nets call it directly.** `_draw()` uses only this function, so the value the nets
## measure = the value actually drawn (`character_view.pick_state` and `spell_view`'s "queries" section).
## The size comes from `monster_defs` (actor). Put the size in `fx_tuning` and the box table lives in two places,
## and the only symptom is "the pig floats 12px off the wall" (the design doc's "screen" box).
static func box_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(x, y, Defs.w_px(kind), Defs.h_px(kind))


## The hp bar's seat — it comes from the box width (for the same reason as the box above, the width is not
## rebuilt here).
static func hp_bar_rect(kind: int, x: int, y: int) -> Rect2:
	return Rect2(float(x), float(y) - Fx.MONSTER_HP_BAR_GAP_PX - Fx.MONSTER_HP_BAR_H_PX,
		float(Defs.w_px(kind)), Fx.MONSTER_HP_BAR_H_PX)


## **The seat of one flame attached to a body. Pure static, so the nets call it directly.**
##
## **It is decided by id and index alone — the frame does not go in.** Change the seat per frame and the flames
##  **teleport every frame**, and that is noise, not fire (what moves is size only).
## **It is a hash, not `randi`.** Use `randi` and the same monster's fire stands somewhere different each frame,
##  and the nets cannot reproduce it either. This is `src/view/` so it is outside the determinism contract,
##  but **reproducibility is still needed.**
##
## **It is biased downward** (`MONSTER_BURN_LOW_BIAS`) — scattered evenly it reads as "glitter attached"
##  rather than "burning". Fire rises from below.
static func flame_pos(r: Rect2, id: int, i: int) -> Vector2:
	# Two large odd numbers are mixed — all it does is keep adjacent ids and is from landing in adjacent seats.
	var h := (id * 2654435761 + i * 40503) & 0xFFFFFF
	var fx := float(h & 0xFF) / 255.0
	var fy := float((h >> 8) & 0xFF) / 255.0
	fy = Fx.MONSTER_BURN_LOW_BIAS + (1.0 - Fx.MONSTER_BURN_LOW_BIAS) * fy
	return r.position + Vector2(r.size.x * fx, r.size.y * fy)


## The filled fraction of the hp bar. Clamped to 0-1 — negative hp is already blocked by `Monster.on_tick`'s
## `maxi(0, …)` (the doc's "there is one door that cuts hp"), but clamping once more on the screen side keeps
## the hp bar inside the box even if the table is misread.
static func hp_bar_fill_frac(hp: int, max_hp: int) -> float:
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)
