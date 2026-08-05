extends RefCounted
## 지팡이 — **끝이 어디인가.** 🔴🔴 **그 답을 내는 함수는 이 파일 하나뿐이다.**
##  화면은 그 값을 **그리기만** 하고, 발사는 그 값을 `aim.fire_cmd` 에 **넘기기만** 한다.
##
## 🔴🔴 **셋(그림 끝 · 물드는 자리 · 발사 원점)이 갈라지면 「쏜 데서 안 나간다」가 되고,
##  그건 스샷으로만 드러난다** — `character_view.gd` 가 같은 것을 미리 적어 뒀다.
##  ⇒ **여기서 나온 값을 호출부가 다시 계산하지 마라.**
##
## 🔴 **`src/view/` 가 아니라 여기 사는 이유**: 화면에 두면 그물이 씬을 세워야 하는데
##  헤드리스에는 픽셀이 없다(`character-sprite` 판정 기록: `SubViewport` 텍스처가 NULL).
##  여기 있으면 격자·상자·방향만 넣고 **값으로** 잰다 — `character.gd` 의
##  `pick_state`·`camera_center` 와 같은 어법이다.
##
## 🔴 **float을 써도 된다** — GDD 멀티 표: 격자·투사체는 결정론, **플레이어는 호스트 권위**다.
##  ⚠ **`src/sim/` 은 한 줄도 안 건드린다.** `spell_sim._walk` 의 「시작 칸은 검사하지 않는다」가
##   그대로 사는 것이 이 파일의 요점이다 — 그 주석은 틀리지 않았고 **전제(「지팡이 끝은 벽 앞이다」)가
##   깨져 있었다.** 여기가 그 전제를 되돌린다.

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Character := preload("res://src/actor/character.gd")

## 🔴🔴 **지팡이 png의 폭과 같아야 한다**(`net_sprite` 가 잰다). 갈라지면 「눈에 보이는 끝」과
##  「발사 원점」이 몇 px 어긋나고, 그건 스샷으로만 드러난다.
## 🔴 **`fx_tuning` 에서 이사해 왔다.** 거기 값은 「화면에만 닿는다」가 계약인데 이 값은
##  `character_view` → `stage` → `aim.fire_cmd` 로 **세상에 닿는다** — 이 파일이 그 위에
##  지형 의존성까지 얹으므로 어긋남이 load-bearing 이 된다.
##  ⚠ 선례가 이미 있다: `character.gd` 의 `MOVE_SPEED_PX`·`RECOIL_*` 가 전부 여기 사는 손맛값이다.
##   실제 규칙은 **「세상에 닿는 손잡이는 그 세상 코드 옆에 있다」**다.
## ⚠ 캐릭터(32px)보다 길어야 「무기」로 읽힌다. 너무 길면 조준점과 끝이 멀어져
##  「쏜 데서 안 나간다」가 된다 — 36px가 그 사이다. **눈으로 보고 정할 값이다.**
const LEN_PX := 36.0

## 손 높이 — 몸 중심에서 아래로 이만큼. ⚠ **눈이 정할 값이다**(기획 「미정」).
## 🔴 상자 **안**이어야 한다(`0 ≤ 이 값 < H_PX/2`) — 넘으면 피벗이 상자 밖이고,
##  그러면 아래 하한의 안전 근거(「상자 안은 지형이 없다」)가 죽는다. `net_staff` 가 잰다.
const PIVOT_DY_PX := 4.0

## 훑기 간격. 🔴 **셀(4px)의 절반이다 — 이보다 크면 셀을 건너뛴다.**
##  ⚠ 건너뛰면 **가끔** 끝이 벽 안에 앉고 재현이 어렵다.
const SCAN_STEP_PX := 2.0


## 지팡이가 뻗어 나오는 자리. 🔴 **몸 중심이 아니라 손 높이다** — 배 한가운데에서 나가면
##  「지팡이를 들고 있다」로 안 읽힌다(기획 판정 6).
static func pivot_px(box_x: int, box_y: int) -> Vector2:
	return Vector2(
		float(box_x) + Character.W_PX * 0.5,
		float(box_y) + Character.H_PX * 0.5 + PIVOT_DY_PX)


