extends RefCounted
## The parts table's own shape, and the six numbers it inherited from plan 2.
##
## **A short row here is an index error at a level-up**, and it is the one defect in this file that no
## behavioural net can see: every check that drives a part drives a part that happens to be in range.
##
## ⚠ **Asserting only that the arrays agree with EACH OTHER passes on a table where every one of them is
## short.** So `NAME.size()` is pinned to the literal `ROWS` first, and every other array is compared to
## that literal — not to `NAME.size()` read back. The same trap one level up: a scan that walks the class's
## constant map and finds nothing at all reports "no short rows" perfectly, so the scan's own hit count is
## asserted too, and `_short_rows()` is run against synthetic tables that must fail IT — including one
## whose only short row sits in the skip list, because a skip list that swallowed everything reads exactly
## like a clean table.
##
## ⚠ **The six carried numbers are LITERALS.** `RANGE[BITE]`, `ARC[BITE]`, `COOLDOWN[BITE]`,
## `SELF_MUL[DASH]`, `SELF_TIME[DASH]`, `COOLDOWN[DASH]` were `Rules.BITE_RANGE` / `BITE_ARC` /
## `BITE_COOLDOWN` / `DASH_SPEED` / `DASH_TIME` / `DASH_COOLDOWN` when plan 2 shipped and was played. Read
## back through the table they pass at every value — both sides of the sim read whatever is in the row, so
## nothing else in the round can see a retune. Only plan 2's tested numbers can, and they are written here.

## The row count. Every parallel array in `Parts` is this long, and it is a literal on purpose.
const ROWS := 8

## Every parallel array in the table, by name. Hand-written so a NEW column added short goes red by name
## rather than disappearing into a total — and the constant-map scan below is what catches a column added
## to the file but never added to this list.
const COLUMNS := ["NAME", "SPECIES", "SLOTS", "KIND", "FORCE", "HP", "MOVEMENT", "COOLDOWN", "BREATH",
		"SHAPE", "RANGE", "ARC", "SELF_MUL", "SELF_TIME", "SUSTAINED", "DROPS"]

## Array constants in `parts.gd` that are NOT columns of the part table. Hand-written and hand-counted the
## same way `COLUMNS` is: a second non-row array added and forgotten here would be silently unchecked, and
## a skip list that quietly grows is a hole in the length scan rather than an exception to it.
const NON_ROW_ARRAYS := ["SPECIES_NAME"]


func run(t) -> void:
	_c17_shape(t)
	_c17b_scan(t)
	_c_carried_numbers(t)
	_c_rows(t)
	_c_crow_rows(t)
	_c_drops(t)


# -- 17: every array is the same length as NAME ---------------------------------------------------------
func _c17_shape(t) -> void:
	t.eq(Parts.NAME.size(), ROWS, "행은 여덟 개다 — 리터럴로 못박는다 (전부 짧은 표는 서로 비교해선 안 잡힌다)")

	var consts: Dictionary = load("res://src/sim/parts.gd").get_script_constant_map()
	t.ok(consts.has("NAME"), "설정: 상수 목록을 실제로 읽었다 — 비면 아래 검사가 저절로 통과한다")

	# Per name, not as a count of failures: "14개가 맞다" tells you nothing about WHICH row is short.
	for col: String in COLUMNS:
		t.ok(consts.has(col), "%s 열이 표에 실제로 있다" % col)
		var arr: Array = consts[col] if consts.has(col) else []
		t.eq(arr.size(), ROWS, "%s의 길이가 8이다" % col)


