extends RefCounted
## Does the character sprite **match the box.** "Does it read as a wizard" cannot be measured in principle —
## what is measured here is only the **size contract** and the **placement contract**. The rest is for the eye
## (plan 7.2).
##
## **Why size is a contract.** The GDD pins down that "making the character and the tile the same thickness is
##  the device that makes power tiers visible — you can **count** off the screen that breaking through that wall
##  lets you pass."
##  If the sprite were 32x48 (the head sticking out above), **"the head is stuck in the wall but it passes through"**
##   appears, and at that moment "you can tell by counting" becomes false. **No error at all is raised; it only
##   shows in a screenshot.**
##
## **The texture (`load`) cannot measure the sprite's content — the original png is opened separately.**
##  `Image.load_from_file` skips the import, reads the png on disk directly, and **runs headless**
##  (measured by verify-read). So this net is valid **only in the source tree** — an exported build has no
##  original png. The nets only run from source, so that is not a problem.
##
## **This is the one path by which a png is caught by a net in this repo.** `.godot/` is a `.gitignore` target
##  so the baked `.ctex` is not committed => on a new machine `--import` has to run once.
##  Without it the first line below **goes red** (it does not vanish quietly).

const Fx := preload("res://src/view/fx_tuning.gd")
const Character := preload("res://src/actor/character.gd")
## The staff sprite's width contract is `Staff.LEN_PX` — "the visible tip" and "the firing origin" must be the same value.
const Staff := preload("res://src/actor/staff.gd")
## **`pick_state()` is purely static so it can be called without a scene** — that is what let acceptances 3 and 4
##  move into the nets. No instance is made (it is a `Node2D`, so making one would need a tree).
const CharacterView := preload("res://src/view/character_view.gd")


func run(t) -> void:
	_body_sheet_fits_the_box(t)
	_staff_sheet_fits_the_reach(t)
	_pick_state_picks_different_cells(t)


## **The staff sprite contract — "the visible tip" and `Staff.tip_px()` must be the same place.**
##  A few px of divergence **only surfaces in a screenshot** (magic that does not leave the tip of the sprite).
##
## **18 of the 24 candidates were rejected right here.** Two failures were common:
##  · **a 4-5px break between the ring and the shaft** — it happened even among ones from the same prompt
##  · **the bbox falls short of the width** (x 0-32 and the like)
##  => **When swapping the sprite, the net bites instead of a person remembering.**
func _staff_sheet_fits_the_reach(t) -> void:
	var tex: Texture2D = load(Fx.STAFF_SHEET)
	t.ok(tex != null, "지팡이 시트를 읽는다 (%s)" % Fx.STAFF_SHEET)
	if tex == null:
		# A bare `return` makes the check **disappear** rather than "fail" (same device as the body sheet above).
		t.ok(false, "지팡이 시트를 못 읽어서 그림 계약을 **하나도 못 쟀다**")
		return

	# **The width is the reach.** Diverge from `Staff.LEN_PX` and "the visible tip" and "the firing origin"
	#  come apart **with no error.** The day the length is changed by eye, the png has to change with it.
	t.eq(float(tex.get_width()), Staff.LEN_PX,
		"지팡이 시트 폭이 지팡이 길이와 같다 (%d == %.0f)" % [tex.get_width(), Staff.LEN_PX])

	# The declaration is **narrowed down to the file path** — written wide, a real silent death is amnestied along with it.
	t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % Fx.STAFF_SHEET)
	var img := Image.load_from_file(Fx.STAFF_SHEET)
	t.ok(img != null, "지팡이 원본 png를 연다 (임포트를 안 거친다)")
	if img == null:
		t.ok(false, "원본 png를 못 읽어서 **내용 검사를 하나도 못 쟀다**")
		return
	# Fix the png without running the import and the game draws the **stale `.ctex`** while the code below
	#  measures the **new png**.
	t.eq(Vector2i(img.get_width(), img.get_height()),
		Vector2i(tex.get_width(), tex.get_height()),
		"원본 png 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)")
	if img.get_width() != tex.get_width() or img.get_height() != tex.get_height():
		t.ok(false, "원본과 텍스처의 크기가 갈려서 **내용 검사를 하나도 못 쟀다**")
		return

	var w := img.get_width()
	var h := img.get_height()
	var box := opaque_bbox(img, 0, 0, w, h)
	t.ok(box.size.x > 0 and box.size.y > 0, "지팡이 그림에 불투명 픽셀이 있다 (bbox %s)" % box)
	if box.size.x <= 0 or box.size.y <= 0:
		return

	# **The bbox fills the width.** If the rightmost column is transparent the visible tip is at `width-1`
	#  while `tip_px()` says `width`, so **the tip floats outside the sprite.**
	t.eq(Vector2i(box.position.x, box.position.x + box.size.x - 1), Vector2i(0, w - 1),
		"bbox가 폭을 꽉 채운다 (x 0~%d)" % (w - 1))

	# **Zero broken columns — the staff is not in two pieces.**
	var gaps := 0
	for x in w:
		if opaque_bbox(img, x, 0, 1, h).size.y <= 0:
			gaps += 1
	t.eq(gaps, 0, "끊긴 열이 0개다 (봉과 고리가 이어져 있다)")

	# **The bbox's y center is the anchor.** Off here and the staff floats above the shoulder **only when facing
	#  left** (rotated 180 degrees) — looking at the right side alone can never catch it.
	var cy := (float(box.position.y) + float(box.position.y + box.size.y - 1)) * 0.5
	t.ok(is_equal_approx(cy, Fx.STAFF_ANCHOR_Y_PX),
		"bbox의 y 중심이 앵커와 같다 (%.1f == %.1f · y %d~%d)" % [
			cy, Fx.STAFF_ANCHOR_Y_PX, box.position.y, box.position.y + box.size.y - 1])

	# The width the ring occupies has to be inside the sprite for the shaft region (`LEN_PX - ring`) to be positive.
	t.ok(Fx.STAFF_RING_W_PX > 0.0 and Fx.STAFF_RING_W_PX < Staff.LEN_PX,
		"고리 폭 %.0f 가 0과 전장 %.0f 사이다" % [Fx.STAFF_RING_W_PX, Staff.LEN_PX])


