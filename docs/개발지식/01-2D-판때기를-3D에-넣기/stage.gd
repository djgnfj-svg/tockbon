extends RefCounted

## **실험대 셋이 같이 쓰는 무대.** 하늘·해·카메라·스위치 목록·글자판을 세운다.
##
## ⚠⚠ **`class_name` 을 일부러 안 붙였다.** 새로 만든 `class_name` 은 편집기가 프로젝트를 한 번
## 훑기 전까지 `--script` 실행에서 못 찾을 수 있다. **`preload()` 로 부르면 그 문제가 없다.**
##
## ⚠ **해와 하늘값은 `look.gd` 에서 가져온다.** 실험대가 게임과 다른 빛을 쓰면 여기서 괜찮아 보인
## 것이 게임에서 안 괜찮아진다 — 이 저장소가 여섯 라운드 걸려 배운 것이다.

const ART := "res://docs/개발지식/자리표시/"

var tree: SceneTree = null
var world: Node3D = null
var cam: Camera3D = null
var sun: DirectionalLight3D = null
var head: Label = null
var list: Label = null
var foot: Label = null

var title := ""
## 스위치 한 줄 = `{"id": String, "name": String, "note": String, "on": bool}`
var rows: Array = []
var cursor := 0

var yaw := 0.0
var pitch := 45.0
var view_tiles := 12.0
## 카메라가 얼마나 뒤에 서나. 정사영에서는 안 보이지만 원근으로 바꾸면 이 값이 왜곡을 정한다.
var back := 60.0
var focus := Vector3.ZERO
## 실험대가 화면 흔들기에 더하는 값. 카메라 자리에 그대로 얹힌다.
var shake := Vector3.ZERO
var _turning := false
var _turn_from := Vector2.ZERO


func build(t: SceneTree, ttl: String, r: Array) -> bool:
	tree = t
	title = ttl
	rows = r
	if DisplayServer.get_name() == "headless":
		push_error("실험대: --headless 로는 볼 것이 없다. 창을 띄워서 돌려라")
		return false
	_build_world()
	_build_hud()
	place_camera()
	write()
	return true


func _build_world() -> void:
	world = Node3D.new()
	tree.root.add_child(world)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(Look.SUN_PITCH_DEG, Look.SUN_YAW_DEG, 0.0)
	sun.light_energy = Look.SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = Look.SUN_SHADOW_DIST_TILES
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_normal_bias = Look.SUN_SHADOW_NORMAL_BIAS
	world.add_child(sun)

	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Look.COL_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Look.COL_AMBIENT
	e.ambient_light_energy = Look.AMBIENT_ENERGY
	var env := WorldEnvironment.new()
	env.environment = e
	world.add_child(env)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.far = Look.CAM_FAR_TILES
	world.add_child(cam)


## 풀밭 한 장. 실험대마다 그 위에 자기 것을 얹는다.
func add_ground(tiles: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(tiles, tiles)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mi.material_override = mat
	world.add_child(mi)
	return mi


func _label(at: Vector2, size_px: int) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.91))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	tree.root.add_child(layer)
	head = _label(Vector2(22.0, 14.0), 21)
	list = _label(Vector2(22.0, 52.0), 16)
	foot = _label(Vector2(22.0, 640.0), 15)
	layer.add_child(head)
	layer.add_child(list)
	layer.add_child(foot)


## 스위치 하나가 켜져 있나. **없는 이름을 물으면 `false`** — 실험대가 아직 안 붙인 기법을
## 물어도 터지지 않게.
func on(id: String) -> bool:
	for row in rows:
		if String(row["id"]) == id:
			return bool(row["on"])
	return false


func set_on(id: String, v: bool) -> void:
	for row in rows:
		if String(row["id"]) == id:
			row["on"] = v
			return


func count_on() -> int:
	var n := 0
	for row in rows:
		if bool(row["on"]):
			n += 1
	return n


func place_camera() -> void:
	cam.size = view_tiles
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0))
	cam.transform = Transform3D(basis, focus + shake + basis * Vector3(0.0, 0.0, back))


func write() -> void:
	head.text = "%s\n켜진 기법 %d / %d" % [title, count_on(), rows.size()]
	var out := PackedStringArray()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var mark := "켜짐" if bool(row["on"]) else "  ·  "
		var arrow := "▶" if i == cursor else "  "
		out.append("%s [%s] %s" % [arrow, mark, String(row["name"])])
	list.text = "\n".join(out)
	var note := ""
	if cursor >= 0 and cursor < rows.size():
		note = String(rows[cursor]["note"])
	foot.text = "%s\n\n↑↓ 고르기   스페이스 켜고끄기   A 전부켜기   Z 전부끄기   오른쪽드래그·Q E 돌리기   R F 기울기   휠 확대   Esc 끝" % note


## 무대가 먹은 입력이면 `true`. 실험대는 `false` 일 때만 자기 키를 본다.
func handle(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			tree.quit()
			return true
		if key == KEY_UP:
			cursor = maxi(0, cursor - 1)
			write()
			return true
		if key == KEY_DOWN:
			cursor = mini(rows.size() - 1, cursor + 1)
			write()
			return true
		if key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
			if cursor >= 0 and cursor < rows.size():
				rows[cursor]["on"] = not bool(rows[cursor]["on"])
			write()
			return true
		if key == KEY_A:
			for row in rows:
				row["on"] = true
			write()
			return true
		if key == KEY_Z:
			for row in rows:
				row["on"] = false
			write()
			return true
		if key == KEY_Q:
			yaw -= 5.0
			place_camera()
			return true
		if key == KEY_E:
			yaw += 5.0
			place_camera()
			return true
		if key == KEY_R:
			pitch = clampf(pitch + 5.0, 10.0, 85.0)
			place_camera()
			return true
		if key == KEY_F:
			pitch = clampf(pitch - 5.0, 10.0, 85.0)
			place_camera()
			return true
		return false
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_RIGHT:
			_turning = click.pressed
			_turn_from = click.position
			return true
		if click.button_index == MOUSE_BUTTON_WHEEL_UP and click.pressed:
			view_tiles = clampf(view_tiles / 1.12, 3.0, 80.0)
			place_camera()
			return true
		if click.button_index == MOUSE_BUTTON_WHEEL_DOWN and click.pressed:
			view_tiles = clampf(view_tiles * 1.12, 3.0, 80.0)
			place_camera()
			return true
		return false
	if event is InputEventMouseMotion and _turning:
		var motion := event as InputEventMouseMotion
		yaw += (motion.position.x - _turn_from.x) * 0.35
		_turn_from = motion.position
		place_camera()
		return true
	return false


## **그림 한 장.** ⚠ 세 갈래로 시도한다 — 들여온 것 · 파일에서 직접 · 마지막엔 코드로 만든 네모.
## **화면이 비는 일은 없어야 한다.** 자리표시가 안 뜨면 기법이 안 보이는 게 아니라 아무것도 안 보인다.
static func tex(name: String, fallback: Color = Color(1, 0, 1)) -> Texture2D:
	var path := ART + name
	if ResourceLoader.exists(path):
		var got := ResourceLoader.load(path)
		if got is Texture2D:
			return got as Texture2D
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			return ImageTexture.create_from_image(img)
	var made := Image.create_empty(16, 32, false, Image.FORMAT_RGBA8)
	made.fill(fallback)
	return ImageTexture.create_from_image(made)
