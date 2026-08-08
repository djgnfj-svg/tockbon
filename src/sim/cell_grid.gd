extends RefCounted
## 셀 격자 시뮬 코어. **순수 객체다 — 씬 트리를 모른다.**
##
## 🔴🔴 `Node`가 아니라 `RefCounted`인 게 이 파일의 가장 중요한 성질이다.
##  `Input`·`Time`·`randi()`·`get_viewport()`·씬 트리에 **절대 접근하지 않는다.**
##  ⇒ 서버가 헤드리스로 N개를 돌릴 수 있고, 그물이 씬 없이 돈다.
##
## 🔴🔴 **격자를 바꾸는 문은 셋이다** — `apply(cmd)` 와, 그물·무대용 직접 문 `ignite` · `set_water`.
##  ⚠ **여기 「`apply` 하나다」라고 적혀 있었고 그건 거짓이 됐다**(2026-08-07). 무대의 F 키가
##   실제로 `set_water` 를 직접 부른다. 🔴 **거짓인 근거 문장은 없느니만 못하다** — 다음 사람이
##   「커맨드만 보면 된다」로 읽고 나머지 둘을 안 본다.
##  ⇒ **멀티에 가는 것은 `apply` 뿐이고, 나머지 둘은 본편에 안 남는 껍데기·그물용이다.**
##   그 구별이 「문이 하나」가 지키려던 것이고, **직접 쓰기 코드가 이 파일 안에만 있다는 것은 그대로다.**
##
## 🔴 **청크 재우기가 있다**(아래 「청크 재우기」 절). ⚠ **불은 여전히 청크와 독립이다** —
##  파면 목록이라 격자가 통째로 잠들어 있어도 탄다(GDD 「상태는 파면 목록으로 돈다」). 건드리지 마라.
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
##   거기로 떨어진 물이 같은 틱에 또 움직인다.
##  🔴🔴 **여기 적혀 있던 「비용은 밴드당 플래그 검사 16 → 256회뿐이다」는 v1 격자 기준이라
##   지금은 거짓이다.** v1은 밴드에 청크가 16개였고 **지금은 256개**라 밴드당 `256 × 16 = 4,096`회다 —
##   전부 잠들어도 **6,016μs/틱 = 예산의 12%** 가 나온다(2026-08-07 실측).
##   ⇒ 그래서 `_band_awake` 가 있다. **그건 최적화가 아니라 이 계약을 감당 가능하게 만드는 값이다.**
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

# ─── 청크 재우기 ──────────────────────────────────────────────────
## 🔴🔴 **격자를 조각으로 나누고 「이번 틱에 뭔가 움직인 조각」만 다음 틱에 돈다.**
##  바로 위 62,676μs 가 이 축이 있는 이유 전부다 — **최적화가 아니라 전제다.**
##
## 🔴 **손잡이(`CHUNK_CELLS`)는 `sim_tuning` 에 있고 여기 셋은 전부 파생값이다.**
##  ⚠ 16으로 안 나눠떨어지면 가장자리 셀이 범위 밖 청크를 찍는다 — `_init()` 이 짖는다.
const CHUNK_W := W / Tuning.CHUNK_CELLS      # 256
const CHUNK_H := H / Tuning.CHUNK_CELLS      # 63  ← 밴드 수
const CHUNK_COUNT := CHUNK_W * CHUNK_H       # 16,128

# ─── 커맨드 — 격자를 바꾸는 유일한 문 ──────────────────────────────
enum { CMD_FILL = 0, CMD_RESET = 1, CMD_BLAST = 2, CMD_IGNITE = 3, CMD_CARVE = 4, CMD_WATER = 5 }

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

## 🔴🔴 **`_awake` = 이번 틱에 도는 청크. `_dirty` = 다음 틱에 돌 청크.**
##
## ⚠ **한 배열로 못 합친다.** 도는 도중에 찍은 것이 이번 틱 순회에 들어가면 같은 물이
##  한 틱에 두 번 움직인다 — 파일 머리의 순회 순서 계약이 정확히 그걸 막는 장치다.
## 🔴 둘을 바꿔 다는 것이 `_chunk_flip()` 이고 **그건 틱의 시작이다**(그 함수 주석).
var _awake := PackedByteArray()
var _dirty := PackedByteArray()

## 🔴🔴 **밴드(청크 행)마다 깨어 있는 청크 수. 최적화가 아니라 전제다.**
##  순회 계약이 「밴드 안에서 행 → 청크」라 밴드 하나를 도는 데 플래그를 `256 × 16 = 4,096`회 본다.
##
## 🔴 **실측 — 진짜 `_water_step` 으로 쟀다**(2026-08-07, 구현 · 헤드리스 · 잠든 격자 `step()` 2000회 × 2):
##
##      밴드 요약 있음(지금)  **5.25μs/틱**  = 예산(50,000μs)의 0.01%
##      밴드 요약 없음        **8,114μs/틱** = 예산의 **16%**       ← 1,546배
##
##  ⚠ 계획에 적힌 「6,016μs / 12%」는 **spec의 대리 구현** 값이고, 진짜 코드는 그보다 **더 나쁘다.**
##  ⚠ 5.25μs 안에는 `_chunk_flip`(단독 3.7μs, verify-run 실측)이 들어 있다 — 밴드 훑기 자체는 ~1.5μs다.
##
## ⚠ **없어도 격자는 정확히 돈다 — 느려질 뿐이라 아무도 안 짖는다.** 그게 이 값이 조용히
##  사라질 수 있는 이유이고, 그물이 `_awake` 를 직접 세어 이 값과 맞대는 이유다.
## 🔴 **그리고 그 맞댐은 「갈라짐」만 잡고 「통째로 사라짐」은 못 잡는다** — 둘 다 지우면 초록이다.
##  ⇒ **시간으로 재는 검사가 단계 3에 들어간다**(기획 「그물」).
var _band_awake := PackedInt32Array()
var _band_dirty := PackedInt32Array()

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
	_awake.resize(CHUNK_COUNT)
	_dirty.resize(CHUNK_COUNT)
	_band_awake.resize(CHUNK_H)
	_band_dirty.resize(CHUNK_H)
	_behavior = Mat.bake_behavior()
	_fuel = Mat.bake_fuel()
	_indestructible = Mat.bake_indestructible()
	# 조용히 어긋나는 자리라 부팅에서 짖게 한다 — 인덱싱이 통째로 틀리면
	# 증상이 「격자가 이상하다」로만 나온다.
	if (1 << X_SHIFT) != W:
		push_error("CellGrid: X_SHIFT(%d)가 W(%d)와 안 맞는다" % [X_SHIFT, W])
	# 🔴 같은 자리·같은 이유. 안 나눠떨어지면 `CHUNK_W`·`CHUNK_H` 가 잘리고 가장자리 셀이
	#  **범위 밖 청크를 찍는다** — 증상은 매 틱 엔진 「Index out of bounds」이고 그건 침묵사다.
	if W % Tuning.CHUNK_CELLS != 0 or H % Tuning.CHUNK_CELLS != 0:
		push_error("CellGrid: 격자 %d×%d 가 청크 %d로 안 나눠떨어진다" % [W, H, Tuning.CHUNK_CELLS])


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
	# 🔴🔴 **틱의 시작이다. 끝이 아니다** — 아래 `_chunk_flip` 주석에 이유가 있다.
	_chunk_flip()
	# ⚠ **물이 불보다 먼저다.** 불이 다 탄 칸을 EMPTY 로 만들면 그 칸은 **다음 틱에** 물을 받는다.
	#  같은 틱에 받게 하려면 순서를 뒤집어야 하는데, 그러면 「이번 틱에 생긴 물 위에 불이 붙나」가
	#  순서에 매달린다. 🔴 **한 틱 늦는 쪽이 읽기 쉽고, 20Hz에서 50ms라 화면에서 구별이 안 된다.**
	_water_tick()
	_burn()


