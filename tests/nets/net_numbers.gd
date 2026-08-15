extends RefCounted
## **The constants themselves, literal to literal.** Nothing here drives the game; every other net does
## that. This one exists because of a shape those nets cannot escape on their own: a check that asserts the
## painted colour equals `Look.CROW_COLOR` moves BOTH sides when the constant moves, so
## `CROW_COLOR → Color(0, 0, 0, 0)` left crows invisible on the field AND on the minimap with the whole
## round green. Nineteen of `look.gd`'s colours were free that way, and four `rules.gd` tables were
## referenced by no check at all.
##
## ⚠ **The colours are NOT pinned to literal RGB, and that is deliberate.** Art in this repo is decided by
## generating candidates and pointing at one (CLAUDE.md), so a literal pin would make every future art
## decision a test edit and the test edit would be made without thinking. What is pinned instead is the
## PROPERTY `look.gd`'s own header claims and nothing measured: **every colour drawn on the field clears a
## contrast floor against `BG`**. A placeholder swapped for real art stays green; a colour that has become
## invisible does not.
##
## `net_hunt._c7_the_speed_ordering` is the shape the `rules.gd` half copies — the round's exemplar for a
## table nothing drives.

## WCAG relative-luminance contrast, and the floor is the DIMMEST colour already accepted on screen.
## ⚠ **3.9, not 4.0, and the 0.1 is a correction rather than slack.** `look.gd` claimed "none sits under
## 4.0:1" with `CROW_COLOR` named as the floor; measured here it is **3.99:1**. The doc is corrected with
## this file, and the floor is written just under the real number so the claim and the check agree.
const FIELD_FLOOR := 3.9
## The two screens are darker than the field and their dim pair is dim on purpose — 도감 and 설정 have to
## read as coming, not broken, which is a lower bar than a creature you have to see coming.
const SCREEN_FLOOR := 3.0
const DIM_ON_PURPOSE_FLOOR := 2.5
## Anything drawn as a wash over what is underneath. Below this the overlay is not there at all.
const OVERLAY_ALPHA_MIN := 0.2


func run(t) -> void:
	_l1_every_field_colour_clears_the_floor(t)
	_l2_the_washes_are_actually_there(t)
	_l3_the_screens_read(t)
	_l4_the_sizes_no_other_check_pins(t)
	_l5_the_floor_colour_is_the_engines(t)
	_r1_the_three_species_table(t)
	_r2_the_ground_and_the_water(t)
	_r3_the_boss_clock(t)
	_r4_the_opening_field_fits_the_cap(t)
	_x_the_instrument(t)


