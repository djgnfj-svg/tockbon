extends Control
## The boss health bar and name — `boss-entrance-and-hp-bar.md`, Stage B. **Both stage-1 bosses**, big,
## across the top of the screen, with the boss's own name drawn over it.
##
## **Modeled on `hp_view.gd` line for line** (frame first, fill on top, pure statics a net calls with no
## node) — **not** the mob vocabulary's 4px head bar (`monster_view`'s `_draw_hp_bar` / `Fx.MONSTER_HP_BAR_*`),
## which this must not be mistaken for. Screen only; it reads `Monster.hp` live and never writes it.
##
## **`_boss` is a reference, not a copy** — the same rule `hp_view._ch` holds. Copy `hp` and the day one
## push is forgotten it becomes "the boss took damage and the bar did not move", with nothing barking.

const Fx := preload("res://src/view/fx_tuning.gd")
const Monster := preload("res://src/actor/monster.gd")
const MonsterDefs := preload("res://src/actor/monster_defs.gd")

var _boss: Monster = null

## **The entrance clock, pushed in every physics frame from `stage._physics_process`** — `-1` means "no
## entrance running" (`fade_alpha(-1)` is 0, the same "not yet arrived" reading a fresh `show_boss()` starts
## at). It is never read back out; `stage.gd` owns the single counter (`_entrance_frames`) this mirrors.
var _entrance_frames := -1

## The frame art. **No null check, deliberately** — the same call `hp_view._frame_tex` makes; `load()` barks
## on a bad path and a quiet `return` would make it "the bar is invisible and nobody said why".
var _frame_tex: Texture2D = load(Fx.HP_FRAME_TEX)


func show_boss(m: Monster) -> void:
	_boss = m


func clear_boss() -> void:
	_boss = null


## **The one door `stage._physics_process` pushes the shared entrance counter through** — see
## `_entrance_frames`'s own comment on why the bar does not keep a second clock of its own.
func set_entrance_frames(frames: int) -> void:
	_entrance_frames = frames


func _ready() -> void:
	position = Fx.BOSS_BAR_RECT.position
	size = Fx.BOSS_BAR_RECT.size
	# **`mouse_filter` is set in the scene, never here** — `hp_view._ready()`'s own comment: `net_render`
	#  forbids writing it at runtime so the scene's value cannot become a false knob.


## **`visible` derived every frame, never latched** — the same discipline `gate_view._process()` already
## holds, and for the same reason: a settlement panel that never set `visible` shipped under 5,576 green
## checks. False before the row materialises (`_boss == null`), true while it lives, false again the instant
## `hp <= 0` — the corpse's own death animation is the mob vocabulary's job, not this bar's.
func _process(_dt: float) -> void:
	visible = _boss != null and _boss.hp > 0
	if not visible:
		return
	# **The whole node fades as one unit** — `CanvasItem.modulate`, not baked into each `_paint_*` colour.
	#  Baking it in would mean the captured colour a net reads from `_paint_name` never equals
	#  `Fx.BOSS_NAME_COLOR` exactly while a fade is running; a net (or the eye) can still read `modulate.a`
	#  directly for the fade itself.
	modulate.a = fade_alpha(_entrance_frames)
	queue_redraw()


## **The filled fraction, clamped** — the same guard `hp_view.fill_frac` holds, widened by `kind` since this
## bar shows two different `max_hp`s across a single run (`MonsterDefs.max_hp`, not `Character.MAX_HP`).
static func fill_frac(hp: int, kind: int) -> float:
	var max_hp := MonsterDefs.max_hp(kind)
	if max_hp <= 0:
		return 0.0
	return clampf(float(hp) / float(max_hp), 0.0, 1.0)


## Where the frame art sits inside this node's own rect — the bottom `Fx.BOSS_BAR_FRAME_H_PX` of it, full
## width. The top `size.y - BOSS_BAR_FRAME_H_PX` is the name band above it (`name_baseline` below).
static func frame_rect(panel: Vector2) -> Rect2:
	return Rect2(0.0, panel.y - Fx.BOSS_BAR_FRAME_H_PX, panel.x, Fx.BOSS_BAR_FRAME_H_PX)


