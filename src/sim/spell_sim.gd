extends RefCounted
## 마법 투사체 시뮬 + **문양 파이프라인** — 순수 객체다. 씬 트리를 모른다.
##
## 🔴🔴 **투사체는 노드가 아니다.** 고정 크기 평행 배열이고, 그리는 건 노드 하나가 통째로 한다.
##  이 결정이 사는 값 넷: ① 서버가 씬 없이 돌리고 그물이 씬 없이 돈다 ② 풀링이 불필요하다
##  ③ `add_child`-물리콜백 함정이 **소멸한다** ④ `queue_free`+그룹 함정이 **소멸한다.**
##  ⚠ 「투사체 = 노드」로 바꾸는 순간 ③④가 둘 다 돌아온다.
##
## ══ 🔴🔴 이 파일의 계약 — **정수만** ═══════════════════════════════
##  위치·속도는 **고정소수점 1/256셀**이다. `Vector2`(32비트 float)·`sqrt`·삼각함수·
##  `randi()`·`Time`·`delta`가 **하나도 없다.** 화면 좌표로 옮기는 일은 렌더가 한다.
##
##  왜 이렇게까지 하나 — **락스텝에서 선을 넘는 건 발사 커맨드 하나뿐이기 때문이다.**
##  비행도 폭발도 격자 변경도 **각 클라가 스스로 재현**해야 하므로, 비행이 결정론적이지 않으면
##  폭발 셀이 하나 어긋나고, 그 셀이 지형을 바꾸고, **두 클라의 세상이 영원히 다른 세상이 된다.**
##  ⇒ 「같은 float 연산이면 어차피 같은 답 아니냐」는 위험하다: `+ - *`는 IEEE-754가 비트까지
##   같지만 **`sqrt`·`sin`·`atan2`는 libm이라 플랫폼마다 다르고**, 조준 정규화가 정확히 거기다.
##
##  🔴 **`sin`/`cos` 테이블도 안 만든다.** 부팅 때 float으로 구우면 그 굽는 값이 다시 플랫폼
##   의존이 된다. ⇒ 정규화는 **정수 뉴턴법 `_isqrt`** 하나로 하고, 발사할 때 **한 번만** 돈다.
##
##  🔴 **돌려서 비교하는 그물은 이 계약을 원리적으로 못 지킨다** — 같은 프로세스의 두 인스턴스는
##   float도 똑같은 답을 낸다. `net_determinism`의 **폴더 텍스트 스캔**이 유일한 감지기다.
## ══════════════════════════════════════════════════════════════════

const CellGrid := preload("res://src/sim/cell_grid.gd")
const Mat := preload("res://src/sim/cell_materials.gd")
const Tuning := preload("res://src/sim/sim_tuning.gd")
const Glyph := preload("res://src/sim/glyph_defs.gd")

## 고정소수점: 하위 8비트가 소수부다. 셀 좌표 = pos >> FP_SHIFT.
## 정밀도 4px / 256 = 0.0156px — 차고 넘친다.
## ⚠ `>>`는 산술 시프트라 **음수에서도 내림**이다(격자 밖에서도 셀 좌표가 안 튄다).
const FP_SHIFT := 8
const FP_ONE := 1 << FP_SHIFT
const FP_HALF := FP_ONE >> 1

## 조준 정규화의 중간 정밀도. 🔴 이게 없으면 짧은 조준 벡터에서 `_isqrt`의 절삭이
##  속도를 40%까지 부풀린다(예: 조준 (1,1)에서 isqrt(2)=1이라 속도가 √2배가 된다).
##  ⚠ **축 방향만 재는 그물로는 이 값을 0으로 죽여도 안 보인다** — 그물이 대각을 재는 이유다.
const AIM_SHIFT := 8

## 조준 성분의 절대 상한. 🔴 발사 커맨드의 조준은 **i16 두 개**가 계약이다.
##  넘으면 `len2 << 16`이 오버플로해서 조용히 틀어진다.
const AIM_MAX := 32767

## 🔴 격자 커맨드와 **다른 키 이름**(`spell_kind`)을 쓴다 — 같은 `kind` 키를 공유하면
##  두 enum의 숫자가 겹쳐 `CellGrid.apply`가 엉뚱한 걸 실행하고, 값이 우연히 유효 범위면
##  **에러 하나 없이** 발사가 채우기가 된다.
const CMD_FIRE := 0

## 확산의 8방향. 🔴 원을 따라 도는 순서다 — 순서가 결정론 계약의 일부다(발사 순서가
##  슬롯 순서를 정하고, 슬롯 순서가 폭발 예산에 걸리는 순서를 정한다).
const SPREAD_DX: Array[int] = [1, 1, 0, -1, -1, -1, 0, 1]
const SPREAD_DY: Array[int] = [0, 1, 1, 1, 0, -1, -1, -1]

