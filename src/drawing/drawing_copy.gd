extends RefCounted
## 드로잉 문구 — **스승의 목소리 한 곳**. 시험대·드로잉룸·체크리스트가 전부 여기서 읽는다.
##
## 톤은 튜토리얼(src/tutorial)의 스승 메모를 잇는다 — 같은 목소리가 게임 내내 이어진다.
## 다만 **명사는 기능 용어를 쓴다: 진 · 룬 · 문양** (사용자 결정).
## 튜토리얼은 "원/글자/화살표"라는 은유를 쓰지만, 작성 문법을 가르치는 자리에서는
## 부품 이름이 명확한 쪽이 낫다 — 체크리스트가 곧 문법 설명이기 때문이다.
## 사용: const Copy := preload("res://src/drawing/drawing_copy.gd")

## 체크리스트 — 아직 못 한 일 (짧게, 스캔 가능하게)
const TODO := {
	Enums.DrawStage.CIRCLE: "진을 두른다",
	Enums.DrawStage.RUNE: "룬을 앉힌다",
	Enums.DrawStage.ARROW: "문양을 긋는다",
}
## 체크리스트 — 해낸 일 (완료형)
const DONE := {
	Enums.DrawStage.CIRCLE: "진을 둘렀다",
	Enums.DrawStage.RUNE: "룬을 앉혔다",
	Enums.DrawStage.ARROW: "문양을 그었다",
}

const NOW_MARK := "← 지금"
const MORE_MARK := "(더 그어도 된다)"

## 순서를 어긴 획 — 스승의 목소리 (튜토리얼 대사를 한 줄로 줄이고 명사만 기능 용어로)
const MASTER := {
	Enums.DrawStage.CIRCLE: "「먼저 진을 두르라. 경계가 서야 룬이 깃들 자리가 생긴다.」",
	Enums.DrawStage.RUNE: "「진 안에 룬을 필사하라. 한 획이면 충분하다.」",
	# 🔴 v2.1: 화살표 = **맞은 뒤 충격이 가는 쪽** (TECH_SPEC §4.0-b).
	# ~~v2.0 "힘의 결(효과)"~~ · ~~v1.9 "힘의 **방향**"(발사각 — 지팡이로 갔다)~~
	Enums.DrawStage.ARROW: "「부딪힌 힘은 어디로 가는가. 문양을 그어 그 길을 정하라.」",
}

## 인식 실패 — 순서 문제가 아니라 형이 흐트러진 것이다. 자동보정으로 유도한다
const UNRECOGNIZED := "「획이 흐트러졌다. 다시 긋거나, 자동보정으로 형을 잡아라.」"
## 잉크 상한 초과
const INK_OVER := "「종이가 먹을 더 먹지 못한다. 획을 지우면 먹이 돌아온다.」"
## 종이 없음
const NO_PAPER := "「종이가 없다. 빈손으론 도안이 맺히지 않는다.」"

## 🔴 **확정 대기** (F1, 2026-07-15) — 세 부품이 다 모였다. 하지만 종이는 확정해야 뜯긴다.
## 화살표 하나로 자동 완성되던 것을 없앴다 (사용자: *"그리지도 않았는데 완료되는 게 띠꺼움"*).
const COMMIT_PROMPT := "▶ 완성 — Enter로 맺는다"
## 확정 버튼 라벨 (제작대 — Enter와 같은 일)
const COMMIT_BUTTON := "✓ 완성 (Enter)"
## 확정을 눌러 종이가 뜯긴 순간 — 이 화면의 클라이맥스
const COMPLETE := "「도안이 맺혔다. 먹이 마르기 전에 시험해 보아라.」"
## 확정 안내 (say 라인) — 초안이 준비됐을 때
const READY_TO_COMMIT := "「진·룬·문양이 다 섰다. Enter로 도안을 맺어라 — 그때 종이가 뜯긴다.」"
const INCOMPLETE := "아직 도안이 아니다 — 진 하나, 룬 하나, 문양 하나."

## 조작 안내 (순서 안내는 체크리스트가 상시 보여 준다 — 여긴 조작만)
const CONTROLS := "좌클릭 드래그 = 획 · Ctrl+Z = 되돌리기 · 휠 = 종이 확대(작은 문양)"