# -- L1: every colour on the field is visible ON the field ------------------------------------------------
## One loop over one hand-written table, which is the whole point: closing nineteen constants one assertion
## at a time is how eighteen of them get closed and the nineteenth does not.
##
## *Mutations this must redden:* any of these to `Color(0, 0, 0, 0)`; any of them to `Look.BG`; the alpha of
## any of them to 0.
func _l1_every_field_colour_clears_the_floor(t) -> void:
	var palette := {
		"HOST_COLOR": Look.HOST_COLOR,
		"HOST_HURT_COLOR": Look.HOST_HURT_COLOR,
		"CLONE_COLOR": Look.CLONE_COLOR,
		"CLONE_LOADED_COLOR": Look.CLONE_LOADED_COLOR,
		"FOOD_COLOR": Look.FOOD_COLOR,
		"CROW_COLOR": Look.CROW_COLOR,
		"HORSE_COLOR": Look.HORSE_COLOR,
		"BOSS_COLOR": Look.BOSS_COLOR,
		"ROCK_COLOR": Look.ROCK_COLOR,
		"WATER_COLOR": Look.WATER_COLOR,
		"CORPSE_COLOR": Look.CORPSE_COLOR,
		"FORCE_LABEL_COLOR": Look.FORCE_LABEL_COLOR,
		"HUD_TEXT": Look.HUD_TEXT,
		"HUD_DIM_TEXT": Look.HUD_DIM_TEXT,
		"HUD_CARRY_COLOR": Look.HUD_CARRY_COLOR,
		"HUD_HP_COLOR": Look.HUD_HP_COLOR,
		"HUD_BAR_FILL": Look.HUD_BAR_FILL,
	}
	# Hand-written, not `palette.size()` read back: an emptied table would run zero assertions and read
	# exactly like a clean palette.
	t.eq(palette.size(), 17, "바닥 위에 그려지는 불투명한 색은 열일곱이다")
	for name: String in palette:
		var col: Color = palette[name]
		t.ok(col.a == 1.0, "%s는 불투명하다 (a %.2f) — 알파 0은 안 그린 것과 같다" % [name, col.a])
		var cr := _contrast(col, Look.BG)
		t.ok(cr >= FIELD_FLOOR,
				"%s는 바닥색에서 %.2f:1 떨어져 있다 — %.1f:1이 바닥이다" % [name, cr, FIELD_FLOOR])

	# The eyes are drawn ON the body, not on the ground, so their floor is the host's own colour.
	t.ok(_contrast(Look.EYE_DOT_COLOR, Look.HOST_COLOR) >= FIELD_FLOOR,
			"눈 점은 바닥이 아니라 몸 위에 찍힌다 — 호스트 색에서 %.2f:1 떨어져 있다"
					% _contrast(Look.EYE_DOT_COLOR, Look.HOST_COLOR))

	# **The floor is a real number and it is CROW_COLOR.** Without this line the loop above passes on a
	# palette where everything is white, and "the dimmest thing already accepted" would be a sentence in a
	# comment rather than a measurement.
	var crow := _contrast(Look.CROW_COLOR, Look.BG)
	t.ok(crow < 4.1 and crow >= FIELD_FLOOR,
			"그리고 그 바닥은 까마귀 자신이다 — 3.99:1 (%.3f)" % crow)


# -- L2: a wash that is not there is not a wash -----------------------------------------------------------
## These are drawn OVER something, so contrast against `BG` says nothing about them; what says something is
## that they have an alpha at all. `MINIMAP_BG` is deliberately black — it darkens the map's own rectangle —
## so it is in this list and not in L1's.
func _l2_the_washes_are_actually_there(t) -> void:
	var washes := {
		"CORPSE_PROGRESS_COLOR": Look.CORPSE_PROGRESS_COLOR,
		"STRIKE_COLOR": Look.STRIKE_COLOR,
		"SPLIT_CHARGE_COLOR": Look.SPLIT_CHARGE_COLOR,
		"BITE_COLOR": Look.BITE_COLOR,
		"MINIMAP_BG": Look.MINIMAP_BG,
		"MINIMAP_FRAME": Look.MINIMAP_FRAME,
		"MINIMAP_CAMERA_COLOR": Look.MINIMAP_CAMERA_COLOR,
		"HUD_BAR_BG": Look.HUD_BAR_BG,
		"ENDING_DIM": Look.ENDING_DIM,
		"BODY_DIM": Look.BODY_DIM,
		"CARD_DIM": Look.CARD_DIM,
		"CELL_SHADOW": Look.CELL_SHADOW,
	}
	t.eq(washes.size(), 12, "무언가 위에 덮이는 색은 열둘이다")
	for name: String in washes:
		var col: Color = washes[name]
		t.ok(col.a >= OVERLAY_ALPHA_MIN and col.a <= 1.0,
				"%s의 알파는 %.2f다 — %.1f 밑이면 안 덮은 것과 같다" % [name, col.a, OVERLAY_ALPHA_MIN])
	# The three that are drawn on the FIELD and must also be seen against it. The minimap's three are drawn
	# on the map's own black background and are excluded by construction, not by omission.
	for pair in [["CORPSE_PROGRESS_COLOR", Look.CORPSE_PROGRESS_COLOR],
			["SPLIT_CHARGE_COLOR", Look.SPLIT_CHARGE_COLOR], ["BITE_COLOR", Look.BITE_COLOR]]:
		var cr := _contrast(Color(pair[1].r, pair[1].g, pair[1].b), Look.BG)
		t.ok(cr >= FIELD_FLOOR,
				"%s의 색조는 바닥에서 %.2f:1 떨어져 있다 — 알파만 있고 색이 바닥이면 안 보인다"
						% [pair[0], cr])


