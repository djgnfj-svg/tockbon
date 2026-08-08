extends RefCounted
## 물비 소스(K, `src/sim/water_source.gd`) B-1·B-2·B-6 — `net_water.gd`의 단계 7이 여기로 옮겨왔다.
##
## 🔴🔴 **왜 별도 파일인가 (2026-08-08, harness-manager 실측)**: 단계 7을 `net_water.gd`에
##  얹었더니 그 그물 하나가 21초 → 48.5초가 됐다. 함수별로 재 보니 다섯 검사(B-1·B-2·B-6·
##  B-3/4·B-5)만으로 35.7초였고, 나머지 39개 검사는 11.2초였다 — **한 파일에 있으면 합쳐서
##  돈다.** `tests/run_nets.ps1`은 `net_*.gd` **파일마다** 별도 프로세스로 병렬 실행하므로
##  (그 파일 머리 주석 「그물마다 별도 프로세스로 병렬 실행한다」), 옮기면 여러 프로세스가
##  **동시에** 돌고 전체 벽시계 시간이 그룹들의 합이 아니라 **가장 느린 그룹 하나**로 줄어든다.
##
## 🔴 **다섯을 셋으로 더 쪼갰다.** B-3/4(13.2초)·B-5(10.9초)를 각자 파일로 더 뗐다
##  (`net_water_rain_speed.gd`·`net_water_rain_cap.gd`) — 여기 남은 B-1·B-2·B-6은 11.6초다.
##  ⇒ 이 셋이 동시에 돌면 벽시계는 37초의 합이 아니라 **가장 느린 하나(≈13초)** 다.
##  🔴 **더 쪼갤 수 있었던 이유가 구조적이다** — `tests/run_nets.ps1`이 그물마다 프로세스를 하나씩
##  띄우고 `maxParallel`(코어수 기반, 보통 8)까지 동시에 돈다. 16개 그물이 있던 자리에 지금
##  18개가 있어도 배치 수는 그대로다(8개씩 도니 늘어난 둘이 다음 배치를 안 만든다) — **공짜 병렬화**.
##
## ⚠ **비용을 지운 게 아니다.** 각 검사가 실제로 도는 틱 수·단언은 그대로다 — 옮긴 것은
##  「어느 프로세스에서 도나」뿐이다. 안 그러면 CLAUDE.md 「가짜 그물 금지」에 걸린다.
##
## 🔴 **파일 이름이 서로를 부분 포함해도 안전하다** (`net_water` ⊂ `net_water_rain` ⊂
##  `net_water_rain_speed`/`net_water_rain_cap`). 원래는 위험했다 — 병렬 스폰이 부분 일치
##  필터로 프로세스를 그물에 묶어서, 이 이름들로 쪼개면 한 프로세스가 여러 그물을 몰래
##  같이 돌 뻔했다(실측 57초짜리 사고). `run_nets.gd`에 `^` 정확 일치를 넣어 고쳤다 — 그 뒤로는
##  이름이 서로를 포함해도 각 프로세스가 자기 그물 하나만 돈다.
##
## 🔴 **아래 헬퍼 `_settle`·`_water_scan`은 `net_water.gd`·다른 물비 조각 파일에도 있다.**
##  의도된 중복이다 — 파일마다 독립 프로세스로 돌아야 하므로(위 이유) 공유 기반 클래스를
##  안 둔다. 이 리포의 다른 `net_*.gd`도 전부 자기 헬퍼를 스스로 든다.
##  ⇒ **이 헬퍼를 고치면 나머지 물비 조각 파일의 것도 같이 고쳐라.**

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Stage := preload("res://src/stage/stage.gd")
const WaterSource := preload("res://src/sim/water_source.gd")


func run(t) -> void:
	_rain_conserves_water(t)
	_rain_touches_only_its_row_once(t)
	_rain_leaves_no_gaps(t)


## `net_water.gd._settle`과 같다 — 위 헤더의 「의도된 중복」.
func _settle(g: CellGrid, cap: int) -> int:
	g.step()
	var n := 1
	while g.active_chunk_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


## `net_water.gd._water_scan`과 같다 — 위 헤더의 「의도된 중복」.
func _water_scan(g: CellGrid, x0: int, y0: int, x1: int, y1: int) -> Array:
	var total := 0
	var cells := 0
	var peak := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var a := g.aux_at(x, y)
			if g.mat_at(x, y) != Mat.WATER:
				continue
			total += a
			cells += 1
			peak = maxi(peak, a)
	return [total, cells, peak]


