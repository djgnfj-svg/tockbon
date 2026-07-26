extends Control
## 재사용 대사 상자 — 여러 줄 대사를 한 줄씩 넘긴다. **대사 내용을 모른다**(줄 배열을 받는 범용).
## 온보딩·정산에서 **문**(`base.gd`의 `ForestGate`)이 한 줄씩 말할 때 리드가 open()으로 배선한다.
## ⚠ 세95에 화자가 길잡이 NPC → 문으로 바뀌었다(길잡이 은퇴 — 설계 `world_and_visual_design.md` §2).
##
## 🔴 **모달 규약은 `tab_panel`과 같다**(그게 살아 있는 참고 원본 — 옛 inventory_panel은
## 세40에 tab_panel이 흡수하며 삭제됐다. 찾지 마라, 필요하면 git 이력):
##  · 열리면 GameState.ui_modal_open=true → player(이동)·caster(조준·발사)가 폴링해 멎는다.
##  · finished 직전 false → 다시 움직이고 쏠 수 있다.
##  · 닫히면 visible=false → GUI 히트테스트에서 빠져 아무 입력도 안 먹는다(클릭이 바닥으로 샌다).
##  · 닫힌 Control도 _unhandled_input은 받으므로(mouse_filter는 마우스만 가른다) 모든 입력 핸들러를
##    `if not _open: return`으로 가둔다 — 닫힌 상자가 E/ESC를 훔치면 안 된다(NPC·다른 패널 것).
##
## 🔴 **mouse_filter 함정**(세션25): 이 루트는 열린 동안 STOP이라 좌클릭을 통째로 먹는다 — 대사를
## 읽는 동안 실수로 안 쏘게. 그래서 진행 좌클릭은 _gui_input(root가 STOP이라 마우스가 여기로 온다),
## 진행 키(E)·건너뛰기(ESC)는 _unhandled_input, "▶" 버튼은 pressed 시그널 — 세 경로가 모두 _advance로
## 모인다. 상자(밴드)·라벨은 mouse_filter=IGNORE라 밴드 아무 데나 클릭해도 root로 버블돼 진행된다.
## "▶" 버튼만 STOP이라 독립적으로 눌린다.
## ⚠ 이 컴포넌트는 헤드리스가 클릭·렌더를 못 잡는다 — 리드가 실게임 push_input으로 확인해야 한다.
##
## 🔴 **CanvasLayer(layer 8) 위에 산다**(dialogue_box.tscn) — 카메라가 플레이어를 따라다녀 월드에
## 그리면 밴드가 흘러간다(HUD·tab_panel과 같은 이유). HUD(하단 슬롯)보다 위, 책(forge, layer 10)보다
## 아래에 둔다.

## 대사가 끝났거나(마지막 줄에서 한 번 더) 건너뛰었을(ESC) 때 정확히 한 번 emit.
signal finished

## 🔴🔴 **사본이 하나 더 있다 — `dialogue_box.tscn`의 `Nameplate/Speaker` 라벨 `text`.**
##   씬 기본값은 상자를 열기 전(또는 `open()`이 안 불린 프레임)에 화면에 나가므로 **둘 다 고쳐야 한다** —
##   코드만 고치면 눈에 잘 안 띄는 채로 옛 이름이 남는다(세86에 실제로 밟은 형태).
##   그물 = `test_dialogue_box_auto`의 「기본 화자」 문자열 검사.
const SPEAKER_DEFAULT := "문"
const FADE_TIME := 0.12   # 연출값(밸런스 아님) — 등장 페이드

@onready var _text: Label = $Band/Margin/VBox/Text
@onready var _hint: Label = $Band/Margin/VBox/Footer/Hint
@onready var _next: Button = $Band/Margin/VBox/Footer/Next
@onready var _speaker: Label = $Nameplate/Speaker

var _lines: Array = []
var _index: int = 0
var _open: bool = false
var _fade: Tween = null


func _ready() -> void:
	# 닫힌 동안엔 클릭을 먹지 않는다(visible=false면 히트테스트에서 빠진다). 열리면 STOP이라
	# 좌클릭을 통째로 먹어 대사를 읽는 동안 실수로 안 쏜다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_next.pressed.connect(_advance)


# ─────────────────────────── 공개 API (리드가 배선) ───────────────────────────

## 대사 줄들(String 배열)을 받아 첫 줄을 띄우고 상자를 보인다.
## 🔴 빈 배열이면 아무것도 안 하고 즉시 finished — 호출부가 "대사 없음"을 특수 처리하지 않아도 된다.
## speaker_name은 선택(기본 = `SPEAKER_DEFAULT`). open(lines)만 불러도 된다.
func open(lines: Array, speaker_name: String = SPEAKER_DEFAULT) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = 0
	_open = true
	visible = true
	GameState.ui_modal_open = true
	_speaker.text = speaker_name
	_show_current()
	_play_fade_in()


# ─────────────────────────── 진행·종료 ───────────────────────────

## 진행 키(E) / 건너뛰기(ESC)는 여기서. 좌클릭은 root가 STOP이라 _gui_input으로 가고,
## 키는 _unhandled_input으로 온다(mouse_filter는 마우스만 가른다). 닫혔으면 아무것도 안 먹는다.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_finish()   # 건너뛰기 — 바로 숨기고 finished
		get_viewport().set_input_as_handled()


## 밴드(및 그 위 빈 영역) 좌클릭 = 다음 줄. root가 STOP이라 마우스가 이 _gui_input으로 온다.
## 밴드·라벨은 IGNORE라 밴드 클릭도 root로 버블된다. "▶" 버튼만 STOP이라 별도로 pressed를 쏜다.
func _gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			accept_event()


## 다음 줄로. 마지막 줄에서 한 번 더 누르면 종료.
func _advance() -> void:
	if not _open:
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_current()


func _show_current() -> void:
	_text.text = str(_lines[_index])
	var last := _index >= _lines.size() - 1
	# 마지막 줄이면 "▶" 대신 "✕"(닫기)로 — 한 번 더 누르면 끝난다는 신호.
	_next.text = "✕" if last else "▶"
	_hint.text = ("[E] / 좌클릭  닫기      [ESC] 건너뛰기" if last
		else "[E] / 좌클릭  다음      [ESC] 건너뛰기")


## 상자를 숨기고 모달을 풀고 finished를 한 번 emit. 진행 완료·건너뛰기 공용 종료 경로.
func _finish() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GameState.ui_modal_open = false
	if _fade != null and _fade.is_valid():
		_fade.kill()
	modulate.a = 1.0
	_lines = []
	finished.emit()


func _play_fade_in() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, FADE_TIME)