# -- L3: the two screens ----------------------------------------------------------------------------------
func _l3_the_screens_read(t) -> void:
	for pair in [["SCREEN_TEXT", Look.SCREEN_TEXT], ["ENDING_CLEARED", Look.ENDING_CLEARED],
			["ENDING_DIED", Look.ENDING_DIED], ["BUTTON_EDGE", Look.BUTTON_EDGE]]:
		var cr := _contrast(pair[1], Look.TITLE_BG)
		t.ok(cr >= SCREEN_FLOOR, "%s는 타이틀 바닥에서 %.2f:1이다" % [pair[0], cr])
	# **The greyed pair is dim on purpose and it still has to be legible.** 도감/설정 reading as broken
	# rather than as coming is the failure at the other end.
	var off := _contrast(Look.BUTTON_TEXT_OFF, Look.BUTTON_BG_OFF)
	t.ok(off >= DIM_ON_PURPOSE_FLOOR and off < SCREEN_FLOOR + 1.0,
			"꺼진 버튼 글씨는 일부러 흐리지만 %.2f:1은 남는다 — 고장이 아니라 예정이라고 읽혀야 한다" % off)
	_l3b_the_two_yellows_are_not_one_constant(t)


# -- L3b: two declarations, not an alias -------------------------------------------------------------------
## ⚠ **This check used to be `Look.BUTTON_EDGE != Look.ENDING_CLEARED or true`, which is true whatever
## either constant holds** — a fake net by CLAUDE.md's definition: the label claimed the two are separate
## and the expression measured nothing at all, deleting both would not have moved it.
##
## The reason it was written that way is real: the two ARE the same value today, so no comparison of values
## can say anything. What is actually claimed is a claim about `look.gd`'s TEXT — `BUTTON_EDGE` is chrome
## under every button and all eleven slots, `ENDING_CLEARED` is one half of a pair with `ENDING_DIED`, and
## the file's own comment records that aliasing them once meant tuning the victory headline dragged every
## button edge with it. **So the text is what gets asserted**: each name is declared with a `Color(...)` of
## its own, and neither is declared as the other.
func _l3b_the_two_yellows_are_not_one_constant(t) -> void:
	var text := _read("res://src/look.gd")
	t.ok(text != "", "look.gd를 읽었다")
	for name in ["BUTTON_EDGE", "ENDING_CLEARED"]:
		var line := _const_line(text, name)
		t.ok(line != "", "look.gd에 const %s 선언이 있다 — 찾은 줄: '%s'" % [name, line])
		t.ok(line.contains("Color("),
				"%s는 제 Color(...) 리터럴로 선언돼 있다 — 다른 상수를 가리키면 값 하나를 고칠 때 둘 다 움직인다"
						% name)
	t.ok(not _const_line(text, "ENDING_CLEARED").contains("BUTTON_EDGE"),
			"ENDING_CLEARED는 BUTTON_EDGE의 별칭이 아니다 — 오늘 값이 같은 것과 같은 상수인 것은 다르다")
	t.ok(not _const_line(text, "BUTTON_EDGE").contains("ENDING_CLEARED"),
			"반대 방향의 별칭도 아니다 — 한쪽만 막으면 나머지 한 줄로 그대로 들어온다")

	# **Invert the instrument.** A reader that cannot see the alias form reads identical to one that can.
	var aliased := "const BUTTON_EDGE := Color(0.95, 0.85, 0.45)\nconst ENDING_CLEARED := BUTTON_EDGE\n"
	t.ok(not _const_line(aliased, "ENDING_CLEARED").contains("Color("),
			"별칭으로 쓴 가짜 파일은 Color 리터럴이 없는 것으로 잡힌다 (스캐너 자가 점검)")
	t.eq(_const_line(aliased, "BUTTON_EDGE_WIDTH"), "",
			"없는 상수는 빈 줄로 답한다 — 접두사가 같은 이름에 걸려들지 않는다 (스캐너 자가 점검)")
	t.ok(_const_line("const ENDING_DIED := Color(0.9, 0.4, 0.35)\n", "ENDING_DIED").contains("Color("),
			"진짜 선언은 제대로 잡힌다 (스캐너 자가 점검)")