# ══════════════════════════════════════════════════════════════════
#  청크 재우기
# ══════════════════════════════════════════════════════════════════

## 다음 틱에 돌 청크를 이번 틱 것으로 갈아 끼운다.
##
## 🔴🔴 **틱의 시작이어야 한다.** 끝에 두면 `step()` **밖에서** 온 변경이 **한 틱 더 기다린다** —
##  틱 N 의 순회는 틱 N-1 끝에 갈아 낀 awake 를 쓰는데, 폭발은 `world_step` 순서상
##  `grid.step()` **뒤에** 오는 `spell.step()` 안에서 격자를 부르므로 그 flip을 이미 지나쳤다.
##  ⇒ 「그릇을 뚫었는데 다음 틱에 안 샌다」이고 **에러가 하나도 안 난다.**
##
## ⚠ **기획 문서는 이걸 「dirty 가 그 자리에서 지워진다」로 적었는데, 이 구현에서는 안 지워진다** —
##  버퍼를 넘겨주므로 늦어질 뿐 잃지는 않는다. 🔴 **그래도 결론은 같고, 「늦는다」쪽이
##  더 무섭다**: 잃으면 언젠가 눈에 띄지만 한 틱 늦는 것은 영영 안 띈다.
## 🔴🔴 **그물이 이 배치를 잰다 — 물이 아니라 불로.** `net_water` 의 `_flip_is_at_tick_start`.
##  ⚠ **「틱 도중에 움직이는 것이 물뿐이라 단계 1에선 못 잰다」는 틀렸다**(구현이 그렇게 적었다가
##   검증에서 뒤집혔다): `_burn()` 이 `step()` **안에서** 다 탄 칸에 `_write_cell` 을 부르고
##   그게 `_touch` 를 탄다. ⇒ **다 탄 그 틱에는 아직 안 깨어 있고 한 틱 뒤에 깨어난다**가
##   flip이 앞에 있다는 증거이고, 뒤로 옮기면 그 자리에서 갈린다(실측으로 확인했다).
##
## ⚠ **버퍼를 넘겨주고 새 것을 받는다.** `_awake = _dirty` 뒤에 `_dirty.fill(0)` 을 하면
##  CoW라 어차피 사본이 뜨는데, 코드는 「두 이름이 한 배열을 본다」로 읽혀 오해를 부른다.
##  ⇒ 새로 잡고 명시적으로 0을 채운다(16,128바이트 memset).
##
## 🔴 **실측: 잠든 격자의 `step()` 이 틱당 3.7μs = 예산(50,000μs)의 0.0074%**
##  (2026-08-07, verify-run이 진짜 코드로 쟀다 — 여기 적혀 있던 「네이티브라 무시 가능」의 근거다).
## ⚠ **이건 flip 비용이지 순회 비용이 아니다.** 계획의 「밴드 요약 있음 → 1μs」와 나란히 두지 마라 —
##  그건 `_water_step` 의 밴드 훑기 값이고, **단계 2에서는 둘이 더해진다.**
func _chunk_flip() -> void:
	_awake = _dirty
	_band_awake = _band_dirty
	_dirty = PackedByteArray()
	_dirty.resize(CHUNK_COUNT)
	_dirty.fill(0)
	_band_dirty = PackedInt32Array()
	_band_dirty.resize(CHUNK_H)
	_band_dirty.fill(0)


## 셀 하나가 든 청크를 **다음 틱에 돌 것**으로 찍는다.
##
## 🔴🔴 **격자를 바꾸는 모든 문이 여기를 지나야 한다.** 안 지나면 그 자리 물이 안 움직이고,
##  그건 화면에 **「보이지 않는 벽」**으로만 드러난다 — 에러가 하나도 안 난다.
## ⚠ **부르는 자리는 둘이다** — `_write_cell` 과 `_write_water`.
##  `_fill_rect` 도 `_disc(파괴)` 도 다 탄 칸 비우기도 전부 앞엣것을 지나고, 물의 모든 이동은 뒤엣것을 지난다.
##  🔴 **여기 「하나뿐이다」라고 적혀 있었다**(2026-08-07까지) — 물이 들어오며 거짓이 됐고,
##   그 문장이 곧 「빠뜨릴 자리가 없다」의 근거였다. **근거가 거짓이면 결론도 못 믿는다.**
## 🔴 **`_ignite_cell` 은 안 부른다.** `_flag`·`_aux` 만 만지고 재료를 안 바꾸며, 점화 조건이
##  연료 > 0 이라 **물 칸(연료 0)에 원리적으로 못 닿는다.** 불은 파면 목록이라 청크와 독립이다.
##
## 🔴🔴 **자기 청크만 찍으면 청크 경계에 「보이지 않는 벽」이 선다.** 2026-08-07에 verify-read2가
##  **원본 코드에서 재현했다**(뮤테이션 없이):
##
##      물 y=335(밴드 20) · 아래 y=336(밴드 21)은 돌 ⇒ 3틱에 잠든다
##      바로 아래만 판다 ⇒ **10틱 뒤에도 물이 y=335에 그대로 떠 있다**
##
##  ⚠ 판 칸의 청크만 깨어나고 **물이 든 밴드는 잠든 채**라 순회가 통째로 건너뛴다.
##   에러 0 · 화면엔 「공중에 뜬 물」로만 보인다. 🔴 **폭발·파기·다 탄 나무가 전부 이 경로다**
##   (물기둥 바닥의 y가 16의 배수 −1일 때 — 대략 16번에 1번).
##
## ⇒ **「물이 이 칸으로 흘러들 수 있는 방향」의 청크도 같이 찍는다.**
## 🔴 **8이웃을 다 찍지 않는다.** 깨어 있는 밴드 하나가 128μs이고 그건 **그 밴드의 청크 수와
##  무관하다**(verify-run 실측) — 넓게 깨우면 밴드 수가 늘어 그 항이 그대로 커진다.
##  ⇒ 아래·대각은 안 찍는다. 물은 위로도 대각으로도 안 온다.
## 🔴🔴 **좌우도 깬다 — 단계 3에서 `_water_step` 이 `(x±1, y)` 로 옮기기 시작했기 때문이다.**
##  ⚠ verify-run이 단계 2에서 「대각 경로가 없다」를 900틱 돌려 확인했는데 **그건 아래로만 가던
##   때의 결론이고 좌우가 붙는 순간 무효다.** 그리고 **열 경계는 행 경계보다 훨씬 자주 걸린다.**
## 🔴 **여전히 8이웃이 아니다.** 아래와 대각은 안 찍는다 — 물은 **아래에서도 대각에서도 안 온다.**
##  실측(verify-run, 단계 2): 좁게 고른 대가로 밴드 항이 낙하 물 기준 **+1.7%**, 연속된 지형
##  채우기는 **델타 0**이다(위 밴드가 이미 깨어 있다).
func _touch(i: int) -> void:
	_touch_chunk_of(i)
	var cc := Tuning.CHUNK_CELLS
	var x := i & X_MASK
	# 🔴 **경계에 걸린 칸만 이웃을 찍는다.** 안쪽 칸은 이웃이 같은 청크라 이미 찍혔다 —
	#  안 거르면 `_fill_rect` 한 번이 `_touch_chunk_of` 를 네 배로 부른다.
	if (i >> X_SHIFT) % cc == 0 and i >= W:
		_touch_chunk_of(i - W)
	if x % cc == 0 and x > 0:
		_touch_chunk_of(i - 1)
	elif x % cc == cc - 1 and x < W - 1:
		_touch_chunk_of(i + 1)


