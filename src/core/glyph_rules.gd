extends RefCounted
## 🔴 문양 **알고리즘 표**의 단일 소스 (세82 데이터화). class_name 없음 — `const GR := preload(...)`.
##
## 왜 생겼나 (사용자 확정 세82): *"토대를 깔고 싶은거긴한데 **그래야 니가 하드코딩을 안해서**
## 문양도 하나씩 생각해서 추가하고 싶고"* — 문양을 늘릴 때마다 계열 판별·효과 분기·수치가
## 코드 여기저기로 흩어지는 걸 구조로 막는다. 논거는 「추가 비용 절감」이 아니라 **작업 규율**이다.
##
## 🔴 **`Db`를 참조하지 않는다 — 순수 static 표다.** `GlyphDef`를 **받아서** 답한다.
##   이유: 이 파일이 `Db`를 더듬으면 ⓐ takbon-rules §3(*"id→리졸버는 전부 Db"*)의 반대 방향이고
##   ⓑ static 캐시가 테스트의 in-memory 주입 관행(`db.glyphs[...] = ...`, 아무도 reload()를 안 부른다)과
##   충돌해 **다음 세션이 조용히 자명 통과할 자리**를 만든다. `code → GlyphDef` 조회는 **`Db`가 쥔다**
##   (`Db.glyph_by_code`) — `ink_mult`·`status_mult_of` 선례 그대로.
##
## 🔴 **이 파일이 곧 기획서다.** 새 알고리즘은 `BEHAVIORS`에 줄 하나 + `ring_spell_system`에 함수 하나.
## 하지만 **대부분의 새 문양은 여기를 안 건드린다** — 같은 알고리즘에 수치만 다르면 `.tres` 한 장이다
## (응축이 폭발과 `blast`를 공유하는 게 그 첫 사례: 반경 계수 부호만 뒤집었다).

const Enums := preload("res://src/core/enums.gd")


## 🔴 **알고리즘 목록 + 계열 판별의 단일 소스.**
##   `bolt`   = 그 칸 방향으로 탄 1발          (전개형 — 명령을 **만든다**)
##   `pillar` = 착탄점에 기둥, 칸 수만큼 굵게   (전개형)
##   `spread` = 안쪽 각 갈래를 복제해 부채꼴 산개 (변형형 — 안쪽 결과를 **받아 바꾼다**)
##   `blast`  = 안쪽을 하나로 융합한 광역        (변형형)
##
## 🔴 **전개형/변형형이 곧 층(밴드) 해석의 뼈대다** (세79 M1): 층은 안→밖이 연산 순서이고,
## 변형형은 그때까지 쌓인 명령 목록을 함수처럼 변환한다. 옛 `Enums.MODIFIER_GLYPHS` 상수가
## 이 자리였는데, 계열이 **문양 데이터에 딸린 성질**이라 알고리즘 표로 내려왔다.
const BEHAVIORS := {
	&"bolt": {"modifier": false},
	&"pillar": {"modifier": false},
	&"spread": {"modifier": true},
	&"blast": {"modifier": true},
}

## 알고리즘별 `params` 기본값 — `.tres`가 키를 빠뜨렸을 때만 쓰인다.
## ⚠ `bolt.reach`는 여기 없다: 기본값이 `balance.glyph_reach_max`라 **balance가 단일 소스**이고,
## 호출부가 그 값을 fallback으로 넘긴다(수치를 여기 박으면 balance와 갈라진다).
const DEFAULTS := {
	&"bolt": {"effect": &""},
	&"pillar": {},
	&"spread": {"fan_deg": 46.0, "branch_mult": 0.6, "offset_px": 44.0, "min_branches": 2},
	&"blast": {
		"base_radius_px": 54.0, "radius_per_branch": 0.18, "radius_per_count": 0.25,
		"min_radius_px": 12.0, "merge_mult": 0.85, "merge_mult_per_count": 0.0,
	},
}

## `bolt.effect` 문자열 → `Enums.GlyphType`. 옛 `ring_spell_system.BOLT_EFFECTS`(code로 키잉된
## 상수)를 대체한다 — 이제 **문양 데이터가 자기 효과를 들고 온다**.
## ⚠ `&""`는 여기 **없다**: 효과 없음은 빈 사전(`{}`)으로 떨어져야 한다. `GlyphType.BASIC`(=0)을
## 실으면 `projectile._setup_effects`가 BASIC을 안 읽어 지금은 무해하지만 새는 씨앗이 된다.
const EFFECTS := {
	&"pierce": Enums.GlyphType.PIERCE,
	&"homing": Enums.GlyphType.HOMING,
	&"bounce": Enums.GlyphType.BOUNCE,
	&"thrust": Enums.GlyphType.THRUST,
}


## 알고리즘 이름이 유효한가. 미등록(빈 값 포함)이면 false — 호출부가 그 칸을 건너뛴다.
static func is_known(behavior: StringName) -> bool:
	return BEHAVIORS.has(behavior)


## 이 알고리즘이 **변형형**인가 (안쪽 결과를 받아 바꾸는가).
static func is_modifier_behavior(behavior: StringName) -> bool:
	var row: Variant = BEHAVIORS.get(behavior)
	return bool(row["modifier"]) if row is Dictionary else false


## 문양 하나가 변형형인가. `def`가 null(미등록 code)이면 false.
static func is_modifier_def(def: GlyphDef) -> bool:
	return def != null and is_modifier_behavior(def.behavior)


## `params` 조회 — `.tres` 값 → 알고리즘 기본값 → `fallback` 순.
## ⚠ `.tres`의 사전 키는 **String**으로 저장되지만 StringName으로도 조회된다(둘은 Dictionary 키로
## 상호 호환 — 세82에 실측 확인). 그래서 키 타입을 호출부가 신경 쓰지 않아도 된다.
static func param(def: GlyphDef, key: StringName, fallback: Variant) -> Variant:
	if def != null and def.params.has(key):
		return def.params[key]
	var d: Variant = DEFAULTS.get(def.behavior) if def != null else null
	if d is Dictionary and (d as Dictionary).has(key):
		return (d as Dictionary)[key]
	return fallback


static func param_f(def: GlyphDef, key: StringName, fallback: float) -> float:
	return float(param(def, key, fallback))


## `bolt`의 효과 사전 — `projectile._setup_effects`가 먹는 형식({GlyphType: reach}).
## 효과 없음이면 **빈 사전**이다(위 `EFFECTS` 주석 참조).
static func bolt_effects(def: GlyphDef, reach: float) -> Dictionary:
	var name := StringName(param(def, &"effect", &""))
	if not EFFECTS.has(name):
		return {}
	return {EFFECTS[name]: reach}
