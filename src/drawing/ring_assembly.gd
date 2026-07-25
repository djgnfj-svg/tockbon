extends RefCounted
## 고리 **조립 상태기계** — 순수 데이터 (2026-07-17 세션 22, ring_board 757줄에서 분리).
##
## 무엇이 놓였고 어느 칸이 열렸는지만 안다. **Control도 렌더도 입력도 모른다** — 헤드리스로
## 완전히 테스트된다(tests/test_ring_assembly_auto.gd).
##
## 모델 (사용자 확정 2026-07-16 · memory takbon-ring-assembly-pivot):
##   • 진 = 바깥 그릇(경계). ⚠ **세85 ⑦: 「진이 칸을 연다」(`glyph_slots`) 축은 은퇴했다** —
##     라이브에서 열린 칸은 `ring_forge_panel.build_assembly()`가 층에 놓인 칸의 합집합으로 만든다.
##     여기 `_open`은 이제 **아무도 안 바꾸는 폴백 [0, 2]**다(진의 개성은 band_count·rune_slots가 쥔다).
##   • 룬 = 중심 속성 — 지금은 불만
##   • 문양 = 열린 칸을 채우는 조각 (응집←/발산→)
##
## 🔴 **순차 조립** (세션 13): 빈 판 → 진 → 룬 → 문양 한 칸씩. 일괄 자동채움은 "툭 완성"돼
## 조립하는 맛을 죽여서 걷어냈다.
##
## 사용: const RingAssembly := preload("res://src/drawing/ring_assembly.gd")

const SLOTS := 8
const GLYPH_NONE := -1

# ── 조립 단계 — 옛 자유드로잉과 **같은 문법**(Enums.DrawStage 재사용, 세션 13):
##   진(CIRCLE) → 룬(RUNE) → 문양(ARROW). 옛 캔버스가 이 순서를 강제하던 그 열거형이다.
const STAGE_JIN := Enums.DrawStage.CIRCLE    # 진(그릇)을 놓을 차례
const STAGE_RUNE := Enums.DrawStage.RUNE     # 룬(중심)을 놓을 차례
const STAGE_GLYPH := Enums.DrawStage.ARROW   # 문양을 한 칸씩 얹을 차례

const RUNE_FIRE := 0   # 기본 룬 (불) — 아직 안 고른 판·옛 도안의 폴백
const RUNE_NONE := -1  # 룬 자리 미선택 (세81 M2 — 다중 룬 자리의 빈 표식)

var _stage: int = STAGE_JIN
var _has_jin := false
## 🔴 룬 단계를 잠갔나 (문양 단계로 넘어갔나) — 세81 M2 전엔 `_has_rune` 하나였다.
## "룬이 놓였나"(has_rune)와 "단계를 잠갔나"(이 값)를 나눈 건, 융합진에서 **룬을 다 고르기 전엔
## 잠기면 안 되기** 때문이다(첫 룬만 골라도 has_rune은 참이지만 아직 안 잠근다).
var _runes_locked := false
## 🔴 고른 룬들 (Enums.RuneType 배열, 자리 순서). 세81 M2 — 룬 하나(`_rune: int`)에서 자리별
## 목록으로. size = `_rune_slots`(진이 정함), 빈 자리 = `RUNE_NONE`. 세션 34 전엔 RUNE_FIRE로
## 하드코딩돼 물·바람을 그려도 불로 나갔다 — 이제 get_assembly가 목록을 실어 저장·발사까지 흐른다.
## 🔴 룬 1개 진(일반진)은 `[불]` 하나라 M1과 계산이 완전히 동일하다(무회귀).
var _runes: Array[int] = [RUNE_NONE]
## 🔴 이 진이 요구하는 룬 자리 수 (JinDef.rune_slots). choose_jin이 `set_rune_slots`로 채운다.
## 기본 1 = 일반진(중심 하나). 융합진 = 2(중심 좌우).
var _rune_slots := 1
## 🔴 고른 진 id (세션44, 진=형태). 진은 **손으로 안 긋고 고른다**(선택) — 지팡이(진)를 골라 그 위에
## 룬·문양을 그린다. get_assembly가 실어 저장·발사(형태)까지 흐른다. 빈 값 = 폴백(발사부가 처리).
var _jin: StringName = &""
var _open: Array[int] = [0, 2]      # 열린 칸들 — 폴백 고정값 (세85 ⑦에 이걸 덮던 축이 은퇴했다)
var _slots: Array[int] = []         # SLOTS개, 값 = 문양 코드 or GLYPH_NONE (열린 칸만 채워진다)