## 셀 인덱스가 든 청크 하나를 dirty 로 찍는다.
func _touch_chunk_of(i: int) -> void:
	var band := (i >> X_SHIFT) / Tuning.CHUNK_CELLS
	_touch_chunk(band * CHUNK_W + ((i & X_MASK) / Tuning.CHUNK_CELLS), band)


## 청크 인덱스로 직접 찍는다. ⚠ `band` 를 인자로 받는 이유는 **부르는 쪽이 이미 알기 때문**이다 —
##  여기서 다시 나누면 내부 루프에 나눗셈이 하나 는다.
func _touch_chunk(c: int, band: int) -> void:
	# 🔴 밴드 요약은 **증분으로만** 유지된다 — 여기서 중복을 안 거르면 같은 청크를 여러 번
	#  찍을 때 요약이 부풀고, 그러면 순회가 잠든 밴드를 깨어 있다고 읽는다(느려질 뿐 안 짖는다).
	if _dirty[c] != 0:
		return
	_dirty[c] = 1
	_band_dirty[band] += 1


# ══════════════════════════════════════════════════════════════════
#  물
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **물이 격자에 닿는 유일한 문이다. `_write_cell` 을 쓰면 양이 그 자리에서 증발한다** —
##  그 함수는 `_flag` 와 `_aux` 를 같이 0으로 만드는데 **양이 `_aux` 에 산다.** 에러는 0이다.
##
## ⚠ **반대 방향은 여전히 `_write_cell` 이 맞다.** 폭발이 물을 지우는 것은 양을 0으로 만드는 게
##  아니라 **칸을 통째로 비우는 것**이다 — 두 문의 경계가 여기다.
##
## 🔴🔴 **부르는 쪽이 「EMPTY 나 WATER 위에만 쓴다」를 보장한다 — 자리가 넷이다.**
##  `set_water`(명시 가드) · `_water_disc`(명시 가드) · `_water_fall`(도착 재료를 본다) ·
##  `_water_share`(이웃 재료를 본다). ⚠ **여기 둘만 적혀 있었다**(2026-08-07까지).
##  🔴 **목록이 짧은 것이 곧 위험이다** — 이 함수는 파면(`_burning`)을 안 만지므로 타는 칸에 쓰면
##   **소속을 주장하는 유령**이 남고, 그러면 `_burn` 이 **물의 양을 연료로 먹는다**(실측 255 → 250).
##  ⇒ **넷 중 하나만 빠져도 뚫린다.** `unburnable_in_front_count()` 가 넷을 한 번에 재는 계기다.
## ⚠ **양의 범위도 부르는 쪽이 본다** — 여기는 내부 루프라 커맨드 경계에서 한 번만 보는 게
##  이 파일의 어법이다(`_valid_mat` 주석). 넘치면 `PackedByteArray` 가 말없이 자른다.
## 🔴🔴 **얕음 비트가 여기서 갱신된다 — 양을 쓰는 바로 그 자리다.**
##  ⚠ 둘을 따로 만지면 갈라지고 **갈라진 쪽은 화면에만 나온다**(시뮬은 양만, 셰이더는 비트만 본다).
func _write_water(i: int, amount: int) -> void:
	if amount <= 0:
		_mat[i] = Mat.EMPTY
		_aux[i] = 0
		# 🔴 **비우는 쪽도 비트를 내려야 한다.** 안 내리면 빈칸이 얕음 비트를 든 채 남고,
		#  다음에 그 칸이 물이 될 때 **양과 비트가 어긋난 채로 시작한다.**
		_flag[i] &= ~Mat.FLAG_SHALLOW
	else:
		_mat[i] = Mat.WATER
		_aux[i] = amount
		if amount <= Tuning.WATER_WET:
			_flag[i] |= Mat.FLAG_SHALLOW
		else:
			_flag[i] &= ~Mat.FLAG_SHALLOW
	# 안 세면 물이 움직여도 **화면이 안 올라간다**(`_changed` 가 「다시 그리나」의 단일 소스다).
	_changed += 1
	_touch(i)


## 정수 원반을 적신다. 🔴 **`_disc` 의 물 쪽 짝이고, 원반을 그리는 규칙이 그것과 같아야 한다** —
##  따로 짜면 한쪽만 원이고 한쪽만 네모가 되는 날이 온다(그 함수 주석과 같은 이유).
##
## 🔴🔴 **`_write_water` 를 부른다. `_write_cell` 이 아니다** — 그건 양을 0으로 만든다.
## ⚠ **덮어쓰지 않고 채운다**(`maxi`). 이미 더 깊은 물이 있는 칸을 얕은 값으로 덮으면
##  **물 룬이 물을 줄이는** 일이 나고, 그건 「적신다」의 뜻이 아니다.
## ⚠ 고체는 건너뛴다 — 돌을 물로 바꾸는 것은 파괴의 일이고, 물 룬은 지형을 안 건드린다.
## ⚠ 격자 밖은 **클램프**다(`_disc` 와 같다).
func _water_disc(cx: int, cy: int, r: int, amount: int) -> void:
	var r2 := r * r
	var ax := maxi(0, cx - r)
	var bx := mini(W - 1, cx + r)
	var ay := maxi(0, cy - r)
	var by := mini(H - 1, cy + r)
	for y in range(ay, by + 1):
		var dy := y - cy
		var dy2 := dy * dy
		var row := y << X_SHIFT
		for x in range(ax, bx + 1):
			var dx := x - cx
			if dx * dx + dy2 > r2:
				continue
			var i := row | x
			# 🔴 `_write_water` 의 계약(EMPTY 나 WATER 위에만) 을 여기서 지킨다 —
			#  타는 칸에 쓰면 파면에 **소속을 주장하는 유령**이 남는다(`set_water` 와 같은 자리).
			if _mat[i] != Mat.EMPTY and _mat[i] != Mat.WATER:
				continue
			_write_water(i, maxi(_aux[i], amount))