## The fill, inset inside the frame art — the same `hp_inner_rect` shape `hp_view.gd` already holds, applied
## to `frame_rect` instead of the whole panel (this panel also carries the name band above the frame).
static func bar_rect(panel: Vector2) -> Rect2:
	var f := frame_rect(panel)
	var i := Fx.BOSS_BAR_INSET_PX
	return Rect2(f.position.x + i, f.position.y + i,
		maxf(0.0, f.size.x - i * 2.0), maxf(0.0, f.size.y - i * 2.0))


## Where the name's baseline sits, centred horizontally on the node — `draw_string` takes a baseline, not a
## top (`hp_view._paint_number`'s own reason), so `_paint_name` below still has to shift left by half the
## measured string width; this only fixes the point that half-width is measured from.
static func name_baseline(panel: Vector2, _font: Font) -> Vector2:
	var band_h := panel.y - Fx.BOSS_BAR_FRAME_H_PX
	return Vector2(panel.x * 0.5, band_h * 0.5 + float(Fx.BOSS_NAME_SIZE) * Fx.HP_NUMBER_BASELINE_FRAC)


## **The whole of beat 3's fade, pure and static** — the same seat `gate_view.tint()` holds. Alpha ramps
## 0 -> 1 over `Fx.BOSS_BAR_FADE_FRAMES`, then holds at 1 for as long as `stage.gd` keeps feeding a frame
## count past it (the entrance counter freezes at its own total once the whole sequence ends, so the bar
## simply stays opaque — no second "hold" branch needed here).
## **`maxf` guards the constant, not the counter** — the same reason `gate_view.tint()`'s own guard exists:
## set to 0 the plain division is NaN, and a NaN alpha reaches `modulate` with nothing barking.
static func fade_alpha(entrance_frames: int) -> float:
	return clampf(float(entrance_frames) / maxf(float(Fx.BOSS_BAR_FADE_FRAMES), 1.0), 0.0, 1.0)


## The title drawn above the bar — **not `MonsterDefs.name_of()`** (that is the kind, 황소/거대 수탉; this is
## the title the world gave it). `Fx.BOSS_TITLES`'s own comment records why `KIND_ROOSTER`'s row is present
## but empty rather than missing or invented.
static func title_of(kind: int) -> String:
	return String(Fx.BOSS_TITLES.get(kind, ""))


## **Each part is its own method so a net can override it and read what it was handed** — the same reason
## `hp_view._paint_frame`/`_paint_fill`/`_paint_number` are split out. Godot refuses to let a script override
## `draw_texture_rect`/`draw_rect`/`draw_string` themselves, so an ordinary method is the only seam.
func _draw() -> void:
	if _boss == null:
		return
	_paint_frame(_frame_tex, frame_rect(size), Fx.HP_FRAME_TINT)
	_paint_fill(bar_rect(size), fill_frac(_boss.hp, _boss.kind))
	var font: Font = ThemeDB.fallback_font
	if font != null:
		_paint_name(font, name_baseline(size, font), title_of(_boss.kind), Fx.BOSS_NAME_SIZE, Fx.BOSS_NAME_COLOR)


func _paint_frame(tex: Texture2D, r: Rect2, tint: Color) -> void:
	draw_texture_rect(tex, r, false, tint)


## The bar. **Ground first, then the fill** — the other way round the fill is covered and the bar reads as
## permanently empty with every value still correct (`hp_view._paint_fill`'s own reason, copied verbatim).
func _paint_fill(r: Rect2, frac: float) -> void:
	draw_rect(r, Fx.BOSS_BAR_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Fx.BOSS_BAR_FULL, true)


## The name, **centred on the baseline `name_baseline` returns** — measured and shifted by half its own
## width, the same idiom `hp_view._paint_number` uses so a longer title does not drift off-centre.
func _paint_name(font: Font, baseline: Vector2, text: String, name_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	draw_string(font, Vector2(baseline.x - w * 0.5, baseline.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, color)
