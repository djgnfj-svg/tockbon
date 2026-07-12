extends RefCounted
## 먹·한지 팔레트 + StyleBoxFlat 팩토리 + 표기 헬퍼 (모듈 E 공용).
## class_name 없이 사용: const InkStyle := preload("res://src/ui/ink_style.gd")
## 지금은 단색+테두리 플레이스홀더 — 추후 잉크·종이 질감 텍스처로 교체 (GDD §10.5).

# ── 한지·먹 팔레트
const PAPER := Color(0.941, 0.902, 0.824)         # 한지 #f0e6d2
const PAPER_DARK := Color(0.886, 0.831, 0.718)    # 묵은 한지
const PAPER_SHADOW := Color(0.788, 0.722, 0.569)  # 한지 그늘
const INK := Color(0.165, 0.149, 0.133)           # 먹 #2a2622
const INK_SOFT := Color(0.290, 0.259, 0.220)      # 옅은 먹
const INK_FAINT := Color(0.522, 0.478, 0.408)     # 바랜 먹 (비활성·미해금)
const SEAL := Color(0.710, 0.278, 0.180)          # 인주 주홍 (경고·강조)
const DIM := Color(0.100, 0.090, 0.080, 0.45)     # 모달 뒤 어둠

# ── 룬 4종 표기 (GDD §4.2)
const RUNE_GLYPHS := {
	Enums.RuneType.FIRE: "△",
	Enums.RuneType.IMPACT: ">",
	Enums.RuneType.WATER: "~",
	Enums.RuneType.WIND: "◎",
}
const RUNE_NAMES := {
	Enums.RuneType.FIRE: "불",
	Enums.RuneType.IMPACT: "충격",
	Enums.RuneType.WATER: "물",
	Enums.RuneType.WIND: "바람",
}
const RUNE_COLORS := {
	Enums.RuneType.FIRE: Color(0.659, 0.294, 0.196),
	Enums.RuneType.IMPACT: Color(0.478, 0.424, 0.247),
	Enums.RuneType.WATER: Color(0.247, 0.420, 0.478),
	Enums.RuneType.WIND: Color(0.373, 0.478, 0.294),
}

# ── 페이즈 표기 (채움 정도 = 하루의 저묾)
const PHASE_NAMES := {
	Enums.Phase.MORNING: "아침",
	Enums.Phase.DAY: "낮",
	Enums.Phase.EVENING: "저녁",
	Enums.Phase.NIGHT: "밤",
}
const PHASE_GLYPHS := {
	Enums.Phase.MORNING: "○",
	Enums.Phase.DAY: "◐",
	Enums.Phase.EVENING: "◑",
	Enums.Phase.NIGHT: "●",
}
const PHASE_COLORS := {
	Enums.Phase.MORNING: Color(0.839, 0.702, 0.451),
	Enums.Phase.DAY: Color(0.800, 0.620, 0.300),
	Enums.Phase.EVENING: Color(0.710, 0.278, 0.180),
	Enums.Phase.NIGHT: Color(0.290, 0.259, 0.220),
}

static func rune_glyph(t: int) -> String:
	return RUNE_GLYPHS.get(t, "?")

static func rune_name(t: int) -> String:
	return RUNE_NAMES.get(t, "?")

static func rune_color(t: int) -> Color:
	return RUNE_COLORS.get(t, INK)

static func phase_name(p: int) -> String:
	return PHASE_NAMES.get(p, "?")

static func phase_glyph(p: int) -> String:
	return PHASE_GLYPHS.get(p, "?")

static func phase_color(p: int) -> Color:
	return PHASE_COLORS.get(p, INK_SOFT)

# ── 도감 해금 id 규약 (리드 확정 대기 — 보고서 참조)
static func rune_unlock_id(t: int) -> StringName:
	match t:
		Enums.RuneType.FIRE: return &"rune_fire"
		Enums.RuneType.IMPACT: return &"rune_impact"
		Enums.RuneType.WATER: return &"rune_water"
		Enums.RuneType.WIND: return &"rune_wind"
	return &"rune_unknown"

static func enemy_unlock_id(enemy_id: StringName) -> StringName:
	return StringName("enemy_" + String(enemy_id))

# ── StyleBox 팩토리

static func make_panel(bg: Color = PAPER, border: Color = INK, border_w: int = 2,
		corner: int = 3, pad_h: int = 8, pad_v: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

static func make_bar_bg() -> StyleBoxFlat:
	var sb := make_panel(Color(PAPER_SHADOW.r, PAPER_SHADOW.g, PAPER_SHADOW.b, 0.85), INK, 1, 2, 1, 1)
	return sb

static func make_bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	return sb

static func make_focus() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = SEAL
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb

## 모듈 E 전 화면 공용 Theme — ui_root에서 1회 적용, 하위 상속
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 10

	t.set_color("font_color", "Label", INK)

	t.set_stylebox("normal", "Button", make_panel(PAPER_DARK, INK, 1, 2, 6, 3))
	t.set_stylebox("hover", "Button", make_panel(PAPER, INK, 1, 2, 6, 3))
	t.set_stylebox("pressed", "Button", make_panel(INK_SOFT, INK, 1, 2, 6, 3))
	t.set_stylebox("disabled", "Button", make_panel(PAPER_SHADOW, INK_FAINT, 1, 2, 6, 3))
	t.set_stylebox("focus", "Button", make_focus())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", INK_FAINT)
	t.set_color("font_focus_color", "Button", INK)

	t.set_stylebox("panel", "PanelContainer", make_panel())

	t.set_stylebox("panel", "TabContainer", make_panel(PAPER, INK, 1, 0, 6, 6))
	t.set_stylebox("tab_selected", "TabContainer", make_panel(PAPER, INK, 1, 0, 8, 3))
	t.set_stylebox("tab_unselected", "TabContainer", make_panel(PAPER_SHADOW, INK_SOFT, 1, 0, 8, 3))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", INK_SOFT)

	t.set_stylebox("background", "ProgressBar", make_bar_bg())
	t.set_stylebox("fill", "ProgressBar", make_bar_fill(INK_SOFT))

	t.set_color("separator", "HSeparator", INK_FAINT)
	return t

# ── 공용 유틸

## 리스트 rebuild용 — queue_free 잔존 자식이 카운트를 오염시키지 않게 즉시 분리
static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func make_label(text: String, font_size: int = 10, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