## 🔴🔴 **한 틱의 물 — `_water_step` 을 `WATER_SUBSTEPS` 번 돈다.**
##  「물이 퍼지는 게 느리다」(사용자가 화면을 보고 판정, 2026-08-07)의 손잡이가 여기다.
##  ⚠ **`TICK_DIVIDER` 로 하면 탄도 불도 같이 빨라진다** — 왜 그 축이 아닌지는 그 상수 주석에 있다.
##
## 🔴🔴 **서브스텝 사이에 `_chunk_flip` 이 없다. 그게 이 배치의 계약이고, 대가가 있다.**
##  `_awake` 는 틱 시작에 한 번 정해지고 서브스텝 도중의 `_touch` 는 `_dirty` 만 찍는다 ⇒
##
##   · **틱 시작에 깨어 있던 청크는 N번 다 돈다** — 고인 물이 눕는 것이 그래서 N배 빨라진다
##     (수면 띠의 청크는 움직이는 동안 매 틱 깨어 있다)
##   · ~~물이 새 청크로 번지는 앞머리는 안 빨라진다~~ → 🔴 **틀렸다. 얕게 퍼지는 앞머리도 3배다**
##     (2026-08-07, verify-run 실측: +8/+16/+32/+64/+95셀 도달이 전부 3.0배).
##     **이유는 속도차다** — 앞머리가 **0.21셀/틱**이라 청크 한 변(16셀)보다 **76배 느리고**,
##     「틱당 한 청크」 한계에 **원리적으로 안 닿는다.** 확산 규칙이 그 속도를 못 낸다.
##     ⚠ **댐이 터져 물이 허공을 가로지르는 경우는 안 쟀다** — 거기서는 아직 물릴 수 있다.
##   · ⚠ **밴드 경계를 지나는 낙하는 그 틱의 남은 서브스텝을 쉰다**(아래 밴드가 아직 안 깨어 있으면).
##     🔴 **실측: `y % 16 == 15` 일 때만, 16셀마다 한 번 = 6틱마다 한 번.**
##     ⇒ 낙하는 3배가 아니라 **2.67칸/틱**이다(이론 3배 중 11%를 잃는다).
##     화면에서는 **「0.3초에 한 번 낙하가 한 프레임 끊긴다」**다 — 고장이 아니다.
##
##  🔴 **서브스텝마다 flip 하면 위 셋이 사라지는 대신 「flip은 틱 시작」이 깨진다**
##   (`_chunk_flip` 주석 · `net_water._flip_is_at_tick_start` 가 그 배치를 잰다).
##   ⇒ **그 값은 지불하지 않았다.** 여기서 얻으려는 것은 「고인 물이 눕는 속도」 하나다.
##
## 🔴🔴 **상한은 틱마다 한 번 자른다 — 서브스텝마다가 아니다.**
##  ⇒ 한 틱의 실제 일이 **`MAX_CHUNKS_PER_TICK × WATER_SUBSTEPS` 청크-패스**다.
##  ⚠ **즉 상한의 실효값이 N분의 1이 된다.** 근거표는 그 상수 주석. **값은 안 내렸다**(화면 판정이다).
##  🔴 **서브스텝마다 자르면 실효 상한이 오히려 N배가 된다** — 첫 컷이 `_awake` 를 이미 줄여 놓아
##   두 번째부터는 `count()` 가 상한 아래라 그냥 통과하기 때문이다. 그건 안전망의 뜻과 반대다.
func _water_tick() -> void:
	# 🔴 **자르는 dir 은 첫 서브스텝의 것이다.** 서브스텝마다 dir 이 뒤집히므로 「도는 순서」가
	#  하나가 아닌데 자르기는 틱에 한 번이라 기준도 하나여야 한다.
	#  ⚠ `_tick` 에서만 파생되므로 **결정론은 그대로다** — 두 클라가 같은 청크를 자른다.
	_cap_awake_chunks(_water_dir(0))
	var sub := 0
	while sub < Tuning.WATER_SUBSTEPS:
		_water_step(_water_dir(sub))
		sub += 1


## 🔴🔴 **물 한 번 훑기.** 순회 순서는 **파일 머리의 계약 그대로다** — 새로 정하지 않았다.
##  밴드 아래→위 · 밴드 안 행도 아래→위 · **행 → 청크** · 열은 dir의 반대.
##
## 🔴🔴 **파일 머리의 「이동 도착지는 이미 지났거나 안 도는 자리」는 세로에만 성립한다.**
##  가로는 성립하지 않고, **성립시킬 수도 없다** — 아래 `_water_spread` 주석에 이유가 있다.
##  ⚠ 머리 주석은 v1의 **알갱이** 모델(한 틱에 한 방향으로만 미끄러진다)에서 왔고, 양 기반의
##   좌우 평균내기는 **확산**이라 성질이 다르다. 🔴 **그 차이를 모르고 머리 주석만 읽으면
##   「가로도 한 틱에 한 칸」으로 믿게 된다 — 아니다.**
##
## 🔴 **`_band_awake` 검사가 이 루프의 첫 줄인 이유**: 그 줄을 빼면 잠든 격자가
##  **5.25μs → 8,114μs/틱 = 예산의 16%** 다(실측 · `_band_awake` 주석에 표).
##
## 🔴🔴 **실측 — 흐르는 물의 청크 하나당 78.0μs**(2026-08-07, 구현 · 헤드리스 · 300틱 · 깨어 있던
##  청크 5,586개-틱 · 최대 114청크 · 물이 실제로 낙하 중). ⚠ **계획의 41μs(spec 대리 측정)의 1.9배다.**
##  ⚠ **그건 아래로만 가던 단계의 값이라 하한이었다.** 좌우가 붙은 뒤 verify-run이 댐 붕괴로 재니
##   **한 틱 최악이 예산의 273~290%, 400틱 평균 101.5%** 다 — 근거표는 `sim_tuning.MAX_CHUNKS_PER_TICK`.
##  🔴 **값을 여기서 안 바꾼다.** 정하는 것은 판정 7(FPS)이다.
func _water_step(dir: int) -> void:
	var cc := Tuning.CHUNK_CELLS
	var band := CHUNK_H - 1
	while band >= 0:
		if _band_awake[band] == 0:
			band -= 1
			continue
		var chunk_base := band * CHUNK_W
		var y := band * cc + cc - 1
		var y_top := band * cc
		while y >= y_top:
			var row := y << X_SHIFT
			# 🔴 격자 맨 아래 행은 받을 곳이 없다. ⚠ 안 걸르면 `_water_fall` 이 격자를 넘겨 읽고,
			#  그건 매 틱 엔진 「Index out of bounds」다 — **단언에 안 잡히고 래퍼만 잡는다**(실측).
			var can_fall := y < H - 1
			# ⚠ **청크도 dir의 반대로 돈다.** 열 순서만 뒤집고 청크 순서를 안 뒤집으면
			#  청크 경계에서 도착 칸이 아직 안 돈 상태가 되고, 그 물이 같은 틱에 또 움직인다.
			var cx := (CHUNK_W - 1) if dir > 0 else 0
			while cx >= 0 and cx < CHUNK_W:
				if _awake[chunk_base + cx] != 0:
					var x := (cx * cc + cc - 1) if dir > 0 else (cx * cc)
					var n := cc
					while n > 0:
						var i := row | x
						# 🔴 **재료 검사가 빠른 길이다** — 물이 한 칸도 없는 청크는
						#  여기서 다 튕긴다(실측 12.5μs/청크, spec의 대리 측정).
						if _mat[i] == Mat.WATER:
							_water_cell(i, x, row, y, can_fall, dir)
						x -= dir
						n -= 1
				cx -= dir
			y -= 1
		band -= 1