## 본보기 자석 — 책자에서 집어 종이로 옮긴다. **손이 이기는 도구다** (멀리 그으면 안 끌린다)
## 🔴 문양(방향 글자)은 **고무줄 겨눔** (2026-07-15): 진 위에서 누른 채 끌어 방향·세기를 정한다.
const TRACE_HELD := "종이를 눌러 본을 앉힌다 · 휠 = 크기(세기를 정한다)"
const TRACE_HELD_ARROW := "진 안에서 누른 채 끌어라 — 끄는 쪽이 방향, 끄는 거리가 세기 · 떼면 앉는다"
const TRACE_PLACED := "「본을 따라 그으면 붓이 끌려간다. 벗어나 긋고 싶으면 벗어나라 — 네 손이 위다.」"

## 자동보정·스탬프
const AUTOCORRECT_OK := "「형을 바로잡았다. 손맛은 네 것 그대로다.」"
const AUTOCORRECT_NONE := "바로잡을 룬이 없다 — 먼저 룬을 앉혀라."
const STAMP_NONE := "「본으로 뜰 룬이 없다. 먼저 룬을 앉혀라.」"
const STAMP_SAVED := "룬을 본으로 떠 두었다 — 목록에서 골라 종이를 눌러라."
const STAMP_PLACE := "종이를 눌러 본을 앉힌다 (우클릭 = 물린다) · 정확도는 뜬 그대로 남는다."

## 방위 — 🔴 **v2.1에서 되살아났다. 의미가 바뀌었다.**
## ~~v1.5~v1.9: 발사 방향~~ (v2.0에서 지팡이로 갔다) → **v2.1: 충격파 방향** (TECH_SPEC §4.0-b).
## **종이 위쪽 = 탄이 가는 쪽** — 위로 그은 화살표는 적을 **밀어내고**, 아래로 그은 화살표는
## **나에게 끌어온다.** 이게 안 보이면 플레이어는 매번 머릿속으로 방향을 상상해야 한다.
const GUIDE_FRONT := "앞"
const GUIDE_BACK := "뒤"
const GUIDE_LEFT := "왼"
const GUIDE_RIGHT := "오"

## 도안 책자 (참조 패널)
const BOOK_TITLE := "도안 책자"
const BOOK_CIRCLE := "진"
const BOOK_RUNE := "룬"
const BOOK_ARROW := "문양"
const BOOK_LOCKED := "?"
const BOOK_ARROW_STRAIGHT := "곧게"
const BOOK_ARROW_CURVED := "휘어도 된다"

## 문양 4종 — **탄에 얹히는 효과** (v2.0, GDD §4.3). 기본은 글자가 아니다(곧은 획).
## 룬과 같은 문법으로 읽힌다: **모양 = 효과 / 길이 = 세기**
## 🔴 **v2.0: 문양 하나가 한 발이 아니다.** 여러 개를 그으면 **한 탄에 효과가 여럿 얹힌다** —
## 발수와 방향은 **지팡이**가 정한다 (v1.9의 "문양 1개 = 1발"은 방향이 지팡이로 가면서 무너졌다:
## 방향이 없으면 N발이 **같은 자리에 겹쳐** 나간다)
##
## 🔴 단일 진실원 (2026-07-17, 세션 21): 이름·효과 문구는 이제 data/shapes/glyph_*.tres의
## display_name·description에서 읽는다. 책자·트레이스·인식기가 모양을 이미 같은 파일에서
## 읽고 있으므로(rune_templates.gd·glyph_templates.gd), 텍스트도 같은 곳에서 읽어야
## "보이는 모양"과 "뜨는 글"이 갈라질 수 없다.
const SHAPE_DIR := "res://data/shapes/"
const GLYPH_FILES := {
	Enums.GlyphType.BASIC: "glyph_basic",
	Enums.GlyphType.BOUNCE: "glyph_bounce",
	Enums.GlyphType.HOMING: "glyph_homing",
	Enums.GlyphType.PIERCE: "glyph_pierce",
	Enums.GlyphType.THRUST: "glyph_thrust",
}
static var _glyph_shape_cache: Dictionary = {}  # type(int) -> ShapeDef Resource 또는 null(로드 실패 기억)


