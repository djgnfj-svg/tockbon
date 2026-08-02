extends RefCounted
## 마법 투사체 시뮬 — **순수 객체다. 씬 트리를 모른다.**
##
## 🔴🔴 **투사체는 노드가 아니다.** 고정 크기 배열이고, 그리는 건 노드 하나가 통째로 한다.
##  이 결정이 사는 값 넷: ① `CellGrid`와 같은 순수성(서버가 씬 없이 돌리고 그물이 씬 없이 돈다)
##  ② 풀링이 불필요하다(배열 + 활성 개수가 곧 풀이다) ③ `add_child`-물리콜백 함정이 **소멸한다**
##  ④ `queue_free`+그룹 함정이 **소멸한다**. ⚠ 「투사체 = 노드」로 바꾸는 순간 ③④가 둘 다 돌아온다.
##
## ══ 🔴🔴 이 파일의 계약 — **정수만** ═══════════════════════════════
##  위치·속도는 **고정소수점 1/256셀**이다. `Vector2`(32비트 float) · `sqrt` · 삼각함수 ·
##  `randi()` · `Time` · `delta`가 **하나도 없다.** 화면 좌표로 옮기는 일은 렌더가 한다.
##
##  왜 이렇게까지 하나 — **락스텝에서 선을 넘는 건 `CMD_FIRE` 하나뿐이기 때문이다.**
##  비행도 폭발도 격자 변경도 **각 클라가 스스로 재현**해야 하므로, 비행이 결정론적이지 않으면
##  폭발 셀이 하나 어긋나고, 그 셀이 물길을 바꾸고, **두 클라의 세상이 영원히 다른 세상이 된다.**
##  ⇒ 「같은 float 연산이면 어차피 같은 답 아니냐」는 위험하다: `+ - *`는 IEEE-754가 비트까지
##   같지만 **`sqrt`·`sin`·`atan2`는 libm이라 플랫폼마다 다르고**, 조준 정규화가 정확히 거기다.
##
##  🔴 **`sin`/`cos` 테이블도 안 만든다.** 부팅 때 float으로 구우면 그 굽는 값이 다시 플랫폼
##   의존이 된다(1 ULP가 반올림 경계에 걸리면 그 각도만 영구 desync — 잡을 방법이 없다).
##   ⇒ 정규화는 **정수 뉴턴법 `_isqrt`** 하나로 하고, 발사할 때 **한 번만** 돈다.
##
##  🔴 **기존 결정성 그물은 이 계약을 원리적으로 못 지킨다** — 같은 프로세스의 두 인스턴스는
##   float도 똑같은 답을 낸다. `test_spell_auto.gd`의 **N12(소스 텍스트 스캔)**가 유일한 감지기다.
## ══════════════════════════════════════════════════════════════════

const CellGrid := preload("res://src/world/cells/cell_grid.gd")
const Mat := preload("res://src/world/cells/cell_materials.gd")
const Tuning := preload("res://src/world/spell/spell_tuning.gd")

## 고정소수점: 하위 8비트가 소수부다. 셀 좌표 = pos >> FP_SHIFT.
## 정밀도 4px / 256 = 0.0156px — 차고 넘친다.
## ⚠ `>>`는 산술 시프트라 **음수에서도 내림**이다(격자 밖에서도 셀 좌표가 안 튄다).
const FP_SHIFT := 8
const FP_ONE := 1 << FP_SHIFT
const FP_HALF := FP_ONE >> 1

## 조준 정규화의 중간 정밀도. 🔴 이게 없으면 짧은 조준 벡터에서 `_isqrt`의 절삭이
##  속도를 40%까지 부풀린다(예: 조준 (1,1)에서 isqrt(2)=1이라 속도가 √2배가 된다).
const AIM_SHIFT := 8

const SPEED_FP := Tuning.SPEED_CELLS << FP_SHIFT

## 커맨드 종류. 🔴 격자 커맨드와 **다른 키 이름**(`spell_kind`)을 쓴다 —
##  같은 `kind` 키를 공유하면 두 enum의 숫자가 겹쳐 `CellGrid.apply`가 엉뚱한 걸 실행한다.
const CMD_FIRE := 0