## 🔴 **dir 의 단일 소스.** `_water_step` 과 `_cap_awake_chunks` 가 **같은 값을 봐야 한다** —
##  자르는 순서와 도는 순서가 갈리면 「잘린 청크」와 「안 돈 청크」가 달라지고, 그건 결정론이 아니라
##  **한 틱에 두 번 도는 청크**로 나타난다. ⚠ 식을 두 곳에 적으면 한쪽만 고치는 날이 온다.
## 🔴 `_tick` 에서 파생시킨다 — **상태를 새로 안 든다.** 뒤집혀 좌우 편향을 없앤다.
##
## 🔴🔴 **서브스텝마다 뒤집는다. 틱마다가 아니다** — `sub` 가 그래서 인자다.
##  틱마다 뒤집으면 한 틱 안에서 **같은 방향으로 N번** 민다 ⇒ 한 틱의 편향 진폭이 그대로 N배다
##  (두 틱에 걸쳐 상쇄되는 것은 같지만, **화면에 보이는 것은 매 틱의 상태**다).
##  서브스텝마다 뒤집으면 진폭이 **서브스텝 한 번치**로 남아 N=1 때와 같다.
##  ⚠ N이 홀수면 한 틱에 한쪽이 한 번 더 밀리지만(3이면 `+,-,+`) **그 잔차는 다음 틱이
##   `-,+,-` 로 받아 상쇄한다** — `_tick` 이 같이 들어가 있어서 그렇다.
##
## 🔴 **`sub` 를 더하는 자리가 여기 하나여야 한다.** `WATER_SUBSTEPS = 1` 이면 `sub` 가 0뿐이라
##  **이 상수가 들어오기 전 식(`_tick & 1`)과 정확히 같은 값**이 나온다 — 되돌리는 길이 값 하나다.
func _water_dir(sub: int) -> int:
	return 1 if ((_tick + sub) & 1) == 0 else -1


## 칸 하나: ① 아래로 넘기고 ② 남으면 좌우로 나눈다.
func _water_cell(i: int, x: int, row: int, y: int, can_fall: bool, dir: int) -> void:
	var amount := _aux[i]
	if can_fall:
		amount = _water_fall(i, x, y, amount)
		if amount <= 0:
			return
	_water_spread(i, x, row, amount, dir)


## ① 아래로. `Tuning.WATER_FALL_CELLS`(K)까지 **연속된 빈칸**을 훑어 제일 낮은 빈칸에
## 통째로 옮긴다(`sim_tuning.WATER_FALL_CELLS` 헤더 — 셀당 속도 상태를 안 든다).
## 물이나 고체를 만나면 그 자리에서 멈추고 **지금 규칙 그대로** 처리한다 ⇒ 쌓임과 막힘의
## 뜻이 안 바뀐다. 아래 칸이 **받을 수 있는 만큼만** 간다. 남은 양을 돌려준다.
## ⚠ `can_fall`(호출부, `y < H - 1`)이 이미 보장한 조건이라 여기서 다시 안 본다.
func _water_fall(i: int, x: int, y: int, amount: int) -> int:
	var last_empty_y := -1
	var k := 0
	while k < Tuning.WATER_FALL_CELLS:
		var ny := y + k + 1
		if ny >= H or _mat[(ny << X_SHIFT) | x] != Mat.EMPTY:
			break
		last_empty_y = ny
		k += 1
	if last_empty_y >= 0:
		# 빈칸을 찾았다 — **그중 제일 낮은 자리**에 통째로 옮긴다.
		# 🔴 **두 번 다 `_write_water` 다** — 한쪽만 이 문을 지나면 다른 쪽에서 양이 증발하고
		#  총량이 조용히 샌다.
		_write_water((last_empty_y << X_SHIFT) | x, amount)
		_write_water(i, 0)
		return 0

	# 연속 빈칸이 없다(바로 아래가 이미 물이거나 고체다) — 1칸짜리 지금 규칙 그대로.
	var below := ((y + 1) << X_SHIFT) | x
	var bm := _mat[below]
	# 🔴 고체를 만나면 아무 일도 안 한다 — 그게 「돌이 물을 막는다」이고, 남은 양은 ②로 간다.
	if bm != Mat.WATER:
		return amount
	var space := Tuning.WATER_MAX - _aux[below]
	if space <= 0:
		return amount
	# ⚠ `mini` 다(`min` 이 아니다) — `src/sim/` 은 float 전역 함수가 금지다(`net_determinism`).
	var move := mini(amount, space)
	_write_water(below, _aux[below] + move)
	_write_water(i, amount - move)
	return amount - move


## ② 좌우로 나눈다. **dir 쪽 이웃을 먼저 본다.**
##
## 🔴🔴 **파일 머리의 순회 계약이 여기서는 성립하지 않는다. 성립시킬 수도 없다.**
##  머리 주석은 「도착지는 이번 틱에 이미 지났거나 아예 안 도는 자리」인데, 열을 dir의 반대로 도니까
##  `x + dir` 은 이미 지났지만 **`x - dir` 은 아직 안 지났다.** ⇒ `x - dir` 로 간 물은 이번 틱에
##  또 움직일 수 있고, 그래서 **가로는 한 틱에 여러 칸 번진다**(255 → 127 → 63 … 로 잦아든다).
##
## 🔴 **이건 버그가 아니라 확산의 성질이다.** 양 기반 평균내기는 Gauss-Seidel 훑기이고,
##  단일 버퍼에서 **어느 순서로 돌든** 한쪽 방향으로는 반드시 연쇄가 난다. 한 방향만 나누게 막으면
##  연쇄는 사라지지만 **평형이 오는 속도가 절반이 되고 기획의 실측 틱 수가 통째로 안 맞는다.**
## ⇒ **그래서 dir 이 매 틱 뒤집힌다.** 편향을 없애는 것이 이 축의 유일한 장치다.
## ⚠ **머리 주석은 세로에만 적용된다** — 세로는 아래→위로 돌아 연쇄가 원리적으로 없다(그물이 잰다).
##
## 🔴 **실측: 가로 도달 거리가 한 틱에 최대 5칸이다**(첫 틱 · 2026-08-07 verify-run).
##  ⚠ **그래서 대각 경로가 실제로 생긴다** — 「한 틱에 아래 한 칸」만 알고 있으면 물이 대각으로
##   새는 것이 고장으로 보인다. 아니다. 세로 1칸 + 가로 5칸이 이 규칙의 모양이다.
##
## 🔴🔴 **차이가 `WATER_MIN_DIFF` 이하면 안 옮긴다 — 여기가 멈춤의 심장이다.**
##  없으면 홀수가 영원히 안 나눠져 1씩 왕복하고, 그러면 **청크가 절대 안 잠들어 청크 재우기가
##  통째로 무효가 된다.** v1이 죽은 자리다.
func _water_spread(i: int, x: int, row: int, amount: int, dir: int) -> void:
	amount = _water_share(i, x + dir, row, amount)
	if amount <= 0:
		return
	_water_share(i, x - dir, row, amount)


## 이웃 한 칸과 평균에 가까워지게 나눈다. 남은 양을 돌려준다.
func _water_share(i: int, nx: int, row: int, amount: int) -> int:
	if nx < 0 or nx >= W:
		return amount
	var j := row | nx
	var nm := _mat[j]
	# 🔴 고체는 안 받는다. 빈칸과 물만 받는다 — `_write_water` 가 그 둘 위에만 쓴다는 계약과 같다.
	if nm != Mat.EMPTY and nm != Mat.WATER:
		return amount
	# ⚠ 빈칸의 `_aux` 는 0이다. 「재료가 EMPTY인데 양이 남아 있다」는 원리적으로 없다
	#  (`_write_cell` 도 `_write_water` 도 비울 때 양을 0으로 만든다).
	var other := _aux[j]
	var diff := amount - other
	if diff <= Tuning.WATER_MIN_DIFF:
		return amount
	# ⚠ **정수 시프트가 안전하다**: `diff` 는 여기서 늘 양수라 `DRAG_NUM` 주석의
	#  「음수에서 `>>` 가 비대칭」 함정에 안 걸린다.
	# 🔴 넘칠 수 없다: `other + move = (amount + other) / 2 ≤ max(amount, other) ≤ WATER_MAX`.
	var move := diff >> 1
	_write_water(j, other + move)
	_write_water(i, amount - move)
	return amount - move


