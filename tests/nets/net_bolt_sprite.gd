extends RefCounted
## 탄 머리 그림이 **표와 맞나.** 🔴 `net_sprite`(캐릭터) · `net_monster_sprite`(몬스터)와 같은 어법이다.
##
## 🔴🔴 **왜 이제야 생겼나 — 계획이 「짤 수 있는데 안 짰다」를 적어 두고 갔다.**
##  `docs/plans/1.ready/bolt-head-sprite.md` 의 「그물이 이 변경을 하나도 안 잰다」 절이
##  **세 검사를 이름까지 적어 놓고 「셋 다 아직 안 짰다」로 끝났다**(2026-08-05).
##  ⇒ 그동안 탄 머리 그림은 **일회용 스크립트로 한 번 잰 값**이 전부였고, 그건 리포에 안 남는다.
##
## 🔴🔴 **이 파일이 원리적으로 못 재는 것: 「그림이 화면에 보이나」.**
##  계획이 실측으로 남겼다 — `spell_view` 의 그리는 코드는 **뮤테이션이 전부 초록**이다
##  (`character-sprite` 가 `draw_set_transform` 복원을 지워도 1,296개 통과였다).
##  ⚠ 실제로 판정 1이 실패한 원인(**글로우가 그림을 덮었다**)은 여기 있는 어떤 검사로도 안 잡힌다.
##  ⇒ **「이 그물이 초록이니 탄이 보인다」로 읽으면 거짓이다.**

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


## 🔴🔴 **표의 키가 `ELEM_ALL` 을 덮나 — 안 덮이면 그 룬의 탄이 화면에서 마젠타가 된다.**
##
## ⚠ **양방향으로 잰다.** 「모든 룬에 그림이 있나」만 재면 표에 **죽은 줄**이 남아도 초록이고,
##  그 줄은 룬을 지운 흔적이라 다음 사람이 「이 룬이 있나 보다」로 읽는다.
##
## 🔴 **계획 문서가 「불·무 둘뿐」이라고 적어 둔 것이 낡았다** — 물 작업에서 `ELEM_WATER` 가
##  들어와 지금은 셋이다. **이 검사가 있었으면 그 낡음이 그날 잡혔다.**
func _table_covers_every_rune(t) -> void:
	t.ok(Tuning.ELEM_ALL.size() > 0, "룬이 하나라도 있다 (검사의 전제)")
	for elem: int in Tuning.ELEM_ALL:
		t.ok(Fx.BOLT_SHEETS.has(elem),
			"룬 %d 에 탄 머리 그림이 있다 (없으면 화면에서 마젠타로 비명을 지른다)" % elem)
	for elem: int in Fx.BOLT_SHEETS:
		t.ok(Tuning.ELEM_ALL.has(elem),
			"표의 룬 %d 가 `ELEM_ALL` 에 실재한다 (죽은 줄이 아니다)" % elem)


