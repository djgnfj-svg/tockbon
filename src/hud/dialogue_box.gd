extends Control
## 재사용 대사 상자 — 여러 줄 대사를 한 줄씩 넘긴다. **대사 내용을 모른다**(줄 배열을 받는 범용).
##
## 🔴 **모달 규약**:
##  · 열리면 `GameState.ui_modal_open = true` → player(이동)·caster(조준·발사)가 폴링해 멎는다.
##  · 닫히면 `visible = false` → GUI 히트테스트에서 빠져 클릭이 바닥으로 샌다.
##  · 🔴 **닫힌 Control도 `_unhandled_input`은 받는다** — 그래서 모든 입력 핸들러를 `if not _open:
##    return`으로 가둔다. 닫힌 상자가 E/ESC를 훔치면 다른 패널이 안 열린다.
##
## 🔴 **mouse_filter 함정**: 이 루트는 열린 동안 STOP이라 **좌클릭을 통째로 먹는다**(대사를 읽는 동안
## 실수로 안 쏘게). 그래서 진행 좌클릭은 `_gui_input`, 키는 `_unhandled_input`, "▶"는 pressed —
## 세 경로가 전부 `_advance`로 모인다. 밴드·라벨은 IGNORE라 아무 데나 클릭해도 root로 버블된다.
## ⚠ 헤드리스가 클릭·렌더를 못 잡는다 — 실게임 push_input으로 확인해야 한다.
##
## 🔴 **CanvasLayer 위에 산다** — 카메라가 플레이어를 따라다녀 월드에 그리면 밴드가 흘러간다.

## 대사가 끝났거나(마지막 줄에서 한 번 더) 건너뛰었을(ESC) 때 정확히 한 번 emit.
signal finished

## 🔴🔴 **사본이 하나 더 있다 — 씬의 `Nameplate/Speaker` 라벨 `text`.** 씬 기본값은 상자를 열기 전
##   프레임에 화면으로 나가므로 **둘 다 고쳐야 한다**(코드만 고치면 옛 이름이 조용히 남는다).
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_next.pressed.connect(_advance)


# ─────────────────────────── 공개 API ───────────────────────────

## 🔴 빈 배열이면 아무것도 안 하고 즉시 finished — 호출부가 "대사 없음"을 특수 처리하지 않아도 된다.
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

## 진행 키(E) / 건너뛰기(ESC). 🔴 닫혔으면 아무것도 안 먹는다(머리말 참조).
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_finish()   # 건너뛰기 — 바로 숨기고 finished
		get_viewport().set_input_as_handled()


## 밴드 좌클릭 = 다음 줄.
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


## 진행 완료·건너뛰기 공용 종료 경로 — 🔴 여기가 `ui_modal_open`을 푸는 유일한 자리다.
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