# -- 17b: the scan itself, and a synthetic table that has to fail it ------------------------------------
## `COLUMNS` is hand-written, so a column added to `parts.gd` and forgotten here would never be checked.
## This walks what the class actually declares instead — and then asserts the walk's own hit count, because
## a scan that matched nothing reports a clean table perfectly.
func _c17b_scan(t) -> void:
	var consts: Dictionary = load("res://src/sim/parts.gd").get_script_constant_map()
	var arrays := 0
	for key: Variant in consts:
		if typeof(consts[key]) == TYPE_ARRAY and not NON_ROW_ARRAYS.has(str(key)):
			arrays += 1
	var short := _short_rows(consts)
	t.eq(NON_ROW_ARRAYS.size(), 1, "표의 열이 아닌 배열 상수는 하나뿐이다 (SPECIES_NAME) — 손으로 센다")
	t.eq(arrays, COLUMNS.size(), "표가 선언한 배열 상수의 수가 손으로 적은 목록과 같다 (%d)" % arrays)
	t.eq(short.size(), 0, "선언된 배열 중 길이가 8이 아닌 것이 하나도 없다 %s" % str(short))

	# **Invert the instrument, not only the subject.** A comparator that never actually compares reads
	# identical to one that does; this synthetic table has one short row and must make the same code report
	# it by name.
	var full := [1, 2, 3, 4, 5, 6, 7, 8]
	var fake_short := _short_rows({"NAME": full, "SHORT": [1, 2, 3], "OK": full})
	t.ok(fake_short.size() == 1 and str(fake_short[0]) == "SHORT",
			"짧은 행 하나짜리 가짜 표는 스스로 잡힌다 (스캐너 자가 점검) %s" % str(fake_short))
	t.eq(_short_rows({"A": full}).size(), 0, "제 길이인 가짜 표는 걸리지 않는다 (스캐너 자가 점검)")

	# **And the skip list itself has to be inverted.** A skip list that swallowed everything would report a
	# perfectly clean table forever, so the same fixture is run both ways: skipped it is silent, unskipped
	# it is one short row by name.
	var skipped := {"NAME": full, "SPECIES_NAME": [1, 2, 3]}
	t.eq(_short_rows(skipped).size(), 0, "열이 아닌 배열은 길이 검사에서 빠진다 (스캐너 자가 점검)")
	var unskipped := _short_rows(skipped, [])
	t.ok(unskipped.size() == 1 and str(unskipped[0]) == "SPECIES_NAME",
			"그러나 건너뛰기 목록을 비우면 바로 잡힌다 — 목록이 전부를 삼키고 있지 않다 %s" % str(unskipped))


func _short_rows(table: Dictionary, skip: Array = NON_ROW_ARRAYS) -> Array:
	var out: Array = []
	for key: Variant in table:
		if typeof(table[key]) != TYPE_ARRAY:
			continue
		if skip.has(str(key)):
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

	# **The two cells plan 4 retuned, pinned as literals, because nothing pinned them before.**
	# 1.8 × HOST_SPEED 200 = 360 and the horse walks at 230: the stage's central mechanic deleted by the
	# stage's own first reward. 1.1 = 220, under the horse — and the relation is asserted, not only the
	# number, so retuning the walk cannot re-open it silently.
	t.ok(absf(float(Parts.SELF_MUL[Parts.HORSE_LEGS]) - 1.1) < 0.0001,
			"갤럽의 배율은 1.1이다 (%.4f)" % float(Parts.SELF_MUL[Parts.HORSE_LEGS]))
	var gallop := float(Parts.SELF_MUL[Parts.HORSE_LEGS]) * Rules.HOST_SPEED
	var horse := float(Rules.SPECIES_SPEED_MUL[Parts.Species.HORSE]) * Rules.HOST_SPEED
	t.ok(gallop < horse, "갤럽 전속력(%.1f)이 말의 속도(%.1f)보다 느리다 — 말은 쫓는 것이 아니라 모는 것이다"
			% [gallop, horse])
	t.ok(absf(float(Parts.BREATH[Parts.HORSE_LUNG]) - 2.5) < 0.0001,
			"말 폐활량이 더하는 숨은 2.5초다 (%.4f)" % float(Parts.BREATH[Parts.HORSE_LUNG]))
	t.eq(int(Parts.HP[Parts.HORSE_MANE]), 5,
			"말 갈기가 올리는 최대 체력은 5다 — 까마귀 한 대(8~12)의 반, 한 대 전부가 아니다")


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
	# 말 다리's own square is asserted in `_c_crow_rows`, paired with 까마귀 발's — the two are one claim
	# (the only square a card can displace anything in) and splitting them across two functions is how one
	# half gets moved without the other.
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
	t.eq(int(Parts.HP[Parts.HORSE_MANE]), 5, "말 갈기의 효과 전부: 최대 체력 +5")
	t.eq(int(Parts.HP[Parts.HORSE_LEGS]), 0, "말 다리는 체력을 주지 않는다")

	# The trait's cost against the table it counts. A fourth horse part makes the trait cheap and this
	# number has to move with it — stated in one place, compared here.
	#
	# ⚠ **This counts ROWS, not what drops.** Only 말 다리 is in `Parts.DROPS`, so the horse trait is
	# unreachable in play this build and that is deliberate — see `Rules.HORSE_TRAIT_COUNT`'s own comment.
	# No check here may assert the trait fires; `net_body` wears the three by hand.
	var horse_parts := 0
	for p in Parts.NAME.size():
		if int(Parts.SPECIES[p]) == Parts.Species.HORSE:
			horse_parts += 1
	t.eq(horse_parts, Rules.HORSE_TRAIT_COUNT,
			"말 특성이 요구하는 수가 표에 실제로 있는 말 부품 수와 같다 (%d)" % horse_parts)