func _body_sheet_fits_the_box(t) -> void:
	var tex: Texture2D = load(Fx.CHAR_SHEET)
	t.ok(tex != null, "몸 시트를 읽는다 (%s)" % Fx.CHAR_SHEET)
	if tex == null:
		# **A bare `return` here makes the check vanish entirely rather than "fail"** —
		#  only the pass count drops and nobody barks. In the log a "vanished check" is indistinguishable from a passed one.
		t.ok(false, "몸 시트를 못 읽어서 크기 계약을 **하나도 못 쟀다**")
		return

	var w := tex.get_width()
	var h := tex.get_height()
	# **Everything here is the "sprite" contract, so the reference is `Fx.CHAR_CELL_PX` — not `Character.W_PX`.**
	#  The two split apart (box 20 · sprite cell 32). Before that, `W_PX` alone carried both meanings, and had it
	#  stayed that way this check would count the sheet **in units of 20px**, arrive at "9.6 cells", and spin idle end to end.
	t.eq(h, Fx.CHAR_CELL_PX, "몸 시트 높이가 그림 칸과 같다 (%dpx)" % Fx.CHAR_CELL_PX)
	# The width is cell count x cell width. Not a multiple and the last cell is drawn clipped, **with no error.**
	t.ok(w > 0 and w % Fx.CHAR_CELL_PX == 0,
		"몸 시트 폭 %d 이 그림 칸 %d 의 배수다" % [w, Fx.CHAR_CELL_PX])
	if w <= 0 or w % Fx.CHAR_CELL_PX != 0:
		t.ok(false, "시트 폭이 배수가 아니라 칸 수를 못 세고 **내용 검사를 하나도 못 쟀다**")
		return

	# **The cell count is not a constant** — it comes from the sheet (the same rule as that comment in `fx_tuning`).
	#  Hardcode it in a third place and the day those three diverge the net **takes the wrong side.**
	var cells := w / Fx.CHAR_CELL_PX
	t.ok(cells > 0, "몸 시트에 칸이 있다 (%d칸)" % cells)

	_cells_hold_their_contract(t, w, h, cells)
	_table_stays_inside_the_sheet(t, cells)


