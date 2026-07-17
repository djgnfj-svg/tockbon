extends Control
## 플레이어 HUD — 장착한 고리 마법진 4칸 + 조작 안내 + (숲에선) HP 막대.
##
## 🔴 **베이스캠프와 숲이 같은 HUD를 쓴다** (세션 26 — 세션 25까지 `src/base/base_hud.gd`였다).
## 슬롯 4칸을 복사하면 갈라진다. 상속으로 갈라 놓는 것도 안 했다 — 다른 건 **안내 문구와 HP 막대**
## 둘뿐이고, 그건 @export 두 개면 끝난다 (백로그는 상속 + `_hint_text()` 훅을 제안했지만,
## 클래스를 하나 더 만들 이유가 되기엔 차이가 너무 작다).
##
## 🔴 위력을 **직접 계산하지 않는다** — `RingPower.power_display()`를 부른다. 조립 리포트·발사·HUD가
## 같은 함수를 봐야 한다 (src/core/ring_power.gd 주석): 복사해 두면 한쪽만 고쳐도 아무도 못 알아채고
## 갈라진다 — HUD는 "위력 140"이라 적어 놓고 130으로 때리는 식으로.
##
## 🔴 CanvasLayer 위에 산다 — 플레이어를 카메라가 따라다녀서 월드에 그리면 HUD가 같이 흘러간다.
##
## 슬롯 내용을 캐시하지 않고 `_draw`가 매번 `GameState.ring_equipped`를 읽는다. 그래서 갱신은
## `queue_redraw()` 하나로 끝나고, 같은 시그널을 받는 GameState와의 **연결 순서를 따질 필요가 없다**
## (실제 그리기는 프레임 끝에 일어나므로 그때는 이미 장착이 끝나 있다).

const RingPower := preload("res://src/core/ring_power.gd")

## 🔴 조작 안내 — **씬마다 다르다.** 베이스엔 책상이 있고 숲엔 귀환 지점이 있다.
## 있지도 않은 조작을 가르치면 그 자체가 버그다 (숲에서 "책상에서 E"를 가르치는 식).
## ⚠ 발사는 **좌클릭만** — Space를 적지 마라 (사용자 확정).
@export_multiline var hint_text: String = "WASD=이동 · 마우스=조준 · 좌클릭=발사 · 1~4=슬롯"
## HP 막대를 그리나 — 숲(맞는 곳)만 참. 베이스는 다칠 일이 없어 빈 막대가 장식이 된다.
@export var show_hp: bool = false

# ── 연출값 (밸런스 아님 — 선례: 시험대의 PLAYER_SPEED·색 상수) ──
const SLOT_SIZE := Vector2(124.0, 48.0)
const SLOT_GAP := 8.0
const MARGIN := 16.0
const HP_SIZE := Vector2(240.0, 12.0)
const HP_GAP := 10.0

const SLOT_BG := Color(0.10, 0.09, 0.08, 0.72)
const SLOT_BG_ON := Color(0.20, 0.16, 0.10, 0.88)
const SLOT_EDGE := Color(0.45, 0.42, 0.36, 0.75)
const SLOT_EDGE_ON := Color(0.98, 0.72, 0.30)
const INDEX_COLOR := Color(0.62, 0.58, 0.50)
const INDEX_COLOR_ON := Color(0.98, 0.82, 0.45)
const NAME_COLOR := Color(0.90, 0.86, 0.78)
const POWER_COLOR := Color(0.95, 0.68, 0.30)
const EMPTY_COLOR := Color(0.50, 0.47, 0.42)
const HINT_COLOR := Color(0.70, 0.66, 0.58)
const SAY_COLOR := Color(0.85, 0.82, 0.74)
const WARN_COLOR := Color(0.92, 0.45, 0.35)
const HP_BG := Color(0.10, 0.09, 0.08, 0.72)
const HP_FILL := Color(0.80, 0.30, 0.28)
const HP_LOW := Color(0.95, 0.55, 0.20)
const HP_EDGE := Color(0.45, 0.42, 0.36, 0.75)