# ─── 상태 ─────────────────────────────────────────────────────────
## ⚠ **평행 배열이다.** `Array[Dictionary]`로 두면 틱마다 32개 딕셔너리를 만진다.
## ⚠ `PackedInt32Array`를 **인자로 넘기지 마라** — CoW 사본이 되어 쓰기가 조용히 증발한다.
##  전부 멤버로 두고 여기서 직접 만진다.
var _px := PackedInt32Array()
var _py := PackedInt32Array()
var _vx := PackedInt32Array()
var _vy := PackedInt32Array()
## 렌더 보간용 직전 위치. 🔴 시뮬은 이걸 **안 읽는다** — 순수하게 화면 몫이다.
var _prev_px := PackedInt32Array()
var _prev_py := PackedInt32Array()
## 🔴 **남은 문양 목록**(`glyph_defs.gd`). 정수 하나다.
var _glyphs := PackedInt32Array()
var _element := PackedByteArray()
var _age := PackedInt32Array()
## 🔴🔴 **확산 세대.** 0 = 원본. **크기·사거리·폭발 반경·점화 반경·연출이 전부 여기서 파생된다**
##  (`sim_tuning.SIM_SIZES` · `fx_tuning.FX_SIZES`).
##  ⚠ 두 표가 **같이** 길어져야 한다 — 시뮬 축만 늘고 화면이 안 따라가는 것이 v1이 죽은 방식이고,
##   `net_tables`가 길이와 단조를 같이 잰다.
var _gen := PackedByteArray()

## 🔴 슬롯 인덱스는 **틱마다 뒤바뀐다**(소멸이 swap-remove다). 렌더가 자취를 인덱스로 들고 있으면
##  투사체가 죽는 순간 남의 자취가 순간이동한다 — 에러 없이 화면만 이상해진다.
##  ⇒ 렌더는 반드시 `get_id()`로 짝을 맞춰라.
var _id := PackedInt32Array()
## 🔴 **리셋에서 안 되돌린다 — 리셋을 넘어 단조 증가한다.** 되돌리면 리셋 뒤 첫 투사체가
##  id 0을 다시 쓰고, 렌더의 자취가 id로 짝을 맞추니 **옛 자취가 새 투사체에 달라붙는다.**
var _next_id := 0

var _count := 0
var _behavior := PackedByteArray()

# ─── 틱 예산 ──────────────────────────────────────────────────────
## 🔴 문양별 「한 틱에 몇 번까지」. `_cap`은 구운 표(불변), `_left`는 이번 틱에 남은 수다.
##  ⚠ **파이프라인이 특정 문양 id를 모르는 게 요점이다** — 예산은 `glyph_defs.DEFS`의 한 칸이고
##   여기는 그걸 인덱싱만 한다. 새 문양에 예산이 붙어도 이 파일은 안 바뀐다.
var _budget_cap := PackedInt32Array()
var _budget_left := PackedInt32Array()

## 🔴🔴 예산이 떨어져 **다음 틱으로 민 파이프라인.**
##  ⚠ 밀리는 것은 폭발 하나가 아니라 **남은 목록째**다. 폭발만 미루고 나머지를 지금 돌리면
##   「폭발 → 확산」이 「확산 → 폭발」이 되고, GDD가 그 둘을 **다른 마법**이라고 못 박았다 —
##   에러 하나 없이 마법의 종류가 바뀐다.
## ⚠ 길이 상한은 투사체 상한(32) × 층 상한(7)이라 저절로 유한하다.
var _pend_x := PackedInt32Array()
var _pend_y := PackedInt32Array()
var _pend_g := PackedInt32Array()
var _pend_e := PackedByteArray()
## ⚠ 세대도 같이 민다 — 안 밀면 밀린 폭발이 **세대 0 크기로** 터져서, 몰아 쏠 때만
##  작은 폭발이 커진다. 눈으로는 「가끔 유난히 크게 터진다」로만 보인다.
var _pend_gen := PackedByteArray()

## 이번 틱에 터진 폭발 — 🔴 **연출의 유일한 통지다.** 시뮬은 이걸 **안 읽는다.**
##  ⚠ `step()` 시작에서 지운다. 껍데기가 지우게 두면 한 번 깜빡하는 순간 같은 섬광이
##   **영원히 재생되고**, 에러는 안 난다.
var _fx_x := PackedInt32Array()
var _fx_y := PackedInt32Array()
var _fx_e := PackedByteArray()
var _fx_g := PackedByteArray()