## data/shapes/glyph_<type>.tres. class_name 캐시에 안 의존하려 load()로 지연 로드
## (rune_templates.gd·glyph_templates.gd와 같은 패턴).
static func _glyph_shape(glyph_type: int) -> Resource:
	if _glyph_shape_cache.has(glyph_type):
		return _glyph_shape_cache[glyph_type]
	var res: Resource = null
	var id: String = GLYPH_FILES.get(glyph_type, "")
	if id != "":
		res = load(SHAPE_DIR + id + ".tres")
	_glyph_shape_cache[glyph_type] = res
	return res


static func glyph_label(glyph_type: int) -> String:
	var shape := _glyph_shape(glyph_type)
	if shape != null and shape.display_name != "":
		return shape.display_name
	return _fallback_glyph_label(glyph_type)


## 무엇을 하는 글자인가 + **길게 그으면 무엇이 늘어나는가** (길이 = 세기 축을 눈에 보이게).
## 길이가 아무것도 안 하면 "짧게 긋는 게 이득"이 되고 표현 수단이 죽는다 (v1.6~v1.8의 교훈)
static func glyph_effect(glyph_type: int) -> String:
	var shape := _glyph_shape(glyph_type)
	if shape != null and shape.description != "":
		return shape.description
	return _fallback_glyph_effect(glyph_type)


# ─────────────────────────── 절차 폴백 (데이터 없을 때만) ───────────────────────────
## data/shapes/glyph_*.tres가 있으면 아래는 절대 실행되지 않는다. 문구의 출생 기록이자 안전망이다.

static func _fallback_glyph_label(glyph_type: int) -> String:
	match glyph_type:
		Enums.GlyphType.BASIC:
			return "기본"
		Enums.GlyphType.BOUNCE:
			return "팅김⚡"
		Enums.GlyphType.HOMING:
			return "유도∿"
		Enums.GlyphType.PIERCE:
			return "관통‖"
		Enums.GlyphType.THRUST:
			return "추진»"
	return "?"


static func _fallback_glyph_effect(glyph_type: int) -> String:
	match glyph_type:
		Enums.GlyphType.BASIC:
			return "그저 난다 — 길수록 멀리"
		Enums.GlyphType.BOUNCE:
			return "벽에 튄다 — 길수록 여러 번"
		Enums.GlyphType.HOMING:
			return "쫓아간다 — 길수록 오래"
		Enums.GlyphType.PIERCE:
			return "꿰뚫는다 — 길수록 여럿"
		Enums.GlyphType.THRUST:
			return "빠르게 난다 — 길수록 더 빨리"
	return ""

# ── 제작대(책 펼침 UI) ──
## 책자는 **참조**다 — 골라서 찍는 게 아니라 보고 따라 그린다 (사용자 결정, 세션 8)
const FORGE_TITLE := "도안 제작"
const FORGE_PAPER := "종이"
const FORGE_INK := "먹"
const FORGE_CLOSE := "ESC — 붓을 놓는다"
const FORGE_OPEN := "E — 도안을 그린다"
const FORGE_BOOK_HINT := "책자는 본보기다. 보고 따라 그으면 진이 알아본다."

## 책자 탭별 안내 — 그 부품이 **무엇을 정하는가**
## 세 부품이 **각자 무엇을 정하는가** (GDD §4.0 역할 축). 전부 "모양 = 무엇을 / 크기 = 얼마나"다.
## ⚠ **문구가 규칙을 가르친다 — 낡으면 플레이어에게 거짓을 가르친다.** 이 파일은 그래서
## 축이 바뀔 때마다 함께 고쳐야 한다 (세션 10에 낡은 거짓말 2건이 실제로 발견됐다):
##   v1.7 — 룬의 정확도는 **위력이 아니라 순도**
##   v1.9 — 문양의 길이는 **크기가 아니라 사거리**
##   🔴 v2.0 — 문양은 **방향도 발수도 정하지 않는다** (지팡이의 것이다). 하나가 한 발이 아니라
##             **여러 개가 한 탄에 얹힌다.** 진은 규모만이 아니라 **탄의 몸 그 자체**다
const TAB_DESC := {
	Enums.DrawStage.CIRCLE: "경계를 두른다. 진이 곧 날아갈 탄이다 —\n크기가 위력·탄 크기·사거리를 정한다.",
	Enums.DrawStage.RUNE: "진 안에 앉힌다. 무엇으로 때리는가.\n진을 꽉 채울수록 속성이 깊이 물든다.",
	Enums.DrawStage.ARROW: "곧은 화살표 = 맞은 뒤 충격이 갈 길.\n모아 겨누면 부딪혀 기둥이 선다.",
}

