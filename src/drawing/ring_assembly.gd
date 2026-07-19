extends RefCounted
## 고리 **조립 상태기계** — 순수 데이터 (2026-07-17 세션 22, ring_board 757줄에서 분리).
##
## 무엇이 놓였고 어느 칸이 열렸는지만 안다. **Control도 렌더도 입력도 모른다** — 헤드리스로
## 완전히 테스트된다(tests/test_ring_assembly_auto.gd).
##
## 모델 (사용자 확정 2026-07-16 · memory takbon-ring-assembly-pivot):
##   • 진 = 바깥 그릇(경계) — 지금은 일반진 하나
##   • 룬 = 중심 속성 — 지금은 불만
##   • 🔴 **문양본(틀)이 칸을 연다** (스텐실). 2방 문양본 = 정해진 2자리만 열린다.
##     문양본 없으면 빈 진(그냥 날아가 맞기만). 얻어 삽입할수록 넓어진다 (2방→4방→8방).
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

## 🔴 문양본(틀) — 각 틀이 **어느 칸을 여는지** 정한다 (칸 0=위, 시계방향으로 2=오른쪽…).
## 얻어서 삽입한다. 배치가 곧 콘텐츠 — 2방은 좁고 8방은 전방위. (지금은 전부 보유로 친다.)
const TEMPLATES := [
	{"name": "2방", "slots": [0, 2]},          # 위·오른쪽
	{"name": "3방(우)", "slots": [1, 2, 3]},    # 오른쪽으로 몰린 셋
	{"name": "4방", "slots": [0, 2, 4, 6]},     # 십자
	{"name": "8방", "slots": [0, 1, 2, 3, 4, 5, 6, 7]},  # 전방위
]

const RUNE_FIRE := 0   # 기본 룬 (불) — 아직 안 고른 판·옛 도안의 폴백

var _stage: int = STAGE_JIN
var _has_jin := false
var _has_rune := false
## 🔴 고른 룬 종류 (Enums.RuneType). 세션 34 전엔 RUNE_FIRE로 **하드코딩**돼, 물·바람을
## 그려도 발사가 불로 나갔다 (get_assembly가 늘 불을 실었고 발사도 FIRE를 하드코딩). 이제
## choose_rune이 set_rune으로 여기 담고, get_assembly가 실어 저장·발사까지 흐른다.
var _rune: int = RUNE_FIRE
## 🔴 고른 진 id (세션44, 진=형태). 진은 **손으로 안 긋고 고른다**(선택) — 지팡이(진)를 골라 그 위에
## 룬·문양을 그린다. get_assembly가 실어 저장·발사(형태)까지 흐른다. 빈 값 = 폴백(발사부가 처리).
var _jin: StringName = &""
var _open: Array[int] = [0, 2]      # 지금 문양본이 연 칸들 (기본 2방)
var _slots: Array[int] = []         # SLOTS개, 값 = 문양 코드 or GLYPH_NONE (열린 칸만 채워진다)


func _init() -> void:
	_reset_slots()


# ─────────────────────────── 조회 ───────────────────────────

func stage() -> int:
	return _stage

func has_jin() -> bool:
	return _has_jin

func has_rune() -> bool:
	return _has_rune

func get_open() -> Array[int]:
	return _open

func get_rune() -> int:
	return _rune

func get_jin() -> StringName:
	return _jin

## 🔴 진을 고른다 (세션44) — 손으로 긋지 않는다. 언제든 바꿀 수 있다(발사 형태 선택).
func set_jin(id: StringName) -> void:
	_jin = id


## 🔴 룬 종류를 고른다 (Enums.RuneType). 룬 단계에서만 유효 — 이미 잠갔으면 무시한다
## ([다시 그리기]가 풀기 전엔 못 바꾼다, choose_jin과 같은 규약).
func set_rune(rune_type: int) -> void:
	if _stage != STAGE_RUNE or _has_rune:
		return
	_rune = rune_type

func glyph_at(slot: int) -> int:
	return _slots[slot] if slot >= 0 and slot < SLOTS else GLYPH_NONE

func filled_count() -> int:
	var n := 0
	for k in _open:
		if _slots[k] != GLYPH_NONE:
			n += 1
	return n


## 열린 칸 중 아직 빈 첫 칸 (없으면 -1). 채우는 순서 = 문양본이 준 순.
func next_open_slot() -> int:
	for k in _open:
		if _slots[k] == GLYPH_NONE:
			return k
	return -1


func is_open_slot(k: int) -> bool:
	return k in _open


## 🔴 진은 문양이 없어도(빈 진) 날아가 맞는다 — 단, **진과 룬은 놓여 있어야** 마법진이다 (세션 13).
func can_commit() -> bool:
	return _has_jin and _has_rune


## 🔴 조립 결과 스냅샷 = **발사 계약**. 발사(ring_spell_system)·저장(RingDesign)이 이걸 읽는다.
## ⚠ 모양을 바꾸면 둘 다 조용히 깨진다 (tests/test_ring_assembly_auto.gd가 못 박아 둔다).
func get_assembly() -> Dictionary:
	return {"ring_count": 1, "rune": _rune, "jin": _jin, "rings": [Array(_slots)],
		"open": _open.duplicate()}


# ─────────────────────────── 상태 전이 ───────────────────────────

## 진을 잠갔다 → 룬 단계로.
func lock_jin() -> void:
	_has_jin = true
	_stage = STAGE_RUNE


## 룬을 잠갔다 → 문양 단계로.
func lock_rune() -> void:
	_has_rune = true
	_stage = STAGE_GLYPH


## 문양 한 칸을 채운다 (열린 칸만).
func place_glyph(slot: int, glyph: int) -> void:
	if slot >= 0 and slot < SLOTS:
		_slots[slot] = glyph


## 🔴 문양본을 삽입한다 — 이 칸들만 열린다. **닫힌 칸의 문양은 걷어낸다.**
## 범위 밖·중복은 걸러진다. 빈 배열 = 빈 진.
func set_template(open_slots: Array) -> void:
	var next: Array[int] = []
	for s in open_slots:
		var k := int(s)
		if k >= 0 and k < SLOTS and not (k in next):
			next.append(k)
	_open = next
	for k in SLOTS:
		if not (k in _open):
			_slots[k] = GLYPH_NONE       # 닫힌 칸은 비운다


func clear() -> void:
	_stage = STAGE_JIN
	_has_jin = false
	_has_rune = false
	_rune = RUNE_FIRE
	_jin = &""
	_reset_slots()


func _reset_slots() -> void:
	_slots = []
	for k in SLOTS:
		_slots.append(GLYPH_NONE)
