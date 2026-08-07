extends RefCounted
## 물과 청크 재우기. 🔴🔴 **물의 실패는 전부 조용하다** — 그래서 여기는 짖음이 아니라 **값**을 잰다.
##
## ⚠ **지금 여기 있는 것은 단계 1(청크 재우기)과 단계 2(아래로 떨어진다)다.**
##  좌우 나눔도 젖음도 물 룬도 아직 없다. 기획이 단계를 가른 이유가 이것이다: 청크가 잘못 서면
##  물도 같이 틀리고 **어느 쪽이 원인인지 못 가른다**
##  (`docs/plans/2.active/water-and-chunk-sleep.md` 「만드는 순서」).
##
## 🔴 **「안 움직인다」로는 아무것도 못 잰다.** v1은 물이 멈춘 것처럼 보이는데 안 멈추고 있었다.
##  ⇒ 여기서 재는 것은 전부 `active_chunk_count()` · `chunk_awake_at()` 같은 **숫자**다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")


func run(t) -> void:
	_chunk_geometry(t)
	_empty_grid_never_wakes(t)
	_blast_wakes_chunk(t)
	_woken_chunk_sleeps_next_tick(t)
	_fill_wakes_exactly_the_covered_chunks(t)
	_ignite_does_not_touch_chunks(t)
	_flip_is_at_tick_start(t)
	_reset_clears_chunks(t)
	_band_summary_matches_scan(t)
	# ── 단계 2 ──
	_water_material_derives_its_rules(t)
	_water_door_refuses_bad_targets(t)
	_write_cell_wipes_water(t)
	_water_falls_per_tick(t)
	_water_falls_and_stacks(t)
	_water_total_is_conserved(t)
	_settled_water_sleeps(t)
	_digging_below_a_chunk_edge_wakes_the_water(t)
	_cmd_fill_refuses_water(t)
	_water_moves_mark_the_screen_dirty(t)
	_bottom_row_water_is_safe(t)
	_front_has_no_unburnable(t)
	# ── 단계 3 ──
	_water_lies_flat(t)
	_min_diff_stops_the_shuffling(t)
	_column_edge_wakes_the_neighbour(t)
	_narrow_bowl_reaches_zero(t)
	_wide_bowl_settles_under_the_cap(t)
	_left_right_has_no_bias(t)
	_tick_cap_delays_but_never_drops(t)
	_same_commands_give_the_same_grid(t)
	_sleeping_grid_is_cheap(t)
	# ── 단계 4 ──
	_shallow_bit_tracks_the_amount(t)
	# ── 단계 5 ──
	_water_disc_fills_without_wiping(t)
	_water_rune_makes_water(t)
	# ── 단계 6 ──
	_water_puts_out_fire(t)
	_no_water_means_no_rescue(t)
	_wet_neighbour_never_catches(t)
	_fire_beside_water_does_not_flicker(t)
	_no_cell_carries_both_bits(t)


## 🔴 격자와 청크가 안 나눠떨어지면 가장자리 셀이 **범위 밖 청크를 찍는다.**
##  `_init()` 이 짖게 해 뒀지만, 짖음에 기대지 않고 여기서 값으로 잰다
##  (CLAUDE.md 「짖음에 기대지 마라 — 흔적을 값으로 남겨서 재라」).
func _chunk_geometry(t) -> void:
	t.eq(CellGrid.W % Tuning.CHUNK_CELLS, 0, "W가 청크 한 변으로 나눠떨어진다")
	t.eq(CellGrid.H % Tuning.CHUNK_CELLS, 0, "H가 청크 한 변으로 나눠떨어진다")
	t.eq(CellGrid.CHUNK_W * Tuning.CHUNK_CELLS, CellGrid.W, "청크 열 수 × 한 변 = W")
	t.eq(CellGrid.CHUNK_H * Tuning.CHUNK_CELLS, CellGrid.H, "밴드 수 × 한 변 = H")
	t.eq(CellGrid.CHUNK_COUNT, CellGrid.CHUNK_W * CellGrid.CHUNK_H, "청크 수가 두 축의 곱이다")

	# 🔴 **마지막 셀이 마지막 청크에 들어가야 한다.** 잘림이 있으면 여기가 범위를 넘는다 —
	#  `chunk_awake_at` 이 그 인덱스를 실제로 읽으므로 넘으면 엔진이 짖는다(= 침묵사가 아니다).
	var g := CellGrid.new()
	t.ok(not g.chunk_awake_at(CellGrid.W - 1, CellGrid.H - 1),
		"격자 마지막 셀의 청크를 읽어도 범위를 안 넘는다")
	t.ok(not g.chunk_awake_at(-1, 0), "격자 밖은 안 깨어 있다 (왼쪽)")
	t.ok(not g.chunk_awake_at(0, CellGrid.H), "격자 밖은 안 깨어 있다 (아래)")


## 🔴🔴 **이 그물의 바닥이다.** 아무도 안 건드린 격자가 스스로 깨어나면 청크 재우기는
##  통째로 무효이고, 그 위에 얹는 물의 판정이 전부 거짓말이 된다.
## ⚠ **한 틱으로는 못 잰다** — `_chunk_flip` 이 잘못 서 있어도 첫 틱은 우연히 0일 수 있다.
func _empty_grid_never_wakes(t) -> void:
	var g := CellGrid.new()
	t.eq(g.active_chunk_count(), 0, "갓 만든 격자는 활성 청크가 0이다")
	for _i in 20:
		g.step()
	t.eq(g.active_chunk_count(), 0, "빈 격자는 20틱을 돌려도 활성 청크가 0이다")
	t.eq(g.get_tick(), 20, "그동안 틱은 실제로 돌았다")


## 🔴🔴 **폭발이 청크를 깨우나.** 안 깨우면 「뚫은 그릇에서 물이 안 샌다」이고
##  원인은 물이 아니라 폭발 쪽에 있다 — 화면에서는 「물이 고장 났다」로만 보인다.
##
## ⚠ **`step()` 을 한 번 돌린 뒤에 봐야 한다.** 커맨드는 `_dirty` 를 찍고, 그게 `awake` 가 되는
##  자리는 `_chunk_flip()` 이다. 🔴 **그 flip이 틱 끝에 있으면 여기가 빨개진다** — 폭발은
##  `spell_sim.step()` 안에서 격자를 부르므로 flip이 뒤에 있으면 찍힌 dirty가 그 자리에서 지워진다.
func _blast_wakes_chunk(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 511, 511, Mat.STONE))
	# 지형을 깔면 깨어난다 — 먼저 **완전히 재운다.** 그래야 아래 깨움이 폭발 때문인 게 확실하다.
	# ⚠ **두 틱으로는 안 된다.** 1,024청크가 깨는데 한 틱 상한이 512라 **밀린다**(단계 3).
	#  그걸 모르고 두 틱으로 두면 이 검사가 「깨어 있다」를 폭발 탓으로 오해한다.
	var calm := _settle(g, 200)
	t.ok(calm > 1 and calm < 200, "지형이 결국 다 잠든다 (%d틱 — 상한에 밀린 만큼 걸린다)" % calm)
	t.eq(g.active_chunk_count(), 0, "완전히 잠들었다")

	g.apply(CellGrid.cmd_blast(200, 200, Tuning.blast_rd(0), Tuning.blast_ignite_r(0)))
	g.step()
	t.ok(g.chunk_awake_at(200, 200), "폭발 자리의 청크가 깨어난다")
	t.ok(g.active_chunk_count() > 0, "활성 청크가 0이 아니다 (%d개)" % g.active_chunk_count())

	# 🔴 **먼 곳은 안 깨어난다.** 「전부 깨운다」로 통과하면 이 그물은 아무것도 안 재는 것이다.
	t.ok(not g.chunk_awake_at(2000, 800), "폭발과 먼 청크는 안 깨어난다")


## 🔴🔴 **깨운 다음 틱에 다시 잠드나.** 안 잠들면 청크 재우기가 「전부 깨어 있다」로 퇴화하고,
##  그건 **아무도 안 짖는다** — 그냥 예산의 12%가 사라질 뿐이다.
func _woken_chunk_sleeps_next_tick(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, 100, 140, 140, Mat.WOOD))
	g.step()
	t.ok(g.chunk_awake_at(120, 120), "채운 자리가 깨어 있다")
	var woke := g.active_chunk_count()
	t.ok(woke > 0, "채우기가 청크를 깨웠다 (%d개)" % woke)

	# 🔴 아무도 안 움직였으므로 dirty가 비어 있어야 하고, flip이 그걸 그대로 넘긴다.
	g.step()
	t.ok(not g.chunk_awake_at(120, 120), "아무 일도 안 일어난 청크는 한 틱 뒤 잠든다")
	t.eq(g.active_chunk_count(), 0, "한 틱 뒤 활성 청크가 0이다")


## 🔴 **깬 청크 수가 지형이 덮은 청크 수와 정확히 같은가.** 「0보다 크다」로는 못 잰다 —
##  `_touch` 가 청크 인덱스를 잘못 계산해도 그건 통과한다.
## ⚠ 그래서 **청크 격자에 딱 맞춘 사각형**을 쓴다. 계산이 한 칸이라도 밀리면 수가 안 맞는다.
func _fill_wakes_exactly_the_covered_chunks(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	var g := CellGrid.new()
	# 청크 (2..5, 밴드 3..6) = 4 × 4 = 16개를 정확히 덮는다.
	g.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc - 1, 7 * cc - 1, Mat.STONE))
	g.step()
	# 🔴🔴 **16이 아니라 28이다** — `_touch` 가 **물이 흘러들 수 있는 이웃 청크도 깨우기 때문이다**
	#  (청크 경계의 「보이지 않는 벽」 고침). 덮은 16 + 위 4밴드 + 좌 4밴드 + 우 4밴드 = 28.
	#  ⚠ 16으로 돌아가면 고침이 통째로 사라진 것이고, 20이면 **좌우만 사라진 것**이다(단계 3).
	t.eq(g.active_chunk_count(), 28, "덮은 16청크 + 위·좌·우 이웃 12청크 = 28이 깨어난다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc), "왼쪽 위 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(6 * cc - 1, 7 * cc - 1), "오른쪽 아래 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc - 1), "바로 위 청크가 깨어 있다 (물이 위에서 흘러든다)")

	# 🔴🔴 **좁게 깨우는 것이 결정이다.** 8이웃을 다 찍으면 아래·좌우도 깨어 있을 것이고,
	#  깨어 있는 밴드 하나가 128μs라 그 값이 그대로 예산이 된다(verify-run 실측).
	#  ⇒ **물이 흘러들 수 있는 방향(위)만** 깨운다.
	t.ok(g.chunk_awake_at(2 * cc - 1, 3 * cc), "바로 왼쪽 청크가 깨어 있다 (물이 옆에서 흘러든다)")
	t.ok(g.chunk_awake_at(6 * cc, 3 * cc), "바로 오른쪽 청크가 깨어 있다")
	t.ok(not g.chunk_awake_at(2 * cc, 1 * cc), "두 밴드 위(밴드 1)는 안 깨어 있다 (한 칸만 번진다)")
	t.ok(not g.chunk_awake_at(2 * cc, 7 * cc), "**아래** 청크는 안 깨어 있다 (물은 아래에서 안 온다)")
	t.ok(not g.chunk_awake_at(0 * cc, 3 * cc), "두 청크 왼쪽(열 0)은 안 깨어 있다 (한 칸만 번진다)")

	# 한 칸만 더 채우면 정확히 한 열이 더 깨어야 한다 — 인덱스가 밀리면 여기가 어긋난다.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc, 7 * cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.active_chunk_count(), 29, "오른쪽으로 한 칸 넘치면 밴드 4개가 한 청크씩 더 깨어난다")


## 🔴🔴 **점화는 청크를 안 찍는다 — 결정이지 사고가 아니다.**
##  `_ignite_cell` 은 `_flag`·`_aux` 만 만지고 재료를 안 바꾼다. 불은 파면 목록이라 청크와
##  독립이고(GDD), 점화 조건이 연료 > 0 이라 **물 칸(연료 0)에 원리적으로 못 닿는다.**
##
## ⚠ **계획과 `_touch` 주석이 이걸 못 박아 놓고 아무도 안 쟀다.** 나중에 「불도 깨워야 하나」로
##  누가 `_ignite_cell` 에 `_touch` 를 넣으면 **타는 나무 전체가 매 틱 청크를 깨운다** —
##  고인 호수 옆 숲 하나가 예산을 먹는데 **에러도 화면 변화도 없다.**
func _ignite_does_not_touch_chunks(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, 100, 110, 100, Mat.WOOD))
	g.step()
	g.step()
	t.eq(g.active_chunk_count(), 0, "나무를 깔고 재운다 (이 검사의 전제)")

	t.ok(g.ignite(105, 100), "나무에 불이 붙는다 (검사의 전제 — 안 붙으면 아래가 헛돈다)")
	g.step()
	t.eq(g.active_chunk_count(), 0, "점화만으로는 청크가 안 깨어난다")
	# 🔴 **타는 동안에도 안 깨운다.** 연료가 줄기만 하는 틱은 `_write_cell` 을 안 지난다.
	g.step()
	g.step()
	t.ok(g.burning_count() > 0, "아직 타는 중이다 (검사의 전제)")
	t.eq(g.active_chunk_count(), 0, "타는 동안에도 청크가 안 깨어난다")