func _init() -> void:
	_reset_slots()


# ─────────────────────────── 조회 ───────────────────────────

func stage() -> int:
	return _stage

func has_jin() -> bool:
	return _has_jin

## 🔴 룬이 **적어도 하나** 놓였나 (밑그림에 룬 중심이 뜨나·구조 힌트를 그리나). 세81 M2 전엔
## "룬을 골랐나"와 같은 뜻이었다. 융합진에서 첫 룬만 골라도 참이다 — "다 골랐나"는 `runes_ready`.
func has_rune() -> bool:
	for r in _runes:
		if r != RUNE_NONE:
			return true
	return false

## 🔴 룬 자리를 **전부** 채웠나 (세81 M2) — 잠금·발사(맺기)의 게이트. 일반진(자리 1)은
## 룬 하나 고르면 참이라 옛 흐름과 같다.
func runes_ready() -> bool:
	if _runes.size() < _rune_slots:
		return false
	for i in _rune_slots:
		if _runes[i] == RUNE_NONE:
			return false
	return true

func get_open() -> Array[int]:
	return _open

## 🔴 primary 룬 (첫 자리) — 옛 소비자(발사·요약·HUD)가 룬 하나를 읽던 자리의 무회귀.
## 아무 자리도 안 골랐으면 RUNE_FIRE 폴백(옛 판의 기본과 동일).
func get_rune() -> int:
	for r in _runes:
		if r != RUNE_NONE:
			return r
	return RUNE_FIRE

## 🔴 고른 룬 목록 (자리 순서, 빈 자리 제외). 발사·저장 계약의 다중 룬 정본.
func get_runes() -> Array[int]:
	var out: Array[int] = []
	for r in _runes:
		if r != RUNE_NONE:
			out.append(r)
	return out

## 이 진의 룬 자리 수 (관측점).
func rune_slots() -> int:
	return _rune_slots

func get_jin() -> StringName:
	return _jin

## 🔴 진을 고른다 (세션44) — 손으로 긋지 않는다. 언제든 바꿀 수 있다(발사 형태 선택).
func set_jin(id: StringName) -> void:
	_jin = id


## 🔴 이 진의 룬 자리 수를 정한다 (세81 M2 — choose_jin이 JinDef.rune_slots로 부른다).
## `_runes`를 n칸으로 맞추고 겹치는 옛 선택은 보존한다(glyph 밴드 `_resize_bands` 선례).
## ⚠ 잠근 뒤엔 안 바꾼다(문양 단계에서 자리 수가 흔들리면 도안이 조용히 어긋난다).
func set_rune_slots(n: int) -> void:
	if _runes_locked:
		return
	_rune_slots = maxi(n, 1)
	var old := _runes
	_runes = []
	for i in _rune_slots:
		_runes.append(old[i] if i < old.size() else RUNE_NONE)


## 🔴 룬 자리 하나에 룬 종류를 넣는다 (Enums.RuneType). 룬 단계에서만·잠그기 전.
## `slot` = 넣을 자리(0부터). **-1 = 다음 빈 자리**(없으면 첫 자리) — 무인자 옛 호출자
## `choose_rune(rune_type)`(자리 1개 진)가 그대로 슬롯0을 채우게 하는 무회귀 경로다.
func set_rune(rune_type: int, slot: int = -1) -> void:
	if _stage != STAGE_RUNE or _runes_locked:
		return
	if _runes.is_empty():
		return
	var k := slot
	if k < 0:
		k = _next_empty_rune_slot()
	if k < 0 or k >= _runes.size():
		return
	_runes[k] = rune_type


