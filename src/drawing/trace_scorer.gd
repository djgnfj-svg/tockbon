extends RefCounted
## 손그림 **탁본 채점기** — 순수 수학 (2026-07-17 세션 22, ring_board 757줄에서 분리).
##
## 🔴 **채점 규칙을 바꿀 땐 여기만 연다.** [[takbon-core-fun-drawing]]이 *"핵심 재미 = 그리는 것"*이라
## 이 규칙은 매 세션 바뀐다 — 예전엔 채점 하나 고치려면 렌더·입력을 소유한 757줄 Control을 열어야 했다.
##
## 규칙 (세션 14b~14c, 사용자 확정 · 정본 = memory takbon-hand-trace-commit):
##   조립이 정답 모양을 **숨은 선(가이드)**으로 준다. 그 위를 손으로 그리면 **그린 궤적 그대로**
##   (스냅 안 함) 먹선이 남는다 — 구불구불해도 된다, **자기만의 마법진**. 너무 벗어난 획만 무시한다.
##     • 완성도(coverage) = 가이드를 얼마나 지났나
##     • 정밀도(accuracy) = 선에 얼마나 가깝게 그렸나 (관대)
##   조각마다 점수 → [다음]으로 수동 진행(마음에 안 들면 다시 그려 덮어씀) → 다 그리면 분석 리포트.
##   🔴 잠근 조각은 **그린 먹선을 그대로 유지**한다 — 정답 모양으로 안 바꾼다.
##
## Control도 기하도 모른다 — 길이 단위(px)는 바깥이 `set_reference_radius`로 준다.
##
## 사용: const TraceScorer := preload("res://src/drawing/trace_scorer.gd")

## 🔴 등급 이름은 **여기서 정하지 않는다** (세션 24에 `_grade`를 걷어냈다). 등급의 최하단이
## 곧 펑 기준선이라, 채점기가 자기 상수로 베껴 적으면 balance의 기준선과 조용히 갈라진다 —
## 세션 23의 「무난인데 터진다」가 정확히 그 어긋남이었다. core가 한 곳에서 판다.
## (채점기 = "얼마나 잘 그렸나"만 잰다. "그래서 쓸 수 있나"는 다른 관심사다.)
const RingPower := preload("res://src/core/ring_power.gd")

## 🔴 **이 조각을 그리려던 획인가**의 경계 (세션 23에 0.24 → 0.32). 이보다 멀면 다른 조각을
## 겨눈 획으로 보고 **통째로 무시**한다 (옆 칸 문양을 그리는 중일 수 있다 — 8칸 고리에서
## 이웃 칸까지는 약 0.46R이라 그 안쪽에서 끊어야 남의 칸 획을 내 점수로 채점하지 않는다).
## ⚠ **여기 바깥은 공짜다** — 판정이 거리에 대해 단조롭지 않다(살짝 삐끗=감점, 크게 삐끗=무효).
## 없앨 수는 없다(펜 뗌·옆 칸 획을 걸러야 한다). 대신 경계를 "이건 그리려던 게 아니다"가
## 분명한 데까지 밀어, 공짜 구간이 **일부러 딴 데 긋는 경우**에만 남게 한다.
const CONSIDER_FRAC := 0.32
const REVEAL_RADIUS_FRAC := 0.08      # 그린 점 주변 이만큼 가이드가 드러난다(완성도)
## 🔴 평균 이 정도 벗어나면 정밀도 0. **세션 23에 0.20 → 0.08로 조였다** (사용자 확정).
## 왜: 0.20은 진 반지름(≈119px)의 5분의 1 — 평균 24px이나 어긋나야 0이라, 눈에 띄게 다른
## 모양을 그려야 감점이었다. 사실상 점수 = 완성도(빠짐없이 덧칠)였고 **정성껏 긋는 사람이
## 손해**를 봤다. 그리고 보정 **펜 아이템이 팔 물건이 정밀도**라, 이 축이 무뎌 있으면
## 좋은 펜을 껴도 점수가 안 변해 아이템이 죽는다 — 펜의 전제조건이다.
## ⚠ 실제 손맛은 **직접 그려 보고** 맞춰야 한다 (헤드리스·좌표 재생으로는 절대 못 잰다).
## 🔴 **세션 53에 0.08 → 0.05로 더 조였다** (사용자: *"마법진이 그냥 대충 그려도 인정되는 게 별로네"*).
## 정밀도 자체를 엄하게 — 평균 이탈이 반지름의 5%(≈5.9px)만 돼도 정밀도 0이라, "선에 붙여
## 긋는 사람"과 "대충 지나가는 사람"의 격차가 벌어진다. ⚠ 이건 **시작값**이다 — 맨손이 이만큼
## 어려워도 되는지는 사용자가 직접 그려 보며 조인다(0.04~0.06 사이).
## ⚠ 이 값은 `piece_score` 바닥(0.25)과 **곱해져 펑(65) 기준선을 함께 움직인다** — 따로 조이지
## 말고 같이 봐라(자세한 상호작용은 `piece_score` 주석). 둘을 동시에 조이면 "완성했는데 펑"이 난다.
const ACC_TOL_FRAC := 0.05
const COMMIT_COVER := 0.15            # 칸을 바꿀 때 이만큼 그렸으면 이전 칸을 자동 잠근다