func _init() -> void:
	var n := Tuning.MAX_PROJECTILES
	_px.resize(n)
	_py.resize(n)
	_vx.resize(n)
	_vy.resize(n)
	_prev_px.resize(n)
	_prev_py.resize(n)
	_glyphs.resize(n)
	_element.resize(n)
	_age.resize(n)
	_gen.resize(n)
	_id.resize(n)
	# 🔴 재료 거동과 문양 예산은 **구워서 받는다** — 여기서 다시 정의하면 규칙이 두 벌이 된다.
	_behavior = Mat.bake_behavior()
	_budget_cap = Glyph.bake_tick_budget()
	_budget_left.resize(_budget_cap.size())


# ══════════════════════════════════════════════════════════════════
#  커맨드
# ══════════════════════════════════════════════════════════════════

## 🔴🔴 **선을 넘는 건 이것 하나다.** 비행도 폭발도 격자 변경도 각 클라의 결정론적 귀결이라
##  **폭발이 아무리 커도 대역폭은 0**이다.
## ⚠ `adx`·`ady`는 **셀 단위 정수 차이**다 — 마우스 float이 `src/actor/aim.gd`에서 딱 한 번 양자화된다.
static func cmd_fire(ox: int, oy: int, adx: int, ady: int, element: int, glyphs: int) -> Dictionary:
	return {
		"spell_kind": CMD_FIRE, "ox": ox, "oy": oy,
		"adx": adx, "ady": ady, "element": element, "glyphs": glyphs,
	}


## 발사. 받아들였으면 true.
## ⚠ **false가 곧 에러는 아니다** — 상한에 걸렸거나 조준이 0이면 조용히 버리는 게 맞다
##  (원점을 그대로 클릭하는 건 정상 입력이다). 모르는 값만 짖는다.
func fire(cmd: Dictionary) -> bool:
	# 🔴🔴 **발사는 설계상 선을 넘는 유일한 커맨드다 — 검증을 여기서 안 하면 할 데가 없다.**
	#  `_px`가 `PackedInt32Array`라 범위 밖 원점은 **에러 없이 32비트로 잘린다**(v1 실측:
	#  ox = 10,000,000 → 저장값 -1,734,967,168 ⇒ 투사체가 격자 반대편에서 시작한다).
	#  ⚠ 그리고 그 잘림은 **결정론적**이라 desync조차 안 나고 **아무도 안 짖는다.**
	#   로컬 마우스로는 도달 불가지만 네트워크는 그 문을 연다.
	if int(cmd.get("spell_kind", -1)) != CMD_FIRE:
		push_error("SpellSim: 모르는 주문 커맨드 %s — 발사를 버린다" % cmd)
		return false
	var element := int(cmd.get("element", -1))
	if not Tuning.ELEM_ALL.has(element):
		push_error("SpellSim: 모르는 룬 %d — 발사를 버린다" % element)
		return false
	var ox := int(cmd.get("ox", 0))
	var oy := int(cmd.get("oy", 0))
	if ox < 0 or ox >= CellGrid.W or oy < 0 or oy >= CellGrid.H:
		push_error("SpellSim: 격자 밖 원점 (%d,%d) — 발사를 버린다" % [ox, oy])
		return false
	var adx := int(cmd.get("adx", 0))
	var ady := int(cmd.get("ady", 0))
	if absi(adx) > AIM_MAX or absi(ady) > AIM_MAX:
		push_error("SpellSim: 조준 (%d,%d)이 i16 범위 밖이다 — 발사를 버린다" % [adx, ady])
		return false
	var glyphs := int(cmd.get("glyphs", Glyph.GLYPH_NONE))
	if not _valid_glyphs(glyphs):
		return false

	return _launch((ox << FP_SHIFT) + FP_HALF, (oy << FP_SHIFT) + FP_HALF,
		adx, ady, glyphs, element, 0)


## 🔴🔴 **문양 제약이 조립 시점이 아니라 여기서도 걸린다.** GDD가 폭증을 상한이 아니라
##  제약으로 막기로 했고(「확산은 한 마법진에 하나만」), 그 표의 소비자가 이 함수다.
##  ⇒ 조립창(B)이 **같은 표를 읽어** 놓기 전에 막는다 — 규칙이 두 벌이 되지 않는다.
func _valid_glyphs(glyphs: int) -> bool:
	var cur := glyphs
	var layers := 0
	while cur != Glyph.GLYPH_NONE:
		var id := Glyph.first(cur)
		if not Glyph.DEFS.has(id):
			push_error("SpellSim: 모르는 문양 id %d — 발사를 버린다" % id)
			return false
		var cap := int(Glyph.DEFS[id]["max_per_circle"])
		if cap > 0 and Glyph.count_of(glyphs, id) > cap:
			push_error("SpellSim: 문양 %s가 한 마법진에 %d개까지다 — 발사를 버린다" % [
				Glyph.DEFS[id]["name"], cap])
			return false
		layers += 1
		cur = Glyph.rest(cur)
	if layers > Tuning.GLYPH_MAX_LAYERS:
		push_error("SpellSim: 층이 %d개다 — 상한은 %d다" % [layers, Tuning.GLYPH_MAX_LAYERS])
		return false
	return true


