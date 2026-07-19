class_name JinDef
extends Resource
## 진 정의 — 마법진의 **바깥 그릇**(투사체 몸). data/jin/*.tres. (세션 13 구조화)
##
## 🔴 축 분담(TRUTH): 진이 **모양**을 정한다 — 몸(비행·히트박스·규모) + 고리 칸 구조.
## 지금은 일반진 하나뿐이지만, 옛 int const `_has_jin`(bool)에서 데이터로 빼 **"진 모양 추가 = .tres 한 장"**
## 이 되게 한다. 층·칸·규모가 늘어날 자리를 연다.

@export var id: StringName = &"plain"
@export var display_name: String = "일반진"
## 1차 고리가 주는 칸 수 (지금 8). 진마다 다른 칸 구조를 줄 자리.
@export var slot_count: int = 8
## 투사체 몸 규모 배수 (비행 히트박스·연출). 지금 1.0.
@export var body_scale: float = 1.0
## 조립 보드에서 그릇 원을 그리는 색.
@export var ui_color: Color = Color(0.42, 0.30, 0.12, 0.55)
## 🔴 발사 형태 (진=형태, 세션44). ring_spell_system이 이 값으로 진(캐리어)을 쏜다.
## Enums.WandPattern 값: 0=단발(SINGLE) · 1=산탄(MULTI) · 2=둘레(NOVA·전방위). 그전엔 지팡이 장비
## (wand_pattern)가 쥐던 축을 진으로 옮겼다 — 이제 "진 = 발사 형태"이고 마법진이 이 진을 저장·발사한다.
@export var pattern: int = 0
## 🔴 해금 id (codex). 빈 값 = 항상 보유. RuneDef.unlock_id와 같은 규약 — 패널이 해금된 진만 보여준다.
## 시작엔 jin_single/fork/ring 셋을 시드한다(GameState._seed_starting_unlocks). 나머진 크래프트/보상.
@export var unlock_id: StringName = &""
## 🔴 UI 열거 순서 (작을수록 앞). all_jins가 id가 아니라 이 값으로 정렬 — 단발→산탄→둘레.
@export var sort: int = 0
