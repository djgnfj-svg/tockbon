extends RefCounted
## 표와 상수의 자기 정합성. 시뮬을 한 틱도 안 돌린다.
##
## 값싼 그물이 가치가 낮은 게 아니다. 여기가 잡는 것들은 전부
## "에러 없이 조용히 어긋나는" 종류다.

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")


func run(t) -> void:
	_grid_constants(t)
	_palette(t)
	_tiers(t)


## 인덱싱이 통째로 틀리면 증상이 "물이 이상하다"로만 나온다.
func _grid_constants(t) -> void:
	t.eq(1 << CellGrid.X_SHIFT, CellGrid.W, "X_SHIFT가 W와 맞는다")
	t.eq(CellGrid.X_MASK, CellGrid.W - 1, "X_MASK가 W와 맞는다")
	t.eq(CellGrid.CX * CellGrid.CHUNK, CellGrid.W, "청크가 격자 폭을 딱 나눈다")
	t.eq(CellGrid.CY * CellGrid.CHUNK, CellGrid.H, "청크가 격자 높이를 딱 나눈다")
	t.eq(1 << CellGrid.CHUNK_SHIFT, CellGrid.CHUNK, "CHUNK_SHIFT가 CHUNK와 맞는다")
	# 전하 TTL은 _aux(PackedByteArray)에 들어간다. 255를 넘으면 말없이 잘린다.
	t.ok(CellGrid.CHARGE_TTL <= 255, "CHARGE_TTL이 바이트에 들어간다")


## 팔레트는 DEFS에서 생성돼야 한다. 셰이더에 색 리터럴을 쓰면 시뮬과 렌더가 갈린다.
func _palette(t) -> void:
	var pal := Mat.bake_palette()
	t.eq(pal.size(), Mat.SLOT_COUNT, "팔레트 길이가 SLOT_COUNT")
	for id: int in Mat.ALL:
		t.eq(pal[id], Mat.DEFS[id]["color"], "%s 색이 DEFS에서 나온다" % Mat.material_name(id))
	# 정의 없는 슬롯은 마젠타여야 한다. 얌전한 검정이면 재료를 늘렸을 때 조용히 안 보인다.
	t.eq(pal[Mat.SLOT_COUNT - 1], Mat.MISSING_COLOR, "빈 슬롯은 마젠타 센티넬")

	var beh := Mat.bake_behavior()
	t.eq(beh.size(), Mat.SLOT_COUNT, "거동 테이블 길이가 SLOT_COUNT")
	for id: int in Mat.ALL:
		t.eq(beh[id], int(Mat.DEFS[id]["behavior"]), "%s 거동이 DEFS에서 나온다" % Mat.material_name(id))


## 위력 단 표. 시뮬 쪽과 연출 쪽이 같이 늘어야 한다.
## 한쪽만 늘리는 것이 이 게임의 v1이 죽은 방식이다.
func _tiers(t) -> void:
	var sim: Array = Tuning.SIM_TIERS
	var fx: Array = Tuning.FX_TIERS
	t.eq(fx.size(), sim.size(), "연출 표 길이가 시뮬 표와 같다")

	# 잔여 반경이 파괴 반경보다 커야 한다. 아니면 잔여가 전부 빈 칸 위에 떨어져 조용히 0이 된다.
	for i in sim.size():
		var d: Dictionary = sim[i]
		t.ok(int(d["rr"]) > int(d["rd"]), "P%d 잔여 반경이 파괴 반경보다 크다" % (i + 1))
		t.ok(int(d["rd"]) <= CellGrid.BLAST_R_MAX, "P%d 파괴 반경이 상한 안에 있다" % (i + 1))

	# 모든 축이 단마다 반드시 커져야 한다. 같은 값을 두면 그물이 "의도"와 "깜빡함"을 못 가른다.
	for i in range(1, sim.size()):
		var prev: Dictionary = sim[i - 1]
		var cur: Dictionary = sim[i]
		for k: String in ["rd", "rr", "fill_r"]:
			t.ok(int(cur[k]) > int(prev[k]), "시뮬 %s가 P%d→P%d에서 커진다" % [k, i, i + 1])
		t.ok(int(cur["pierce"]) >= int(prev["pierce"]), "관통이 P%d→P%d에서 안 줄어든다" % [i, i + 1])

		var pf: Dictionary = fx[i - 1]
		var cf: Dictionary = fx[i]
		for k: String in cf.keys():
			t.ok(int(cf[k]) > int(pf[k]), "연출 %s가 P%d→P%d에서 커진다" % [k, i, i + 1])

	# 원소마다 연출 색이 있어야 한다. 없으면 화면이 마젠타로 비명을 지른다.
	for e: int in Tuning.ELEM_ALL:
		t.ok(Tuning.ELEM_FX.has(e), "원소 %s에 연출 색이 있다" % Tuning.ELEM_NAMES[e])
		t.ok(Tuning.ELEM_DEFS.has(e), "원소 %s에 잔여 정의가 있다" % Tuning.ELEM_NAMES[e])