## The one `const NAME :=` line, or `""`. Whole-word on the name, so `BUTTON_EDGE` does not answer for
## `BUTTON_EDGE_WIDTH` — the two live one line apart in `look.gd`.
func _const_line(text: String, name: String) -> String:
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("const "):
			continue
		var rest := line.substr(6).strip_edges()
		var cut := rest.find(":")
		if cut < 0:
			cut = rest.find("=")
		if cut < 0:
			continue
		if rest.substr(0, cut).strip_edges() == name:
			return line
	return ""


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


# -- L4: the sizes no other check pins --------------------------------------------------------------------
## Every number here was free at any value. Each is a literal on BOTH sides, which is the only shape that
## measures a constant rather than copying it.
func _l4_the_sizes_no_other_check_pins(t) -> void:
	t.eq(Look.FORCE_CLUSTER_RADIUS, 48.0,
			"뭉쳐 읽히는 거리는 48px다 — 40마리를 한 점에 세운 픽스처는 이 값을 재지 못한다")
	t.eq(Look.FORCE_LABEL_OFFSET, 18.0, "라벨은 몸 아래 18px에 놓인다")
	t.eq(Look.FORCE_LABEL_SIZE, 14, "라벨 글씨는 14다")
	t.eq(Look.CORPSE_PROGRESS_WIDTH, 3.0, "먹는 호의 굵기는 3px다 — 이 값을 읽는 검사가 하나도 없었다")
	t.eq(Look.CORPSE_PROGRESS_RING, 1.5, "그 호의 반지름은 시체 크기의 1.5배다")
	t.eq(Look.MINIMAP_SIZE, Vector2(240.0, 135.0), "지도는 240×135다 — 필드와 같은 16:9다")
	t.eq(Look.MINIMAP_MARGIN, 16.0, "지도는 화면 모서리에서 16px 떨어져 있다")
	t.eq(Look.MINIMAP_HOST_R, 3.0, "지도 위 호스트 점은 3px다")
	t.eq(Look.MINIMAP_CLONE_R, 1.5, "분신 점은 1.5px — 호스트보다 작다")
	t.eq(Look.MINIMAP_CREATURE_R, 2.0, "생물 점은 2px다")
	t.eq(Look.MINIMAP_SHOW_DIST, 1600.0,
			"호스트에서 1600px 안의 생물만 지도에 뜬다 — 이 값은 1500~2140 어디여도 초록이었다")
	t.ok(Look.MINIMAP_HOST_R > Look.MINIMAP_CREATURE_R
			and Look.MINIMAP_CREATURE_R > Look.MINIMAP_CLONE_R,
			"세 점의 크기 순서는 호스트 > 생물 > 분신이다 — 찾는 점이 가장 크다")
	t.eq(Look.STRIKE_RADIUS, 22.0, "3을 누른 자리의 표시는 22px다")
	t.eq(Look.SPLIT_CHARGE_RING, 1.6, "F 충전 호는 몸 반지름의 1.6배 자리에 그려진다")
	t.eq(Look.SPLIT_CHARGE_WIDTH, 3.0, "그 호의 굵기는 3px다")
	t.eq(Look.BITE_SHOW_TIME, 0.12, "물린 원뿔은 0.12초 남는다")
	t.eq(Look.CLONE_LOAD_GROWTH, 1.6, "가득 실은 분신은 1.6배로 커진다 — 이 게임의 유일한 가독성 요구다")
	t.eq(Look.CLONE_LOAD_FULL, 8.0, "가득이라는 것은 8이다")
	t.eq(Look.CORNER, 0.34, "몸은 모서리를 반폭의 0.34만큼 깎은 사각형이다")
	# 0.001 = 1초 뒤에 틈의 1/1000만 남는다. 이 값이 hud.gd 안에 박혀 있는 동안은 아무도 안 쟀다.
	t.eq(Look.HUD_BAR_CHASE, 0.001, "레벨 바는 1초에 남은 틈의 0.001배까지 따라붙는다 — 낮을수록 빠르다")
	t.eq(Look.ZOOM_NEAR, 1.6, "카메라는 1.6에서 시작해서")
	t.eq(Look.ZOOM_FAR, 0.8, "무리가 커지면 0.8까지 물러난다")
	t.eq(Look.ZOOM_FULL_AT, 30.0, "다 물러나는 것은 무리 30에서다")
	t.ok(Look.ZOOM_NEAR > Look.ZOOM_FAR, "그리고 NEAR가 FAR보다 크다 — 큰 값이 가까운 쪽이다")

	# The HUD's layout, moved out of `hud.gd` with the rest of the palette. `net_hud` hand-writes the same
	# numbers off the drawn rectangles; these are the declarations those assertions land on.
	t.eq(Look.HUD_BAR_AT, Vector2(24.0, 22.0), "레벨 바는 (24, 22)에서 시작한다")
	t.eq(Look.HUD_BAR_HEIGHT, 14.0, "높이는 14다")
	t.eq(Look.HUD_BAR_INSETS, 48.0, "좌우로 24씩, 합쳐 48을 뺀 폭이다")
	t.eq(Look.HUD_BANK_AT, Vector2(24.0, 84.0), "은행 숫자는 (24, 84)다")
	t.eq(Look.HUD_CARRY_AT, Vector2(24.0, 112.0), "무리 줄은 (24, 112)다")
	t.eq(Look.HUD_HP_AT_UP, Vector2(34.0, 28.0), "체력은 바닥에서 28 위, 왼쪽에서 34다")
	t.eq(Look.HUD_LEGEND_AT_UP, Vector2(24.0, 68.0), "안내줄은 바닥에서 68 위다")
	t.eq(Look.FONT_HUD_BANK, 44, "은행 숫자가 가장 큰 글씨다 — 44")
	t.eq(Look.FONT_HUD_ROW, 20, "무리 줄과 안내줄은 20이다")
	t.eq(Look.FONT_HUD_HP, 26, "체력은 26이다")
	t.eq(Look.HUD_LEGEND_TIME, 12.0, "게임 안의 유일한 안내는 12초만 떠 있다")
	t.ok(Look.FONT_HUD_BANK > Look.FONT_HUD_HP and Look.FONT_HUD_HP > Look.FONT_HUD_ROW,
			"글씨 크기 순서는 은행 > 체력 > 줄이다")


