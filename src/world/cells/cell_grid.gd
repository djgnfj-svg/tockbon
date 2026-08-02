extends RefCounted
## 셀 격자 시뮬 코어. **순수 객체다 — 씬 트리를 모른다.**
##
## 🔴🔴 `Node`가 아니라 `RefCounted`인 게 이 파일의 가장 중요한 성질이다(설계 §8 ①).
##  `Input`·`Time`·`randi()`·`get_viewport()`·씬 트리에 **절대 접근하지 않는다.**
##  ⇒ 서버가 헤드리스로 N개를 돌릴 수 있고, 클라가 0개를 돌릴 수도 있고, 테스트가 씬 없이 돈다.
##  시뮬이 `_process`에서 마우스를 읽는 `Node2D`이면 멀티를 붙일 때 그 자리가 통째로 재작성이다.
##
## 🔴 **격자를 바꾸는 문은 `apply(cmd)` 하나다.** 직접 쓰기 코드는 이 파일 안에만 있다(설계 §8 ②).
##  입력 핸들러가 `_mat[i] = WATER`를 하는 순간 그게 재작성 자리가 된다.

const CellHash := preload("res://src/world/cells/cell_hash.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")

# ─── 격자 수치 (설계 §1) ───────────────────────────────────────────
const W := 256
const H := 144
## 🔴 `idx = (y << X_SHIFT) | x`. W가 2의 거듭제곱이라 **곱셈이 사라진다** —
##  내부 루프에서 상시 계산되는 값이라 이게 그대로 성능이다.
##  ⚠ W를 바꾸면 여기도 바꿔야 한다. `_init()`이 안 맞으면 짖는다.
const X_SHIFT := 8
const X_MASK := W - 1
const CELL_COUNT := W * H  # 36,864

const CHUNK := 16
const CHUNK_SHIFT := 4
const CX := W >> CHUNK_SHIFT  # 16
const CY := H >> CHUNK_SHIFT  # 9
const CHUNK_COUNT := CX * CY  # 144

# ─── 조정 손잡이 ───────────────────────────────────────────────────
## 물이 한 틱에 수평으로 미끄러지는 최대 칸 수.
## ⚠ 측정 ①(「픽셀 물처럼 보이나」)의 주 튜닝 대상이다. 크면 빨리 퍼지고 「미끄러지는」 느낌,
##  작으면 점성 있게 보인다. 손맛 값이라 사용자가 직접 만져 정한다.
## 🔴 **정착 수면의 기울기도 이 값이 정한다** — 「SLIDE_MAX칸에 1칸」까지만 눕는다(`_slide_target`).
##  올리면 더 평평해지고 더 멀리 튄다. 두 성질이 한 손잡이에 묶여 있다는 걸 알고 만져라.
const SLIDE_MAX := 4

## 전하가 유지되는 틱 수. `_aux`에 들어가므로 255를 넘길 수 없다.
const CHARGE_TTL := 30

# 해시 솔트 — 용도마다 달라야 같은 셀에서 두 판정이 붙어 다니지 않는다.
const SALT_DIAG := 0x9E3779B9

# ─── 커맨드 (설계 §8 ②) ───────────────────────────────────────────
## ⚠ 설계의 `CLEAR(rect)`는 별도 커맨드가 아니라 `CMD_FILL`에 `mat = EMPTY`다.
##  같은 일을 하는 문을 둘 두면 갈라진다(SKILL.md 「단일 소스를 늘리지 마라」).
enum { CMD_PAINT = 0, CMD_FILL = 1, CMD_STRIKE = 2, CMD_RESET = 3, CMD_BLAST = 4 }

## 폭발 반경 상한. 🔴 검증이 없으면 범위 밖 값 하나가 바운딩 박스를 격자 밖까지 늘리고,
##  그건 `SCRIPT ERROR` grep에 안 걸리는 엔진 「Index out of bounds」로만 짖는다.
const BLAST_R_MAX := 48

## 🔴 **명시 리스트다 — 비트값이라 연속이 아니다**(0 · 1 · 4). 인덱스로 순회하면 조용히 어긋난다.
const RESIDUE_ALL: Array[int] = [0, Mat.FLAG_WET, Mat.FLAG_CHARGED]

# ─── 상태 ─────────────────────────────────────────────────────────
var _mat := PackedByteArray()   # 재료 id
var _aux := PackedByteArray()   # 🔴 의미는 재료·상태별로 다르다 — cell_materials.gd의 `_aux` 절을 봐라
var _flag := PackedByteArray()  # 상태 비트 (하위 4비트만)

var _awake := PackedByteArray()       # 이번 틱에 돌 청크
var _awake_next := PackedByteArray()  # 다음 틱에 돌 청크