## 다음 빈 룬 자리 (없으면 0 — 다 찼으면 첫 자리를 덮어쓴다).
func _next_empty_rune_slot() -> int:
	for i in _runes.size():
		if _runes[i] == RUNE_NONE:
			return i
	return 0

func glyph_at(slot: int) -> int:
	return _slots[slot] if slot >= 0 and slot < SLOTS else GLYPH_NONE

func filled_count() -> int:
	var n := 0
	for k in _open:
		if _slots[k] != GLYPH_NONE:
			n += 1
	return n


## 열린 칸 중 아직 빈 첫 칸 (없으면 -1). 채우는 순서 = 진이 연 순.
func next_open_slot() -> int:
	for k in _open:
		if _slots[k] == GLYPH_NONE:
			return k
	return -1


func is_open_slot(k: int) -> bool:
	return k in _open


## 🔴 진은 문양이 없어도(빈 진) 날아가 맞는다 — 단, **진과 룬(모든 자리)이 놓여 있어야** 마법진이다
## (세션 13 · 세81 M2: 융합진은 두 자리를 다 채워야 맺힌다).
func can_commit() -> bool:
	return _has_jin and runes_ready()


## 🔴 조립 결과 스냅샷 = **발사 계약**. 발사(ring_spell_system)·저장(RingDesign)이 이걸 읽는다.
## ⚠ 모양을 바꾸면 둘 다 조용히 깨진다 (tests/test_ring_assembly_auto.gd가 못 박아 둔다).
func get_assembly() -> Dictionary:
	return {"ring_count": 1, "rune": get_rune(), "runes": get_runes(),
		"jin": _jin, "rings": [Array(_slots)], "open": _open.duplicate()}


# ─────────────────────────── 상태 전이 ───────────────────────────

## 진을 잠갔다 → 룬 단계로.
func lock_jin() -> void:
	_has_jin = true
	_stage = STAGE_RUNE


## 룬을 잠갔다 → 문양 단계로. 🔴 세81 M2: **모든 룬 자리가 차야** 잠근다 — 융합진에서 첫 룬만
## 골랐는데 잠기면 도안에 빈 자리가 남는다(발사 계약이 룬 하나만 실어 나감). 아직이면 무시한다
## (호출부 = ring_board 트레이스 잠금이 룬을 다 안 골랐을 때 이걸 부를 수 있다).
func lock_rune() -> void:
	if not runes_ready():
		return
	_runes_locked = true
	_stage = STAGE_GLYPH


## 문양 한 칸을 채운다 (열린 칸만).
func place_glyph(slot: int, glyph: int) -> void:
	if slot >= 0 and slot < SLOTS:
		_slots[slot] = glyph


## ⚠ **`set_open_slots`는 세85 ⑦에 은퇴했다** (사용자 결정 · 감사 #8). 세60에 「진이 칸을 연다」
## (`JinDef.glyph_slots` → `choose_jin` → 여기)를 배선했지만, 라이브에서 열린 칸을 만드는 자리는
## `ring_forge_panel.build_assembly()`(층에 놓인 칸의 합집합)이고 이 경로의 src 호출자는 0이었다.
## 축이 통째로 은퇴했으므로 진입점(`JinDef.glyph_slots`)과 함께 걷었다 — 그물만 남기면 거짓 신호다.
func clear() -> void:
	_stage = STAGE_JIN
	_has_jin = false
	_runes_locked = false
	# 🔴 룬 자리 수는 진이 정하므로, 리셋은 옛 판(자리 1·미선택)으로 돌린다 — 다음 choose_jin이
	# 그 진의 rune_slots로 다시 채운다(진 미선택 = 자리 1 폴백, 옛 판과 동일).
	_rune_slots = 1
	_runes = [RUNE_NONE]
	_jin = &""
	_reset_slots()


func _reset_slots() -> void:
	_slots = []
	for k in SLOTS:
		_slots.append(GLYPH_NONE)
