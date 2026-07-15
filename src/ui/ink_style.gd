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

# ── 룬 3종 표기 (v2.2: 충격 제거 — 룬은 순수 원소만)
const RUNE_GLYPHS := {
	Enums.RuneType.FIRE: "△",
	Enums.RuneType.WATER: "~",
	Enums.RuneType.WIND: "◎",
}
const RUNE_NAMES := {
	Enums.RuneType.FIRE: "불",
	Enums.RuneType.WATER: "물",
	Enums.RuneType.WIND: "바람",
}
const RUNE_COLORS := {
	Enums.RuneType.FIRE: Color(0.659, 0.294, 0.196),
	Enums.RuneType.WATER: Color(0.247, 0.420, 0.478),
	Enums.RuneType.WIND: Color(0.373, 0.478, 0.294),
}
## 픽셀 글리프 아이콘 (ART_SPEC P1) — 미임포트 환경(헤드리스 테스트 등)에서는 null → 텍스트 글리프 폴백
const RUNE_ICON_PATHS := {
	Enums.RuneType.FIRE: "res://assets/sprites/ui/rune_fire.png",
	Enums.RuneType.WATER: "res://assets/sprites/ui/rune_water.png",
	Enums.RuneType.WIND: "res://assets/sprites/ui/rune_wind.png",
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

## 룬 농도(SpellDesign.rune_fill 0..1) → 사람이 읽는 말 (v1.7 속성 농도 축, GDD §4.2).
## 구간은 **표시용**이다 — 실제 세기는 balance의 rune_density_min/max가 연속으로 정한다.
## 여기서 밸런스를 만들지 말 것 (이 값을 읽어 계산하는 코드가 생기면 축이 두 곳으로 갈라진다)
static func density_name(fill: float) -> String:
	if fill < 0.33:
		return "옅음"
	if fill < 0.66:
		return "보통"
	return "짙음"

static func rune_icon(t: int) -> Texture2D:
	var path: String = RUNE_ICON_PATHS.get(t, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## 16×16 룬 아이콘 TextureRect — 아이콘이 없으면 null (호출부에서 텍스트 폴백)
static func make_rune_icon(t: int) -> TextureRect:
	var tex := rune_icon(t)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(16, 16)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return tr

## core DesignThumb의 fallback_builder — strokes 없는 도안(샘플·구세이브)에 룬 표기를 대신 넣는다.
## core는 폴백의 생김새를 모른다(의존 방향 유지) — 스타일을 아는 모듈 E가 주입한다.
## 사용: thumb.fallback_builder = InkStyle.make_design_fallback
static func make_design_fallback(design: SpellDesign, box_size: Vector2) -> Control:
	var box := CenterContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mark: Control = make_rune_icon(design.rune_type)
	if mark == null:
		var font_size := clampi(int(minf(box_size.x, box_size.y) * 0.5), 8, 20)
		mark = make_label(rune_glyph(design.rune_type), font_size, rune_color(design.rune_type))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 버튼 위에 얹힌다 — 클릭을 먹지 않게
	box.add_child(mark)
	return box

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
		Enums.RuneType.WATER: return &"rune_water"
		Enums.RuneType.WIND: return &"rune_wind"
	return &"rune_unknown"

static func enemy_unlock_id(enemy_id: StringName) -> StringName:
	return StringName("enemy_" + String(enemy_id))

# ── StyleBox 팩토리

## 한지 9-slice 텍스처 (ART_SPEC P4) — 미임포트 환경(헤드리스 테스트 등)에서는 StyleBoxFlat 폴백
const PANEL_TEX_L := "res://assets/sprites/ui/panel_paper.png"    # 48×48 마진 12 — 모달·대형 패널
const PANEL_TEX_S := "res://assets/sprites/ui/panel_paper_s.png"  # 24×24 마진 6 — 행·버튼·칩
const PANEL_TEX_BAR := "res://assets/sprites/ui/frame_bar.png"    # 12×12 마진 3 — 바 프레임

## 텍스처 원색은 PAPER 톤으로 그려져 있다 — 요청 bg와 PAPER의 비율로 변조해
## 기존 호출부의 색 변형(묵은 한지·그늘·먹 채움·반투명)을 그대로 살린다
static func _paper_box(path: String, tex_margin: int, bg: Color,
		pad_h: int, pad_v: int) -> StyleBoxTexture:
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path) as Texture2D
	sb.set_texture_margin_all(tex_margin)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.modulate_color = Color(
		minf(bg.r / PAPER.r, 1.0), minf(bg.g / PAPER.g, 1.0), minf(bg.b / PAPER.b, 1.0), bg.a)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

## pad_v로 티어 자동 선택: 대형(모달)·소형(행·버튼)·바 프레임. border/corner는 텍스처 모드에서 무시
static func make_panel(bg: Color = PAPER, border: Color = INK, border_w: int = 2,
		corner: int = 3, pad_h: int = 8, pad_v: int = 6) -> StyleBox:
	var tex: StyleBoxTexture
	if pad_v >= 5:
		tex = _paper_box(PANEL_TEX_L, 12, bg, pad_h, pad_v)
	elif pad_v >= 2:
		tex = _paper_box(PANEL_TEX_S, 6, bg, pad_h, pad_v)
	else:
		tex = _paper_box(PANEL_TEX_BAR, 3, bg, pad_h, pad_v)
	if tex != null:
		return tex
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

static func make_bar_bg() -> StyleBox:
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
