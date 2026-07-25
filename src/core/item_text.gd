extends RefCounted
## 🔴 장비 **효과 문구·발사 패턴 라벨**의 단일 소스 (세84 감사 #21). class_name 없음 —
## `const ItemText := preload("res://src/core/item_text.gd")`로 참조한다.
##
## 왜 생겼나: 같은 문구가 **세 벌**로 흩어져 있었다 —
##   `tab_panel._effect_text`/`_wand_pattern_text`/`_pattern_label` · `workshop_panel._effect_text`/
##   `_wand_pattern_text`. 포맷 문자열까지 글자 하나 안 틀리게 같았고 주석이 스스로
##   *"workshop_panel과 동일"*이라 자백하고 있었다. `Enums.WandPattern`에 값을 더하거나 모자에
##   파라미터를 붙이면 **고친 한 곳만 맞고** 나머지(소지품 착용줄·캐릭터 탭·공방 행)는 빈 문자열이나
##   "단발"로 남는다 — `grade_colors.gd`를 core로 올린 이유와 같은 실패 방식이다.
##
## 🔴 **왜 `src/hud/`가 아니라 core인가**: `workshop_panel`이 `src/base`다. 그 패널이 `src/hud`를
## preload하면 모듈 경계(takbon-rules §0: 모듈 간은 EventBus + core 스키마만)가 깨진다.
## `grade_colors.gd`가 core에 있는 이유가 정확히 그것이다.
##
## 🔴 **`Db`를 참조하지 않는다 — `ItemDef`를 받아서 답한다**(`glyph_rules.gd` 선례).
## id→ItemDef 조회는 `Db`가 쥔다 — 호출부가 `Db.get_item(id)`를 넘긴다. 그래서 이 파일은
## 순수 static이고 `-s` 오토로드 컴파일 함정에 안 걸린다.
## ⚠ 수치는 전부 아이템 `.tres`의 `params`에서 읽는다 — 여기에 밸런스 상수를 박지 마라.


## 장비 효과 한 줄 — 펜=보정, 로브=HP/마나, 지팡이=발사 패턴, 부적=구르기 쿨, 모자=이동 속도.
## 효과가 없거나 장비가 아니거나 `it == null`이면 빈 문자열(호출부가 "" 검사로 줄을 건너뛴다).
static func effect_text(it: ItemDef) -> String:
	if it == null:
		return ""
	match int(it.kind):
		Enums.ItemKind.PEN:
			return "손그림 보정 +%.2f" % float(it.params.get("correction", 0.0))
		Enums.ItemKind.ROBE:
			var parts: Array[String] = []
			if it.params.has("hp_max_add"):
				parts.append("HP +%d" % int(it.params["hp_max_add"]))
			if it.params.has("mana_max_add"):
				parts.append("마나 +%d" % int(it.params["mana_max_add"]))
			return " · ".join(parts)
		Enums.ItemKind.WAND:
			return wand_pattern_text(it)
		Enums.ItemKind.CHARM:
			return "구르기 쿨 -%d%%" % roundi((1.0 - float(it.params.get("dash_cooldown_mult", 1.0))) * 100.0)
		Enums.ItemKind.HAT:
			return "이동 속도 +%d%%" % roundi(float(it.params.get("move_speed_mult", 0.0)) * 100.0)
		_:
			return ""


## 지팡이 아이템의 발사 패턴 문구. 🔴 **말은 `pattern_label`이 판다** — 여긴 `.tres`에서 값을
## 꺼내는 일만 한다(옛 사본 둘은 match를 각자 갖고 있어 값을 더하면 갈라졌다).
static func wand_pattern_text(it: ItemDef) -> String:
	if it == null:
		return ""
	return pattern_label(int(it.params.get("wand_pattern", Enums.WandPattern.SINGLE)))


## 발사 패턴(`Enums.WandPattern`) → 사람 말. 지팡이를 안 든 경우도 `GameState.wand_pattern()`이
## SINGLE을 돌려주므로 늘 뭔가 보여 준다(캐릭터 탭이 그 경로로 부른다).
## ⚠ BURST·SPRAY·SEEK는 아직 표시 어휘가 없다 — 폴백("단발")이 아니라 값이 오면 여기 한 줄이다
## (지금 콘텐츠엔 도달 경로가 없다 — 감사 #5).
static func pattern_label(pattern: int) -> String:
	match pattern:
		Enums.WandPattern.MULTI:
			return "산탄 (여러 발)"
		Enums.WandPattern.NOVA:
			return "전방위"
		_:
			return "단발"
