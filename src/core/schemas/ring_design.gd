class_name RingDesign
extends Resource
## 고리 조립 도안 — 마법진의 **유일한** 저장·장착 단위. 스키마 변경은 리드만.
## 순수 Dictionary(assembly)를 감싸 리소스로 만든다 — 라이브 생산자는
## `ring_forge_panel.build_assembly()`이고, 되돌리는 쪽(`to_assembly()`)이 **발사가 먹는 계약**이다.
##
## assembly 키 = `to_assembly()`가 정본이다. 각 칸 값 = 문양 코드(`Enums.GlyphCode`) 또는 빈칸(-1).
## 🔴 `rings`는 **층(밴드) 배열**이다 — 인덱스가 곧 감쌈 깊이(안→밖 = 연산 순서).
##  옛 8칸 한 겹도 그대로 로드된다(`layers_of`가 층 1개로 승격 — 저장 무회귀).

@export var id: StringName
## ⚠ 맺은 도안은 전부 "고리 마법진"이다 — `base.gd`가 이름을 상수로 넘겨서 1·2·3 슬롯이 무엇을
## 쏘는지 이름으로 구분이 안 된다. 고칠 자리는 `from_assembly`의 `name`을 채우는 호출부다.
@export var display_name: String = "고리 마법진"
## 룬 종류 — **첫 룬**(primary). 다중 룬의 정본은 아래 `runes`이고, 이 필드는 `rune` 하나를 읽던
## 옛 소비자가 조용히 안 깨지게 첫 룬으로 계속 채운다. 🔴 읽을 땐 `runes_of()`를 거쳐라.
@export var rune: int = 0
## 룬 목록. 진에 룬이 2개+면 자리 순서대로 담긴다(값은 `Enums.RuneType` 정수).
## 🔴 읽을 땐 `runes_of()`를 거쳐라 — 옛 도안은 이 필드가 없어 기본 `[]`로 로드된다.
@export var runes: Array = []
## 진 id — 이 마법진을 어느 진에 그렸나. 발사 형태를 정한다(id→패턴은 `Db.get_jin(jin).pattern`).
## 빈 값 = 옛 도안 = 단발(SINGLE)로 떨어진다.
## ⚠ ink처럼 여기에 Db를 두지 마라(class_name → `-s` 컴파일 함정) — 패턴 해석은 발사부가 한다.
@export var jin: StringName = &""
## 진의 고리들 = **층 배열**. `rings[i][k]` = 층 i·칸 k의 문양 코드 or -1. 층 인덱스 = 감쌈 깊이.
## 🔴 읽을 땐 반드시 `layers_of()`를 거쳐라 — 옛 도안은 `rings`가 정수 8칸이라 `rings[0]`이
## 칸 값이지 층이 아니다.
@export var rings: Array = []
## 진이 연 칸 인덱스 (렌더·요약용). 출처는 `build_assembly()`의 층 합집합이다.
@export var open: Array = []
## 종합 점수(0~1) — **위력을 정한다**(`src/core/ring_power.gd`).
## 출처는 `balance.skip_drawing`으로 갈린다(부품 조립 점수 ↔ 손으로 얼마나 잘 그렸나).
## 어느 쪽이든 척도가 같은 0~1이라 위력·등급 함수가 그대로 돈다.
@export var total_score: float = 0.0
## 이 진을 그린 잉크 id — 등급 배수가 발사 위력에 곱해진다. 빈 값 = 배수 1.0.
## ⚠ 여기에 `ink_mult()`를 두지 마라 — 이 스키마는 class_name이라 Db를 참조하면 `-s` 테스트가
## 오토로드 등록 전 컴파일에서 터진다. 배수는 **호출부**가 `Db.ink_mult(ink)`로 뽑는다.
@export var ink: StringName = &""
## 특별잉크 id + 얼마나 썼나(0..1). 발사가 `Db.status_mult_of()`로 상태 세기를 증폭한다.
## 빈 값 = 증폭 없음.
@export var special_ink: StringName = &""
@export var special_ratio: float = 0.0
## 진 크기 — 그릴 때의 jin_scale (1.0=기본). 종이 등급이 상한을 올리고, 큰 진일수록 세다.
@export var size: float = 1.0