# ══════════════════════════════════════════════════════════════════
#  단계 7 — 물비 소스 (K, `src/sim/water_source.gd`)
# ══════════════════════════════════════════════════════════════════
#
# 🔴🔴 **여기부터는 `water_source.gd` 를 직접 돌린다 — 여기서 다시 구현하지 않는다.**
#  그 파일이 `src/sim/` 에 있는 이유가 「그물이 출하되는 바로 그 코드를 잰다」였다
#  (`docs/plans/2.active/water-jump-and-escape.md` 「어디에 두나」). 이 그물이 붓는 셈을
#  스스로 다시 짜면 그 이유가 무효가 되고, 초록이 나와도 게임의 물 속도는 아무도 안 잰 것이 된다.
#
# 🔴 **실제 스테이지1 ① 구덩이를 쓴다.** `Stage.build_terrain_into()` 로 진짜 지형을 세운다
#  (`net_tables._wood_clumps` 가 이미 같은 static 문을 씬 없이 쓴다). **폭은 `Tuning.WATER_RAIN_HALF_W`
#  에서 파생한다** — K가 실제로 붓는 폭과 다르면 이 그물이 게임과 다른 것을 재는 것이다.

## 구덩이 입구 행(셀). `stage1-map-layout.md` 의 타일26 = 셀 208.
const _PIT_ROW := 208
## 왼쪽 벽 안쪽 첫 칸(셀). 오른쪽 끝은 매 검사가 `Tuning.WATER_RAIN_HALF_W * 2` 폭으로 스스로 구한다.
const _PIT_X0 := 1888


## 진짜 지형을 세우고 완전히 잠들 때까지 돈다.
##
## ⚠ **B-1~B-5가 각자 독립된 그릇을 받는다** — 하나를 공유하면 한 검사가 부은 물이 다음 검사의
##  전제(「아직 안 부었다」)를 깬다. `Stage.build_terrain_into` 자체는 `cmd_fill` 뭉치라 싸지만,
##  **먼저 완전히 재운다**(맵 전체를 세우면 벽·바닥이 한꺼번에 청크를 깨운다) — 그래야
##  「지형을 세우는 스파이크」와 「물이 도는 비용」이 이후 검사에서 안 섞인다.
func _build_settled_pit() -> CellGrid:
	var g := CellGrid.new()
	Stage.build_terrain_into(g)
	_settle(g, 400)
	return g


## 🔴🔴 **B-1 — 보존.** 소스가 스스로 센 「실제로 들어간 양」과 격자의 물 총량이 정확히 같아야 한다.
##
## ⚠ **뒤집으면 빨개지는 것**: `water_source.tick()` 이 `aux_at` 으로 읽지 않고 그냥
##  `set_water(x, row, per_cell)` 로 **덮어쓰면** — 이전 틱에 쌓인 물이 사라져 `_water_scan` 의
##  합이 `poured()` 보다 작아진다. 이게 계획이 「덮어쓰기가 아니라 더하기다」라고 못 박은 사고다.
func _rain_conserves_water(t) -> void:
	var g := _build_settled_pit()
	t.eq(g.active_chunk_count(), 0, "물을 붓기 전에 지형이 완전히 잠들었다 (전제)")

	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	# 🔴 **좌표를 손으로 안 믿는다.** 맵이 바뀌면 이 단언이 먼저 값으로 빨개진다.
	t.ok(not g.is_solid(_PIT_X0, _PIT_ROW), "구덩이 입구 왼쪽 끝이 열려 있다 (전제)")
	t.ok(not g.is_solid(x1, _PIT_ROW), "구덩이 입구 오른쪽 끝도 열려 있다 (전제)")
	t.ok(g.is_solid(_PIT_X0 - 1, _PIT_ROW), "그 왼쪽은 벽이다 (전제)")
	t.ok(g.is_solid(x1 + 1, _PIT_ROW), "그 오른쪽도 막혀 있다 (전제 — 램프가 입구부터 막는다)")

	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)
	# 🔴 **100틱에서 멈춘다.** 이 그릇의 실측 용량(≈13,312칸 × 255)의 약 60%다 — 넘기면 수면이
	#  입구 위 벽 없는 하늘로 넘쳐 이 검사의 사각형 밖으로 새고, 그건 진짜 누수와 구별이 안 된다.
	for _i in 100:
		src.tick(g)
		g.step()

	t.ok(src.poured() > 0, "소스가 실제로 물을 부었다 (전제)")
	var scan := _water_scan(g, _PIT_X0 - 4, _PIT_ROW - 4, x1 + 4, _PIT_ROW + 150)
	t.eq(scan[0], src.poured(), "격자의 물 총량이 소스가 센 누적량과 정확히 같다 (안 샌다)")
	t.ok(scan[2] <= Tuning.WATER_MAX, "어떤 칸도 최대량을 안 넘는다")