## 🔴🔴 **한 틱 상한 — 깨어 있는 청크가 상한을 넘으면 나머지를 다음 틱으로 민다.**
##
## 🔴🔴 **부르는 자리는 `_water_tick` 이고, 서브스텝 루프 「밖」이다** — 상한은 틱당 청크 수이지
##  서브스텝당이 아니다. ⚠ 안쪽에 두면 첫 컷이 `_awake` 를 이미 줄여 놓아 나머지 서브스텝은
##  `count()` 에서 그냥 통과하고, **실효 상한이 N배**가 된다(`_water_tick` 주석).
##
## 🔴🔴 **자르는 자리가 밴드 순회 「전」이어야 한다.** 밴드 안에서 「행 → 청크」로 도니까
##  **한 청크의 16행이 순회에서 연속된 구간이 아니다** — 루프 안에서 「N번째에서 멈춘다」를 하면
##  **한 청크의 행 절반만 도는 일**이 난다.
##  🔴🔴 **깨지는 것은 「물리」이지 「결정론」이 아니다.** 여기 「결정론이 깨진다」고 적혀 있었고
##   그건 틀렸다 — 같은 코드는 같은 순서로 **같게** 틀리므로 두 클라가 **똑같이** 틀린다.
##   ⇒ desync 가 아니라 **물이 청크 안에서 반만 흐르는 것**이고, 그건 화면에만 나온다.
##   ⚠ **그래서 결정론 그물로 원리적으로 못 잡는다**(`net_water` 의 그 함수 주석). 금지된 방식을
##    실제로 구현해 확인됐다(2026-08-07, verify-run). **잡는 자리가 없다 — 이 주석이 전부다.**
## ⇒ 순회 전에 순회 순서(밴드 내림차순 → dir 반대 방향 열)로 세어, 넘는 것을 **이번 틱에서만**
##  재운다. 🔴 **자르는 순서가 곧 상태다** — 그래서 `dir` 을 `_water_step` 과 **같은 문**
##  (`_water_dir`)으로 읽는다. ⚠ 서브스텝이 서면서 「같은 값」은 아니게 됐다 — 첫 서브스텝의 것이다.
##
## 🔴 **잘린 청크는 다음 틱에 돈다** — `_touch_chunk` 로 다시 찍는다. **버리는 게 아니다.**
##  ⚠ 안 찍으면 「상한에 걸린 물이 영영 안 움직인다」이고 그건 안전망이 아니라 고장이다.
##
## ⚠ **넘지 않으면 네이티브 `count()` 한 번(~2μs)에 끝난다.** 훑기는 넘을 때만 판다.
func _cap_awake_chunks(dir: int) -> void:
	if _awake.count(1) <= Tuning.MAX_CHUNKS_PER_TICK:
		return
	var kept := 0
	var band := CHUNK_H - 1
	while band >= 0:
		if _band_awake[band] > 0:
			var base := band * CHUNK_W
			var cx := (CHUNK_W - 1) if dir > 0 else 0
			while cx >= 0 and cx < CHUNK_W:
				var c := base + cx
				if _awake[c] != 0:
					if kept < Tuning.MAX_CHUNKS_PER_TICK:
						kept += 1
					else:
						_awake[c] = 0
						_band_awake[band] -= 1
						_touch_chunk(c, band)
				cx -= dir
		band -= 1


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
		var x := idx & X_MASK
		var y := idx >> X_SHIFT
		# 🔴🔴 **물이 불을 끈다 — 파면 쪽에서 본다.**
		#  ⚠ 물 쪽에서 「내 옆에 불이 있나」를 보면 **물이 든 모든 칸이 매 틱 이웃 넷을 읽고**,
		#   그건 고인 호수 전체를 깨우는 것이라 「깨어 있는 청크는 표면 띠뿐」이 통째로 무효가 된다.
		#   파면은 청크와 독립이므로 이 방향은 공짜다.
		# 🔴 **재료를 다시 쓴다**(`_mat[idx]` 그대로) — `_write_cell` 이 `_unburn`·`_flag`·`_aux`·
		#  `_changed`·`_touch` 를 **한 자리에서** 처리한다. 손으로 셋을 만지면 갈라진다.
		#  ⚠ 다 탄 칸의 `_write_cell(idx, EMPTY)` 와 같은 어법·같은 루프 위치라 swap-remove
		#   함정도 그 주석이 이미 다룬다.
		if _water_adjacent(x, y):
			_write_cell(idx, _mat[idx])
			i -= 1
			continue
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
			# 🔴 **네 방향이다.** 대각까지 열면 1셀 틈을 사선으로 새서 「돌에서 멈춘다」가 흐려진다.
			_ignite_cell(x - 1, y)
			_ignite_cell(x + 1, y)
			_ignite_cell(x, y - 1)
			_ignite_cell(x, y + 1)
		i -= 1