# ─── 상태 ─────────────────────────────────────────────────────────
## ⚠ **평행 배열이다.** `Array[Dictionary]`로 두면 틱마다 32개 딕셔너리를 만진다.
## ⚠ `PackedInt32Array`를 **인자로 넘기지 마라** — CoW 사본이 되어 쓰기가 조용히 증발한다
##  (`cell_grid.gd`가 `_charge_next`로 한 번 데였다). 전부 멤버로 두고 여기서 직접 만진다.
var _px := PackedInt32Array()
var _py := PackedInt32Array()
var _vx := PackedInt32Array()
var _vy := PackedInt32Array()
## 렌더 보간용 직전 위치. 🔴 시뮬은 이걸 **안 읽는다** — 순수하게 화면 몫이다.
var _prev_px := PackedInt32Array()
var _prev_py := PackedInt32Array()
var _tier := PackedByteArray()
var _element := PackedByteArray()
var _age := PackedInt32Array()
## 지금까지 씹은 고체 셀 수. 🔴 **틱을 넘어 유지된다** — 두꺼운 벽은 두 틱에 걸쳐 씹힐 수 있다.
var _chewed := PackedInt32Array()

## 🔴 슬롯 인덱스는 **틱마다 뒤바뀐다**(소멸이 swap-remove다). 렌더가 자취를 인덱스로 들고 있으면
##  투사체가 죽는 순간 남의 자취가 순간이동한다 — 에러 없이 화면만 이상해진다.
##  ⇒ 렌더는 반드시 `get_id()`로 짝을 맞춰라.
var _id := PackedInt32Array()
var _next_id := 0

var _count := 0
var _behavior := PackedByteArray()

## 상한을 넘긴 폭발이 앉는 자리. 🔴 **버리지 않고 다음 틱으로 민다** — 버리면 「가끔 안 터진다」가
##  되고, 그건 사용자에게 고장으로 읽힌다. 순서를 지키므로 결정론적이다.
var _pending: Array[Dictionary] = []


func _init() -> void:
	var n := Tuning.MAX_PROJECTILES
	_px.resize(n)
	_py.resize(n)
	_vx.resize(n)
	_vy.resize(n)
	_prev_px.resize(n)
	_prev_py.resize(n)
	_tier.resize(n)
	_element.resize(n)
	_age.resize(n)
	_chewed.resize(n)
	_id.resize(n)
	# 🔴 재료 거동은 **구워서 받는다** — 여기서 다시 정의하면 규칙이 두 벌이 된다(SKILL.md T5).
	_behavior = Mat.bake_behavior()


# ══════════════════════════════════════════════════════════════════
#  커맨드
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **선을 넘는 건 이것 하나다**(12바이트). 비행·폭발·격자 변경은 전부 각 클라의
##  결정론적 귀결이라 **폭발이 아무리 커도 대역폭은 0**이다.
##  ⚠ `adx`·`ady`는 **셀 단위 정수 차이**다 — 마우스 float이 여기서 딱 한 번 양자화된다.
static func cmd_fire(ox: int, oy: int, adx: int, ady: int, tier: int, element: int) -> Dictionary:
	return {
		"spell_kind": CMD_FIRE, "ox": ox, "oy": oy,
		"adx": adx, "ady": ady, "tier": tier, "element": element,
	}


## 위력 단 + 원소 → 격자 커맨드.
## 🔴 **위력 표가 `CellGrid`에 안 들어가는 이유가 이 함수다.** 「위력 → 반경」은 게임 규칙이고
##  `CellGrid`는 격자 도구다. 표를 격자에 넣으면 시뮬 코어가 밸런스를 알게 되고, 원소가 늘 때마다
##  `cell_grid.gd`를 열게 된다.
## ⚠ **인자 검증은 `fire()`가 이미 했다** — 여기는 검증하지 않는다(`_move_into_empty`가
##  「도착지가 EMPTY다」를 호출부에 맡기는 것과 같은 계약이다). 밖에서 부르려면 단·원소를 먼저 봐라.
static func blast_cmd(x: int, y: int, tier: int, element: int) -> Dictionary:
	var t: Dictionary = Tuning.SIM_TIERS[tier]
	var e: Dictionary = Tuning.ELEM_DEFS[element]
	return CellGrid.cmd_blast(
		x, y, int(t["rd"]), int(t["rr"]), int(e["residue"]), int(e["fill"]), int(t["fill_r"]))


