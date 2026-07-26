extends Node
## data/ 리소스 레지스트리 — 룬·적·아이템 정의 조회.
## .tres 인스턴스 작성: 룬=모듈 B / 적=모듈 C / 아이템=모듈 D.

## 문양 계열 판별(변형형인가)의 단일 소스 — `modifier_codes()`가 쓴다. 순수 static 표라
## `Db`를 되참조하지 않는다(세82 — 순환·`-s` 컴파일 함정 둘 다 없다).
const GlyphRules := preload("res://src/core/glyph_rules.gd")

## {Enums.RuneType: RuneDef}
var runes: Dictionary = {}
## {StringName: EnemyDef}
var enemies: Dictionary = {}
## {StringName: ItemDef}
var items: Dictionary = {}
## {StringName: JinDef} — 고리 조립 진 (세션 13 구조화)
var jins: Dictionary = {}
## {StringName: GlyphDef} — 고리 조립 문양 (세션 13 구조화)
var glyphs: Dictionary = {}
## {StringName: GlyphRingDef} — 문양-고리 (세68 조립→탁본 모델의 파밍 단위)
var glyph_rings: Dictionary = {}
## {StringName: RecipeDef} — 정제·제작 레시피 (세션29 경제)
var recipes: Dictionary = {}
## {StringName: QuestDef} — 진행 목표 퀘스트 (세션36 스파인)
var quests: Dictionary = {}
## {StringName: ChapterDef} — 챕터(보스방 스테이지) (세58-B 세피리아식 루프)
var chapters: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	runes.clear()
	enemies.clear()
	items.clear()
	jins.clear()
	glyphs.clear()
	glyph_rings.clear()
	recipes.clear()
	quests.clear()
	chapters.clear()
	for res in _load_dir("res://data/runes"):
		var rune := res as RuneDef
		if rune == null:
			_warn_wrong_type("data/runes", res, "RuneDef")
			continue
		runes[rune.type] = rune
	for res in _load_dir("res://data/enemies"):
		var enemy := res as EnemyDef
		if enemy == null:
			_warn_wrong_type("data/enemies", res, "EnemyDef")
			continue
		enemies[enemy.id] = enemy
	for res in _load_dir("res://data/items"):
		var item := res as ItemDef
		if item == null:
			_warn_wrong_type("data/items", res, "ItemDef")
			continue
		items[item.id] = item
	for res in _load_dir("res://data/jin"):
		var jin := res as JinDef
		if jin == null:
			_warn_wrong_type("data/jin", res, "JinDef")
			continue
		jins[jin.id] = jin
	for res in _load_dir("res://data/glyphs"):
		var glyph := res as GlyphDef
		if glyph == null:
			_warn_wrong_type("data/glyphs", res, "GlyphDef")
			continue
		glyphs[glyph.id] = glyph
	for res in _load_dir("res://data/glyph_rings"):
		var gr := res as GlyphRingDef
		if gr == null:
			_warn_wrong_type("data/glyph_rings", res, "GlyphRingDef")
			continue
		glyph_rings[gr.id] = gr
	for res in _load_dir("res://data/recipes"):
		var recipe := res as RecipeDef
		if recipe == null:
			_warn_wrong_type("data/recipes", res, "RecipeDef")
			continue
		recipes[recipe.id] = recipe
	for res in _load_dir("res://data/quests"):
		var quest := res as QuestDef
		if quest == null:
			_warn_wrong_type("data/quests", res, "QuestDef")
			continue
		quests[quest.id] = quest
	for res in _load_dir("res://data/chapters"):
		var chapter := res as ChapterDef
		if chapter == null:
			_warn_wrong_type("data/chapters", res, "ChapterDef")
			continue
		chapters[chapter.id] = chapter
	reindex_glyphs()