var _selected: int = 0
var _say: String = ""
var _warn: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 조준 클릭이 HUD에 먹히면 안 된다
	EventBus.ring_design_committed.connect(_on_design_committed)
	EventBus.player_hp_changed.connect(_on_hp_changed)


## 지금 고른 슬롯 (caster의 slot_changed가 알려 준다).
func select(slot: int) -> void:
	_selected = slot
	queue_redraw()


## 한 줄 안내문. warn=true면 붉게 (빈 슬롯에 쏘려 한 경우 등).
func say(text: String, warn: bool = false) -> void:
	_say = text
	_warn = warn
	queue_redraw()


## 새 마법진이 맺혔다 — GameState가 같은 시그널로 빈 슬롯에 장착한다.
## HUD가 이걸 놓치면 **맺자마자 슬롯이 빈 채로 보인다**.
func _on_design_committed(_design: RingDesign) -> void:
	say("새 마법진이 맺혔다 — 책을 덮고(ESC) 좌클릭으로 쏴 보세요")


func _on_hp_changed(_hp: float, _hp_max: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(MARGIN, MARGIN + 12.0), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HINT_COLOR)
	if _say != "":
		draw_string(font, Vector2(MARGIN, MARGIN + 32.0), _say,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WARN_COLOR if _warn else SAY_COLOR)

	var y := size.y - MARGIN - SLOT_SIZE.y
	for i in GameState.EQUIP_SLOTS:
		_draw_slot(font, Vector2(MARGIN + float(i) * (SLOT_SIZE.x + SLOT_GAP), y), i)
	if show_hp:
		_draw_hp(font, Vector2(MARGIN, y - HP_GAP - HP_SIZE.y))


## HP 막대 — GameState가 원장이다 (씬을 갈아타도 남는 값). 숫자도 같이 적는다:
## 막대만 있으면 "조금 남았다"는 알아도 **한 대를 더 맞아도 되는지**는 모른다.
func _draw_hp(font: Font, at: Vector2) -> void:
	var hp_max := GameState.hp_max()
	var frac := clampf(GameState.hp / hp_max, 0.0, 1.0) if hp_max > 0.0 else 0.0
	draw_rect(Rect2(at, HP_SIZE), HP_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(at, Vector2(HP_SIZE.x * frac, HP_SIZE.y)),
			HP_LOW if frac <= 0.3 else HP_FILL, true)
	draw_rect(Rect2(at, HP_SIZE), HP_EDGE, false, 1.0)
	draw_string(font, at + Vector2(HP_SIZE.x + 8.0, HP_SIZE.y - 1.0),
		"HP %d / %d" % [ceili(GameState.hp), roundi(hp_max)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HINT_COLOR)


## 슬롯 한 칸 — 빈 칸은 비어 보이고, 찬 칸은 **손그림 점수와 그게 만든 위력**을 보여 준다.
## 이름만 적으면 잘 그린 진과 막 그린 진이 HUD에서 똑같아 보인다 — 세션 23이 점수에 이빨을
## 준 이유가 그거였으니 여기서 다시 감추면 안 된다.
func _draw_slot(font: Font, at: Vector2, idx: int) -> void:
	var on := idx == _selected
	var rect := Rect2(at, SLOT_SIZE)
	draw_rect(rect, SLOT_BG_ON if on else SLOT_BG, true)
	draw_rect(rect, SLOT_EDGE_ON if on else SLOT_EDGE, false, 2.0 if on else 1.0)
	draw_string(font, at + Vector2(7.0, 15.0), "%d" % (idx + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INDEX_COLOR_ON if on else INDEX_COLOR)

	var design: RingDesign = GameState.ring_equipped[idx]
	if design == null:
		draw_string(font, at + Vector2(22.0, 30.0), "비어 있음",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, EMPTY_COLOR)
		return
	draw_string(font, at + Vector2(22.0, 20.0), design.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, NAME_COLOR)
	# 🔴 점수 반올림도 core가 판다 — 「퍼펙트」가 그 반올림으로 정의돼 있다 (score_display 주석).
	draw_string(font, at + Vector2(22.0, 38.0),
		"위력 %d · %d점" % [RingPower.power_display(design.total_score),
			RingPower.score_display(design.total_score)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, POWER_COLOR)
