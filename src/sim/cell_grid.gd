extends RefCounted
## 셀 격자 시뮬 코어. **순수 객체다 — 씬 트리를 모른다.**
##
## 🔴🔴 `Node`가 아니라 `RefCounted`인 게 이 파일의 가장 중요한 성질이다.
##  `Input`·`Time`·`randi()`·`get_viewport()`·씬 트리에 **절대 접근하지 않는다.**
##  ⇒ 서버가 헤드리스로 N개를 돌릴 수 있고, 그물이 씬 없이 돈다.
##
## 🔴🔴 **격자를 바꾸는 문은 `apply(cmd)` 하나다.** 직접 쓰기 코드는 이 파일 안에만 있다.
##  입력 핸들러가 `_mat[i] = STONE`을 하는 순간 그게 재작성 자리가 된다.
##
## ⚠ **청크 재우기가 없다.** 이 단계에는 **움직이는 셀이 0개**라 잴 대상이 없고,
##  불은 파면 목록이라 청크와 독립이다(GDD 「상태는 파면 목록으로 돈다」). 물이 들어올 때 만든다.
##
## ══ 🔴🔴 물을 만들 때 필요한 **순회 순서 계약** ═══════════════════
##  v1이 비싸게 얻었고 **v1 파일은 단계 7에서 지워졌다.** 그래서 여기 인라인한다 —
##  「지워진 파일에서 가져와라」는 갈 데가 없는 참조다.
##  전문은 `git show e19e2a0:src/world/cells/cell_grid.gd`(`_sweep` 주석)에 있다.
##
##  **단일 버퍼 물 시뮬의 전제다.** 이중 버퍼를 쓰면 매 틱 격자 전체를 복사해야 하고,
##  그건 「활성 영역만 돈다」와 정면으로 충돌한다. ⇒ 대신 **순회 순서**로 이중 이동을 없앤다.
##
##  🔴 불변량 하나: **셀이 이동할 수 있는 모든 도착지는, 이번 틱에 이미 지났거나 아예 안 도는 자리여야 한다.**
##    · 밴드(청크 행)를 **아래 → 위**로     ⇒ y+1은 언제나 먼저 지났다
##    · 밴드 안에서 행도 **아래 → 위**로    ⇒ 같은 밴드 안에서도 y+1이 먼저다
##    · 행 안의 열은 **선호 방향 dir의 반대**로 ⇒ dir로 미끄러지는 도착 열이 먼저다
##
##  ⚠ **밴드 안에서 「청크 → 행」이 아니라 「행 → 청크」로 돈다.** 청크를 바깥에 두면
##   **대각 아래 이동이 청크 열 경계에서 깨진다** — 같은 밴드의 옆 청크는 아직 안 돈 상태라
##   거기로 떨어진 물이 같은 틱에 또 움직인다. 비용은 밴드당 플래그 검사 16 → 256회뿐이다.
##  ⚠ dir이 매 틱 뒤집히므로 **좌우 편향이 없다.** v1은 그걸 재는 그물을 갖고 있었다 —
##   물을 여기 올리는 사람이 그 그물도 같이 가져와야 한다(지금은 잴 대상이 없어 없다).
## ══════════════════════════════════════════════════════════════════

const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")

# ─── 격자 수치 ─────────────────────────────────────────────────────
## 🔴 뷰포트가 1920×1080px이고 셀이 4px이라 **보이는 건 480×270셀**이다.
##  격자를 그보다 크게 잡은 것은 여백이고, **무대는 보이는 끝 안에 있어야 한다**(`stage.gd` MAP 주석).
## ⚠ 32px 전환에서 ×2 됐다(전: 256×144). **셀은 여전히 4px이다** — 바뀐 것은 뷰포트다.
## 🔴🔴 **2026-08-06, 사용자가 그린 "1스테이지" 실물(312×126타일)을 담으려고 다시 키웠다**
##  (전: 512×288셀 = 64×36타일). W는 2의 거듭제곱이어야 해서 312타일(2496셀)이 그대로 안 들어가고
##  **4096셀(512타일)로 반올림됐다** — 오른쪽에 약 200타일 여백이 남는다. `terrain_baker.gd`가
##  그린 영역이 이 용량을 넘으면 조용히 안 자르고 여기서 짖는다(굽기 실패) — 더 커지면 또 온다.
const W := 4096
const H := 1008

