extends RefCounted
## 아이템 아이콘 아틀라스 (ART_SPEC P4) — assets/sprites/ui/items.png 16×16 가로 스트립.
## class_name 없음 — `const ItemIcons := preload("res://src/core/item_icons.gd")`로 참조.
## 순서는 scratchpad build_items.lua(아트 생성 스크립트)와 이 표가 유일한 계약 — 변경은 리드만.

const SHEET_PATH := "res://assets/sprites/ui/items.png"
const ICON_SIZE := 16
const ICON_INDEX := {
	&"ink_basic": 0, &"ink_mid": 1, &"ink_high": 2,
	&"paper_1": 3, &"paper_2": 4, &"paper_3": 5,
	&"fragment_water": 6, &"fragment_wind": 7,
	&"mat_vine": 8, &"mat_hound_fang": 9, &"mat_slime_core": 10,
	&"mat_mist_essence": 11, &"mat_beetle_shell": 12,
	&"mat_night_bloom": 13, &"mat_moon_sap": 14,
	&"wand_basic": 15, &"robe_basic": 16, &"charm_basic": 17,
}

static var _sheet: Texture2D = null
static var _checked: bool = false
static var _cache: Dictionary = {}

## 아이템 아이콘 — 시트가 없거나(미임포트) 미등록 품목이면 null (호출부 텍스트 폴백)
static func icon(item_id: StringName) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	if not _checked:
		_checked = true
		if ResourceLoader.exists(SHEET_PATH):
			_sheet = load(SHEET_PATH)
	if _sheet == null or not ICON_INDEX.has(item_id):
		return null
	var at := AtlasTexture.new()
	at.atlas = _sheet
	at.region = Rect2(int(ICON_INDEX[item_id]) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	_cache[item_id] = at
	return at