## 전하 파면. 🔴 확산 루프와 **완전히 분리**된다 — 전기는 물질 수송이 아니라 파면 전파라
##  CA 루프에 넣으면 순회 순서에 따라 한 틱에 화면을 가로지른다(설계 §4.4).
var _charge_front := PackedInt32Array()
var _charge_next := PackedInt32Array()

var _behavior := PackedByteArray()  # 부팅 때 구운 평면 테이블 — 내부 루프는 이것만 인덱싱한다
var _tick := 0


func _init() -> void:
	_mat.resize(CELL_COUNT)
	_aux.resize(CELL_COUNT)
	_flag.resize(CELL_COUNT)
	_awake.resize(CHUNK_COUNT)
	_awake_next.resize(CHUNK_COUNT)
	_behavior = Mat.bake_behavior()
	# 조용히 어긋나는 자리라 부팅에서 짖게 한다 — 인덱싱이 통째로 틀리면 증상이 「물이 이상하다」로만 나온다.
	if (1 << X_SHIFT) != W:
		push_error("CellGrid: X_SHIFT(%d)가 W(%d)와 안 맞는다" % [X_SHIFT, W])
	if CX * CHUNK != W or CY * CHUNK != H:
		push_error("CellGrid: 청크 크기(%d)가 격자(%dx%d)를 딱 나누지 못한다" % [CHUNK, W, H])


# ══════════════════════════════════════════════════════════════════
#  틱
# ══════════════════════════════════════════════════════════════════

## 한 틱 진행하고 **이번 틱에 실제로 돈 청크 수**를 돌려준다.
func step() -> int:
	_tick += 1

	# 다음 틱 목록을 이번 틱 목록으로 넘기고, 쓰던 버퍼를 재활용해 0으로 연다.
	var prev := _awake_next
	_awake_next = _awake
	_awake = prev
	_awake_next.fill(0)

	# 이번 틱의 수평 선호 방향. 🔴 매 틱 뒤집히는 게 좌우 편향을 없애는 장치다.
	var dir := 1 if (_tick & 1) == 1 else -1
	var processed := _sweep(dir)
	_step_charge()
	return processed


## 🔴🔴🔴 **순회 순서 — 이건 계약이다. 「읽기 쉽게」 바꾸면 전제가 통째로 무너진다.**
##
## 이 시뮬은 **단일 버퍼 in-place**다. 더블 버퍼를 쓰면 두 셀이 같은 빈 칸을 목표로 삼아
## 물이 복제되거나 사라진다 — 낙하 물은 장(field) 확산이 아니라 **물질 수송**이기 때문이다.
## 그래서 질량 보존이 안 된다. 단일 버퍼가 이 설계의 전제다(설계 §4).
##
## 단일 버퍼의 대가는 「한 셀이 한 틱에 두 번 움직일 수 있다」인데,
## 보통은 그걸 **「이번 틱에 이미 움직였나」 플래그**로 막는다.
## 🔴 **그 플래그를 도입하지 마라.** 매 틱 전 격자를 지워야 해서
##   「활성 영역만 돈다」(설계 §5·GDD 「멀티가 사는 조건」 2)와 **정면으로 충돌한다.**
##   (틱 패리티 스탬프로 지우기를 피하는 꼼수도 틀린다 — 두 틱 연속 안 움직인 셀이 잘못 건너뛰어진다.)
##
## ⇒ 대신 **순회 순서**로 없앤다. 지켜야 하는 불변량은 하나다:
##    **셀이 이동할 수 있는 모든 도착지는, 이번 틱에 이미 지났거나 아예 안 도는 자리여야 한다.**
##
##   · 밴드(청크 행)를 **아래 → 위**로 돈다      ⇒ y+1은 언제나 먼저 지났다
##   · 밴드 안에서는 **행을 아래 → 위**로 돈다   ⇒ 같은 밴드 안에서도 y+1이 먼저다
##   · 행 안의 열은 **선호 방향 dir의 반대**로   ⇒ dir로 미끄러지는 도착 열이 먼저다
##
## ⚠ **밴드 안에서 「청크 → 행」이 아니라 「행 → 청크」로 도는 이유가 여기 있다.**
##   설계 원문은 청크를 바깥에 두었는데, 그러면 **대각 아래 이동이 청크 열 경계에서 깨진다**:
##   같은 밴드의 옆 청크는 아직 안 돈 상태라 거기로 떨어진 물이 같은 틱에 또 움직인다.
##   행을 바깥에 두면 밴드 전체에서 y+1이 항상 먼저 처리되므로 그 구멍이 닫힌다.
##   비용은 밴드당 청크 플래그 검사 16 → 256회뿐이다(무시 가능).
##
## ⇒ 그리고 dir이 매 틱 뒤집히므로 **좌우 편향이 없다.** 테스트가 이걸 잰다.
func _sweep(dir: int) -> int:
	var processed := 0
	for cy in range(CY - 1, -1, -1):  # 밴드 아래 → 위
		var base := cy * CX
		var band_awake := false
		for cx in CX:
			if _awake[base + cx] != 0:
				band_awake = true
				processed += 1
		if not band_awake:
			continue
		var y_top := cy << CHUNK_SHIFT
		for y in range(y_top + CHUNK - 1, y_top - 1, -1):  # 행 아래 → 위
			_sweep_row(y, base, dir)
	return processed