## 🔴 `idx = (y << X_SHIFT) | x`. W가 2의 거듭제곱이라 **곱셈이 사라진다** —
##  내부 루프에서 상시 계산되는 값이라 이게 그대로 성능이다.
##  ⚠ W를 바꾸면 여기도 바꿔야 한다. `_init()`이 안 맞으면 짖는다.
const X_SHIFT := 12
const X_MASK := W - 1
## 🔴🔴 **4,128,768셀이다.** 2026-08-06에 맵이 커지며 28배가 됐고(전: 147,456),
##  그 값에 기대던 실측 주석 넷이 안 따라와서 **하루 동안 조용히 거짓이었다**(2026-08-07에 다시 쟀다).
##  ⇒ **W·H를 바꾸는 사람은 이 상수를 읽는 곳이 아니라 「147,456」 같은 숫자가 박힌
##   주석을 찾아야 한다.** 코드는 파생되지만 주석은 안 따라온다.
##
## 🔴🔴 **물을 만들 사람이 제일 먼저 알아야 할 값이다** — GDScript로 이 격자를 **한 번 훑는 데
##  62,676μs**(2026-08-07 실측, 헤드리스). 20Hz 틱 예산이 50,000μs이므로 **훑기 한 번이 예산의 125%**다.
##  ⇒ **청크 재우기 없이는 물이 원리적으로 불가능하다.** 「일단 만들고 느리면 최적화」가 안 되는 자리다.
const CELL_COUNT := W * H  # 4,128,768

# ─── 커맨드 — 격자를 바꾸는 유일한 문 ──────────────────────────────
enum { CMD_FILL = 0, CMD_RESET = 1, CMD_BLAST = 2, CMD_IGNITE = 3, CMD_CARVE = 4 }

# ─── 상태 ─────────────────────────────────────────────────────────
var _mat := PackedByteArray()   # 재료 id
var _flag := PackedByteArray()  # 상태 비트 (하위 4비트만)
var _aux := PackedByteArray()   # 🔴 의미는 `cell_materials.gd`의 `_aux` 절에 있다

## 부팅 때 구운 평면 테이블 — 내부 루프는 이것만 인덱싱한다.
var _behavior := PackedByteArray()
var _indestructible := PackedByteArray()
var _fuel := PackedByteArray()

## 🔴🔴 **불의 파면 목록 — 지금 타는 셀의 인덱스다.** 격자를 훑지 않는다.
##  이게 GDD의 「상태는 파면 목록으로 돈다」이고, **청크 재우기와 독립**이라 격자가 잠들어 있어도
##  불은 탄다. ⚠ v1의 전하 파면이 같은 구조였고 검증됐다.
##
## ⚠ **멤버로 두고 여기서 직접 민다.** `PackedInt32Array`를 인자로 넘기면 CoW 사본이 되어
##  `append`가 **에러 없이 증발한다**(v1 `_charge_next`가 데인 자리).
## 🔴 v1에서 번개가 안 꺼진 원인은 TTL이 아니라 **물의 왕복 버그**였다(움직이는 물이 매 틱
##  파면에 재등록됐다). **불은 안 움직이니 그 문제가 원리적으로 없다.**
var _burning := PackedInt32Array()

## 셀 → `_burning` 안의 자리. -1이면 안 탄다. 🔴 **파면의 소속을 정하는 단일 소스다**
##  (`_flag`의 BURNING 비트는 셰이더가 읽는 **거울**이고, 둘은 항상 같이 움직인다).
## ⚠ 이게 없으면 지워진 칸을 파면에서 빼는 데 **선형 탐색**이 필요하고, 폭발 하나가 수백 칸을
##  지우므로 그게 곧 O(칸수 × 파면길이)가 된다. 590KB로 그걸 O(1)로 바꾼다.
var _burn_slot := PackedInt32Array()

var _tick := 0

## 마지막으로 읽어 간 뒤에 실제로 쓴 셀 수. 🔴 **「화면을 다시 올려야 하나」의 단일 소스다.**
##  격자를 바꾸는 문이 `_write_cell` 하나이므로 여기 셈이 곧 정확하다.
## ⚠ 껍데기가 따로 걸쇠를 들면 규칙이 두 벌이 되고, **커맨드 큐를 안 지나는 변경**(폭발은
##  투사체 시뮬이 직접 부른다)이 그 걸쇠를 조용히 빠뜨린다 — 그러면 구멍이 화면에 안 뜬다.
var _changed := 0