## **Even an entirely transparent cell leaves every check above green** — verify-read measured it on the 16px sheet:
##  swapping in a transparent sheet left **the nets green and stderr clean.** The character disappears from the
##  screen and nobody barks. => **`null` was blocked and "an empty sprite" was wide open.**
##
## **It is written per cell.** There is one cell now, but at stage 3 there will be six, and then "only one cell
##  was not drawn" and "only one cell is misaligned" are exactly the shape that leaks quietly.
func _cells_hold_their_contract(t, w: int, h: int, cells: int) -> void:
	# The engine barks "this will not work on export". **That bark is legitimate** — the nets run only in the
	# source tree, and the side the game draws is the imported `.ctex` (`load()`), so exporting is unaffected.
	# **The declaration is narrowed down to the file path.** Written wide, a real silent death is amnestied along with it —
	#  and an amnesty covers **the whole run, not one net** (the runner collects every `[EXPECT]` from stdout).
	t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % Fx.CHAR_SHEET)
	var img := Image.load_from_file(Fx.CHAR_SHEET)
	t.ok(img != null, "몸 시트 원본 png를 연다 (임포트를 안 거친다)")
	if img == null:
		t.ok(false, "원본 png를 못 읽어서 **내용 검사를 하나도 못 쟀다**")
		return

	# **Whether the original and the imported texture are the same picture is looked at first.** Fix the png
	#  without running the import and the game draws the **stale `.ctex`** while this function measures the
	#  **new png** => the green below becomes unrelated to the screen.
	#  The case where the size was also made to match cannot be caught. Still, "the cell count grew but the
	#  screen did not" is bitten here.
	t.eq(Vector2i(img.get_width(), img.get_height()), Vector2i(w, h),
		"원본 png 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)")
	if img.get_width() != w or img.get_height() != h:
		t.ok(false, "원본과 텍스처의 크기가 갈려서 **내용 검사를 하나도 못 쟀다**")
		return

	# **The airborne cells are pulled from the table.** Writing the numbers by hand makes a second copy alongside `fx_tuning`.
	var airborne := _airborne_cells()
	# If the list is empty the exception below never triggers, and then the label "grounded cells only" is false.
	t.ok(airborne.size() > 0, "공중 칸이 표에서 나온다 (%d칸 — 발 검사의 예외다)" % airborne.size())

	# Only the cells that **stand** against a wall (`Fx.CHAR_UPRIGHT`) are collected — "the box is not wider than
	# the sprite" below is measured with this. **These are not the grounded cells**: "grounded" in (3) below
	#  includes downed, and downed is a sprite lying sideways (width 28), so mixing it in lets the box widen to 28 and still pass.
	var upright := _upright_cells()
	t.ok(upright.size() > 0, "서는 칸이 표에서 나온다 (%d칸 — 상자 폭 검사의 기준이다)" % upright.size())
	var widest_upright := 0
	for cell in cells:
		var box := opaque_bbox(img, cell * Fx.CHAR_CELL_PX, 0, Fx.CHAR_CELL_PX, Fx.CHAR_CELL_PX)
		# (1) It is not an empty cell.
		t.ok(box.size.x > 0 and box.size.y > 0,
			"칸 %d 에 불투명 픽셀이 있다 (bbox %s)" % [cell, box])
		if box.size.x <= 0 or box.size.y <= 0:
			continue

		# (2) **The condition for a horizontal flip to land in the same place inside the box.**
		#  Flipping about the box sends x to `W-1-x` => for the content to land in place,
		#  **`minx + maxx == W-1`** must hold. One column off and **the character jumps 1px when it turns.**
		#  It is nearly invisible on screen and nobody but a net catches it — the earlier version of this png
		#   was actually `7+23 = 30`, one px short (plan 3.1).
		#  If this assertion holds, **an even content width follows from it** — one line catches two things.
		var minx: int = box.position.x
		var maxx: int = box.position.x + box.size.x - 1
		t.eq(minx + maxx, Fx.CHAR_CELL_PX - 1,
			"칸 %d 의 minx+maxx 가 %d 이다 (좌우 반전이 제자리에 앉는다 · %d+%d)" % [
				cell, Fx.CHAR_CELL_PX - 1, minx, maxx])

		# (3) **Only grounded cells have their feet touching the bottom row.** Not touching makes the character
		#  **float above the terrain**, and differing per cell makes it **jump up and down** when the state changes.
		#  The box is unchanged and only the sprite floats, so no behavior check catches it at all.
		#
		# **Jump and fall are exceptions. They were not overlooked.** They are **airborne poses** with the legs
		#  tucked, so the feet are not at the bottom, and forcing them down to the bottom row **stretches the
		#  character vertically** (measured: jump maxy 28 · fall 29).
		#  **Do not widen it again** — widening means fixing the sprite, and that "fix" is precisely the stretched character.
		#  The exception list comes from `Fx.CHAR_AIRBORNE` **and nowhere else.** Write a state name here again and
		#   there are two places, and the day airborne poses are added only one of them follows.
		if upright.has(cell):
			widest_upright = maxi(widest_upright, int(box.size.x))
		if airborne.has(cell):
			continue
		var maxy: int = box.position.y + box.size.y - 1
		t.eq(maxy, Fx.CHAR_CELL_PX - 1,
			"접지 칸 %d 의 발이 맨 아랫줄에 닿는다 (maxy %d)" % [cell, maxy])

	# **If the collision box is wider than the sprite, the character stops before touching the wall.**
	#  The user saw that and called it "a hit registered before touching the wall", which is why
	#  `Character.W_PX` went 32 -> 20. **This one assertion is what protects that fix** —
	#  without it, anyone reverting `W_PX` to 32 leaves the nets all green (they were green before the fix too).
	#
	# **With "grounded cells" as the reference this check goes slack — measured by inversion.**
	#  It first measured grounded (= non-airborne) cells, and then the **downed cell (width 28)** became the
	#  maximum, so while "box 32 <= 28" did go red, **widening the box to 28 passed.**
	#  => The reference is **the cells that stand against a wall** (`Fx.CHAR_UPRIGHT`) and their current max is walking (20).
	#  The label said "downed is excluded" while not excluding it — CLAUDE.md's "the label is wider than what it measures".
	#
	#  **No slack is given (`<=`)** — the moment "we allow a few px" goes in, that number becomes a second
	#   groundless knob, and the next person raises it and brings the symptom back.
	t.ok(widest_upright > 0, "서는 칸에서 내용 폭을 쟀다 (%dpx — 검사의 전제)" % widest_upright)
	t.ok(Character.W_PX <= widest_upright,
		"충돌 상자가 서는 칸 그림보다 넓지 않다 (상자 %d ≤ 제일 넓은 서는 칸 %d)" % [
			Character.W_PX, widest_upright])