## 🔴🔴 **캐스트 실패를 시끄럽게 만든다** (세84 감사 #10). 전엔 아홉 루프가 다 `if x:`로
## 캐스트 실패를 **조용히 버렸다** — 그리고 이건 **완전 무음**이다: 파싱 실패는 엔진이 최소한
## `Parse Error`를 찍지만(관행인 `SCRIPT ERROR` grep엔 안 걸려도 로그엔 남는다), 폴더에 엉뚱한
## 타입의 .tres가 들어간 경우는 **엔진 로그조차 없다.** 세50에 바람 룬이 두 세션 죽어 있던 게
## 이 계열이고, 그때 전 스위트가 그린이었다. Db가 「빠졌다」를 알 수 있는 유일한 자리라 여기서 짖는다.
func _warn_wrong_type(dir: String, res: Resource, expected: String) -> void:
	var where := res.resource_path if res != null else "<null>"
	push_warning("%s에 %s가 아닌 리소스가 있다 — 이 파일은 등록되지 않는다: %s"
		% [dir, expected, where])

func get_rune(type: Enums.RuneType) -> RuneDef:
	return runes.get(type) as RuneDef

func get_enemy(id: StringName) -> EnemyDef:
	return enemies.get(id) as EnemyDef

func get_item(id: StringName) -> ItemDef:
	return items.get(id) as ItemDef


## 🔴 잉크 id → 데미지 배수 (세션29, 사용자: "등급=데미지"). **한 곳뿐인 리졸버**다 —
## 발사(ring_spell_system)·리포트(ring_forge_panel)·HUD·캐스터가 전부 이걸 부른다.
## 잉크 없음(맨손·옛 도안)/미등록 = 1.0. 배수 값 자체는 잉크 .tres(`ItemDef.power_mult`)가 쥔다.
## ⚠ **여기(레지스트리 오토로드)에 둔다** — 스키마(ItemDef·RingDesign)에 두면 그건 class_name이라
## `-s` 테스트가 오토로드 등록 전에 컴파일하다 `Db` 참조에서 터진다(CLAUDE.md 오토로드 함정).
func ink_mult(id: StringName) -> float:
	if id == &"":
		return 1.0
	var it := get_item(id)
	return it.power_mult() if it != null else 1.0


func get_recipe(id: StringName) -> RecipeDef:
	return recipes.get(id) as RecipeDef

## 정제대가 나열할 레시피 — id 오름차순.
func all_recipes() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	var keys := recipes.keys()
	keys.sort()
	for k: StringName in keys:
		out.append(recipes[k])
	return out

## 🔴 한 작업대의 레시피만 — 정제대(&"refine")와 공방(&"craft")이 서로 남의 레시피를 안 보이게
## (세션32). 안 걸러 내면 펜 레시피가 정제대에도 뜬다. 정렬은 all_recipes(id 오름차순)를 물려받는다.
func recipes_for_station(station: StringName) -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for r: RecipeDef in all_recipes():
		if r.station == station:
			out.append(r)
	return out


# ── 특별잉크·종이 리졸버 (세션29) — 잉크 등급(ink_mult)과 같은 이유로 레지스트리에 둔다 ──

## 🔴 특별잉크인가 — `params.special_rune`이 있으면 특별잉크다(그리는 동안 **소모**되고 룬 효과를
## 증폭한다). 기본잉크(ink_basic/mid/high)는 이게 없어 무한이다. 보드가 소모 여부를 이걸로 가른다.
func ink_is_special(id: StringName) -> bool:
	var it := get_item(id)
	return it != null and it.params.has("special_rune")

## 🔴 특별잉크가 완성 진에 박는 **상태이상 증폭 배수** (세션29, 사용자: "화상 증폭").
## `params.status_mult`(예: 1.5)를, 그 진을 **얼마나 특별잉크로 그렸나**(ratio 0..1)에 비례해 적용한다:
## 전부 특별=최대, 절반=중간, 안 씀=1.0(그대로). 발사가 status_power에 곱한다.
func status_mult_of(special_ink: StringName, ratio: float) -> float:
	if special_ink == &"":
		return 1.0
	var it := get_item(special_ink)
	if it == null:
		return 1.0
	var full := float(it.params.get("status_mult", 1.0))
	return lerpf(1.0, full, clampf(ratio, 0.0, 1.0))

## 종이 id → 진 확대 상한(jin_scale max). 없음/미등록 = 기본 종이 상한(호출부가 넘기는 기본값).
func paper_zoom_max(id: StringName, fallback: float) -> float:
	if id == &"":
		return fallback
	var it := get_item(id)
	if it == null:
		return fallback
	return float(it.params.get("zoom_max", fallback))

