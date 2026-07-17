class_name ItemDef
extends Resource
## 잉크·종이·장비·재료·탁본 조각 공통 정의 — data/items/*.tres (인스턴스 작성은 모듈 D 소유).

@export var id: StringName
@export var kind: Enums.ItemKind = Enums.ItemKind.MATERIAL
@export var grade: int = 1
@export var display_name: String = ""
## kind별 자유 파라미터 — 스키마 확장 대신 이 Dictionary를 쓴다 (TEAM_PLAN 규칙 3)
@export var params: Dictionary = {}

## 🔴 소지품 카테고리 — 창고 탭·제작 입력 분류 (세션28 경제 정비).
## 완성품은 **kind가 곧 카테고리**, 재료(MATERIAL)만 `params.cat`로 "무엇의 재료"인지 가른다:
## ink_mat(잉크재료)·paper_mat(종이재료)·equip_mat(장비재료)·food(밥)·water(물).
## 🔴 **enum을 쪼개지 않는 이유**: ItemKind를 나누면 저장된 아이템·equipment의 키가 밀린다
## (enums.gd의 PEN 주석과 같은 함정). 그래서 데이터 태그로 나눈다 — 새 분류 = .tres params 한 줄.
func category() -> StringName:
	match kind:
		Enums.ItemKind.INK: return &"ink"
		Enums.ItemKind.PAPER: return &"paper"
		Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM, Enums.ItemKind.PEN: return &"equip"
		Enums.ItemKind.FRAGMENT: return &"fragment"
		Enums.ItemKind.MATERIAL: return StringName(params.get("cat", "material"))
		_: return &"material"


## 🔴 잉크 등급 = 기본 데미지 배수 (세션29, 사용자 확정: "등급=데미지").
## `params.power_mult`(ink_basic/mid/high = 1.0/1.3/1.7). 값이 없으면 1.0.
## ⚠ **id→배수 리졸버는 여기가 아니라 `Db.ink_mult`**다 — 그건 Db(레지스트리)를 봐야 하는데,
## 이 스키마는 class_name이라 `-s` 테스트가 오토로드 등록 전에 컴파일해 `Db` 참조에서 터진다.
func power_mult() -> float:
	return float(params.get("power_mult", 1.0))
