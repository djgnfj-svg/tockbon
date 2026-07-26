## 실게임 스크린샷 도구 (세91) — 「존재는 재도 보인다는 못 본다」를 메우는 눈.
##
## 왜: 헤드리스 스위트는 노드·값만 잰다. 렌더·레이아웃 버그는 **화면을 봐야** 잡힌다
##   (세63에 그림자 가림·먼지 뭉개짐을 실게임이 잡았고 그때 전 그물이 그린이었다).
##   세90은 이 방식으로 스샷 3장을 찍었는데 스크립트를 남기지 않아 세91이 다시 짰다 — 그래서 도구로 남긴다.
##
## 🔴 `--headless`를 쓰지 마라 — 헤드리스는 렌더를 안 해서 **빈 이미지가 나온다.**
##   창이 잠깐 뜨지만 사용자 창을 앞으로 끌어오지 않는다(세85 「OS 창 캡처 금지」 함정을 피한다).
##
## ✅ `-s`로 뜨므로 세이브 뿌리가 `user://save_test`로 격리된다(세59) — **실플레이 세이브를 안 건드린다.**
##
## 사용:
##   ./Godot_v4.7.1-stable_win64.exe --path . -s res://tools/shot.gd -- <씬경로> <출력png> [대기프레임]
## 예:
##   ... -s res://tools/shot.gd -- res://src/base/base.tscn shot_base.png 30
extends SceneTree

const DEFAULT_WAIT := 30

var _out := ""
var _wait := DEFAULT_WAIT
var _frames := 0
var _shot := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("[shot] 인자: <씬경로> <출력png> [대기프레임]")
		quit(1)
		return
	var scene_path := args[0]
	_out = args[1]
	if args.size() >= 3:
		_wait = maxi(int(args[2]), 1)

	# 🔴 오토로드 식별자는 컴파일 타임에 참조하면 안 된다(세: -s는 오토로드 등록 전에 컴파일된다).
	#   여기서는 씬만 바꾸므로 오토로드를 안 건드린다 — 필요하면 root.get_node("/root/...")로 런타임 조회.
	var err := change_scene_to_file(scene_path)
	if err != OK:
		push_error("[shot] 씬 로드 실패 %s (err %d)" % [scene_path, err])
		quit(1)


func _process(_delta: float) -> bool:
	if _shot:
		return true  # quit
	_frames += 1
	if _frames < _wait:
		return false
	_shot = true
	# 🔴 그린 직후에 읽어야 한다 — 이 시그널 없이 읽으면 **한 프레임 전(또는 빈) 화면**이 나온다.
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)
	return false


func _grab() -> void:
	var img := root.get_texture().get_image()
	var e := img.save_png(_out)
	if e != OK:
		push_error("[shot] 저장 실패 %s (err %d)" % [_out, e])
	else:
		print("[shot] saved %s  %dx%d" % [_out, img.get_width(), img.get_height()])
	quit(0 if e == OK else 1)