# -- L5: the floor colour is the one the engine actually clears with --------------------------------------
## **`Look.BG` is read nowhere in `src/`.** It is mirrored by hand into `project.godot`'s
## `environment/defaults/default_clear_color`, and `look.gd`'s own comment says there is no automatic link
## between the two files. This is the link. The same key sat under a doubled path prefix for a day and the
## play field showed the engine's default grey with every check green.
func _l5_the_floor_colour_is_the_engines(t) -> void:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	t.ok(f != null, "project.godot을 읽었다")
	if f == null:
		return
	var found := ""
	for raw: String in f.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("environment/defaults/default_clear_color"):
			found = line
	t.ok(found != "",
			"project.godot의 [rendering] 아래에 environment/defaults/default_clear_color가 있다 — "
			+ "접두사가 겹치면 이 키는 아무 데도 적용되지 않는다")
	var open_at := found.find("Color(")
	if open_at < 0:
		t.ok(false, "그 줄은 Color(...)를 담고 있다 (%s)" % found)
		return
	var inner := found.substr(open_at + 6, found.find(")", open_at) - open_at - 6)
	var parts := inner.split(",")
	t.ok(parts.size() >= 3, "그 Color는 세 성분 이상이다 (%s)" % inner)
	var engine_bg := Color(float(parts[0]), float(parts[1]), float(parts[2]))
	t.ok(absf(engine_bg.r - Look.BG.r) < 0.001 and absf(engine_bg.g - Look.BG.g) < 0.001
			and absf(engine_bg.b - Look.BG.b) < 0.001,
			"엔진이 지우는 색과 Look.BG가 같다 — 두 파일을 잇는 것은 이 검사뿐이다 (%s vs %s)"
					% [str(engine_bg), str(Look.BG)])