## 룬 3종 — 무엇을 하는 글자인가 (v2.2: 충격 제거, 원소만)
## 🔴 단일 진실원 (2026-07-17, 세션 21): 이름·효과 문구는 data/shapes/rune_*.tres의
## display_name·description에서 읽는다 (문양쪽과 같은 이유·같은 패턴).
const RUNE_FILES := {
	Enums.RuneType.FIRE: "rune_fire",
	Enums.RuneType.WATER: "rune_water",
	Enums.RuneType.WIND: "rune_wind",
}
static var _rune_shape_cache: Dictionary = {}  # type(int) -> ShapeDef Resource 또는 null(로드 실패 기억)


## data/shapes/rune_<type>.tres. class_name 캐시에 안 의존하려 load()로 지연 로드.
static func _rune_shape(rune_type: int) -> Resource:
	if _rune_shape_cache.has(rune_type):
		return _rune_shape_cache[rune_type]
	var res: Resource = null
	var id: String = RUNE_FILES.get(rune_type, "")
	if id != "":
		res = load(SHAPE_DIR + id + ".tres")
	_rune_shape_cache[rune_type] = res
	return res


static func rune_effect(rune_type: int) -> String:
	var shape := _rune_shape(rune_type)
	if shape != null and shape.description != "":
		return shape.description
	return _fallback_rune_effect(rune_type)


# ─────────────────────────── 절차 폴백 (데이터 없을 때만) ───────────────────────────
## data/shapes/rune_*.tres가 있으면 아래는 절대 실행되지 않는다. 문구의 출생 기록이자 안전망이다.

static func _fallback_rune_effect(rune_type: int) -> String:
	match rune_type:
		Enums.RuneType.FIRE:
			return "태운다 — 화상·지속 피해"
		Enums.RuneType.WATER:
			return "적신다 — 둔화·갑주 무력"
		Enums.RuneType.WIND:
			return "흩는다 — 확산·면 제어"
	return ""

## 진·문양 칸 이름
const BOOK_CIRCLE_NAME := "진"
const BOOK_LOCKED_HINT := "아직 모르는 글자다 — 탁본으로 배운다"


## 거부 사유(StringName) → 스승의 말.
## info: 캔버스의 get_last_reject() — near_rune·score가 있으면 **구체적으로** 말해 준다.
static func reject_line(reason: StringName, stage: int, info: Dictionary = {}) -> String:
	match reason:
		&"out_of_order":
			return String(MASTER.get(stage, ""))
		&"unrecognized":
			return unrecognized_line(info)
		&"ink_over":
			return INK_OVER
		&"no_paper":
			return NO_PAPER
	return ""


## 인식 실패 — **가장 가까운 룬과 점수를 보여 준다.** "거의 됐다"와 "전혀 아니다"를
## 구별할 수 있어야 플레이어가 다시 그릴 마음이 생긴다. 정보가 없으면 일반 문구로 폴백.
static func unrecognized_line(info: Dictionary) -> String:
	if not info.has("near_rune") or not info.has("score"):
		return UNRECOGNIZED
	var name := rune_label(int(info.near_rune))
	if name == "":
		return UNRECOGNIZED
	return "「%s에 가깝다 — %.2f. %.2f에 못 미친다.\n다시 긋거나, 자동보정으로 형을 잡아라.」" % [
		name, float(info.score), float(info.get("min_score", 0.6))]


static func rune_label(rune_type: int) -> String:
	var shape := _rune_shape(rune_type)
	if shape != null and shape.display_name != "":
		return shape.display_name
	return _fallback_rune_label(rune_type)


static func _fallback_rune_label(rune_type: int) -> String:
	match rune_type:
		Enums.RuneType.FIRE:
			return "불△"
		Enums.RuneType.WATER:
			return "물~"
		Enums.RuneType.WIND:
			return "바람◎"
	return ""