func get_quest(id: StringName) -> QuestDef:
	return quests.get(id) as QuestDef

## 퀘스트 목록 — id 오름차순 (사슬 순서 = id 순. q01·q02… 로 이름 지어 스파인 순서를 낸다).
func all_quests() -> Array[QuestDef]:
	var out: Array[QuestDef] = []
	var keys := quests.keys()
	keys.sort()
	for k: StringName in keys:
		out.append(quests[k])
	return out


# ── 챕터 (세58-B 보스방 루프) ──

func get_chapter(id: StringName) -> ChapterDef:
	return chapters.get(id) as ChapterDef

## 챕터 목록 — order 오름차순 (선택 패널 카드 순서 = 잠금 순서).
func chapters_sorted() -> Array[ChapterDef]:
	var out: Array[ChapterDef] = []
	for c in chapters.values():
		out.append(c)
	out.sort_custom(func(a: ChapterDef, b: ChapterDef) -> bool: return a.order < b.order)
	return out

## 🔴 챕터 클리어 codex 키 — **파생 규칙 한 곳**(&"chapter_clear_" + id). ChapterDef 필드로 두면
## .tres마다 베껴 적다 한 글자 틀리는 세50 계열 함정이라 여기서만 만든다. boss_room(클리어 emit)과
## chapter_panel(잠금 판정)이 같은 함수를 부른다 — 복사 금지.
## ⚠ 룬 해금으로 클리어를 판정하면 안 된다 — `_seed_starting_unlocks`가 룬 6종을 덮고 있어
## 부팅 즉시 전 챕터가 클리어로 보인다. 이 키는 시드 무접촉이라 안전하다.
func chapter_clear_id(chapter: ChapterDef) -> StringName:
	return StringName("chapter_clear_" + String(chapter.id))


func get_jin(id: StringName) -> JinDef:
	return jins.get(id) as JinDef

## 진 목록 — sort 오름차순 (UI 열거용, 세션44: 단발→산탄→둘레).
func all_jins() -> Array[JinDef]:
	var out: Array[JinDef] = []
	for j in jins.values():
		out.append(j)
	out.sort_custom(func(a: JinDef, b: JinDef) -> bool: return a.sort < b.sort)
	return out

## 🔴 **문양 `code` → GlyphDef 역인덱스** (세82 데이터화). `glyphs`는 `id`로 키잉돼 있는데
## **저장 도안·발사 계약은 정수 `code`**라(`Enums.GlyphCode`) 이 방향 조회가 필요하다.
## ⚠ **여기(레지스트리 오토로드)에 둔다** — `ink_mult` 주석과 같은 이유다. 스키마(`GlyphDef`·
## `RingDesign`)나 `GlyphRules`에 두면 그건 class_name/preload라 `-s` 테스트가 오토로드 등록 전에
## 컴파일하다 `Db` 참조에서 터진다.
var _glyph_by_code: Dictionary = {}

## 🔴 **공개인 이유** = 테스트가 `db.glyphs[...] = ...`로 in-memory 주입한 뒤 부를 수 있어야 한다
## (세61 리셋 이후의 관행 — 주입 테스트는 아무도 `reload()`를 안 부른다). `reload()`에서만 채우면
## 주입한 GlyphDef가 역인덱스에 안 들어가 **그물이 조용히 자명 통과한다**.
func reindex_glyphs() -> void:
	_glyph_by_code.clear()
	for g in glyphs.values():
		var gd := g as GlyphDef
		if gd == null:
			continue
		var prev := _glyph_by_code.get(gd.code) as GlyphDef
		if prev != null:
			# 🔴 **결정적 승자 = id 사전순으로 앞선 쪽**. 로드 순서에 기대면 같은 데이터가
			# 실행마다 다르게 해석될 수 있다. 조용히 덮으면 어느 쪽이 이겼는지 아무도 못 찾는다.
			# ⚠ 진 쪽은 둘 다 `glyphs`(id 키)에 그대로 남는다 — 여기서 지우지 않는다.
			push_warning("문양 code %d가 겹친다: %s vs %s — id 사전순으로 %s를 쓴다"
				% [gd.code, prev.id, gd.id, prev.id if String(prev.id) < String(gd.id) else gd.id])
			if String(prev.id) < String(gd.id):
				continue
		_glyph_by_code[gd.code] = gd

