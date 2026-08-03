extends RefCounted
## 진 표 → 좌표. 🔴🔴 **그림과 클릭이 같은 좌표를 쓰는 단일 소스다.**
##  좌표를 두 곳에서 계산하면 「클릭이 엉뚱한 층으로 간다」가 되고 **에러가 안 난다.**
##
## ══ 🔴🔴 축이 셋이고, 축끼리 서로를 안 부른다 ═══════════════════
## ```
##         진 축                  룬 축                층 축
## 좌표    frame()               rune_slots()        layer_rings() · layer_slots()
## 그림    _draw_frame()         _draw_rune_slot()   _draw_ring()      ← circle_window
## ```
## ⚠ **룬이 둘이 되는 날 열리는 것은 룬 열 둘뿐이고 층·진 코드는 안 열린다.** 한 덩어리로 짜면
##  조립창을 통째로 다시 만든다 — 기획 「경계」가 이 단계에 요구한 것이 그것 하나다.
##
## ⚠ **셋이 `_center`·`_radius` 하나를 같이 쓰는 것은 축을 섞는 게 아니다.** 그 반대다 —
##  각자 중심을 구하면 **중심이 세 곳**이 되고, 창 크기를 바꾸는 날 셋이 따로 논다.
##  🔴 축 분리는 「누가 무엇을 정하나」의 분리지 「같은 원반을 공유하지 마라」가 아니다.
## ══════════════════════════════════════════════════════════════════
##
## 🔴 **층 수·룬 자리 수는 전부 `circle_defs` 표에서 나온다.** 여기 2·1을 박으면
##  「모델은 3층인데 셋째 고리가 안 그려진다」가 되고, 그건 층 수가 안 따라오는 것보다 **더 나쁘다**
##  (시뮬만 늘고 화면이 안 따라가는 것 = v1이 죽은 방식). `net_circle`이 텍스트로 잰다.
##
## ⚠ 치수 비율은 전부 `fx_tuning`이다 — 여기에 숫자를 적지 않는다.

const CircleDefs := preload("res://src/sim/circle_defs.gd")
const Fx := preload("res://src/view/fx_tuning.gd")


## 주어진 상자 안에서 마법진이 앉는 자리. **상자 원점 기준**이다.
##
## 🔴🔴 **마법진은 자기가 어디에 앉았는지 모른다.** 창이 좌표계를 옮겨 주고
##  (`circle_window`의 `draw_set_transform`) 여기는 **크기만** 받는다 —
##  페이지 사각형을 넘기면 **마법진 축이 창 축에 매달린다.**
## ⚠ 그래서 인자가 `Rect2`가 아니라 `Vector2`다. 자리를 아는 순간 창 모양이 바뀔 때마다
##  이 파일이 같이 열린다(§2의 「축이 서로를 안 부른다」와 같은 정신).
## ⚠ **그림도 클릭도 이 함수를 지난다**(단계 4b).
static func circle_area(box: Vector2) -> Rect2:
	var pad := Fx.CIRCLE_AREA_PAD_PX
	return Rect2(pad, pad, maxf(box.x - pad * 2.0, 0.0), maxf(box.y - pad * 2.0, 0.0))


# ─── 진 축 ────────────────────────────────────────────────────────

## 진 테두리. 진이 없어도 **자리는 있다** — 그게 「빈 슬롯」이다.
static func frame(area: Rect2) -> Dictionary:
	return {"center": _center(area), "radius": _radius(area)}


## 진 슬롯을 눌렀나. 🔴 **테두리 안 전체가 진의 자리다** — 층·룬 자리를 뺀 나머지고,
##  그 우선순위는 호출부가 정한다(안쪽 것을 먼저 본다).
## ⚠ **진이 없어도 참이다.** 그래야 진을 뺀 사용자가 다시 놓을 수 있다 — 아니면 **갇힌다.**
static func frame_has_point(area: Rect2, p: Vector2) -> bool:
	return p.distance_to(_center(area)) <= _radius(area)


# ─── 룬 축 ────────────────────────────────────────────────────────

## 룬 자리의 중심들. 길이 = `circle_defs.rune_slots`.
##
## 🔴 **`rune_slots != 1`에 짖는다.** 진을 늘리면서 룬을 어떻게 늘어놓을지 안 정하면
##  래퍼의 stderr 검사에 **공짜로** 걸린다(`spell_sim._run_glyph`와 같은 장치다).
##  ⚠ 융합은 두 자리가 맞물리고 병렬은 떨어져 있다 — **배치가 곧 진의 그림이라** 자동으로 못 정한다.
## ⚠ 자리가 0개(진 없음)인 것은 **정상**이라 안 짖는다.
static func rune_slots(circle_id: int, area: Rect2) -> PackedVector2Array:
	var n := CircleDefs.rune_slots(circle_id)
	var out := PackedVector2Array()
	if n <= 0:
		return out
	if n != 1:
		push_error("CircleLayout: 룬 자리 %d개짜리 진의 배치가 아직 없다" % n)
		return out
	# 룬은 한가운데다. 🔴 그래서 층 고리가 **룬을 감싸며 밖으로** 자라고,
	#  「안쪽이 먼저」가 그림 자체에 들어간다.
	out.append(_center(area))
	return out


