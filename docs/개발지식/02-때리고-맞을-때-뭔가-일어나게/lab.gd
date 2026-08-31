extends SceneTree

## # 실험대 02 — 때리고 맞을 때 뭔가 일어난 것처럼 보이게 하는 법
##
## ```
## .\Godot_v4.7.1-stable_win64.exe --path . --script res://docs/개발지식/02-때리고-맞을-때-뭔가-일어나게/lab.gd
## ```
##
## **검사 하나와 짐승 하나가 계속 서로 때린다.** 스위치를 켜면 그 타격에 기법이 하나씩 얹힌다.
## **왼쪽 한 쌍은 스위치를 안 받는 대조군**이라 언제든 「원래는 이랬다」를 옆에서 볼 수 있다.
##
## ⚠⚠ **스페이스로 한 대씩 때리는 게 아니라 계속 때린다.** 타격감은 한 번 봐서는 안 갈리고
## **연달아 볼 때 갈린다** — 그래서 0.9 초마다 자동으로 친다. **B 를 누르면 여덟 마리가 한꺼번에**
## 때린다: 19·20 번(효과 누적 막기)이 무엇을 막는지는 그때만 보인다.
##
## ⚠ 문서는 개발지식 02 번 — 「때리고 맞을 때 뭔가 일어난 것처럼 보이게 하는 법」이다. 기법 스물여섯 개 중
## **화면에서 갈리는 열넷**이 스위치로 서 있다.

const Stage := preload("res://docs/개발지식/02-때리고-맞을-때-뭔가-일어나게/stage.gd")

const PERIOD := 0.9
const ROWS := [
	{"id": "windup", "name": "1 · 예비 동작", "on": false,
		"note": "때리기 전 0.18 초 동안 뒤로 뺀다. 없으면 맞는 쪽이 반응할 틈이 없다."},
	{"id": "hitstop", "name": "3 · 히트스톱", "on": false,
		"note": "때린 둘만 0.07 초 멈춘다. ⚠ 이 목록에서 가장 싸고 가장 크게 바뀐다."},
	{"id": "flash", "name": "4 · 흰색 번쩍임", "on": false,
		"note": "맞은 몸이 0.1 초 하얘진다."},
	{"id": "shake", "name": "5 · 화면 흔들기", "on": false,
		"note": "때린 방향으로 카메라를 찬다. ⚠ 아무렇게나 떨면 싸구려가 된다 — 방향이 있어야 한다."},
	{"id": "slash", "name": "6 · 타격 그림", "on": false,
		"note": "맞은 자리에 호 한 장. 자리표시 그림이다."},
	{"id": "spark", "name": "7 · 튀는 조각", "on": false,
		"note": "때린 방향으로 여섯 조각이 흩어진다."},
	{"id": "knock", "name": "9 · 밀려남", "on": false,
		"note": "맞은 몸이 뒤로 밀렸다 돌아온다. ⚠ 3 번이 끝난 뒤에 시작한다 — 겹치면 순간이동이다."},
	{"id": "stun", "name": "10 · 멈칫", "on": false,
		"note": "맞은 몸이 0.25 초 못 움직인다. 9 번과 다르다 — 이건 안 움직이는 것."},
	{"id": "squash", "name": "11 · 눌리고 늘어나기", "on": false,
		"note": "맞을 때 납작해진다. ⚠ 부피가 그대로여야 한다 — 넓어지면 낮아진다."},
	{"id": "number", "name": "13 · 숫자 뜨기", "on": false,
		"note": "깎인 피가 위로 떠오르며 사라진다."},
	{"id": "bar_lag", "name": "14 · 체력 바 지연 감소", "on": false,
		"note": "빨간 칸이 먼저 줄고 흰 칸이 뒤따라 줄어 얼마나 맞았는지가 보인다."},
	{"id": "punch_in", "name": "15 · 카메라 확 당기기", "on": false,
		"note": "결정타에만 화면이 살짝 줌인했다 돌아온다. 22 번과 같이 켜야 뜻이 산다."},
	{"id": "slowmo", "name": "16 · 느려짐", "on": false,
		"note": "세상 전체가 잠깐 느려진다. ⚠ 3 번은 멈추는 것, 이건 늦추는 것."},
	{"id": "cap", "name": "19 · 효과 누적 막기", "on": false,
		"note": "⚠⚠ B 로 여덟을 한꺼번에 때려 보라. 이게 없으면 화면이 발작한다."},
	{"id": "last_only", "name": "22 · 마지막 한 방만 크게", "on": false,
		"note": "15·16 번을 죽이는 타격에만 쓴다. 매 대에 쓰면 게임이 안 돌아간다."},
]

