extends RefCounted
## 캐릭터 그림이 **상자와 맞나.** 🔴 「마법사로 읽히나」는 원리적으로 못 잰다 —
## 여기가 재는 것은 **크기 계약**과 **자리 계약**뿐이다. 나머지는 눈이 본다(계획 §7.2).
##
## 🔴🔴 **왜 크기가 계약인가.** GDD가 「캐릭터와 타일 두께를 같게 잡은 것이 위력 단을 눈에 보이게
##  만드는 장치다 — 저 벽을 뚫으면 지나갈 수 있다를 화면에서 **세어서** 알 수 있다」고 못 박았다.
##  ⚠ 그림이 32×48이면(머리가 위로 튀어나오면) **「머리가 벽에 박히는데 지나간다」**가 생기고,
##   그 순간 「세어서 안다」가 거짓이 된다. **에러는 하나도 안 나고 스샷에서만 보인다.**
##
## 🔴🔴 **텍스처(`load`)로는 그림의 내용을 못 잰다 — 원본 png를 따로 연다.**
##  `Image.load_from_file` 이 임포트를 안 거치고 디스크의 png를 그대로 읽으며 **헤드리스에서 돈다**
##  (verify-read 실측). ⚠ 그래서 이 그물은 **소스 트리에서만** 유효하다 — 내보낸 빌드에는 원본 png가
##  없다. 그물은 소스에서만 도니 문제가 아니다.
##
## ⚠ **이 리포에서 png가 그물에 걸리는 길이 여기 하나다.** `.godot/` 이 `.gitignore` 대상이라
##  구운 `.ctex` 는 커밋되지 않는다 ⇒ 새 기계에서는 `--import` 가 한 번 돌아야 한다.
##  안 돌면 아래 첫 줄이 **빨개진다**(조용히 없어지지 않는다).

const Fx := preload("res://src/view/fx_tuning.gd")
const Character := preload("res://src/actor/character.gd")
## 🔴 **`pick_state()` 가 순수 static 이라 씬 없이 부를 수 있다** — 그게 판정 3·4를 그물로
##  옮긴 이유다. ⚠ 인스턴스를 만들지 않는다(`Node2D` 라 만들면 트리가 필요하다).
const CharacterView := preload("res://src/view/character_view.gd")


func run(t) -> void:
	_body_sheet_fits_the_box(t)
	_pick_state_picks_different_cells(t)


func _body_sheet_fits_the_box(t) -> void:
	var tex: Texture2D = load(Fx.CHAR_SHEET)
	t.ok(tex != null, "몸 시트를 읽는다 (%s)" % Fx.CHAR_SHEET)
	if tex == null:
		# 🔴🔴 **여기서 그냥 `return` 하면 검사가 「실패」가 아니라 통째로 사라진다** —
		#  통과 수만 줄고 아무도 안 짖는다. 로그에서 「없어진 검사」는 「통과한 검사」와 구별이 안 된다.
		t.ok(false, "몸 시트를 못 읽어서 크기 계약을 **하나도 못 쟀다**")
		return

	var w := tex.get_width()
	var h := tex.get_height()
	# 🔴🔴 위 GDD 주석이 재는 자리. **높이가 상자보다 크면 안 된다.**
	t.eq(h, Character.H_PX, "몸 시트 높이가 캐릭터 상자와 같다 (%dpx)" % Character.H_PX)
	# 🔴 폭은 칸 수 × 상자 폭이다. 배수가 아니면 마지막 칸이 잘려 그려지는데 **에러가 안 난다.**
	t.ok(w > 0 and w % Character.W_PX == 0,
		"몸 시트 폭 %d 이 상자 폭 %d 의 배수다" % [w, Character.W_PX])
	if w <= 0 or w % Character.W_PX != 0:
		t.ok(false, "시트 폭이 배수가 아니라 칸 수를 못 세고 **내용 검사를 하나도 못 쟀다**")
		return

	# 🔴🔴 **칸 수는 상수가 아니다** — 시트에서 나온다(`fx_tuning` 의 그 주석과 같은 규칙).
	#  세 번째 곳에 박으면 그 셋이 갈라지는 날 그물이 **틀린 쪽 편을 든다.**
	var cells := w / Character.W_PX
	t.ok(cells > 0, "몸 시트에 칸이 있다 (%d칸)" % cells)

	_cells_hold_their_contract(t, w, h, cells)
	_table_stays_inside_the_sheet(t, cells)