## The set of **cell numbers** used by the states in `Fx.CHAR_AIRBORNE`.
static func _airborne_cells() -> Dictionary:
	var out: Dictionary = {}
	for state: int in Fx.CHAR_AIRBORNE:
		for cell: int in Fx.CHAR_FRAMES.get(state, []):
			out[cell] = true
	return out


## The cells that **stand** against a wall. **The same shape as `_airborne_cells` above but not its complement** —
##  downed belongs to neither (it is not airborne and it is not standing).
##  The list comes from `Fx.CHAR_UPRIGHT` alone. Write a state name here and there are two copies.
static func _upright_cells() -> Dictionary:
	var out: Dictionary = {}
	for state: int in Fx.CHAR_UPRIGHT:
		for cell: int in Fx.CHAR_FRAMES.get(state, []):
			out[cell] = true
	return out


## If a table's cell number falls outside the sheet, the screen **draws the wrong cell with no error.**
func _table_stays_inside_the_sheet(t, cells: int) -> void:
	# If the table is empty the loop below never runs and **it goes green.** Same reason as the first line of a folder-scanning net.
	t.ok(Fx.CHAR_FRAMES.size() > 0, "상태 → 칸 표가 비어 있지 않다 (%d줄)" % Fx.CHAR_FRAMES.size())
	for state: int in Fx.CHAR_FRAMES.keys():
		var frames: Variant = Fx.CHAR_FRAMES[state]
		t.ok(frames is Array, "상태 %d 의 칸 목록이 배열이다" % state)
		if not (frames is Array):
			continue
		# An empty list means **there is no cell to draw**, but the consumer indexes `[0]` — it dies at runtime.
		t.ok((frames as Array).size() > 0, "상태 %d 에 칸이 하나라도 있다" % state)
		for cell: int in (frames as Array):
			t.ok(cell >= 0 and cell < cells,
				"상태 %d 의 칸 %d 이 시트 안이다 (0~%d)" % [state, cell, cells - 1])

	# **No missing cells and no spare cells.** A cell not listed in the table is **a sprite nobody draws**
	#  (it only makes the sheet heavier), and two states sharing a cell means **those two are indistinguishable
	#  on screen** — the spot where acceptances 3 and 4 quietly die.
	var used: Dictionary = {}
	var overlap := 0
	for state: int in Fx.CHAR_FRAMES.keys():
		for cell: int in Fx.CHAR_FRAMES[state]:
			if used.has(cell):
				overlap += 1
			used[cell] = true
	t.eq(overlap, 0, "두 상태가 같은 칸을 안 쓴다")
	t.eq(used.size(), cells, "표가 쓰는 칸 수와 시트의 칸 수가 같다 (빠진 칸도 남는 칸도 없다)")