# -- R1: the three species, literal to literal ------------------------------------------------------------
## `SPECIES_RADIUS` had **zero** hits in all of `tests/`: the size ordering the design rests on
## (a maxed crow can never reach the weakest horse) was stated in a comment and computed by nothing.
## `SPECIES_REACH_BONUS[CROW]`/`[HORSE]` at 500 was green — a crow damaging the host from half a screen
## away, which deletes "walk up to it and it hits back".
func _r1_the_three_species_table(t) -> void:
	const CROW := 0
	const HORSE := 1
	const BOSS := 2
	t.eq(float(Rules.SPECIES_RADIUS[CROW]), 12.0, "까마귀의 바탕 크기는 12px다")
	t.eq(float(Rules.SPECIES_RADIUS[HORSE]), 22.0, "말은 22px다")
	t.eq(float(Rules.SPECIES_RADIUS[BOSS]), 48.0, "보스는 48px다")
	# The ordering with force's 1.5× ceiling folded in — the sentence "size belongs to the species and force
	# only leans on it", as arithmetic. A maxed crow is 18 and the weakest horse is 22.
	t.ok(float(Rules.SPECIES_RADIUS[CROW]) * 1.5 < float(Rules.SPECIES_RADIUS[HORSE]),
			"힘을 다 채운 까마귀(18)도 가장 약한 말(22)보다 작다 — 크기는 종의 것이다")
	t.ok(float(Rules.SPECIES_RADIUS[HORSE]) * 1.5 < float(Rules.SPECIES_RADIUS[BOSS]),
			"힘을 다 채운 말(33)도 보스(48)보다 작다")

	t.eq(int(Rules.SPECIES_FORCE_MIN[CROW]), 8, "까마귀의 힘은 8에서")
	t.eq(int(Rules.SPECIES_FORCE_MAX[CROW]), 12, "12 사이다")
	t.eq(int(Rules.SPECIES_FORCE_MIN[HORSE]), 30, "말은 30에서")
	t.eq(int(Rules.SPECIES_FORCE_MAX[HORSE]), 40,
			"40 사이다 — 이 값이 300이어도 초록이었고, 그러면 첫 말이 30체력 호스트를 한 방에 죽인다")
	t.eq(int(Rules.SPECIES_FORCE_MIN[BOSS]), 120, "보스는 120이고")
	t.eq(int(Rules.SPECIES_FORCE_MAX[BOSS]), 120, "위아래가 같은 숫자다 — 보스는 하나고 힘도 하나다")

	t.eq(float(Rules.SPECIES_REACH_BONUS[CROW]), 0.0,
			"까마귀의 추가 사거리는 0이다 — 걸어가서 때리면 되받는 것이지 원거리 공격이 아니다")
	t.eq(float(Rules.SPECIES_REACH_BONUS[HORSE]), 0.0, "말도 0이다")
	t.eq(float(Rules.SPECIES_REACH_BONUS[BOSS]), 70.0, "보스만 70이다")
	# The RELATION, not only the number: pinned as a literal alone, retuning 물기 to 80 silently re-opens
	# the band where a host kills a 360-HP boss backpedalling, damage-free.
	t.eq(float(Rules.SPECIES_REACH_BONUS[BOSS]), float(Parts.RANGE[Parts.BITE]),
			"그리고 그 70은 물기의 사거리와 같은 수다 — 물기를 80으로 올리면 이 줄이 빨개진다")

	t.eq(int(Rules.SPECIES_FLEES[CROW]), 0, "까마귀는 안 도망친다")
	t.eq(int(Rules.SPECIES_FLEES[HORSE]), 1, "말은 도망친다 — 그래서 몰아야 한다")
	t.eq(int(Rules.SPECIES_FLEES[BOSS]), 0, "보스도 안 도망친다")

	t.eq(String(Parts.SPECIES_NAME[CROW]), "까마귀", "이름 세 개, 종 순서대로")
	t.eq(String(Parts.SPECIES_NAME[HORSE]), "말", "말")
	t.eq(String(Parts.SPECIES_NAME[BOSS]), "보스",
			"보스 — 이 칸이 빈 문자열이어도 초록이었고, 그러면 엔딩의 먹은 종 줄에 빈 항목이 찍힌다")

	t.eq(Rules.HP_PER_FORCE, 3, "몸의 체력은 힘 × 3이다")
	t.eq(Rules.CROW_COUNTER_TIME, 2.0, "맞은 까마귀는 2초 동안 가장 가까운 몸을 향해 걷는다")