## 문양 코드 → 정의. 미등록이면 null (호출부가 경고하고 그 칸을 건너뛴다 — 코드에 기본표를
## 남기지 않는 게 규약이다. 남기면 소스가 둘이 되어 갈라진다).
func glyph_by_code(code: int) -> GlyphDef:
	return _glyph_by_code.get(code) as GlyphDef

## ⚠ 옛 `glyph_behavior(code)` 편의 함수는 **내지 않았다** (세82). 설계 초안엔 있었지만 실제
## 호출부는 `params`도 함께 필요해 전부 `glyph_by_code(g).behavior`로 읽는다 — 소비자 0인
## 편의 함수를 두면 **뮤테이션이 안 잡히는 죽은 코드**가 된다(세82 뮤테이션이 실제로 그걸 드러냈다).

## 🔴 **변형형 문양 코드 목록** — 옛 `Enums.MODIFIER_GLYPHS`의 자리. **core 스키마
## (`RingDesign`)는 `Db`를 못 보므로**(위 주석) 이 배열을 **인자로 받아** 판정한다.
## 계열의 진짜 단일 소스는 `GlyphRules.BEHAVIORS`이고 여기는 그걸 code로 옮겨 담을 뿐이다.
func modifier_codes() -> Array[int]:
	var out: Array[int] = []
	for code in _glyph_by_code.keys():
		if GlyphRules.is_modifier_def(_glyph_by_code[code] as GlyphDef):
			out.append(int(code))
	out.sort()   # 결정적 순서 (변형형 적용 순서가 실행마다 흔들리면 안 된다)
	return out


## 문양 목록 — **code 오름차순** (응집0·발산1·…·응축8). 책·조립 패널의 셀 순서가 이 순서다.
## ⚠ 옛 Q/W 고르기 키는 세25에 폐지됐다(마우스 클릭만) — 키 대응으로 읽지 마라.
func all_glyphs() -> Array[GlyphDef]:
	var out: Array[GlyphDef] = []
	for g in glyphs.values():
		out.append(g)
	out.sort_custom(func(a: GlyphDef, b: GlyphDef) -> bool: return a.code < b.code)
	return out


# ── 문양-고리 (세68 조립→탁본 모델) ──

func get_glyph_ring(id: StringName) -> GlyphRingDef:
	return glyph_rings.get(id) as GlyphRingDef

## 문양-고리 목록 — sort 오름차순 (조립 패널 목록 순서).
func all_glyph_rings() -> Array[GlyphRingDef]:
	var out: Array[GlyphRingDef] = []
	for gr in glyph_rings.values():
		out.append(gr)
	out.sort_custom(func(a: GlyphRingDef, b: GlyphRingDef) -> bool: return a.sort < b.sort)
	return out


func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		# 🔴 폴더가 없으면 그 축의 콘텐츠가 **통째로** 빠지는데 전엔 조용히 빈 배열이었다(세84 #10).
		push_warning("data 폴더를 열 수 없다 — 이 축의 콘텐츠가 통째로 빠진다: %s (err %d)"
			% [path, DirAccess.get_open_error()])
		return out
	for file in dir.get_files():
		# 익스포트 빌드에서는 .tres가 .tres.remap으로 바뀌므로 양쪽 처리
		var clean := file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			var full := path.path_join(clean)
			var res := load(full) as Resource
			# 🔴 로드 실패(대개 **파싱 오류** — `Color`를 3인자로 쓰면 파서가 리소스 전체를
			# 거부한다, 세50 바람 룬)를 전엔 `if res:`로 조용히 버렸다. 엔진 `Parse Error`는
			# `SCRIPT ERROR` grep에 안 걸리고 `-s`는 OK를 찍는다 — 그래서 여기서 한 번 더 짖는다.
			if res == null:
				push_warning("리소스 로드 실패 (파싱 오류일 수 있다 — 세50 함정): %s" % full)
				continue
			out.append(res)
	return out
