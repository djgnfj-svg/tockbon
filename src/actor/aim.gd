extends RefCounted
## 🔴🔴 **정수 경계다. 정수 쪽으로 들어가는 화살표는 이 함수 하나뿐이다.**
##
## ```
## fire_cmd(tip_px, mouse_px, element, glyphs) -> Dictionary
##    ↑ float px 두 개가 들어온다      ↓ 여기 return이 경계선이다
## { spell_kind, ox, oy, adx, ady, element, glyphs }   ← 전부 정수
## ```
##
## 🔴 **px → 셀 양자화가 이 함수 안에서만 일어난다.** 원점(`ox,oy`)과 조준(`adx,ady`)을
##  **한 함수가 같이** 내놓는 이유가 그것이다 — 둘을 나누면 px→셀 변환이 두 곳이 되고,
##  그 둘이 갈라지면 「조준이 미묘하게 빗나간다」로만 보인다.
##
## 🔴 **경계 함수가 float 쪽(`src/actor/`)에 사는 게 요점이다.** float을 받으니 `src/sim/`에
##  못 들어가고, 정수를 내놓으니 `src/sim/`이 받을 수 있다.
##  ⚠ 여기서 방향을 정규화하지 마라 — `atan2`·`normalized()`가 들어오는 순간 계약이 깨진다.
##   정규화는 `SpellSim._launch`가 **정수 제곱근**으로 한다.

const Tuning := preload("res://src/sim/sim_tuning.gd")
const SpellSim := preload("res://src/sim/spell_sim.gd")
const CellGrid := preload("res://src/sim/cell_grid.gd")


## 🔴🔴 **원점을 격자 안으로 클램프한다.** 경계 함수가 **못 쓰는 커맨드를 내놓을 수 있으면
##  그건 경계가 아니다.**
##
## ⚠ 도달 불가한 상태가 아니다 — 기획 「극단값」이 「발밑을 쏘면 지형이 사라지고 캐릭터가
##  떨어진다 · 막지 않는다」고 정했으므로 **캐릭터는 실제로 격자 밖으로 나간다.**
##  클램프가 없으면 그때 좌클릭이 `spell_sim`에서 `push_error`로 죽고, 화면에서는
##  **「좌클릭했는데 아무 일도 안 일어난다」**로만 보인다. 게다가 래퍼가 stderr를 실패로 치니
##  그 상태를 지나는 그물·프로브가 통째로 빨개진다.
## 🔴 그래도 `spell_sim.fire()`의 범위 검사는 **남긴다** — 저기는 네트워크가 여는 문이고,
##  이 함수는 로컬 입력만 지난다. 두 검사는 서로 다른 것을 지킨다.
static func fire_cmd(tip_px: Vector2, mouse_px: Vector2, element: int, glyphs: int) -> Dictionary:
	var ox := clampi(_to_cell(tip_px.x), 0, CellGrid.W - 1)
	var oy := clampi(_to_cell(tip_px.y), 0, CellGrid.H - 1)
	# ⚠ 조준은 **클램프한 원점 기준**의 차이다. 원점만 옮기고 마우스 셀을 그대로 빼면
	#  격자 밖에서 쏠 때 방향이 조용히 틀어진다.
	return SpellSim.cmd_fire(
		ox, oy, _to_cell(mouse_px.x) - ox, _to_cell(mouse_px.y) - oy, element, glyphs)


## ⚠ `floori`다. `int()`는 0 쪽으로 자르므로 격자 왼쪽·위 밖에서 셀 좌표가 한 칸 튄다 —
##  화면 왼쪽 끝을 겨냥했을 때만 어긋나서 **눈으로 거의 못 본다.**
static func _to_cell(px: float) -> int:
	return floori(px / Tuning.CELL_PX)
