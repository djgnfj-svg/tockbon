extends SceneTree

## # 실험대 01 — 2D 판때기를 3D 에 넣을 때 어색하지 않게 하는 법
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/lab/billboard_lab.gd
## ```
##
## **기법 하나에 스위치 하나.** ↑↓ 로 고르고 스페이스로 켠다. **조합은 켜는 것이지 만드는 게 아니다** —
## 스위치 열여섯이면 화면은 65536 가지이고, 코드는 열여섯 덩어리다.
##
## ⚠⚠ **몸 셋이 같은 자리에 서 있다.** 왼쪽은 스위치를 안 받는 대조군이고, 가운데가 스위치를 받는
## 쪽이고, 오른쪽은 절벽 뒤에 서 있다 — **알파 잘라내기가 없으면 절벽을 뚫고 그려지는** 그 몸이다.
##
## ⚠ **문서는 개발지식 01 번 — 「2D 판때기를 3D 에 넣을 때 어색하지 않게 하는 법」이다.** 기법 스물여덟 개 중
## **화면에서 갈리는 열여섯 개**가 여기 스위치로 서 있다. 나머지 열둘은 설정이거나 그림이 있어야 한다.

const Stage := preload("res://tools/lab/lab_stage.gd")

const ROWS := [
	{"id": "y_axis", "name": "1 · Y 축 고정 빌보드", "on": false,
		"note": "전 축이면 카메라를 내릴수록 몸이 눕는다. R F 로 기울여 보면 갈린다."},
	{"id": "pitch_lock", "name": "2 · 카메라 각도 고정 (45 도)", "on": false,
		"note": "그림을 그린 각도로 못박는다. R F 가 안 먹게 된다 — 그게 이 기법의 값이다."},
	{"id": "facings", "name": "3 · 방향 여러 장", "on": false,
		"note": "몸이 도는 방향에 따라 앞·옆·뒤 그림이 바뀐다. 꺼 두면 앞모습 한 장뿐이다."},
	{"id": "nearest", "name": "6 · 가장 가까운 점으로 확대", "on": false,
		"note": "끄면 픽셀이 뭉개진다. 휠로 크게 당겨 보면 확실히 보인다."},
	{"id": "alpha_cut", "name": "8 · 알파 잘라내기", "on": false,
		"note": "끄면 오른쪽 몸이 절벽을 뚫고 그려진다. 판때기에 깊이값이 없어서다."},
	{"id": "ortho", "name": "10 · 정사영 카메라", "on": false,
		"note": "끄면 원근 카메라가 된다. 화면 가장자리 몸이 바깥으로 기운다."},
	{"id": "feet", "name": "12 · 기준점을 발에", "on": false,
		"note": "끄면 그림 한가운데가 땅에 박혀 몸이 반쯤 묻힌다."},
	{"id": "shadow_disc", "name": "13 · 접지 그림자", "on": false,
		"note": "발밑 동그라미 하나. 이거 하나로 몸이 땅에 붙는다."},
	{"id": "real_shadow", "name": "14 · 판때기의 진짜 그림자 (켜면 안 되는 것)", "on": false,
		"note": "⚠ 일부러 넣은 나쁜 예. 켜고 카메라를 돌려 보면 그림자가 같이 돈다."},
	{"id": "shaded", "name": "16 · 빛을 받게 하기", "on": false,
		"note": "끄면 배경이 어두워도 몸만 대낮이다. 켜면 노멀맵 없이도 배경에 앉는다."},
	{"id": "outline", "name": "17 · 외곽선", "on": false,
		"note": "몸 뒤에 검은 사본 한 장을 조금 크게 깐다. 배경에서 떨어져 나온다."},
	{"id": "stretch", "name": "22 · 세로 늘려 보정", "on": false,
		"note": "카메라를 내릴수록 세로로 늘려 되돌린다. 2 번을 못 할 때의 대안이다."},
	{"id": "lean", "name": "23 · 살짝 뒤로 눕히기", "on": false,
		"note": "12 도쯤 눕힌다. 땅과 덜 싸우고 빛을 조금 더 받는다."},
	{"id": "depth_push", "name": "24 · 깊이 조금 밀어주기", "on": false,
		"note": "판때기 아래끝과 땅이 같은 깊이라 지지직거릴 때 카메라 쪽으로 민다."},
	{"id": "breathe", "name": "25 · 가만히 있어도 미세하게 움직이기", "on": false,
		"note": "위아래로 한 픽셀. 멈춘 그림은 죽어 보인다 — 이 하나가 살린다."},
	{"id": "separate", "name": "26 · 색으로 배경에서 떼기", "on": false,
		"note": "몸을 배경보다 밝고 진하게. 땅색에 묻히는 걸 막는다."},
]

var _stage = null
var _bodies: Array[Sprite3D] = []
var _discs: Array[MeshInstance3D] = []
var _outlines: Array[Sprite3D] = []
var _cliff: MeshInstance3D = null
var _tex_front: Texture2D = null
var _tex_side: Texture2D = null
var _tex_back: Texture2D = null
var _time := 0.0
var _spin := 0.0


func _initialize() -> void:
	_stage = Stage.new()
	var rows: Array = []
	for r in ROWS:
		rows.append(r.duplicate())
	if not _stage.build(self, "실험대 01 — 판때기를 3D 에 세우기", rows):
		quit(1)
		return
	_stage.view_tiles = 7.0
	_stage.pitch = 45.0
	_build()
	root.window_input.connect(_on_input)
	_apply()
	_stage.place_camera()
	_run()


