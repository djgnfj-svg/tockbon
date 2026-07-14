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
	Enums.DrawStage.ARROW: "「룬은 갈 곳을 묻는다. 문양을 그어 힘의 방향을 정하라.」",
}

## 인식 실패 — 순서 문제가 아니라 형이 흐트러진 것이다. 자동보정으로 유도한다
const UNRECOGNIZED := "「획이 흐트러졌다. 다시 긋거나, 자동보정으로 형을 잡아라.」"
## 잉크 상한 초과
const INK_OVER := "「종이가 먹을 더 먹지 못한다. 획을 지우면 먹이 돌아온다.」"
## 종이 없음
const NO_PAPER := "「종이가 없다. 빈손으론 도안이 맺히지 않는다.」"

## 도안 완성 — 이 화면의 클라이맥스
const COMPLETE := "「도안이 맺혔다. 먹이 마르기 전에 시험해 보아라.」"
const INCOMPLETE := "아직 도안이 아니다 — 진 하나, 룬 하나, 문양 하나."

## 조작 안내 (순서 안내는 체크리스트가 상시 보여 준다 — 여긴 조작만)
const CONTROLS := "좌클릭 드래그 = 획 · 우클릭/Ctrl+Z = 취소 · 휠 = 종이 확대(작은 문양)"

## 자동보정·스탬프
const AUTOCORRECT_OK := "「형을 바로잡았다. 손맛은 네 것 그대로다.」"
const AUTOCORRECT_NONE := "바로잡을 룬이 없다 — 먼저 룬을 앉혀라."
const STAMP_NONE := "「본으로 뜰 룬이 없다. 먼저 룬을 앉혀라.」"
const STAMP_SAVED := "룬을 본으로 떠 두었다 — 목록에서 골라 종이를 눌러라."
const STAMP_PLACE := "종이를 눌러 본을 앉힌다 (우클릭 = 물린다) · 정확도는 뜬 그대로 남는다."

## 방위 — 캔버스 위쪽이 조준 방향이다
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

## 문양 4종 — **탄이 어떻게 나가는가** (v1.9, GDD §4.3). 기본은 글자가 아니다(곧은 획).
## 룬과 같은 문법으로 읽힌다: **모양 = 방식 / 길이 = 세기**
const GLYPH_LABEL := {
	Enums.GlyphType.BASIC: "기본",
	Enums.GlyphType.BOUNCE: "팅김⚡",
	Enums.GlyphType.HOMING: "유도∿",
	Enums.GlyphType.PIERCE: "관통‖",
}
## 무엇을 하는 글자인가 + **길게 그으면 무엇이 늘어나는가** (길이 = 세기 축을 눈에 보이게).
## 길이가 아무것도 안 하면 "짧게 긋는 게 이득"이 되고 표현 수단이 죽는다 (v1.6~v1.8의 교훈)
const GLYPH_EFFECT := {
	Enums.GlyphType.BASIC: "곧게 난다 — 길수록 멀리",
	Enums.GlyphType.BOUNCE: "벽에 튄다 — 길수록 여러 번",
	Enums.GlyphType.HOMING: "쫓아간다 — 길수록 오래",
	Enums.GlyphType.PIERCE: "꿰뚫는다 — 길수록 여럿",
}

static func glyph_label(glyph_type: int) -> String:
	return String(GLYPH_LABEL.get(glyph_type, "?"))

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
## ⚠ v1.9 정정: 룬의 정확도는 **위력이 아니라 순도**를 정하고(v1.7 축 분리), 문양의 길이는
## **크기가 아니라 사거리**를 정한다(v1.6 규모 이관 → v1.9 사거리 배율). 옛 문구는 둘 다
## 플레이어에게 **틀린 규칙을 가르치고 있었다.**
const TAB_DESC := {
	Enums.DrawStage.CIRCLE: "경계를 두른다. 진의 크기가 곧 규모 —\n위력·탄 크기·사거리를 전부 진이 정한다.",
	Enums.DrawStage.RUNE: "진 안에 앉힌다. 무엇으로 때리는가.\n진을 꽉 채울수록 속성이 깊이 물든다.",
	Enums.DrawStage.ARROW: "진을 뚫고 나가는 획 — 하나가 한 발.\n무엇을 그리느냐가 그 탄의 방식이다.",
}

## 룬 4종 — 무엇을 하는 글자인가 (GDD §4.2)
const RUNE_EFFECT := {
	Enums.RuneType.FIRE: "태운다 — 화상·지속 피해",
	Enums.RuneType.IMPACT: "때린다 — 넉백·점 타격",
	Enums.RuneType.WATER: "적신다 — 둔화·갑주 무력",
	Enums.RuneType.WIND: "흩는다 — 확산·면 제어",
}

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
	match rune_type:
		Enums.RuneType.FIRE:
			return "불△"
		Enums.RuneType.IMPACT:
			return "충격>"
		Enums.RuneType.WATER:
			return "물~"
		Enums.RuneType.WIND:
			return "바람◎"
	return ""