## 조각 점수 키 — 바깥(보드)과 공유하는 규약. get_analysis가 이 키로 찾는다.
const KEY_JIN := "jin"
const KEY_RUNE := "rune"

static func glyph_key(slot: int) -> String:
	return "g%d" % slot


## 🔴 잠근 조각의 손그림 — 그린 대로 유지된다(정답 모양 교체 없음). 보드가 이 목록을 그린다.
## 🔴 먹선은 **획들**이다 (세션 25) — 한 조각이 여러 획으로 이뤄진다. 이어 붙이면 안 된다:
## 획과 획 사이(펜을 뗀 구간)를 선으로 그으면 화살표가 삼각형이 된다.
class LockedPiece extends RefCounted:
	var target: int                    # 보드의 TraceTarget (색 구분용 — 채점기는 뜻을 모른다)
	var slot: int
	var strokes: Array[PackedVector2Array]
	var glyph: int

	func _init(p_target: int, p_slot: int, p_strokes: Array[PackedVector2Array], p_glyph: int) -> void:
		target = p_target
		slot = p_slot
		strokes = p_strokes
		glyph = p_glyph


var _guide: PackedVector2Array = []     # 숨은 정답 선 (조밀, 로컬 좌표)
var _revealed: PackedByteArray = []     # 각 가이드 점이 드러났나 (0/1)
## 🔴 그린 먹선 = **획의 목록** (그린 대로, 렌더용). 세션 25에 `PackedVector2Array` 하나에서
## 바뀌었다 — 하나였을 땐 한 조각에 획이 하나뿐이라, 화살표처럼 획이 여러 개인 모양을
## **물리적으로 그릴 수 없었다** (사용자: "획단위로 초기화되서 화살표를 그리기가 어렵네?").
var _strokes: Array[PackedVector2Array] = []
var _dev_sum := 0.0                     # 그린 점들의 선-이탈 누적 (정밀도용)
var _dev_n := 0
var _scores: Dictionary = {}            # key → {cover, acc, score, glyph}
var _locked: Array[LockedPiece] = []    # 잠근 조각의 손그림
var _radius := 1.0                      # 길이 단위 기준 (보드의 _outer_radius) — 바깥이 준다
var _correction := 0.0                  # 펜 보정도 (0=그린 대로 · 1=정답선) — 바깥이 준다


# ─────────────────────────── 기준 길이 · 가이드 ───────────────────────────

## 판 크기가 바뀌거나 가이드를 세울 때 바깥이 준다. 모든 거리 임계값이 이 값 비례다.
func set_reference_radius(r: float) -> void:
	_radius = maxf(r, 0.001)


## 🔴 펜 보정도 (0..1) — 바깥(보드)이 `GameState.stroke_correction()`에서 읽어 준다.
## 채점기는 아이템도 장비도 모른다 — 숫자 하나만 받는다 (set_reference_radius와 같은 규약).
func set_correction(v: float) -> void:
	_correction = clampf(v, 0.0, 1.0)


func correction() -> float:
	return _correction


## 새 가이드를 세운다 (그릴 대상이 바뀜) — 문지름 상태를 비운다.
func set_guide(pts: PackedVector2Array) -> void:
	_guide = pts
	reset_stroke()


func guide_points() -> PackedVector2Array:
	return _guide


## 그린 먹선 = 획의 목록. 보드가 획마다 따로 polyline을 긋는다 (이어 그으면 안 된다).
func strokes() -> Array[PackedVector2Array]:
	return _strokes


func is_revealed(i: int) -> bool:
	return i >= 0 and i < _revealed.size() and _revealed[i] == 1


