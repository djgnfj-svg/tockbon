extends RefCounted
## 물비 소스 B-5 — 붓는 동안 활성 청크가 상한 아래에 머무나. `net_water_rain.gd`에서 더 뗐다.
##
## 🔴 **왜 또 쪼갰나**: `net_water_rain.gd` 머리 주석과 같은 사정(11.6·13.2·10.9초 세 그룹).
##  이 파일 하나가 10.9초다.
##
## 🔴🔴 **지금 실패 중이다. 알려진 것이고 의도적으로 안 고쳤다** (2026-08-08, 팀 리더가 못
##  박았다) — `src/`는 harness-manager의 권한 밖이라 고치지 않는다. **이 검사를 지우거나
##  임계를 늦추지 마라.** 파일을 옮기면서도 이 계약은 그대로 들고 왔다.
##
## ⚠ **비용을 지운 게 아니다.** 130틱·상한 비교는 그대로다 — 옮긴 것은 프로세스뿐이다.
##
## 🔴 **아래 헬퍼는 의도된 중복이다** — `net_water_rain.gd` 머리 주석의 이유와 같다.
##  ⇒ 고치면 그쪽·`net_water.gd`·`net_water_rain_speed.gd`도 같이 고쳐라.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const WaterSource := preload("res://src/sim/water_source.gd")

## `net_water_rain.gd`와 같다.
const _PIT_ROW := 208
const _PIT_X0 := 1888


func run(t) -> void:
	_rain_stays_under_the_chunk_cap(t)


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


## 🔴🔴 **B-5 — 붓는 동안 상한(100)에 안 닿는다.**
##
## ⚠ **뒤집으면 빨개지는 것**: 폭(`WATER_RAIN_HALF_W`)을 넓히거나 틱당 양을 올리면 활성 청크가
##  상한에 붙는다 — 대안 A/B/C 재측정이 **이 폭·이 속도에서만** 안 붙는다고 적어 둔 값이다.
## 🔴 **지형을 먼저 완전히 재운 뒤에 잰다**(`_build_settled_pit`). 계획은 「지형 세우는 첫 30틱을
##  뺀다」고 적었지만, 여기서는 그 스파이크 자체가 시작 전에 이미 가라앉아 있으므로 **뺄 구간이
##  없다** — 물이 도는 비용만 순수하게 잡힌다.
func _rain_stays_under_the_chunk_cap(t) -> void:
	var g := _build_settled_pit()
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)

	var peak := 0
	# 🔴 130틱 ≈ 정착 용량의 76% — 상한을 재기에 충분히 오래 돌리면서도 넘쳐서 새지 않는다.
	for _i in 130:
		src.tick(g)
		g.step()
		peak = maxi(peak, g.active_chunk_count())

	t.ok(peak > 0, "붓는 동안 실제로 활성 청크가 생겼다 (전제 — 0이면 아무것도 안 잰 것이다)")
	t.ok(peak < Tuning.MAX_CHUNKS_PER_TICK,
		"붓는 동안 활성 청크가 상한(%d) 아래에 머문다 (최대 %d)" % [Tuning.MAX_CHUNKS_PER_TICK, peak])