## 🔴🔴 **`_chunk_flip()` 이 틱의 시작인가 — 이 그물에서 값이 제일 큰 검사다.**
##
## ⚠ **틱 도중에 움직이는 것이 물뿐이라고 생각하기 쉽지만 틀렸다** — `_burn()` 이 `step()`
##  **안에서** 다 탄 칸에 `_write_cell(EMPTY)` 를 부르고, 그게 `_touch` 를 탄다.
##  ⇒ **물 없이도 flip 배치가 관측된다.**
##
## 🔴 갈리는 자리가 정확히 여기다(실측):
##    flip 앞(맞다) — 다 탄 그 틱: 활성 0 · 한 틱 더: 활성 1
##    flip 뒤(틀렸다) — 다 탄 그 틱: **활성 1**
##  ⚠ 이 검사가 없으면 flip을 끝으로 옮겨도 나머지가 **전부 초록**이고, 옮긴 사람이 그 초록을
##   근거로 쓴다. 그때 대가는 「폭발로 뚫었는데 다음 틱에 안 샌다」이고 **에러가 안 난다.**
func _flip_is_at_tick_start(t) -> void:
	var g := CellGrid.new()
	# 🔴 **한 칸이어야 한다.** 여러 칸이면 다 타는 틱이 갈려서 아래 0/1이 뭉개진다.
	g.apply(CellGrid.cmd_fill(100, 100, 100, 100, Mat.WOOD))
	g.step()
	g.step()
	t.eq(g.active_chunk_count(), 0, "나무 한 칸을 깔고 재운다 (이 검사의 전제)")

	g.ignite(100, 100)
	var ticks := 0
	while g.burning_count() > 0 and ticks < 200:
		g.step()
		ticks += 1
	t.eq(g.burning_count(), 0, "나무 한 칸이 다 탄다 (%d틱)" % ticks)
	# 🔴 **`_write_cell` 이 실제로 돌았다는 증거.** 안 돌았으면 아래 0은 「아무 일도 없었다」라
	#  같은 값이 나오고, 그러면 이 검사가 통째로 헛돈다.
	t.eq(g.mat_at(100, 100), Mat.EMPTY, "다 탄 자리가 빈칸이 됐다 (`_write_cell` 이 돌았다)")

	t.eq(g.active_chunk_count(), 0, "다 탄 그 틱에는 아직 안 깨어 있다 (flip이 틱 시작이라는 증거)")
	g.step()
	t.eq(g.active_chunk_count(), 1, "한 틱 뒤에 정확히 한 청크가 깨어난다")
	t.ok(g.chunk_awake_at(100, 100), "깨어난 것이 다 탄 자리의 청크다")


## 🔴 `_reset` 이 청크를 안 비우면 **새 무대가 옛 dirty 를 들고 태어난다** —
##  `_burning` 과 똑같은 함정이고, `_reset` 은 `fill` 을 쓰므로 `_write_cell` 을 한 번도 안 지난다.
##
## 🔴🔴 **awake 와 dirty 를 다른 검사로 잰다. 한 검사로 묶으면 절반이 헛돈다.**
##  ⚠ **실측이다**(2026-08-07, 구현이 뒤집어 봤다): `_reset` 에서 `_dirty`·`_band_dirty` 지우는
##   두 줄만 빼도 아래 ① 은 **초록**이었다 — ① 은 리셋 전에 `step()` 을 돌려서 dirty 가 이미
##   비어 있었고, 그러니 「dirty 도 비었다」라는 라벨이 재는 것보다 넓었다.
##   ⇒ ② 처럼 **찍힌 채로** 리셋해야 그 절반이 실제로 재진다(CLAUDE.md 「가짜 그물 금지」).
func _reset_clears_chunks(t) -> void:
	# ① awake 쪽 — 이미 깨어 있는 청크를 리셋이 재우나.
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, 511, 511, Mat.STONE))
	g.step()
	t.ok(g.active_chunk_count() > 0, "먼저 청크를 깨운다 (%d개)" % g.active_chunk_count())

	g.apply(CellGrid.cmd_reset())
	t.eq(g.active_chunk_count(), 0, "리셋이 활성 청크를 0으로 만든다")
	# 🔴 **밴드 요약도 같이 봐야 한다.** `_reset` 에서 `_band_awake.fill(0)` **한 줄만** 빼도
	#  위 줄은 초록이다 — 요약은 `_awake` 와 다른 배열이라 서로를 안 고친다.
	#  ⚠ 요약이 부푼 채 남으면 순회가 **텅 빈 밴드를 매 틱 훑는다**(느려질 뿐 안 짖는다).
	t.eq(_band_sum(g), 0, "리셋 직후 밴드 요약 합도 0이다")
	g.step()
	t.eq(g.active_chunk_count(), 0, "리셋 뒤 한 틱을 돌려도 활성 청크가 0이다")

	# ② dirty 쪽 — 🔴 **찍힌 채로 리셋한다.** flip 을 한 번도 안 지났으므로 옛 dirty 가
	#  살아 있으면 리셋 다음 틱에 **새 무대가 그걸 그대로 깨운다.**
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(0, 0, 511, 511, Mat.STONE))
	t.eq(g2.active_chunk_count(), 0, "채우기 직후는 아직 안 깨어 있다 (flip 전이다 — 이 검사의 전제)")
	g2.apply(CellGrid.cmd_reset())
	g2.step()
	t.eq(g2.active_chunk_count(), 0, "찍힌 채로 리셋하면 다음 틱에도 안 깨어난다 (dirty를 비웠다)")
	t.eq(_band_sum(g2), 0, "그때 밴드 요약 합도 0이다 (밴드 쪽 dirty도 비웠다)")


