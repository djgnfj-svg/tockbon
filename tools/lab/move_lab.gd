extends SceneTree

## # 실험대 03 — 몸과 부대가 기분 좋게 움직이게 하는 법
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://tools/lab/move_lab.gd
## ```
##
## **아홉이 한 부대다. 왼쪽 클릭으로 갈 자리를 찍는다.** 스위치를 켜면 그 이동에 기법이 하나씩 얹힌다.
## **T 를 누르면 미리 정해진 자리 넷을 돌아가며 자동으로 명령한다** — 손을 안 쓰고 보려는 것.
##
## ⚠⚠ **몸이 빌보드를 안 쓰고 카메라 방향을 직접 받는다.** 고도의 빌보드는 모델 행렬을 다시 세우면서
## **노드의 회전과 크기를 버릴 수 있고**, 그러면 9 번(기울기) 스위치가 아무것도 안 보여 준다.
## **빌보드 자체를 보는 것은 실험대 01 이다.**
##
## ⚠⚠ **아무것도 안 켜면 아홉이 한 조각에 겹쳐 서고, 일정한 속도로 미끄러진다.** 그게 지금 게임의
## 모습이고 대조군이다.
##
## ⚠ 문서는 개발지식 03 번 — 「몸과 부대가 기분 좋게 움직이게 하는 법」이다. 기법 스물여섯 개 중
## **화면에서 갈리는 열셋**이 스위치로 서 있다.

const Stage := preload("res://tools/lab/lab_stage.gd")

const N := 9
const SPEED := 2.4
const SLOW := 1.4          # 21 번을 켜면 부대 전체가 이 속도로 맞춰진다
const TOURS := [Vector3(3.0, 0, 2.4), Vector3(-3.2, 0, 2.0), Vector3(-2.6, 0, -2.6), Vector3(3.2, 0, -2.2)]

const ROWS := [
	{"id": "instant", "name": "1 · 즉시 반응", "on": false,
		"note": "누른 그 프레임에 몸이 목적지 쪽으로 살짝 튼다. 없으면 다 해도 굼떠 보인다."},
	{"id": "click_mark", "name": "2 · 누른 자리 표시", "on": false,
		"note": "찍은 조각에 자국이 잠깐 뜬다."},
	{"id": "line", "name": "3 · 이동선", "on": false,
		"note": "갈 길을 점선으로 깐다. 점 하나 그림을 반복해서 놓는 방식이다."},
	{"id": "ease", "name": "5 · 가속과 감속", "on": false,
		"note": "출발할 때 붙고 도착할 때 잦아든다. ⚠ 일정 속도는 기계처럼 보인다."},
	{"id": "turn", "name": "6 · 방향 돌 때 부드럽게", "on": false,
		"note": "제자리에서 홱 도는 대신 도는 속도에 한계를 둔다."},
	{"id": "lean", "name": "9 · 걸을 때 기울기", "on": false,
		"note": "가는 쪽으로 몸이 살짝 기운다."},
	{"id": "slots", "name": "11 · 도착 자리 나눠 갖기", "on": false,
		"note": "⚠⚠ 이게 없으면 아홉이 한 조각에 겹쳐 선다. 제일 먼저 티 나는 것."},
	{"id": "formation", "name": "12 · 대형 유지", "on": false,
		"note": "가는 동안에도 3x3 을 유지한다. 11 번이 도착만 다루는 것과 다르다."},
	{"id": "separate", "name": "13 · 서로 안 겹치기", "on": false,
		"note": "몸끼리 밀어낸다. 겹쳐 선 아홉이 스스로 풀린다."},
	{"id": "tolerance", "name": "19 · 도착 여유", "on": false,
		"note": "⚠⚠ 없으면 몸이 목적지에서 영원히 떤다. 한 발 넘고 한 발 되돌아온다."},
	{"id": "hold", "name": "20 · 서 있는 몸은 안 밀린다", "on": false,
		"note": "S 로 한 명을 세워 두고 부대를 그 위로 보내 보라. 켜면 안 밀린다."},
	{"id": "slowest", "name": "21 · 가장 느린 몸에 맞추기", "on": false,
		"note": "한 명이 느리게 걷는다. 켜면 전부 그 속도가 되어 부대가 안 늘어진다."},
	{"id": "ring", "name": "18 · 선택 표시", "on": false,
		"note": "고른 부대의 발밑에 고리가 보인다."},
]

var _stage = null
var _pos: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _face: Array[float] = []
var _goal: Array[Vector3] = []
var _held: Array[bool] = []
var _sprites: Array[Sprite3D] = []
var _rings: Array[Sprite3D] = []
var _dots: Array[Sprite3D] = []
var _mark: Sprite3D = null
var _mark_life := 0.0
var _target := Vector3.ZERO
var _tour := 0
var _auto := false
var _auto_clock := 0.0
var _time := 0.0