# -- R2: the ground -------------------------------------------------------------------------------------
## `WATER_RADIUS_MIN`/`MAX` had **zero** hits: at 3.0 the field grows twelve three-pixel ponds, `WATER_SLOW`
## still applies and nothing is ever big enough to be slowed in — "water is the third wall herding needs"
## silently false.
func _r2_the_ground_and_the_water(t) -> void:
	t.eq(Rules.ROCK_COUNT, 40, "바위는 마흔 개다")
	t.eq(Rules.ROCK_RADIUS_MIN, 40.0, "가장 작은 바위가 40px이고")
	t.eq(Rules.ROCK_RADIUS_MAX, 90.0, "가장 큰 것이 90px이다")
	t.eq(Rules.ROCK_CLEAR_DIST, 400.0,
			"호스트 출발점 400px 안에는 바위가 없다 — 검사가 상수 자신을 경계로 읽고 있었다")
	t.eq(Rules.WATER_COUNT, 12, "물은 열두 군데다")
	t.eq(Rules.WATER_RADIUS_MIN, 90.0, "가장 작은 물웅덩이가 90px이고")
	t.eq(Rules.WATER_RADIUS_MAX, 180.0, "가장 큰 것이 180px이다")
	t.eq(Rules.WATER_SLOW, 0.6, "물 안에서는 0.6배로 느려진다 — 몸도 생물도 같이")
	# A pond has to be bigger than what walks into it, or it is not a wall. The boss at 48 is the biggest
	# thing on the field.
	t.ok(Rules.WATER_RADIUS_MIN > float(Rules.SPECIES_RADIUS[2]),
			"가장 작은 웅덩이(90)도 가장 큰 생물(48)보다 크다 — 3px 웅덩이는 벽이 아니다")
	t.ok(Rules.ROCK_RADIUS_MIN > Rules.BODY_RADIUS * 2.0,
			"가장 작은 바위(40)도 몸 지름(28)보다 크다")


# -- R3: the boss's clock and the arena -------------------------------------------------------------------
## Eight references to `BOSS_HUNT_AT` in `tests/` and **every one symbolic**. At 0.0 the boss walks at the
## host from the opening frame and one touch is 120 damage on a 30-HP host; at 99999.0 the run has no last
## act. Both green.
func _r3_the_boss_clock(t) -> void:
	t.eq(Rules.BOSS_HUNT_AT, 150.0, "보스는 150초까지 배회하고 그 뒤로는 호스트에게 온다")
	t.eq(Rules.ARENA_RADIUS, 900.0, "아레나는 반지름 900px이다")
	t.eq(Rules.ARENA_SUMMON_RING, 300.0, "닫히는 순간 분신은 호스트 둘레 300px에 떨어진다")
	t.eq(Rules.BOSS_SPAWN_MIN_DIST, 1800.0,
			"보스는 호스트에서 최소 1800px 밖에서 시작한다 — 검사가 상수 자신을 경계로 읽고 있었다")
	t.eq(Rules.BOSS_PLACE_TRIES, 200,
			"보스 자리는 200번 뽑아 본다 — 12번이면 다섯 번에 한 번 떨어지고 열 씨앗 검사가 100번에 7번 통과한다")
	t.eq(Rules.CRITTER_SPAWN_MIN_DIST, 900.0, "다른 생물도 900px 밖에서 들어온다")
	t.ok(Rules.BOSS_SPAWN_MIN_DIST > Look.MINIMAP_SHOW_DIST,
			"보스의 출발 거리는 지도 표시 거리보다 멀다 — 처음부터 보이는 것은 보스뿐이라는 예외의 값이다")
	t.ok(Rules.ARENA_SUMMON_RING < Rules.ARENA_RADIUS,
			"소환 고리는 아레나 안이다 — 밖이면 닫는 순간 분신이 벽 너머로 떨어진다")
	t.eq(Rules.HOST_HIT_GRACE, 1.0, "호스트는 한 번 맞으면 1초 동안 다시 맞지 않는다")
	t.eq(Rules.CLONE_ATTACK_PERIOD, 1.2, "그리고 공격 주기는 1.2초다")
	t.ok(Rules.HOST_HIT_GRACE < Rules.CLONE_ATTACK_PERIOD,
			"무적 시간이 공격 주기보다 짧다 — 그래서 한 마리만으로는 이 규칙이 안 보이고, 둘 이상 붙어야 보인다")