## 🔴🔴 **밴드 요약이 진짜인가.** `_band_awake` 는 `_touch` 가 증분으로 들고, 그 값이 낮으면
##  순회가 **깨어 있는 밴드를 통째로 건너뛴다** — 물이 그 자리에 얼어붙고 에러는 0이다.
##
## ⚠ **없어도 격자는 정확히 돈다(느려질 뿐이다).** 그래서 이 값은 조용히 죽을 수 있고,
##  그걸 잡는 유일한 길이 **독립 측정과 맞대는 것**이다(`claimed_slot_count` 와 같은 자리).
func _band_summary_matches_scan(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	var g := CellGrid.new()
	t.eq(_band_sum(g), 0, "빈 격자의 밴드 요약 합이 0이다")

	# 밴드 3에 청크 5개, 밴드 9에 청크 2개.
	g.apply(CellGrid.cmd_fill(0, 3 * cc, 5 * cc - 1, 4 * cc - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(40 * cc, 9 * cc, 42 * cc - 1, 10 * cc - 1, Mat.WOOD))
	g.step()

	var mismatched := 0
	for b in CellGrid.CHUNK_H:
		if g.band_awake_count(b) != g.scan_awake_in_band(b):
			mismatched += 1
	t.eq(mismatched, 0, "모든 밴드에서 요약과 직접 센 값이 같다")
	# ⚠ 좌우 이웃까지 깨므로 덮은 수보다 크다 — 밴드 3은 청크 0..4 + 오른쪽 1 = 6
	#  (왼쪽은 격자 끝이라 없다), 밴드 9는 청크 40·41 + 좌우 각 1 = 4.
	t.eq(g.band_awake_count(3), 6, "밴드 3의 요약이 6이다 (덮은 5 + 오른쪽 이웃 1)")
	t.eq(g.band_awake_count(9), 4, "밴드 9의 요약이 4다 (덮은 2 + 좌우 이웃 2)")
	t.eq(_band_sum(g), g.active_chunk_count(), "밴드 요약의 합이 활성 청크 수와 같다")

	# 🔴 **같은 청크를 여러 번 찍어도 요약이 안 부푼다.** `_touch` 의 중복 가드가 그 자리다 —
	#  안 걸러지면 요약이 실제보다 커지고, 그건 「깨어 있다고 착각해서 도는」 쪽이라 안 짖는다.
	var g2 := CellGrid.new()
	for _i in 4:
		g2.apply(CellGrid.cmd_fill(0, 0, cc - 1, cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.band_awake_count(0), 2, "한 청크를 네 번 채워도 밴드 요약이 안 부푼다 (덮은 1 + 오른쪽 1)")
	t.eq(g2.active_chunk_count(), 2, "활성 청크도 2다")

	# 잠들면 요약도 같이 0으로 돌아가야 한다 — flip이 요약을 안 갈아 끼우면 여기가 걸린다.
	g2.step()
	t.eq(_band_sum(g2), 0, "다 잠들면 밴드 요약 합도 0이다")


## 🔴🔴 **평형까지 돌린다. 「먼저 한 틱을 돈다」가 이 함수의 존재 이유다.**
##
## ⚠ 커맨드는 `_dirty` 만 찍으므로 **flip 전에는 `active_chunk_count()` 가 0이다** —
##  `while active > 0` 로 시작하는 루프는 **한 번도 안 돌고**, 그러면 「잠들었다」가 공짜로 통과한다.
## 🔴 **이 리포에서 실제로 세 번 났다**(2026-08-07). 세 번째는 뮤테이션이 안 물어서 알았다.
##  ⇒ **직접 while 을 쓰지 마라. 이 문을 써라.**
##
## 반환은 돈 틱 수다. ⚠ `cap` 에 닿았으면 평형이 **아니다** — 부르는 쪽이 그걸 단언해야 한다.
func _settle(g: CellGrid, cap: int) -> int:
	g.step()
	var n := 1
	while g.active_chunk_count() > 0 and n < cap:
		g.step()
		n += 1
	return n


## 한 열에서 물이 든 행을 전부 모은다. 🔴 **「어디 있나」와 「몇 칸인가」를 한 번에 준다** —
##  자리를 미리 짐작해 `aux_at` 을 찍으면 **복제된 칸이 검사 밖에 남는다.**
func _column_water_rows(g: CellGrid, x: int, y0: int, y1: int) -> Array[int]:
	var rows: Array[int] = []
	for y in range(y0, y1 + 1):
		if g.aux_at(x, y) > 0:
			rows.append(y)
	return rows


## 밴드 요약의 전체 합. 🔴 **`active_chunk_count()` 와 독립적인 경로다** — 둘을 맞대야
##  「요약이 부풀었다」와 「요약이 비었다」를 둘 다 잡는다.
func _band_sum(g: CellGrid) -> int:
	var n := 0
	for b in CellGrid.CHUNK_H:
		n += g.band_awake_count(b)
	return n


# ══════════════════════════════════════════════════════════════════
#  단계 2 — 물 재료 + 아래로만 떨어진다
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **물의 규칙 둘은 표에서 파생된다. 따로 막는 코드가 없다** — 그래서 표를 잰다.
##  ⚠ 누가 `DEFS` 의 `behavior` 를 `BEHAVIOR_STATIC` 으로 바꾸면 **캐릭터가 물 위에 선다**.
##   `fuel` 을 올리면 **물에 불이 붙는다.** 둘 다 에러가 안 나고 화면에서만 이상하다.
func _water_material_derives_its_rules(t) -> void:
	t.ok(Mat.ALL.has(Mat.WATER), "WATER가 ALL 목록에 있다 (순회가 명시 목록으로만 돈다)")
	t.ok(Mat.DEFS.has(Mat.WATER), "WATER가 DEFS에 있다")
	t.ok(Mat.WATER < Mat.SLOT_COUNT, "WATER id %d 가 팔레트 슬롯 %d 안이다" % [
		Mat.WATER, Mat.SLOT_COUNT])
	t.ok(Mat.rgb_of(Mat.WATER) != Mat.MISSING_RGB, "WATER에 색이 있다 (마젠타 센티넬이 아니다)")

	var g := CellGrid.new()
	t.ok(g.set_water(50, 50, 200), "물을 놓는다 (아래 검사들의 전제)")
	# 🔴 **거동을 파생값으로 잰다** — `is_solid` 가 「고체인가」의 단일 소스다.
	t.ok(not g.is_solid(50, 50), "물은 고체가 아니다 (캐릭터도 탄도 통과한다)")
	t.ok(not g.ignite(50, 50), "물에는 불이 안 붙는다 (연료가 0이라 파생된다)")
	t.eq(g.burning_count(), 0, "파면에도 안 올라간다")


## 🔴🔴 **물의 문이 아무 데나 쓰면 안 되는 이유는 파면이다.** `_write_water` 는 `_unburn` 을
##  안 부르므로, 타는 칸에 물을 쓰면 **소속을 주장하는 유령**이 남고 그 칸은 영영 다시 못 탄다.
##  ⚠ `claimed_slot_count()` 로 그걸 값으로 잰다 — 화면에도 에러에도 안 나오는 종류다.
func _water_door_refuses_bad_targets(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(10, 10, 10, 10, Mat.STONE))
	g.apply(CellGrid.cmd_fill(12, 10, 12, 10, Mat.WOOD))
	g.ignite(12, 10)
	t.eq(g.burning_count(), 1, "나무 한 칸이 탄다 (검사의 전제)")

	t.ok(not g.set_water(10, 10, 100), "돌 위에는 물을 못 놓는다")
	t.eq(g.mat_at(10, 10), Mat.STONE, "돌이 그대로다")
	t.ok(not g.set_water(12, 10, 100), "타는 칸에는 물을 못 놓는다")
	t.eq(g.burning_count(), 1, "파면이 그대로다")
	t.eq(g.claimed_slot_count(), g.burning_count(), "유령 슬롯이 안 생긴다")

	t.ok(not g.set_water(-1, 10, 100), "격자 밖은 조용히 거절한다")
	# 🔴 **범위를 넘는 양은 짖고 버린다.** 안 보면 `PackedByteArray` 가 말없이 하위 8비트로 자른다.
	t.expect_error("CellGrid.set_water: 양")
	t.ok(not g.set_water(20, 20, Tuning.WATER_MAX + 1), "최대량을 넘는 양은 짖고 안 놓인다")
	t.eq(g.mat_at(20, 20), Mat.EMPTY, "거절된 양이 칸을 안 건드린다")

	# 물 위에 물은 놓인다 — 그게 「양을 고쳐 쓴다」이고 물 룬이 지날 길이다.
	t.ok(g.set_water(30, 30, 100), "빈칸에 물을 놓는다")
	t.ok(g.set_water(30, 30, 200), "물 위에 물을 다시 놓는다")
	t.eq(g.aux_at(30, 30), 200, "양이 덮어써진다")
	t.ok(g.set_water(30, 30, 0), "양 0을 쓰면")
	t.eq(g.mat_at(30, 30), Mat.EMPTY, "그 칸이 빈칸이 된다")


## 🔴🔴 **두 문의 경계.** 폭발이 물을 지우는 것은 양을 0으로 만드는 게 아니라 **칸을 통째로
##  비우는 것**이고, 그때는 `_write_cell` 이 맞다 — 기획 ②의 마지막 줄이 그걸 못 박았다.
## ⚠ **반대쪽(물이 `_write_cell` 을 지나면 양이 증발한다)은 여기가 아니라 `총량 보존`이 잡는다.**
func _write_cell_wipes_water(t) -> void:
	var g := CellGrid.new()
	g.set_water(100, 200, 255)
	t.eq(g.aux_at(100, 200), 255, "물이 놓였다 (검사의 전제)")

	g.apply(CellGrid.cmd_carve(100, 200, 3))
	t.eq(g.mat_at(100, 200), Mat.EMPTY, "파기가 물 칸을 비운다")
	t.eq(g.aux_at(100, 200), 0, "그때 양도 같이 0이 된다 (칸을 통째로 비우는 게 맞다)")
	t.eq(g.count_material(Mat.WATER), 0, "물이 한 칸도 안 남는다")


## 🔴🔴 **순회 순서 계약을 정면으로 재는 유일한 검사다**(`cell_grid.gd` 머리).
##  단일 버퍼라 「도착지는 이번 틱에 이미 지났거나 아예 안 도는 자리」여야 하고, 그걸 세우는 것이
##  **밴드 아래→위 · 밴드 안 행도 아래→위**다.
##
## ⚠ **뒤집으면 물이 한 틱에 격자를 가로지른다** — 그런데 **최종 상태는 똑같다.**
##  「다 쌓였나」·「총량이 같나」는 순서를 뒤집어도 전부 초록이다. ⇒ **틱마다 봐야만 잡힌다.**
## 🔴 밴드 경계(575 → 576)를 일부러 지난다. 밴드 순서만 뒤집혀도 거기서 갈린다.
##
## 🔴🔴 **2026-08-07 — 「정확히 한 칸」이 「한 틱에 최대 `WATER_SUBSTEPS` 칸」이 됐다.**
##  `cell_grid.step()` 이 `_water_step` 을 그 수만큼 돌리므로 **낙하도 같이 그만큼 빨라진다**
##  (그 상수 주석 — 사용자가 「물이 퍼지는 게 느리다」고 판정한 결과다).
##
## ⚠ **왜 「정확히 N칸」이 아니라 범위인가**: 서브스텝 사이에 `_chunk_flip` 이 없어서, 물이
##  **밴드 경계를 넘어 들어간 그 틱에는 아래 밴드가 아직 안 깨어 있으면 남은 서브스텝을 쉰다**
##  (`cell_grid._water_tick` 주석). ⇒ 16행마다 한 번 **N보다 적게** 내려간다. 그건 이 배치의
##  성질이지 고장이 아니다 — **그 틱 수를 검사가 예측하려면 시뮬을 검사 안에 다시 짜야 한다.**
##
## 🔴 **그래도 뒤집기는 그대로 잡힌다.** 밴드나 행 순서를 뒤집으면 물이 **한 틱에 바닥까지**
##  (27칸) 내려가므로 상한 N을 훌쩍 넘는다. ⚠ **범위가 잡는 것은 「가로지르지 않는다」이고,
##  「N이 실제로 돈다」는 아래 `max_delta == WATER_SUBSTEPS` 가 따로 잰다** — 둘을 한 단언에
##  묶으면 서브스텝 루프를 1회로 줄여도 초록이 된다.
func _water_falls_per_tick(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 600, 100, 600, Mat.STONE))
	var y0 := 572
	t.eq(y0 / Tuning.CHUNK_CELLS, 35, "시작 행이 밴드 35다 (아래 경계 통과의 전제)")
	t.eq(576 / Tuning.CHUNK_CELLS, 36, "네 칸 아래가 밴드 36이다 — 이 검사가 밴드 경계를 지난다")
	# ⚠ **이 장면의 기하가 감당하는 범위**: 아래로 갈 여유가 20칸이고 밴드 높이가 16이다.
	#  넘는 값을 쓰려면 **장면을 다시 짜라** — 조용히 헛도는 것보다 여기서 짖는 게 낫다.
	t.ok(Tuning.WATER_SUBSTEPS >= 1 and Tuning.WATER_SUBSTEPS <= 8,
		"WATER_SUBSTEPS(%d)가 이 장면이 감당하는 1~8 안이다" % Tuning.WATER_SUBSTEPS)
	g.set_water(50, y0, Tuning.WATER_MAX)
	# 🔴🔴 **두 번째 기둥이 아래 밴드를 깨어 있게 잡아 둔다.** 없으면 밴드 순서 뒤집기가
	#  **안 잡힌다** — 기둥이 하나면 물이 밴드 36에 처음 들어가는 그 틱에 36이 아직 잠들어 있어서
	#  순회가 그 밴드를 아예 안 돌고, 뒤집힌 순서가 드러날 자리가 없다(2026-08-07에 확인했다).
	g.set_water(52, 578, Tuning.WATER_MAX)

	# 아래쪽 기둥이 바닥에 닿기 전까지만 본다 — 닿으면 「한 틱에 몇 칸」이 아니라 쌓임을 재게 된다.
	var ticks := mini(6, (598 - 578) / Tuning.WATER_SUBSTEPS)
	t.ok(ticks >= 2, "루프가 실제로 %d바퀴 돈다 (0바퀴면 이 검사는 공짜로 통과한다)" % ticks)
	var prev := {50: y0, 52: 578}
	var max_delta := 0
	for k in ticks:
		g.step()
		for x in [50, 52]:
			var rows := _column_water_rows(g, x, 560, 599)
			t.eq(rows.size(), 1, "%d틱 뒤 x=%d 기둥이 정확히 한 칸이다 (복제도 증발도 없다)"
				% [k + 1, x])
			if rows.size() != 1:
				return
			var y: int = rows[0]
			t.eq(g.aux_at(x, y), Tuning.WATER_MAX, "%d틱 뒤 x=%d 의 양이 그대로다" % [k + 1, x])
			var delta: int = y - int(prev[x])
			# 🔴 **아래가 비어 있는 한 반드시 내려간다.** 0이면 그 칸이 잠들어 버린 것이고,
			#  그건 「보이지 않는 벽」의 증상이다.
			t.ok(delta >= 1, "%d틱 뒤 x=%d 가 적어도 한 칸 내려갔다 (%d칸)" % [k + 1, x, delta])
			# 🔴🔴 **여기가 순회 순서 계약이다.** 뒤집으면 한 틱에 바닥까지 간다.
			t.ok(delta <= Tuning.WATER_SUBSTEPS,
				"%d틱 뒤 x=%d 가 한 틱에 %d칸을 안 넘었다 (%d칸)"
				% [k + 1, x, Tuning.WATER_SUBSTEPS, delta])
			max_delta = maxi(max_delta, delta)
			prev[x] = y

	# 🔴🔴 **서브스텝이 실제로 도는지는 이 한 줄이 잰다.** 루프를 1회로 줄이면 여기만 빨개진다 —
	#  위 범위 단언은 「더 적게 내려간다」를 다 통과시킨다.
	t.eq(max_delta, Tuning.WATER_SUBSTEPS,
		"어느 틱엔가는 정확히 %d칸 내려간다 (서브스텝이 실제로 돈다)" % Tuning.WATER_SUBSTEPS)
	t.ok(int(prev[50]) >= 576, "물이 실제로 밴드 경계(576)를 지났다 (이 검사의 전제)")
	t.eq(g.count_material(Mat.WATER), 2, "물 칸 수가 내내 2다")


## 🔴 공중에 놓은 물이 바닥까지 내려가 쌓이나. **아래로만** 가는 단계라 결과가 정확히 예측된다.
func _water_falls_and_stacks(t) -> void:
	var g := CellGrid.new()
	# 바닥 한 줄과 그 위 기둥 하나.
	g.apply(CellGrid.cmd_fill(0, 300, 200, 300, Mat.STONE))
	# 🔴 **좌우 벽이 필요하다**(단계 3부터). 없으면 물이 옆으로 퍼져 「기둥으로 쌓인다」를
	#  못 잰다 — 재는 것이 낙하인데 확산이 섞이면 두 축이 한 검사에 들어간다.
	g.apply(CellGrid.cmd_fill(99, 280, 99, 299, Mat.STONE))
	g.apply(CellGrid.cmd_fill(101, 280, 101, 299, Mat.STONE))
	var poured := 0
	for k in 4:
		g.set_water(100, 290 + k, Tuning.WATER_MAX)
		poured += Tuning.WATER_MAX

	t.eq(g.aux_at(100, 299), 0, "바닥 바로 위는 아직 비어 있다 (검사의 전제)")
	for _i in 60:
		g.step()

	# 🔴 **꽉 찬 물 4칸이 바닥 위 4칸에 그대로 쌓인다.** 한 칸이라도 새면 여기가 어긋난다.
	for k in 4:
		t.eq(g.aux_at(100, 299 - k), Tuning.WATER_MAX,
			"바닥에서 %d칸 위가 꽉 찼다" % (k + 1))
	t.eq(g.aux_at(100, 295), 0, "그 위는 비었다")
	t.eq(g.mat_at(100, 295), Mat.EMPTY, "그 위 재료도 빈칸이다")
	t.eq(g.mat_at(100, 300), Mat.STONE, "바닥 돌은 그대로다 (물이 고체를 안 지난다)")
	t.eq(g.count_material(Mat.WATER), 4, "물 칸 수가 정확히 4다")

	# 부분량도 옮겨진다 — 「받을 수 있는 만큼만」이 실제로 도나.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(0, 300, 200, 300, Mat.STONE))
	g2.apply(CellGrid.cmd_fill(49, 290, 49, 299, Mat.STONE))
	g2.apply(CellGrid.cmd_fill(51, 290, 51, 299, Mat.STONE))
	g2.set_water(50, 299, 200)
	g2.set_water(50, 298, 100)
	for _i in 20:
		g2.step()
	t.eq(g2.aux_at(50, 299), Tuning.WATER_MAX, "아래 칸이 최대까지만 찬다")
	t.eq(g2.aux_at(50, 298), 300 - Tuning.WATER_MAX, "넘친 %d 이 위에 남는다" % (300 - Tuning.WATER_MAX))


## 🔴🔴 **총량 보존 — 새는 물은 화면에서 안 보인다.**
##  ⚠ 물이 `_write_cell` 을 지나는 순간 `_flag`·`_aux` 가 0이 되어 **양이 그 자리에서 증발한다.**
##   에러도 화면 변화도 없다. 이 검사가 그 위험의 유일한 그물이다.
##
## 🔴 **세 가지를 한 번의 훑기로 잰다**: 합 · 물 칸 수 · 최대 양.
##  · 합    ⇒ 새나
##  · 칸 수 ⇒ **훑은 사각형 밖으로 샜나**(`count_material` 과 맞댄다 — 독립 경로다)
##  · 최대 ⇒ `_aux` 가 255를 넘어 **하위 8비트로 잘렸나**
func _water_total_is_conserved(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 400, 300, 400, Mat.STONE))
	var poured := 0
	# 여러 높이 · 여러 열에 붓는다. 한 기둥만 쓰면 「한 줄에서만 맞다」를 못 가른다.
	for x in range(20, 60):
		for k in 3:
			var amount := 60 + (x % 7) * 20 + k * 10
			if g.set_water(x, 350 + k * 5, amount):
				poured += amount
	t.ok(poured > 0, "물을 부었다 (%d, 검사의 전제)" % poured)

	var before := _water_scan(g, 0, 0, 300, 420)
	t.eq(before[0], poured, "붓기 직후 합이 부은 양과 같다")
	t.eq(before[1], g.count_material(Mat.WATER), "붓기 직후 사각형 밖에 물이 없다")

	for _i in 200:
		g.step()

	var after := _water_scan(g, 0, 0, 300, 420)
	t.eq(after[0], poured, "200틱 뒤에도 총량이 정확히 같다")
	t.eq(after[1], g.count_material(Mat.WATER), "200틱 뒤에도 사각형 밖으로 안 샜다")
	t.ok(after[2] <= Tuning.WATER_MAX, "어떤 칸도 최대량을 안 넘는다 (최대 %d)" % after[2])
	# 🔴 **실제로 움직였다는 증거.** 안 움직였어도 총량은 맞으므로, 이게 없으면 위 둘이 헛돈다.
	t.ok(after[1] < before[1], "물이 실제로 아래로 모였다 (칸 수 %d → %d)" % [before[1], after[1]])


## 🔴🔴 **단계 2의 심장.** 좌우가 없으므로 평형이 **진짜로 0**이 된다 —
##  기획이 「여기서 0이 안 나오면 단계 3으로 가지 마라」고 적은 자리다.
## ⚠ **「물이 안 움직인다」로는 못 잰다.** 안 움직이는데 안 자는 것이 v1이었다.
func _settled_water_sleeps(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 500, 200, 500, Mat.STONE))
	g.apply(CellGrid.cmd_fill(39, 460, 39, 499, Mat.STONE))
	g.apply(CellGrid.cmd_fill(80, 460, 80, 499, Mat.STONE))
	# 🔴🔴 **여러 층을 부어야 한다.** 한 층만 부으면 쌓인 물 위에 물이 없어서
	#  `_water_fall` 의 「아래가 꽉 찼다(`space <= 0`)」 가지를 **한 번도 안 지난다** —
	#  그 조기 탈출을 지워도 이 검사가 초록이었다(2026-08-07에 확인했다).
	#  ⚠ 지우면 꽉 찬 칸끼리 매 틱 **양이 안 바뀌는 쓰기**를 주고받으며 청크를 영영 깨운다.
	for x in range(40, 80):
		for k in 3:
			g.set_water(x, 470 + k, Tuning.WATER_MAX)
	# ⚠ 벽 사이 40열에 3층을 부었으므로 평형은 정확히 3층이다 — 아래 「꽉 찬 채로 남아 있다」의 근거.
	g.step()

	# 떨어지는 동안에는 깨어 있어야 한다 — 안 그러면 아래 0이 「처음부터 아무 일도 없었다」다.
	t.ok(g.active_chunk_count() > 0, "떨어지는 동안 활성 청크가 0이 아니다 (%d개)" % g.active_chunk_count())

	var ticks := 0
	while g.active_chunk_count() > 0 and ticks < 400:
		g.step()
		ticks += 1
	t.eq(g.active_chunk_count(), 0, "다 쌓이면 활성 청크가 0이 된다 (%d틱)" % ticks)
	t.eq(_band_sum(g), 0, "밴드 요약 합도 0이다")

	# 🔴 **그리고 계속 0이어야 한다.** 한 틱만 0인 것은 평형이 아니다.
	for _i in 50:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 50틱을 더 돌려도 0이다")
	# 🔴 **세 층이 실제로 꽉 찬 채 겹쳐 있다** — 이게 「아래가 꽉 찼다」 가지를 매 틱 지나는
	#  형태이고, 그런데도 잠든다는 것이 이 검사의 요점이다.
	for k in 3:
		t.eq(g.aux_at(60, 499 - k), Tuning.WATER_MAX,
			"바닥에서 %d칸 위가 꽉 찬 채로 남아 있다" % (k + 1))


