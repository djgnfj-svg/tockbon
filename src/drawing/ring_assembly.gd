extends RefCounted
## 고리 **조립 상태기계** — 순수 데이터. 무엇이 놓였고 어느 칸이 열렸는지만 안다.
## Control도 렌더도 입력도 모른다 — 헤드리스로 완전히 테스트된다.
## 모델: 진 = 바깥 그릇 · 룬 = 중심 속성(융합진은 자리별) · 문양 = 칸을 채우는 조각.
##
## 🔴🔴 **이 상태기계는 라이브에서 안 돈다** — `lock_jin`·`lock_rune`·`place_glyph`·`set_jin`·
## `set_rune`를 부르는 src 코드가 0곳이고, 조립 상태의 실소유자는 `ring_forge_panel`
## (`_sel_jin`·`_sel_runes`·`_bands` → `build_assembly()`)이다.
## **여기를 고치기 전에 정말 라이브에 닿는지 먼저 확인해라.**
##
## 사용: const RingAssembly := preload("res://src/drawing/ring_assembly.gd")

const SLOTS := 8
const GLYPH_NONE := -1

# 조립 단계 — 진(CIRCLE) → 룬(RUNE) → 문양(ARROW). Enums.DrawStage를 그대로 재사용한다.
const STAGE_JIN := Enums.DrawStage.CIRCLE    # 진(그릇)을 놓을 차례
const STAGE_RUNE := Enums.DrawStage.RUNE     # 룬(중심)을 놓을 차례
const STAGE_GLYPH := Enums.DrawStage.ARROW   # 문양을 한 칸씩 얹을 차례

const RUNE_FIRE := 0   # 기본 룬 (불) — 아직 안 고른 판·옛 도안의 폴백
const RUNE_NONE := -1  # 룬 자리 미선택

var _stage: int = STAGE_JIN
var _has_jin := false
## 🔴 "룬이 놓였나"(has_rune)와 갈라 둔 값이다 — 융합진에서 첫 룬만 골라도 has_rune은 참이지만
## 자리를 다 채우기 전엔 잠기면 안 된다.
var _runes_locked := false
## 🔴 고른 룬들 — **복수다**. size = `_rune_slots`, 빈 자리 = `RUNE_NONE`.
var _runes: Array[int] = [RUNE_NONE]
## 이 진이 요구하는 룬 자리 수 (JinDef.rune_slots). 기본 1 = 일반진, 융합진 = 2.
var _rune_slots := 1
## 고른 진 id — 진은 손으로 안 긋고 **고른다**. 빈 값 = 폴백(발사부가 처리).
var _jin: StringName = &""
var _open: Array[int] = [0, 2]      # 열린 칸들 — 아무도 안 덮는 폴백 고정값
var _slots: Array[int] = []         # SLOTS개, 값 = 문양 코드 or GLYPH_NONE (열린 칸만 채워진다)


func _init() -> void:
	_reset_slots()


# ─────────────────────────── 조회 ───────────────────────────

func stage() -> int:
	return _stage

func has_jin() -> bool:
	return _has_jin

## 룬이 **적어도 하나** 놓였나. ⚠ "다 골랐나"는 `runes_ready` — 융합진에선 둘이 다르다.
func has_rune() -> bool:
	for r in _runes:
		if r != RUNE_NONE:
			return true
	return false

## 룬 자리를 **전부** 채웠나 — 잠금·맺기의 게이트.
func runes_ready() -> bool:
	if _runes.size() < _rune_slots:
		return false
	for i in _rune_slots:
		if _runes[i] == RUNE_NONE:
			return false
	return true

func get_open() -> Array[int]:
	return _open

## primary 룬 (첫 자리). ⚠ 룬은 복수다 — 발사·저장은 `get_runes()`를 봐야 한다.
func get_rune() -> int:
	for r in _runes:
		if r != RUNE_NONE:
			return r
	return RUNE_FIRE

## 🔴 고른 룬 목록 (자리 순서, 빈 자리 제외) — 발사·저장 계약의 다중 룬 정본.
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

## 진을 고른다 — 손으로 긋지 않는다. 언제든 바꿀 수 있다.
func set_jin(id: StringName) -> void:
	_jin = id


## 이 진의 룬 자리 수를 정한다. `_runes`를 n칸으로 맞추되 겹치는 옛 선택은 보존한다.
## ⚠ 잠근 뒤엔 안 바꾼다 — 문양 단계에서 자리 수가 흔들리면 도안이 조용히 어긋난다.
func set_rune_slots(n: int) -> void:
	if _runes_locked:
		return
	_rune_slots = maxi(n, 1)
	var old := _runes
	_runes = []
	for i in _rune_slots:
		_runes.append(old[i] if i < old.size() else RUNE_NONE)


## 룬 자리 하나에 룬 종류를 넣는다. 룬 단계에서만·잠그기 전.
## `slot` = 넣을 자리(0부터). **-1 = 다음 빈 자리**(없으면 첫 자리).
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


## 🔴 빈 진도 날아가 맞는다 — 단 **진과 룬(모든 자리)이 놓여 있어야** 마법진이다.
func can_commit() -> bool:
	return _has_jin and runes_ready()


## 🔴 조립 결과 스냅샷 = **발사 계약**. 발사·저장이 이걸 읽는다 — 모양을 바꾸면 둘 다 조용히 깨진다.
func get_assembly() -> Dictionary:
	return {"ring_count": 1, "rune": get_rune(), "runes": get_runes(),
		"jin": _jin, "rings": [Array(_slots)], "open": _open.duplicate()}


# ─────────────────────────── 상태 전이 ───────────────────────────

## 진을 잠갔다 → 룬 단계로.
func lock_jin() -> void:
	_has_jin = true
	_stage = STAGE_RUNE


## 룬을 잠갔다 → 문양 단계로. 🔴 **모든 룬 자리가 차야** 잠근다 — 첫 룬만 고른 채 잠기면
## 도안에 빈 자리가 남아 발사 계약이 룬 하나만 실어 나간다.
func lock_rune() -> void:
	if not runes_ready():
		return
	_runes_locked = true
	_stage = STAGE_GLYPH


## 문양 한 칸을 채운다 (열린 칸만).
func place_glyph(slot: int, glyph: int) -> void:
	if slot >= 0 and slot < SLOTS:
		_slots[slot] = glyph


func clear() -> void:
	_stage = STAGE_JIN
	_has_jin = false
	_runes_locked = false
	# 룬 자리 수는 진이 정하므로 폴백(1)으로 돌린다 — 다음 진 선택이 다시 채운다.
	_rune_slots = 1
	_runes = [RUNE_NONE]
	_jin = &""
	_reset_slots()


func _reset_slots() -> void:
	_slots = []
	for k in SLOTS:
		_slots.append(GLYPH_NONE)