## 네 이웃 중에 물이 있나. 🔴 **대각은 안 본다** — 불의 번짐이 네 방향이라 같은 축이어야 한다.
##
## 🔴🔴 **「이웃에 물이 있다」이지 「이 나무가 젖었다」가 아니다.** 나무 칸 자체는 아무것도 안 바뀐다.
##  ⚠ `docs/design/물.md` 의 **「젖은 나무는 안 타나」는 여전히 미정이다**(사용자가 「나중 문제」로
##   미뤘다) — 그건 **물이 지나간 나무가 마른 뒤에도 안 타나**, 즉 나무가 젖음을 **기억하나**이다.
##  🔴 **이 함수는 그 물음에 답하지 않는다.** 여기 물이 빠지면 그 칸은 곧바로 다시 탄다.
##   ⇒ 이걸 「미정이 해결됐다」로 읽지 마라.
##
## 🔴🔴 **얕은 물은 못 끈다 — `WATER_WET` 초과여야 끈다** (2026-08-07, 사용자가 정했다).
##  ⚠ **이 함수가 「임계가 없다」였다.** 그 주석이 되살아나는 조건을 미리 적어 뒀고
##   — **「얇게 퍼진 한 톨이 큰 불을 끄는 게 화면에서 과할 때」** — 화면에서 정확히 그게 났다:
##   **F 한 번(797칸)이 좌우로 퍼져 숲 ≈860칸을 영구히 방화 처리한다.** 200초가 지나도 아직 자랐다.
##   ⇒ 물이 안 줄고 · 닿은 칸이 안 타고 · 계속 퍼지는 **셋의 곱**이었고, 여기가 가운데 항이다.
##
## 🔴🔴 **새 상수를 안 세웠다. `WATER_WET` 을 그대로 쓴다** — 「없는 세 번째 손잡이」를 안 만들려고.
##  ⚠ **그 값이 `FLAG_SHALLOW` 의 경계이므로 규칙과 화면이 같은 선을 쓴다:**
##  **밝은 하늘색으로 보이는 젖은 자국은 못 끄고, 어두운 남색 진짜 물만 끈다.**
##  ⇒ 「왜 이 물은 불을 못 끄나」가 **화면에 이미 그려져 있다.** 값을 바꾸면 둘이 같이 움직인다.
## 🔴 **비트가 아니라 `_aux` 를 본다** — `_flag` 는 거울이고 양이 원본이다(`_ignite_cell` 의 같은 함정).
##
## 🔴 **대각은 안 본다** — 불의 번짐이 네 방향이라 같은 축이어야 한다.
##
## 🔴🔴 **「이웃에 물이 있다」이지 「이 나무가 젖었다」가 아니다.** 나무 칸 자체는 아무것도 안 바뀐다.
##  ⚠ `docs/design/물.md` 의 **「젖은 나무는 안 타나」는 여전히 미정이다**(사용자가 「나중 문제」로
##   미뤘다) — 그건 **물이 지나간 나무가 마른 뒤에도 안 타나**, 즉 나무가 젖음을 **기억하나**이다.
##  🔴 **이 함수는 그 물음에 답하지 않는다.** 여기 물이 빠지면 그 칸은 곧바로 다시 탄다.
##   ⇒ 이걸 「미정이 해결됐다」로 읽지 마라.
##
## ⚠ **비용을 안 쟀다.** 부르는 자리 둘 다 이미 같은 지점에서 함수 호출 4회(`_ignite_cell`)를
##  하고 있어 자리수가 안 바뀐다고 보지만, **읽고 낸 판단이지 실측이 아니다.**
func _water_adjacent(x: int, y: int) -> bool:
	var row := y << X_SHIFT
	if x > 0 and _deep_water(row | (x - 1)):
		return true
	if x < W - 1 and _deep_water(row | (x + 1)):
		return true
	if y > 0 and _deep_water((row - W) | x):
		return true
	if y < H - 1 and _deep_water((row + W) | x):
		return true
	return false


## 이 칸이 **불을 끌 만큼** 물인가. 🔴 가장자리 가드는 부르는 쪽이 이미 봤다 —
##  여기서 또 보면 `_water_adjacent` 의 네 줄이 두 배가 되고 그 함수는 파면 루프 안이다.
func _deep_water(i: int) -> bool:
	return _mat[i] == Mat.WATER and _aux[i] > Tuning.WATER_WET


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
	# 🔴🔴 **젖은 곳 옆에는 애초에 안 붙는다. `_burn` 의 끄기만으로는 부족하다.**
	#  ⚠ 끄기만 두면 이렇게 된다: 이웃 불이 번져 붙는다 → 다음 틱에 꺼진다 → 그 이웃이 아직
	#   타므로 또 붙는다. **실측 37틱 연속**(2026-08-07, 이 줄을 넣기 전에 그물로 쟀다).
	#   화면엔 **물가에서 불이 깜빡이는 것**으로 보이고 그건 규칙이 아니라 고장으로 읽힌다.
	#  ⚠ **「영영 안 잠든다」는 아니다** — 이웃 나무의 연료가 다하면 끝나므로 **유한하다.**
	#   그래서 「끝나고 잠드나」로는 못 잡고 **틱마다 그 칸을 봐야** 잡힌다(`net_water` 의 그 검사).
	# 🔴 **이 검사가 여기 마지막인 이유**: 위 셋은 전부 O(1) 비교이고 이건 배열을 넷 읽는다 —
	#  안 붙을 칸에까지 이웃을 읽을 이유가 없다.
	if _water_adjacent(x, y):
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


## **적시기만.** 🔴 지형을 한 칸도 안 부수고 불도 안 붙인다 — 물 룬의 흔적이 지나는 문이다.
##
## 🔴🔴 **`cmd_ignite` 의 물 쪽 거울이고, `cmd_carve` 와 나란한 세 번째 흔적이다.**
##  ⚠ **`_disc` 로는 못 만든다** — 그 함수는 `_write_cell` 을 부르고 그건 `_aux` 를 0으로 만든다.
##   물이 그 문을 지나면 **양이 그 자리에서 증발한다**(재료만 WATER, 양은 0). 에러는 0이다.
##   ⇒ `_water_disc()` 가 따로 있고 `_write_water` 를 부른다.
##
## 🔴 **양을 커맨드가 들고 다닌다.** 반경만 보내고 양을 격자가 정하면, 세기마다 다른 물을
##  만들려 할 때 **`sim_tuning` 과 `cell_grid` 두 곳이 그 규칙을 나눠 갖게 된다.**
## 🔴 **커맨드라서 대역폭이 공짜다** — 네 정수면 각 클라가 같은 원반을 적신다(`cmd_blast` 와 같다).
static func cmd_water(x: int, y: int, r: int, amount: int) -> Dictionary:
	return {"kind": CMD_WATER, "x": x, "y": y, "r": r, "amount": amount}


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
		CMD_WATER:
			var wr := int(cmd["r"])
			var amount := int(cmd["amount"])
			# ⚠ 범위 검사는 **커맨드 경계에서 한 번만**이다(`_valid_mat` 과 같은 어법) —
			#  안쪽 원반 루프가 셀마다 보면 그게 곧 비용이고, 여기 한 번이면 충분하다.
			if amount < 0 or amount > Tuning.WATER_MAX:
				push_error("CellGrid.cmd_water: 양 %d 이 0~%d 밖이다" % [amount, Tuning.WATER_MAX])
			elif wr > 0 and amount > 0:
				_water_disc(int(cmd["x"]), int(cmd["y"]), wr, amount)
		_:
			push_error("CellGrid.apply: 모르는 커맨드 %s" % cmd)


## 🔴 `apply()`는 멀티에서 **클라가 서버에 보내는 문**이다. 검증 없이 두면 범위 밖 id 하나가
##  `_behavior[mat]`에서 **매 틱 엔진 「Index out of bounds」**를 낸다 — 그건 `SCRIPT ERROR`
##  grep에 안 걸리는 침묵사다. 255를 넘으면 `PackedByteArray`가 말없이 하위 8비트로 자르고,
##  셰이더는 `clamp`라 마젠타로 뜬다 ⇒ **시뮬과 렌더가 서로 다른 방식으로** 틀어진다.
## ⚠ 내부 루프가 아니라 **커맨드 경계**에서 한 번만 본다 — 채우기 하나가 `_write_cell`을 수천 번 돈다.
func _valid_mat(mat: int) -> bool:
	# 🔴🔴 **물은 여기로 못 들어온다.** `cmd_fill` 은 `_write_cell` 을 지나고 그건 `_aux` 를 0으로
	#  만든다 ⇒ **재료는 WATER인데 양이 0인 칸**이 생기고, `cell_materials.gd` 의 `_aux` 절이
	#  「원리적으로 없다」고 못 박은 상태가 실제로 선다.
	#  ⚠ 실측(2026-08-07, verify-read2): `cmd_fill(…, WATER)` 로 놓은 55칸이 **20틱 뒤 0개**다.
	#   첫 순회에서 `_water_fall` 이 양 0을 아래로 넘기고 그 칸을 EMPTY 로 만든다 — **조용히 증발한다.**
	# 🔴 **양을 여기서 지어내지 않는다.** `cmd_fill` 에는 양 칸이 없고, 255를 넣는 것은
	#  「채우기가 곧 가득 찬 물」이라는 **없는 규칙을 발명하는 것**이다. 물의 문은 양을 들고 온다
	#  (`set_water` · 단계 5의 `CMD_WATER`) ⇒ 여기서는 **짖고 버린다.**
	# ⚠ 맵에 물을 두는 날 지형 굽기가 이 줄에 부딪힌다. **그게 맞는 신호다** — 그때 물 커맨드가 선다.
	if mat == Mat.WATER:
		push_error("CellGrid: 물은 cmd_fill 로 못 놓는다 — 양이 없으면 그 자리에서 증발한다")
		return false
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
	# 🔴🔴 **청크를 깨우는 유일한 자리다**(`_touch` 주석). 폭발로 뚫은 그릇에서 물이 새는 것도,
	#  다 탄 자리로 물이 흘러드는 것도 전부 이 한 줄에 매달려 있다.
	_touch(i)


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
	# 🔴 청크도 직접 비운다. `fill`은 `_write_cell`을 안 지나 `_touch`가 한 번도 안 도므로
	#  **`_burning` 과 똑같은 함정이다** — 새 무대가 옛 dirty 를 들고 태어난다.
	# ⚠ 리셋 직후는 전부 EMPTY라 움직일 것이 원리적으로 없다 ⇒ **깨워 둘 이유가 없다.**
	#  지형은 리셋 뒤 `cmd_fill` 이 깔고, 그 채우기가 `_write_cell` 을 지나며 제 손으로 깨운다.
	_awake.fill(0)
	_dirty.fill(0)
	_band_awake.fill(0)
	_band_dirty.fill(0)
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


