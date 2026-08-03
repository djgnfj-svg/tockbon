extends RefCounted
## 문양 표 + **남은 문양 목록**의 팩/언팩.
##
## 🔴🔴 **탄이 들고 다니는 「남은 문양 목록」은 정수 하나다.** 4비트씩 니블에 쌓는다.
##
## ```
## 목록 [확산, 폭발]  →  g = 확산 | (폭발 << 4)
##
## 첫 문양   first(g) = g & 0xF
## 남은 목록 rest(g)  = g >> 4
## 목록 끝   g == 0                    ← GLYPH_NONE = 0 을 예약해서 얻는다
## ```
##
## 이 선택이 사는 값:
##  · **평행 배열 계약을 안 깬다.** 힙 할당 0. 「남은 목록을 새 탄에 넘긴다」가 **정수 대입**이다
##  · 🔴 **폭발 → 폭발 → … 이 무한이 될 수 없다.** `rest`가 매번 4비트씩 줄어 최대 7번이면 0이다.
##    **상한 가드가 원리적으로 필요 없다**
##  · 🔴 **커맨드가 4바이트만 는다** — GDD의 「파괴는 이벤트라 공짜다」 논증이 그대로 산다
##
## 🔴 **시프트는 여기 세 함수 안에서만 한다.** 두 곳에서 시프트하면 반드시 갈라진다.

const Tuning := preload("res://src/sim/sim_tuning.gd")

## 🔴 **예약값이다. 「목록 끝」이 곧 0이다.** 그래서 문양 id는 1부터 시작한다.
const GLYPH_NONE := 0

## 문양의 두 종류. 🔴 **이 구분이 파이프라인의 전부다**(GDD 「문양의 실행 규칙」).
##  · SPAWN    탄을 만든다 → 새 탄들에게 **남은 목록을 넘긴다**
##  · TERMINAL 그 자리에서 끝난다 → 탄이 안 생기므로 **같은 자리에서 다음 문양이 이어 실행된다**
const KIND_SPAWN := 0
const KIND_TERMINAL := 1

const MASK := (1 << Tuning.GLYPH_BITS) - 1

# ─── 문양 id ───────────────────────────────────────────────────────
# 🔴 id는 int이고 **순회는 반드시 `ALL` 명시 리스트로만** 한다 — 값이 연속이라고 가정하지 않는다.
const GLYPH_SPREAD := 1
const GLYPH_BLAST := 2

## 🔴🔴 **문양 하나 추가 = 여기 한 줄 + `spell_sim._run_glyph`의 한 갈래 + (연출이 다르면)
##  `fx_tuning` 한 줄. 넷째 곳이 생기면 구조가 틀린 것이다.**
##
##   kind            SPAWN이면 탄을 만들고 목록을 넘긴다 · TERMINAL이면 같은 자리에서 이어진다
##   max_per_circle  한 마법진에 몇 개까지. 🔴 **0 = 무제한.**
##     GDD가 폭증을 상한이 아니라 **제약**으로 막기로 했다 — 확산이 하나뿐이면
##     8 → 64 폭증이 **구조적으로 불가능해진다.** 소비자는 `spell_sim.fire()`(커맨드 경계)다.
##   tick_budget     한 틱에 몇 번까지 실행되나. 🔴 **0 = 무제한.**
##     ⚠ 넘친 것은 **버려지지 않고 남은 목록째로 다음 틱에 밀린다**(`spell_sim._defer`).
##     🔴 예산이 표의 한 칸인 게 요점이다 — 파이프라인 코드가 특정 문양 id를 알 이유가 없어진다.
const DEFS: Dictionary = {
	# 🔴🔴 **`max_per_circle: 1`이 GDD의 폭증 방어 전부다.** 확산이 하나뿐이면
	#  8 → 64 폭증이 **구조적으로 불가능해진다** — 동시 투사체 상한을 조절 손잡이로 쓰지 않는
	#  이유가 이것이다(상한에 걸려 탄이 안 나가면 플레이어에게는 **고장**으로 읽힌다).
	#  ⇒ 문제가 발사 시점이 아니라 **조립 시점**에 드러난다.
	GLYPH_SPREAD: {
		"name": &"확산", "kind": KIND_SPAWN,
		"max_per_circle": 1,
		"tick_budget": 0,
	},
	GLYPH_BLAST: {
		"name": &"폭발", "kind": KIND_TERMINAL,
		"max_per_circle": 0,
		"tick_budget": Tuning.MAX_BLASTS_PER_TICK,
	},
}

## 🔴 순회는 **반드시 이 명시 리스트로만** 한다.
const ALL: Array[int] = [GLYPH_SPREAD, GLYPH_BLAST]


## 틱 예산의 평면 표. 부팅 1회 — 착탄마다 딕셔너리를 조회하면 그것만으로 VM 호출이 쌓인다.
## ⚠ 길이가 `MASK + 1`이라 id를 그대로 인덱스로 쓴다. 표에 없는 id는 0(무제한)이지만,
##  그런 id는 `fire()`의 검증에서 이미 걸러진다.
static func bake_tick_budget() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(MASK + 1)
	for id: int in ALL:
		out[id] = int(DEFS[id]["tick_budget"])
	return out


## 목록 → 정수. 못 쓰는 목록이면 짖고 0(빈 목록)을 돌려준다.
## ⚠ 여기는 **구조**만 본다(니블에 들어가나 · 층 수가 상한 안인가).
##  「그런 문양이 실재하나」와 「한 마법진에 몇 개까지인가」는 `spell_sim.fire()`가 본다 —
##  거기가 선을 넘는 유일한 커맨드 경계라, 검증을 거기서 안 하면 할 데가 없다.
static func pack(list: Array[int]) -> int:
	if list.size() > Tuning.GLYPH_MAX_LAYERS:
		push_error("Glyph: 층이 %d개다 — 상한은 %d다" % [list.size(), Tuning.GLYPH_MAX_LAYERS])
		return GLYPH_NONE
	var g := 0
	for i in list.size():
		var id: int = list[i]
		if id <= GLYPH_NONE or id > MASK:
			push_error("Glyph: 문양 id %d가 니블 범위(1~%d) 밖이다" % [id, MASK])
			return GLYPH_NONE
		g |= id << (i * Tuning.GLYPH_BITS)
	return g


## 지금 실행할 문양. 0이면 목록이 비었다.
static func first(g: int) -> int:
	return g & MASK


## 나머지. 🔴 매번 4비트씩 줄어드니 **유한이 보장된다.**
static func rest(g: int) -> int:
	return g >> Tuning.GLYPH_BITS


## 목록에 이 문양이 몇 개 들어 있나. `max_per_circle` 검증용이다.
static func count_of(g: int, id: int) -> int:
	var n := 0
	var cur := g
	while cur != GLYPH_NONE:
		if first(cur) == id:
			n += 1
		cur = rest(cur)
	return n
