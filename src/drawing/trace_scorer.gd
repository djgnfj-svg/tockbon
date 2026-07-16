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

const CONSIDER_FRAC := 0.24           # 가이드에서 이보다 멀면 이 조각과 무관(펜 뗌). 이 안이면 그린 대로 남는다
const REVEAL_RADIUS_FRAC := 0.08      # 그린 점 주변 이만큼 가이드가 드러난다(완성도)
const ACC_TOL_FRAC := 0.20            # 평균 이 정도 벗어나면 정밀도 0 — **관대**(구불구불 허용)
const COMMIT_COVER := 0.15            # 칸을 바꿀 때 이만큼 그렸으면 이전 칸을 자동 잠근다

## 조각 점수 키 — 바깥(보드)과 공유하는 규약. get_analysis가 이 키로 찾는다.
const KEY_JIN := "jin"
const KEY_RUNE := "rune"

static func glyph_key(slot: int) -> String:
	return "g%d" % slot


## 🔴 잠근 조각의 손그림 — 그린 대로 유지된다(정답 모양 교체 없음). 보드가 이 목록을 그린다.
class LockedPiece extends RefCounted:
	var target: int                    # 보드의 TraceTarget (색 구분용 — 채점기는 뜻을 모른다)
	var slot: int
	var ink: PackedVector2Array
	var glyph: int

	func _init(p_target: int, p_slot: int, p_ink: PackedVector2Array, p_glyph: int) -> void:
		target = p_target
		slot = p_slot
		ink = p_ink
		glyph = p_glyph


var _guide: PackedVector2Array = []     # 숨은 정답 선 (조밀, 로컬 좌표)
var _revealed: PackedByteArray = []     # 각 가이드 점이 드러났나 (0/1)
var _ink: PackedVector2Array = []       # 그린 먹선 (그린 대로, 렌더용)
var _dev_sum := 0.0                     # 그린 점들의 선-이탈 누적 (정밀도용)
var _dev_n := 0
var _scores: Dictionary = {}            # key → {cover, acc, score, glyph}
var _locked: Array[LockedPiece] = []    # 잠근 조각의 손그림
var _radius := 1.0                      # 길이 단위 기준 (보드의 _outer_radius) — 바깥이 준다


# ─────────────────────────── 기준 길이 · 가이드 ───────────────────────────

## 판 크기가 바뀌거나 가이드를 세울 때 바깥이 준다. 모든 거리 임계값이 이 값 비례다.
func set_reference_radius(r: float) -> void:
	_radius = maxf(r, 0.001)


## 새 가이드를 세운다 (그릴 대상이 바뀜) — 문지름 상태를 비운다.
func set_guide(pts: PackedVector2Array) -> void:
	_guide = pts
	reset_stroke()


func guide_points() -> PackedVector2Array:
	return _guide


func ink() -> PackedVector2Array:
	return _ink


func is_revealed(i: int) -> bool:
	return i >= 0 and i < _revealed.size() and _revealed[i] == 1


func locked_pieces() -> Array[LockedPiece]:
	return _locked


# ─────────────────────────── 문지르기 ───────────────────────────

## 문지름 상태를 비운다 (새 가이드 / 다시 그리기 = 덮어쓰기).
func reset_stroke() -> void:
	_revealed = PackedByteArray()
	_revealed.resize(_guide.size())
	_ink = PackedVector2Array()
	_dev_sum = 0.0
	_dev_n = 0


## 한 점을 그었다. 🔴 **그린 궤적 그대로** 먹선을 남긴다 (스냅 안 함 — 구불구불 OK).
## 가이드에서 너무 멀면(CONSIDER 밖) 이 조각과 무관한 획이라 무시하고 false를 돌려준다.
## 이탈은 정밀도로 채점(관대).
func add_point(local_pos: Vector2) -> bool:
	if _guide.is_empty():
		return false
	var best_d2 := INF
	for j in _guide.size():
		var d2 := local_pos.distance_squared_to(_guide[j])
		if d2 < best_d2:
			best_d2 = d2
	var consider := _radius * CONSIDER_FRAC
	if best_d2 > consider * consider:
		return false   # 가이드에서 너무 멀다 = 이 조각과 무관 (펜 뗌)
	_dev_sum += sqrt(best_d2)
	_dev_n += 1
	_ink.append(local_pos)               # 🔴 그린 대로 남긴다 (선에 안 붙임)
	var rr := _radius * REVEAL_RADIUS_FRAC
	var rr2 := rr * rr
	for j in _guide.size():
		if _revealed[j] == 0 and _guide[j].distance_squared_to(local_pos) <= rr2:
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


## 지금 조각 점수 = 완성도 × 정밀도 보정. 완성도가 지배하고 정밀도가 품질을 얹는다.
func piece_score() -> float:
	return coverage() * (0.5 + 0.5 * accuracy())


# ─────────────────────────── 잠금 · 분석 ───────────────────────────

## 지금 조각의 점수 + **그린 먹선**을 저장한다. 먹선은 잠근 뒤에도 그대로 렌더된다.
## 🔴 같은 조각(같은 key)을 다시 그리면 이전 먹선을 걷어내고 새것으로 교체한다 (재편집).
func lock(key: String, target: int, slot: int, glyph: int) -> float:
	var sc := piece_score()
	_scores[key] = {"cover": coverage(), "acc": accuracy(), "score": sc, "glyph": glyph}
	for i in range(_locked.size() - 1, -1, -1):
		if _locked[i].target == target and _locked[i].slot == slot:
			_locked.remove_at(i)
	_locked.append(LockedPiece.new(target, slot, _ink.duplicate(), glyph))
	return sc


func score_of(key: String) -> float:
	return float(_scores[key].score) if _scores.has(key) else 0.0


## 마법진 분석 리포트 — 조각별 점수 + 종합 + 등급. 패널이 리포트 UI로 그린다.
## open = 지금 문양본이 연 칸들 (조립 상태기계가 쥔 값 — 채점기는 모른다).
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
		"glyphs": glyphs, "total": total, "grade": _grade(total),
	}


## 종합 점수 → 등급 이름 (분석 리포트용).
func _grade(s: float) -> String:
	if s >= 0.90:
		return "명인"
	if s >= 0.75:
		return "능숙"
	if s >= 0.55:
		return "무난"
	if s >= 0.35:
		return "거침"
	return "서툼"


func clear() -> void:
	_scores = {}
	_locked = []
	set_guide(PackedVector2Array())