func _initialize() -> void:
	_stage = Stage.new()
	var rows: Array = []
	for r in ROWS:
		rows.append(r.duplicate())
	if not _stage.build(self, "실험대 03 — 몸과 부대가 움직이기", rows):
		quit(1)
		return
	_stage.view_tiles = 14.0
	_stage.pitch = 52.0
	_build()
	root.window_input.connect(_on_input)
	_stage.place_camera()
	_write()
	_run()


func _sprite(tex: Texture2D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = Look.SPRITE_PIXEL_SIZE
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.centered = false
	s.offset = Vector2(-float(tex.get_width()) * 0.5, -float(tex.get_height()))
	_stage.world.add_child(s)
	return s


## 땅에 붙어 눕는 표시. **빌보드를 안 쓴다** — 발밑 고리는 땅에 그려진 것이지 세워 둔 그림이 아니다.
func _flat(tex: Texture2D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = Look.SPRITE_PIXEL_SIZE
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	s.visible = false
	_stage.world.add_child(s)
	return s


func _build() -> void:
	_stage.add_ground(60.0, Color(0.352, 0.451, 0.286))
	# 조각 눈금 — 몇 조각을 갔는지 눈으로 세라고.
	for i in range(-6, 7):
		for axis in 2:
			var line := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(12.0, 0.02) if axis == 0 else Vector2(0.02, 12.0)
			line.mesh = q
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1, 1, 1, 0.10)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			line.material_override = m
			line.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			line.position = Vector3(0.0, 0.012, float(i)) if axis == 0 else Vector3(float(i), 0.012, 0.0)
			_stage.world.add_child(line)

	var tex_body := Stage.tex("body_front.png")
	var tex_ring := Stage.tex("ring.png")
	var tex_dot := Stage.tex("dot.png")
	for i in N:
		var col := i % 3
		var row := i / 3
		var at := Vector3(-4.0 + float(col) * 0.6, 0.0, -1.0 + float(row) * 0.6)
		_pos.append(at)
		_vel.append(Vector3.ZERO)
		_face.append(0.0)
		_goal.append(at)
		_held.append(false)
		_sprites.append(_sprite(tex_body))
		_rings.append(_flat(tex_ring))
	for i in 40:
		_dots.append(_flat(tex_dot))
	_mark = _flat(Stage.tex("click.png"))
	_target = _pos[4]


func _write() -> void:
	_stage.write()
	_stage.foot.text = _stage.foot.text + "\n왼쪽클릭 그리로 가라   T 자동으로 네 자리 돌기 (%s)   S 한 명 세워 두기 (%s)   H 처음 자리로" % ["켜짐" if _auto else "꺼짐", "켜짐" if _held[0] else "꺼짐"]


func _on_input(event: InputEvent) -> void:
	if _stage.handle(event):
		_write()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_T:
			_auto = not _auto
			_auto_clock = 0.0
			_write()
		elif key == KEY_S:
			_held[0] = not _held[0]
			_write()
		elif key == KEY_H:
			for i in N:
				_pos[i] = Vector3(-4.0 + float(i % 3) * 0.6, 0.0, -1.0 + float(i / 3) * 0.6)
				_vel[i] = Vector3.ZERO
				_goal[i] = _pos[i]
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			var hit := _ground_under(click.position)
			if hit != null:
				_order(hit)
		return


## 화면의 한 점이 땅의 어디인가. **카메라에서 광선을 쏘아 y = 0 평면과 만나는 자리.**
func _ground_under(screen: Vector2):
	var from: Vector3 = _stage.cam.project_ray_origin(screen)
	var dir: Vector3 = _stage.cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var t: float = -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t


func _order(at: Vector3) -> void:
	_target = Vector3(at.x, 0.0, at.z)
	if _stage.on("click_mark"):
		_mark_life = 0.5
		_mark.position = _target + Vector3(0.0, 0.02, 0.0)
	for i in N:
		if _held[i] and _stage.on("hold"):
			continue
		_goal[i] = _slot_for(i)
		# 1 번 — 누른 그 프레임에 몸이 목적지 쪽으로 튼다. 아직 한 걸음도 안 걸었는데도.
		if _stage.on("instant"):
			var to: Vector3 = _goal[i] - _pos[i]
			if to.length() > 0.001:
				_face[i] = atan2(to.x, to.z)


## 11 번 — 목적지 둘레의 자리를 하나씩 나눠 갖는다. 꺼져 있으면 아홉이 같은 점을 받는다.
func _slot_for(i: int) -> Vector3:
	if not _stage.on("slots"):
		return _target
	var col := i % 3
	var row := i / 3
	return _target + Vector3(float(col - 1) * 0.62, 0.0, float(row - 1) * 0.62)


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
	var st = _stage

	if _auto:
		_auto_clock += dt
		if _auto_clock > 2.6:
			_auto_clock = 0.0
			_tour = (_tour + 1) % TOURS.size()
			_order(TOURS[_tour])

	# 21 번 — 한 명이 느리다. 켜면 전부 그 속도가 된다.
	var slowest := SPEED
	if st.on("slowest"):
		slowest = SLOW

	for i in N:
		var speed := SPEED
		if i == 3:
			speed = SLOW
		if st.on("slowest"):
			speed = slowest

		if _held[i] and st.on("hold"):
			_vel[i] = Vector3.ZERO
		else:
			var goal: Vector3 = _goal[i]
			# 12 번 — 가는 동안에도 대형을 지킨다. 자기 자리를 따라간다.
			if st.on("formation"):
				goal = _slot_for(i)
			var to: Vector3 = goal - _pos[i]
			var d: float = to.length()
			# 19 번 — 도착 여유. 없으면 목적지 위에서 한 발 넘고 한 발 되돌아온다.
			var stop_at := 0.14 if st.on("tolerance") else 0.0
			if d <= stop_at:
				_vel[i] = Vector3.ZERO
			else:
				var want := to.normalized() * speed
				# 5 번 — 붙었다 잦아든다. 끄면 처음부터 끝까지 같은 속도다.
				if st.on("ease"):
					want *= clampf(d / 1.2, 0.18, 1.0)
					_vel[i] = _vel[i].move_toward(want, 9.0 * dt)
				else:
					_vel[i] = want
				_pos[i] += _vel[i] * dt

		# 13 번 — 서로 밀어낸다. ⚠ 순서를 못박아야 같은 판이 두 번 같이 굴러간다.
		if st.on("separate"):
			for j in N:
				if j == i:
					continue
				if _held[j] and st.on("hold"):
					continue
				var away: Vector3 = _pos[i] - _pos[j]
				var gap: float = away.length()
				if gap > 0.0001 and gap < 0.55:
					_pos[i] += away.normalized() * (0.55 - gap) * 0.5

		# 6 번 — 도는 속도에 한계를 둔다. 끄면 방향이 홱 바뀐다.
		var moving: bool = _vel[i].length() > 0.05
		if moving:
			var want_face: float = atan2(_vel[i].x, _vel[i].z)
			if st.on("turn"):
				_face[i] = _turn_toward(_face[i], want_face, 6.0 * dt)
			else:
				_face[i] = want_face

		var s := _sprites[i]
		s.position = _pos[i]
		# 9 번 — 가는 쪽으로 기운다.
		var tilt := 0.0
		if st.on("lean") and moving:
			tilt = deg_to_rad(7.0)
		# ⚠ 카메라 쪽을 직접 보게 하고, 그 위에 기울기를 얹는다. 빌보드였다면 이 줄이 통째로 무시된다.
		s.rotation = Vector3(0.0, deg_to_rad(_stage.yaw), sin(_face[i]) * tilt)
		_rings[i].visible = st.on("ring")
		_rings[i].position = _pos[i] + Vector3(0.0, 0.015, 0.0)

	_draw_line()

	if _mark_life > 0.0:
		_mark_life -= dt
		_mark.visible = st.on("click_mark")
		_mark.modulate = Color(1, 1, 1, clampf(_mark_life / 0.5, 0.0, 1.0))
	else:
		_mark.visible = false


## 3 번 — 점 하나 그림을 일정 간격으로 깔아 선을 만든다. 곡선이 아니라 점선인 이유는
## **점 하나면 그림이 한 장으로 끝나고, 길이가 변해도 늘어나거나 흐려지지 않기 때문이다.**
func _draw_line() -> void:
	var show: bool = _stage.on("line")
	if not show:
		for d in _dots:
			d.visible = false
		return
	var from: Vector3 = _pos[4]
	var to: Vector3 = _target
	var span: float = from.distance_to(to)
	var step := 0.28
	var n: int = mini(_dots.size(), int(span / step))
	for i in _dots.size():
		if i >= n:
			_dots[i].visible = false
			continue
		var t: float = float(i + 1) * step / maxf(span, 0.001)
		_dots[i].visible = true
		_dots[i].position = from.lerp(to, t) + Vector3(0.0, 0.02, 0.0)


## 각도를 짧은 쪽으로 돌린다. **−PI 와 +PI 사이를 그냥 빼면 한 바퀴를 돌아간다.**
func _turn_toward(now: float, want: float, step: float) -> float:
	var d: float = wrapf(want - now, -PI, PI)
	if absf(d) <= step:
		return want
	return now + signf(d) * step