## ring_spell_system이 먹는 발사 계약(Dictionary)으로 되돌린다.
## 🔴 `score`를 실어야 **저장해 둔 도안을 다시 쏴도 그때 그린 위력이 그대로 난다.**
## 빼면 장착한 진이 조용히 기준 위력으로 발사된다 (tests/test_ring_design_auto가 못 박아 둔다).
func to_assembly() -> Dictionary:
	return {
		"ring_count": 1,
		"rune": rune,
		"runes": runes_of(runes, rune),
		"jin": jin,
		"rings": rings.duplicate(true),
		"open": open.duplicate(),
		"score": total_score,
		"ink": ink,
		"special_ink": special_ink,
		"special_ratio": special_ratio,
		"size": size,
	}


## assembly(get_assembly 결과)를 감싸 RingDesign을 만든다.
## 점수는 assembly가 이미 실어 온다(`ring_forge_panel.build_assembly`가 계산해 싣는다) —
## 기본값이 그걸 쓴다. `score`를 명시로 주면 그게 이긴다. 음수 = "안 줬음" 표식.
static func from_assembly(a: Dictionary, name: String = "", score: float = -1.0) -> RingDesign:
	var d := RingDesign.new()
	d.rune = int(a.get("rune", 0))
	# assembly가 `runes`를 실어 오면 그걸, 아니면 `rune` 하나에서 승격(옛 경로).
	d.runes = runes_of(a.get("runes", []), d.rune)
	# 🔴 `rune`(primary) = 목록 첫 룬으로 맞춘다 — 둘이 갈라지면 옛 소비자가 다른 룬을 본다.
	if not d.runes.is_empty():
		d.rune = int(d.runes[0])
	d.jin = StringName(a.get("jin", &""))
	d.rings = (a.get("rings", []) as Array).duplicate(true)
	d.open = (a.get("open", []) as Array).duplicate()
	d.total_score = score if score >= 0.0 else float(a.get("score", 0.0))
	d.ink = StringName(a.get("ink", &""))
	d.special_ink = StringName(a.get("special_ink", &""))
	d.special_ratio = float(a.get("special_ratio", 0.0))
	d.size = float(a.get("size", 1.0))
	if name != "":
		d.display_name = name
	return d


## 🔴 **`rings`를 층 배열로 정규화한다 — 이 판별의 단일 소스.**
##   • `[[1,1,-1,…], [7,-1,…]]` (배열의 배열) = 이미 층 배열 → 그대로.
##   • `[1,1,-1,…]` (8칸 한 겹, 옛 모양) = **층 1개로 승격**.
## 🔴 이 판별을 호출부에 복사하지 마라 — 한쪽만 고치면 옛 도안이 조용히 안 나가거나(발사)
## 바깥 층이 통째로 안 보인다(HUD).
## static인 이유 = 인스턴스가 없는 자리(발사부·HUD)에서도 같은 함수를 불러야 해서다.
static func layers_of(rings_v: Array) -> Array:
	if rings_v.is_empty():
		return []
	return rings_v if rings_v[0] is Array else [rings_v]


## 🔴 **룬을 목록으로 정규화한다 — 이 승격의 단일 소스**(`layers_of` 선례).
##   • `runes_v`가 비지 않았으면 그 정수 목록을 그대로(자리 순서).
##   • 비었으면(=옛 도안·룬 하나 경로) `fallback_rune` 하나로 `[rune]` 승격.
## 🔴 이 판별을 호출부에 복사하지 마라 — 발사·저장·요약이 같은 함수를 봐야 룬 1개 진이 전과
## 정확히 같게 돈다.
static func runes_of(runes_v: Array, fallback_rune: int) -> Array:
	var out: Array = []
	for r in runes_v:
		out.append(int(r))
	if out.is_empty():
		out.append(int(fallback_rune))
	return out