## 🔴🔴 **파면에 「탈 수 없는 재료」가 앉아 있나. 0이어야 한다.**
##
## ⚠ **`claimed_slot_count()` 와 `burning_count()` 로는 원리적으로 못 잡는다** — 그 둘은 **서로만**
##  맞대므로, 물 칸이 파면 소속을 주장해도 **두 수가 똑같다.**
## 🔴 그때 무슨 일이 나는가(2026-08-07, verify-read2가 `set_water` 가드를 빼고 재현했다):
##  물 칸이 `FLAG_BURNING` 을 달고 앉아 있고 `_burn()` 이 **물의 양을 연료로 먹는다**
##  (255 → 250 → 245 …). 물이 조용히 마르고, 다 마르면 그 칸이 EMPTY 가 된다.
## ⇒ **단계 6(물이 불을 끈다)의 전제다.** 거기서 두 축이 처음 같은 칸에서 만난다.
##
## 🔴 **재료 이름을 안 박고 연료 표에서 파생시킨다** — 「연료가 0인데 타고 있다」가 불변량이고,
##  그건 물뿐 아니라 돌·빈칸에도 그대로 걸린다. ⚠ **그물 전용 질의다**(파면을 훑는다).
func unburnable_in_front_count() -> int:
	var n := 0
	for k in _burning.size():
		if _fuel[_mat[_burning[k]]] <= 0:
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


## 물을 직접 놓는다. 🔴 **그물과 무대용 문이다** — `ignite` 와 정확히 같은 자리다.
##  게임 중 물은 물 룬이 만든다(단계 5의 `CMD_WATER`). **그때 커맨드가 서고, 이 문은 남는다.**
##
## 🔴🔴 **EMPTY 나 WATER 위에만 쓴다.** 타는 칸에 쓰면 `_burn_slot` 이 그 칸의 소속을 주장한 채
##  재료만 바뀌어 **파면에 유령이 남는다** — `_write_cell` 이 `_unburn` 을 부르는 이유가 그것이고,
##  물의 문은 파면을 안 만지므로 여기서 막는 것이 유일한 길이다.
## ⚠ 돌을 물로 바꾸지 않는 것도 같은 줄이 한다 — 지형을 지우는 것은 **파괴의 일**이다.
##
## 🔴 **양의 범위를 여기서 본다**(`_valid_mat` 과 같은 어법 — 커맨드 경계에서 한 번만).
##  `_aux` 가 `PackedByteArray` 라 255를 넘으면 **에러 없이 하위 8비트로 잘린다.**
func set_water(x: int, y: int, amount: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	if amount < 0 or amount > Tuning.WATER_MAX:
		push_error("CellGrid.set_water: 양 %d 이 0~%d 밖이다" % [amount, Tuning.WATER_MAX])
		return false
	var i := (y << X_SHIFT) | x
	if _mat[i] != Mat.EMPTY and _mat[i] != Mat.WATER:
		return false
	_write_water(i, amount)
	return true


## 이번 틱에 도는 청크 수.
##
## 🔴🔴 **「물이 멈췄나」를 값으로 읽는 유일한 자리다.** 「안 움직이는 것 같다」로는 못 잰다 —
##  v1은 물이 멈춘 것처럼 보이는데 안 멈추고 있었고, 그게 번개를 죽였다(`docs/design/물.md`).
## ⚠ **실측 2.25μs**(2026-08-07, verify-run · 2000회 × 2세트). 네이티브 `count()` 라 16,128칸이고,
##  `count_material` 이 4,128,768칸에 588μs인 비례와도 맞는다. HUD가 매 프레임 불러도 무시 가능하다.
func active_chunk_count() -> int:
	return _awake.count(1)


## 그 셀이 든 청크가 이번 틱에 도나.
## ⚠ **격자 밖은 거짓이다** — `mat_at` 이 격자 밖을 고체로 주는 것과 다른 축이다.
##  여기서 「밖은 늘 깨어 있다」로 두면 경계 이동 검사가 **아무것도 안 재게 된다.**
##
## 🔴 **변경 직후가 아니라 다음 `step()` 부터 참이다.** 격자를 바꾸는 문은 `_dirty` 를 찍고,
##  그게 `awake` 가 되는 것은 `_chunk_flip()` 이다 — 「이번 틱에 돈다」의 뜻이 그것이다.
func chunk_awake_at(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0 or y >= H:
		return false
	return _awake[(y / Tuning.CHUNK_CELLS) * CHUNK_W + (x / Tuning.CHUNK_CELLS)] != 0


## 밴드의 깨어 있는 청크 수 — **순회가 밴드를 통째로 건너뛸 때 읽을 값이다**(`_band_awake` 주석).
func band_awake_count(band: int) -> int:
	if band < 0 or band >= CHUNK_H:
		return 0
	return _band_awake[band]


## 🔴🔴 **밴드 요약의 독립 측정.** 위 `band_awake_count` 는 `_touch` 가 **증분으로** 든 값이고,
##  이건 `_awake` 를 **직접 세어** 만든 값이다.
##
## ⚠ **둘이 갈라지는 쪽은 늘 요약이다**(`claimed_slot_count` 와 정확히 같은 자리). 요약이 0으로
##  낮으면 순회가 **깨어 있는 밴드를 통째로 건너뛰고**, 그 물은 그 자리에 얼어붙는다 —
##  에러도 없고 화면엔 「보이지 않는 벽」으로만 나온다.
## ⚠ **그물 전용이다.** 청크 행을 훑으므로 게임 루프에서 부르지 마라.
func scan_awake_in_band(band: int) -> int:
	if band < 0 or band >= CHUNK_H:
		return 0
	var n := 0
	var base := band * CHUNK_W
	for k in CHUNK_W:
		if _awake[base + k] != 0:
			n += 1
	return n
