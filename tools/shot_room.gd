## 보스방 스크린샷 도구 (세99) — `tools/shot.gd`의 챕터 판.
## `tools/shot.gd`를 본떴고 두 걸음이 더 있다:
##  ① `boss_room`은 `GameState.pending_chapter`가 비면 베이스로 되돌린다(설계대로) — 세팅이 필요하다.
##  ② 기본 카메라가 플레이어에 묶여 **남쪽 입구만** 보인다 — 방 전체를 보려면 zoom을 뽑아야 한다.
##
## 🔴 `--headless`를 쓰지 마라 — 렌더를 안 해서 빈 이미지가 나온다.
## ✅ `-s`로 뜨므로 세이브 뿌리가 `user://save_test`로 격리된다 — 실플레이 세이브를 안 건드린다.
##
## 사용: ./Godot... --path . -s res://tools/shot_room.gd -- <챕터id> <출력png> [대기프레임] [wide|force_named|both]
extends SceneTree

const ROOM := "res://src/field/boss_room.tscn"
const CAM_SETUP_FRAME := 8   ## 씬이 서고 카메라가 붙을 시간

var _out := ""
var _chapter := ""
var _wait := 40
var _wide := false
var _force_named := false
var _frames := 0
var _shot := false
var _entered := false
var _cam_done := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("[shot_room] 인자: <챕터id> <출력png> [대기프레임] [wide|force_named|both]")
		quit(1)
		return
	_chapter = args[0]
	_out = args[1]
	if args.size() >= 3:
		_wait = maxi(int(args[2]), 1)
	if args.size() >= 4:
		_wide = args[3] == "wide" or args[3] == "both"
		_force_named = args[3] == "force_named" or args[3] == "both"


func _process(_delta: float) -> bool:
	if not _entered:
		_entered = true
		# 🔴 오토로드는 `_init`엔 아직 없다 — 여기서 런타임 조회한다(`-s` 컴파일 함정 회피).
		var gs = root.get_node("/root/GameState")
		var db = root.get_node("/root/Db")
		gs.pending_chapter = StringName(_chapter)
		# 네임드를 반드시 띄운다 — 확률이라 그냥은 안 뜬다(설계상 「하나도 안 뜸」이 정상 결과).
		if _force_named:
			var ch = db.get_chapter(StringName(_chapter))
			if ch != null:
				for n in ch.named_pool:
					n.chance = 1.0
		var err := change_scene_to_file(ROOM)
		if err != OK:
			push_error("[shot_room] 씬 로드 실패 (err %d)" % err)
			quit(1)
		return false

	if _shot:
		return true
	_frames += 1

	if _wide and not _cam_done and _frames >= CAM_SETUP_FRAME:
		_cam_done = true
		var cam := _find_cam(root)
		if cam != null:
			cam.position_smoothing_enabled = false
			cam.zoom = Vector2(0.22, 0.22)
			# ⚠ `boss_room._clamp_camera_to_room`이 limit을 걸어 둔다 — 뽑아 보려면 풀어야 한다.
			cam.limit_left = -100000
			cam.limit_right = 100000
			cam.limit_top = -100000
			cam.limit_bottom = 100000
			cam.global_position = Vector2(0, -400)   # 방 중앙께
		else:
			push_error("[shot_room] Camera2D를 못 찾았다")

	if _frames < _wait:
		return false
	_shot = true
	# 🔴 그린 직후에 읽어야 한다 — 이 시그널 없이 읽으면 한 프레임 전(또는 빈) 화면이 나온다.
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)
	return false


func _find_cam(n: Node) -> Camera2D:
	if n is Camera2D:
		return n as Camera2D
	for c in n.get_children():
		var got := _find_cam(c)
		if got != null:
			return got
	return null


func _grab() -> void:
	var img := root.get_texture().get_image()
	var e := img.save_png(_out)
	if e != OK:
		push_error("[shot_room] 저장 실패 (err %d)" % e)
	else:
		print("[shot_room] saved %s  %dx%d" % [_out, img.get_width(), img.get_height()])
	quit(0 if e == OK else 1)