func locked_pieces() -> Array[LockedPiece]:
	return _locked


# ─────────────────────────── 문지르기 ───────────────────────────

## 문지름 상태를 **전부** 비운다 (새 가이드 / 명시적 다시 그리기). 획이 통째로 사라진다.
## ⚠ 펜을 다시 대는 건 이게 아니다 — 그건 `begin_stroke`(누적)다.
func reset_stroke() -> void:
	_revealed = PackedByteArray()
	_revealed.resize(_guide.size())
	_strokes = []
	_dev_sum = 0.0
	_dev_n = 0


## 🔴 **새 획을 시작한다** (펜을 다시 댔다) — 앞서 그은 획도 점수도 **그대로 남는다** (세션 25).
## 세션 24까지 펜을 대는 순간 `reset_stroke`가 불려 한 조각 = **한 획**이 강제됐다: 선을 긋고
## 펜을 떼서 화살촉을 그리면 앞의 선이 사라져, 획이 여러 개인 모양은 아예 못 그렸다.
## 완성도·정밀도가 획 사이에 이어지는 게 요점이다 — 조각 하나를 여러 번에 나눠 그린 것이다.
func begin_stroke() -> void:
	_strokes.append(PackedVector2Array())


## 한 점을 그었다. 🔴 **그린 궤적 그대로** 먹선을 남긴다 (스냅 안 함 — 구불구불 OK).
## 가이드에서 너무 멀면(CONSIDER 밖) **다른 조각을 겨눈 획**이라 무시하고 false를 돌려준다.
## 그 안쪽은 **벗어난 만큼 정밀도로 벌한다** (사용자 확정 세션 23: "벗어난 만큼 벌한다").
func add_point(local_pos: Vector2) -> bool:
	if _guide.is_empty():
		return false
	var best_d2 := INF
	var best_j := -1
	for j in _guide.size():
		var d2 := local_pos.distance_squared_to(_guide[j])
		if d2 < best_d2:
			best_d2 = d2
			best_j = j
	var consider := _radius * CONSIDER_FRAC
	if best_d2 > consider * consider:
		return false   # 가이드에서 너무 멀다 = 이 조각과 무관 (펜 뗌)

	# 🔴 **펜 보정** (세션 23) — 그은 점을 가이드 쪽으로 당긴다. 보정도 0이면 손 그대로다.
	# ⚠ **판정 전에 당긴다** — 보정된 획이 곧 내가 그린 획이다. 먹선·완성도·정밀도가 전부
	# 이 점을 보므로 좋은 펜은 셋 다 올려 준다 (사용자: "펜등급마다 보정도가 오르는거임").
	# 당김은 항상 가장 가까운 가이드 점 쪽이라, 이탈은 정확히 (1-보정도)배가 된다.
	var pt := local_pos
	var dev := sqrt(best_d2)
	if _correction > 0.0 and best_j >= 0:
		pt = local_pos.lerp(_guide[best_j], _correction)
		dev *= (1.0 - _correction)

	_dev_sum += dev
	_dev_n += 1
	# 🔴 보정 없으면 그린 대로 (선에 안 붙임). 지금 획에 얹는다 — `begin_stroke` 없이 들어온
	# 점(헤드리스 테스트가 그런다)도 받도록 획이 없으면 하나 연다.
	if _strokes.is_empty():
		_strokes.append(PackedVector2Array())
	_strokes[_strokes.size() - 1].append(pt)
	var rr := _radius * REVEAL_RADIUS_FRAC
	var rr2 := rr * rr
	for j in _guide.size():
		if _revealed[j] == 0 and _guide[j].distance_squared_to(pt) <= rr2:
			_revealed[j] = 1
	return true


# ─────────────────────────── 점수 ───────────────────────────

## 완성도 = 가이드를 얼마나 드러냈나 (0~1).
func coverage() -> float:
	if _guide.is_empty():
		return 0.0
	var n := 0
	for r in _revealed:
		n += r
	return float(n) / float(_guide.size())


## 정밀도 = 문지른 점들이 선에 얼마나 붙었나 (0~1). 문지른 게 없으면 0.
func accuracy() -> float:
	if _dev_n == 0:
		return 0.0
	var tol := _radius * ACC_TOL_FRAC
	if tol <= 0.0:
		return 0.0
	return clampf(1.0 - (_dev_sum / float(_dev_n)) / tol, 0.0, 1.0)