## 🔴🔴 **청크 경계의 「보이지 않는 벽」.** 잠든 물 **바로 아래**를 파는데 그 아래가 **다음 밴드**면,
##  판 칸의 청크만 깨어나고 **물이 든 밴드는 잠든 채**라 순회가 통째로 건너뛴다.
##
## ⚠ **원본 코드에서 실제로 났다**(2026-08-07, verify-read2 · 뮤테이션 없이):
##  물이 y=335에 `aux=255` 인 채 **10틱 뒤에도 공중에 떠 있었다.** 에러 0.
## 🔴 **폭발·파기·다 탄 나무가 전부 이 경로다** — 물기둥 바닥의 y가 16의 배수 −1일 때 걸리므로
##  **대략 16번에 1번**이다. 화면엔 「공중에 뜬 물」로만 보인다.
##
## 🔴 **대조군을 같이 잰다.** 같은 청크 안에서 판 경우는 늘 동작하므로, 그것만 재면
##  「물이 떨어진다」가 초록인 채 경계만 조용히 죽는다.
func _digging_below_a_chunk_edge_wakes_the_water(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	# 밴드 20의 **마지막 행** = 청크 경계 바로 위.
	var y_edge := 21 * cc - 1
	t.eq(y_edge / cc, 20, "물이 밴드 20의 마지막 행에 있다")
	t.eq((y_edge + 1) / cc, 21, "그 바로 아래가 밴드 21이다 — 이 검사의 전제")

	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(90, y_edge + 1, 110, y_edge + 4, Mat.STONE))
	# 🔴 좌우를 막는다 — 재는 것은 **아래로 흘러드나**이고, 옆으로 새면 그 축이 흐려진다.
	g.apply(CellGrid.cmd_fill(99, y_edge, 99, y_edge, Mat.STONE))
	g.apply(CellGrid.cmd_fill(101, y_edge, 101, y_edge, Mat.STONE))
	g.set_water(100, y_edge, Tuning.WATER_MAX)
	# 🔴🔴 **먼저 한 틱을 돌려야 한다.** 커맨드는 `_dirty` 만 찍으므로 flip 전에는
	#  `active_chunk_count()` 가 **0이다** — 그냥 `while active > 0` 로 시작하면 루프가
	#  **한 번도 안 돌고** 아래 「잠들었다」가 공짜로 통과한다.
	#  ⚠ 실제로 그렇게 짰다가 뮤테이션이 안 물어서 알았다(2026-08-07). 검사가 헛돌고 있었다.
	var settle := _settle(g, 20)
	t.ok(settle > 1, "물이 실제로 떨어지는 동안 깨어 있었다 (%d틱 — 루프가 헛돌지 않았다)" % settle)
	t.eq(g.active_chunk_count(), 0, "돌 위에 얹힌 물이 먼저 잠든다 (%d틱)" % settle)
	t.eq(g.aux_at(100, y_edge), Tuning.WATER_MAX, "물은 그 자리에 있다")

	# 🔴 **물 바로 아래만 판다.** 물 칸은 안 건드린다 — 건드리면 물의 청크가 제 손으로 깨어나
	#  이 검사가 통째로 헛돈다.
	g.apply(CellGrid.cmd_fill(100, y_edge + 1, 100, y_edge + 1, Mat.EMPTY))
	for _i in 10:
		g.step()
	t.eq(g.aux_at(100, y_edge), 0, "10틱 뒤 물이 원래 자리에 없다 (공중에 안 떠 있다)")
	t.eq(g.aux_at(100, y_edge + 1), Tuning.WATER_MAX, "판 자리로 내려왔다")

	# 대조군 — 같은 청크 안에서 파면 원래도 됐다. 둘이 갈리는 것이 이 버그의 모양이다.
	var h := CellGrid.new()
	var y_mid := 21 * cc + 5
	t.eq(y_mid / cc, (y_mid + 1) / cc, "대조군은 위아래가 같은 밴드다 (전제)")
	h.apply(CellGrid.cmd_fill(90, y_mid + 1, 110, y_mid + 4, Mat.STONE))
	h.apply(CellGrid.cmd_fill(99, y_mid, 99, y_mid, Mat.STONE))
	h.apply(CellGrid.cmd_fill(101, y_mid, 101, y_mid, Mat.STONE))
	h.set_water(100, y_mid, Tuning.WATER_MAX)
	var h_settle := _settle(h, 20)
	# 🔴 **511과 같은 줄이다.** 없으면 이 대조군이 나중에 헛돌게 돼도 `(1틱)` 이라고 찍고 통과한다 —
	#  대조군이 죽으면 위 경계 검사의 「갈린다」가 통째로 뜻을 잃는다.
	t.ok(h_settle > 1, "대조군도 실제로 떨어지는 동안 깨어 있었다 (%d틱)" % h_settle)
	t.eq(h.active_chunk_count(), 0, "대조군도 먼저 잠든다 (%d틱)" % h_settle)
	h.apply(CellGrid.cmd_fill(100, y_mid + 1, 100, y_mid + 1, Mat.EMPTY))
	for _i in 10:
		h.step()
	t.eq(h.aux_at(100, y_mid + 1), Tuning.WATER_MAX, "대조군도 내려온다 (같은 청크 안)")


## 🔴🔴 **`cmd_fill` 로는 물을 못 놓는다.** 그 문은 `_write_cell` 을 지나 `_aux` 를 0으로 만들고,
##  그러면 **재료는 WATER인데 양이 0인 칸**이 선다 — `cell_materials.gd` 의 `_aux` 절이
##  「원리적으로 없다」고 못 박은 상태다.
## ⚠ 실측(2026-08-07, verify-read2): 그렇게 놓은 물 55칸이 **20틱 뒤 0개**다. 조용히 증발한다.
## 🔴 **곧 실제로 밟는다** — 맵에 물을 두는 날 지형 굽기가 이 경로를 쓴다. 그래서 짖게 해 뒀다.
func _cmd_fill_refuses_water(t) -> void:
	var g := CellGrid.new()
	t.expect_error("CellGrid: 물은 cmd_fill 로 못 놓는다")
	g.apply(CellGrid.cmd_fill(10, 695, 20, 699, Mat.WATER))
	t.eq(g.count_material(Mat.WATER), 0, "cmd_fill 이 물을 한 칸도 안 놓는다")
	t.eq(g.mat_at(15, 697), Mat.EMPTY, "그 자리가 빈칸 그대로다")

	# 🔴 **거절이 「양 0짜리 물」보다 낫다는 것이 요점이다.** 물의 문으로는 여전히 놓인다.
	t.ok(g.set_water(15, 697, 128), "같은 자리에 물의 문으로는 놓인다")
	t.eq(g.aux_at(15, 697), 128, "양이 실제로 들어간다")


## 🔴🔴 **시뮬은 도는데 화면이 안 바뀐다 — CLAUDE.md 의 대표 가짜.**
##  `_changed` 가 「화면을 다시 올리나」의 단일 소스인데 **`net_water` 가 한 번도 안 봤다** ⇒
##  `_write_water` 의 `_changed += 1` 을 지워도 전 그물이 초록이었다(2026-08-07에 확인했다).
## ⚠ **반대쪽도 같이 잰다** — 늘 0이 아닌 값을 주면 그건 「매 프레임 전부 다시 올린다」라
##  또 다른 고장이고, 그쪽은 성능으로만 드러난다.
func _water_moves_mark_the_screen_dirty(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 700, 100, 700, Mat.STONE))
	g.set_water(50, 690, Tuning.WATER_MAX)
	g.consume_changed()  # 놓기까지의 몫을 걷어낸다

	g.step()
	# ⚠ **「한 칸」이라고 못 박지 않는다** — `WATER_SUBSTEPS` 가 낙하 거리를 정하고, 여기서 재는
	#  것은 거리가 아니라 `_changed` 다. 거리는 `_water_falls_per_tick` 이 따로 잰다.
	t.eq(g.aux_at(50, 690), 0, "물이 실제로 그 자리를 떠났다 (전제)")
	t.eq(g.count_material(Mat.WATER), 1, "그리고 한 칸 그대로다 (복제되지도 사라지지도 않았다)")
	t.ok(g.consume_changed() > 0, "물이 움직인 틱은 화면을 다시 올리라고 표시한다")

	# 다 쌓여 잠든 뒤에는 0이어야 한다.
	# 🔴🔴 **상한이 있어야 한다.** 물이 안 멈추면 **실패가 아니라 러너가 영원히 매달린다** —
	#  단언 하나가 빨개지는 것과 그물 전체가 안 끝나는 것은 다른 사고다.
	#  ⚠ **바로 다음 단계에 그 조건이 온다**: 기획이 「단계 3의 넓은 물은 원리적으로 안 멈춘다」고
	#   적어 뒀다(폭 128셀은 4,000틱에도 평형이 안 난다). ⇒ 닿으면 **실패로 떨어뜨린다.**
	var settle := _settle(g, 200)
	t.ok(settle < 200, "물이 상한 안에 잠든다 (%d틱 — 닿으면 안 멈춘 것이다)" % settle)
	g.consume_changed()
	for _i in 10:
		g.step()
	t.eq(g.consume_changed(), 0, "잠든 뒤에는 화면을 안 건드린다")


## 🔴 **격자 맨 아래 행.** `_water_step` 의 `y < H - 1` 가드가 없으면 `below` 가 격자를 넘어
##  **매 틱 엔진 「Index out of bounds」**가 난다 — 그건 단언에 안 잡히는 침묵사고, 래퍼만 잡는다.
## ⚠ 그물이 물을 y=600대까지만 놓고 있어서 이 가드가 **한 번도 안 밟혔다**(2026-08-07).
func _bottom_row_water_is_safe(t) -> void:
	var g := CellGrid.new()
	var last := CellGrid.H - 1
	# 🔴 좌우를 막는다(단계 3부터) — 재는 것은 **아래 경계**이지 확산이 아니다.
	g.apply(CellGrid.cmd_fill(299, last - 3, 299, last, Mat.STONE))
	g.apply(CellGrid.cmd_fill(301, last - 3, 301, last, Mat.STONE))
	t.ok(g.set_water(300, last, Tuning.WATER_MAX), "격자 맨 아래 행에 물을 놓는다")
	t.ok(g.set_water(300, last - 1, Tuning.WATER_MAX), "그 바로 위에도 놓는다")
	for _i in 20:
		g.step()
	# 🔴 아래로 갈 곳이 없으므로 그대로 있어야 한다. 격자 밖으로 새면 총량이 준다.
	t.eq(g.aux_at(300, last), Tuning.WATER_MAX, "맨 아래 물이 격자 밖으로 안 샌다")
	t.eq(g.aux_at(300, last - 1), Tuning.WATER_MAX, "위 칸도 그대로다 (아래가 꽉 찼다)")
	t.eq(g.active_chunk_count(), 0, "그리고 잠든다")