func _sweep_row(y: int, chunk_base: int, dir: int) -> void:
	var row := y << X_SHIFT
	if dir > 0:
		# dir이 오른쪽이면 **왼쪽으로** 훑는다 — 도착 열이 이미 지난 자리가 되도록.
		for cx in range(CX - 1, -1, -1):
			if _awake[chunk_base + cx] == 0:
				continue
			var x0 := cx << CHUNK_SHIFT
			for x in range(x0 + CHUNK - 1, x0 - 1, -1):
				_step_cell(x, y, row | x, dir)
	else:
		for cx in CX:
			if _awake[chunk_base + cx] == 0:
				continue
			var x0 := cx << CHUNK_SHIFT
			for x in range(x0, x0 + CHUNK):
				_step_cell(x, y, row | x, dir)


func _step_cell(x: int, y: int, i: int, dir: int) -> void:
	var m := _mat[i]
	if m == Mat.EMPTY:
		return  # 조기 탈출 — 빈 셀이 압도적 다수라 이 한 줄이 전 격자 훑기 비용을 정한다

	var f := _flag[i]
	if (f & Mat.FLAG_CHARGED) != 0:
		# 전하 TTL은 여기서 깎는다. 파면 인덱스 목록을 따로 들고 있으면
		# 물이 움직일 때마다 인덱스가 낡아서 못 쓴다.
		var ttl := _aux[i] - 1
		if ttl <= 0:
			_flag[i] = f & ~Mat.FLAG_CHARGED
			_aux[i] = 0
		else:
			_aux[i] = ttl
		# 전하가 줄어든 것도 쓰기다 — 안 깨우면 다음 틱에 이 청크를 안 돌아 전하가 영원히 남는다.
		_wake(x, y)

	if _behavior[m] == Mat.BEHAVIOR_LIQUID:
		_move_water(x, y, i, dir)


## 물 한 셀. **전제는 `_sweep`의 순회 순서 주석이다 — 그걸 읽지 않고 이 함수를 고치지 마라.**
func _move_water(x: int, y: int, i: int, dir: int) -> void:
	var below := y + 1
	# 격자 밖은 고체로 취급한다(설계 §1) — 특수 규칙이 없어서 **질량이 정확히 보존된다.**
	if below < H:
		var row_b := below << X_SHIFT
		# 1. 아래
		if _mat[row_b | x] == Mat.EMPTY:
			_move_into_empty(i, x, y, row_b | x, x, below)
			return
		# 2. 대각 아래. 좌/우 중 어느 쪽을 먼저 보는지는 **위치 해시**로 정한다.
		#    ⚠ `randi()`가 아니다 — 스트림 난수는 호출 횟수 하나만 달라도 클라가 갈라진다.
		var first := dir
		if (CellHash.hash32(x, y, _tick, SALT_DIAG) & 1) == 1:
			first = -dir
		var nx := x + first
		if nx >= 0 and nx < W and _mat[row_b | nx] == Mat.EMPTY:
			_move_into_empty(i, x, y, row_b | nx, nx, below)
			return
		nx = x - first
		if nx >= 0 and nx < W and _mat[row_b | nx] == Mat.EMPTY:
			_move_into_empty(i, x, y, row_b | nx, nx, below)
			return

	# 3. 선호 방향으로 미끄러진다 — **내려갈 데가 있을 때만.**
	var row := y << X_SHIFT
	var tx := _slide_target(x, y, row, dir)
	if tx != x:
		_move_into_empty(i, x, y, row | tx, tx, y)
		return

	# 4. 자리를 잡았다.
	# 🔴🔴 **이동 규칙이 dir에 의존하니 재우기 판정도 dir을 알아야 한다.**
	#  재우기는 「이번 틱에 쓰기가 있었나」로만 판정하는데, 반대 방향으로는 갈 수 있는 물이
	#  이번 틱에 아무것도 안 쓰고 잠들면 **다음 틱에 dir이 뒤집혀도 청크를 안 돌아 그 자리에 얼어붙는다.**
	#  ⇒ 조건은 「반대 방향으로 갈 수 있나」 그 자체여야 한다. 같은 함수로 물어야 둘이 안 갈라진다.
	#
	#  🔴 **이 두 줄을 지켜주는 그물은 `test_cell_grid_auto.gd`의 12번 하나뿐이다.**
	#   ⚠ 재우기 그물(6c·6d)은 **구조적으로 이걸 못 잡는다** — 깨우기를 빼면 격자가 **더 빨리** 잠들어서
	#    `awake_count() == 0`이 오히려 더 잘 통과한다. 그래서 12번은 「잠들었나」가 아니라
	#    **「물이 도착했나」**를 재고, `dir` 패리티 **양쪽**을 다 돈다(한쪽은 검사 없이도 통과한다).
	#   ⚠ 예전에 여기 「청크 경계 통과 그물이 이걸 잡는다」고 적혀 있었는데 **사실이 아니었다**(T4).
	#
	#  ⚠ **`dir`에 의존하는 「갈 수 있나」 판정은 규칙 3(미끄러짐) 하나뿐이다.** 규칙 2(대각)는
	#   좌/우를 **둘 다** 시도하므로 `dir`·틱과 무관하게 가능 여부가 같고, `_sweep_row`의 방향은
	#   방문 **순서**만 정할 뿐 방문 **여부**를 안 바꾼다. 그래서 이 자리 말고 같은 갈래는 없다.
	if _slide_target(x, y, row, -dir) != x:
		_wake(x, y)
	_wet_neighbors(x, y)


