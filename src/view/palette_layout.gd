extends RefCounted
## 팔레트 좌표 — 🔴🔴 **「슬롯 종류 × 항목」이다. 「문양 팔레트」가 아니다.**
##
## ```
##  ┌ 진 ──────────────┐   ← 구획 하나 = 슬롯 종류 하나
##  │  ○               │      항목은 표를 순회해서 나온다
##  ├ 룬 ──────────────┤
##  │  ●               │
##  ├ 문양 ────────────┤
##  │  ✳      ●        │
##  └──────────────────┘
## ```
##
## ⚠ **문양 전용으로 짜면 진·룬을 붙일 때 통째로 다시 짠다** — 그게 이 단계에서 제일 비싼 실수라
##  계획이 🔴🔴로 박아 뒀다. 단계 5는 **칸 둘을 늘리는 일**이어야 한다.
##
## 🔴 **항목을 손으로 적지 않는다.** 셋 다 명시 리스트를 순회하므로 표에 한 줄을 늘리면
##  팔레트가 **저절로** 는다 — 그게 「진 하나 추가 = 표 한 줄」이 참이라는 눈에 보이는 증거다.
##  ⚠ 손으로 적으면 표를 늘렸는데 팔레트가 안 늘어도 **아무도 안 짖는다.**
##
## 🔴 **그림도 클릭도 이 파일의 같은 함수를 지난다**(단계 4b-2b의 히트테스트).
##  좌표가 두 곳이면 「이걸 눌렀는데 저게 골라진다」가 되고 **에러가 안 난다.**
##
## ⚠ 팔레트는 **자기가 어느 페이지에 앉았는지 모른다** — `circle_layout`과 같은 규율이다.
##  창이 좌표계를 옮겨 주고 여기는 **크기만** 받는다.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")

## 슬롯 종류. 🔴 **이 셋이 팔레트의 축이다.**
const KIND_CIRCLE := 0
const KIND_RUNE := 1
const KIND_GLYPH := 2

## 🔴🔴 **슬롯 종류 하나 추가 = 파일 둘이다.**
##
## ```
## palette_layout.gd   const KIND_X · KIND_DEFS · KINDS · items_of 갈래   (표와 좌표)
## circle_window.gd    _draw_palette_item 갈래                            (그림)
## ```
##
## ⚠ **「넷을 넘었다」고 적었던 적이 있는데 단위가 틀린 셈이었다** — 이 리포의 「네 군데면 설계가
##  틀린 것」은 **파일 수 계약**인데 나는 줄·갈래를 세어 맞댔다. 파일 둘은 위반이 아니다.
##
## 🔴 **그래도 남길 하나: 그림이 다른 파일이라 제일 빠뜨리기 쉽다.** 표만 늘리면 그 종류가
##  **팔레트에 자리는 잡는데 아무것도 안 그려진다** — 빈 칸으로 보이고 에러는 안 난다.
##
## ⚠ 이 셈은 **문양 추가와 다른 축이다.** 문양을 늘려도 위 갈래는 안 바뀐다 —
##  문양은 전부 `KIND_GLYPH` 한 갈래로 들어가고 그 안에서 `glyph_defs`의 `kind`가 모양을 정한다.
## ⚠ 이름이 여기 있는 이유: **한 개념에 딸린 것은 한 곳에 둔다**(CLAUDE.md).
##  종류 목록과 이름 목록을 따로 만들면 둘을 손으로 맞춰야 하고, 반드시 어긋난다.
const KIND_DEFS: Dictionary = {
	KIND_CIRCLE: {"name": &"진"},
	KIND_RUNE: {"name": &"룬"},
	KIND_GLYPH: {"name": &"문양"},
}

## 🔴 순회는 **반드시 이 명시 리스트로만** 한다.
const KINDS: Array[int] = [KIND_CIRCLE, KIND_RUNE, KIND_GLYPH]


