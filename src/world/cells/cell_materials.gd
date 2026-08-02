extends RefCounted
## 재료·상태 테이블. **런타임 형식은 평면 배열이고, 부팅 때 한 번 굽는다**(설계 §7).
##
## 🔴 S1은 `.tres`를 만들지 않는다 — 재료가 셋인데 오소링 층을 세우면 과설계다.
##  다만 **모양은 처음부터 「평면 배열 + 부팅 베이크」**여야 S2에서 `.tres`를 얹는 게
##  `bake_*()` 함수 교체 하나로 끝난다. 내부 루프가 `Resource`를 조회하게 짜면 그때 루프를 다시 쓴다.
##
## 🔴 **팔레트도 이 테이블에서 나온다** — 셰이더에 색 리터럴을 쓰면 시뮬과 렌더가 갈린다(SKILL.md T5).

# ─── 재료 id ───────────────────────────────────────────────────────
# 🔴 id는 int이고 **순회는 반드시 `ALL` 명시 리스트로만** 한다.
#  enum 값이 연속이라고 가정하면 나중에 은퇴한 자리가 생겼을 때 조용히 어긋난다(SKILL.md).
const EMPTY := 0
const STONE := 1
const WATER := 2

const ALL: Array[int] = [EMPTY, STONE, WATER]

## 팔레트 슬롯 수. 🔴 셰이더의 `palette[16]`과 **같은 값이어야 한다.**
##  16을 넘기면 `_flag`·재료 id가 L8 정밀도 안전선(0~15)을 벗어난다(설계 §3).
const SLOT_COUNT := 16

# ─── 거동 ─────────────────────────────────────────────────────────
const BEHAVIOR_NONE := 0    # 아무것도 안 한다 (EMPTY)
const BEHAVIOR_STATIC := 1  # 안 움직인다 (STONE)
const BEHAVIOR_LIQUID := 2  # 중력 + 수평 분산 (WATER)

# ─── 상태 비트(`_flag`) ────────────────────────────────────────────
# 🔴 **하위 4비트만 쓴다.** L8 텍스처를 셰이더에서 `int(v*255+0.5)`로 되찾는데,
#  정밀도가 mediump로 떨어지는 기계에서도 0~15는 안전하다(설계 §3).
# ⚠ 셰이더(`cell_grid.gdshader`)에 같은 값이 상수로 박혀 있다 — 여기를 바꾸면 거기도 바꿔라.
const FLAG_WET := 1
const FLAG_BURNING := 2  # S2(불)에서 쓴다. S1은 절대 켜지 않는다
const FLAG_CHARGED := 4
# ⚠ 비트 8은 비어 있다. **이름을 미리 붙이지 마라** — 소비자도 계획도 없는 이름은
#  거짓 손잡이가 된다(SKILL.md T3). 예전에 `FLAG_FROZEN := 8`이 정확히 그렇게 있었다.
#  속성 목록 자체가 GDD에 **미정**이라 지금 정할 것도 아니다.

# ─── 🔴 `_aux`의 의미 — 재료·상태별로 다르다 ────────────────────────
# 소비자가 없는 필드를 놀려두면 나중에 누가 「물의 양」으로 읽는다(SKILL.md T3 거짓 손잡이).
# 그래서 **의미를 여기 못 박고, 안 쓰는 자리는 0을 강제한다.**
#
#   CHARGED 켜짐 → 남은 전하 틱 수  (재료와 무관하게 이 의미가 이긴다)
#   WATER + CHARGED 아님 → **사용 안 함. 0이어야 한다.**  ← 테스트가 이걸 잰다
#   STONE / EMPTY → 사용 안 함. 0이어야 한다
#   (S2) FIRE → 남은 연료

## 재료 정의. 🔴 여기 한 곳에서 거동·색·이름이 전부 파생된다(단일 소스).
const DEFS: Dictionary = {
	EMPTY: {"name": &"empty", "behavior": BEHAVIOR_NONE, "color": Color(0.055, 0.055, 0.075, 1.0)},
	STONE: {"name": &"stone", "behavior": BEHAVIOR_STATIC, "color": Color(0.36, 0.34, 0.31, 1.0)},
	WATER: {"name": &"water", "behavior": BEHAVIOR_LIQUID, "color": Color(0.16, 0.42, 0.86, 1.0)},
}

## 정의가 없는 슬롯의 색. 🔴 **일부러 마젠타다** — 재료를 늘렸는데 팔레트가 안 따라오면
##  화면이 비명을 지른다. 얌전한 검정으로 두면 「쏘는 것 ≠ 보이는 것」이 조용히 난다(SKILL.md T8).
const MISSING_COLOR := Color(1.0, 0.0, 1.0, 1.0)


## 부팅 1회. 내부 루프는 이 배열을 인덱싱만 한다 — 리소스 조회 0회.
static func bake_behavior() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SLOT_COUNT)
	for id: int in ALL:
		out[id] = int(DEFS[id]["behavior"])
	return out


## 셰이더 `palette[16]` uniform. 🔴 `DEFS`에서 **생성**한다 — 손으로 박지 마라.
static func bake_palette() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(SLOT_COUNT)
	for i: int in SLOT_COUNT:
		out[i] = MISSING_COLOR
	for id: int in ALL:
		out[id] = DEFS[id]["color"]
	return out


static func material_name(id: int) -> StringName:
	if not DEFS.has(id):
		return &"?"
	return DEFS[id]["name"]