## `d` 쪽으로 최대 SLIDE_MAX칸 훑어 **내려갈 데가 있는 첫 자리**를 돌려준다. 없으면 x 그대로.
##
## 🔴🔴 **「내려갈 데가 있나」가 이 규칙의 전부다.** 이 조건이 없으면 평평한 바닥의 물이
##  매 틱 뒤집히는 dir을 따라 ±SLIDE_MAX칸을 **영원히 왕복한다** — 멈추지도, 잠들지도 않는다.
##  실측이었다: 실제 씬이 2400틱까지 활성청크 10/144 · 웅덩이가 20Hz로 16px씩 떨었고,
##  움직이는 물이 매 틱 전하 파면에 재등록돼 **번개가 영영 안 꺼졌다.**
##  ⇒ 재는 것 셋(픽셀 물처럼 보이나 · 순서가 손에 잡히나 · 성능)을 전부 왜곡했다.
##
## ⚠ **대가**: 높이차 1짜리 계단은 안 무너진다. 수면이 「완전 평평」이 아니라
##  **SLIDE_MAX칸에 1칸 기울기**까지만 눕는다(높이차 2 이상은 규칙 2의 대각이 무너뜨린다).
##  그물 3(평탄화)이 그 값을 실측으로 잰다 — 기대치를 임의로 정하지 마라.
## ⚠ 격자 맨 아랫줄(y = H-1)은 아래가 없어서 수평 확산이 아예 안 된다. 화면 밖 여백이라 받아들인다.
func _slide_target(x: int, y: int, row: int, d: int) -> int:
	var below := y + 1
	if below >= H:
		return x
	var row_b := below << X_SHIFT
	var tx := x
	for _k in SLIDE_MAX:
		var nx := tx + d
		if nx < 0 or nx >= W or _mat[row | nx] != Mat.EMPTY:
			return x  # 길이 막혔다 — 여기까지 내려갈 데가 없었다
		tx = nx
		if _mat[row_b | nx] == Mat.EMPTY:
			return tx  # 내려갈 데를 찾았다. **거기까지만** 간다 — 지나치면 구멍을 넘어간다
	return x


## 🔴 도착지가 EMPTY라는 건 **호출부가 이미 확인했다.** 그래서 덮어써도 아무것도 안 사라진다
##  = 질량이 정확히 보존된다. 이 전제를 깨는 호출을 추가하지 마라.
func _move_into_empty(i: int, x: int, y: int, j: int, nx: int, ny: int) -> void:
	var f := _flag[i]
	_mat[j] = _mat[i]
	_flag[j] = f
	_aux[j] = _aux[i]
	_mat[i] = Mat.EMPTY
	_flag[i] = 0
	_aux[i] = 0
	_wake(x, y)
	_wake(nx, ny)
	# 전하를 띤 물이 움직이면 파면 목록의 인덱스가 낡는다 — 새 자리를 다시 넣어 전파를 잇는다.
	if (f & Mat.FLAG_CHARGED) != 0:
		_charge_front.append(j)


## 물이 자리를 잡을 때 인접 4방향 **고체**에 WET을 켠다.
## ⚠ S1에서 WET은 **마르지 않는다.** 마름을 넣으면 젖은 셀이 매 틱 갱신돼야 해서
##  청크가 영영 안 잠들고, 그러면 성능 예산이 통째로 틀어진다. 측정에 필요 없는 **의도적 누락**이다.
## 🔴 값이 실제로 바뀔 때만 깨운다 — 안 그러면 고인 물이 자기 청크를 영원히 깨워 둔다.
func _wet_neighbors(x: int, y: int) -> void:
	_wet_one(x - 1, y)
	_wet_one(x + 1, y)
	_wet_one(x, y - 1)
	_wet_one(x, y + 1)


