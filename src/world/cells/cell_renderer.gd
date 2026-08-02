extends Sprite2D
## 격자를 화면에 올린다. 🔴 **읽기만 한다 — 격자에 절대 쓰지 않는다**(설계 §8 ⑤).
##  멀티에서 클라가 복제된 격자를 그리는 것과 이 코드가 같아야 한다.
##
## 🔴 **셀→픽셀 변환 패스가 아예 없다.** `_mat`·`_flag` 바이트 배열이 그대로 L8 텍스처 데이터다.
##  틱당 GDScript 호출 4회(`set_data` 2 + `update` 2) · 73,728바이트 업로드.
##  ⚠ `Image.set_pixel` 루프로 바꾸지 마라 — 틱당 36,864회 VM 호출이라 그것만으로 4~11ms다(설계 §3).

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const SHADER_PATH := "res://src/world/cells/cell_grid.gdshader"

## 셀 하나가 화면에서 몇 px인가. GDD 확정값 4px.
const CELL_PX := 4

var _grid: CellGrid = null
var _mat_img: Image = null
var _mat_tex: ImageTexture = null
var _flag_img: Image = null
var _flag_tex: ImageTexture = null


## 🔴 **`centered`·`scale`·`texture_filter`의 단일 소스는 여기다** — `.tscn`에 같은 값을 또 적지 마라.
##  런타임엔 이쪽이 이겨서 갈라져도 아무도 모른다(SKILL.md T5). 그리고 `.tscn` 주석은
##  에디터가 저장할 때 날아가서 그쪽에 이유를 적어둘 수도 없다.
func setup(grid: CellGrid) -> void:
	_grid = grid

	_mat_img = Image.create_from_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, grid.get_mat())
	_mat_tex = ImageTexture.create_from_image(_mat_img)
	_flag_img = Image.create_from_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, grid.get_flag())
	_flag_tex = ImageTexture.create_from_image(_flag_img)

	texture = _mat_tex
	centered = false
	position = Vector2.ZERO
	scale = Vector2(CELL_PX, CELL_PX)
	# 프로젝트 기본이 Nearest지만 **명시**한다 — 뭉개지면 4px 셀이 통째로 죽는데
	# 그건 스샷으로만 드러나고 에러가 안 난다(설계 §3).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var sm := ShaderMaterial.new()
	sm.shader = load(SHADER_PATH)
	sm.set_shader_parameter("flag_tex", _flag_tex)
	# 🔴 팔레트는 재료 테이블에서 **생성**해 주입한다 — 셰이더에 색을 박으면 단일 소스가 깨진다.
	sm.set_shader_parameter("palette", Mat.bake_palette())
	material = sm


## 틱 뒤에 한 번만 부른다. 틱 사이에는 격자가 안 변하므로 더 부를 이유가 없다.
func refresh() -> void:
	if _grid == null:
		return
	_mat_img.set_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, _grid.get_mat())
	_mat_tex.update(_mat_img)
	_flag_img.set_data(CellGrid.W, CellGrid.H, false, Image.FORMAT_L8, _grid.get_flag())
	_flag_tex.update(_flag_img)
