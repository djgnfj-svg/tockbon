extends Node2D
## The town's three fixtures on screen — a block, a name, and a prompt on the one being stood at.
## **It touches the screen only.** Which fixture is reachable is decided by `Fixtures.at()`; this file asks
##  that question and draws the answer, exactly as `monster_view` reads `world` and never writes it.
##
## **It is drawn, not built out of nodes.** Three `Sprite2D`s plus three `Label`s would be six nodes in the
##  scene file whose positions live in two places (the scene and `town_map.FIXTURE_TILES`), and the pair
##  drifts silently — the same trap `monster_view._ready` records for its own layers ("pin them in the scene
##  file and those two worlds diverge, and the divergent symptom shows up on screen only").
##
## **Hidden outside the town.** The shell flips `visible`; there is no second copy of "am I in the town" here.

const Fixtures := preload("res://src/actor/fixtures.gd")
const TownMap := preload("res://src/stage/town_map.gd")
const Character := preload("res://src/actor/character.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

var _char: Character = null

## kind -> centre x in world px. **Read once** — the room is a constant, so recomputing it every frame would
##  be work with no possible different answer.
var _seats: Dictionary = TownMap.fixture_seats()

## kind -> its sprite. **Loaded once, at construction**, the same reason `monster_view._anim_sheets` is:
##  `load()` is engine-cached, but relying on that cache is relying on something no net can see.
var _sprites: Dictionary = load_sprites()


## static, so `net_town` can check every path loads before any node exists — the same door
##  `MonsterView._load_sheets` opens.
static func load_sprites() -> Dictionary:
	var out: Dictionary = {}
	for kind: int in Fx.TOWN_FIXTURES:
		out[kind] = load(Fx.TOWN_FIXTURES[kind]["path"]) as Texture2D
	return out


func setup(ch: Character) -> void:
	_char = ch
	queue_redraw()


func _process(_dt: float) -> void:
	# The prompt follows the player every frame, so there is always something to redraw while visible.
	queue_redraw()


## **Which fixture the player can use right now, or -1.** The shell asks this too (to act on E), and both go
##  through this one function so the prompt and the action can never disagree — a prompt that says "[E] 조립대"
##  while E opens something else is exactly the kind of screen/sim split this repo calls its signature fake.
func reachable() -> int:
	if _char == null:
		return -1
	return Fixtures.at(_seats, _char.center().x)


## The floor line the blocks stand on (world px). **Derived from the room, not written down** — the same
##  reason `monster_view.box_rect` reads the box from `monster_defs`: two copies of "where the floor is"
##  means the fixtures sink into it or float above it, and nothing barks either way.
static func floor_y() -> float:
	return float(TownMap.ROOM_Y1 + 1) * float(Tuning.TILE_CELLS * Tuning.CELL_PX)


## Where one fixture is drawn. **Pure static, so a net can call it with no scene** — the same idiom as
##  `monster_view.box_rect`.
##
## **Centred on its seat and standing on the floor**, whatever its own proportions are: the three pieces are
##  three different shapes (a squat bench, a wide bench, a tall gate) and lining them up by anything other
##  than the ground line would make them look like they float at different heights.
static func fixture_rect(kind: int, seat_x: float) -> Rect2:
	var row: Dictionary = Fx.TOWN_FIXTURES.get(kind, {})
	var w := float(row.get("w", 32.0)) * Fx.TOWN_FIXTURE_ZOOM
	var h := float(row.get("h", 32.0)) * Fx.TOWN_FIXTURE_ZOOM
	return Rect2(seat_x - w * 0.5, floor_y() - h, w, h)


func _draw() -> void:
	# If there is no font it does not draw text — passing `null` barks every frame, and the wrapper counts
	#  stderr as failure, so an ordinary screen would turn the nets red (`monster_view._draw_dmg_number`).
	var font: Font = ThemeDB.fallback_font
	var here := reachable()
	for kind: int in _seats:
		var seat := float(_seats[kind])
		var r := fixture_rect(kind, seat)
		var tex: Texture2D = _sprites.get(kind)
		if tex == null:
			# Substitute, do not bark — `Fx.TOWN_FIXTURE_FALLBACK`'s own box.
			draw_rect(r, Fx.TOWN_FIXTURE_FALLBACK)
		else:
			# **`false` for `tile`** — the art is drawn to `r`, which is its own size times the zoom, so this
			#  is an integer upscale of a pixel-art sprite and not a stretch to an arbitrary box.
			draw_texture_rect(tex, r, false)
		if font == null:
			continue
		_centered(font, String(Fixtures.name_of(kind)), seat, r.position.y - Fx.TOWN_NAME_LIFT_PX,
			Fx.TOWN_NAME_SIZE, Fx.TOWN_NAME_COLOR)
		if kind == here:
			_centered(font, prompt_text(kind),
				seat, r.position.y - Fx.TOWN_PROMPT_LIFT_PX, Fx.TOWN_PROMPT_SIZE, Fx.TOWN_PROMPT_COLOR)


## **The prompt line's own text — pure, so a net can drive `_draw()` and check the string it captured**
## (`onboarding-and-palette-tabs.md` Stage 7). 연구대 reads 「준비중」 here instead of `TOWN_PROMPT_FMT` —
## this is the visible seat for that closed door: `stage._town_message` sits behind F3, so the player would
## never see it there. Every other fixture is unaffected.
static func prompt_text(kind: int) -> String:
	if kind == Fixtures.KIND_RESEARCH:
		return Fx.TOWN_RESEARCH_PROMPT
	return Fx.TOWN_PROMPT_FMT % String(Fixtures.name_of(kind))


## Centred text. **The same idiom as `monster_view._draw_dmg_number`** — everything in this repo's
##  `draw_string` family is LEFT-aligned, so the width is measured and the seat shifted by half.
func _centered(font: Font, text: String, cx: float, y: float, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(cx - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
