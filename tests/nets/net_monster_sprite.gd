extends RefCounted
## Does the monster body sprite **match the box.** Same idiom as `net_sprite.gd` (the character) —
##  "does it read as a monster" cannot be measured in principle. What this file measures is only the
##  **size contract** and the **alignment contract**.
##
## **One place that differs from the character — a monster has one sprite per kind.** There are no
##  per-state cells (`CHAR_FRAMES`) (open question 16 — there is no walk animation yet, `character-sprite`
##  set the precedent). => There is no "cell" check here corresponding to
##  `_cells_hold_their_contract` · `_table_stays_inside_the_sheet` — instead **the whole sprite is one box.**
##
## **The texture (`load`) cannot measure the sprite's content — the original png is opened separately.**
##  `Image.load_from_file` skips the import and reads the png on disk directly (same reason as `net_sprite`).
##
## **Without `.import`, the first line (reading the texture) goes red** — it does not vanish quietly.
##  `assets/monster/*.png` are files that first arrived in this work, so on a new machine a headless
##  `--import` has to be run once (the builder ran it and confirmed).

const Fx := preload("res://src/view/fx_tuning.gd")
const Defs := preload("res://src/actor/monster_defs.gd")
const MonsterView := preload("res://src/view/monster_view.gd")
const NetSprite := preload("res://tests/nets/net_sprite.gd")


func run(t) -> void:
	_sheets_load_from_the_table(t)
	for kind: int in Defs.ALL:
		_sheet_fits_the_box(t, kind)


## **`_sheets` comes from `MONSTER_SHEETS` — not from two hardcoded paths.**
##  Every kind has a value (positive) and swapping in a non-existent path makes only that entry `null`
##  (confirmed by inversion — the box below).
func _sheets_load_from_the_table(t) -> void:
	var sheets: Dictionary = MonsterView._load_sheets()
	t.eq(sheets.size(), Defs.ALL.size(), "종류 수만큼 그림이 실린다 (%d개)" % Defs.ALL.size())
	for kind: int in Defs.ALL:
		t.ok(sheets.has(kind), "%s 칸이 있다" % Defs.name_of(kind))
		var tex: Variant = sheets.get(kind)
		t.ok(tex != null, "%s 그림을 읽었다 (%s)" % [Defs.name_of(kind), Fx.MONSTER_SHEETS[kind]])


## **The sprite size equals the table size.** If they diverge, `monster_view` still draws at box size
##  (`_draw_monster_body` uses `r.size`, not the texture pixels, as the destination), so the game does not
##  break but **the sprite visibly stretches or shrinks** — that mismatch is caught here by value first.
func _sheet_fits_the_box(t, kind: int) -> void:
	var path: String = Fx.MONSTER_SHEETS[kind]
	var tex: Texture2D = load(path)
	t.ok(tex != null, "%s 시트를 읽는다 (%s)" % [Defs.name_of(kind), path])
	if tex == null:
		t.ok(false, "%s 시트를 못 읽어서 크기 계약을 하나도 못 쟀다" % Defs.name_of(kind))
		return

	t.eq(tex.get_width(), Defs.w_px(kind),
		"%s 시트 폭이 상자 폭과 같다 (%d == %d)" % [Defs.name_of(kind), tex.get_width(), Defs.w_px(kind)])
	t.eq(tex.get_height(), Defs.h_px(kind),
		"%s 시트 높이가 상자 높이와 같다 (%d == %d)" % [Defs.name_of(kind), tex.get_height(), Defs.h_px(kind)])

	# The declaration is narrowed down to the file path — same reason as `net_sprite` (an amnesty covers the whole run).
	t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % path)
	var img := Image.load_from_file(path)
	t.ok(img != null, "%s 원본 png를 연다 (임포트를 안 거친다)" % Defs.name_of(kind))
	if img == null:
		t.ok(false, "%s 원본 png를 못 읽어서 내용 검사를 하나도 못 쟀다" % Defs.name_of(kind))
		return

	# Fix the png without running the import and the game draws the stale `.ctex` while the code below measures the new png.
	t.eq(Vector2i(img.get_width(), img.get_height()), Vector2i(tex.get_width(), tex.get_height()),
		"%s 원본 png 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)" % Defs.name_of(kind))
	if img.get_width() != tex.get_width() or img.get_height() != tex.get_height():
		t.ok(false, "%s 원본과 텍스처 크기가 갈려서 내용 검사를 하나도 못 쟀다" % Defs.name_of(kind))
		return

	var w := img.get_width()
	var h := img.get_height()
	var box := NetSprite.opaque_bbox(img, 0, 0, w, h)
	t.ok(box.size.x > 0 and box.size.y > 0,
		"%s 그림에 불투명 픽셀이 있다 (bbox %s)" % [Defs.name_of(kind), box])
	if box.size.x <= 0 or box.size.y <= 0:
		return

	# **The condition for a horizontal flip to land in the same place inside the box** (same formula as `net_sprite`) —
	#  `minx + maxx == W-1` must hold or the monster jumps when it changes direction.
	var minx: int = box.position.x
	var maxx: int = box.position.x + box.size.x - 1
	t.eq(minx + maxx, w - 1,
		"%s의 minx+maxx가 %d다 (좌우 반전이 제자리에 앉는다 · %d+%d)" % [
			Defs.name_of(kind), w - 1, minx, maxx])

	# The feet touch the bottom row — the same contract as the character's grounded cells
	# (`net_sprite._cells_hold_their_contract` (3)). A monster has no airborne pose (no walk animation yet),
	# so there is no exception.
	var maxy: int = box.position.y + box.size.y - 1
	t.eq(maxy, h - 1, "%s의 발이 맨 아랫줄에 닿는다 (maxy %d)" % [Defs.name_of(kind), maxy])
