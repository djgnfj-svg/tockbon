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
