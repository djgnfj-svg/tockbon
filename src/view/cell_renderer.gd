extends Sprite2D
## 격자를 화면에 올린다. 🔴 **읽기만 한다 — 격자에 절대 쓰지 않는다.**
##
## 🔴 **셀→픽셀 변환 패스가 아예 없다.** `_mat` 바이트 배열이 그대로 L8 텍스처 데이터다.
##  틱당 GDScript 호출 2회(`set_data` + `update`) · 36,864바이트 업로드.
##  ⚠ `Image.set_pixel` 루프로 바꾸지 마라 — 틱당 36,864회 VM 호출이라 그것만으로 4~11ms다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Fx := preload("res://src/view/fx_tuning.gd")
const SHADER_PATH := "res://src/view/cell_grid.gdshader"

var _grid: CellGrid = null
var _mat_img: Image = null
var _mat_tex: ImageTexture = null
## 🔴 **두 번째 텍스처.** 재료는 그대로인데 상태만 바뀌는 것(= 타는 중)은 여기로만 화면에 온다.
##  ⚠ `_mat`에 「불타는 나무」 재료를 따로 만드는 길도 있었지만, 그러면 불이 꺼질 때
##   원래 재료를 복원해야 하고 그 복원이 어긋나면 **에러 없이 재료가 바뀐 채로 남는다.**
var _flag_img: Image = null
var _flag_tex: ImageTexture = null


## 🔴 **`centered`·`scale`·`texture_filter`의 단일 소스는 여기다** — `.tscn`에 같은 값을 또 적지 마라.
##  런타임엔 이쪽이 이겨서 갈라져도 아무도 모른다. 그리고 `.tscn` 주석은 에디터가 저장할 때
##  날아가서 그쪽에 이유를 적어둘 수도 없다.
func setup(grid: CellGrid) -> void:
	_grid = grid

	_mat_img = Image.create_from_data(
		CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, grid.get_mat())
	_mat_tex = ImageTexture.create_from_image(_mat_img)
	_flag_img = Image.create_from_data(
		CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, grid.get_flag())
	_flag_tex = ImageTexture.create_from_image(_flag_img)

	texture = _mat_tex
	centered = false
	position = Vector2.ZERO
	scale = Vector2(Tuning.CELL_PX, Tuning.CELL_PX)
	# 프로젝트 기본이 Nearest지만 **명시**한다 — 뭉개지면 4px 셀이 통째로 죽는데
	# 그건 스샷으로만 드러나고 에러가 안 난다.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var sm := ShaderMaterial.new()
	sm.shader = load(SHADER_PATH)
	# 🔴 팔레트는 재료 표에서 **생성**해 주입한다 — 셰이더에 색을 박으면 단일 소스가 깨진다.
	sm.set_shader_parameter("palette", bake_palette())
	# 🔴 비트 위치는 `cell_materials.gd`가 단일 소스다 — 셰이더에 `2`를 박으면
	#  비트를 옮기는 날 **불이 조용히 엉뚱한 상태를 그린다.**
	sm.set_shader_parameter("flag_tex", _flag_tex)
	sm.set_shader_parameter("flag_burning", Mat.FLAG_BURNING)
	sm.set_shader_parameter("fire_lo", Fx.FIRE_LO)
	sm.set_shader_parameter("fire_hi", Fx.FIRE_HI)
	sm.set_shader_parameter("fire_hz", Fx.FIRE_FLICKER_HZ)
	material = sm


## 셰이더 `palette[16]` uniform. 🔴 `Mat.DEFS`의 `rgb`에서 **생성**한다 — 손으로 박지 마라.
##
## 🔴🔴 **이 함수가 `src/sim/`이 아니라 여기 사는 이유**: `Color`는 부동소수라 시뮬 폴더의
##  「정수만」 계약에 걸린다. 재료 표는 여전히 단일 소스이고(`rgb` 한 칸), **정수 → Color 변환만**
##  화면 쪽으로 넘어왔다.
##  ⚠ 예외 목록으로 `Color`를 사면하는 길도 있었지만, 그러면 **폴더 계약과 그물이 재는 것이
##   갈라진 채로 남는다** — 예외는 반드시 낡는다.
static func bake_palette() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(Mat.SLOT_COUNT)
	for i: int in Mat.SLOT_COUNT:
		out[i] = _rgb_to_color(Mat.rgb_of(i))
	return out


## 0xRRGGBB → Color. `Color8`은 정수 채널을 그대로 받는다(255로 나누는 코드를 두 번 쓰지 않는다).
static func _rgb_to_color(rgb: int) -> Color:
	return Color8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)


## 틱 뒤에 한 번만 부른다. 틱 사이에는 격자가 안 변하므로 더 부를 이유가 없다.
## ⚠ **두 장을 같이 올린다.** 하나만 올리면 「불은 붙었는데 안 보인다」 또는 그 반대가 되고,
##  둘 다 에러가 안 난다.
func refresh() -> void:
	if _grid == null:
		return
	_mat_img.set_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, _grid.get_mat())
	_mat_tex.update(_mat_img)
	_flag_img.set_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, _grid.get_flag())
	_flag_tex.update(_flag_img)
