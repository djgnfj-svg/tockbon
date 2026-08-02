extends RefCounted
## 손그림 **탁본 채점기** — 순수 수학. 🔴 채점 규칙을 바꿀 땐 여기만 연다.
##
## 🔴🔴 **휴면이지 죽은 게 아니다** — `balance.skip_drawing = true`인 지금은 점수 출력
## (`coverage`·`accuracy`·`piece_score`)의 소비자가 없지만(패널이 `RingPower.assembled_score`로
## 갈라진다), 그 스위치를 false로 되돌리면 되살아난다. **지우지 마라.** 가이드 보관
## (`set_guide`/`guide_points`)은 지금도 라이브다 — 판이 밑그림을 그린다.
##
## 규칙: 조립이 정답 모양을 **숨은 선(가이드)**으로 주고, 그 위를 손으로 그으면 **그린 궤적
## 그대로**(스냅 안 함) 먹선이 남는다. 완성도 = 가이드를 얼마나 지났나 · 정밀도 = 얼마나 붙었나.
##
## Control도 기하도 모른다 — 길이 단위(px)는 바깥이 `set_reference_radius`로 준다.
##
## 사용: const TraceScorer := preload("res://src/drawing/trace_scorer.gd")

## 🔴 등급·펑 기준선을 여기 상수로 베끼지 마라 — 등급 최하단이 곧 펑 기준선이라
## 갈라지면 「무난인데 터진다」가 난다. 판정은 core(`RingPower`) 한 곳이다.
## (채점기는 "얼마나 잘 그렸나"만 잰다. "그래서 쓸 수 있나"는 다른 관심사다.)
const RingPower := preload("res://src/core/ring_power.gd")

## 이보다 멀면 가이드와 무관한 획으로 보고 **통째로 무시**한다(펜 뗌·판 여백 클릭).
## ⚠ 바깥은 공짜다 — 판정이 거리에 단조롭지 않다(살짝 삐끗=감점, 크게 삐끗=무효).
## 없앨 수는 없으니, 경계를 "이건 그리려던 게 아니다"가 분명한 데까지 밀어 둔다.
const CONSIDER_FRAC := 0.32
const REVEAL_RADIUS_FRAC := 0.08      # 그린 점 주변 이만큼 가이드가 드러난다(완성도)
## 평균 이 정도 벗어나면 정밀도 0. 이 축이 무디면 보정 펜 아이템이 통째로 죽는다.
## ⚠ 실제 손맛은 **직접 그려 봐야** 맞춘다 — 헤드리스·좌표 재생으로는 못 잰다.
## 🔴 이 값은 `piece_score` 바닥과 **곱해져 펑 기준선을 함께 움직인다** — 둘을 동시에 조이면
## "완성했는데 펑"이 난다. 따로 조이지 말고 같이 봐라.
const ACC_TOL_FRAC := 0.05

## 조각 점수 키. ⚠ 조각 잠금이 은퇴해 `_scores`는 늘 비어 있다 — 통째 점수의 정본은 `piece_score()`.
const KEY_JIN := "jin"
const KEY_RUNE := "rune"

static func glyph_key(slot: int) -> String:
	return "g%d" % slot


var _guide: PackedVector2Array = []     # 숨은 정답 선 (조밀, 로컬 좌표)
var _revealed: PackedByteArray = []     # 각 가이드 점이 드러났나 (0/1)
## 🔴 그린 먹선 = **획의 목록**(배열 하나가 아니다) — 화살표처럼 획이 여러 개인 모양을 그리려면 필요하다.
var _strokes: Array[PackedVector2Array] = []
var _dev_sum := 0.0                     # 그린 점들의 선-이탈 누적 (정밀도용)
var _dev_n := 0
var _scores: Dictionary = {}            # key → {cover, acc, score, glyph} — 잠금 은퇴 후 늘 빈다
var _radius := 1.0                      # 길이 단위 기준 (보드의 _outer_radius) — 바깥이 준다
var _correction := 0.0                  # 펜 보정도 (0=그린 대로 · 1=정답선) — 바깥이 준다


# ─────────────────────────── 기준 길이 · 가이드 ───────────────────────────

## 판 크기가 바뀌거나 가이드를 세울 때 바깥이 준다. 모든 거리 임계값이 이 값 비례다.
func set_reference_radius(r: float) -> void:
	_radius = maxf(r, 0.001)


## 펜 보정도 (0..1). 🔴 채점기는 아이템도 장비도 모른다 — 숫자 하나만 받는다.
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


# ─────────────────────────── 문지르기 ───────────────────────────

## 문지름 상태를 **전부** 비운다 (새 가이드 / 명시적 다시 그리기). 획이 통째로 사라진다.
## ⚠ 펜을 다시 대는 건 이게 아니다 — 그건 `begin_stroke`(누적)다.
func reset_stroke() -> void:
	_revealed = PackedByteArray()
	_revealed.resize(_guide.size())
	_strokes = []
	_dev_sum = 0.0
	_dev_n = 0


## 🔴 새 획을 시작한다 — 앞서 그은 획도 점수도 **그대로 남는다**(여기서 reset하면 획이 여러 개인
## 모양을 아예 못 그린다).
func begin_stroke() -> void:
	_strokes.append(PackedVector2Array())


## 한 점을 그었다. 🔴 **그린 궤적 그대로** 먹선을 남긴다(스냅 안 함).
## CONSIDER 밖이면 무관한 획이라 무시하고 false, 안쪽이면 벗어난 만큼 정밀도로 벌한다.
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

	# 🔴 펜 보정은 **판정 전에** 당긴다 — 보정된 획이 곧 내가 그린 획이라, 먹선·완성도·정밀도가
	# 전부 이 점을 봐야 좋은 펜이 셋 다 올려 준다.
	var pt := local_pos
	var dev := sqrt(best_d2)
	if _correction > 0.0 and best_j >= 0:
		pt = local_pos.lerp(_guide[best_j], _correction)
		dev *= (1.0 - _correction)

	_dev_sum += dev
	_dev_n += 1
	# `begin_stroke` 없이 들어온 점(헤드리스 테스트)도 받도록 획이 없으면 하나 연다.
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
## 바닥 0.25는 **절벽을 피하려는 것** — 완성했는데 손 떨린 획이 펑 기준선 아래로 억울하게 안 가게.
## 🔴 그런데 이 바닥은 `ACC_TOL_FRAC`과 곱해져 펑 기준선을 함께 올린다 — 둘을 동시에 조이면
## 「완성했는데 펑」이 다시 열린다. 조율은 반드시 둘을 같이 보고 하나만 푼다.
func piece_score() -> float:
	return coverage() * (0.25 + 0.75 * accuracy())


# ─────────────────────────── 분석 ───────────────────────────

## 마법진 분석 리포트 — 조각별 점수 + 종합 + 등급. 패널이 리포트 UI로 그린다.
## open = 열린 칸 목록. 🔴 채점기는 어느 칸이 열렸는지 스스로 모른다 — 바깥이 준다.
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
	set_guide(PackedVector2Array())