## 🔴🔴 **16×16 이고, 통째로 비어 있지 않다.**
##
## ⚠ **「비어 있지 않나」가 이 파일에서 제일 값어치 있는 줄이다.** `character-sprite` 가
##  **「통째로 투명한 시트가 초록」** 구멍을 실제로 찾았다 — 크기만 재면 **온통 검은 png** 도 통과한다.
##  🔴 그리고 탄은 **가산 합성**이라(`spell_view._ready` 의 `BLEND_MODE_ADD`) **검정이 곧 투명이다**
##   ⇒ 알파를 재면 안 되고 **밝기**를 재야 한다. 여기가 캐릭터·몬스터 쪽과 갈리는 자리다.
##
## 🔴 **`Image.load_from_file` 로 디스크의 png 를 직접 연다** — `load()` 는 임포트를 거쳐서
##  압축 텍스처가 되고, 그러면 픽셀을 못 읽는다(`net_sprite` 와 같은 이유).
func _sheet_is_square_and_not_blank(t, elem: int) -> void:
	if not Fx.BOLT_SHEETS.has(elem):
		return   # 위 검사가 이미 빨갛다. 여기서 또 짖으면 같은 고장이 두 번 세어진다
	var path: String = Fx.BOLT_SHEETS[elem]

	var tex: Texture2D = load(path)
	t.ok(tex != null, "룬 %d 의 그림이 읽힌다 (%s)" % [elem, path.get_file()])
	if tex == null:
		return

	# 🔴 **크기가 `bolt_px` 에서 나온다 — 16을 박지 않는다.** 표를 바꾸면 그림도 따라야 한다.
	var want := int(Fx.bolt_px(0) * 2.0)
	t.eq(tex.get_width(), want,
		"룬 %d 의 그림 폭이 세대0 지름(%d)과 같다" % [elem, want])
	t.eq(tex.get_height(), want, "룬 %d 의 그림이 정사각이다" % elem)

	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	t.ok(img != null, "룬 %d 의 png 를 디스크에서 직접 연다" % elem)
	if img == null:
		return

	# 🔴🔴 **밝은 픽셀을 센다.** 가산 합성이라 어두운 픽셀은 화면에 아무것도 안 더한다 ⇒
	#  「알파가 있다」로는 **온통 검은 그림**을 못 거른다.
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
	# 🔴 **반대쪽**: 온통 흰 사각형도 「그림」이 아니다. 계획이 「밝은 코어 → 어두운 가장자리
	#  그라데이션이 이미 들어 있어 자체가 빛이다」를 근거로 글로우를 줄였으므로,
	#  **그 그라데이션이 실재하는지**를 값으로 남긴다.
	t.ok(bright < img.get_width() * img.get_height(),
		"룬 %d 의 그림이 **꽉 찬 사각형이 아니다** (밝은 픽셀 %d / %d)"
			% [elem, bright, img.get_width() * img.get_height()])


## 🔴🔴 **그려지는 지름이 세대 표에서 나온다 — 그림 크기를 상수로 안 박는다.**
##  ⚠ 갈라지면 **「세대가 작아졌는데 그림만 그대로」**가 되는데 **에러가 안 난다**
##   (`spell_view._draw_head` 주석이 그 함정을 든다).
## 🔴 **세대가 실제로 작아지는지도 같이 잰다** — 표를 평평하게 만들면(둘 다 8.0)
##  「지름이 표에서 나온다」는 여전히 참이지만 **「크기가 세대를 나른다」가 죽는다.**
func _head_diameter_follows_the_generation_table(t) -> void:
	var g0 := Fx.bolt_px(0)
	var g1 := Fx.bolt_px(1)
	t.ok(g0 > g1, "세대1 머리가 세대0보다 작다 (%.1f > %.1f) — 크기가 세대를 나른다" % [g0, g1])
	t.eq(g1 * 2.0, g0, "세대1이 정확히 절반이다 (그림이 짝수 배율로 줄어 안 뭉개진다)")
	# 🔴 그림 원본과 세대0이 1:1이라야 **가장 큰 탄에서 원본이 그대로 보인다.**
	for elem: int in Tuning.ELEM_ALL:
		if not Fx.BOLT_SHEETS.has(elem):
			continue
		var tex: Texture2D = load(Fx.BOLT_SHEETS[elem])
		if tex != null:
			t.eq(float(tex.get_width()), g0 * 2.0,
				"룬 %d 는 세대0에서 원본과 1:1이다 (확대도 축소도 없다)" % elem)


## 🔴🔴 **무리(글로우)가 그림을 안 씻나 — 값으로 잴 수 있는 절반만.**
##
## ⚠ **판정 1이 실패한 자리가 여기다**(2026-08-05, 사용자: 「빛이 따라가니까 안보임」).
##  🔴 **「보이나」는 원리적으로 눈의 몫이다.** 여기서 재는 것은 **「그 값이 원 시절 그대로인가」** 뿐이다.
##  ⇒ 0.45 로 되돌리면 이 검사가 빨개져서 **그 사연이 다시 읽힌다.**
## ⚠ **0.12 가 옳다는 증거가 아니다** — 사용자가 고른 값이고 **아직 아무도 화면을 다시 안 봤다.**
func _glow_no_longer_washes_out_the_sprite(t) -> void:
	t.ok(Fx.BOLT_GLOW_A < 0.2,
		"무리 알파가 원 시절 값(0.45)에서 크게 내려왔다 (%.2f)" % Fx.BOLT_GLOW_A)
	t.ok(Fx.BOLT_GLOW_A > 0.0,
		"그래도 0은 아니다 — 세대1(8px)이 검은 배경에 묻히지 않게 받쳐 준다")


