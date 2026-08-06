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
	_water_falls_one_cell_per_tick(t)
	_water_falls_and_stacks(t)
	_water_total_is_conserved(t)
	_settled_water_sleeps(t)
	_digging_below_a_chunk_edge_wakes_the_water(t)
	_cmd_fill_refuses_water(t)
	_water_moves_mark_the_screen_dirty(t)
	_bottom_row_water_is_safe(t)
	_front_has_no_unburnable(t)


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
	g.step()
	g.step()
	t.eq(g.active_chunk_count(), 0, "지형을 깔고 두 틱이면 다시 다 잠든다")

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
	# 🔴🔴 **16이 아니라 20이다** — `_touch` 가 **위쪽 이웃 청크도 깨우기 때문이다**(청크 경계의
	#  「보이지 않는 벽」 고침). 채운 사각형의 첫 행이 밴드 3의 첫 행이라 **밴드 2의 4청크**가 따라 깬다.
	#  ⚠ 이 수가 16으로 돌아가면 그 고침이 사라진 것이다.
	t.eq(g.active_chunk_count(), 20, "덮은 16청크 + 위쪽 이웃 4청크 = 20이 깨어난다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc), "왼쪽 위 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(6 * cc - 1, 7 * cc - 1), "오른쪽 아래 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc - 1), "바로 위 청크가 깨어 있다 (물이 위에서 흘러든다)")

	# 🔴🔴 **좁게 깨우는 것이 결정이다.** 8이웃을 다 찍으면 아래·좌우도 깨어 있을 것이고,
	#  깨어 있는 밴드 하나가 128μs라 그 값이 그대로 예산이 된다(verify-run 실측).
	#  ⇒ **물이 흘러들 수 있는 방향(위)만** 깨운다.
	t.ok(not g.chunk_awake_at(2 * cc, 1 * cc), "두 밴드 위(밴드 1)는 안 깨어 있다 (한 칸만 번진다)")
	t.ok(not g.chunk_awake_at(2 * cc, 7 * cc), "**아래** 청크는 안 깨어 있다 (물은 아래에서 안 온다)")
	t.ok(not g.chunk_awake_at(2 * cc - 1, 3 * cc), "채운 자리 바로 왼쪽 청크는 안 깨어 있다")
	t.ok(not g.chunk_awake_at(6 * cc, 3 * cc), "채운 자리 바로 오른쪽 청크는 안 깨어 있다")

	# 한 칸만 더 채우면 정확히 한 열이 더 깨어야 한다 — 인덱스가 밀리면 여기가 어긋난다.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc, 7 * cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.active_chunk_count(), 25, "오른쪽으로 한 칸 넘치면 밴드 5개 × 1청크가 더 깨어난다")


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
	t.eq(g.band_awake_count(3), 5, "밴드 3의 요약이 5다")
	t.eq(g.band_awake_count(9), 2, "밴드 9의 요약이 2다")
	t.eq(_band_sum(g), g.active_chunk_count(), "밴드 요약의 합이 활성 청크 수와 같다")

	# 🔴 **같은 청크를 여러 번 찍어도 요약이 안 부푼다.** `_touch` 의 중복 가드가 그 자리다 —
	#  안 걸러지면 요약이 실제보다 커지고, 그건 「깨어 있다고 착각해서 도는」 쪽이라 안 짖는다.
	var g2 := CellGrid.new()
	for _i in 4:
		g2.apply(CellGrid.cmd_fill(0, 0, cc - 1, cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.band_awake_count(0), 1, "한 청크를 네 번 채워도 밴드 요약은 1이다")
	t.eq(g2.active_chunk_count(), 1, "활성 청크도 1이다")

	# 잠들면 요약도 같이 0으로 돌아가야 한다 — flip이 요약을 안 갈아 끼우면 여기가 걸린다.
	g2.step()
	t.eq(_band_sum(g2), 0, "다 잠들면 밴드 요약 합도 0이다")


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
func _water_falls_one_cell_per_tick(t) -> void:
	var g := CellGrid.new()
	g.apply(CellGrid.cmd_fill(0, 600, 100, 600, Mat.STONE))
	var y0 := 572
	t.eq(y0 / Tuning.CHUNK_CELLS, 35, "시작 행이 밴드 35다 (아래 경계 통과의 전제)")
	t.eq(576 / Tuning.CHUNK_CELLS, 36, "네 칸 아래가 밴드 36이다 — 이 검사가 밴드 경계를 지난다")
	g.set_water(50, y0, Tuning.WATER_MAX)
	# 🔴🔴 **두 번째 기둥이 아래 밴드를 깨어 있게 잡아 둔다.** 없으면 밴드 순서 뒤집기가
	#  **안 잡힌다** — 기둥이 하나면 물이 밴드 36에 처음 들어가는 그 틱에 36이 아직 잠들어 있어서
	#  순회가 그 밴드를 아예 안 돌고, 뒤집힌 순서가 드러날 자리가 없다(2026-08-07에 확인했다).
	g.set_water(52, 578, Tuning.WATER_MAX)

	for k in 6:
		g.step()
		t.eq(g.aux_at(50, y0 + k + 1), Tuning.WATER_MAX,
			"%d틱 뒤 정확히 %d칸 내려와 있다" % [k + 1, k + 1])
		t.eq(g.aux_at(50, y0 + k), 0, "%d틱 뒤 직전 자리는 비었다" % (k + 1))
		# 🔴 아래 밴드의 기둥도 한 틱에 한 칸이어야 한다 — 밴드 순서가 뒤집히면 여기가 먼저 깨진다.
		t.eq(g.aux_at(52, 578 + k + 1), Tuning.WATER_MAX,
			"%d틱 뒤 아래 밴드 기둥도 정확히 %d칸이다" % [k + 1, k + 1])


## 🔴 공중에 놓은 물이 바닥까지 내려가 쌓이나. **아래로만** 가는 단계라 결과가 정확히 예측된다.
func _water_falls_and_stacks(t) -> void:
	var g := CellGrid.new()
	# 바닥 한 줄과 그 위 기둥 하나.
	g.apply(CellGrid.cmd_fill(0, 300, 200, 300, Mat.STONE))
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
	# 🔴🔴 **여러 층을 부어야 한다.** 한 층만 부으면 쌓인 물 위에 물이 없어서
	#  `_water_fall` 의 「아래가 꽉 찼다(`space <= 0`)」 가지를 **한 번도 안 지난다** —
	#  그 조기 탈출을 지워도 이 검사가 초록이었다(2026-08-07에 확인했다).
	#  ⚠ 지우면 꽉 찬 칸끼리 매 틱 **양이 안 바뀌는 쓰기**를 주고받으며 청크를 영영 깨운다.
	for x in range(40, 80):
		for k in 3:
			g.set_water(x, 470 + k, Tuning.WATER_MAX)
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
	g.set_water(100, y_edge, Tuning.WATER_MAX)
	# 🔴🔴 **먼저 한 틱을 돌려야 한다.** 커맨드는 `_dirty` 만 찍으므로 flip 전에는
	#  `active_chunk_count()` 가 **0이다** — 그냥 `while active > 0` 로 시작하면 루프가
	#  **한 번도 안 돌고** 아래 「잠들었다」가 공짜로 통과한다.
	#  ⚠ 실제로 그렇게 짰다가 뮤테이션이 안 물어서 알았다(2026-08-07). 검사가 헛돌고 있었다.
	g.step()
	var settle := 1
	while g.active_chunk_count() > 0 and settle < 20:
		g.step()
		settle += 1
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
	h.set_water(100, y_mid, Tuning.WATER_MAX)
	h.step()  # 🔴 위와 같은 이유 — flip 전에는 활성이 0이라 루프가 헛돈다
	var h_settle := 1
	while h.active_chunk_count() > 0 and h_settle < 20:
		h.step()
		h_settle += 1
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
	t.eq(g.aux_at(50, 691), Tuning.WATER_MAX, "물이 실제로 한 칸 움직였다 (전제)")
	t.ok(g.consume_changed() > 0, "물이 움직인 틱은 화면을 다시 올리라고 표시한다")

	# 다 쌓여 잠든 뒤에는 0이어야 한다.
	while g.active_chunk_count() > 0:
		g.step()
	g.consume_changed()
	for _i in 10:
		g.step()
	t.eq(g.consume_changed(), 0, "잠든 뒤에는 화면을 안 건드린다")


## 🔴 **격자 맨 아래 행.** `_water_step` 의 `y < H - 1` 가드가 없으면 `below` 가 격자를 넘어
##  **매 틱 엔진 「Index out of bounds」**가 난다 — 그건 단언에 안 잡히는 침묵사고, 래퍼만 잡는다.
## ⚠ 그물이 물을 y=600대까지만 놓고 있어서 이 가드가 **한 번도 안 밟혔다**(2026-08-07).
func _bottom_row_water_is_safe(t) -> void:
	var g := CellGrid.new()
	t.ok(g.set_water(300, CellGrid.H - 1, Tuning.WATER_MAX), "격자 맨 아래 행에 물을 놓는다")
	t.ok(g.set_water(301, CellGrid.H - 2, Tuning.WATER_MAX), "그 바로 위에도 놓는다")
	for _i in 20:
		g.step()
	# 🔴 아래로 갈 곳이 없으므로 그대로 있어야 한다. 격자 밖으로 새면 총량이 준다.
	t.eq(g.aux_at(300, CellGrid.H - 1), Tuning.WATER_MAX, "맨 아래 물이 격자 밖으로 안 샌다")
	t.eq(g.aux_at(301, CellGrid.H - 1), Tuning.WATER_MAX, "위 칸의 물은 맨 아래로 내려온다")
	t.eq(g.aux_at(301, CellGrid.H - 2), 0, "내려온 자리는 비었다")
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
