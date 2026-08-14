extends RefCounted
## The parts table's own shape, and the six numbers it inherited from plan 2.
##
## **A short row here is an index error at a level-up**, and it is the one defect in this file that no
## behavioural net can see: every check that drives a part drives a part that happens to be in range.
##
## ⚠ **Asserting only that the arrays agree with EACH OTHER passes on a table where every one of them is
## short.** So `NAME.size()` is pinned to the literal 5 first, and every other array is compared to that
## literal — not to `NAME.size()` read back. The same trap one level up: a scan that walks the class's
## constant map and finds nothing at all reports "no short rows" perfectly, so the scan's own hit count is
## asserted too, and `_short_rows()` is run against a synthetic table that must fail IT.
##
## ⚠ **The six carried numbers are LITERALS.** `RANGE[BITE]`, `ARC[BITE]`, `COOLDOWN[BITE]`,
## `SELF_MUL[DASH]`, `SELF_TIME[DASH]`, `COOLDOWN[DASH]` were `Rules.BITE_RANGE` / `BITE_ARC` /
## `BITE_COOLDOWN` / `DASH_SPEED` / `DASH_TIME` / `DASH_COOLDOWN` when plan 2 shipped and was played. Read
## back through the table they pass at every value — both sides of the sim read whatever is in the row, so
## nothing else in the round can see a retune. Only plan 2's tested numbers can, and they are written here.

## The row count. Every parallel array in `Parts` is this long, and it is a literal on purpose.
const ROWS := 5

## Every parallel array in the table, by name. Hand-written so a NEW column added short goes red by name
## rather than disappearing into a total — and the constant-map scan below is what catches a column added
## to the file but never added to this list.
const COLUMNS := ["NAME", "SPECIES", "SLOTS", "KIND", "FORCE", "HP", "MOVEMENT", "COOLDOWN", "BREATH",
		"SHAPE", "RANGE", "ARC", "SELF_MUL", "SELF_TIME", "SUSTAINED"]


func run(t) -> void:
	_c17_shape(t)
	_c17b_scan(t)
	_c_carried_numbers(t)
	_c_rows(t)


# -- 17: every array is the same length as NAME ---------------------------------------------------------
func _c17_shape(t) -> void:
	t.eq(Parts.NAME.size(), ROWS, "행은 다섯 개다 — 리터럴로 못박는다 (전부 짧은 표는 서로 비교해선 안 잡힌다)")

	var consts: Dictionary = load("res://src/sim/parts.gd").get_script_constant_map()
	t.ok(consts.has("NAME"), "설정: 상수 목록을 실제로 읽었다 — 비면 아래 검사가 저절로 통과한다")

	# Per name, not as a count of failures: "14개가 맞다" tells you nothing about WHICH row is short.
	for col: String in COLUMNS:
		t.ok(consts.has(col), "%s 열이 표에 실제로 있다" % col)
		var arr: Array = consts[col] if consts.has(col) else []
		t.eq(arr.size(), ROWS, "%s의 길이가 5다" % col)


# -- 17b: the scan itself, and a synthetic table that has to fail it ------------------------------------
## `COLUMNS` is hand-written, so a column added to `parts.gd` and forgotten here would never be checked.
## This walks what the class actually declares instead — and then asserts the walk's own hit count, because
## a scan that matched nothing reports a clean table perfectly.
func _c17b_scan(t) -> void:
	var consts: Dictionary = load("res://src/sim/parts.gd").get_script_constant_map()
	var arrays := 0
	for key: Variant in consts:
		if typeof(consts[key]) == TYPE_ARRAY:
			arrays += 1
	var short := _short_rows(consts)
	t.eq(arrays, COLUMNS.size(), "표가 선언한 배열 상수의 수가 손으로 적은 목록과 같다 (%d)" % arrays)
	t.eq(short.size(), 0, "선언된 배열 중 길이가 5가 아닌 것이 하나도 없다 %s" % str(short))

	# **Invert the instrument, not only the subject.** A comparator that never actually compares reads
	# identical to one that does; this synthetic table has one short row and must make the same code report
	# it by name.
	var fake_short := _short_rows({"NAME": [1, 2, 3, 4, 5], "SHORT": [1, 2, 3], "OK": [1, 2, 3, 4, 5]})
	t.ok(fake_short.size() == 1 and str(fake_short[0]) == "SHORT",
			"짧은 행 하나짜리 가짜 표는 스스로 잡힌다 (스캐너 자가 점검) %s" % str(fake_short))
	t.eq(_short_rows({"A": [1, 2, 3, 4, 5]}).size(), 0,
			"제 길이인 가짜 표는 걸리지 않는다 (스캐너 자가 점검)")