## 🔴 **발사와 확산이 같은 문을 지난다.** 둘이 각자 정규화하면 「확산 8발만 속도가 다르다」가
##  되고, 그건 눈으로는 「퍼지는 모양이 이상하다」로만 보인다.
## ⚠ 인자는 **고정소수점 위치**다(셀이 아니다) — 확산은 착탄점 한가운데에서 나가야 한다.
func _launch(pfx: int, pfy: int, adx: int, ady: int,
		glyphs: int, element: int, gen: int) -> bool:
	if _count >= Tuning.MAX_PROJECTILES:
		# 🔴 **짖고 버린다.** 싱글에서 확산이 한 마법진에 하나뿐이라 1 → 8발이 상한이고,
		#  32에 원리적으로 도달할 수 없다. 도달하면 그건 버그이므로 짖어야 한다
		#  (래퍼가 stderr를 실패로 치니 아무도 못 놓친다).
		push_error("SpellSim: 동시 투사체 상한 %d을 넘었다" % Tuning.MAX_PROJECTILES)
		return false
	var len2 := adx * adx + ady * ady
	if len2 <= 0:
		return false
	# 🔴 유일한 양자화 지점이자 유일한 제곱근이다. 비행 중에는 다시 안 돈다.
	var norm := _isqrt(len2 << (AIM_SHIFT + AIM_SHIFT))
	if norm <= 0:
		return false

	# 🔴 속도도 세대 표에서 나온다 — 「작아지고 약해진다」에는 **덜 멀리 간다**가 포함된다.
	#  항력 사거리 상한 = speed / (1 − DRAG) 이므로 이 한 줄이 사거리를 통째로 정한다.
	var speed_fp := Tuning.speed_cells(gen) << FP_SHIFT
	var i := _count
	_px[i] = pfx
	_py[i] = pfy
	_prev_px[i] = pfx
	_prev_py[i] = pfy
	_vx[i] = (adx << AIM_SHIFT) * speed_fp / norm
	_vy[i] = (ady << AIM_SHIFT) * speed_fp / norm
	_glyphs[i] = glyphs
	_element[i] = element
	_age[i] = 0
	_gen[i] = gen
	_id[i] = _next_id
	_next_id += 1
	_count = i + 1
	return true


## ⚠ **밀린 파이프라인도 같이 지운다.** 안 지우면 R로 무대를 새로 지은 다음 틱에
##  앞 실험의 폭발이 새 지형에 구멍을 낸다 — 두 조합을 비교하는 판정 1·2가 거기서 죽는다.
## 🔴 `_next_id`는 **되돌리지 않는다**(위 주석).
func reset() -> void:
	_count = 0
	_pend_x.clear()
	_pend_y.clear()
	_pend_g.clear()
	_pend_e.clear()
	_pend_gen.clear()
	_clear_fx()


# ══════════════════════════════════════════════════════════════════
#  틱
# ══════════════════════════════════════════════════════════════════

## 🔴 **호출 순서가 계약이다**: 1. 외부 커맨드 배수 2. `grid.step()` 3. `spell.step(grid)`.
##  투사체는 **셀이 움직인 뒤의 격자**를 상대로 난다.
##
## ⚠ 이 안의 순서도 계약이다: **밀린 것을 먼저 갚고 새 착탄을 본다.** 뒤집으면 이번 틱 착탄이
##  예산을 다 먹어 밀린 것이 영원히 못 터진다 — 「몰아 쏘면 몇 발이 안 터진다」의 다른 얼굴이다.
func step(grid: CellGrid) -> void:
	_clear_fx()
	for id: int in Glyph.ALL:
		_budget_left[id] = _budget_cap[id]
	_drain_pending(grid)

	var i := 0
	while i < _count:
		if _advance(grid, i):
			i += 1
		else:
			_remove(i)