## 🔴🔴 **칸이 통째로 투명해도 위 검사는 전부 초록이다** — 16px 시트에서 verify-read가 실측했다:
##  투명한 시트로 바꿔도 **그물이 초록이고 stderr까지 깨끗했다.** 캐릭터가 화면에서 사라지는데
##  아무도 안 짖는다. ⇒ **`null` 은 막혀 있었고 「빈 그림」이 열려 있었다.**
##
## ⚠ **칸 단위로 짠다.** 지금은 칸이 하나지만 단계 3에서 6칸이 되고, 그때 「한 칸만 안 그렸다」와
##  「한 칸만 정렬이 어긋났다」가 정확히 조용히 새는 모양이다.
func _cells_hold_their_contract(t, w: int, h: int, cells: int) -> void:
	# 🔴 엔진이 「내보낸 빌드에서는 안 된다」고 짖는다. **정당한 짖음이다** — 그물은 소스 트리에서만
	#  돌고, 게임이 그리는 쪽은 임포트된 `.ctex`(`load()`)라 내보내기에 아무 영향이 없다.
	# ⚠ **선언을 파일 경로까지 넣어 좁힌다.** 넓게 적으면 도는 동안 진짜 침묵사도 같이 사면된다 —
	#  그리고 사면은 **그물 하나가 아니라 실행 전체**에 걸린다(러너가 stdout의 `[EXPECT]` 를 다 모은다).
	t.expect_error("Loaded resource as image file, this will not work on export: '%s'" % Fx.CHAR_SHEET)
	var img := Image.load_from_file(Fx.CHAR_SHEET)
	t.ok(img != null, "몸 시트 원본 png를 연다 (임포트를 안 거친다)")
	if img == null:
		t.ok(false, "원본 png를 못 읽어서 **내용 검사를 하나도 못 쟀다**")
		return

	# 🔴🔴 **원본과 임포트된 텍스처가 같은 그림인지 먼저 본다.** png를 고치고 임포트를 안 돌리면
	#  게임은 **낡은 `.ctex`** 를 그리는데 이 함수는 **새 png** 를 잰다 ⇒ 아래 초록이 화면과 무관해진다.
	#  ⚠ 크기까지 같게 고친 경우는 못 잡는다. 그래도 「칸 수가 늘었는데 화면은 그대로」는 여기서 문다.
	t.eq(Vector2i(img.get_width(), img.get_height()), Vector2i(w, h),
		"원본 png 크기가 임포트된 텍스처와 같다 (임포트가 안 낡았다)")
	if img.get_width() != w or img.get_height() != h:
		t.ok(false, "원본과 텍스처의 크기가 갈려서 **내용 검사를 하나도 못 쟀다**")
		return

	# 🔴 **공중 칸을 표에서 뽑는다.** 번호를 손으로 적으면 `fx_tuning` 과 두 벌이 된다.
	var airborne := _airborne_cells()
	# ⚠ 목록이 비면 아래 예외가 한 번도 안 걸리고, 그러면 「접지 칸만」이라는 라벨이 거짓이 된다.
	t.ok(airborne.size() > 0, "공중 칸이 표에서 나온다 (%d칸 — 발 검사의 예외다)" % airborne.size())

	for cell in cells:
		var box := opaque_bbox(img, cell * Character.W_PX, 0, Character.W_PX, Character.H_PX)
		# ① 빈 칸이 아니다.
		t.ok(box.size.x > 0 and box.size.y > 0,
			"칸 %d 에 불투명 픽셀이 있다 (bbox %s)" % [cell, box])
		if box.size.x <= 0 or box.size.y <= 0:
			continue

		# ② 🔴🔴 **좌우 반전이 상자 안 같은 자리에 앉는 조건.**
		#  상자를 기준으로 뒤집으면 x 가 `W−1−x` 로 간다 ⇒ 내용이 제자리에 앉으려면
		#  **`minx + maxx == W−1`** 이어야 한다. 한 열만 밀려도 **방향을 바꿀 때 캐릭터가 1px 튄다.**
		#  ⚠ 화면에서 거의 안 보이고 그물이 아니면 아무도 안 잡는다 — 실제로 이 png의 앞 판이
		#   `7+23 = 30` 이라 1px 모자랐다(계획 §3.1).
		#  🔴 이 단언이 참이면 **내용 폭이 짝수인 것도 따라 나온다** — 하나로 둘을 잡는다.
		var minx: int = box.position.x
		var maxx: int = box.position.x + box.size.x - 1
		t.eq(minx + maxx, Character.W_PX - 1,
			"칸 %d 의 minx+maxx 가 %d 이다 (좌우 반전이 제자리에 앉는다 · %d+%d)" % [
				cell, Character.W_PX - 1, minx, maxx])

		# ③ 🔴 **접지 칸만 발이 맨 아랫줄에 닿는다.** 안 닿으면 캐릭터가 지형 위에 **떠 보이고**,
		#  칸마다 다르면 상태가 바뀔 때 **위아래로 튄다.** 상자는 그대로인데 그림만 뜨는 것이라
		#  거동 검사에는 하나도 안 걸린다.
		#
		# 🔴🔴 **점프·낙하는 예외다. 빠뜨린 게 아니다.** 다리를 접은 **공중 포즈**라 발이 아래에 없고,
		#  억지로 맨 아랫줄까지 내리면 **캐릭터가 세로로 늘어난다**(실측: 점프 maxy 28 · 낙하 29).
		#  ⚠ **다시 넓히지 마라** — 넓히는 순간 그림을 고쳐야 하고, 그 「고침」이 곧 늘어난 캐릭터다.
		#  🔴 예외 목록은 `Fx.CHAR_AIRBORNE` **하나에서만** 나온다. 여기 상태 이름을 또 적으면
		#   두 곳이 되고, 공중 포즈를 늘리는 날 한쪽만 따라온다.
		if airborne.has(cell):
			continue
		var maxy: int = box.position.y + box.size.y - 1
		t.eq(maxy, Character.H_PX - 1,
			"접지 칸 %d 의 발이 맨 아랫줄에 닿는다 (maxy %d)" % [cell, maxy])