## 그 종류에 무엇이 있나. 🔴 **전부 표를 그대로 돌려준다** — 여기서 목록을 만들면
##  표를 늘렸는데 팔레트가 안 느는 날이 오고, 그 갈라짐은 조용하다.
## ⚠ 「소유」 개념이 없다 — **존재하는 것 전부**가 뜬다(던전에서 얻기는 이 단계 범위 밖).
static func items_of(kind: int) -> Array[int]:
	if kind == KIND_CIRCLE:
		return CircleDefs.ALL
	if kind == KIND_RUNE:
		return Tuning.ELEM_ALL
	if kind == KIND_GLYPH:
		return Glyph.ALL
	# 🔴 모르는 종류에 짖는다 — 표에 종류를 늘리고 여기를 안 늘리면 그 칸이 **조용히 빈다.**
	push_error("PaletteLayout: 모르는 슬롯 종류 %d — 항목이 없다" % kind)
	return []


## 종류 하나가 차지하는 구획. 🔴 **종류 수로 나눈다** — 종류가 늘면 자동으로 좁아진다.
##  상수로 박으면 진·룬 칸을 붙이는 날 구획이 겹치거나 페이지를 넘는다.
static func section(page_size: Vector2, kind_index: int) -> Rect2:
	var n := KINDS.size()
	if n <= 0 or kind_index < 0 or kind_index >= n:
		return Rect2()
	var pad := Fx.PALETTE_PAD_PX
	var gap := Fx.PALETTE_SECTION_GAP_PX
	var w := maxf(page_size.x - pad * 2.0, 0.0)
	var h := maxf((page_size.y - pad * 2.0 - gap * float(n - 1)) / float(n), 0.0)
	return Rect2(pad, pad + float(kind_index) * (h + gap), w, h)


## 구획 안에서 항목 하나가 차지하는 칸. 🔴 **항목 수로 나눈다.**
## ⚠ 제목 띠를 뺀 아래쪽만 쓴다 — 항목이 제목 위에 앉으면 둘 다 안 읽힌다.
static func item_slot(sec: Rect2, item_index: int, item_count: int) -> Rect2:
	if item_count <= 0 or item_index < 0 or item_index >= item_count:
		return Rect2()
	var head := Fx.PALETTE_HEAD_PX
	var top := sec.position.y + head
	var h := maxf(sec.size.y - head, 0.0)
	var w := sec.size.x / float(item_count)
	return Rect2(sec.position.x + float(item_index) * w, top, w, h)


## 항목 심볼의 반지름.
##
## 🔴 **칸의 짧은 변이 정한다.** 그래서 항목이 하나든 넷이든 **심볼 크기가 같다** —
##  구획 높이가 늘 짧은 변이기 때문이다. ⚠ 긴 변으로 정하면 항목 하나짜리 종류(진·룬)만
##  거대해져서 「진이 제일 중요한가」로 잘못 읽힌다.
static func item_symbol_radius(slot: Rect2) -> float:
	return minf(slot.size.x, slot.size.y) * 0.5 * Fx.PALETTE_SYMBOL_RATIO


## 🔴🔴 **무엇을 눌렀나.** `{"kind": int, "item": int}` — 아무것도 아니면 **빈 딕셔너리**다.
##
## ⚠ **그림과 같은 `section()`·`item_slot()`을 돈다.** 좌표를 여기서 다시 구하면
##  「이걸 눌렀는데 저게 골라진다」가 되고 **에러가 안 난다**(위험 6의 팔레트 얼굴).
## ⚠ 인자 `p`는 **페이지 원점 기준**이다 — 창이 `draw_set_transform`으로 옮긴 만큼을
##  호출부가 **빼서** 넘겨야 한다(위험 22).
##
## 🔴 **칸 전체가 누르는 자리다**(심볼 원이 아니라). 심볼만 하면 항목이 작을 때 못 누르고,
##  그건 「눌렀는데 아무 일도 안 난다」가 된다.
static func item_at(page_size: Vector2, p: Vector2) -> Dictionary:
	for ki in KINDS.size():
		var sec := section(page_size, ki)
		var kind: int = KINDS[ki]
		var items := items_of(kind)
		for ii in items.size():
			if item_slot(sec, ii, items.size()).has_point(p):
				return {"kind": kind, "item": items[ii]}
	return {}