## 🔴🔴 **파면에 탈 수 없는 재료가 앉아 있나.** 물과 불이 같은 칸에서 만나는 것을 막는 불변량이고,
##  **단계 6의 전제**다.
## ⚠ **`claimed == burning` 으로는 원리적으로 못 잡는다** — 그 둘은 서로만 맞대므로 물 칸이
##  파면 소속을 주장해도 두 수가 같다. 그때 `_burn` 이 **물의 양을 연료로 먹는다**
##  (255 → 250 → 245 …, verify-read2 실측). 물이 조용히 마른다.
func _front_has_no_unburnable(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 800, 200, 800, Mat.STONE))
	g.apply(CellGrid.cmd_fill(100, 799, 120, 799, Mat.WOOD))
	for x in range(100, 121):
		g.ignite(x, 799)
	t.ok(g.burning_count() > 0, "나무가 탄다 (전제)")
	t.eq(g.unburnable_in_front_count(), 0, "붙인 직후 파면에 탈 수 없는 재료가 없다")

	# 🔴🔴 **가드의 「결과」를 잰다. 반환값만 보면 안 된다.**
	#  `set_water` 가 false 를 돌려주는 것을 보는 검사는 위에 이미 있다(`_water_door_refuses_bad_targets`).
	#  ⚠ 그건 **「거절했다」만 재고 「거절 안 했으면 뭐가 나쁜가」는 안 잰다** — 가드를 지우면
	#   그 검사는 빨개지지만 **파면이 실제로 오염되는 것은 아무도 안 본다.**
	#  🔴 여기서 오염 자체를 값으로 잰다: 물 칸이 파면에 앉으면 `_burn` 이 **물의 양을 연료로 먹는다.**
	var fuel_before := g.fuel_at(100, 799)
	t.ok(fuel_before > 0, "타는 칸에 연료가 있다 (전제)")
	g.set_water(100, 799, Tuning.WATER_MAX)
	t.eq(g.unburnable_in_front_count(), 0, "타는 칸에 물을 놓으려 해도 파면이 안 오염된다")
	t.eq(g.mat_at(100, 799), Mat.WOOD, "그 칸은 여전히 나무다")
	g.step()
	t.eq(g.unburnable_in_front_count(), 0, "한 틱 뒤에도 파면에 탈 수 없는 재료가 없다")
	t.eq(g.fuel_at(100, 799), fuel_before - Tuning.FIRE_BURN_PER_TICK,
		"연료가 정상적으로 준다 (물의 양을 연료로 먹고 있지 않다)")

	# 타는 나무 위로 물을 붓는다 — 두 축이 만날 수 있는 유일한 자리다.
	for x in range(100, 121):
		g.set_water(x, 790, Tuning.WATER_MAX)
	# 🔴 **매 틱 본다.** 마지막 틱만 보면 「잠깐 들어갔다 빠졌다」를 놓치는데, 그 한 틱에
	#  `_burn` 이 이미 물의 양을 먹는다.
	var dirty_ticks := 0
	for _i in 30:
		g.step()
		if g.unburnable_in_front_count() != 0 or g.claimed_slot_count() != g.burning_count():
			dirty_ticks += 1
	t.eq(dirty_ticks, 0, "물이 불 위로 흐르는 30틱 내내 파면이 깨끗하다")

	t.eq(g.unburnable_in_front_count(), 0, "물이 타는 자리에 닿아도 파면에 물이 안 들어간다")
	t.eq(g.claimed_slot_count(), g.burning_count(), "그때 자리 표도 여전히 맞다")

	# 🔴 다 태운 뒤에도. 자기교환(`at == last`)이 도는 구간이다.
	for _i in 100:
		g.step()
	t.eq(g.unburnable_in_front_count(), 0, "다 탄 뒤에도 파면에 탈 수 없는 재료가 없다")


# ══════════════════════════════════════════════════════════════════
#  단계 3 — 좌우 나눔 · 한 틱 상한
# ══════════════════════════════════════════════════════════════════

## 그릇 하나를 만들고 한쪽에 물을 붓는다. `[격자, 부은 양]`.
func _make_bowl(width: int, y_floor: int, poured_cols: int, depth: int) -> Array:
	var g := CellGrid.new()
	var x0 := 200
	g.apply(CellGrid.cmd_fill(x0 - 1, y_floor, x0 + width, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x0 - 1, y_floor - 40, x0 - 1, y_floor, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x0 + width, y_floor - 40, x0 + width, y_floor, Mat.STONE))
	var poured := 0
	for k in poured_cols:
		for d in depth:
			if g.set_water(x0 + k, y_floor - 1 - d, Tuning.WATER_MAX):
				poured += Tuning.WATER_MAX
	return [g, poured]


## 🔴 **판정 2 — 계단이 아니라 수면이 되나.** 좌우 나눔이 실제로 도는지의 가장 직접적인 값이다.
## ⚠ **「퍼졌다」로는 부족하다** — 한쪽으로만 퍼져도 퍼진 것이다. **높이 차이**를 재야 한다.
func _water_lies_flat(t) -> void:
	var made := _make_bowl(32, 700, 8, 8)
	var g: CellGrid = made[0]
	var poured: int = made[1]

	var settle := _settle(g, 4000)
	t.ok(settle > 1 and settle < 4000, "폭 32 그릇이 상한 안에 평형에 든다 (%d틱)" % settle)

	# 수면 높이 = 열마다 물이 있는 가장 위 행.
	var lo := 1 << 30
	var hi := -1
	var dry := 0
	for k in 32:
		var top := -1
		for y in range(660, 700):
			if g.mat_at(200 + k, y) == Mat.WATER:
				top = y
				break
		if top < 0:
			dry += 1
			continue
		lo = mini(lo, top)
		hi = maxi(hi, top)
	# 🔴 **마른 열이 하나라도 있으면 눕지 않은 것이다.** 안 보면 「퍼진 8열만 평평하다」가
	#  통과하고, 그건 정확히 계단 모양이다.
	t.eq(dry, 0, "32열이 전부 젖는다 (한쪽에만 8열 부었다)")
	# 🔴 부은 양(8열 × 8칸)이 32열에 퍼지면 2칸 높이다. 수면이 **한 칸 안**이어야 눕는 것이다.
	t.ok(hi - lo <= 1, "수면이 평평하다 (가장 높은 곳과 낮은 곳의 차 %d칸)" % (hi - lo))
	t.eq(_water_scan(g, 190, 650, 240, 705)[0], poured, "그동안 총량이 정확히 보존된다")


## 🔴🔴 **`WATER_MIN_DIFF` 가 멈춤의 심장인가.** 0으로 두면 홀수가 영원히 안 나눠져
##  1씩 왕복하고 **청크가 절대 안 잠든다** — v1이 죽은 자리다.
## ⚠ **이 검사는 「멈춘다」를 재는 게 아니라 「그 상수가 멈춤의 원인이다」를 잰다** —
##  값을 0으로 낮추면 빨개져야 하고, 그게 손잡이가 진짜 손잡이라는 뜻이다.
func _min_diff_stops_the_shuffling(t) -> void:
	t.ok(Tuning.WATER_MIN_DIFF > 0,
		"차이 하한이 0보다 크다 (0이면 1씩 왕복하며 청크가 영영 안 잠든다)")

	# 이웃과의 차이가 하한 이하인 두 칸은 **한 톨도** 안 움직여야 한다.
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(400, 800, 410, 800, Mat.STONE))
	# 🔴🔴 **두 칸을 벽으로 가둬야 한다.** 옆이 빈칸이면 차이가 255라 하한과 **무관하게** 퍼지고,
	#  그러면 이 검사는 하한을 재는 게 아니라 확산을 재는 것이 된다.
	g.apply(CellGrid.cmd_fill(403, 795, 403, 799, Mat.STONE))
	g.apply(CellGrid.cmd_fill(406, 795, 406, 799, Mat.STONE))
	g.set_water(404, 799, 100)
	g.set_water(405, 799, 100 + Tuning.WATER_MIN_DIFF)
	g.step()
	g.step()
	t.eq(g.aux_at(404, 799), 100, "차이가 하한과 같으면 왼쪽이 그대로다")
	t.eq(g.aux_at(405, 799), 100 + Tuning.WATER_MIN_DIFF, "오른쪽도 그대로다")
	t.eq(g.active_chunk_count(), 0, "그래서 그 청크가 잠든다")

	# 하한을 한 톨 넘으면 움직인다 — 반대쪽을 같이 재야 「아무것도 안 움직인다」와 안 헷갈린다.
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(400, 800, 410, 800, Mat.STONE))
	h.apply(CellGrid.cmd_fill(403, 795, 403, 799, Mat.STONE))
	h.apply(CellGrid.cmd_fill(406, 795, 406, 799, Mat.STONE))
	h.set_water(404, 799, 100)
	h.set_water(405, 799, 100 + Tuning.WATER_MIN_DIFF + 2)
	h.step()
	h.step()
	t.ok(h.aux_at(404, 799) > 100, "하한을 넘으면 실제로 옮겨진다 (%d)" % h.aux_at(404, 799))


## 🔴🔴 **열 경계의 「보이지 않는 벽」.** 행 경계와 같은 사고이고 **훨씬 자주 걸린다** —
##  좌우 나눔이 붙은 지금 처음으로 잴 수 있다.
## ⚠ verify-run이 단계 2에서 「대각 경로가 없다」를 확인했지만 **그건 아래로만 가던 때의 결론이다.**
func _column_edge_wakes_the_neighbour(t) -> void:
	var cc := Tuning.CHUNK_CELLS
	# 청크 열 25의 **마지막 칸**에 물, 그 오른쪽(청크 열 26의 첫 칸)은 막혀 있다.
	var x_edge := 26 * cc - 1
	t.eq(x_edge / cc, 25, "물이 청크 열 25의 마지막 칸에 있다")
	t.eq((x_edge + 1) / cc, 26, "그 오른쪽이 청크 열 26이다 — 이 검사의 전제")

	var g := CellGrid.new()
	var y := 850
	g.apply(CellGrid.cmd_fill(x_edge - 4, y + 1, x_edge + 6, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x_edge + 1, y, x_edge + 1, y, Mat.STONE))  # 오른쪽 벽
	# 🔴 왼쪽도 막는다. 안 막으면 물이 그쪽으로 새고, 그러면 **뚫기 전에 이미 청크가 깨어 있어**
	#  아래 「경계 너머로 흘러든다」가 무엇 때문인지 못 가른다.
	g.apply(CellGrid.cmd_fill(x_edge - 1, y, x_edge - 1, y, Mat.STONE))
	g.set_water(x_edge, y, Tuning.WATER_MAX)
	var settle := _settle(g, 60)
	t.ok(settle > 1, "물이 먼저 자리를 잡는다 (%d틱 — 루프가 헛돌지 않았다)" % settle)
	t.eq(g.active_chunk_count(), 0, "그리고 잠든다")

	# 🔴 **벽만 뚫는다.** 물 칸은 안 건드린다 — 건드리면 물의 청크가 제 손으로 깨어난다.
	g.apply(CellGrid.cmd_fill(x_edge + 1, y, x_edge + 1, y, Mat.EMPTY))
	for _i in 20:
		g.step()
	t.ok(g.aux_at(x_edge + 1, y) > 0 or g.aux_at(x_edge + 1, y + 1) > 0,
		"청크 열 경계 너머로 물이 흘러든다 (보이지 않는 벽이 없다)")
	t.ok(g.aux_at(x_edge, y) < Tuning.WATER_MAX, "그만큼 원래 칸이 줄었다")


## 🔴🔴 **판정 1-a — 좁은 물은 진짜로 활성 청크 0이 되나.**
##  ⚠ **판정 1-b와 다른 검사다. 묶으면 라벨이 재는 것보다 넓어진다**(기획이 그렇게 갈랐다).
## ⚠ 기획의 「폭 32 · MIN_DIFF 16 ⇒ 약 2,800틱」은 **spec의 대리 구현** 값이고 지금 `MIN_DIFF` 는 4다.
##  ⇒ **틱 수를 단언하지 않는다** — 재는 것은 **0이 되나**이고, 실제 틱 수는 라벨에 찍는다.
func _narrow_bowl_reaches_zero(t) -> void:
	var made := _make_bowl(32, 750, 8, 6)
	var g: CellGrid = made[0]
	var poured: int = made[1]

	var ticks := _settle(g, 6000)
	t.ok(ticks > 1 and ticks < 6000, "폭 32 그릇의 활성 청크가 0이 된다 (%d틱)" % ticks)
	t.eq(g.active_chunk_count(), 0, "정말 0이다")
	t.eq(_band_sum(g), 0, "밴드 요약 합도 0이다")

	# 🔴 **그리고 계속 0이어야 한다.** 한 틱만 0인 것은 평형이 아니다.
	for _i in 50:
		g.step()
	t.eq(g.active_chunk_count(), 0, "그 뒤 50틱을 더 돌려도 0이다")
	t.eq(_water_scan(g, 190, 700, 240, 755)[0], poured, "총량이 보존된다")


## 🔴🔴 **판정 1-b — 넓은 물은 0이 안 된다. 대신 활성 청크가 한 자리로 잠긴다.**
##
## ⚠ **이게 「실패」로 읽히면 안 된다.** 반씩 나누는 규칙은 확산이라 평평해지는 데 폭의 제곱에
##  비례하는 시간이 들고, **총량은 정확히 보존된다 — 새는 게 아니라 안 끝나는 것이다.**
## 🔴 **실패인 경우는 둘뿐이다**: 총량이 새거나, 활성 청크가 **계속 느는** 것.
##  ⇒ 여기서 재는 것도 정확히 그 둘이다.
func _wide_bowl_settles_under_the_cap(t) -> void:
	var made := _make_bowl(128, 900, 32, 8)
	var g: CellGrid = made[0]
	var poured: int = made[1]

	g.step()
	var late := 0
	var peak := 0
	for i in 1200:
		g.step()
		var a := g.active_chunk_count()
		peak = maxi(peak, a)
		if i >= 1100:
			late = maxi(late, a)

	t.ok(peak > 0, "넓은 물은 도는 내내 깨어 있다 (최대 %d청크)" % peak)
	# 🔴🔴 **재는 것은 「는가」가 아니라 「경계 안에 갇히나」다.**
	#  ⚠ 인접한 두 구간의 최대값을 맞대는 것은 **잡음을 성장으로 읽는다** — 실측으로 9 ↔ 10 을
	#   오가고, 그건 성장이 아니라 표면 띠가 출렁이는 것이다. 그렇게 짰다가 빨개졌다(2026-08-07).
	#  🔴 진짜 실패는 **경계 없이 느는 것**이고, 그건 고정 상한으로 잡힌다.
	#   기획 실측은 폭 128에서 최대 16~18이었다 ⇒ 32면 두 배 여유다.
	t.ok(late <= 32, "1,100틱 뒤에도 활성 청크가 32 아래에 갇힌다 (최대 %d)" % late)
	t.ok(peak < 64, "도는 내내도 64 아래다 (최대 %d, 상한 %d 훨씬 아래)" % [
		peak, Tuning.MAX_CHUNKS_PER_TICK])
	# 🔴 **총량이 이 판정의 나머지 절반이다** — 안 멈추는 것은 괜찮지만 새는 것은 아니다.
	t.eq(_water_scan(g, 190, 850, 340, 905)[0], poured, "1,200틱 뒤에도 총량이 정확히 같다")