func _init() -> void:
	_mat.resize(CELL_COUNT)
	_flag.resize(CELL_COUNT)
	_aux.resize(CELL_COUNT)
	_burn_slot.resize(CELL_COUNT)
	_burn_slot.fill(-1)
	_behavior = Mat.bake_behavior()
	_fuel = Mat.bake_fuel()
	_indestructible = Mat.bake_indestructible()
	# 조용히 어긋나는 자리라 부팅에서 짖게 한다 — 인덱싱이 통째로 틀리면
	# 증상이 「격자가 이상하다」로만 나온다.
	if (1 << X_SHIFT) != W:
		push_error("CellGrid: X_SHIFT(%d)가 W(%d)와 안 맞는다" % [X_SHIFT, W])


# ══════════════════════════════════════════════════════════════════
#  틱
# ══════════════════════════════════════════════════════════════════

## 한 틱 진행한다.
## ⚠ **일한 셀 수를 돌려주지 않는다.** 「지금 몇 칸이 타나」는 `burning_count()`가 답하고,
##  그 값은 **이 틱이 끝난 뒤에도 계속 맞다.** 반환값으로 주면 껍데기가 그걸 들고 있게 되는데,
##  틱 순서가 `grid.step()` → `spell.step()`이라 **폭발이 붙인 불이 그 값에 안 들어간다** —
##  실측으로 HUD가 폭발 틱에 0을 찍고 다음 틱에 104를 찍었다(한 틱 지연).
func step() -> void:
	_tick += 1
	_burn()


## 🔴🔴 **불 한 틱.** 격자를 안 훑고 파면 목록만 돈다.
##
## ⚠ **뒤에서 앞으로 돈다.** 앞에서 돌면서 swap-remove 하면 방금 끌어온 셀을 건너뛴다.
##  그리고 번지면서 목록이 **뒤로 자라므로**, 시작 시점 길이(`n`)까지만 보는 것이 계약이다 —
##  이번 틱에 붙은 불이 같은 틱에 또 번지면 한 틱에 격자를 가로지른다.
## 🔴 유한성: 연료는 매 틱 반드시 줄고 0에서 셀이 EMPTY가 되며, EMPTY는 연료가 0이라
##  **다시 못 붙는다.** ⇒ 불은 반드시 꺼진다(판정 5).
func _burn() -> void:
	var n := _burning.size()
	if n == 0:
		return
	var spread := (_tick % Tuning.FIRE_SPREAD_TICKS) == 0
	var i := n - 1
	while i >= 0:
		var idx := _burning[i]
		var fuel := _aux[idx] - Tuning.FIRE_BURN_PER_TICK
		if fuel <= 0:
			# 🔴 다 탄 자리는 **빈칸이 된다.** 재료를 그대로 두면 불이 지나간 흔적이 화면에
			#  하나도 안 남아서, 「폭발 1번 + 잔불 8갈래」의 잔불 쪽 증거가 통째로 사라진다.
			# ⚠ 파면에서 빼는 것도 `_write_cell`이 같이 한다(swap-remove라 자리 `i`가 뒤에서
			#  끌려온 칸으로 바뀐다) — 여기서 또 빼면 그 칸을 건너뛴다.
			_write_cell(idx, Mat.EMPTY)
			i -= 1
			continue
		_aux[idx] = fuel
		if spread:
			var x := idx & X_MASK
			var y := idx >> X_SHIFT
			# 🔴 **네 방향이다.** 대각까지 열면 1셀 틈을 사선으로 새서 「돌에서 멈춘다」가 흐려진다.
			_ignite_cell(x - 1, y)
			_ignite_cell(x + 1, y)
			_ignite_cell(x, y - 1)
			_ignite_cell(x, y + 1)
		i -= 1