## 🔴🔴 **판정 2 — 머리가 실제 위치와 어긋나나. 값으로 잴 수 있는 절반.**
##
## `spell_view._draw_head` 는 그림을 **머리 좌표 중심의 정사각형**에 그린다 ⇒ **그림 안에서
## 코어가 치우쳐 있으면 그만큼 어긋난다.** 시뮬은 맞는데 눈에는 틀린, 에러가 안 나는 종류다.
## 🔴 `tools/pixel/crop_head.py` 가 **밝기² 무게중심으로 코어를 중앙에** 맞춰 자르는 이유가 이것이고,
##  **그 도구가 실제로 일했는지를 아무도 안 재고 있었다.**
##
## ⚠ **1px 을 요구하지 않는다** — 자르기가 정수 픽셀이라 반 픽셀은 원리적으로 남는다.
##  실측(2026-08-08): 불 **1.49px** · 무 0.59 · 물 0.89. 폭의 15%(16px 에서 2.4px)를 선으로 둔다.
## 🔴 **왜 15%인가**: 세대1은 그림이 절반(8px)이라 같은 비율이 **0.75px** 이 된다 — 이 선을 넘으면
##  세대1에서 「탄이 진행 방향에서 한 칸 밀려 보인다」가 시작될 수 있다.
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
				# 🔴 밝기의 **제곱**이다 — `crop_head.py` 와 같은 무게라야 같은 것을 잰다.
				#  선형으로 재면 어두운 가장자리가 무게를 나눠 가져 중심이 안쪽으로 끌린다.
				var v: float = maxf(c.r, maxf(c.g, c.b))
				var wgt := v * v
				sw += wgt
				sx += wgt * (float(x) + 0.5)
				sy += wgt * (float(y) + 0.5)
		if sw <= 0.0:
			continue      # 위 「비어 있지 않나」가 이미 빨갛다
		var off := Vector2(sx / sw - w * 0.5, sy / sw - h * 0.5)
		t.ok(absf(off.x) < w * 0.15 and absf(off.y) < h * 0.15,
			"룬 %d 의 코어가 중앙에 있다 (%+.2f, %+.2f)px — 그림 폭의 15%% 안" % [elem, off.x, off.y])


## 🔴🔴 **판정 4 — 룬이 화면에서 갈리나. 색으로 잴 수 있는 절반.**
##
## ⚠ **「보이나」가 아니라 「색이 다른가」다.** 눈이 갈라 보는지는 여전히 사람의 몫이고,
##  여기서 막는 것은 **「두 룬의 그림이 사실상 같은 색이 되는 것」**뿐이다 —
##  룬을 늘리다 보면 조용히 일어나고, 그때 플레이어는 **무슨 마법을 쐈는지 화면에서 못 읽는다.**
##
## 🔴 **배경을 평균에서 뺀다.** 가산 합성이라 **검정 = 투명**이고, 넣으면 셋 다 회색으로 수렴해
##  「거리가 0에 가깝다」가 나온다 — 라벨은 「색이 같다」인데 실제로 잰 것은 「배경이 같다」다.
##
## 실측(2026-08-08): 불(채도 0.92 주황) · 무(**채도 0.03 무채색**) · 물(채도 0.92 하늘).
##  거리는 0.64~1.29 다. 0.3 을 선으로 둔다.
## 🔴 **무의 채도 0.03 이 계획이 경고한 그 자리다** — 「못 쏜다」의 회색과 색축이 겹친다.
##  ⚠ **이 검사는 그 문제를 못 잡는다.** 룬끼리는 갈리기 때문이다. 사연은 `진-룬-문양.md`.
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