## `Fx.CHAR_AIRBORNE` 의 상태들이 쓰는 **칸 번호** 집합.
static func _airborne_cells() -> Dictionary:
	var out: Dictionary = {}
	for state: int in Fx.CHAR_AIRBORNE:
		for cell: int in Fx.CHAR_FRAMES.get(state, []):
			out[cell] = true
	return out


## 🔴 표의 칸 번호가 시트를 벗어나면 화면이 **엉뚱한 칸을 그리는데 에러가 안 난다.**
func _table_stays_inside_the_sheet(t, cells: int) -> void:
	# ⚠ 표가 비면 아래 루프가 한 번도 안 돌고 **초록이 된다.** 폴더 스캔 그물의 첫 줄과 같은 이유다.
	t.ok(Fx.CHAR_FRAMES.size() > 0, "상태 → 칸 표가 비어 있지 않다 (%d줄)" % Fx.CHAR_FRAMES.size())
	for state: int in Fx.CHAR_FRAMES.keys():
		var frames: Variant = Fx.CHAR_FRAMES[state]
		t.ok(frames is Array, "상태 %d 의 칸 목록이 배열이다" % state)
		if not (frames is Array):
			continue
		# 🔴 빈 목록은 **그릴 칸이 없다**는 뜻인데, 소비자는 `[0]` 을 인덱싱한다 — 런타임에 죽는다.
		t.ok((frames as Array).size() > 0, "상태 %d 에 칸이 하나라도 있다" % state)
		for cell: int in (frames as Array):
			t.ok(cell >= 0 and cell < cells,
				"상태 %d 의 칸 %d 이 시트 안이다 (0~%d)" % [state, cell, cells - 1])

	# 🔴🔴 **빠진 칸도 남는 칸도 없다.** 표에 안 적힌 칸은 **아무도 안 그리는 그림**이고(시트만 무거워진다),
	#  두 상태가 같은 칸을 쓰면 **그 둘이 화면에서 구별이 안 된다** — 판정 3·4가 조용히 죽는 자리다.
	var used: Dictionary = {}
	var overlap := 0
	for state: int in Fx.CHAR_FRAMES.keys():
		for cell: int in Fx.CHAR_FRAMES[state]:
			if used.has(cell):
				overlap += 1
			used[cell] = true
	t.eq(overlap, 0, "두 상태가 같은 칸을 안 쓴다")
	t.eq(used.size(), cells, "표가 쓰는 칸 수와 시트의 칸 수가 같다 (빠진 칸도 남는 칸도 없다)")


