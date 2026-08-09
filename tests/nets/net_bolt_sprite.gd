extends RefCounted
## Does the bolt head sprite **match the table.** Same idiom as `net_sprite` (character) ·
## `net_monster_sprite` (monster).
##
## **Why it only exists now — the plan wrote down "this could be written and was not" and moved on.**
##  The section "the nets measure none of this change" in `bolt-head-sprite.md`
##  **named all three checks and then ended with "none of the three are written yet".**
##  => Until now the bolt head sprite had only **one measurement taken by a throwaway script**, and that
##  does not stay in the repo.
##
## **What this file cannot measure in principle: "is the sprite visible on screen".**
##  The plan left that as a measurement — the drawing code in `spell_view` is **all green under mutation**
##  (deleting the `draw_set_transform` restore in `character-sprite` still gave 1,296 passes).
##  The actual cause of acceptance 1 failing (**the glow washed out the sprite**) is caught by none of the
##  checks here.
##  => **Reading "this net is green, therefore the bolt is visible" is false.**

const Fx := preload("res://src/view/fx_tuning.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellView := preload("res://src/view/spell_view.gd")


func run(t) -> void:
	_table_covers_every_rune(t)
	for elem: int in Tuning.ELEM_ALL:
		_sheet_is_square_and_not_blank(t, elem)
	_head_diameter_follows_the_generation_table(t)
	_glow_no_longer_washes_out_the_sprite(t)
	_core_sits_at_the_center(t)
	_runes_are_told_apart_by_color(t)


## **Do the table's keys cover `ELEM_ALL` — if not, that rune's bolt turns magenta on screen.**
##
## **It is measured in both directions.** Measuring only "does every rune have a sprite" stays green while a
##  **dead row** remains in the table, and that row is the trace of a deleted rune, which the next person
##  reads as "so this rune exists".
##
## **The plan document's note that there are "only fire and none" went stale** — `ELEM_WATER` arrived in the
##  water work and there are three now. **Had this check existed, that staleness would have been caught that day.**
func _table_covers_every_rune(t) -> void:
	t.ok(Tuning.ELEM_ALL.size() > 0, "룬이 하나라도 있다 (검사의 전제)")
	for elem: int in Tuning.ELEM_ALL:
		t.ok(Fx.BOLT_SHEETS.has(elem),
			"룬 %d 에 탄 머리 그림이 있다 (없으면 화면에서 마젠타로 비명을 지른다)" % elem)
	for elem: int in Fx.BOLT_SHEETS:
		t.ok(Tuning.ELEM_ALL.has(elem),
			"표의 룬 %d 가 `ELEM_ALL` 에 실재한다 (죽은 줄이 아니다)" % elem)


## **It is 16x16 and it is not entirely blank.**
##
## **"Is it not blank" is the most valuable line in this file.** `character-sprite` actually found the hole
##  where **an entirely transparent sheet was green** — measuring size alone lets an **all-black png** pass.
##  And the bolt uses **additive blending** (`BLEND_MODE_ADD` in `spell_view._ready`), so **black is transparent**
##   => alpha must not be measured, **brightness** must be. This is where it parts from the character and
##   monster side.
##
## **`Image.load_from_file` opens the png on disk directly** — `load()` goes through the import and becomes a
##  compressed texture, and then the pixels cannot be read (same reason as `net_sprite`).
func _sheet_is_square_and_not_blank(t, elem: int) -> void:
	if not Fx.BOLT_SHEETS.has(elem):
		return   # the check above is already red. Barking again here counts the same fault twice
	var path: String = Fx.BOLT_SHEETS[elem]

	var tex: Texture2D = load(path)
	t.ok(tex != null, "룬 %d 의 그림이 읽힌다 (%s)" % [elem, path.get_file()])
	if tex == null:
		return

	# **The size comes from `bolt_px` — 16 is not hardcoded.** Change the table and the sprite must follow.
	var want := int(Fx.bolt_px(0) * 2.0)
	t.eq(tex.get_width(), want,
		"룬 %d 의 그림 폭이 세대0 지름(%d)과 같다" % [elem, want])
	t.eq(tex.get_height(), want, "룬 %d 의 그림이 정사각이다" % elem)

	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	t.ok(img != null, "룬 %d 의 png 를 디스크에서 직접 연다" % elem)
	if img == null:
		return

	# **Bright pixels are counted.** With additive blending a dark pixel adds nothing to the screen =>
	#  "there is alpha" cannot filter out an **all-black sprite**.
	var bright := 0
	var peak := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v: float = maxf(c.r, maxf(c.g, c.b)) * c.a
			peak = maxf(peak, v)
			if v > 0.25:
				bright += 1
	t.ok(bright > 0,
		"룬 %d 의 그림에 밝은 픽셀이 있다 (%d개 — 통째로 검정/투명이 아니다)" % [elem, bright])
	t.ok(peak > 0.9,
		"룬 %d 의 그림에 거의 흰 픽셀이 있다 (최대 밝기 %.2f — 코어가 산다)" % [elem, peak])
	# **The other side**: an all-white square is not a "sprite" either. The plan cut the glow on the grounds
	#  that "a bright core -> dark edge gradient is already in there, so it is a light by itself", so
	#  **whether that gradient really exists** is left here as a value.
	t.ok(bright < img.get_width() * img.get_height(),
		"룬 %d 의 그림이 **꽉 찬 사각형이 아니다** (밝은 픽셀 %d / %d)"
			% [elem, bright, img.get_width() * img.get_height()])


## **The drawn diameter comes from the generation table — the sprite size is not a hardcoded constant.**
##  If they diverge it becomes **"the generation shrank but only the sprite stayed"** and **no error is raised**
##   (the comment on `spell_view._draw_head` names that trap).
## **Whether the generation actually shrinks is measured along with it** — flatten the table (both 8.0) and
##  "the diameter comes from the table" is still true but **"size carries the generation" dies.**
func _head_diameter_follows_the_generation_table(t) -> void:
	var g0 := Fx.bolt_px(0)
	var g1 := Fx.bolt_px(1)
	t.ok(g0 > g1, "세대1 머리가 세대0보다 작다 (%.1f > %.1f) — 크기가 세대를 나른다" % [g0, g1])
	t.eq(g1 * 2.0, g0, "세대1이 정확히 절반이다 (그림이 짝수 배율로 줄어 안 뭉개진다)")
	# The source sprite and generation 0 must be 1:1 so that **the original shows as-is on the biggest bolt.**
	for elem: int in Tuning.ELEM_ALL:
		if not Fx.BOLT_SHEETS.has(elem):
			continue
		var tex: Texture2D = load(Fx.BOLT_SHEETS[elem])
		if tex != null:
			t.eq(float(tex.get_width()), g0 * 2.0,
				"룬 %d 는 세대0에서 원본과 1:1이다 (확대도 축소도 없다)" % elem)


## **Does the halo (glow) avoid washing out the sprite — only the half that can be measured by value.**
##
## **This is where acceptance 1 failed** (user: "the light follows it so I can't see it").
##  **"Is it visible" is the eye's job in principle.** What is measured here is only **"is that value still the
##  one from the circle era".**
##  => Revert to 0.45 and this check goes red, so **the story gets read again.**
## **This is not evidence that 0.12 is right** — it is a value the user chose and **nobody has looked at the
##  screen again yet.**
func _glow_no_longer_washes_out_the_sprite(t) -> void:
	t.ok(Fx.BOLT_GLOW_A < 0.2,
		"무리 알파가 원 시절 값(0.45)에서 크게 내려왔다 (%.2f)" % Fx.BOLT_GLOW_A)
	t.ok(Fx.BOLT_GLOW_A > 0.0,
		"그래도 0은 아니다 — 세대1(8px)이 검은 배경에 묻히지 않게 받쳐 준다")


## **Acceptance 2 — is the head offset from the real position. The half that can be measured by value.**
##
## `spell_view._draw_head` draws the sprite into **a square centered on the head coordinate** => **if the core
## is off-center inside the sprite, it is offset by exactly that much.** The sim is right and the eye is wrong,
## the kind that raises no error.
## That is why `tools/pixel/crop_head.py` crops with **the core centered by brightness-squared centroid**, and
##  **nobody was measuring whether that tool actually did its job.**
##
## **1px is not demanded** — the crop is in whole pixels so half a pixel remains in principle.
##  Measured: fire **1.49px** · none 0.59 · water 0.89. The line is drawn at 15% of the width (2.4px at 16px).
## **Why 15%**: generation 1 has a half-size sprite (8px), so the same ratio becomes **0.75px** — cross this
##  line and "the bolt looks pushed one cell off its direction of travel" can begin at generation 1.
func _core_sits_at_the_center(t) -> void:
	for elem: int in Tuning.ELEM_ALL:
		if not Fx.BOLT_SHEETS.has(elem):
			continue
		var img := Image.load_from_file(
			ProjectSettings.globalize_path(Fx.BOLT_SHEETS[elem]))
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var sw := 0.0
		var sx := 0.0
		var sy := 0.0
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				# It is the **square** of brightness — the same weight as `crop_head.py`, or it measures
				#  something else. Weighted linearly, the dark edges take a share and pull the center inward.
				var v: float = maxf(c.r, maxf(c.g, c.b))
				var wgt := v * v
				sw += wgt
				sx += wgt * (float(x) + 0.5)
				sy += wgt * (float(y) + 0.5)
		if sw <= 0.0:
			continue      # the "is it not blank" check above is already red
		var off := Vector2(sx / sw - w * 0.5, sy / sw - h * 0.5)
		t.ok(absf(off.x) < w * 0.15 and absf(off.y) < h * 0.15,
			"룬 %d 의 코어가 중앙에 있다 (%+.2f, %+.2f)px — 그림 폭의 15%% 안" % [elem, off.x, off.y])


## **Acceptance 4 — are the runes told apart on screen. The half that can be measured by color.**
##
## **It is not "is it visible" but "is the color different".** Whether the eye tells them apart is still a
##  person's job, and what is blocked here is only **"two runes' sprites becoming effectively the same color"** —
##  it happens quietly as runes are added, and then the player **cannot read off the screen which spell they fired.**
##
## **The background is excluded from the mean.** With additive blending **black = transparent**, and including
##  it converges all three to grey and yields "the distance is near 0" — the label says "the colors are the same"
##  while what was actually measured is "the backgrounds are the same".
##
## Measured: fire (saturation 0.92 orange) · none (**saturation 0.03, achromatic**) · water (saturation 0.92 sky).
##  Distances are 0.64-1.29. The line is drawn at 0.3.
## **None's saturation of 0.03 is exactly the spot the plan warned about** — its color axis overlaps the grey of
##  "cannot fire". **This check cannot catch that problem**, because the runes are told apart from each other.
##  The story is in `circle-rune-glyph.md`.
func _runes_are_told_apart_by_color(t) -> void:
	var means := {}
	for elem: int in Tuning.ELEM_ALL:
		if not Fx.BOLT_SHEETS.has(elem):
			continue
		var img := Image.load_from_file(
			ProjectSettings.globalize_path(Fx.BOLT_SHEETS[elem]))
		if img == null:
			continue
		var sum := Vector3.ZERO
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if maxf(c.r, maxf(c.g, c.b)) < 0.1:
					continue
				sum += Vector3(c.r, c.g, c.b)
				n += 1
		if n > 0:
			means[elem] = sum / float(n)
	t.ok(means.size() >= 2, "색을 맞댈 룬이 둘 이상이다 (검사의 전제)")
	var keys: Array = means.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Vector3 = means[keys[i]]
			var b: Vector3 = means[keys[j]]
			t.ok((a - b).length() > 0.3,
				"룬 %d 와 %d 가 색으로 갈린다 (거리 %.2f)" % [keys[i], keys[j], (a - b).length()])