## 셀 하나에 불을 붙인다. 붙었으면 true.
## 🔴🔴 **「탈 것이 있는 곳으로만」이 이 함수의 세 줄이다**(GDD). 돌은 연료가 0이라 여기서 멈추고,
##  빈칸도 연료가 0이라 **불이 허공을 못 건넌다.**
func _ignite_cell(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	var i := (y << X_SHIFT) | x
	# 🔴 소속은 자리 표로 본다 — `_flag`는 거울이라, 둘 중 하나로만 판정하면
	#  둘이 갈라지는 날 같은 칸이 파면에 **두 번** 들어간다.
	if _burn_slot[i] >= 0:
		return false
	var fuel := _fuel[_mat[i]]
	if fuel <= 0:
		return false
	# ⚠ 안전망이다. 여기 걸리는 게 보이면 값이 아니라 **나무를 얼마나 뒀나**를 봐라.
	if _burning.size() >= Tuning.MAX_BURNING:
		return false
	_flag[i] |= Mat.FLAG_BURNING
	_aux[i] = fuel
	_burn_slot[i] = _burning.size()
	_burning.append(i)
	# 🔴 재료는 그대로지만 **화면은 바뀐다**(셰이더가 `_flag`를 읽는다). 안 세면 불이 안 뜬다.
	_changed += 1
	return true


# ══════════════════════════════════════════════════════════════════
#  커맨드
# ══════════════════════════════════════════════════════════════════

static func cmd_fill(x0: int, y0: int, x1: int, y1: int, mat: int) -> Dictionary:
	return {"kind": CMD_FILL, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "mat": mat}


## ⚠ 틱 번호도 0으로 돌아간다 — 「세상을 새로 연다」는 뜻이라 그게 맞다.
static func cmd_reset() -> Dictionary:
	return {"kind": CMD_RESET}


## **파괴 + 점화.** v1의 채우기·잔여는 물이 없으니 없다.
##
## 🔴🔴 **`ignite_r`가 `rd`보다 커야 한다.** 파괴가 먼저라 `rd` 안은 EMPTY = 연료 0이 되고,
##  두 반경이 같으면 **자기가 태울 것을 자기가 먼저 지운다.** 불이 원리적으로 안 붙는데
##  에러는 하나도 안 난다 — `net_fire`가 그 부등식을 계약으로 잰다.
## ⚠ 인자를 기본값으로 두지 않는 이유: 안 넘긴 호출부가 조용히 「불 없는 폭발」이 된다.
##
## 🔴 **커맨드라서 대역폭이 공짜다** — 네 정수를 보내면 각 클라가 같은 원을 지우고 같은 고리를
##  태운다. 폭발이 아무리 커도 네트워크 비용이 안 는다(GDD 멀티).
static func cmd_blast(x: int, y: int, rd: int, ignite_r: int) -> Dictionary:
	return {"kind": CMD_BLAST, "x": x, "y": y, "rd": rd, "ignite_r": ignite_r}


## **점화만.** 🔴 지형을 한 칸도 안 부순다 — 룬 흔적이 지나는 문이다.
##  ⚠ `cmd_blast(x, y, 0, r)`로도 같은 일이 되지만 **이름을 따로 둔다.**
##   「폭발인데 반경이 0」은 읽는 사람에게 거짓말이고, 커맨드 이름은 로그와 네트워크에 남는다.
static func cmd_ignite(x: int, y: int, r: int) -> Dictionary:
	return {"kind": CMD_IGNITE, "x": x, "y": y, "r": r}


## **파기만.** 🔴 불을 한 칸도 안 붙인다 — 모든 착탄이 지나는 문이다(`spell_sim._impact` 의 ①).
##  ⚠ 바로 위 `cmd_ignite` 의 **정확한 거울이고, 같은 이유로 이름을 따로 둔다.**
##   `cmd_blast(x, y, r, 0)` 로도 같은 일이 되지만 「폭발인데 점화 반경이 0」은 읽는 사람에게
##   거짓말이다. 그리고 대가가 셋 더 있다 — ① 바로 위 `cmd_blast` 가 못 박은 `ignite_r > rd`
##   계약을 정면으로 깨는데 **런타임에 아무도 안 짖는다**(그물은 **표**를 재지 **호출**을 안 잰다)
##   ② `cmd_blast` ↔ `spell_sim._notify_blast` 의 짝이 깨진다 ③ 착탄마다 `CMD_BLAST` 가
##   로그와 네트워크에 남는다.
## 🔴 **부수효과는 두 벌이 안 된다** — `_disc(…, true)` → `_write_cell` 하나를 같이 쓴다.
static func cmd_carve(x: int, y: int, r: int) -> Dictionary:
	return {"kind": CMD_CARVE, "x": x, "y": y, "r": r}


func apply(cmd: Dictionary) -> void:
	match int(cmd.get("kind", -1)):
		CMD_FILL:
			_fill_rect(int(cmd["x0"]), int(cmd["y0"]), int(cmd["x1"]), int(cmd["y1"]),
				int(cmd["mat"]))
		CMD_RESET:
			_reset()
		CMD_BLAST:
			_blast(int(cmd["x"]), int(cmd["y"]), int(cmd["rd"]), int(cmd["ignite_r"]))
		CMD_IGNITE:
			var r := int(cmd["r"])
			if r > 0:
				_disc(int(cmd["x"]), int(cmd["y"]), r, false)
		CMD_CARVE:
			var cr := int(cmd["r"])
			if cr > 0:
				_disc(int(cmd["x"]), int(cmd["y"]), cr, true)
		_:
			push_error("CellGrid.apply: 모르는 커맨드 %s" % cmd)


## 🔴 `apply()`는 멀티에서 **클라가 서버에 보내는 문**이다. 검증 없이 두면 범위 밖 id 하나가
##  `_behavior[mat]`에서 **매 틱 엔진 「Index out of bounds」**를 낸다 — 그건 `SCRIPT ERROR`
##  grep에 안 걸리는 침묵사다. 255를 넘으면 `PackedByteArray`가 말없이 하위 8비트로 자르고,
##  셰이더는 `clamp`라 마젠타로 뜬다 ⇒ **시뮬과 렌더가 서로 다른 방식으로** 틀어진다.
## ⚠ 내부 루프가 아니라 **커맨드 경계**에서 한 번만 본다 — 채우기 하나가 `_write_cell`을 수천 번 돈다.
func _valid_mat(mat: int) -> bool:
	if mat >= 0 and mat < Mat.SLOT_COUNT and Mat.DEFS.has(mat):
		return true
	push_error("CellGrid: 모르는 재료 id %d — 커맨드를 버린다" % mat)
	return false


func _fill_rect(x0: int, y0: int, x1: int, y1: int, mat: int) -> void:
	if not _valid_mat(mat):
		return
	var ax := maxi(0, mini(x0, x1))
	var bx := mini(W - 1, maxi(x0, x1))
	var ay := maxi(0, mini(y0, y1))
	var by := mini(H - 1, maxi(y0, y1))
	for y in range(ay, by + 1):
		var row := y << X_SHIFT
		for x in range(ax, bx + 1):
			_write_cell(row | x, mat)


## 🔴🔴 **정수 원반이다.** `dx*dx + dy*dy <= rd*rd` — `sqrt`가 한 번도 안 나온다.
##  그래야 각 클라가 **같은 셀 집합**을 지운다. 하나만 어긋나도 그 셀이 지형을 바꾸고,
##  그 뒤로 두 클라의 세상이 영원히 다른 세상이 된다.
##
## ⚠ 격자 밖은 **클램프**다(자르지 않고 버리지도 않는다) — 벽 모서리에 터진 폭발이
##  「반쪽만 파인다」가 맞는 그림이고, 범위 검사를 안 하면 `_mat[i]`가 매 셀 엔진 에러를 낸다.
## ⚠ rd ≤ 0은 조용히 아무 일도 안 한다 — 「반경 0인 폭발」은 정상 입력이 아니지만
##  짖을 만한 것도 아니다(확산 하한이 붙으면 실제로 0이 나올 수 있다).
func _blast(cx: int, cy: int, rd: int, ignite_r: int) -> void:
	# 🔴 **파괴가 먼저다.** 순서를 뒤집으면 방금 붙인 불을 그 자리에서 지운다.
	if rd > 0:
		_disc(cx, cy, rd, true)
	if ignite_r > 0:
		_disc(cx, cy, ignite_r, false)


## 정수 원반을 훑는다. `destroy`면 지우고, 아니면 불을 붙인다.
## ⚠ 두 패스가 같은 훑기를 쓰는 게 요점이다 — 따로 짜면 한쪽만 원이고 한쪽만 네모가 되는 날이 온다.
func _disc(cx: int, cy: int, rd: int, destroy: bool) -> void:
	var r2 := rd * rd
	var ax := maxi(0, cx - rd)
	var bx := mini(W - 1, cx + rd)
	var ay := maxi(0, cy - rd)
	var by := mini(H - 1, cy + rd)
	for y in range(ay, by + 1):
		var dy := y - cy
		var dy2 := dy * dy
		var row := y << X_SHIFT
		for x in range(ax, bx + 1):
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			if destroy:
				# 🔴 못 부시는 재질(`Mat.BEDROCK` 등)은 여기서 걸러진다 — `_write_cell`을 아예 안 부른다.
				if _indestructible[_mat[row | x]] == 1:
					continue
				_write_cell(row | x, Mat.EMPTY)
			else:
				_ignite_cell(x, y)


## 🔴 재료를 쓰면 `_flag`·`_aux`도 같이 지운다 — 안 지우면 탄 자리에 새 나무를 채웠을 때
##  「이미 다 탄 나무」가 되어 불이 안 붙는다. 에러 없이 규칙만 틀어진다.
func _write_cell(i: int, mat: int) -> void:
	# 🔴🔴 **파면에서도 뺀다.** 안 빼면 지워진 칸의 인덱스가 `_burning`에 유령으로 남는다.
	#  지금은 다음 틱에 스스로 빠지지만(연료가 0이라), 그 자가 치유는 **「지워진 자리가 그대로
	#  비어 있다」에 기대고 있다.** 물이나 지형 재생성이 들어와 그 자리가 나무로 다시 채워지면
	#  (a) `_aux`가 0이라 **새 나무가 다음 틱에 빈칸이 되고** (b) 중복 가드가 통과해 **같은 칸이
	#  파면에 두 번** 들어간다. ⇒ 값이 싸니(자리 표로 O(1)) 지금 막는다.
	# ⚠ 그리고 `burning_count()`가 곧 계기다 — 한 틱이라도 41% 부푼 값은 잴 바닥이 못 된다(실측).
	_unburn(i)
	_mat[i] = mat
	_flag[i] = 0
	_aux[i] = 0
	_changed += 1


## 파면에서 뺀다. 자리 표 덕에 O(1)이다.
## ⚠ 마지막 칸을 끌어와 덮으므로 **순서가 바뀐다** — 결정론은 유지된다(인덱스 연산만 한다).
func _unburn(i: int) -> void:
	var at := _burn_slot[i]
	if at < 0:
		return
	var last := _burning.size() - 1
	var moved := _burning[last]
	_burning[at] = moved
	_burn_slot[moved] = at
	_burning.resize(last)
	# ⚠ **끌어온 칸이 자기 자신일 때가 있다**(`at == last`). 그래서 이 줄이 맨 뒤여야 한다 —
	#  위에서 `_burn_slot[moved]`가 `i`를 되살려 놓기 때문이다.
	#  🔴 실측: 앞으로 옮기면 폭발 직후 고아 9칸 · 숲이 다 탄 뒤 100칸이 되고,
	#   그 칸들은 중복 가드에 막혀 **영영 다시 못 탄다.** `net_fire`가 그걸 잰다.
	_burn_slot[i] = -1


func _reset() -> void:
	_mat.fill(0)
	_flag.fill(0)
	_aux.fill(0)
	# 🔴 파면도 비운다. 안 비우면 새 지형의 셀 인덱스에 옛 불이 그대로 앉아 있고,
	#  거기는 연료가 없으니 **한 틱 뒤 그 칸이 빈칸이 된다** — 새 무대에 구멍이 뚫린다.
	_burning.clear()
	_burn_slot.fill(-1)
	_tick = 0
	# `fill`은 `_write_cell`을 안 지나므로 여기서 직접 센다. 안 세면 리셋 뒤 첫 화면이
	# 옛 지형인 채로 남는다(다음 폭발이 있을 때까지).
	_changed += CELL_COUNT


# ══════════════════════════════════════════════════════════════════
#  질의 — 전부 읽기 전용
# ══════════════════════════════════════════════════════════════════
# 🔴🔴 **`get_mat()`·`get_flag()`는 사본이 아니라 「살아 있는 뷰」다.**
#  `PackedByteArray`의 CoW를 믿고 「밖에서 고쳐도 안전하다」고 짜면 **에러 없이 틀린다** —
#  GDScript에서 돌려받은 배열에 `arr[0] = 9`를 하면 격자가 실제로 바뀐다(v1 실측).
#  ⇒ 여기서 나간 배열에 **쓰지 마라.** 언어가 막아주지 않으니 규율로만 지켜진다.

func get_mat() -> PackedByteArray:
	return _mat


func get_flag() -> PackedByteArray:
	return _flag


func get_tick() -> int:
	return _tick


## 마지막으로 읽어 간 뒤에 바뀐 셀 수. ⚠ **읽으면 0으로 돌아간다** — 두 번 읽으면
##  두 번째는 0이다. 껍데기가 「화면을 다시 올리나」를 이걸로만 판단한다.
func consume_changed() -> int:
	var n := _changed
	_changed = 0
	return n


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


## 🔴🔴 **「고체인가」의 단일 소스다.** 캐릭터도 투사체도 이걸 부른다 —
##  각자 `mat_at(x,y) != EMPTY`로 판정하면 재료가 늘 때 한쪽만 안 따라오고,
##  그건 「탄은 뚫는데 캐릭터는 막힌다」로만 보인다.
## ⚠ 격자 밖은 고체다(`mat_at`) — 그래서 캐릭터도 탄도 격자를 못 벗어난다.
func is_solid(x: int, y: int) -> bool:
	return _behavior[mat_at(x, y)] == Mat.BEHAVIOR_STATIC


## 네이티브 `count()`지만 **한 번에 588μs다**(2026-08-07 실측, 4,128,768칸).
## 🔴🔴 **이 줄은 2026-08-06까지 「~20μs · 예산의 0.24%」라고 적혀 있었고 그건 격자가 28배
##  작던 때의 값이다.** 지금 **HUD가 프레임마다 2회 부르므로 60Hz에서 70,600μs/s = CPU의 7%**다.
##  ⚠ **네이티브라서 싸다는 직관이 격자 크기 앞에서 깨진 자리다** — 훑는 칸 수에 그대로 비례한다.
## 🔴 **고칠 자리는 여기가 아니라 부르는 쪽이다**(`stage.gd` HUD). 셈이 필요하면 `_write_cell`에서
##  증분으로 들거나, 매 프레임이 아니라 N틱마다 부른다. 이 함수 자체는 그물과 무대의 문이라 남는다.
func count_material(mat: int) -> int:
	return _mat.count(mat)


## 지금 타는 셀 수. ⚠ 그물이 **꺼지나**를 재는 자리이고, 파면 누수도 여기서 드러난다.
func burning_count() -> int:
	return _burning.size()


## 🔴🔴 **파면 소속을 주장하는 칸 수. `burning_count()`와 반드시 같아야 한다.**
##
## ⚠ **자리 표의 역방향이고, 깨지는 쪽은 늘 이쪽이다.** 정방향(`_burn_slot[_burning[k]] == k`)은
##  `_burning`을 훑으면 나오니 잘 안 깨진다. 반대로 **파면에 없는데 소속을 주장하는 칸**(고아)은
##  아무 데도 안 나타난다 — 그 칸은 `_ignite_cell`의 중복 가드에 막혀 **영영 다시 못 탄다.**
##  에러도 없고 화면에도 안 뜬다. 실측으로 `_unburn`의 마지막 줄을 앞으로 옮기면
##  숲이 다 탄 뒤 고아가 168칸이었다.
## ⚠ **그물 전용 질의다**(`ignite`와 같은 자리). 매번 격자를 훑으므로 게임 루프에서 부르지 마라.
func claimed_slot_count() -> int:
	var n := 0
	for i in CELL_COUNT:
		if _burn_slot[i] >= 0:
			n += 1
	return n


## 🔴🔴 **「타고 있나」의 단일 소스다** — `is_solid`와 같은 이유다.
##  캐릭터(지속 피해)도 연료 조회도 이걸 지난다. 각자 `flag_at() & FLAG_BURNING`을 쓰면
##  깃발의 뜻이 바뀌는 날 한쪽만 안 따라오고, 그건 「불 위에 서 있는데 안 아프다」로만 보인다.
## ⚠ 격자 밖은 안 탄다(`flag_at`이 0을 준다).
func is_burning(x: int, y: int) -> bool:
	return (flag_at(x, y) & Mat.FLAG_BURNING) != 0


## 남은 연료. 🔴 타는 셀이 아니면 뜻이 없다(`cell_materials.gd`의 `_aux` 절).
func fuel_at(x: int, y: int) -> int:
	if not is_burning(x, y):
		return 0
	return aux_at(x, y)


## 불을 직접 붙인다. 🔴 **그물과 무대용 문이다** — 게임 중 점화는 `cmd_blast`의 `ignite_r`가 한다.
func ignite(x: int, y: int) -> bool:
	return _ignite_cell(x, y)