## 🔴🔴 **좌우 편향 — dir 뒤집기가 실제로 도나.** v1이 이 그물을 갖고 있었다.
##
## ⚠ **대칭 지형 · 대칭 투입이어야 한다.** 한쪽이라도 안 대칭이면 이 검사는 아무것도 안 잰다.
## 🔴 **틱 수를 짝수로 끊는다** — dir 이 매 틱 뒤집히므로 홀수에서 끊으면 마지막 한 틱의
##  방향이 남아 **편향이 없어도 좌우가 다르다.** 그건 고장이 아니라 재는 방법이 틀린 것이다.
func _left_right_has_no_bias(t) -> void:
	var g := CellGrid.new()
	var cx := 600
	var y := 950
	g.apply(CellGrid.cmd_fill(cx - 40, y + 1, cx + 40, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(cx - 41, y - 20, cx - 41, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(cx + 41, y - 20, cx + 41, y + 1, Mat.STONE))
	# 한가운데 한 열에만 붓는다 — 좌우로 정확히 대칭인 유일한 투입이다.
	var poured := 0
	for d in 12:
		g.set_water(cx, y - d, Tuning.WATER_MAX)
		poured += Tuning.WATER_MAX

	for _i in 400:
		g.step()

	var left: int = _water_scan(g, cx - 41, y - 30, cx - 1, y + 1)[0]
	var right: int = _water_scan(g, cx + 1, y - 30, cx + 41, y + 1)[0]
	var mid: int = _water_scan(g, cx, y - 30, cx, y + 1)[0]
	t.ok(left + right + mid == poured, "총량이 보존된다 (좌 %d + 중 %d + 우 %d)" % [left, mid, right])
	t.ok(left > 0 and right > 0, "양쪽으로 다 퍼졌다 (좌 %d · 우 %d)" % [left, right])
	# 🔴🔴 **「좌우가 정확히 같다」는 이 규칙으로 원리적으로 안 나온다. 기획의 그 문장이 틀렸다.**
	#  한 칸에서 dir 쪽을 **먼저** 나누고 **그 결과로 줄어든 양**을 반대쪽에 나누므로 한 틱 안의
	#  좌우가 대칭이 아니다. dir 이 매 틱 뒤집혀도 `diff >> 1` 이 **내림**이라 반올림 잔돈이 남고,
	#  그건 정확히 상쇄되지 않는다. ⚠ 실측 차이는 3,060 중 **1**이다(0.03%).
	# 🔴 **그래서 재는 것은 「편향」이지 「동일」이 아니다.** 편향이면 차이가 물 한 칸 값을 넘고
	#  틱이 늘수록 커진다 — 아래 임계가 그 둘을 가른다.
	# ⚠ **임계를 0으로 좁히지 마라.** 초록으로 만들 수 없고, 그러면 다음 사람이 이 검사를 지운다.
	t.ok(absi(left - right) <= Tuning.WATER_MAX,
		"좌우 편향이 없다 (차이 %d — 물 한 칸 %d 아래면 반올림 잔돈이다)" % [
			absi(left - right), Tuning.WATER_MAX])


## 🔴🔴 **한 틱 상한 — 미는 것이지 버리는 것이 아니다.**
##  ⚠ 버리면 「물이 사라진다」이고 그건 안전망이 아니라 고장이다. 총량으로 잰다.
## 🔴 **상한에 실제로 닿게 만들어야 한다** — 안 닿으면 이 검사가 통째로 헛돈다.
##  `cmd_fill` 로 넓게 깔면 `_write_cell` 이 수천 청크를 찍는다(기획 「위험」의 R 항목).
func _tick_cap_delays_but_never_drops(t) -> void:
	var g := CellGrid.new()
	# 상한(512)을 훌쩍 넘는 지형을 깐다.
	g.apply(CellGrid.cmd_fill(0, 100, 2047, 500, Mat.STONE))
	g.step()
	# 🔴 **상한이 실제로 물렸다는 증거.** 이게 없으면 아래가 아무것도 안 잰다.
	t.eq(g.active_chunk_count(), Tuning.MAX_CHUNKS_PER_TICK,
		"깨어 있는 청크가 상한에서 정확히 잘린다")

	# 🔴 **잘린 것이 사라지지 않는다** — 다음 틱에도 상한만큼 깨어 있어야 한다.
	g.step()
	t.ok(g.active_chunk_count() > 0, "다음 틱에도 깨어 있다 (잘린 청크가 버려지지 않았다)")

	# 그리고 결국 전부 처리되고 잠든다.
	var ticks := _settle(g, 200)
	t.ok(ticks < 200, "밀린 청크가 결국 다 처리되고 잠든다 (%d틱)" % ticks)

	# 상한 아래에서는 안 자른다 — 반대쪽을 재야 「늘 자른다」와 안 헷갈린다.
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(0, 100, 100, 120, Mat.STONE))
	h.step()
	t.ok(h.active_chunk_count() < Tuning.MAX_CHUNKS_PER_TICK,
		"작은 지형은 상한에 안 걸린다 (%d청크)" % h.active_chunk_count())

	# 🔴 물이 상한에 걸려도 총량이 보존된다 — 안전망의 계약 그 자체다.
	var w := CellGrid.new()
	w.apply(CellGrid.cmd_fill(0, 600, 2047, 600, Mat.STONE))
	# 🔴 오른쪽 벽. 없으면 물이 바닥 끝을 지나 **검사 사각형 밖으로** 나가고, 그건 「샜다」와
	#  구별이 안 된다 — 안 새는데 빨개지면 다음 사람이 검사를 지운다.
	w.apply(CellGrid.cmd_fill(2048, 560, 2048, 600, Mat.STONE))
	var poured := 0
	for x in range(0, 2048, 4):
		if w.set_water(x, 599, Tuning.WATER_MAX):
			poured += Tuning.WATER_MAX
	for _i in 60:
		w.step()
	t.eq(_water_scan(w, 0, 540, 2047, 601)[0], poured, "상한에 걸리는 동안에도 총량이 보존된다")


## 결정론 — 같은 커맨드 열이 같은 격자를 만드나(물은 멀티에서 각자 계산한다).
##
## ⚠🔴 **이 검사가 재는 것은 좁다. 라벨을 넓게 읽지 마라.**
##  같은 프로세스에서 같은 코드를 두 번 돌리면 **틀린 순서도 똑같이 틀리므로 늘 같은 답이 나온다.**
##  ⇒ 잡는 것은 「상태가 아닌 것에 기댔나」(딕셔너리 해시 순서 · 객체 주소 · 시계 · 난수)뿐이고,
##   **「자르는 순서가 틀렸다」는 원리적으로 못 잡는다.**
## 🔴 **그건 `net_determinism` 의 텍스트 스캔과 위 상한 검사가 나눠서 맡는다** —
##  상한이 **청크 단위로** 잘리는 것은 `active_chunk_count() == MAX_CHUNKS_PER_TICK` 이 고정하고,
##  「한 청크의 행 절반만 돈다」는 **`_awake` 를 청크마다 읽는 순회 구조 자체**가 막는다(구조 논증이다).
## ⚠ **구조 논증이라는 말은 그물이 없다는 뜻이다.** 순회를 고치는 사람이 여기를 읽어야 한다.
func _same_commands_give_the_same_grid(t) -> void:
	var a := _run_scenario()
	var b := _run_scenario()
	# 🔴 **`_aux` 전체를 바이트로 맞댄다.** 한 칸만 달라도 그 뒤로 두 세상이 영영 갈린다.
	var diff := 0
	for y in range(560, 640):
		for x in range(150, 350):
			if a.aux_at(x, y) != b.aux_at(x, y) or a.mat_at(x, y) != b.mat_at(x, y):
				diff += 1
	t.eq(diff, 0, "같은 커맨드 열이 같은 격자를 만든다")
	t.eq(a.active_chunk_count(), b.active_chunk_count(), "활성 청크 수도 같다")
	t.ok(_water_scan(a, 150, 560, 350, 640)[0] > 0, "그 안에 물이 실제로 있다 (검사의 전제)")


func _run_scenario() -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(150, 620, 350, 620, Mat.STONE))
	for k in 40:
		g.set_water(200 + k, 600, Tuning.WATER_MAX)
	for i in 60:
		g.step()
		if i == 20:
			g.apply(CellGrid.cmd_blast(250, 620, 6, 9))
		if i == 40:
			g.apply(CellGrid.cmd_carve(220, 618, 4))
	return g


## 🔴🔴 **`_band_awake` 가 살아 있나 — 시간으로만 잴 수 있다.**
##
## ⚠ **구조로는 못 잡는다.** 요약과 직접 센 값을 맞대는 검사는 **갈라짐**만 잡고,
##  `_band_awake`·`_band_dirty` 를 **통째로 죽이면 격자는 여전히 정확히 돈다** — 느려질 뿐이다.
##  ⇒ 실측으로 잠든 격자 `step()` 이 **5.25μs → 8,114μs(1,546배)** 가 된다. 그게 예산의 16%다.
##
## 🔴 **절대값으로 재지 않는다 — 기계마다 흔들린다.** 같은 기계에서 잰 **기준자와의 배수**로 잰다.
##  기준자는 `active_chunk_count()`(16,128칸 네이티브 count, 실측 2.25μs) — 기계가 빠르면 이것도
##  같이 빨라지므로 비율이 유지된다.
##
##      지금       잠든 step() / 기준자 ≈ 5.25 / 2.25 = **2.3배**
##      요약 없으면                    ≈ 8,114 / 2.25 = **3,600배**
##  ⇒ **임계 50배.** 지금보다 21배 위, 깨진 상태보다 72배 아래다. 양쪽에 여유가 충분하다.
## ⚠ 임계를 좁히지 마라 — 이 그물이 **흔들려서 꺼지는 것**이 `_band_awake` 가 죽는 것보다 나쁘다.
func _sleeping_grid_is_cheap(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 0, CellGrid.W - 1, CellGrid.H - 1, Mat.STONE))
	# ⚠ 16,128청크가 깨는데 한 틱 상한이 512라 **다 재우는 데 수십 틱이 든다.**
	#  고정 횟수로 두면 이 검사가 「안 잠든 격자」를 재게 된다.
	var calm := _settle(g, 500)
	t.ok(calm > 1 and calm < 500, "격자가 결국 다 잠든다 (%d틱)" % calm)
	t.eq(g.active_chunk_count(), 0, "격자가 완전히 잠들었다 (이 검사의 전제)")

	var n := 2000
	var t0 := Time.get_ticks_usec()
	for _i in n:
		g.active_chunk_count()
	var ref := Time.get_ticks_usec() - t0

	var t1 := Time.get_ticks_usec()
	for _i in n:
		g.step()
	var slept := Time.get_ticks_usec() - t1

	t.ok(ref > 0, "기준자가 잴 수 있는 시간을 낸다 (%dμs / %d회)" % [ref, n])
	t.ok(slept <= ref * 50,
		"잠든 격자 step() 이 기준자의 50배 아래다 (%dμs vs 기준 %dμs — %d배)" % [
			slept, ref, slept / maxi(ref, 1)])


