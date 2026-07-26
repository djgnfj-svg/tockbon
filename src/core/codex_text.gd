extends RefCounted
## 🔴 codex 해금 id → **사람이 읽는 이름·안내**의 단일 소스 (세87 사냥 흐름 S4). class_name 없음 —
## `const CodexText := preload("res://src/core/codex_text.gd")`로 참조한다. `item_text.gd`의 형제다.
##
## 왜 생겼나: `boss_room`의 클리어 보상 줄이 **`Db.get_glyph_ring()` 하나만** 불렀다. 챕터 보상이
## 고리뿐일 때는 맞았지만, 세87에 보상이 **룬**으로 바뀌자 두 겹으로 틀린 문구가 됐다 —
##   ① `glyph_rings.get()`이 null이라 폴백이 걸려 **원시 id가 화면에 노출**된다("보상: rune_water")
##   ② 안내가 *"책상에서 밴드에 끼워라"*로 고정이라 **밴드는 고리 자리인데 룬을 거기 끼우라**고
##      가르친다 = 거짓 지시
## 발신처가 셋(보스 클리어 · 공방 제작 · 두루마리 픽업)이라 각자 3중 조회를 복제하면 그게
## 감사 T5(*"문구는 사본이 아니라는 무의식 예외"*)의 재발이다. 그래서 core에 둔다.
##
## 🔴 **룬만 조회 방향이 다르다** — `RuneDef`엔 `id` 필드가 없고 `Db.get_rune(type)`은 **타입 키**다.
## 그래서 `Enums.RUNE_TYPES`를 순회해 `unlock_id`를 맞춘다. ⚠ `RuneType`은 값이 연속이 아니라
## (`[0,2,3,4,5,6]` — 1은 은퇴한 IMPACT 구멍) `range()`/`size()`로 돌리면 없는 룬이 생긴다.
## 진·고리는 `all_jins()`·`all_glyph_rings()`가 있어 그대로 훑는다.
##
## ⚠ `Db`를 **런타임 조회**한다(`/root/Db`) — static 함수에서 오토로드 식별자를 컴파일 타임에
## 물면 `-s` 테스트가 오토로드 등록 전에 이 파일을 컴파일할 때 깨진다(CLAUDE.md 알려진 함정).
## 조회 실패 시엔 이름 폴백 + 빈 안내로 조용히 선다 — 문구는 게임을 멈출 이유가 아니다.


## 종류 이름 — `kind_of`의 반환값이자 `hint_for_kind`의 입력.
const KIND_RUNE := &"rune"
const KIND_JIN := &"jin"
const KIND_RING := &"ring"

## 🔴 종류별 안내문 = **「어디에 쓰는 물건인지」**. 세 자리가 실제로 다르다:
## 룬은 진 **중심**, 고리는 **밴드(층)** 칸, 진은 **바탕**이다. 여기를 고치면 세 발신처가 같이 바뀐다.
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
## 🔴 **룬만 종류 이름을 붙인다** (`물` → `물 룬`). `RuneDef.display_name`은 조립 책의 룬 셀 안에서
## 쓰라고 만든 값이라 그 안에선 "물"이 맞지만, 획득 문구로 나가면 *"보상: 물(…)"* = **「물을 얻었다」**로
## 읽힌다. 진·고리는 이름에 이미 종류가 들어 있다(`확산 고리 ×3` · `단발진 2등급`) — 룬만 비어 있었다.
## ⚠ 붙이는 자리를 여기로 고른 이유: `.tres`의 `display_name`을 고치면 **조립 책 룬 셀이 "물 룬"으로**
## 같이 바뀐다(그 안에선 군더더기다). 종류는 **문맥이 정하는 것**이라 표시부에서 붙인다.
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


## 종류별 안내문 — 🔴 **순수 함수**(Db를 안 본다). 문구 계약을 Db 없이 잴 수 있게 갈라 뒀다.
static func hint_for_kind(kind: StringName) -> String:
	return String(HINTS.get(kind, ""))


## codex id의 안내문 — 획득물이 아니면 빈 문자열(호출부가 "" 검사로 괄호를 생략한다).
static func hint_of(unlock_id: StringName) -> String:
	return hint_for_kind(kind_of(unlock_id))


## 🔴 화면에 그대로 나가는 한 줄 — `이름(안내)`. 발신처 셋이 이걸 부른다(각자 조립하면 또 사본이다).
## 안내가 없으면 괄호까지 생략해 `이름`만 돌려준다 — 빈 괄호 "물 룬()"가 나가지 않게.
static func label_of(unlock_id: StringName) -> String:
	var nm := name_of(unlock_id)
	if nm == "":
		return ""
	var hint := hint_of(unlock_id)
	if hint == "":
		return nm
	return "%s(%s)" % [nm, hint]


## 🔴 획득 순간 화면에 나가는 **문장** — `이름 획득! 안내` (세88). 두루마리 픽업·공방 제작이 쓴다.
##
## `label_of`(`이름(안내)`)와 형태가 갈린 이유: 획득은 **문장**이고 클리어 보상 표기는 **항목**이다
## (`boss_room`의 " 보상: X(안내)"). 두 형태가 다 필요하다는 것 자체가 이 파일을 만든 이유다 —
## 발신처가 각자 조립하면 넷째 사본이 생긴다.
##
## 🔴 **획득물이 아니면 빈 문자열이다.** `chapter_clear_*`도 `codex_unlocked`로 오는데, 그때
## `name_of`의 원시 id 폴백을 그대로 쓰면 화면에 **"chapter_clear_ch1 획득!"**이 뜬다.
## 그래서 `kind_of`로 먼저 걸러 낸다 — 호출부는 "" 검사로 조용히 넘긴다.
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


## `/root/Db` 런타임 조회 — 위 주석의 `-s` 컴파일 함정 회피용. 오토로드가 없으면 null.
static func _db() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(^"/root/Db")
