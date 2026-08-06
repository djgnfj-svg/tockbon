extends RefCounted
## 🔴🔴 **붓 팔레트의 단일 소스. 「무엇을 그릴 수 있나」와 「몇 번 칸인가」가 여기서만 나온다.**
##
## 이 파일이 생기기 전에는 같은 것이 **두 곳에 손으로** 적혀 있었다 —
## `assets/stage/terrain_tiles.png` 의 칸 순서와 `build_terrain_tileset.gd` 의 `TILES` 표.
## ⚠ **둘이 갈라져도 게임 화면은 안 틀린다**(화면은 셀 격자가 그린다) — **붓을 집을 때만** 헷갈리고,
##  그래서 `docs/design/지형-굽기.md` 가 「아무도 눈치 못 챈다」고 적어 뒀다.
##
## 🔴 **표가 아니라 파생이다.** 그릴 수 있는 것 = `Mat.ALL` 에서 `EMPTY` 를 뺀 것 —
##  빈칸은 「타일을 안 놓는 것」이라 붓이 될 수 없다. ⇒ **재료를 늘려도 여기는 안 고친다.**
##
## ⚠ **순서가 계약이다.** atlas 좌표가 `Mat.ALL` 안의 순서에서 나오므로, `ALL` 의 **앞쪽 순서를
##  바꾸면 이미 그려 둔 맵의 타일이 통째로 다른 재료가 된다.** 🔴 뒤에 **더하는 것만** 안전하다.
##  (지금 순서: 돌 0 · 나무 1 · 기반암 2 · 물 3 — 물은 2026-08-07에 **뒤에** 붙었다.)

const Mat := preload("res://src/sim/cell_materials.gd")


## 붓이 되는 재료를 **순서대로**. index 가 곧 atlas 열이다.
static func paintable() -> Array[int]:
	var out: Array[int] = []
	for id: int in Mat.ALL:
		if id == Mat.EMPTY:
			continue
		out.append(id)
	return out


## 팔레트 순서 → atlas 좌표. 🔴 한 줄로 늘어놓는다 — 세로로 접으면 두 스크립트가 접는 규칙을
##  각자 갖게 되고, 그게 이 파일이 없애려는 것이다.
static func atlas_of(index: int) -> Vector2i:
	return Vector2i(index, 0)


## 붓 그림 한 칸의 px. 🔴 타일 크기이자 atlas 격자라 **둘이 같은 값이어야 한다.**
##  ⚠ 지형 타일은 8×8셀 = 32px이다(`sim_tuning.TILE_CELLS` × `CELL_PX`) — 여기 박지 않고
##   그 둘에서 파생시킨다. 안 그러면 타일 크기를 바꾸는 날 붓만 낡는다.
const Tuning := preload("res://src/sim/sim_tuning.gd")

static func tile_px() -> int:
	return Tuning.TILE_CELLS * Tuning.CELL_PX