func _wet_one(x: int, y: int) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	var i := (y << X_SHIFT) | x
	var m := _mat[i]
	if m == Mat.EMPTY or m == Mat.WATER:
		return
	var f := _flag[i]
	if (f & Mat.FLAG_WET) != 0:
		return
	_flag[i] = f | Mat.FLAG_WET
	_wake(x, y)


# ══════════════════════════════════════════════════════════════════
#  전하 — 프론티어 큐(BFS). 확산 루프와 분리돼 있다.
# ══════════════════════════════════════════════════════════════════

func _step_charge() -> void:
	if _charge_front.is_empty():
		return
	for idx: int in _charge_front:
		# 물이 움직여 이 자리가 비었거나 TTL이 끝났으면 건너뛴다.
		if (_flag[idx] & Mat.FLAG_CHARGED) == 0:
			continue
		var x := idx & X_MASK
		var y := idx >> X_SHIFT
		_charge_into(x - 1, y)
		_charge_into(x + 1, y)
		_charge_into(x, y - 1)
		_charge_into(x, y + 1)
	# 틱당 딱 1칸씩 퍼진다 ⇒ **눈에 보이는 전파**가 된다. 순회 순서와 무관하므로 편향도 없다.
	var prev := _charge_front
	_charge_front = _charge_next
	_charge_next = prev
	_charge_next.clear()


## ⚠ `PackedInt32Array`를 인자로 넘기면 CoW 사본이 되어 **append가 호출부에 안 보인다.**
##  그래서 파면 목록은 멤버(`_charge_next`)로 두고 여기서 직접 민다. 에러 없이 조용히 죽는 자리다.
func _charge_into(x: int, y: int) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	var i := (y << X_SHIFT) | x
	var f := _flag[i]
	if (f & Mat.FLAG_CHARGED) != 0:
		return
	if not _conducts(i, f):
		return
	_flag[i] = f | Mat.FLAG_CHARGED
	_aux[i] = CHARGE_TTL
	_wake(x, y)
	_charge_next.append(i)


func _conducts(i: int, f: int) -> bool:
	var m := _mat[i]
	if m == Mat.WATER:
		return true
	return m != Mat.EMPTY and (f & Mat.FLAG_WET) != 0


# ══════════════════════════════════════════════════════════════════
#  청크 깨우기
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **3×3 셀 이웃을 덮는 모든 청크**를 깨운다. 자기 청크만 깨우면
##  **물이 청크 경계에서 얼어붙는다** — 잠든 청크 D의 경계에 선 물은, 그 옆(깨어 있는 청크 C)이
##  비워져도 D가 안 깨어나서 영원히 안 흐른다. 설계가 이걸 1급 버그로 지목했다(설계 §5).
##  대각 이동도 있으니 3×3이고, 최대 4청크가 켜진다. 셀이 청크 안쪽이면 반복 1회다.
## ⚠ **외부 이벤트(페인트·번개·나중의 지형 파괴)도 반드시 이 문을 지나야 한다.**
##  안 지나면 에러 없이 아무 일도 안 난다.
func _wake(x: int, y: int) -> void:
	var cx0 := (x - 1) >> CHUNK_SHIFT
	var cx1 := (x + 1) >> CHUNK_SHIFT
	var cy0 := (y - 1) >> CHUNK_SHIFT
	var cy1 := (y + 1) >> CHUNK_SHIFT
	if cx0 < 0:
		cx0 = 0
	if cy0 < 0:
		cy0 = 0
	if cx1 >= CX:
		cx1 = CX - 1
	if cy1 >= CY:
		cy1 = CY - 1
	for cy in range(cy0, cy1 + 1):
		var b := cy * CX
		for cx in range(cx0, cx1 + 1):
			_awake_next[b + cx] = 1


# ══════════════════════════════════════════════════════════════════
#  커맨드 — 격자를 바꾸는 유일한 문
# ══════════════════════════════════════════════════════════════════

static func cmd_paint(x: int, y: int, r: int, mat: int) -> Dictionary:
	return {"kind": CMD_PAINT, "x": x, "y": y, "r": r, "mat": mat}


static func cmd_fill(x0: int, y0: int, x1: int, y1: int, mat: int) -> Dictionary:
	return {"kind": CMD_FILL, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "mat": mat}


static func cmd_strike(x: int, y: int) -> Dictionary:
	return {"kind": CMD_STRIKE, "x": x, "y": y}