var _stage = null
var _time := 0.0
var _clock := 0.0
## 대조군 · 스위치를 받는 쌍 · B 로 부르는 여덟
var _pairs: Array = []
var _horde: Array = []
var _horde_on := false
var _stop_left := 0.0
var _slow_left := 0.0
var _punch := 0.0
var _shake_left := 0.0
var _shake_dir := Vector3.ZERO
var _sparks: Array[Sprite3D] = []
var _spark_life: Array[float] = []
var _spark_vel: Array[Vector3] = []
var _numbers: Array[Label3D] = []
var _number_life: Array[float] = []
var _hp := 100.0
var _hp_ghost := 100.0
var _bar_red: MeshInstance3D = null
var _bar_ghost: MeshInstance3D = null
var _tex_body: Texture2D = null
var _tex_beast: Texture2D = null
var _tex_spark: Texture2D = null
var _tex_slash: Texture2D = null
var _slash_node: Sprite3D = null
var _slash_life := 0.0


func _initialize() -> void:
	_stage = Stage.new()
	var rows: Array = []
	for r in ROWS:
		rows.append(r.duplicate())
	if not _stage.build(self, "실험대 02 — 때리고 맞을 때", rows):
		quit(1)
		return
	_stage.view_tiles = 9.0
	_stage.pitch = 42.0
	_build()
	root.window_input.connect(_on_input)
	_stage.place_camera()
	_stage.write()
	_run()