## 지금 조각 점수 = 완성도 × 정밀도 보정.
## 🔴 **세션 53에 정밀도 바닥을 0.5 → 0.25로 낮췄다** (사용자: *"대충 그려도 인정되는 게 별로네"*).
## 전엔 정밀도 0이어도 완성도의 절반(0.5)을 먹어 **완성도가 지배**했다 — 삐뚤빼뚤 가이드만 훑으면
## 고득점이라 "대충"이 인정됐다. 이제 정밀도가 점수의 75%를 쥔다: 대충 그림(정밀도≈0)은 완성도의
## 25%만 받아 확연히 벌점. 바닥을 0(순수 곱)이 아니라 0.25로 둔 건 **절벽을 피하려는 것** —
## 완성했는데 손 떨려 삐뚤한 획도 25%는 받아, 마법진 전체가 65 펑 기준선 아래로 억울하게
## 처박히지 않는다(세션 23 「잘 그렸는데 터진다」의 재발 방지). ⚠ 0.2~0.3은 **시작값** — 사용자 몫.
## 🔴 **그러나 이 바닥은 `ACC_TOL_FRAC` 조임과 곱해져 펑(65) 기준선을 함께 올린다**(세션53 리뷰 지적):
## 완성도 1이어도 안 펑이려면 `0.25+0.75·acc > 0.65` → **acc>0.53**(평균 이탈<2.8px)이라야 한다.
## 즉 정성껏 그었지만 완벽친 않은(dev≈3px) 획도 펑날 수 있어, 위 「재발 방지」가 tol 조임과 곱해지면
## 역설적으로 그 재발을 다시 연다. 조율할 땐 이 바닥과 `ACC_TOL_FRAC`을 **따로가 아니라 같이** 보고
## 「완성했는데 억울하게 펑」이 나는지 관찰해라 — 그러면 둘 중 하나를 푼다(둘을 동시에 조이지 마라).
func piece_score() -> float:
	return coverage() * (0.25 + 0.75 * accuracy())


# ─────────────────────────── 잠금 · 분석 ───────────────────────────

## 지금 조각의 점수 + **그린 먹선**을 저장한다. 먹선은 잠근 뒤에도 그대로 렌더된다.
## 🔴 같은 조각(같은 key)을 다시 그리면 이전 먹선을 걷어내고 새것으로 교체한다 (재편집).
func lock(key: String, target: int, slot: int, glyph: int) -> float:
	var sc := piece_score()
	_scores[key] = {"cover": coverage(), "acc": accuracy(), "score": sc, "glyph": glyph}
	for i in range(_locked.size() - 1, -1, -1):
		if _locked[i].target == target and _locked[i].slot == slot:
			_locked.remove_at(i)
	var copy: Array[PackedVector2Array] = []
	for s in _strokes:
		copy.append(s.duplicate())     # 획마다 복사 — 얕게 담으면 다음 조각이 덮어쓴다
	_locked.append(LockedPiece.new(target, slot, copy, glyph))
	return sc


func score_of(key: String) -> float:
	return float(_scores[key].score) if _scores.has(key) else 0.0


## 마법진 분석 리포트 — 조각별 점수 + 종합 + 등급. 패널이 리포트 UI로 그린다.
## open = 지금 진이 연 칸들 (JinDef.glyph_slots → 조립 상태기계가 쥔 값 — 채점기는 모른다).
func get_analysis(open: Array) -> Dictionary:
	var glyphs: Array = []
	for k in open:
		var key := glyph_key(int(k))
		if _scores.has(key):
			var e: Dictionary = _scores[key]
			glyphs.append({"slot": int(k), "glyph": int(e.glyph),
				"cover": float(e.cover), "acc": float(e.acc), "score": float(e.score)})
	var vals: Array = []
	if _scores.has(KEY_JIN):
		vals.append(float(_scores[KEY_JIN].score))
	if _scores.has(KEY_RUNE):
		vals.append(float(_scores[KEY_RUNE].score))
	for g in glyphs:
		vals.append(float(g.score))
	var total := 0.0
	for v in vals:
		total += float(v)
	total = total / float(vals.size()) if not vals.is_empty() else 0.0
	return {
		"jin": _scores.get(KEY_JIN, null), "rune": _scores.get(KEY_RUNE, null),
		"glyphs": glyphs, "total": total, "grade": RingPower.grade_of(total),
	}




func clear() -> void:
	_scores = {}
	_locked = []
	set_guide(PackedVector2Array())