# ══════════════════════════════════════════════════════════════════
#  단계 4 — 얕음 비트
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **양과 비트가 한 자리에서 움직이나.** 갈라지면 **화면에만** 나온다 —
##  시뮬은 양만 보고 셰이더는 비트만 보므로 서로를 안 고쳐 준다.
##
## 🔴 **경계값 양쪽을 다 잰다.** 「임계 이하면 켜진다」만 재면 **늘 켜는 구현**도 통과한다.
## ⚠ 임계값을 여기 박지 않는다 — `WATER_WET` 이 바뀌면 손으로 적은 숫자가 조용히 낡는다.
func _shallow_bit_tracks_the_amount(t) -> void:
	var wet := Tuning.WATER_WET
	t.ok(wet > 0 and wet < Tuning.WATER_MAX,
		"임계가 0과 최대량 사이다 (%d — 아니면 아래 두 쪽 중 하나가 원리적으로 안 나온다)" % wet)
	# 🔴 두 비트가 안 겹친다 — 겹치면 「얕은 물」과 「타는 칸」이 화면에서 같은 칸이 된다.
	t.eq(Mat.FLAG_SHALLOW & Mat.FLAG_BURNING, 0, "얕음 비트와 불 비트가 안 겹친다")
	t.ok(Mat.FLAG_SHALLOW < 16, "얕음 비트가 하위 4비트 안이다 (L8 정밀도 안전선)")

	var g := CellGrid.new()
	# 경계 **바로 위**: 얕지 않다.
	g.set_water(500, 100, wet + 1)
	t.eq(g.flag_at(500, 100) & Mat.FLAG_SHALLOW, 0, "임계보다 한 톨 많으면 얕음이 꺼져 있다")
	# 경계 **정확히**: 얕다(「이하」가 계약이다).
	g.set_water(501, 100, wet)
	t.eq(g.flag_at(501, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "임계와 같으면 얕음이 켜진다")
	g.set_water(502, 100, 1)
	t.eq(g.flag_at(502, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "한 톨만 있어도 얕음이다")
	g.set_water(503, 100, Tuning.WATER_MAX)
	t.eq(g.flag_at(503, 100) & Mat.FLAG_SHALLOW, 0, "꽉 찬 칸은 안 얕다")

	# 🔴 **넘나들면 따라 뒤집힌다.** 한 번만 재면 「처음에만 맞다」를 못 가른다.
	g.set_water(504, 100, Tuning.WATER_MAX)
	t.eq(g.flag_at(504, 100) & Mat.FLAG_SHALLOW, 0, "깊게 시작한다")
	g.set_water(504, 100, wet)
	t.eq(g.flag_at(504, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "얕아지면 켜진다")
	g.set_water(504, 100, Tuning.WATER_MAX)
	t.eq(g.flag_at(504, 100) & Mat.FLAG_SHALLOW, 0, "다시 깊어지면 꺼진다")

	# 🔴🔴 **비우는 쪽도 내려야 한다.** 안 내리면 빈칸이 비트를 든 채 남고, 다음에 그 칸이
	#  물이 될 때 양과 비트가 어긋난 채로 시작한다 — 화면에만 나온다.
	# ⚠ **반드시 「얕은 물」에서 비워야 잰다.** 깊은 물(비트가 이미 0)에서 비우면 지우는 줄을
	#  통째로 지워도 **초록**이다 — 2026-08-07까지 그렇게 짜여 있었고 뮤테이션이 안 물었다.
	g.set_water(505, 100, wet)
	t.eq(g.flag_at(505, 100) & Mat.FLAG_SHALLOW, Mat.FLAG_SHALLOW, "먼저 얕음을 켠다 (검사의 전제)")
	g.set_water(505, 100, 0)
	t.eq(g.mat_at(505, 100), Mat.EMPTY, "양 0이면 빈칸이 된다")
	t.eq(g.flag_at(505, 100), 0, "**켜져 있던** 얕음 비트가 빈칸에 안 남는다")

	# 🔴🔴 **직접 쓰기 말고 시뮬이 굴러서도 맞나.** `set_water` 만 재면 `_water_step` 이 지나는
	#  경로(`_water_fall`·`_water_share`)가 비트를 안 만져도 통과한다.
	# 🔴🔴 **벽으로 가둔 그릇이어야 두 깊이가 같이 나온다.** 열린 바닥에 부으면 물이 평형까지
	#  퍼져서 **전부 얕아진다** — 실제로 그렇게 짰다가 「깊은 칸 0개」로 빨개졌다(2026-08-07).
	#  ⇒ 폭 8 그릇에 **2층 + 나머지 16**이 되게 붓는다: 아래 두 줄은 255, 맨 윗줄은 16이다.
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(599, 200, 608, 200, Mat.STONE))
	h.apply(CellGrid.cmd_fill(599, 188, 599, 199, Mat.STONE))
	h.apply(CellGrid.cmd_fill(608, 188, 608, 199, Mat.STONE))
	for k in 16:
		h.set_water(600 + (k % 8), 195 - (k / 8), Tuning.WATER_MAX)
	h.set_water(600, 193, 128)
	var settle := _settle(h, 200)
	t.ok(settle > 1 and settle < 200, "부은 물이 흘러 정착한다 (%d틱)" % settle)

	var mismatched := 0
	var shallow_cells := 0
	var deep_cells := 0
	for y in range(185, 201):
		for x in range(600, 608):
			if h.mat_at(x, y) != Mat.WATER:
				# 물이 아닌 칸에 얕음 비트가 남아 있으면 그것도 어긋난 것이다.
				if (h.flag_at(x, y) & Mat.FLAG_SHALLOW) != 0:
					mismatched += 1
				continue
			var want := Mat.FLAG_SHALLOW if h.aux_at(x, y) <= wet else 0
			if (h.flag_at(x, y) & Mat.FLAG_SHALLOW) != want:
				mismatched += 1
			if want != 0:
				shallow_cells += 1
			else:
				deep_cells += 1
	t.eq(mismatched, 0, "흘러서 정착한 물의 양과 비트가 한 칸도 안 어긋난다")
	# 🔴 **양쪽이 실제로 나왔다는 증거.** 한쪽이 0이면 위 검사가 절반만 돈 것이다.
	t.ok(shallow_cells > 0, "얕은 칸이 실제로 생긴다 (%d칸 — 수면 쪽이다)" % shallow_cells)
	t.ok(deep_cells > 0, "깊은 칸도 남는다 (%d칸 — 그릇 속이다)" % deep_cells)


# ══════════════════════════════════════════════════════════════════
#  단계 5 — 물 룬
# ══════════════════════════════════════════════════════════════════

const SpellSim := preload("res://src/sim/spell_sim.gd")

## 🔴🔴 **`CMD_WATER` 는 `_write_cell` 을 지나면 안 된다.** 지나면 재료만 WATER 이고 **양이 0**인
##  칸이 생기고, 그 칸은 첫 순회에서 조용히 증발한다(`cmd_fill` 이 데인 자리와 같다).
## 🔴 **덮어쓰지 않고 채운다** — 얕은 값으로 깊은 물을 덮으면 **물 룬이 물을 줄인다.**
func _water_disc_fills_without_wiping(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_water(300, 300, 6, 200))
	var got := _water_scan(g, 280, 280, 320, 320)
	t.ok(got[1] > 0, "물 커맨드가 칸을 적신다 (%d칸)" % got[1])
	t.eq(got[2], 200, "양이 커맨드가 준 값 그대로 들어간다 (증발하지 않는다)")
	t.eq(g.aux_at(300, 300), 200, "한가운데도 200이다")
	# 🔴 **원반이다.** 네모면 모서리도 젖는다 — `_disc` 와 같은 모양이어야 한다.
	t.eq(g.aux_at(306, 306), 0, "원 밖 모서리는 안 젖는다")
	t.eq(g.aux_at(306, 300), 200, "원 안 끝은 젖는다")

	# 🔴 **더 깊은 물을 얕은 값으로 안 덮는다.**
	g.set_water(300, 300, Tuning.WATER_MAX)
	g.apply(CellGrid.cmd_water(300, 300, 6, 100))
	t.eq(g.aux_at(300, 300), Tuning.WATER_MAX, "깊은 칸이 얕은 값으로 안 줄어든다")
	t.eq(g.aux_at(302, 300), 200, "옆 칸도 원래 값(200)보다 안 줄어든다")

	# 지형은 안 건드린다 — 물 룬은 파괴가 아니다.
	var h := CellGrid.new()
	h.apply(CellGrid.cmd_fill(400, 400, 420, 420, Mat.STONE))
	h.apply(CellGrid.cmd_water(410, 410, 6, Tuning.WATER_MAX))
	t.eq(h.mat_at(410, 410), Mat.STONE, "돌은 물로 안 바뀐다")
	t.eq(h.count_material(Mat.WATER), 0, "고체 속에는 물이 한 칸도 안 생긴다")

	# 🔴 타는 칸도 건너뛴다 — 파면에 유령이 남는 경로다.
	var f := CellGrid.new()
	f.apply(CellGrid.cmd_fill(500, 500, 510, 500, Mat.WOOD))
	f.ignite(505, 500)
	f.apply(CellGrid.cmd_water(505, 500, 4, Tuning.WATER_MAX))
	t.eq(f.unburnable_in_front_count(), 0, "타는 칸에 물을 부어도 파면이 안 오염된다")
	t.eq(f.claimed_slot_count(), f.burning_count(), "자리 표도 맞다")

	# 범위 밖 양은 짖고 버린다.
	t.expect_error("CellGrid.cmd_water: 양")
	var b := CellGrid.new()
	b.apply(CellGrid.cmd_water(600, 600, 4, Tuning.WATER_MAX + 1))
	t.eq(b.count_material(Mat.WATER), 0, "범위 밖 양은 한 칸도 안 적신다")

	# 청크를 깨운다 — 안 깨우면 만든 물이 그 자리에 얼어붙는다.
	var w := CellGrid.new()
	w.apply(CellGrid.cmd_water(700, 700, 6, Tuning.WATER_MAX))
	w.step()
	t.ok(w.chunk_awake_at(700, 700), "적신 자리의 청크가 깨어난다")


## 🔴🔴 **물 룬으로 쏘면 물이 생기고, 다른 룬으로 쏘면 안 생긴다.**
##  ⚠ **반대쪽을 같이 재는 것이 요점이다** — 「물이 생긴다」만 재면 **모든 착탄이 물을 만드는**
##   구현도 통과하고, 그건 룬이 축이 아니게 된 것이다.
func _water_rune_makes_water(t) -> void:
	for element in Tuning.ELEM_ALL:
		var g := CellGrid.new()
		var spell := SpellSim.new()
		# 벽을 세우고 그 앞으로 쏜다 — 착탄이 확실히 나야 잰다.
		g.apply(CellGrid.cmd_fill(400, 0, 400, 400, Mat.STONE))
		t.ok(spell.fire(SpellSim.cmd_fire(300, 200, 1, 0, element, 0)),
			"룬 %d 로 발사된다 (검사의 전제)" % element)
		var hit := false
		for _i in 60:
			spell.step(g)
			if spell.active_count() == 0:
				hit = true
				break
		t.ok(hit, "룬 %d 의 탄이 벽에 닿는다" % element)

		var total: int = _water_scan(g, 380, 180, 420, 220)[0]
		if element == Tuning.ELEM_WATER:
			t.ok(total > 0, "물 룬은 착탄점에 물을 만든다 (합 %d)" % total)
			# ⚠ **격자를 한 틱 밀어야 본다.** `spell.step()` 은 격자의 flip 을 안 돌린다 —
			#  커맨드는 `_dirty` 만 찍고 `awake` 가 되는 것은 `_chunk_flip()` 이다.
			#  🔴 그걸 모르고 바로 보면 늘 거짓이라 「안 깨운다」로 오진한다(실제로 그랬다).
			g.step()
			t.ok(g.active_chunk_count() > 0,
				"착탄이 만든 물이 청크를 깨운다 (%d개)" % g.active_chunk_count())
		else:
			t.eq(total, 0, "룬 %d 는 물을 한 톨도 안 만든다" % element)

	# 🔴 **세기마다 다른 양이 반경에서 파생되나.** 세대가 깊어지면 원반이 작아지므로 총량도 준다.
	t.ok(Tuning.water_r(1) < Tuning.water_r(0),
		"세대 1의 물 반경이 세대 0보다 작다 (%d < %d)" % [Tuning.water_r(1), Tuning.water_r(0)])
	var a := CellGrid.new()
	a.apply(CellGrid.cmd_water(800, 800, Tuning.water_r(0), Tuning.WATER_MAX))
	var b := CellGrid.new()
	b.apply(CellGrid.cmd_water(800, 800, Tuning.water_r(1), Tuning.WATER_MAX))
	var sum_a: int = _water_scan(a, 780, 780, 820, 820)[0]
	var sum_b: int = _water_scan(b, 780, 780, 820, 820)[0]
	t.ok(sum_b < sum_a, "깊은 세대가 만드는 물이 더 적다 (%d < %d)" % [sum_b, sum_a])


# ══════════════════════════════════════════════════════════════════
#  단계 6 — 불과 물
# ══════════════════════════════════════════════════════════════════

## 나무 한 줄 + 그 아래 돌바닥.
## ⚠ 나무를 **돌 위에** 얹는다 — 물이 나무 아래로 빠지면 이웃 판정이 흐려진다.
func _make_forest(y: int) -> CellGrid:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(100, y + 1, 160, y + 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(100, y, 160, y, Mat.WOOD))
	return g


## 나무 줄 **위**에 물 한 칸을 가둔다. 🔴 **좌우를 돌로 막는 것이 요점이다.**
##
## ⚠ **막지 않으면 물이 나무 줄 위를 통째로 덮는다** — 아래가 고체(나무)라 못 내려가고
##  좌우가 빈칸이라 끝까지 퍼진다. 그러면 **숲 전체가 젖어서 아무것도 안 타고**,
##  「불이 물까지 번져 왔나」가 원리적으로 거짓이 된다.
## 🔴 **실제로 그렇게 짰다가 검사가 헛돌았다**(2026-08-07) — 불이 물 근처에 오지도 못했고
##  그런데도 「깜빡임 0」이 초록이었다. **전제 단언이 그걸 잡았다.**
func _wet_pocket(g: CellGrid, x: int, y_wood: int) -> void:
	g.apply(CellGrid.cmd_fill(x - 1, y_wood - 1, x - 1, y_wood - 1, Mat.STONE))
	g.apply(CellGrid.cmd_fill(x + 1, y_wood - 1, x + 1, y_wood - 1, Mat.STONE))
	g.set_water(x, y_wood - 1, Tuning.WATER_MAX)


## 🔴🔴 **이미 타는 칸 옆에 물이 오면 꺼진다** — `_burn` 쪽 경로다.
##  ⚠ 아래 `_wet_neighbour_never_catches`(점화 쪽)와 **다른 검사다.** 한 검사로 묶으면
##   어느 경로가 죽었는지 못 가른다 — 둘은 실제로 다른 함수에 산다.
func _water_puts_out_fire(t) -> void:
	var g := _make_forest(300)
	g.ignite(130, 300)
	for _i in 8:
		g.step()
	var lit := g.burning_count()
	t.ok(lit > 1, "불이 먼저 번진다 (%d칸 — 검사의 전제)" % lit)
	t.eq(g.unburnable_in_front_count(), 0, "그때 파면이 깨끗하다")

	# 🔴🔴 **한 칸을 지목해서 잰다.** 「불이 결국 0이 된다」로는 **아무것도 안 재진다** —
	#  끄기를 통째로 지워도 그 칸들은 연료가 다해서 스스로 0이 된다(뒤집어 확인했다, 2026-08-07).
	#  ⇒ 가르는 것은 **「연료가 남았는데 꺼졌고, 나무가 살아남았나」**다.
	t.ok(g.is_burning(130, 300), "지목한 칸이 타고 있다 (검사의 전제)")
	t.ok(g.fuel_at(130, 300) > 0, "그 칸에 연료가 아직 남아 있다 (%d)" % g.fuel_at(130, 300))
	t.eq(g.mat_at(130, 300), Mat.WOOD, "그리고 아직 나무다")

	# 🔴 **타는 한복판에 물을 붓는다.** 물 룬이 실제로 지나는 문(`cmd_water`)을 쓴다.
	g.apply(CellGrid.cmd_water(130, 299, 8, Tuning.WATER_MAX))
	g.step()
	t.ok(not g.is_burning(130, 300), "물이 닿은 다음 틱에 곧바로 꺼진다 (연료가 남았는데도)")
	t.eq(g.mat_at(130, 300), Mat.WOOD, "그 나무가 살아남는다 (다 탄 게 아니라 꺼진 것이다)")
	t.eq(g.aux_at(130, 300), 0, "꺼진 칸의 연료 자리가 0으로 돌아간다")

	var ticks := 1
	while g.burning_count() > 0 and ticks < 200:
		g.step()
		ticks += 1
	t.ok(ticks < 200, "물 밖의 불도 결국 다 꺼진다 (%d틱)" % ticks)
	t.eq(g.burning_count(), 0, "정말 0이다")
	t.ok(g.count_material(Mat.WOOD) > 0,
		"나무가 남아 있다 (%d칸)" % g.count_material(Mat.WOOD))
	t.eq(g.unburnable_in_front_count(), 0, "끈 뒤에도 파면에 탈 수 없는 재료가 없다")
	t.eq(g.claimed_slot_count(), g.burning_count(), "자리 표도 맞다")

	# ⚠ **물은 안 준다** — 끈 만큼 증발시키면 `_burn` 이 `_write_water` 를 지나야 하고,
	#  그건 `_touch` 를 타서 **타는 숲 옆 호수가 매 틱 깨어난다.** 그 대가로 웅덩이는 무한 소화기다.
	t.ok(g.count_material(Mat.WATER) > 0, "물은 그대로 남는다 (%d칸)" % g.count_material(Mat.WATER))


## 🔴🔴 **반대쪽.** 물이 없으면 안 꺼져야 한다 — 안 재면 「불이 그냥 꺼진 것」과 구별이 안 되고,
##  위 검사가 **아무것도 안 재는 것**이 된다.
func _no_water_means_no_rescue(t) -> void:
	var g := _make_forest(400)
	g.ignite(130, 400)
	for _i in 8:
		g.step()
	t.ok(g.burning_count() > 1, "같은 조건에서 불이 번진다 (검사의 전제)")

	# 위 검사와 **같은 틱 수**를 돌린다. 물만 없다.
	for _i in 20:
		g.step()
	t.ok(g.burning_count() > 0,
		"물이 없으면 같은 시간에 안 꺼진다 (%d칸이 아직 탄다)" % g.burning_count())

	# 그리고 결국은 **연료가 다해서** 꺼진다 — 나무가 남지 않는 것이 그 증거다.
	var ticks := 0
	while g.burning_count() > 0 and ticks < 400:
		g.step()
		ticks += 1
	t.ok(ticks < 400, "연료가 다하면 결국 꺼진다 (%d틱)" % ticks)
	t.eq(g.count_material(Mat.WOOD), 0, "그때는 나무가 한 칸도 안 남는다 (다 탔다)")


## 🔴🔴 **물 옆 나무에는 애초에 안 붙는다** — `_ignite_cell` 쪽 경로다.
##  ⚠ 이게 없으면 「붙었다가 즉시 꺼진다」가 되고, 그건 화면에서 **깜빡임**이다(= 고장으로 읽힌다).
func _wet_neighbour_never_catches(t) -> void:
	var g := _make_forest(500)
	g.set_water(130, 499, Tuning.WATER_MAX)
	t.ok(not g.ignite(130, 500), "물 아래 나무에는 직접 붙여도 안 붙는다")
	t.eq(g.burning_count(), 0, "파면에도 안 올라간다")

	# 🔴🔴 **네 방향을 하나씩 다 잰다.** 왼쪽만 재면 `_water_adjacent` 를 **두 방향으로 줄여도**
	#  전부 초록이다(2026-08-07에 확인했다). 방향 하나가 죽으면 그쪽에서만 불이 물을 건넌다.
	# 🔴 옆 칸을 물로 만들려면 **먼저 파야 한다** — `set_water` 는 나무 위에 안 쓴다.
	var h := _make_forest(600)
	h.apply(CellGrid.cmd_fill(129, 600, 129, 600, Mat.EMPTY))
	t.ok(h.set_water(129, 600, Tuning.WATER_MAX), "판 자리에 물을 놓는다 (전제)")
	t.ok(not h.ignite(130, 600), "**왼쪽** 칸이 물이어도 안 붙는다")

	var r := _make_forest(620)
	r.apply(CellGrid.cmd_fill(131, 620, 131, 620, Mat.EMPTY))
	t.ok(r.set_water(131, 620, Tuning.WATER_MAX), "오른쪽을 파고 물을 놓는다 (전제)")
	t.ok(not r.ignite(130, 620), "**오른쪽** 칸이 물이어도 안 붙는다")

	# 아래 — 나무 줄 **아래**가 돌바닥이라 거기를 파고 물을 놓는다.
	var d2 := _make_forest(640)
	d2.apply(CellGrid.cmd_fill(130, 641, 130, 641, Mat.EMPTY))
	t.ok(d2.set_water(130, 641, Tuning.WATER_MAX), "아래를 파고 물을 놓는다 (전제)")
	t.ok(not d2.ignite(130, 640), "**아래** 칸이 물이어도 안 붙는다")

	# 위 — 이 함수 첫 줄(물 아래 나무)이 이미 잰다.

	# 🔴 **반대쪽**: 물이 안 닿으면 붙는다. 안 재면 「아무 데도 안 붙는다」가 통과한다.
	var d := _make_forest(700)
	d.set_water(120, 699, Tuning.WATER_MAX)
	t.ok(d.ignite(140, 700), "물에서 떨어진 나무에는 붙는다")

	# 번짐도 물에서 멈춘다 — 직접 점화만 재면 `_burn` 의 번짐 경로가 안 걸린다.
	var s := _make_forest(800)
	_wet_pocket(s, 140, 800)
	s.ignite(120, 800)
	for _i in 60:
		s.step()
	t.eq(s.mat_at(140, 800), Mat.WOOD, "번지던 불이 물 아래 나무에서 멈춘다")
	t.ok(s.mat_at(125, 800) != Mat.WOOD, "그 앞쪽 나무는 탔다 (검사의 전제 — 불이 실제로 번졌다)")


## 🔴🔴 **진동이 없나 — 물 아래 나무가 「붙었다 꺼졌다」를 반복하지 않나.**
##
## ⚠ **`_burn` 에서만 끄면 이렇게 된다**: 이웃 불이 번져 붙는다 → 다음 틱에 꺼진다 →
##  그 이웃이 아직 타므로 또 붙는다. 화면엔 **물가에서 불이 깜빡이는 것**으로 보이고,
##  매번 `_write_cell` 이 돌므로 그 청크가 그동안 계속 깨어 있다.
##
## 🔴🔴 **재는 것은 「잠드나」가 아니라 「한 틱이라도 붙나」다. 그 구별이 이 검사의 전부다.**
##  ⚠ **처음에 「끝나고 잠드나」로 짰더니 막기 전에도 초록이었다**(2026-08-07 실측).
##   진동이 **이웃 나무의 연료가 다하면 끝나기 때문**이다 — 즉 **유한하다.** 그러니 「영영 안
##   잠든다」는 거짓이고, 「끝나고 잠드나」는 **진동이 있어도 통과한다.**
##  ⇒ **틱마다 그 칸을 봐야만 잡힌다.** 막기 전에 빨간 것을 확인하고 박았다.
func _fire_beside_water_does_not_flicker(t) -> void:
	var g := _make_forest(900)
	# 숲 한쪽 끝에 **가둔** 물, 반대쪽 끝에 불. 불이 물 쪽으로 번져 와서 멈춘다.
	_wet_pocket(g, 150, 900)
	g.ignite(110, 900)

	# 🔴 **틱마다 물 아래 나무를 본다.** 한 틱이라도 타면 그게 깜빡임이다.
	var lit_ticks := 0
	var ticks := 0
	while g.burning_count() > 0 and ticks < 400:
		g.step()
		ticks += 1
		if g.is_burning(150, 900):
			lit_ticks += 1
	t.ok(ticks < 400, "불이 결국 꺼진다 (%d틱)" % ticks)
	# 🔴 **불이 실제로 물까지 번져 왔다는 증거.** 안 오면 이 검사가 통째로 헛돈다.
	t.ok(g.mat_at(149, 900) != Mat.WOOD, "불이 물 바로 옆까지 번져 왔다 (검사의 전제)")
	t.eq(lit_ticks, 0, "물 아래 나무가 한 틱도 안 붙는다 (붙었다 꺼졌다를 반복하지 않는다)")

	var settle := _settle(g, 200)
	t.ok(settle < 200, "그 뒤 격자가 잠든다 (%d틱)" % settle)
	t.eq(g.mat_at(150, 900), Mat.WOOD, "물 아래 나무는 안 탔다")
	t.ok(g.count_material(Mat.WATER) > 0, "물도 그대로다")


## 🔴🔴 **한 칸이 얕음과 불을 동시에 들지 않는다.**
##
## ⚠ **이 성질이 코드 주석 하나를 떠받치고 있다** — `cell_grid.gdshader` 의 「물 분기를 불보다 앞에
##  둔다」가 「두 비트는 같은 칸에 못 선다」에 기대고 있고, **그걸 재는 검사가 없었다**(2026-08-07).
## 🔴 성립하는 이유는 둘이다: 물은 연료가 0이라 점화가 안 닿고, `_write_water` 는 EMPTY·WATER
##  위에만 쓴다. **둘 중 하나만 깨져도** 화면에서 얕은 물이 불로 그려진다.
##
## 🔴 **네이티브 `count()` 로 온 격자를 잰다.** `_flag` 에 쓰이는 비트가 그 둘뿐이라
##  「둘 다 켜짐」이 곧 바이트 값 `SHALLOW|BURNING` 이다 — 아래에서 그 전제부터 단언한다.
##  ⚠ 세 번째 상태 비트가 생기면 이 셈이 새므로, **그때 이 검사를 고쳐야 한다.**
##
## ⚠🔴 **이 검사가 언제 무는지 재 봤다 — 가드 셋이 **전부** 빠져야 문다**(2026-08-07):
##  `_ignite_cell` 의 연료 가드 · 같은 함수의 물 인접 가드 · `_burn` 의 끄기.
##  하나나 둘만 빼면 **초록이다** — 남은 가드가 먼저 가로채기 때문이다.
##  ⇒ **이건 1차 감지기가 아니라 뒷받침이다.** 앞의 셋은 각자 제 검사가 따로 물고,
##   이건 **그 셋이 동시에 무너졌을 때 화면이 거짓말하는 것**을 막는 마지막 줄이다.
##  🔴 「이게 초록이니 두 비트가 안 겹친다」로 읽지 마라 — **가드가 살아 있어서 초록일 수도 있다.**
func _no_cell_carries_both_bits(t) -> void:
	# 🔴 전제: `_flag` 에 쓰이는 비트가 정말 둘뿐인가. 상수 이름으로 훑어 확인한다.
	var consts: Dictionary = (Mat as GDScript).get_script_constant_map()
	var bits := 0
	var names := 0
	for nm: String in consts:
		if nm.begins_with("FLAG_"):
			bits |= int(consts[nm])
			names += 1
	t.eq(names, 2, "상태 비트가 둘이다 (셋이 되면 아래 count 셈이 샌다)")
	var both: int = Mat.FLAG_SHALLOW | Mat.FLAG_BURNING
	t.eq(bits, both, "그 둘이 얕음과 불이다")

	var g := _make_forest(950)
	_wet_pocket(g, 150, 950)
	# 타는 칸과 얕은 물이 **둘 다 실재하는** 상태를 만든다 — 없으면 아래 0이 공짜다.
	g.apply(CellGrid.cmd_fill(120, 949, 120, 949, Mat.EMPTY))
	g.set_water(120, 949, Tuning.WATER_WET)
	g.ignite(110, 950)
	var lit_seen := false
	var shallow_seen := false
	var bad := 0
	for _i in 200:
		g.step()
		if g.burning_count() > 0:
			lit_seen = true
		var flags := g.get_flag()
		if flags.count(Mat.FLAG_SHALLOW) > 0:
			shallow_seen = true
		bad += flags.count(both)
	t.ok(lit_seen, "그동안 불이 실제로 탔다 (검사의 전제)")
	t.ok(shallow_seen, "얕은 물도 실제로 있었다 (검사의 전제)")
	t.eq(bad, 0, "200틱 내내 얕음과 불을 동시에 든 칸이 한 칸도 없다")


## 사각형 안의 물을 한 번에 훑는다 ⇒ `[합, 물 칸 수, 최대 양]`.
## ⚠ **`aux_at` 을 쓴다** — `_aux` 를 직접 못 읽으므로 격자의 공개 문만 지난다.
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