func _sprite(tex: Texture2D, at: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = Look.SPRITE_PIXEL_SIZE
	# ⚠⚠ 빌보드를 안 쓴다. 고도의 빌보드는 모델 행렬을 다시 세우면서 노드의 크기를 버릴 수 있고,
	# 그러면 11 번(눌리고 늘어나기)이 아무것도 안 보여 준다. 대신 카메라 방향을 매 프레임 먹인다.
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.centered = false
	s.offset = Vector2(-float(tex.get_width()) * 0.5, -float(tex.get_height()))
	s.position = at
	_stage.world.add_child(s)
	return s


func _bar(col: Color, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 0.14)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	# ⚠ 이게 없으면 빌보드가 모델 행렬을 다시 세우면서 노드의 크기를 버린다 — 체력 바가 안 줄어든다.
	m.billboard_keep_scale = true
	mi.material_override = m
	mi.position = Vector3(1.0, y, 0.0)
	_stage.world.add_child(mi)
	return mi


func _build() -> void:
	_stage.add_ground(40.0, Color(0.352, 0.451, 0.286))
	_tex_body = Stage.tex("body_front.png")
	_tex_beast = Stage.tex("beast.png")
	_tex_spark = Stage.tex("spark.png")
	_tex_slash = Stage.tex("slash.png")

	# 대조군 한 쌍 (x = -3.2) 과 스위치를 받는 한 쌍 (x = 1.0)
	for i in 2:
		var x := -3.2 + float(i) * 4.2
		_pairs.append({
			"man": _sprite(_tex_body, Vector3(x - 0.55, 0.0, 0.0)),
			"beast": _sprite(_tex_beast, Vector3(x + 0.55, 0.0, 0.0)),
			# ⚠⚠ 선 자리를 값으로 들고 있는다. 노드의 지금 위치에서 다시 읽으면 밀림과 예비 동작이
			# 프레임마다 쌓여서 몸이 화면 밖으로 걸어 나간다.
			"x": x - 0.55,
			"live": i == 1,
			"knock": 0.0,
			"flash": 0.0,
			"squash": 0.0,
			"stun": 0.0,
		})

	for i in 8:
		var a := float(i) * TAU / 8.0
		_horde.append(_sprite(_tex_beast, Vector3(1.0 + cos(a) * 2.2, 0.0, sin(a) * 2.2)))
		(_horde[i] as Sprite3D).visible = false

	_bar_ghost = _bar(Color(0.92, 0.92, 0.88), 2.3)
	_bar_red = _bar(Color(0.78, 0.24, 0.20), 2.31)

	_slash_node = _sprite(_tex_slash, Vector3(1.0, 1.0, 0.0))
	_slash_node.visible = false

	for i in 24:
		var sp := _sprite(_tex_spark, Vector3.ZERO)
		sp.visible = false
		_sparks.append(sp)
		_spark_life.append(0.0)
		_spark_vel.append(Vector3.ZERO)

	for i in 8:
		var n := Label3D.new()
		n.text = "0"
		n.font_size = 64
		n.pixel_size = 0.006
		n.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		n.modulate = Color(1, 1, 1)
		n.visible = false
		_stage.world.add_child(n)
		_numbers.append(n)
		_number_life.append(0.0)


func _on_input(event: InputEvent) -> void:
	if _stage.handle(event):
		_stage.write()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_B:
			_horde_on = not _horde_on
			for h in _horde:
				(h as Sprite3D).visible = _horde_on
			_stage.write()
		elif key == KEY_H:
			_hp = 100.0
			_hp_ghost = 100.0


func _run() -> void:
	var last := Time.get_ticks_usec()
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt: float = minf(float(now - last) / 1000000.0, 0.1)
		last = now
		_step(dt)


func _step(raw_dt: float) -> void:
	_time += raw_dt

	# 16 번 — 세상 전체를 늦춘다. ⚠ 3 번 히트스톱과는 다른 시계다.
	var dt := raw_dt
	if _slow_left > 0.0:
		_slow_left -= raw_dt
		dt = raw_dt * 0.35

	# 3 번 — 때린 둘만 멈춘다. 나머지 세상은 계속 돈다. 그래서 이 시계는 따로다.
	var pair_dt := dt
	if _stop_left > 0.0:
		_stop_left -= raw_dt
		pair_dt = 0.0

	_clock += dt
	if _clock >= PERIOD:
		_clock -= PERIOD
		_hit()

	_advance_pairs(pair_dt, dt)
	_advance_effects(dt)
	_face_camera()
	_advance_camera(raw_dt)


## 한 번의 타격. **스위치가 켜진 것만 일어난다.**
func _hit() -> void:
	var st = _stage
	var live: Dictionary = _pairs[1]
	var killing := _hp <= 25.0            # 22 번이 「마지막 한 방」이라고 부르는 것
	var big: bool = (not st.on("last_only")) or killing

	_hp = maxf(0.0, _hp - 9.0)
	if _hp <= 0.0:
		_hp = 100.0
		_hp_ghost = 100.0

	if st.on("hitstop"):
		_stop_left = 0.07
	if st.on("flash"):
		live["flash"] = 0.1
	if st.on("squash"):
		live["squash"] = 0.18
	if st.on("stun"):
		live["stun"] = 0.25
	if st.on("knock"):
		live["knock"] = 0.30
	if st.on("slash"):
		_slash_life = 0.14
	if st.on("spark"):
		_spawn_sparks(6)
	if st.on("number"):
		_spawn_number(9)
	if st.on("shake"):
		_add_shake(Vector3(1.0, 0.0, 0.0), 0.16)
	if st.on("punch_in") and big:
		_punch = 0.35
	if st.on("slowmo") and big:
		_slow_left = 0.25

	# 19 번 — 여덟이 한꺼번에 때릴 때. 켜져 있으면 가장 센 것 하나만 남는다.
	if _horde_on:
		var extra := 8
		if st.on("cap"):
			extra = 0                      # 흔들기는 이미 위에서 한 번 더해졌다
		for i in extra:
			_add_shake(Vector3(cos(float(i)), 0.0, sin(float(i))), 0.16)
		if st.on("spark"):
			_spawn_sparks(2 if st.on("cap") else 12)
		if st.on("number"):
			_spawn_number(9)


func _add_shake(dir: Vector3, life: float) -> void:
	# ⚠ 19 번이 켜져 있으면 이미 흔들리는 중일 때 더 세게 못 만든다 — 가장 센 것 하나만 남긴다.
	if _stage.on("cap") and _shake_left > 0.0:
		return
	_shake_dir = dir.normalized()
	_shake_left = maxf(_shake_left, life)


func _spawn_sparks(n: int) -> void:
	var made := 0
	for i in _sparks.size():
		if made >= n:
			break
		if _spark_life[i] > 0.0:
			continue
		var a := randf() * TAU
		_sparks[i].position = Vector3(1.0, 0.9, 0.0)
		_sparks[i].visible = true
		_spark_vel[i] = Vector3(cos(a) * 2.4 + 1.6, absf(sin(a)) * 3.0, sin(a) * 1.2)
		_spark_life[i] = 0.4
		made += 1


func _spawn_number(dmg: int) -> void:
	for i in _numbers.size():
		if _number_life[i] > 0.0:
			continue
		_numbers[i].text = str(dmg)
		_numbers[i].position = Vector3(1.0 + randf_range(-0.3, 0.3), 1.3, 0.0)
		_numbers[i].visible = true
		_number_life[i] = 0.8
		return


func _advance_pairs(pair_dt: float, dt: float) -> void:
	for p in _pairs:
		var pair: Dictionary = p
		var man: Sprite3D = pair["man"]
		var beast: Sprite3D = pair["beast"]
		var base_x: float = float(pair["x"])
		var step: float = pair_dt if bool(pair["live"]) else dt

		pair["flash"] = maxf(0.0, float(pair["flash"]) - step)
		pair["squash"] = maxf(0.0, float(pair["squash"]) - step)
		pair["stun"] = maxf(0.0, float(pair["stun"]) - step)
		pair["knock"] = maxf(0.0, float(pair["knock"]) - step)

		# 1 번 — 때리기 직전에 뒤로 뺀다. 주기의 마지막 0.18 초.
		var lead := 0.0
		if bool(pair["live"]) and _stage.on("windup"):
			var to_hit := PERIOD - _clock
			if to_hit < 0.18:
				lead = -(0.18 - to_hit) * 1.6
		man.position = Vector3(base_x + lead, 0.0, 0.0)

		# 9 번 — 밀렸다 돌아온다. 빠르게 갔다 천천히 멎는다.
		var k: float = float(pair["knock"])
		var push := 0.0
		if k > 0.0:
			push = sin(k / 0.30 * PI) * 0.55
		beast.position.x = base_x + 1.1 + push

		# 4 번 — 흰색
		var f: float = float(pair["flash"])
		beast.modulate = Color(1, 1, 1).lerp(Color(3.0, 3.0, 3.0), clampf(f / 0.1, 0.0, 1.0))

		# 11 번 — 넓어지면 낮아진다. 부피를 지킨다.
		var q: float = float(pair["squash"])
		var w := 1.0 + sin(clampf(q / 0.18, 0.0, 1.0) * PI) * 0.28
		beast.scale = Vector3(w, 1.0 / w, 1.0)


func _advance_effects(dt: float) -> void:
	if _slash_life > 0.0:
		_slash_life -= dt
		_slash_node.visible = true
		_slash_node.modulate = Color(1, 1, 1, clampf(_slash_life / 0.14, 0.0, 1.0))
	else:
		_slash_node.visible = false

	for i in _sparks.size():
		if _spark_life[i] <= 0.0:
			continue
		_spark_life[i] -= dt
		if _spark_life[i] <= 0.0:
			_sparks[i].visible = false
			continue
		_spark_vel[i].y -= 9.0 * dt
		_sparks[i].position += _spark_vel[i] * dt

	for i in _numbers.size():
		if _number_life[i] <= 0.0:
			continue
		_number_life[i] -= dt
		if _number_life[i] <= 0.0:
			_numbers[i].visible = false
			continue
		_numbers[i].position.y += 1.1 * dt
		_numbers[i].modulate = Color(1, 1, 1, clampf(_number_life[i] / 0.8, 0.0, 1.0))

	# 14 번 — 흰 칸이 뒤늦게 따라온다. 끄면 두 칸이 같이 움직여 아무것도 안 보인다.
	if _stage.on("bar_lag"):
		_hp_ghost = move_toward(_hp_ghost, _hp, 40.0 * dt)
	else:
		_hp_ghost = _hp
	var red := _hp / 100.0
	var ghost := _hp_ghost / 100.0
	_bar_red.scale = Vector3(maxf(red, 0.001), 1.0, 1.0)
	_bar_ghost.scale = Vector3(maxf(ghost, 0.001), 1.0, 1.0)
	_bar_red.position.x = 1.0 - (1.0 - red)
	_bar_ghost.position.x = 1.0 - (1.0 - ghost)


func _face_camera() -> void:
	var yaw: float = deg_to_rad(_stage.yaw)
	for p in _pairs:
		var pair: Dictionary = p
		(pair["man"] as Sprite3D).rotation.y = yaw
		(pair["beast"] as Sprite3D).rotation.y = yaw
	for h in _horde:
		(h as Sprite3D).rotation.y = yaw
	for sp in _sparks:
		sp.rotation.y = yaw
	_slash_node.rotation.y = yaw


func _advance_camera(raw_dt: float) -> void:
	var st = _stage
	if _shake_left > 0.0:
		_shake_left -= raw_dt
		var amp := clampf(_shake_left / 0.16, 0.0, 1.0) * 0.16
		st.shake = _shake_dir * amp * sin(_time * 90.0)
	else:
		st.shake = Vector3.ZERO
	if _punch > 0.0:
		_punch -= raw_dt
	st.view_tiles = 9.0 - clampf(_punch / 0.35, 0.0, 1.0) * 1.6
	st.place_camera()