# -- R4: the opening field fits in the table ---------------------------------------------------------------
## `_spawn_at()` refuses at the cap; `_place_boss()` calls `_write_critter()` unconditionally. Latent today
## and nothing pinned the relation, so both start counts were free to be tuned past it — a write past
## `critter_count` into a preallocated row nothing clears.
func _r4_the_opening_field_fits_the_cap(t) -> void:
	# ⚠ **The product, not the sum.** `SPECIES_START` counts HERDS and each one arrives `SPECIES_HERD` deep,
	# so reading the table as a head count says 16 where the field is 31 — and the check that exists to keep
	# the opening under the cap would bless a field half again as big as it measured.
	var heads := 0
	for s in Rules.SPECIES_START.size():
		heads += int(Rules.SPECIES_START[s]) * int(Rules.SPECIES_HERD[s])
	t.eq(heads, 31, "필드는 서른한 마리로 시작한다 (무리 수 × 무리 크기)")
	t.eq(int(Rules.SPECIES_START[Parts.Species.BOSS]), 0,
			"보스의 시작 칸은 0이다 — _place_boss가 유일한 보스를 놓는다")
	t.eq(Rules.CRITTER_MAX, 64, "표는 예순넷까지다")
	t.ok(heads + 1 <= Rules.CRITTER_MAX,
			"서른하나 + 보스 하나는 예순넷 안이다 — _place_boss는 상한을 안 보고 쓴다")
	t.ok(heads + 1 < Rules.CRITTER_MAX,
			"그리고 딱 맞는 게 아니라 남는다 — 꽉 찬 개막은 이후의 도착이 전부 무시된다는 뜻이다")
	t.eq(Rules.CRITTER_INTERVAL, 20.0, "그 뒤로 20초마다 무리 하나가 들어온다")
	t.eq(int(Rules.SPECIES_SPAWN_WEIGHT[Parts.Species.BOSS]), 0, "보스의 가중치는 0이다 — 굴려지지 않는다")
	t.ok(int(Rules.SPECIES_SPAWN_WEIGHT[Parts.Species.CROW])
					> int(Rules.SPECIES_SPAWN_WEIGHT[Parts.Species.HORSE]),
			"까마귀의 가중치가 말보다 크다 — 말은 사건이고 까마귀는 일상이다")


# -- the instrument itself ---------------------------------------------------------------------------------
## **Invert the instrument, not only the subject** (CLAUDE.md). Every assertion above rests on `_contrast`,
## and a `_contrast` that returned a constant would pass the whole file.
func _x_the_instrument(t) -> void:
	t.ok(absf(_contrast(Color.WHITE, Color.BLACK) - 21.0) < 0.01,
			"흰색과 검은색의 대비는 21:1이다 (계기 자가 점검)")
	t.eq(_contrast(Look.BG, Look.BG), 1.0, "같은 색끼리는 1:1이다 (계기 자가 점검)")
	t.ok(_contrast(Color(0.0, 0.0, 0.0, 0.0), Look.BG) < FIELD_FLOOR,
			"투명한 검정은 바닥을 못 넘는다 — L1이 잡으려는 바로 그 값이다 (계기 자가 점검)")
	t.ok(absf(_contrast(Color.WHITE, Color.BLACK) - _contrast(Color.BLACK, Color.WHITE)) < 0.0001,
			"어느 쪽을 먼저 넣어도 같은 수다 (계기 자가 점검)")


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(col: Color) -> float:
	return 0.2126 * _linear(col.r) + 0.7152 * _linear(col.g) + 0.0722 * _linear(col.b)


func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