# -- the crow's three rows, cell by cell -----------------------------------------------------------------
## *Mutation: any one cell.* Every value is a literal — read back through `Parts.*` these pass at any
## number, which is the whole reason the six carried numbers above are written out too.
##
## 까마귀 날개 and 까마귀 부리 are the two ends of one axis (wide and slow · narrow and fast); 까마귀 발 is
## the passive, and it is the only part in either pool that shares a square with another one.
func _c_crow_rows(t) -> void:
	for p in [Parts.CROW_WING, Parts.CROW_BEAK, Parts.CROW_FOOT]:
		t.eq(int(Parts.SPECIES[p]), Parts.Species.CROW, "%s은(는) 까마귀의 것이다" % str(Parts.NAME[p]))

	t.eq(str(Parts.NAME[Parts.CROW_WING]), "까마귀 날개", "5번 행의 이름은 까마귀 날개다")
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.CROW_WING]), PackedInt32Array([Parts.Slot.BACK]),
			"까마귀 날개는 등 칸이다")
	t.eq(int(Parts.KIND[Parts.CROW_WING]), Parts.Kind.ACTIVE, "까마귀 날개는 액티브다")
	t.eq(int(Parts.FORCE[Parts.CROW_WING]), 3, "까마귀 날개는 힘 3을 준다")
	t.eq(int(Parts.HP[Parts.CROW_WING]), 0, "까마귀 날개는 체력을 주지 않는다")
	t.eq(int(Parts.MOVEMENT[Parts.CROW_WING]), 0, "까마귀 날개는 스페이스가 거부한다 — 움직이는 것이 아니다")
	t.eq(int(Parts.SHAPE[Parts.CROW_WING]), Parts.Shape.ARC, "까마귀 날개는 앞쪽 부채꼴이다")
	t.ok(absf(float(Parts.RANGE[Parts.CROW_WING]) - 55.0) < 0.0001,
			"까마귀 날개의 사거리는 55px다 (%.4f)" % float(Parts.RANGE[Parts.CROW_WING]))
	t.ok(absf(float(Parts.ARC[Parts.CROW_WING]) - deg_to_rad(100.0)) < 0.000001,
			"까마귀 날개의 각은 100도다 (%.6f)" % float(Parts.ARC[Parts.CROW_WING]))
	t.ok(absf(float(Parts.COOLDOWN[Parts.CROW_WING]) - 1.4) < 0.0001,
			"까마귀 날개의 쿨다운은 1.4초다 (%.4f)" % float(Parts.COOLDOWN[Parts.CROW_WING]))

	t.eq(str(Parts.NAME[Parts.CROW_BEAK]), "까마귀 부리", "6번 행의 이름은 까마귀 부리다")
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.CROW_BEAK]), PackedInt32Array([Parts.Slot.HEAD]),
			"까마귀 부리는 머리 칸이다")
	t.eq(int(Parts.KIND[Parts.CROW_BEAK]), Parts.Kind.ACTIVE, "까마귀 부리는 액티브다")
	t.eq(int(Parts.FORCE[Parts.CROW_BEAK]), 4, "까마귀 부리는 힘 4를 준다 — 셋 중 가장 무겁다")
	t.eq(int(Parts.HP[Parts.CROW_BEAK]), 0, "까마귀 부리는 체력을 주지 않는다")
	t.eq(int(Parts.MOVEMENT[Parts.CROW_BEAK]), 0, "까마귀 부리도 스페이스가 거부한다")
	t.eq(int(Parts.SHAPE[Parts.CROW_BEAK]), Parts.Shape.ARC, "까마귀 부리도 앞쪽 부채꼴이다")
	t.ok(absf(float(Parts.RANGE[Parts.CROW_BEAK]) - 40.0) < 0.0001,
			"까마귀 부리의 사거리는 40px다 (%.4f)" % float(Parts.RANGE[Parts.CROW_BEAK]))
	t.ok(absf(float(Parts.ARC[Parts.CROW_BEAK]) - deg_to_rad(40.0)) < 0.000001,
			"까마귀 부리의 각은 40도다 (%.6f)" % float(Parts.ARC[Parts.CROW_BEAK]))
	t.ok(absf(float(Parts.COOLDOWN[Parts.CROW_BEAK]) - 0.6) < 0.0001,
			"까마귀 부리의 쿨다운은 0.6초다 (%.4f)" % float(Parts.COOLDOWN[Parts.CROW_BEAK]))

	t.eq(str(Parts.NAME[Parts.CROW_FOOT]), "까마귀 발", "7번 행의 이름은 까마귀 발다")
	t.eq(int(Parts.KIND[Parts.CROW_FOOT]), Parts.Kind.PASSIVE, "까마귀 발은 패시브다 — 키에 넣을 수 없다")
	t.eq(int(Parts.FORCE[Parts.CROW_FOOT]), 2, "까마귀 발은 힘 2를 준다")
	t.eq(int(Parts.HP[Parts.CROW_FOOT]), 3, "까마귀 발은 최대 체력 3을 준다")
	t.eq(int(Parts.MOVEMENT[Parts.CROW_FOOT]), 0, "까마귀 발도 움직이는 것이 아니다")
	t.eq(int(Parts.SHAPE[Parts.CROW_FOOT]), Parts.Shape.NONE, "까마귀 발은 발동하는 모양이 없다")
	t.ok(absf(float(Parts.RANGE[Parts.CROW_FOOT])) < 0.0001, "까마귀 발은 사거리가 없다")
	t.ok(absf(float(Parts.COOLDOWN[Parts.CROW_FOOT])) < 0.0001, "까마귀 발은 쿨다운이 없다")

	for p in [Parts.CROW_WING, Parts.CROW_BEAK, Parts.CROW_FOOT]:
		t.ok(absf(float(Parts.BREATH[p])) < 0.0001, "%s은(는) 숨을 더하지 않는다" % str(Parts.NAME[p]))
		t.ok(absf(float(Parts.SELF_MUL[p])) < 0.0001, "%s은(는) 제 속도를 바꾸지 않는다" % str(Parts.NAME[p]))
		t.ok(absf(float(Parts.SELF_TIME[p])) < 0.0001, "%s은(는) 지속 시간이 없다" % str(Parts.NAME[p]))
		t.eq(int(Parts.SUSTAINED[p]), 0, "%s은(는) 누르고 있는 것이 아니다" % str(Parts.NAME[p]))

	# **The one square two parts share, asserted as ONE claim.** This is the whole of card displacement in
	# this build: nothing else in the two pools can ever push anything out.
	# *Mutation: move 까마귀 발 to FORELIMBS — displacement quietly stops existing and every other check in
	# the round stays green.*
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.HORSE_LEGS]), PackedInt32Array([Parts.Slot.HINDLIMBS]),
			"말 다리와 까마귀 발이 같은 칸(뒷다리)을 쓴다 — 카드가 밀어낼 수 있는 유일한 자리 (1/2)")
	t.eq(PackedInt32Array(Parts.SLOTS[Parts.CROW_FOOT]), PackedInt32Array([Parts.Slot.HINDLIMBS]),
			"말 다리와 까마귀 발이 같은 칸(뒷다리)을 쓴다 — 카드가 밀어낼 수 있는 유일한 자리 (2/2)")

	# **결정 5's other half, written as an assertion**: the multi-slot fork was closed and no two-square
	# part ships. This is what goes red the day one lands after all — the guards in `hp_max()`,
	# `breath_max()` and `_recompute_traits()` keep only synthetic coverage until then.
	var multi := []
	for p in Parts.NAME.size():
		if (Parts.SLOTS[p] as Array).size() > 1:
			multi.append(str(Parts.NAME[p]))
	t.eq(multi.size(), 0, "이번 빌드에 두 칸짜리 부품은 없다 %s" % str(multi))