## 🔴🔴 **B-2 — 한 틱에 정확히 한 번, 정확히 그 띠(`K×서브스텝`행)에만.**
##
## 🔴🔴 **2026-08-08 — 「그 행」이 「그 띠」가 됐다.** 화면에서 가로 줄무늬가 나서
##  `water_source.tick()`이 한 행 대신 `WATER_FALL_CELLS × WATER_SUBSTEPS`행짜리 띠를
##  채우도록 고쳐졌다(`water_source.gd` 헤더 — 「왜 한 행이 아닌가」). 이 검사도 그 띠를 잰다.
##
## ⚠ **뒤집으면 빨개지는 것**: `tick()` 이 부르는 쪽에서 한 틱에 두 번 불리면(예: `_on_ticked()`
##  대신 `_physics_process` 에 배선해 `TICK_DIVIDER` 배 빨리 붓는 사고) 아래 「한 번의 몫」 단언이
##  깨진다. 띠를 벗어난 행도 건드리게 고치면 위아래 행 단언이 깨진다.
##  🔴 **띠 폭을 도로 1행으로 되돌리는 것(줄무늬 버그 그 자체)은 이 검사로는 안 잡힌다** —
##  아래 `_rain_leaves_no_gaps` 가 그건 따로 잡는다. **둘이 짝이다.**
## ⚠ **`g.step()` 을 안 부른다** — 불렀으면 낙하가 띠 아래 행을 적셔 「아직 안 건드린다」가 거짓이 된다.
##  이 검사가 재는 것은 `tick()` 딱 하나의 몫이다.
func _rain_touches_only_its_row_once(t) -> void:
	var g := _build_settled_pit()
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)

	src.tick(g)
	var width := x1 - _PIT_X0 + 1
	var band_rows := Tuning.WATER_FALL_CELLS * Tuning.WATER_SUBSTEPS
	var per_cell := Tuning.WATER_RAIN_PER_TICK / (width * band_rows)
	# 표본 세 칸(양끝 + 가운데)만 본다 — 176칸을 전부 재도 답은 같지만 표본으로도 충분하다.
	for x in [_PIT_X0, (_PIT_X0 + x1) / 2, x1]:
		for y in range(_PIT_ROW, _PIT_ROW + band_rows):
			t.eq(g.aux_at(x, y), per_cell, "한 번의 몫이 정확히 칸당 양이다 (x=%d, y=%d)" % [x, y])
		t.eq(g.aux_at(x, _PIT_ROW - 1), 0, "띠 바로 위 행은 안 건드린다 (x=%d)" % x)
		t.eq(g.aux_at(x, _PIT_ROW + band_rows), 0,
			"띠 바로 아래 행도 아직 안 건드린다 (x=%d, `step()` 을 안 불렀다)" % x)
	t.eq(src.poured(), per_cell * width * band_rows,
		"누적량도 한 번의 몫(칸당 양 × 폭 × 띠 높이)과 같다")


## 🔴🔴 **B-6 — 붓는 중 세로 줄무늬(빈틈)가 없다.**
##
## 🔴🔴 **화면에서 실제로 났다**(verify-look, 2026-08-08): 한 열(cx=1975)에서 물이 든 행이
##  `K × 서브스텝`(=12칸=48px)마다 정확히 반복하고 그 사이는 전부 0이었다 — 붓기가 한 행만
##  채우는데 낙하가 한 틱에 12칸을 옮기니 **그 행이 통째로 내려가고 위가 완전히 빈 채로 한
##  틱을 보낸다.** 원인이 `K × WATER_SUBSTEPS` 값과 정확히 일치했다.
##
## ⚠ **뒤집으면 빨개지는 것**: `water_source.gd`의 `_BAND_ROWS`를 도로 1로 바꾸면(줄무늬가
##  나던 원래 코드) 이 열에서 최대 빈틈이 `K × 서브스텝 - 1` 로 나온다 — 지금은 0이어야 한다.
func _rain_leaves_no_gaps(t) -> void:
	var g := _build_settled_pit()
	var x1 := _PIT_X0 + Tuning.WATER_RAIN_HALF_W * 2 - 1
	var src := WaterSource.new(_PIT_X0, x1, _PIT_ROW, Tuning.WATER_RAIN_PER_TICK)

	var probe_x := (_PIT_X0 + x1) / 2  # verify-look이 화면에서 본 바로 그 열(1975)이다.
	var max_gap := 0
	# 🔴 20틱을 본다 — 첫 틱은 아직 안 떨어져 빈틈이 없는 게 당연하므로, 여러 틱을 봐야
	#  「계속 안 생긴다」를 잰다.
	for _i in 20:
		src.tick(g)
		g.step()
		var last_row := -1
		for y in range(_PIT_ROW, _PIT_ROW + 200):
			if g.mat_at(probe_x, y) != Mat.WATER:
				continue
			if last_row >= 0:
				max_gap = maxi(max_gap, y - last_row - 1)
			last_row = y
	t.eq(max_gap, 0, "붓는 동안 세로 줄무늬(빈틈)가 없다 (최대 빈틈 %d칸)" % max_gap)
