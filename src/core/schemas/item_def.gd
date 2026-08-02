class_name ItemDef
extends Resource
## 잉크·종이·장비·재료·탁본 조각 공통 정의 — data/items/*.tres.

@export var id: StringName
@export var kind: Enums.ItemKind = Enums.ItemKind.MATERIAL
@export var grade: int = 1
@export var display_name: String = ""
## kind별 자유 파라미터 — 스키마 확장 대신 이 Dictionary를 쓴다.
## ⚠ 키를 늘릴 땐 **소비자를 같은 커밋에** — 읽는 데 없는 키는 무효인데 인스펙터엔 보인다.
@export var params: Dictionary = {}

## 소지품 카테고리 — 창고 탭·제작 입력 분류. 완성품은 kind가 곧 카테고리, 재료(MATERIAL)만
## `params.cat`로 가른다: ink_mat·paper_mat·equip_mat·food·water.
## 🔴 enum을 쪼개지 않는 이유 — ItemKind를 나누면 **저장된 아이템·equipment의 키가 밀린다**.
## 그래서 데이터 태그로 나눈다(새 분류 = .tres params 한 줄).
func category() -> StringName:
	match kind:
		Enums.ItemKind.INK: return &"ink"
		Enums.ItemKind.PAPER: return &"paper"
		Enums.ItemKind.WAND, Enums.ItemKind.ROBE, Enums.ItemKind.CHARM, Enums.ItemKind.PEN, Enums.ItemKind.HAT: return &"equip"
		Enums.ItemKind.FRAGMENT: return &"fragment"
		Enums.ItemKind.MATERIAL: return StringName(params.get("cat", "material"))
		_: return &"material"


## 잉크 등급 = 기본 데미지 배수. `params.power_mult`, 없으면 1.0.
## ⚠ id→배수 리졸버는 여기가 아니라 `Db.ink_mult`다 — 스키마(class_name)가 `Db`를 물면
##  `-s` 테스트가 오토로드 등록 전 컴파일에서 터진다.
func power_mult() -> float:
	return float(params.get("power_mult", 1.0))