## 발사. 받아들였으면 true.
## ⚠ **false가 곧 에러는 아니다** — 상한에 걸렸거나 조준이 0이면 조용히 버리는 게 맞다
##  (원점을 그대로 클릭하는 건 정상 입력이다). 모르는 단·원소만 짖는다.
func fire(cmd: Dictionary) -> bool:
	var tier := int(cmd.get("tier", -1))
	if tier < 0 or tier >= Tuning.SIM_TIERS.size():
		push_error("SpellSim: 모르는 위력 단 %d — 발사를 버린다" % tier)
		return false
	var element := int(cmd.get("element", -1))
	if not Tuning.ELEM_ALL.has(element):
		push_error("SpellSim: 모르는 원소 %d — 발사를 버린다" % element)
		return false
	if _count >= Tuning.MAX_PROJECTILES:
		return false

	var adx := int(cmd.get("adx", 0))
	var ady := int(cmd.get("ady", 0))
	var len2 := adx * adx + ady * ady
	if len2 <= 0:
		return false
	# 🔴 유일한 양자화 지점이자 유일한 제곱근이다. 비행 중에는 다시 안 돈다.
	var norm := _isqrt(len2 << (AIM_SHIFT + AIM_SHIFT))
	if norm <= 0:
		return false

	var i := _count
	_px[i] = (int(cmd.get("ox", 0)) << FP_SHIFT) + FP_HALF
	_py[i] = (int(cmd.get("oy", 0)) << FP_SHIFT) + FP_HALF
	_prev_px[i] = _px[i]
	_prev_py[i] = _py[i]
	_vx[i] = (adx << AIM_SHIFT) * SPEED_FP / norm
	_vy[i] = (ady << AIM_SHIFT) * SPEED_FP / norm
	_tier[i] = tier
	_element[i] = element
	_age[i] = 0
	_chewed[i] = 0
	_id[i] = _next_id
	_next_id += 1
	_count = i + 1
	return true


func reset() -> void:
	_count = 0
	_next_id = 0
	_pending.clear()


# ══════════════════════════════════════════════════════════════════
#  틱
# ══════════════════════════════════════════════════════════════════

## 한 틱 진행하고 **이번 틱에 실제로 터진 폭발**을 돌려준다(연출용 이벤트).
##
## 🔴🔴 **폭발을 여기서 직접 `grid.apply()` 한다 — 껍데기에 맡기지 않는다.**
##  설계는 「껍데기가 폭발 커맨드를 적용한다」로 적었지만, 그러면 **결정론이 껍데기의 성실함에
##  달린다.** 껍데기는 프로토타입이라 갈아엎히고, 서버는 껍데기를 안 쓴다.
##  ⇒ `CMD_BLAST`는 **시뮬이 자기 자신에게 거는 내부 커맨드**다(설계 §9의 네 번째 줄 그대로).
##  ⚠ 격자를 바꾸는 문은 여전히 `CellGrid.apply(cmd)` 하나다 — 여기서 `_mat`을 만지지 않는다.
##
## 🔴 **호출 순서가 계약이다**(설계 §6):
##    1. 외부 커맨드 배수  2. `grid.step()`  3. `spell.step(grid)`
##  투사체는 **셀이 움직인 뒤의 격자**를 상대로 난다. 순서를 바꾸면 결과가 달라진다.
##  ⚠ 그래서 구멍은 이번 틱에 보이고, 쏟아지는 물은 **다음 틱**에 흐르기 시작한다(눈에 안 보인다).
func step(grid: CellGrid) -> Array[Dictionary]:
	var i := 0
	while i < _count:
		if _advance(grid, i):
			i += 1
		else:
			_remove(i)
	return _flush_blasts(grid)


## 투사체 하나. 살아남으면 true.
func _advance(grid: CellGrid, i: int) -> bool:
	_age[i] += 1
	if _age[i] > Tuning.LIFETIME_TICKS:
		return false

	var x0 := _px[i]
	var y0 := _py[i]
	var x1 := x0 + _vx[i]
	var y1 := y0 + _vy[i]
	_prev_px[i] = x0
	_prev_py[i] = y0
	_px[i] = x1
	_py[i] = y1
	return _walk(grid, i, x0 >> FP_SHIFT, y0 >> FP_SHIFT, x1 >> FP_SHIFT, y1 >> FP_SHIFT)