## **This is where acceptance 3 (walk/jump/fall told apart) and 4 (downed) move from the eye into the nets.**
##  `pick_state()` is **purely static**, so combinations can be fed in and cells read back with no scene and no character.
##
## **But what is measured here is only "the code picks a different cell".**
##  **Drawing all six cells identically still leaves this check green** — "the sprites in those cells really
##  differ" is measured by the eye alone in principle (plan 7.2). Do not widen the label that far.
func _pick_state_picks_different_cells(t) -> void:
	# [downed, grounded, vy, moving] -> expected state
	var cases: Array[Array] = [
		[true, true, 0.0, false, Fx.CHAR_DOWNED, "쓰러짐"],
		[true, false, -100.0, true, Fx.CHAR_DOWNED, "쓰러진 채 공중이어도 쓰러짐이 이긴다"],
		[false, false, -100.0, false, Fx.CHAR_JUMP, "올라가는 중"],
		[false, false, 100.0, true, Fx.CHAR_FALL, "떨어지는 중"],
		[false, true, 0.0, true, Fx.CHAR_WALK, "걷는 중"],
		[false, true, 0.0, false, Fx.CHAR_STAND, "서기"],
	]
	# If the list is empty the code below never runs and **it goes green.**
	t.ok(cases.size() > 0, "조합이 %d개다" % cases.size())

	var seen: Dictionary = {}
	for c: Array in cases:
		var got: int = CharacterView.pick_state(c[0], c[1], float(c[2]), c[3])
		t.eq(got, int(c[4]), "%s → 상태 %d" % [c[5], int(c[4])])
		seen[got] = true

	# **Does each combination yield a different state.** With only the `t.eq` above, `pick_state` always
	#  returning the same value would still pass as long as the expected values were written as that value —
	#  **"they differ from each other"** is measured separately.
	#  Two of the six combinations are deliberately the same state (downed), so there are five distinct states.
	t.eq(seen.size(), Fx.CHAR_FRAMES.size(),
		"조합이 표의 상태 %d개를 전부 고른다 (하나도 도달 불가가 아니다)" % Fx.CHAR_FRAMES.size())


## The rectangle **the opaque pixels actually occupy** within a region (region-local coordinates). Size 0 for an empty region.
##
## **Stage 4 uses this function as-is.** Item 7 of plan 7.1 is the same shape —
##  "even if the staff png is 36 wide, **if the rightmost column is transparent** the visible tip is at 35px
##  while `tip_px()` says 36px, so the muzzle floats outside the sprite". That is measuring `box.end.x == width`
##  with this bbox.
static func opaque_bbox(img: Image, ox: int, oy: int, w: int, h: int) -> Rect2i:
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			# It is written as filtering out `<= 0.0` rather than testing `> 0.0` — even one semi-transparent pixel counts as "drawn".
			if img.get_pixel(ox + x, oy + y).a <= 0.0:
				continue
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