## ⚠ 틱 번호도 0으로 돌아간다 — 「세상을 새로 연다」는 뜻이라 그게 맞다.
##  멀티에서는 라운드 경계에서 서버가 보내는 커맨드가 된다.
static func cmd_reset() -> Dictionary:
	return {"kind": CMD_RESET}


## 폭발 — **파괴 · 채우기 · 잔여가 한 커맨드 안**이다.
##
## 🔴🔴 **기존 PAINT/FILL 조합으로는 못 만든다. 원자성보다 이 이유가 앞선다:**
##  `_write_cell`이 `_flag`·`_aux`를 무조건 0으로 지운다 ⇒ PAINT로는 잔여를 남길 방법이 아예 없고,
##  「파괴한 뒤 페인트」로 쪼개면 **겹치는 영역의 잔여가 조용히 지워진다.** 순서 의존 침묵사다.
##  원자성도 같이 산다 — 폭발은 세상에서 **한 사건**이라 쪼개면 리플레이·롤백이 절반만 적용한다.
##
## 🔴 **위력 표(`power → 반경`)를 여기 넣지 않는다.** 그건 게임 규칙이고 `CellGrid`는 격자 도구다.
##  표를 격자에 넣으면 시뮬 코어가 밸런스를 알게 되고, 원소가 늘 때마다 이 파일을 열게 된다.
##  ⇒ 표는 `spell_tuning.gd`에 두고 커맨드는 **자기설명적**으로 만든다.
##
##   rd       파괴 반경          rr  잔여 반경 (🔴 rr > rd가 아니면 잔여가 전부 EMPTY 위에 떨어진다)
##   residue  `Mat.FLAG_WET` · `Mat.FLAG_CHARGED` · 0
##   fill_mat 구멍을 채울 재료 (EMPTY면 채우기 패스를 건너뛴다)      rf  채우는 반경
static func cmd_blast(
	x: int, y: int, rd: int, rr: int, residue: int, fill_mat: int, rf: int
) -> Dictionary:
	return {
		"kind": CMD_BLAST, "x": x, "y": y, "rd": rd, "rr": rr,
		"residue": residue, "fill_mat": fill_mat, "rf": rf,
	}


func apply(cmd: Dictionary) -> void:
	match int(cmd.get("kind", -1)):
		CMD_PAINT:
			_paint_brush(int(cmd["x"]), int(cmd["y"]), int(cmd["r"]), int(cmd["mat"]))
		CMD_FILL:
			_fill_rect(int(cmd["x0"]), int(cmd["y0"]), int(cmd["x1"]), int(cmd["y1"]), int(cmd["mat"]))
		CMD_STRIKE:
			_strike(int(cmd["x"]), int(cmd["y"]))
		CMD_RESET:
			_reset()
		CMD_BLAST:
			_blast(
				int(cmd["x"]), int(cmd["y"]), int(cmd["rd"]), int(cmd["rr"]),
				int(cmd["residue"]), int(cmd["fill_mat"]), int(cmd["rf"]))
		_:
			push_error("CellGrid.apply: 모르는 커맨드 %s" % cmd)


## 🔴 `apply()`는 **멀티에서 클라가 서버에 보내는 문**이다(설계 §8 ②). 검증 없이 두면
##  범위 밖 id 하나가 `_behavior[mat]`에서 **매 틱 엔진 「Index out of bounds」**를 낸다 —
##  그건 `SCRIPT ERROR` grep에 안 걸리는 이 리포 단골 침묵사다(SKILL.md).
##  255를 넘으면 `PackedByteArray`가 말없이 하위 8비트로 자르고, 셰이더는 `clamp`라 마젠타로 뜬다
##  ⇒ **시뮬과 렌더가 서로 다른 방식으로** 틀어진다.
## ⚠ 내부 루프가 아니라 **커맨드 경계**에서 한 번만 본다 — 브러시 하나가 `_write_cell`을 수백 번 돈다.
func _valid_mat(mat: int) -> bool:
	if mat >= 0 and mat < Mat.SLOT_COUNT and Mat.DEFS.has(mat):
		return true
	push_error("CellGrid: 모르는 재료 id %d — 커맨드를 버린다" % mat)
	return false


func _paint_brush(cx: int, cy: int, r: int, mat: int) -> void:
	if not _valid_mat(mat):
		return
	var rr := r * r
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= H:
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= W:
				continue
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy > rr:
				continue
			_write_cell(x, y, mat)


func _fill_rect(x0: int, y0: int, x1: int, y1: int, mat: int) -> void:
	if not _valid_mat(mat):
		return
	var ax := maxi(0, mini(x0, x1))
	var bx := mini(W - 1, maxi(x0, x1))
	var ay := maxi(0, mini(y0, y1))
	var by := mini(H - 1, maxi(y0, y1))
	for y in range(ay, by + 1):
		for x in range(ax, bx + 1):
			_write_cell(x, y, mat)


