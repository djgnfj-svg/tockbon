extends Control
## 타이틀 메뉴 (세션37) — 게임의 새 진입점(project.godot main_scene). [이어하기]/[새로하기] 라우팅.
##
## 🔴 왜 이 메뉴가 생겼나 (F8): 세션26에 저장을 켠 대가로 **부팅이 무조건 세이브를 이어받아
## 「새로하기」가 사라졌었다.** SaveManager._ready는 **그대로** 부팅 시 load_game()한다(F3 가드 유지) —
## 이 메뉴는 그 로드된 상태를 **이어갈지 / 버리고 새로 시작할지**만 고른다. 부팅 흐름은 안 건드린다.
##   • [이어하기] = 이미 로드됐으니 베이스로 씬 전환만.
##   • [새로하기] = SaveManager.start_new_game() → wipe + GameState.new_game() + 저장 → 베이스.
##
## ⚠ 화면을 덮는 Control이지만 여기선 버튼(mouse_filter=STOP 기본)만 클릭하므로, 세션25의
## Ground STOP 함정(바닥이 좌클릭을 먹음)과 무관하다 — 발사 계층이 아예 없다.

const BASE_SCENE := "res://src/base/base.tscn"

@onready var _continue_btn: Button = $Center/Box/ContinueButton
@onready var _new_btn: Button = $Center/Box/NewButton

## 진행이 있을 때 새로하기 2단 확인 — 첫 클릭은 무장, 둘째 클릭이 실행 (다이얼로그 없이 = alert 함정 회피).
var _new_armed: bool = false

func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_on_new)
	var has: bool = SaveManager.has_save()
	_continue_btn.visible = has
	_continue_btn.disabled = not has
	(_continue_btn if has else _new_btn).grab_focus()

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
