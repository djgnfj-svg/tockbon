extends RefCounted
## 물과 청크 재우기. 🔴🔴 **물의 실패는 전부 조용하다** — 그래서 여기는 짖음이 아니라 **값**을 잰다.
##
## ⚠ **지금 여기 있는 것은 단계 1(청크 재우기)뿐이다.** 물 재료도 `_water_step` 도 아직 없다.
##  기획이 단계를 가른 이유가 이것이다: 청크가 잘못 서면 물도 같이 틀리고 **어느 쪽이 원인인지
##  못 가른다**(`docs/plans/2.active/water-and-chunk-sleep.md` 「만드는 순서」).
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
	_reset_clears_chunks(t)
	_band_summary_matches_scan(t)


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
	# 청크 (2..5, 3..6) = 4 × 4 = 16개를 정확히 덮는다.
	g.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc - 1, 7 * cc - 1, Mat.STONE))
	g.step()
	t.eq(g.active_chunk_count(), 16, "청크 격자에 딱 맞는 채우기가 정확히 16청크를 깨운다")
	t.ok(g.chunk_awake_at(2 * cc, 3 * cc), "왼쪽 위 모서리 청크가 깨어 있다")
	t.ok(g.chunk_awake_at(6 * cc - 1, 7 * cc - 1), "오른쪽 아래 모서리 청크가 깨어 있다")
	t.ok(not g.chunk_awake_at(2 * cc - 1, 3 * cc), "채운 자리 바로 왼쪽 청크는 안 깨어 있다")
	t.ok(not g.chunk_awake_at(6 * cc, 3 * cc), "채운 자리 바로 오른쪽 청크는 안 깨어 있다")

	# 한 칸만 더 채우면 정확히 한 청크가 더 깨어야 한다 — 인덱스가 밀리면 여기가 어긋난다.
	var g2 := CellGrid.new()
	g2.apply(CellGrid.cmd_fill(2 * cc, 3 * cc, 6 * cc, 7 * cc - 1, Mat.STONE))
	g2.step()
	t.eq(g2.active_chunk_count(), 20, "오른쪽으로 한 칸 넘치면 밴드 4개 × 1청크가 더 깨어난다")


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
