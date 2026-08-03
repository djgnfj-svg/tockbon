extends RefCounted
## 재료 표. 🔴🔴 **재료 하나 추가 = `DEFS` 한 줄.** 거동·색·이름·연료가 전부 거기서 파생된다.
##
## 🔴 런타임 형식은 **평면 배열**이고 부팅 때 한 번 굽는다 — 내부 루프가 `Dictionary`를 조회하면
##  그것만으로 틱당 수천 번 VM 호출이다.
## 🔴 **팔레트도 이 표에서 나온다.** 셰이더에 색 리터럴을 쓰면 시뮬과 렌더가 갈린다.

# ─── 재료 id ───────────────────────────────────────────────────────
# 🔴 id는 int이고 **순회는 반드시 `ALL` 명시 리스트로만** 한다.
#  값이 연속이라고 가정하면 나중에 은퇴한 자리가 생겼을 때 조용히 어긋난다.
const EMPTY := 0
const STONE := 1
const WOOD := 2

const ALL: Array[int] = [EMPTY, STONE, WOOD]

## 팔레트 슬롯 수. 🔴 셰이더의 `palette[16]`과 **같은 값이어야 한다.**
##  16을 넘기면 재료 id가 L8 정밀도 안전선(0~15)을 벗어난다.
const SLOT_COUNT := 16

# ─── 거동 ─────────────────────────────────────────────────────────
const BEHAVIOR_NONE := 0    # 아무것도 안 한다 (EMPTY)
const BEHAVIOR_STATIC := 1  # 안 움직인다. 🔴 **고체다** — 탄이 여기서 착탄하고 캐릭터가 여기 선다

# ─── 상태 비트(`_flag`) ────────────────────────────────────────────
# 🔴 **하위 4비트만 쓴다.** L8 텍스처를 셰이더에서 `int(v*255+0.5)`로 되찾는데,
#  정밀도가 mediump로 떨어지는 기계에서도 0~15는 안전하다.
# 🔴 이 값은 셰이더에 **uniform으로 주입된다**(`cell_renderer.gd`) — 셰이더에 다시 박지 마라.
const FLAG_BURNING := 2
# ⚠ 비트 1·4·8은 비어 있다. **이름을 미리 붙이지 마라** — 소비자도 계획도 없는 이름은 거짓 손잡이다.
#  v1에 `FLAG_FROZEN := 8`이 정확히 그렇게 있었다.

# ─── 🔴 `_aux`의 의미 ──────────────────────────────────────────────
# 소비자 없는 필드를 놀려두면 나중에 누가 다른 뜻으로 읽는다. **의미를 여기 못 박는다.**
#
#   BURNING 켜짐 → 남은 연료
#   그 외        → 사용 안 함. 0이어야 한다

## 재료 정의. 🔴 여기 한 곳에서 거동·색·이름·연료가 전부 파생된다.
##
##   fuel  🔴 **불의 예산이다.** 0이면 안 탄다. `_aux`(PackedByteArray)에 들어가므로 **255 이하.**
##         「타면서 연료가 줄고 0이 되면 꺼진다」 ⇒ 나무를 어디 두느냐가 곧 불의 수명이다(GDD).
##   rgb   🔴🔴 **색은 `Color`가 아니라 24비트 정수 `0xRRGGBB`다.**
##         이 폴더의 계약이 「정수만」이고 `net_determinism`이 **실수 리터럴을 잡기** 때문이다.
##         ⚠ 색을 `Color(0.36, ...)`로 두면 폴더 계약과 그물이 재는 것이 갈라지고,
##          그 틈을 예외 목록으로 메우면 **그 목록이 다음에 낡는다.** ⇒ 예외를 없앴다.
##         🔴 그래도 단일 소스는 그대로다 — `Color`로 굽는 일만 `src/view/cell_renderer.gd`가 한다.
const DEFS: Dictionary = {
	EMPTY: {"name": &"빈칸", "behavior": BEHAVIOR_NONE, "fuel": 0, "rgb": 0x0E0E13},
	STONE: {"name": &"돌", "behavior": BEHAVIOR_STATIC, "fuel": 0, "rgb": 0x5C574F},
	WOOD: {"name": &"나무", "behavior": BEHAVIOR_STATIC, "fuel": 200, "rgb": 0x6B4524},
}

## 정의가 없는 슬롯의 색. 🔴 **일부러 마젠타다** — 재료를 늘렸는데 팔레트가 안 따라오면
##  화면이 비명을 지른다. 얌전한 검정으로 두면 「쏘는 것 ≠ 보이는 것」이 조용히 난다.
const MISSING_RGB := 0xFF00FF


## 부팅 1회. 내부 루프는 이 배열을 인덱싱만 한다 — 딕셔너리 조회 0회.
static func bake_behavior() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		out[id] = int(DEFS[id]["behavior"])
	return out


## 🔴 연료도 평면 배열이다. 불은 매 틱 수십~수백 셀의 연료를 만진다.
static func bake_fuel() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		var f := int(DEFS[id]["fuel"])
		if f < 0 or f > 255:
			# `_aux`가 PackedByteArray라 범위 밖 연료는 **에러 없이 하위 8비트로 잘린다.**
			push_error("Mat: %s 연료 %d가 바이트 범위 밖이다" % [DEFS[id]["name"], f])
			f = clampi(f, 0, 255)
		out[id] = f
	return out


## 슬롯의 색(0xRRGGBB). 정의가 없으면 마젠타 센티넬.
## 🔴 **`Color`로 굽는 일은 여기가 아니라 `src/view/cell_renderer.gd`가 한다** — 위 `rgb` 주석.
static func rgb_of(id: int) -> int:
	if not DEFS.has(id):
		return MISSING_RGB
	return int(DEFS[id]["rgb"])


static func material_name(id: int) -> StringName:
	if not DEFS.has(id):
		return &"?"
	return DEFS[id]["name"]