## **층별 문양 요약** — 안→밖 순서로 `[[{code, count}, …], …]`.
## 빈 층은 빈 배열이라 **자리는 유지된다**(감쌈 깊이가 밀리면 안 되므로).
## UI마다 `rings`를 직접 뜯으면 층 판별이 또 갈라지므로 여기 한 곳에 둔다.
## ⚠ 문양 이름·색은 여기 안 넣는다 — core가 drawing이나 `Db`를 참조하면 모듈 경계가 깨진다.
## 코드→이름 해석은 표시하는 쪽이 한다.
func layer_summary() -> Array:
	var out: Array = []
	for layer_v in layers_of(rings):
		var counts: Dictionary = {}
		for g in (layer_v as Array):
			var c := int(g)
			if c != -1:
				counts[c] = int(counts.get(c, 0)) + 1
		var entries: Array = []
		for c: int in counts.keys():
			entries.append({"code": c, "count": int(counts[c])})
		# 🔴 코드 오름차순 고정 — Dictionary 키 순서에 기대면 같은 도안이 열 때마다 다르게 보인다.
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["code"]) < int(b["code"]))
		out.append(entries)
	return out


## 이 도안에 변형형 문양(확산·폭발)이 끼어 있나 — **위력 표시 단위를 가른다.**
## 끼어 있으면 `RingPower.power_display`의 숫자는 **갈래 하나의 위력**이라, 표시하는 쪽은 이 값을
## 보고 "갈래당 위력 N"이라 적는다.
## 🔴 계열 목록을 **인자로 받는다** — 이 스키마는 `class_name` Resource라 `Db`를 볼 수 없고
## (`-s` 컴파일 함정), 인스펙터·프리로드 문맥에선 `Db`가 아예 없어 **조용히 `false`**가 나온다.
## 그러면 HUD가 "갈래당 위력"을 "위력"이라 적는다 = 이 함수가 잡으려던 바로 그 거짓말이다.
## 호출부(HUD·패널)가 `Db.modifier_codes()`를 넘기고, 계열의 단일 소스는 `GlyphRules.BEHAVIORS`다.
func has_modifier_glyph(modifier_codes: Array) -> bool:
	if modifier_codes.is_empty():
		return false
	for layer_v in layers_of(rings):
		for g in (layer_v as Array):
			if int(g) in modifier_codes:
				return true
	return false


## 칸 k에 문양이 놓였나 — **어느 층에든** 놓였으면 참.
## 🔴 `rings[0]`만 보면 2등급 진에서 바깥 층 문양이 통째로 안 그려지는데, `open`은 층들의
## 합집합이라 화면이 **"열렸는데 비었다"로 조용히 거짓말한다.**
## ⚠ `_draw` 안에 인라인으로 두면 헤드리스가 못 재서 회귀 검출이 0이 된다 — 그래서 순수 함수다.
func is_slot_filled(k: int) -> bool:
	for layer_v in layers_of(rings):
		var layer: Array = layer_v
		if k >= 0 and k < layer.size() and int(layer[k]) != -1:
			return true
	return false


## 채워진 칸 수 (열린 칸 중 문양이 놓인 것). 요약·표시용.
## 🔴 **모든 층을 센다** — `rings[0]`만 보면 2등급 진에서 바깥 층이 통째로 안 세어져
## 요약이 조용히 거짓말을 한다.
func filled_count() -> int:
	var layers := layers_of(rings)
	var n := 0
	for layer_v in layers:
		var ring: Array = layer_v
		for k in open:
			var idx := int(k)
			if idx >= 0 and idx < ring.size() and int(ring[idx]) != -1:
				n += 1
	return n