## 🔴🔴 **판정 3(걷기·점프·낙하 구별)과 4(쓰러짐)를 눈에서 그물로 옮기는 자리다.**
##  `pick_state()` 가 **순수 static** 이라 씬도 캐릭터도 없이 조합을 넣고 칸을 받아 볼 수 있다.
##
## 🔴🔴 **다만 여기가 재는 것은 「코드가 다른 칸을 고른다」까지다.**
##  **여섯 칸을 전부 똑같이 그려도 이 검사는 초록이다** — 「그 칸의 그림이 실제로 다르다」는
##  원리적으로 눈만 잰다(계획 §7.2). ⚠ 라벨을 거기까지 넓히지 마라.
func _pick_state_picks_different_cells(t) -> void:
	# [쓰러짐, 접지, vy, 움직임] → 기대 상태
	var cases: Array[Array] = [
		[true, true, 0.0, false, Fx.CHAR_DOWNED, "쓰러짐"],
		[true, false, -100.0, true, Fx.CHAR_DOWNED, "쓰러진 채 공중이어도 쓰러짐이 이긴다"],
		[false, false, -100.0, false, Fx.CHAR_JUMP, "올라가는 중"],
		[false, false, 100.0, true, Fx.CHAR_FALL, "떨어지는 중"],
		[false, true, 0.0, true, Fx.CHAR_WALK, "걷는 중"],
		[false, true, 0.0, false, Fx.CHAR_STAND, "서기"],
	]
	# ⚠ 목록이 비면 아래가 한 번도 안 돌고 **초록이 된다.**
	t.ok(cases.size() > 0, "조합이 %d개다" % cases.size())

	var seen: Dictionary = {}
	for c: Array in cases:
		var got: int = CharacterView.pick_state(c[0], c[1], float(c[2]), c[3])
		t.eq(got, int(c[4]), "%s → 상태 %d" % [c[5], int(c[4])])
		seen[got] = true

	# 🔴 **조합마다 다른 상태가 나오나.** 위 `t.eq` 만 있으면 `pick_state` 가 늘 같은 값을 줘도
	#  기대값을 그 값으로 적어 두면 통과한다 — **서로 다르다**를 따로 잰다.
	#  ⚠ 조합 여섯 중 둘은 일부러 같은 상태(쓰러짐)라 서로 다른 상태는 다섯이다.
	t.eq(seen.size(), Fx.CHAR_FRAMES.size(),
		"조합이 표의 상태 %d개를 전부 고른다 (하나도 도달 불가가 아니다)" % Fx.CHAR_FRAMES.size())


## 영역 안에서 **불투명 픽셀이 실제로 차지하는 사각형**(영역 로컬 좌표). 빈 영역이면 크기 0이다.
##
## 🔴 **단계 4가 이 함수를 그대로 쓴다.** 계획 §7.1의 7이 같은 모양이다 —
##  「지팡이 png 폭이 36이어도 **맨 오른쪽 열이 투명하면** 눈에 보이는 끝은 35px인데 `tip_px()` 는
##  36px이라 총구가 그림 밖에 뜬다」. 그건 `box.end.x == 폭` 인지를 이 bbox로 재는 일이다.
static func opaque_bbox(img: Image, ox: int, oy: int, w: int, h: int) -> Rect2i:
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			# ⚠ `> 0.0` 이 아니라 `<= 0.0` 을 걸러내는 쪽으로 적는다 — 반투명 1픽셀도 「그렸다」다.
			if img.get_pixel(ox + x, oy + y).a <= 0.0:
				continue
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