# -- DROPS: the column, and the pools it produces --------------------------------------------------------
## 결정 5 lives entirely in this array, so it needs two checks and not one: the literal row, and the
## CONSEQUENCE driven off it. *Mutation: set `DROPS[HORSE_MANE]` back to 1 — both must go red, and if only
## one does, the count is being derived from the literal instead of counted.*
func _c_drops(t) -> void:
	t.eq(Parts.DROPS.size(), ROWS, "DROPS도 여덟 칸이다")
	t.eq(int(Parts.DROPS[Parts.BITE]), 0, "물기는 어느 풀에도 없다")
	t.eq(int(Parts.DROPS[Parts.DASH]), 0, "짧은 숨도 어느 풀에도 없다")
	t.eq(int(Parts.DROPS[Parts.HORSE_LEGS]), 1, "말 다리는 풀에 있다 — 이번 빌드 말의 유일한 부품이다")
	t.eq(int(Parts.DROPS[Parts.HORSE_MANE]), 0, "말 갈기는 행으로만 남고 풀에서는 빠진다")
	t.eq(int(Parts.DROPS[Parts.HORSE_LUNG]), 0, "말 폐활량도 행으로만 남는다")
	t.eq(int(Parts.DROPS[Parts.CROW_WING]), 1, "까마귀 날개는 풀에 있다")
	t.eq(int(Parts.DROPS[Parts.CROW_BEAK]), 1, "까마귀 부리도 풀에 있다")
	t.eq(int(Parts.DROPS[Parts.CROW_FOOT]), 1, "까마귀 발도 풀에 있다")

	# Counted, not restated. Three · one · zero is the shape of the whole card economy this build.
	var by_species := [0, 0, 0]
	for p in Parts.NAME.size():
		var s := int(Parts.SPECIES[p])
		if s >= 0 and int(Parts.DROPS[p]) == 1:
			by_species[s] += 1
	t.eq(by_species[Parts.Species.CROW], 3, "까마귀가 내놓는 부품은 셋이다 — 풀은 흔한 쪽에서 열린다")
	t.eq(by_species[Parts.Species.HORSE], 1, "말이 내놓는 부품은 하나다 (말 다리)")
	t.eq(by_species[Parts.Species.BOSS], 0, "보스는 부품을 내놓지 않는다 — 경험치와 런의 끝뿐이다")

	# **The one active in the pool that can be rolled onto a clone.** With every droppable part passive the
	# corpse roll's ARC branch is dead code in play, reachable only by writing `Parts.BITE` into the swarm
	# by hand — which the roll itself can never do, since 물기 is `SPECIES` -1.
	var pooled_arcs := 0
	for p in Parts.NAME.size():
		if int(Parts.DROPS[p]) == 1 and int(Parts.SHAPE[p]) == Parts.Shape.ARC:
			pooled_arcs += 1
	t.eq(pooled_arcs, 2, "풀 안에 부채꼴 액티브가 둘 있다 — 분신에게 굴러갈 무기가 실제로 존재한다")
