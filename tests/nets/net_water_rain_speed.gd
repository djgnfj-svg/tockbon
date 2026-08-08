extends RefCounted
## 물비 소스 B-3·B-4 — 틱당 양에 비례해 목표에 닿나. `net_water_rain.gd`에서 더 뗐다.
##
## 🔴 **왜 또 쪼갰나 (2026-08-08, harness-manager 실측)**: 이 검사 하나가 13.2초였다 —
##  B-1·B-2·B-6(11.6초)·B-5(10.9초)와 한 파일에 있었을 때 그 파일 전체가 37초였다.
##  `net_water_rain.gd` 머리 주석에 전체 사정이 있다. 셋으로 나누면 벽시계는 합(37초)이 아니라
##  **가장 느린 하나(≈13초)** 다 — 8-way 병렬(`run_nets.ps1` `maxParallel`)에 여유가 있어서
##  그물 수가 늘어도 배치가 안 늘어난다(공짜 병렬화).
##
## ⚠ **비용을 지운 게 아니다.** 틱 수·비율 임계는 그대로다 — 옮긴 것은 프로세스뿐이다.
##
## 🔴 **아래 헬퍼는 의도된 중복이다** — `net_water_rain.gd` 머리 주석의 이유와 같다.
##  ⇒ 고치면 그쪽·`net_water.gd`·`net_water_rain_cap.gd`도 같이 고쳐라.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const WaterSource := preload("res://src/sim/water_source.gd")

## `net_water_rain.gd`와 같다.
const _PIT_ROW := 208
const _PIT_X0 := 1888


func run(t) -> void:
	_rain_speed_scales_with_per_tick(t)


func _settle(g: CellGrid, cap: int) -> int:
	g.step()
	var n := 1
	while g.active_chunk_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


func _build_settled_pit() -> CellGrid:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	_settle(g, 400)
	return g


## `src` 가 격자에 부은 총량이 `target` 에 닿을 때까지 돈다. 반환은 돈 틱 수.
## ⚠ `cap` 에 닿았으면 실패다 — `_settle` 과 같은 어법으로 부르는 쪽이 그걸 단언해야 한다.
func _ticks_until(src: WaterSource, g: CellGrid, target: int, cap: int) -> int:
	var n := 0
	while src.poured() < target and n < cap:
		src.tick(g)
		g.step()
		n += 1
	return n


## 🔴🔴 **B-3·B-4 — 목표 시각이 틱당 양에 비례하나, 그리고 루프가 실제로 여러 바퀴 돌았나.**
##
## ⚠ **뒤집으면 빨개지는 것**: 틱당 양을 반으로 줄이면(계획이 명시한 뮤테이션) 같은 목표에
##  닿는 시간이 거의 정확히 두 배가 되어야 한다 — 절반이 안 되거나 그대로면 `tick()` 이
##  `_per_tick` 을 실제로 안 쓰고 있다는 뜻이다.
## 🔴 **절대 틱 수를 못 박지 않는다 — 비율만 잰다.** 지형이 바뀌면 절대 수치는 흔들리지만
##  비율은 안 흔들린다(그래서 이 검사는 맵 변경에 안 깨진다).
## ⚠ **B-4(루프가 헛돌지 않았다)도 여기서 같이 잰다** — `ticks > 1` 단언이 그 자리다. 시작 조건이
##  거짓이라 0바퀴 돌고 「닿았다」가 공짜로 통과하는 것(CLAUDE.md의 그 사고)을 막는다.
func _rain_speed_scales_with_per_tick(t) -> void:
	# 🔴 정착 용량(≈13,312칸 × 255 ≈ 3,394,560)의 약 20%대에 둔다 — 반 속도 쪽이 두 배 걸려도
	#  넘치지 않을 여유가 필요하다.
	var target := Tuning.WATER_RAIN_PER_TICK * 40
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1

	var g1 := _build_settled_pit()
	var src1 := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)
	var ticks1 := _ticks_until(src1, g1, target, 400)
	t.ok(ticks1 > 1 and ticks1 < 400, "정상 속도가 상한 안에 목표에 닿는다 (%d틱 — 루프가 헛돌지 않았다)"
		% ticks1)

	var g2 := _build_settled_pit()
	var src2 := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK / 2)
	var ticks2 := _ticks_until(src2, g2, target, 800)
	t.ok(ticks2 > 1 and ticks2 < 800, "반 속도도 상한 안에 목표에 닿는다 (%d틱 — 루프가 헛돌지 않았다)"
		% ticks2)

	var ratio := float(ticks2) / float(ticks1)
	t.ok(ratio > 1.6 and ratio < 2.4,
		"반 속도가 걸리는 틱이 정상의 약 두 배다 (%d → %d, 비율 %.2f)" % [ticks1, ticks2, ratio])
