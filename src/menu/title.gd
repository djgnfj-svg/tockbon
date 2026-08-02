extends Control
## 타이틀 메뉴 — 게임 진입점(project.godot main_scene).
##
## SaveManager._ready가 부팅 때 무조건 load_game()한다. 이 메뉴는 그 로드된 상태를
## 이어갈지 / 버리고 새로 시작할지만 고른다 — 부팅 흐름 자체는 안 건드린다.

const BASE_SCENE := "res://src/base/base.tscn"

@onready var _continue_btn: Button = $Center/Box/ContinueButton
@onready var _new_btn: Button = $Center/Box/NewButton
@onready var _sound_btn: Button = $Center/Box/SoundButton

## 새로하기 2단 확인 — 다이얼로그 대신 버튼 재클릭으로 받는다(모달 alert 함정 회피).
var _new_armed: bool = false

func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_on_new)
	_sound_btn.pressed.connect(_on_sound)
	# 음소거 상태의 주인은 Audio다. 버튼은 비출 뿐이라 시그널로 라벨을 따라간다(단축키로 꺼도 맞는다).
	EventBus.audio_muted_changed.connect(_on_muted_changed)
	_refresh_sound_label()
	var has: bool = SaveManager.has_save()
	_continue_btn.visible = has
	_continue_btn.disabled = not has
	(_continue_btn if has else _new_btn).grab_focus()

func _on_sound() -> void:
	Audio.toggle_mute()

func _on_muted_changed(_muted: bool) -> void:
	_refresh_sound_label()

func _refresh_sound_label() -> void:
	_sound_btn.text = "소리: 꺼짐" if Audio.is_muted() else "소리: 켜짐"

func _on_continue() -> void:
	# 부팅 때 이미 load_game()됐다 — 그 상태 그대로 베이스로.
	get_tree().change_scene_to_file(BASE_SCENE)

func _on_new() -> void:
	if SaveManager.has_save() and not _new_armed:
		_new_armed = true
		_new_btn.text = "정말? 진행이 사라진다 — 다시 누르면 새로 시작"
		return
	SaveManager.start_new_game()
	get_tree().change_scene_to_file(BASE_SCENE)