func _build() -> void:
	_stage.add_ground(40.0, Color(0.352, 0.451, 0.286))

	# 절벽 하나. 알파 잘라내기를 끄면 오른쪽 몸이 이걸 뚫고 그려진다.
	_cliff = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 2.0, 0.5)
	_cliff.mesh = box
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.560, 0.545, 0.575)
	rock.roughness = 1.0
	_cliff.material_override = rock
	_cliff.position = Vector3(2.1, 1.0, 0.6)
	_stage.world.add_child(_cliff)

	_tex_front = Stage.tex("body_front.png")
	_tex_side = Stage.tex("body_side.png")
	_tex_back = Stage.tex("body_back.png")

	for i in 3:
		var x := -2.1 + float(i) * 2.1
		var shell := Sprite3D.new()
		shell.texture = _tex_front
		shell.modulate = Color(0.09, 0.08, 0.10, 1.0)
		shell.visible = false
		_stage.world.add_child(shell)
		_outlines.append(shell)

		var s := Sprite3D.new()
		s.texture = _tex_front
		s.position = Vector3(x, 0.0, 0.0)
		_stage.world.add_child(s)
		_bodies.append(s)

		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.30
		cyl.bottom_radius = 0.30
		cyl.height = 0.02
		disc.mesh = cyl
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disc.material_override = dm
		disc.position = Vector3(x, 0.02, 0.0)
		disc.visible = false
		_stage.world.add_child(disc)
		_discs.append(disc)


## 스위치가 바뀔 때마다 통째로 다시 먹인다. **바뀐 것만 골라 먹이면 어느 스위치가 무엇을
## 되돌리는지 표가 하나 더 생긴다** — 그 표가 어긋나는 것이 이런 실험대가 거짓말하는 방식이다.
func _apply() -> void:
	var st = _stage
	# 10 번 — 정사영이면 멀리서 평행하게, 원근이면 가까이서 넓은 화각으로. ⚠ 거리를 같이 안 바꾸면
	# 원근 카메라가 사실상 정사영처럼 보여서 이 스위치가 아무것도 안 보여 준다.
	if st.on("ortho"):
		st.cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		st.back = 60.0
	else:
		st.cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		st.cam.fov = 55.0
		st.back = 7.0
	if st.on("pitch_lock"):
		st.pitch = 45.0
	for i in _bodies.size():
		var s := _bodies[i]
		s.pixel_size = Look.SPRITE_PIXEL_SIZE
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if st.on("y_axis") else BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if st.on("nearest") else BaseMaterial3D.TEXTURE_FILTER_LINEAR
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if st.on("alpha_cut") else SpriteBase3D.ALPHA_CUT_DISABLED
		s.shaded = st.on("shaded")
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if st.on("real_shadow") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.modulate = Color(1.18, 1.14, 1.22) if st.on("separate") else Color(1, 1, 1)
		if st.on("feet"):
			s.centered = false
			s.offset = Vector2(-float(s.texture.get_width()) * 0.5, -float(s.texture.get_height()))
		else:
			s.centered = true
			s.offset = Vector2.ZERO
		_discs[i].visible = st.on("shadow_disc")
		var shell := _outlines[i]
		shell.visible = st.on("outline")
		shell.pixel_size = s.pixel_size * 1.10
		shell.billboard = s.billboard
		shell.texture_filter = s.texture_filter
		shell.alpha_cut = s.alpha_cut
		shell.shaded = false
		shell.centered = s.centered
		shell.offset = s.offset
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.place_camera()
	_stage.write()


func _on_input(event: InputEvent) -> void:
	var before_pitch: float = _stage.pitch
	if _stage.handle(event):
		if _stage.on("pitch_lock") and not is_equal_approx(_stage.pitch, before_pitch):
			_stage.pitch = 45.0
			_stage.place_camera()
		_apply()


func _run() -> void:
	var last := Time.get_ticks_usec()
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt: float = minf(float(now - last) / 1000000.0, 0.1)
		last = now
		_step(dt)


func _step(dt: float) -> void:
	_time += dt
	_spin = fmod(_spin + dt * 45.0, 360.0)
	var st = _stage
	var breathe := 0.0
	if st.on("breathe"):
		breathe = (sin(_time * 3.2) * 0.5 + 0.5) * Look.SPRITE_PIXEL_SIZE
	# 22 번 — 기울기가 클수록 세로로 늘려 되돌린다.
	var stretch := 1.0
	if st.on("stretch"):
		stretch = 1.0 / maxf(cos(deg_to_rad(st.pitch)), 0.35)
	var lean := deg_to_rad(-12.0) if st.on("lean") else 0.0
	var push := 0.02 if st.on("depth_push") else 0.0
	for i in _bodies.size():
		var s := _bodies[i]
		var x := -2.1 + float(i) * 2.1
		s.position = Vector3(x, breathe, push)
		s.scale = Vector3(1.0, stretch, 1.0)
		s.rotation = Vector3(lean, 0.0, 0.0)
		# 3 번 — 가운데 몸만 돈다. 방향 그림이 켜져 있으면 그림이 바뀐다.
		if i == 1 and st.on("facings"):
			var f: int = clampi(int(fmod(_spin, 360.0) / 90.0), 0, 3)
			s.texture = [_tex_front, _tex_side, _tex_back, _tex_side][f]
		else:
			s.texture = _tex_front
		# ⚠ 외곽선 사본은 카메라가 보는 쪽으로 조금 더 멀리 세운다. 월드 축으로 밀면 카메라를
		# 돌렸을 때 사본이 몸 옆으로 빠져나온다 — 빌보드는 화면을 보지 월드를 안 본다.
		var away: Vector3 = -_stage.cam.global_transform.basis.z * 0.03
		_outlines[i].position = s.position + away
		_outlines[i].texture = s.texture
		_outlines[i].scale = s.scale
		_outlines[i].rotation = s.rotation
