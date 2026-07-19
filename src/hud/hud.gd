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
const MANA_SIZE := Vector2(240.0, 10.0)
const HUNGER_SIZE := Vector2(240.0, 10.0)
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
const MANA_FILL := Color(0.34, 0.55, 0.88)
const MANA_LOW := Color(0.90, 0.45, 0.35)
const HUNGER_FILL := Color(0.62, 0.72, 0.32)
const HUNGER_LOW := Color(0.90, 0.45, 0.35)

var _selected: int = 0
var _say: String = ""
var _warn: bool = false
## 마나·허기는 매 프레임 변해 시그널이 없다 — 값이 바뀐 프레임만 다시 그린다 (매 프레임 redraw 회피).
## 🔴 둘 다 봐야 한다: 숲에서 마나가 만땅(안 변함)이어도 허기는 줄어 막대가 얼어붙으면 안 된다.
var _last_mana: float = -1.0
var _last_hunger: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 조준 클릭이 HUD에 먹히면 안 된다
	EventBus.ring_design_committed.connect(_on_design_committed)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.audio_muted_changed.connect(_on_muted_changed)


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


func _on_muted_changed(_muted: bool) -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_equal_approx(GameState.mana, _last_mana) \
			or not is_equal_approx(GameState.hunger, _last_hunger):
		_last_mana = GameState.mana
		_last_hunger = GameState.hunger
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(MARGIN, MARGIN + 12.0), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HINT_COLOR)
	# 음소거 중이면 우상단에 표시 (O로 다시 켠다). 소리가 꺼진 걸 눈으로 알게 — 안 그러면
	# "왜 소리가 안 나지" 하고 버그로 오해한다. 이모지는 fallback_font에서 두부가 되니 텍스트로.
	if Audio.is_muted():
		draw_string(font, Vector2(size.x - 150.0, MARGIN + 12.0), "[음소거] O로 켜기",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WARN_COLOR)
	if _say != "":
		draw_string(font, Vector2(MARGIN, MARGIN + 32.0), _say,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WARN_COLOR if _warn else SAY_COLOR)

	var y := size.y - MARGIN - SLOT_SIZE.y
	for i in GameState.EQUIP_SLOTS:
		_draw_slot(font, Vector2(MARGIN + float(i) * (SLOT_SIZE.x + SLOT_GAP), y), i)
	# 마나 막대는 늘 그린다 — 베이스 연습장에서도 발사에 마나가 드니까 (HP·허기는 숲만).
	var mana_y := y - HP_GAP - MANA_SIZE.y
	_draw_mana(font, Vector2(MARGIN, mana_y))
	if show_hp:
		var hp_y := mana_y - HP_GAP - HP_SIZE.y
		_draw_hp(font, Vector2(MARGIN, hp_y))
		# 허기는 베이스에선 늘 만복이라 장식이 된다 — HP와 같은 이유로 숲(show_hp)만 그린다.
		_draw_hunger(font, Vector2(MARGIN, hp_y - HP_GAP - HUNGER_SIZE.y))


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


## 마나 막대 — 발사 예산. 다 쓰면 발사가 거부되고(caster의 spend_mana) HUD가 "마나 부족"을 띄운다.
## 숫자도 적는다: 막대만 있으면 "한 발 더 쏠 수 있나"를 못 읽는다 (HP 막대와 같은 이유).
func _draw_mana(font: Font, at: Vector2) -> void:
	var mana_max := GameState.mana_max()
	var frac := clampf(GameState.mana / mana_max, 0.0, 1.0) if mana_max > 0.0 else 0.0
	draw_rect(Rect2(at, MANA_SIZE), HP_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(at, Vector2(MANA_SIZE.x * frac, MANA_SIZE.y)),
			MANA_LOW if GameState.mana < RingPower.cast_mana_cost() else MANA_FILL, true)
	draw_rect(Rect2(at, MANA_SIZE), HP_EDGE, false, 1.0)
	draw_string(font, at + Vector2(MANA_SIZE.x + 8.0, MANA_SIZE.y - 1.0),
		"마나 %d / %d" % [floori(GameState.mana), roundi(mana_max)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HINT_COLOR)


## 허기(포만) 막대 — 숲에서만 준다. 0이면 굶어 HP가 깎인다(GameState._tick_hunger). 낮으면 붉게.
## 이게 무한 파밍을 막는다: 눌러앉으면 굶어 귀환을 강제당한다 (세션 35).
func _draw_hunger(font: Font, at: Vector2) -> void:
	var hunger_max := GameState.hunger_max()
	var frac := clampf(GameState.hunger / hunger_max, 0.0, 1.0) if hunger_max > 0.0 else 0.0
	draw_rect(Rect2(at, HUNGER_SIZE), HP_BG, true)
	if frac > 0.0:
		draw_rect(Rect2(at, Vector2(HUNGER_SIZE.x * frac, HUNGER_SIZE.y)),
			HUNGER_LOW if frac <= 0.25 else HUNGER_FILL, true)
	draw_rect(Rect2(at, HUNGER_SIZE), HP_EDGE, false, 1.0)
	draw_string(font, at + Vector2(HUNGER_SIZE.x + 8.0, HUNGER_SIZE.y - 1.0),
		"허기 %d / %d" % [floori(GameState.hunger), roundi(hunger_max)],
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
		"위력 %d · %d점" % [RingPower.power_display(design.total_score, Db.ink_mult(design.ink)),
			RingPower.score_display(design.total_score)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, POWER_COLOR)
