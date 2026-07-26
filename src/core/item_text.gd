extends RefCounted
## 🔴 장비 **효과 문구**의 단일 소스 (세84 감사 #21). class_name 없음 —
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


## 🔴 재료 진행 한 칸 — **`이름 보유/필요`** (세87 사냥 흐름 §7). 진행 막대 관례대로 **보유가 먼저다.**
##
## 왜 core로 올렸나: 공방·정제대가 **글자까지 같은 사본**을 각자 들고 있었고 **둘 다 인자가 거꾸로**였다
## (`[name, need, have]` — 주석은 *"재료(보유/필요)"*라고 선언하는데 코드가 반대라, 5개 필요한데 3개
## 가졌으면 "슬라임 핵 5/3"으로 찍혔다). 한쪽만 고치면 다른 쪽이 계속 거꾸로 남는다 = 감사 T5.
## ⚠ **이름 조회는 호출부가 한다**(`Db.get_item(id).display_name`) — 이 파일은 `Db`를 안 본다.
static func count_text(item_name: String, have: int, need: int) -> String:
	return "%s %d/%d" % [item_name, have, need]


## 장비 효과 한 줄 — 펜=보정, 로브=HP/마나, 지팡이=진 속도·발사 마나, 부적=구르기 쿨, 모자=이동 속도.
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
			return wand_text(it)
		Enums.ItemKind.CHARM:
			return "구르기 쿨 -%d%%" % roundi((1.0 - float(it.params.get("dash_cooldown_mult", 1.0))) * 100.0)
		Enums.ItemKind.HAT:
			return "이동 속도 +%d%%" % roundi(float(it.params.get("move_speed_mult", 0.0)) * 100.0)
		_:
			return ""


## 지팡이 아이템의 효과 문구 — **세기·속도 스칼라** (세85, 감사 #5).
##
## 🔴 옛 `wand_pattern_text`/`pattern_label`(발사 패턴 → "산탄 (여러 발)"·"전방위")은 **은퇴했다**:
## 발사 형태는 이제 **진**만 정한다(`JinDef.pattern`). 지팡이가 형태를 쥐던 축은 실제로 도달 불가였고
## (`ring_spell_system`의 폴백이 진 없는 도안에서만 걸렸다) 두 축이 같은 자리를 다투고 있었다.
## 되살리지 마라 — 지팡이가 다시 형태를 말하면 진이 정한 형태와 화면에서 갈라진다.
##
## 🔴 여기 적는 축은 **소비자가 있는 것만이다**: `wand_speed_mult`(→ `ring_spell_system._spawn_carrier`)·
## `wand_mana_mult`(→ `GameState.cast_mana_cost`). 소비자 없는 키를 문구에 적으면 그게 곧
## `attack_cooldown_mult`(선언만 있고 아무도 안 읽어 1.15가 무효였다)의 재발이다.
static func wand_text(it: ItemDef) -> String:
	if it == null:
		return ""
	var parts: Array[String] = []
	var spd := float(it.params.get("wand_speed_mult", 1.0))
	if not is_equal_approx(spd, 1.0):
		parts.append("진 속도 %+d%%" % roundi((spd - 1.0) * 100.0))
	var mana := float(it.params.get("wand_mana_mult", 1.0))
	if not is_equal_approx(mana, 1.0):
		parts.append("발사 마나 %+d%%" % roundi((mana - 1.0) * 100.0))
	return " · ".join(parts)
