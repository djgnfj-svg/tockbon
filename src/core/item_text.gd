extends RefCounted
## 🔴 장비 **효과 문구**의 단일 소스. class_name 없음 —
## `const ItemText := preload("res://src/core/item_text.gd")`로 참조한다.
##
## 사본을 두면 `Enums.WandPattern`에 값을 더하거나 모자에 파라미터를 붙일 때 고친 한 곳만 맞고
## 나머지(소지품 착용줄·캐릭터 탭·공방 행)는 빈 문자열로 남아서 여기로 합쳤다.
## `src/hud`가 아니라 core인 이유 — `workshop_panel`(src/base)이 hud를 preload하면 모듈 경계가 깨진다.
##
## 🔴 `Db`를 참조하지 않고 `ItemDef`를 **받아서** 답한다 — 그래야 순수 static이라
## `-s` 테스트가 오토로드 등록 전 컴파일에서 안 터진다. id→ItemDef 조회는 호출부/`Db` 몫이다.
## ⚠ 수치는 전부 아이템 `.tres`의 `params`에서 읽는다 — 여기에 밸런스 상수를 박지 마라.


## 재료 진행 한 칸 — `이름 보유/필요`. 진행 막대 관례대로 **보유가 먼저다**(인자 순서를 뒤집지 마라).
## ⚠ 이름 조회는 호출부가 한다 — 이 파일은 `Db`를 안 본다.
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


## 지팡이 아이템의 효과 문구 — 세기·속도 스칼라만.
## 🔴 발사 **형태**는 여기 적지 마라 — 형태는 진(`JinDef.pattern`)이 정한다. 지팡이가 다시 형태를
## 말하면 진이 정한 형태와 화면에서 갈라진다.
## 🔴 적는 축은 소비자가 있는 것만이다(`wand_speed_mult`·`wand_mana_mult`) — 아무도 안 읽는 키를
## 문구에 적으면 「효과가 있다고 써 놓고 아무 일도 안 하는」 필드가 된다.
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