## 룬 자리 그림의 반지름.
static func rune_radius(area: Rect2) -> float:
	return _radius(area) * Fx.CIRCLE_RUNE_RATIO


# ─── 층 축 ────────────────────────────────────────────────────────

## 층 고리의 반지름들. 길이 = `circle_defs.layers`. 안쪽(1층)이 먼저다.
##
## 🔴🔴 **층 수로 나눠서 파생시킨다.** 상수 둘을 박으면 3층 진이 오는 날 고리가 겹치고,
##  겹친 그림은 「층이 둘인지 셋인지」를 화면에서 못 세게 만든다.
static func layer_rings(circle_id: int, area: Rect2) -> PackedFloat32Array:
	var n := CircleDefs.layers(circle_id)
	var out := PackedFloat32Array()
	if n <= 0:
		return out
	var zone := _radius(area) * Fx.CIRCLE_RING_ZONE
	for i in n:
		out.append(zone * float(i + 1) / float(n))
	return out


## 문양이 앉는 점들. 🔴🔴 **그림과 클릭이 이 함수 하나를 쓴다**(단계 4의 히트테스트).
## ⚠ 같은 축이라 `layer_rings`를 부른다 — 반지름을 여기서 다시 구하면 그게 두 벌이다.
static func layer_slots(circle_id: int, area: Rect2) -> PackedVector2Array:
	var c := _center(area)
	var out := PackedVector2Array()
	# 12시 방향. ⚠ 층마다 각도를 흩으면 「어느 고리의 문양인가」가 안 읽힌다.
	for r: float in layer_rings(circle_id, area):
		out.append(c + Vector2(0.0, -r))
	return out


## 문양 심볼의 반지름.
static func glyph_radius(area: Rect2) -> float:
	return _radius(area) * Fx.CIRCLE_GLYPH_RATIO


## 🔴🔴 **어느 층을 눌렀나.** 없으면 -1.
##  ⚠ **그림과 같은 `layer_slots()`·`glyph_radius()`를 쓴다.** 좌표를 여기서 다시 구하면
##   「클릭이 엉뚱한 층으로 간다」가 되고 **에러가 안 난다**(위험 6).
## ⚠ 인자 `p`는 **상자 원점 기준**이다 — 창이 `draw_set_transform`으로 옮긴 만큼을
##  호출부가 **빼서** 넘겨야 한다(위험 22). 안 빼면 조용히 어긋난다.
## ⚠ 누르는 원이 심볼보다 크다 — 심볼만 하면 빈 층을 정확히 겨냥해야 해서 못 누른다.
static func layer_at(circle_id: int, area: Rect2, p: Vector2) -> int:
	var slots := layer_slots(circle_id, area)
	var r := glyph_radius(area) * Fx.SLOT_HIT_RATIO
	for i in slots.size():
		if p.distance_to(slots[i]) <= r:
			return i
	return -1


## 어느 룬 자리를 눌렀나. 없으면 -1. ⚠ 위와 같은 규율이다.
static func rune_slot_at(circle_id: int, area: Rect2, p: Vector2) -> int:
	var slots := rune_slots(circle_id, area)
	var r := rune_radius(area) * Fx.SLOT_HIT_RATIO
	for i in slots.size():
		if p.distance_to(slots[i]) <= r:
			return i
	return -1


## 층 번호의 글자 크기. 🔴 **반지름에서 파생한다** — 박으면 진이 커질 때 번호만 얼어붙고,
##  그건 「안쪽이 먼저」를 말하는 장치 둘 중 하나가 **약해지는** 방향이다(기획 판정 3).
static func layer_num_size(area: Rect2) -> int:
	return maxi(int(_radius(area) * Fx.CIRCLE_LAYER_NUM_RATIO), Fx.CIRCLE_LAYER_NUM_MIN)


# ─── 셋이 같이 쓰는 원반 ──────────────────────────────────────────
# ⚠ 위 주석 참고 — 이걸 공유하는 것이 축을 섞는 게 아니라 **중심이 세 곳이 되는 것을 막는다.**

## 마법진의 한가운데. 🔴 **어느 축에도 안 속한다** — 그래서 공개다.
##  ⚠ 층을 그리려고 `frame()`을 부르면 **층 축이 진 축에 매달린다.** 진이 여러 개인 진
##   (문양이 룬마다)이 오는 날 `frame()`이 여럿을 돌려주게 되고, 그때 층 코드가 같이 깨진다.
static func center(area: Rect2) -> Vector2:
	return _center(area)


static func _center(area: Rect2) -> Vector2:
	return area.get_center()


static func _radius(area: Rect2) -> float:
	return minf(area.size.x, area.size.y) * 0.5 * Fx.CIRCLE_DISC_RATIO