## 🔴🔴 **정수 Bresenham으로 지나간 칸을 전부 밟는다 — 「도착 칸만 검사」로 짜지 마라.**
##  틱당 10셀을 뛰므로 도착 칸만 보면 **1~2타일 벽을 그냥 통과한다.** 한 프레임이라
##  **눈으로 절대 못 본다** — 사용자에게는 「가끔 안 터진다」로만 보인다(N6이 그 자리다).
##
## ⚠ **시작 칸은 검사하지 않는다.** 지난 틱에 이미 봤고(통과했으니 살아 있다), 다시 세면
##  두꺼운 벽에서 관통 예산이 한 칸씩 덜 남는다. 첫 틱의 시작 칸 = 사용자가 고른 발사 원점이다.
## ⚠ Bresenham은 **대각 모서리를 스쳐 지나간다**(연속 선분이 닿는 칸을 다 밟지는 않는다).
##  지형 최소 두께가 4셀(1타일)이라 지금은 안 걸린다. 걸리면 답은 supercover DDA고, 그때 고쳐라.
func _walk(grid: CellGrid, i: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var cx := x0
	var cy := y0
	var pierce := int(Tuning.SIM_TIERS[_tier[i]]["pierce"])

	# 🔴 `while`이 아니라 걸음 수 상한이 있는 `for`다 — 부호가 한 번만 어긋나도
	#  `while`은 프레임을 통째로 먹고 멈춘다(에러 없이 게임이 얼어붙는다).
	var steps := dx - dy
	for _k in steps:
		if cx == x1 and cy == y1:
			return true
		var e2 := err + err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy

		if cx < 0 or cx >= CellGrid.W or cy < 0 or cy >= CellGrid.H:
			return false  # 격자 밖 = 폭발 없이 소멸
		if _behavior[grid.mat_at(cx, cy)] != Mat.BEHAVIOR_STATIC:
			continue  # 🔴 물은 투명하다 — 안 멈춘다. 「폭포 너머로 쏜다」가 공짜로 된다
		_chewed[i] += 1
		if _chewed[i] > pierce:
			_pending.append({
				"x": cx, "y": cy, "tier": _tier[i], "element": _element[i], "id": _id[i],
			})
			return false
	return true


## 밀린 것부터 상한만큼 터뜨린다.
func _flush_blasts(grid: CellGrid) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while not _pending.is_empty() and out.size() < Tuning.MAX_BLASTS_PER_TICK:
		var b: Dictionary = _pending.pop_front()
		grid.apply(blast_cmd(int(b["x"]), int(b["y"]), int(b["tier"]), int(b["element"])))
		out.append(b)
	return out


## 마지막 슬롯을 끌어와 덮는다. ⚠ **인덱스가 뒤바뀐다** — 위 `_id` 주석을 봐라.
func _remove(i: int) -> void:
	var last := _count - 1
	if i != last:
		_px[i] = _px[last]
		_py[i] = _py[last]
		_vx[i] = _vx[last]
		_vy[i] = _vy[last]
		_prev_px[i] = _prev_px[last]
		_prev_py[i] = _prev_py[last]
		_tier[i] = _tier[last]
		_element[i] = _element[last]
		_age[i] = _age[last]
		_chewed[i] = _chewed[last]
		_id[i] = _id[last]
	_count = last


## 정수 제곱근(뉴턴법). 🔴 **이 다섯 줄이 삼각함수·`sqrt`·각도 테이블을 통째로 대신한다.**
##  발사할 때 한 번 돌고 비행 중엔 안 돈다.
## ⚠ 오버플로 여유: 입력 최대 = 2 × 256² << 16 ≈ 8.6e9로 int64에 압도적으로 남는다.
func _isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


# ══════════════════════════════════════════════════════════════════
#  질의 — 전부 읽기 전용 (렌더 · 그물)
# ══════════════════════════════════════════════════════════════════
# 🔴🔴 아래 배열들은 **사본이 아니라 「살아 있는 뷰」다**(`CellGrid.get_mat()`과 같다).
#  돌려받은 `PackedInt32Array`에 쓰면 시뮬이 실제로 바뀐다. **쓰지 마라** — 언어가 안 막아준다.
# ⚠ 배열 길이는 늘 `MAX_PROJECTILES`다. **살아 있는 건 앞에서 `active_count()`개뿐이고**,
#  그 뒤는 지난 틱의 시체다. 길이로 순회하면 유령이 그려진다.

func active_count() -> int:
	return _count


func get_px() -> PackedInt32Array:
	return _px


func get_py() -> PackedInt32Array:
	return _py


func get_prev_px() -> PackedInt32Array:
	return _prev_px


func get_prev_py() -> PackedInt32Array:
	return _prev_py


func get_tier() -> PackedByteArray:
	return _tier


func get_element() -> PackedByteArray:
	return _element


## 🔴 렌더가 자취를 짝지을 유일한 안전한 열쇠. 슬롯 인덱스는 매 틱 뒤바뀐다.
func get_id() -> PackedInt32Array:
	return _id