## 투사체 하나. 살아남으면 true.
func _advance(grid: CellGrid, i: int) -> bool:
	_age[i] += 1
	if _age[i] > Tuning.LIFETIME_TICKS:
		return false

	# 🔴🔴 **이 두 줄이 궤적 규칙의 전부다**(기획 「궤적」).
	#  속도가 클 때는 관성이 중력을 이겨서 거의 직진처럼 보이고, 느려지면 중력이 이겨서 처진다.
	#  「N틱 동안 직진하다 그 뒤에 떨어진다」를 규칙 하나가 저절로 만든다 — **꺾이는 순간이 없다.**
	#  ⚠ 순서가 계약이다: 항력을 **먼저** 곱하고 중력을 **나중에** 더한다. 뒤집으면 이번 틱에
	#   더한 중력까지 감쇠돼서 종단 속도가 DRAG배만큼 낮아진다(눈으로는 「덜 무겁다」로만 보인다).
	_vx[i] = _vx[i] * Tuning.DRAG_NUM / Tuning.DRAG_DEN
	_vy[i] = _vy[i] * Tuning.DRAG_NUM / Tuning.DRAG_DEN + Tuning.GRAVITY_FP

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
##  첫 틱에 10셀을 뛰므로 도착 칸만 보면 **1~2타일 벽을 그냥 통과한다.** 한 프레임이라
##  **눈으로 절대 못 본다** — 사용자에게는 「가끔 안 터진다」로만 보인다.
##
## ⚠ **시작 칸은 검사하지 않는다.** 지난 틱에 이미 봤고(통과했으니 살아 있다),
##  첫 틱의 시작 칸은 지팡이 끝이다 — 캐릭터가 벽에 붙어 있으면 거기서 바로 터지는 게 맞다.
## ⚠ Bresenham은 **대각 모서리를 스쳐 지나간다.** 🔴 「지형 최소 두께가 4셀이라 안 걸린다」는
##  초기 맵에서만 참이고, **폭발 자신이 그 전제를 깬다** — 정수 원반이 지형을 깎으면
##  1셀짜리 대각 조각이 생긴다. ⇒ 실게임에서 **「가끔 안 터진다」가 보고되면 여기가 첫 용의자다.**
##  답은 supercover DDA인데 비용이 늘고 이 단계가 재는 것과 무관해서 **일부러 안 바꿨다.**
func _walk(grid: CellGrid, i: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var cx := x0
	var cy := y0
	# 🔴 착탄점은 **고체 셀이 아니라 그 직전 빈 셀**이다. 확산이 고체 셀에서 8발을 뿌리면
	#  8발이 전부 벽 안에서 태어나 **그 자리에서 다 터진다** — 폭발 8번이 폭발 1번으로 보이고
	#  판정 2가 통째로 죽는다. 폭발도 같은 점을 쓴다(1셀 차이는 반경 12셀 원에서 안 보인다).
	var fx := x0
	var fy := y0

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
			return false  # 격자 밖 = 착탄 없이 소멸
		if _behavior[grid.mat_at(cx, cy)] != Mat.BEHAVIOR_STATIC:
			fx = cx
			fy = cy
			continue
		_impact(grid, fx, fy, i)
		return false
	return true


func _impact(grid: CellGrid, x: int, y: int, i: int) -> void:
	# 🔴 **룬 흔적이 문양보다 먼저다.** 흔적은 바닥값이고 문양이 그 위에 얹힌다.
	_rune_trace(grid, x, y, _element[i], _gen[i])
	_resume(grid, x, y, _glyphs[i], _element[i], _gen[i])


## 🔴🔴 **문양이 하나도 없어도 착탄은 룬만큼은 한다**(기획 「탄은 문양이 없어도 룬의 흔적을 남긴다」).
##
## ⚠ **조건 분기가 없는 게 요점이다.** 「목록이 비었을 때만」으로 짜면 규칙이 둘이 되고,
##  그 둘이 갈라지는 날 「어떤 탄은 흔적을 남기고 어떤 탄은 안 남긴다」가 된다.
##  ⇒ **모든 착탄이 흔적을 남긴다.** `net_spell._glyph_bolt_also_traces`가 그 결정을 지킨다.
##
## ⚠ **그 대가를 정확히 적어 둔다 — 「덮어쓰기」가 아니다.**
##  폭발이 뒤따르면 `rune_r < rd` 가 계약이고 둘이 **같은 점**을 쓰므로 흔적의 원반이 폭발의
##  원반에 통째로 들어간다 ⇒ **관측 가능한 효과가 0이고, 남는 것은 파면의 유령 인덱스뿐이다**
##  (지워진 칸이 `_burning`에 한 틱 남는다. 실측으로 키 4에서 217칸 중 90칸 = **41%**가 유령이었다).
##  🔴 자가 치유는 이 빈도에서도 한 틱에 성립하지만, **파면 정리가 필요한 근거가 여기 있다** —
##   물이나 지형 재생성이 들어오면 그 유령이 실제 버그가 된다.
##
## 🔴 **지형은 안 부순다. 점화만 한다.** 부수면 확산이 폭발을 겸하게 되고,
##  그러면 「확산→폭발」과 「폭발→확산」이 화면에서 다시 뭉개진다 — 이 단계가 재려는 바로 그 차이다.
## 🔴 **모르는 흔적에 짖는다.** 그물이 `ELEM_ALL`을 한 번씩 착탄시키면 표에만 있고 코드에 없는
##  룬이 래퍼의 stderr 검사에 **공짜로** 걸린다(`_run_glyph`와 같은 장치다).
func _rune_trace(grid: CellGrid, x: int, y: int, element: int, gen: int) -> void:
	var trace := int(Tuning.ELEM_DEFS[element]["trace"])
	if trace == Tuning.TRACE_IGNITE:
		grid.apply(CellGrid.cmd_ignite(x, y, Tuning.rune_r(gen)))
		return
	push_error("SpellSim: 룬 흔적 %d에 구현이 없다" % trace)


## 🔴🔴 **문양 파이프라인.** 착탄점에서 목록의 **첫 문양**부터 실행한다.
##
##  · **탄을 만드는 문양**(SPAWN) → 새 탄들에게 남은 목록을 넘기고 **여기서 끝난다**
##  · **그 자리에서 끝나는 문양**(TERMINAL) → 탄이 안 생기므로 **같은 자리에서 이어 실행한다**
##
## 🔴 목록이 비면 그걸로 끝이다 — **그게 「문양을 다 빼고 쏘면 쏴져야 한다」와 같은 코드 경로다.**
## 🔴 무한이 될 수 없다: `rest`가 매번 4비트씩 줄어 최대 7번이면 0이다.
##
## ⚠ 착탄 지점이 아니라 **위치·목록·룬만** 받는 이유: 밀린 파이프라인을 다음 틱에 이어 돌릴 때
##  그 투사체는 이미 없다. 슬롯 인덱스에 매달리면 그때 이어 돌 방법이 없어진다.
func _resume(grid: CellGrid, x: int, y: int, glyphs: int, element: int, gen: int) -> void:
	var g := glyphs
	while g != Glyph.GLYPH_NONE:
		var id := Glyph.first(g)
		# 🔴 예산이 떨어지면 **남은 목록째로** 민다(위 `_pend_*` 주석). 여기서 이 문양만 빼고
		#  나머지를 계속 돌리면 순서가 뒤집혀 다른 마법이 된다.
		# ⚠ 0 = 무제한이라 **세지도 않는다.** 세면 카운터가 음수로 흘러 뜻이 없어진다.
		if _budget_cap[id] > 0:
			if _budget_left[id] <= 0:
				_defer(x, y, g, element, gen)
				return
			_budget_left[id] -= 1
		g = _run_glyph(grid, x, y, id, Glyph.rest(g), element, gen)


## 문양 하나를 실행하고 **이어서 실행할 남은 목록**을 돌려준다.
## 목록을 새 탄에게 넘겼거나 모르는 문양이면 `GLYPH_NONE`(= 여기서 끝)을 돌려준다.
##
## 🔴 **모르는 id에 짖는다.** 그물이 `Glyph.ALL`을 한 번씩 실행하면 표에만 있고 코드에 없는
##  문양이 래퍼의 stderr 검사에 **공짜로** 걸린다.
## ⚠ `match`가 아니라 `if`인 이유: `match`에서 `Glyph.GLYPH_BLAST` 같은 속성 접근은
##  **바인딩 패턴으로 읽힐 위험**이 있고, 그러면 모든 id가 첫 갈래에 걸려도 에러가 안 난다.
func _run_glyph(grid: CellGrid, x: int, y: int, id: int, rest: int,
		element: int, gen: int) -> int:
	if id == Glyph.GLYPH_BLAST:
		# 🔴 격자를 바꾸는 문은 `apply(cmd)` 하나다 — 여기서 `_mat`을 직접 만지면
		#  나중에 붙는 부수효과(깨우기·점화)를 통째로 건너뛰고 **에러 없이 아무 일도 안 난다.**
		var rd := Tuning.blast_rd(gen)
		grid.apply(CellGrid.cmd_blast(x, y, rd, Tuning.blast_ignite_r(gen)))
		_notify_blast(x, y, element, gen)
	elif id == Glyph.GLYPH_SPREAD:
		# 🔴🔴 **「하한에 막혔다」와 「슬롯이 없다」를 반드시 가른다.** 둘 다 「탄이 안 생겼다」지만
		#  앞은 **설계된 정상 경로**라 조용해야 하고 뒤는 **버그**라 짖어야 한다.
		#  한 갈래로 묶으면 버그가 정상 경로의 침묵 뒤에 숨는다.
		if gen >= Tuning.SPLIT_MAX:
			# 🔴 **크기 하한**(GDD). 탄이 안 생겼으니 목록을 넘길 데가 없다 ⇒ 같은 자리에서 이어 간다.
			#  ⚠ **지금은 도달 불가다** — 확산이 한 마법진에 하나뿐이라(`max_per_circle: 1`)
			#   세대 1 탄이 확산을 들 수가 없다. 그 제약이 느슨해지는 날을 위한 구조적 바닥이고,
			#   **그물도 이 갈래엔 못 닿는다**(공개 API로 만들 수 없는 상태다).
			return rest
		if _spread(x, y, rest, element, gen) == 0:
			# 🔴🔴 **슬롯이 하나도 없다 = 버그다.** 여기서 `return rest`를 하면 남은 목록이
			#  **착탄점에서 세대 0으로** 실행된다 — 「확산 → 폭발」이 작은 구멍 여덟 대신
			#  **큰 구멍 하나**가 되고, GDD가 **다른 마법**이라고 못 박은 그 차이다.
			#  ⇒ 조용히 다른 마법이 되느니 **짖고 버린다**(계획 9: 확산은 밀지 않는다).
			push_error("SpellSim: 확산이 슬롯을 하나도 못 얻었다 — 남은 목록 %d를 버린다" % rest)
			return Glyph.GLYPH_NONE
	else:
		push_error("SpellSim: 문양 %d에 구현이 없다" % id)
		return Glyph.GLYPH_NONE

	# 🔴🔴 **이어질지 끝날지는 id가 아니라 표의 `kind`가 고른다** — GDD가 「이 구분이 파이프라인의
	#  전부」라고 적은 축이고, 여기가 그 축의 **유일한 소비자**다.
	#   · SPAWN    새 탄들이 남은 목록을 들고 갔다 ⇒ 여기서 끝
	#   · TERMINAL 탄이 안 생겼다 ⇒ 같은 자리에서 이어 실행
	#  ⚠ 이 분기가 없으면 `kind`를 바꿔도 아무 일이 안 일어나고, 그러면 표와 코드가 갈린 채로
	#   「문양의 실행 규칙」이 주석에만 남는다.
	if int(Glyph.DEFS[id]["kind"]) == Glyph.KIND_SPAWN:
		return Glyph.GLYPH_NONE
	return rest


## 🔴🔴 **확산 — 착탄점에서 8방향으로 작은 탄을 뿌리고 남은 목록을 그들에게 넘긴다.**
##  **실제로 태어난 수**를 돌려준다. 크기 하한 판정은 호출부가 한다(위 주석).
##
## 🔴 `(±1,0) (0,±1) (±1,±1)` **여덟 개는 `sin`·`cos` 없이 정수로 그대로 나온다** —
##  문양의 정수 제약이 여기서는 비용이 아니다(GDD).
## ⚠ 정규화는 `_launch`가 한다 — 여기서 대각을 따로 보정하면 「대각 넷만 더 빠르다」가 되고,
##  그건 화면에서 **찌그러진 방사형**으로만 보인다.
## ⚠ **일부만 나는 것도 버그다** — 방사형이 한쪽으로 찌그러진다. `_launch`가 슬롯 상한에
##  이미 짖으므로 여기서 다시 짖지 않는다(같은 사실을 두 번 짖으면 사면 선언이 넓어진다).
func _spread(x: int, y: int, rest: int, element: int, gen: int) -> int:
	# ⚠ 착탄점 **한가운데**에서 나간다. 셀 모서리에서 내보내면 여덟 방향이 비대칭이 된다.
	var pfx := (x << FP_SHIFT) + FP_HALF
	var pfy := (y << FP_SHIFT) + FP_HALF
	var born := 0
	for k in Tuning.SPREAD_COUNT:
		# 🔴 **남은 목록을 그대로 넘긴다**(`rest`) — 이 정수 대입 하나가 GDD의
		#  「탄을 만드는 문양은 새 탄들에게 남은 목록을 넘긴다」 전부다.
		if _launch(pfx, pfy, SPREAD_DX[k], SPREAD_DY[k], rest, element, gen + 1):
			born += 1
	return born


func _defer(x: int, y: int, glyphs: int, element: int, gen: int) -> void:
	_pend_x.append(x)
	_pend_y.append(y)
	_pend_g.append(glyphs)
	_pend_e.append(element)
	_pend_gen.append(gen)


## 🔴🔴 **시작 시점의 개수만 돈다.** 이번 틱에 다시 밀린 것을 같은 틱에 또 보면
##  예산이 0인 채로 `_resume`이 곧장 다시 밀어서 **프레임이 통째로 멈춘다**(에러 없이 얼어붙는다).
func _drain_pending(grid: CellGrid) -> void:
	var n := _pend_x.size()
	if n == 0:
		return
	for k in n:
		_resume(grid, _pend_x[k], _pend_y[k], _pend_g[k], _pend_e[k], _pend_gen[k])
	# 앞 n개를 걷어낸다. 뒤에 붙은 건 방금 다시 밀린 것이다.
	# ⚠ `slice`가 새 배열을 만들고 **멤버에 다시 대입**한다 — 인자로 넘겨서 CoW 사본에
	#  쓰는 그 함정(위 `_px` 주석)과 반대 방향이라 안전하다.
	_pend_x = _pend_x.slice(n)
	_pend_y = _pend_y.slice(n)
	_pend_g = _pend_g.slice(n)
	_pend_e = _pend_e.slice(n)
	_pend_gen = _pend_gen.slice(n)


## ⚠ **세대를 나르고 반경은 안 나른다.** 반경은 시뮬 표(`SIM_SIZES.rd`)의 값이고 연출이 쓸 일이
##  없다 — 섬광 크기는 화면 표(`FX_SIZES.flash_px`)에서 나온다. 안 쓰는 값을 실어 보내면
##  그게 거짓 손잡이다.
## 🔴 두 표가 갈라지는 걸 막는 것은 **통지에 반경을 끼워 넣는 것이 아니라** `net_tables`가
##  두 표의 길이와 단조를 **같이** 재는 것이다.
func _notify_blast(x: int, y: int, element: int, gen: int) -> void:
	_fx_x.append(x)
	_fx_y.append(y)
	_fx_e.append(element)
	_fx_g.append(gen)


func _clear_fx() -> void:
	_fx_x.clear()
	_fx_y.clear()
	_fx_e.clear()
	_fx_g.clear()


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
		_glyphs[i] = _glyphs[last]
		_element[i] = _element[last]
		_age[i] = _age[last]
		_gen[i] = _gen[last]
		_id[i] = _id[last]
	_count = last


## 정수 제곱근(뉴턴법). 🔴 **이 몇 줄이 삼각함수·`sqrt`·각도 테이블을 통째로 대신한다.**
##  발사할 때 한 번 돌고 비행 중엔 안 돈다.
## ⚠ 오버플로 여유: 입력 최대는 조준 상한에서 나온다 — `2 × AIM_MAX² << 16` ≈ 1.4e14로
##  int64(9.2e18)에 압도적으로 남는다. 🔴 `AIM_MAX`를 키우면 이 계산을 다시 해라.
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
# 🔴🔴 아래 배열들은 **사본이 아니라 「살아 있는 뷰」다.** 돌려받은 배열에 쓰면 시뮬이 실제로
#  바뀐다. **쓰지 마라** — 언어가 안 막아준다.
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


func get_vx() -> PackedInt32Array:
	return _vx


func get_vy() -> PackedInt32Array:
	return _vy


func get_element() -> PackedByteArray:
	return _element


func get_glyphs() -> PackedInt32Array:
	return _glyphs


## 🔴 확산 세대. 렌더가 머리 크기·자취 길이를 여기서 파생시킨다 — 시뮬 축만 늘고
##  화면이 안 따라가는 것이 v1이 죽은 방식이다.
func get_gen() -> PackedByteArray:
	return _gen


## 🔴 렌더가 자취를 짝지을 유일한 안전한 열쇠. 슬롯 인덱스는 매 틱 뒤바뀐다.
func get_id() -> PackedInt32Array:
	return _id


# ─── 이번 틱에 터진 폭발 ──────────────────────────────────────────
# 🔴🔴 **연출의 유일한 통지다.** 껍데기가 `step()` **직후에** 읽어 `blast_fx`에 넘긴다.
#  ⚠ 다음 `step()`이 지운다 — 두 틱 뒤에 읽으면 빈 배열이다.
# 🔴 이 값이 시뮬로 돌아가는 경로는 없다. 화면 쪽이라 클라마다 달라도 세상이 안 갈라진다.

func blast_count() -> int:
	return _fx_x.size()


func get_blast_x() -> PackedInt32Array:
	return _fx_x


func get_blast_y() -> PackedInt32Array:
	return _fx_y


func get_blast_element() -> PackedByteArray:
	return _fx_e


func get_blast_gen() -> PackedByteArray:
	return _fx_g


## 예산이 떨어져 다음 틱으로 밀린 파이프라인 수. ⚠ 그물과 HUD가 **버려지지 않았다**를 재는 자리다.
func pending_count() -> int:
	return _pend_x.size()