func _short_rows(table: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in table:
		if typeof(table[key]) != TYPE_ARRAY:
			continue
		if (table[key] as Array).size() != ROWS:
			out.append(str(key))
	return out


# -- the six numbers plan 2 shipped, played, and handed over --------------------------------------------
## ⚠ Every one of these is a literal. The plan's own table writes `ARC` as `1.22` — 0.0017 rad off
## `deg_to_rad(70)` — and calls retyping these numbers "a silent retune of the one attack the player has
## had since plan 2, disguised as a refactor". The tolerance below is 1e-6, which 1.22 does not survive.
func _c_carried_numbers(t) -> void:
	t.ok(absf(float(Parts.RANGE[Parts.BITE]) - 70.0) < 0.0001,
			"물기의 사거리는 plan 2의 70px 그대로다 (%.6f)" % float(Parts.RANGE[Parts.BITE]))
	t.ok(absf(float(Parts.ARC[Parts.BITE]) - 1.2217304764) < 0.000001,
			"물기의 각은 plan 2의 70도(1.2217304764rad) 그대로다 — 1.22로 적으면 여기서 걸린다 (%.10f)"
					% float(Parts.ARC[Parts.BITE]))
	t.ok(absf(float(Parts.COOLDOWN[Parts.BITE]) - 0.5) < 0.0001,
			"물기의 쿨다운은 plan 2의 0.5초 그대로다 (%.4f)" % float(Parts.COOLDOWN[Parts.BITE]))

	t.ok(absf(float(Parts.SELF_MUL[Parts.DASH]) - 2.8) < 0.0001,
			"짧은 숨의 배율은 2.8이다 (%.4f)" % float(Parts.SELF_MUL[Parts.DASH]))
	t.ok(absf(float(Parts.SELF_TIME[Parts.DASH]) - 0.16) < 0.0001,
			"짧은 숨의 지속은 plan 2의 0.16초 그대로다 (%.4f)" % float(Parts.SELF_TIME[Parts.DASH]))
	t.ok(absf(float(Parts.COOLDOWN[Parts.DASH]) - 0.8) < 0.0001,
			"짧은 숨의 쿨다운은 plan 2의 0.8초 그대로다 (%.4f)" % float(Parts.COOLDOWN[Parts.DASH]))

	# **The division nobody wrote down.** `Rules.DASH_SPEED` was an absolute 560 and `SELF_MUL` is a
	# multiplier; the two agree only while `HOST_SPEED` is exactly 200. This is the one place that equality
	# is stated, so retuning the walk without noticing what it does to the burst goes red here.
	t.ok(absf(float(Parts.SELF_MUL[Parts.DASH]) * Rules.HOST_SPEED - 560.0) < 0.01,
			"배율 × 걷는 속도가 plan 2의 대시 속도 560px/s와 같다 (%.1f)"
					% (float(Parts.SELF_MUL[Parts.DASH]) * Rules.HOST_SPEED))

	t.ok(absf(float(Parts.SELF_MUL[Parts.HORSE_LEGS]) - 1.8) < 0.0001,
			"갤럽의 배율은 1.8이다 (%.4f)" % float(Parts.SELF_MUL[Parts.HORSE_LEGS]))
	t.ok(absf(float(Parts.BREATH[Parts.HORSE_LUNG]) - 2.5) < 0.0001,
			"말 폐활량이 더하는 숨은 2.5초다 (%.4f)" % float(Parts.BREATH[Parts.HORSE_LUNG]))


# -- the rows themselves, by value -----------------------------------------------------------------------
## The columns a mechanical sweep can flip without anything noticing: which slots a part takes, whether it
## is an active, whether `space` will take it, and whether it is held or fired.
func _c_rows(t) -> void:
	t.eq(Parts.Slot.size(), 11, "칸은 열하나다 — 여섯 겉, 다섯 속")
	t.eq(Parts.Slot.EYES, 6, "일곱째 칸부터가 속이다 (겉 여섯 · 속 다섯의 경계)")
	t.eq(Parts.Slot.LUNG, 10, "숨은 제 칸을 갖는다 — 밥통에 접히지 않았다")

	# **`Parts.BITE` is 0, so 0 cannot be the empty sentinel anywhere.** Plan 2's `Actives.NONE` was 0; a
	# mechanical carry-over would read "holding 물기" as "holding nothing", and it compiles and runs.
	t.eq(Parts.BITE, 0, "물기의 id는 0이다 — 빈 칸을 0으로 쓰면 안 되는 이유가 이것이다")

	t.eq(Parts.SLOTS[Parts.BITE].size(), 0, "물기는 어떤 칸도 차지하지 않는다")
	t.eq(Parts.SLOTS[Parts.DASH].size(), 0, "짧은 숨도 어떤 칸도 차지하지 않는다")
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.HORSE_LEGS]), PackedInt32Array([Parts.Slot.HINDLIMBS]),
			"말 다리는 뒷다리 칸이다")
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.HORSE_MANE]), PackedInt32Array([Parts.Slot.TORSO]),
			"말 갈기는 몸통 칸이다")
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.HORSE_LUNG]), PackedInt32Array([Parts.Slot.LUNG]),
			"말 폐활량은 허파 칸이다")

	# The pool's only lock: `Cards.roll()` skips `SPECIES < 0`, which is what keeps the two you are handed
	# out of the level-up cards with no second list to maintain.
	t.ok(int(Parts.SPECIES[Parts.BITE]) < 0, "물기는 어느 종의 것도 아니다 — 카드로 나오지 않는다")
	t.ok(int(Parts.SPECIES[Parts.DASH]) < 0, "짧은 숨도 어느 종의 것도 아니다")
	for p in [Parts.HORSE_LEGS, Parts.HORSE_MANE, Parts.HORSE_LUNG]:
		t.eq(int(Parts.SPECIES[p]), Parts.Species.HORSE, "%s은(는) 말의 것이다" % str(Parts.NAME[p]))

	t.eq(int(Parts.KIND[Parts.BITE]), Parts.Kind.ACTIVE, "물기는 액티브다")
	t.eq(int(Parts.KIND[Parts.DASH]), Parts.Kind.ACTIVE, "짧은 숨은 액티브다")
	t.eq(int(Parts.KIND[Parts.HORSE_LEGS]), Parts.Kind.ACTIVE, "말 다리는 액티브다")
	t.eq(int(Parts.KIND[Parts.HORSE_MANE]), Parts.Kind.PASSIVE, "말 갈기는 패시브다 — 키에 넣을 수 없다")
	t.eq(int(Parts.KIND[Parts.HORSE_LUNG]), Parts.Kind.PASSIVE, "말 폐활량은 패시브다")

	# **`MOVEMENT` and `KIND` are two different gates and 물기 is the one part that tells them apart.**
	# Gated on `KIND` alone, 말 갈기 is still refused by `space` and the wrong gate passes every check.
	t.eq(int(Parts.MOVEMENT[Parts.BITE]), 0, "물기는 움직이는 것이 아니다 (액티브지만 스페이스는 거부한다)")
	t.eq(int(Parts.MOVEMENT[Parts.DASH]), 1, "짧은 숨은 움직이는 것이다")
	t.eq(int(Parts.MOVEMENT[Parts.HORSE_LEGS]), 1, "말 다리는 움직이는 것이다")

	t.eq(int(Parts.SHAPE[Parts.BITE]), Parts.Shape.ARC, "물기는 앞쪽 부채꼴이다")
	t.eq(int(Parts.SHAPE[Parts.DASH]), Parts.Shape.SELF, "짧은 숨은 제 몸을 바꾼다 — 아무것도 때리지 않는다")
	t.eq(int(Parts.SHAPE[Parts.HORSE_MANE]), Parts.Shape.NONE, "말 갈기는 발동하는 모양이 없다")

	# **The whole difference between the two movement actives.** Flipped, 갤럽은 한 프레임짜리 대시가 된다.
	t.eq(int(Parts.SUSTAINED[Parts.DASH]), 0, "짧은 숨은 한 번 터지고 만다")
	t.eq(int(Parts.SUSTAINED[Parts.HORSE_LEGS]), 1, "말 다리는 누르고 있는 동안 이어진다")

	t.eq(int(Parts.FORCE[Parts.HORSE_LEGS]), 5, "말 다리는 힘 5를 준다")
	t.eq(int(Parts.FORCE[Parts.HORSE_MANE]), 5, "말 갈기도 힘 5를 준다")
	t.eq(int(Parts.FORCE[Parts.HORSE_LUNG]), 0, "말 폐활량은 힘을 주지 않는다")
	t.eq(int(Parts.HP[Parts.HORSE_MANE]), 1, "말 갈기의 효과 전부: 최대 체력 +1")
	t.eq(int(Parts.HP[Parts.HORSE_LEGS]), 0, "말 다리는 체력을 주지 않는다")

	# The trait's cost against the table it counts. A fourth horse part makes the trait cheap and this
	# number has to move with it — stated in one place, compared here.
	var horse_parts := 0
	for p in Parts.NAME.size():
		if int(Parts.SPECIES[p]) == Parts.Species.HORSE:
			horse_parts += 1
	t.eq(horse_parts, Rules.HORSE_TRAIT_COUNT,
			"말 특성이 요구하는 수가 표에 실제로 있는 말 부품 수와 같다 (%d)" % horse_parts)
