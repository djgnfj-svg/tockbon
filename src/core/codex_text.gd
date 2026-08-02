extends RefCounted
## 🔴 codex 해금 id → **사람이 읽는 이름·안내**의 단일 소스. class_name 없음 —
## `const CodexText := preload("res://src/core/codex_text.gd")`로 참조한다. `item_text.gd`의 형제다.
##
## 발신처가 셋(보스 클리어 · 공방 제작 · 두루마리 픽업)이라 각자 조회를 복제하면 보상 종류가
## 바뀔 때 원시 id 노출·거짓 안내("룬을 밴드에 끼워라")가 한 곳씩 남는다.
##
## 🔴 룬만 조회 방향이 다르다 — `RuneDef`엔 `id`가 없고 `Db.get_rune(type)`은 타입 키라
## `Enums.RUNE_TYPES`를 순회해 `unlock_id`를 맞춘다. ⚠ `RuneType`은 값이 **연속이 아니라**
## `range()`/`size()`로 돌리면 없는 룬이 생긴다.
##
## ⚠ `Db`를 런타임 조회한다(`/root/Db`) — static 함수가 오토로드 식별자를 컴파일 타임에 물면
## `-s` 테스트가 오토로드 등록 전 컴파일에서 터진다.
## 조회 실패 시엔 이름 폴백 + 빈 안내로 조용히 선다 — 문구는 게임을 멈출 이유가 아니다.


## 종류 이름 — `kind_of`의 반환값이자 `hint_for_kind`의 입력.
const KIND_RUNE := &"rune"
const KIND_JIN := &"jin"
const KIND_RING := &"ring"

## 종류별 안내문 = 「어디에 쓰는 물건인지」. 세 자리가 실제로 다르다 —
## 룬은 진 중심, 고리는 밴드(층) 칸, 진은 바탕이다. 여기를 고치면 세 발신처가 같이 바뀐다.
const HINTS: Dictionary = {
	KIND_RUNE: "책상에서 진 중심에 놓아라",
	KIND_JIN: "책상에서 바탕 진으로 고를 수 있다",
	KIND_RING: "책상에서 밴드에 끼워라",
}


## codex id가 룬·진·고리 중 무엇인가 — 셋 다 아니면 빈 StringName.
## ⚠ `chapter_clear_*`처럼 **획득물이 아닌 codex 키**도 이 함수에 들어온다(그때 빈 값이 정답이다).
static func kind_of(unlock_id: StringName) -> StringName:
	if unlock_id == &"":
		return &""
	var db := _db()
	if db == null:
		return &""
	for t: int in Enums.RUNE_TYPES:
		var rune: RuneDef = db.call(&"get_rune", t)
		if rune != null and rune.unlock_id == unlock_id:
			return KIND_RUNE
	for jin: JinDef in db.call(&"all_jins"):
		if jin.unlock_id == unlock_id:
			return KIND_JIN
	for ring: GlyphRingDef in db.call(&"all_glyph_rings"):
		if ring.unlock_id == unlock_id:
			return KIND_RING
	return &""


## 표시명 — 못 찾으면 원시 id로 폴백한다(데이터 오류가 화면에 보이는 편이 조용히 빈 줄보다 낫다).
## ⚠ 폴백이 걸리는 것 자체가 버그 신호다 — `test_ui_text_auto`가 원시 id 노출을 잰다.
##
## 🔴 룬만 종류 이름을 붙인다(`물` → `물 룬`) — 진·고리는 이름에 이미 종류가 들어 있다.
## 붙이는 자리가 `.tres`가 아닌 이유: `display_name`을 고치면 조립 책 룬 셀까지 "물 룬"이 된다.
## 종류는 문맥이 정하는 것이라 표시부에서 붙인다.
static func name_of(unlock_id: StringName) -> String:
	if unlock_id == &"":
		return ""
	var db := _db()
	if db == null:
		return String(unlock_id)
	for t: int in Enums.RUNE_TYPES:
		var rune: RuneDef = db.call(&"get_rune", t)
		if rune != null and rune.unlock_id == unlock_id:
			return "%s 룬" % rune.display_name
	for jin: JinDef in db.call(&"all_jins"):
		if jin.unlock_id == unlock_id:
			return jin.display_name
	for ring: GlyphRingDef in db.call(&"all_glyph_rings"):
		if ring.unlock_id == unlock_id:
			return ring.display_name
	return String(unlock_id)


## 종류별 안내문 — 순수 함수(Db를 안 본다). 문구 계약을 Db 없이 잴 수 있게 갈라 뒀다.
static func hint_for_kind(kind: StringName) -> String:
	return String(HINTS.get(kind, ""))


## codex id의 안내문 — 획득물이 아니면 빈 문자열(호출부가 "" 검사로 괄호를 생략한다).
static func hint_of(unlock_id: StringName) -> String:
	return hint_for_kind(kind_of(unlock_id))


## 화면에 그대로 나가는 한 줄 — `이름(안내)`. 발신처 셋이 이걸 부른다(각자 조립하면 또 사본이다).
## 안내가 없으면 괄호까지 생략한다 — 빈 괄호 "물 룬()"가 나가지 않게.
static func label_of(unlock_id: StringName) -> String:
	var nm := name_of(unlock_id)
	if nm == "":
		return ""
	var hint := hint_of(unlock_id)
	if hint == "":
		return nm
	return "%s(%s)" % [nm, hint]


## 획득 순간 화면에 나가는 **문장** — `이름 획득! 안내`. 두루마리 픽업·공방 제작이 쓴다.
## `label_of`(`이름(안내)`)와 갈린 이유: 획득은 문장이고 클리어 보상 표기는 항목이다.
##
## 🔴 획득물이 아니면 빈 문자열이다 — `chapter_clear_*`도 `codex_unlocked`로 오는데 `name_of`의
## 원시 id 폴백을 그대로 쓰면 화면에 "chapter_clear_ch1 획득!"이 뜬다. 그래서 `kind_of`로 먼저 거른다.
static func acquired_line(unlock_id: StringName) -> String:
	if kind_of(unlock_id) == &"":
		return ""
	var nm := name_of(unlock_id)
	if nm == "":
		return ""
	var hint := hint_of(unlock_id)
	if hint == "":
		return "%s 획득!" % nm
	return "%s 획득! %s" % [nm, hint]


## `/root/Db` 런타임 조회 — 머리말의 `-s` 컴파일 함정 회피용. 오토로드가 없으면 null.
static func _db() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(^"/root/Db")