## 🔴 값이 안 바뀌면 깨우지 않는다 — 아무 일도 안 하는 페인트가 청크를 깨우면
##  「재우기」가 깨지고 성능 예산이 통째로 틀어진다.
func _write_cell(x: int, y: int, mat: int) -> void:
	var i := (y << X_SHIFT) | x
	if _mat[i] == mat and _flag[i] == 0 and _aux[i] == 0:
		return
	_mat[i] = mat
	_flag[i] = 0
	_aux[i] = 0
	_wake(x, y)


func _strike(x: int, y: int) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	var i := (y << X_SHIFT) | x
	var f := _flag[i]
	# 🔴 마른 곳에 치면 아무 데도 안 간다. 그게 「순서가 다르면 결과가 다르다」의 최소 시연이다
	#    — 먼저 적시고 번개, 와 번개 먼저는 결과의 **종류**가 다르다(GDD 「세상 상태」).
	if (f & Mat.FLAG_CHARGED) != 0 or not _conducts(i, f):
		return
	_flag[i] = f | Mat.FLAG_CHARGED
	_aux[i] = CHARGE_TTL
	_wake(x, y)
	_charge_front.append(i)


## 🔴🔴🔴 **세 패스의 순서는 계약이다 — 「읽기 쉽게」 묶거나 뒤집지 마라.**
##
##   1. 파괴   반경 rd 안의 **고체만** EMPTY로. ⚠ 물은 안 지운다 — 그래야 호수 밑을 터뜨리면
##             호수가 구멍으로 **쏟아진다.** 공짜로 얻는 최고의 「세상이 바뀌었다」다.
##   2. 채우기 반경 rf 안의 **지금 EMPTY인 칸**에 fill_mat.
##             🔴 1보다 먼저 돌면 채울 EMPTY가 하나도 없다 — 에러 없이 **물이 0칸** 나온다(N5).
##   3. 잔여   반경 rr 안에 `_wet_one` / `_strike`.
##             🔴🔴 **1·2 뒤여야 한다.** 앞이면 `_write_cell`이 방금 붙인 플래그를 지운다.
##
## 🔴🔴 **새 규칙을 하나도 안 만든다.** 잔여는 기존 `_wet_one`·`_strike`를 **셀마다 부르는 것**이다.
##  ⇒ 규칙이 두 벌이 될 수 없고(SKILL.md T5), 그물 8·8e·9의 전기 규칙이 **공짜로 폭발에도** 적용된다.
##  ⚠ 그래서 **마른 돌에 번개 폭발을 쏘면 잔여가 정확히 0칸이다**(`_strike`가 전도체만 본다).
##   그게 버그가 아니라 이 게임의 테제고, N4가 그걸 잰다.
##
## ⚠ 검증은 **커맨드 경계에서 한 번만** 한다(`_paint_brush` 선례) — 내부 루프가 수천 번 돈다.
func _blast(cx: int, cy: int, rd: int, rr: int, residue: int, fill_mat: int, rf: int) -> void:
	if not _valid_mat(fill_mat):
		return
	if not (_valid_radius(rd) and _valid_radius(rr) and _valid_radius(rf)):
		return
	if not RESIDUE_ALL.has(residue):
		push_error("CellGrid: 모르는 잔여 비트 %d — 커맨드를 버린다" % residue)
		return
	# 🔴 `rr <= rd`면 잔여가 **전부 파괴로 비워진 칸 위에** 떨어져 `_wet_one`·`_strike`가 통째로
	#  건너뛴다 ⇒ **에러 없이 잔여 0칸.** 주석으로만 적어 두면 다음 사람이 반경을 조이다 밟는다.
	#  ⚠ `residue == 0`(잔여 없는 폭발)은 정당하니 게이트한다 — 안 그러면 그 호출이 매번 짖는다.
	if residue != 0 and rr <= rd:
		push_error("CellGrid: 잔여 반경(%d)이 파괴 반경(%d) 이하다 — 잔여가 조용히 0이 된다" % [rr, rd])
		return

	_blast_destroy(cx, cy, rd)
	if fill_mat != Mat.EMPTY:
		_blast_fill(cx, cy, rf, fill_mat)
	if residue != 0:
		_blast_residue(cx, cy, rr, residue)


func _valid_radius(r: int) -> bool:
	if r >= 0 and r <= BLAST_R_MAX:
		return true
	push_error("CellGrid: 폭발 반경 %d가 범위(0~%d) 밖이다 — 커맨드를 버린다" % [r, BLAST_R_MAX])
	return false