## 🔴🔴 **지팡이 끝. 지형에 막히면 짧아진다.**
##
## ```
## ① 피벗   = 손 높이
## ② 최대 끝 = 피벗 + 조준방향 × LEN_PX
## ③ 그 사이를 훑어 **고체 셀을 만나면 그 직전까지** 자른다
## ④ 하한   = 몸 상자의 **마지막 안쪽 픽셀**. 그 아래로는 안 줄어든다
## ```
##
## 🔴 **돌려주는 점은 「고체가 아닌 것을 실제로 확인한 마지막 표본」이다.** 그게 계약이고
##  `net_staff` 가 그걸 잰다 — 「빈 셀에 있다」는 값이지 「클램프를 부른다」가 아니다.
##
## ⚠ `dir` 은 **단위벡터로 받는다. 여기서 정규화하지 않는다** — 호출부가 이미 했고,
##  두 번 하면 「어디서 정규화하나」가 두 곳이 된다. 0벡터면 피벗을 그대로 돌려준다.
## ⚠ `LEN_PX < min_len`(지팡이가 몸보다 짧다)이면 **하한이 이긴다.** 그래도 상자 안이라 안전하다.
static func tip_px(grid: CellGrid, box_x: int, box_y: int, dir: Vector2) -> Vector2:
	var pivot := pivot_px(box_x, box_y)
	if dir.length_squared() <= 0.0:
		return pivot
	# ⚠ 하한 자체는 **표본을 안 뜬다.** 뜰 필요가 없다 — 상자 안은 캐릭터가 지금 서 있는 자리라
	#  지형이 없는 것을 `_box_free` 가 매 프레임 지킨다.
	var d := _min_len(pivot, box_x, box_y, dir)
	while d < LEN_PX:
		var nd := minf(d + SCAN_STEP_PX, LEN_PX)
		var p := pivot + dir * nd
		if grid.is_solid(
				floori(p.x / float(Tuning.CELL_PX)), floori(p.y / float(Tuning.CELL_PX))):
			break
		d = nd
	return pivot + dir * d


## 🔴🔴 **하한 — 「몸 상자의 마지막 안쪽 픽셀」까지의 광선 거리다. 「표면」이 아니다.**
##
## `_box_free` 가 실제로 지키는 범위는 `[px, px+W−1] × [py, py+H−1]` 이라
## `px + W_PX` · `py + H_PX`(표면)는 **이미 다음 셀**이다. 바닥에 선 캐릭터로 밟아 보면:
##
## ```
## 상자 y 768~799 (셀 192~199)      바닥 셀 200 = px 800~803, 고체
## 표면      (y = 800) → floori(800/4) = 200 = 고체     ✗ 여기서 태어나면 옛 버그 그대로다
## 마지막 안쪽(y = 799) → floori(799/4) = 199 = 빈칸     ✓
## ```
##
## ⚠ **표면으로 짜면 옆·위는 멀쩡하고 발밑에만 옛 버그가 남는다. 에러가 하나도 안 난다.**
## ⚠ **왼쪽·위 모서리는 `box` 그대로가 맞다** — `floori` 가 그 픽셀을 상자 셀로 매핑한다.
##  비대칭이 정상이다.
static func _min_len(pivot: Vector2, box_x: int, box_y: int, dir: Vector2) -> float:
	return minf(
		_axis_exit(pivot.x, dir.x, float(box_x), float(box_x + Character.W_PX - 1)),
		_axis_exit(pivot.y, dir.y, float(box_y), float(box_y + Character.H_PX - 1)))


## 한 축에서 광선이 `[lo, hi]` 를 벗어나는 거리.
## ⚠ 축과 나란하면(`d ≈ 0`) 그 축은 광선을 **안 가둔다** — 나눗셈이 아니라 갈래로 처리한다
##  (`character._slab` 과 같은 어법). 두 축이 다 0인 경우는 호출부가 먼저 걸렀다.
## ⚠ 피벗이 상자 밖이면 음수가 나올 수 있다 — 0으로 막는다(하한이 뒤로 가면 안 된다).
static func _axis_exit(a: float, d: float, lo: float, hi: float) -> float:
	if is_zero_approx(d):
		return INF
	return maxf(0.0, ((hi if d > 0.0 else lo) - a) / d)