## 🔴 `BEHAVIOR_STATIC`인 칸만 지운다 — 물을 지우면 위 주석의 「쏟아진다」가 사라진다.
func _blast_destroy(cx: int, cy: int, r: int) -> void:
	var r2 := r * r
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= H:
			continue
		var row := y << X_SHIFT
		var dy := y - cy
		var dy2 := dy * dy
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= W:
				continue
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			if _behavior[_mat[row | x]] != Mat.BEHAVIOR_STATIC:
				continue
			_write_cell(x, y, Mat.EMPTY)


func _blast_fill(cx: int, cy: int, r: int, mat: int) -> void:
	var r2 := r * r
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= H:
			continue
		var row := y << X_SHIFT
		var dy := y - cy
		var dy2 := dy * dy
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= W:
				continue
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			if _mat[row | x] != Mat.EMPTY:
				continue
			_write_cell(x, y, mat)


## ⚠ `_wet_one`·`_strike`가 각자 EMPTY·비전도를 걸러낸다 — 여기서 다시 판정하면 규칙이 두 벌이 된다.
func _blast_residue(cx: int, cy: int, r: int, residue: int) -> void:
	var r2 := r * r
	var wet := residue == Mat.FLAG_WET
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= H:
			continue
		var dy := y - cy
		var dy2 := dy * dy
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= W:
				continue
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			if wet:
				_wet_one(x, y)
			else:
				_strike(x, y)


## 🔴 **공개가 아니다.** 예전엔 공개 `reset()`이라 `apply()` 밖의 **두 번째 쓰기 문**이었고,
##  그물 10이 그걸 화이트리스트에 넣어 정상으로 굳히고 있었다(그물의 취지와 정반대).
##  ⇒ `CMD_RESET`으로 문 안에 넣었다. 커맨드가 넷이 됐지만 **문은 하나로 유지된다.**
func _reset() -> void:
	_mat.fill(0)
	_aux.fill(0)
	_flag.fill(0)
	_awake.fill(0)
	_awake_next.fill(0)
	_charge_front.clear()
	_charge_next.clear()
	_tick = 0


# ══════════════════════════════════════════════════════════════════
#  질의 — 전부 읽기 전용
# ══════════════════════════════════════════════════════════════════
# 🔴🔴 **`get_mat()`·`get_flag()`·`get_aux()`는 사본이 아니라 「살아 있는 뷰」다.**
#  `PackedByteArray`의 CoW를 믿고 「밖에서 고쳐도 안전하다」고 짜면 **에러 없이 틀린다** —
#  GDScript에서 돌려받은 배열에 `arr[0] = 9`를 하면 격자가 실제로 바뀐다(실측).
#  ⇒ 여기서 나간 배열에 **쓰지 마라.** 언어가 막아주지 않으니 규율로만 지켜진다.
#  사본이 필요하면 호출부에서 `.duplicate()`를 해라(틱당 36KB — 렌더 경로에는 넣지 마라).
#  🔴 격자를 바꾸는 문은 여전히 `apply(cmd)` 하나이고, 그걸 자동 그물이 지킨다.

func get_mat() -> PackedByteArray:
	return _mat


func get_flag() -> PackedByteArray:
	return _flag


func get_aux() -> PackedByteArray:
	return _aux


func get_tick() -> int:
	return _tick


## **다음 틱에 돌** 청크 수. 0이면 격자가 완전히 잠들었다는 뜻이다.
func awake_count() -> int:
	var n := 0
	for i in CHUNK_COUNT:
		if _awake_next[i] != 0:
			n += 1
	return n


## 이 칸이 전기를 통하나. 순수 질의다 — 격자를 안 바꾼다.
## ⚠ 소비자는 HUD다(마른 곳 번개가 「헛침」으로 **보여야** 측정 ②가 손에 잡힌다).
##  그 판정을 껍데기가 다시 구현하면 규칙이 두 벌이 된다.
func conducts_at(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	var i := (y << X_SHIFT) | x
	return _conducts(i, _flag[i])


func mat_at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return Mat.STONE  # 격자 밖 = 고체
	return _mat[(y << X_SHIFT) | x]


func flag_at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return 0
	return _flag[(y << X_SHIFT) | x]


func aux_at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return 0
	return _aux[(y << X_SHIFT) | x]


## 네이티브 `count()`라 36,864칸을 훑고도 ~5μs다(GDScript 루프는 ~520μs — 100배).
func count_material(mat: int) -> int:
	return _mat.count(mat)


## ⚠ 여기는 `count()`를 못 쓴다 — 그건 **값이 정확히 같은 것**만 세는데 이건 비트마스크다.
##  `count(FLAG_WET)`으로 바꾸면 WET+CHARGED인 셀(값 5)이 조용히 빠진다. ~520μs는 감수한다.
func count_flag(bit: int) -> int:
	var n := 0
	for i in CELL_COUNT:
		if (_flag[i] & bit) != 0:
			n += 1
	return n
