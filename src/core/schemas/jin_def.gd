class_name JinDef
extends Resource
## 진 정의 — 마법진의 **바깥 그릇**(투사체 몸). data/jin/*.tres. (세션 13 구조화)
##
## 🔴 축 분담(TRUTH): 진이 **모양**을 정한다 — 몸(비행·히트박스·규모) + 고리 칸 구조.
## 지금은 일반진 하나뿐이지만, 옛 int const `_has_jin`(bool)에서 데이터로 빼 **"진 모양 추가 = .tres 한 장"**
## 이 되게 한다. 층·칸·규모가 늘어날 자리를 연다.

@export var id: StringName = &"plain"
@export var display_name: String = "일반진"
## 1차 고리가 주는 칸 수 (지금 8). ⚠ 고리 기하 계약(8점 원주)이라 8 고정 — "어느 칸"은 아래 glyph_slots.
@export var slot_count: int = 8
## 🔴 이 진이 여는 문양 칸 (세션60 — 문양본 축 흡수. 옛 TEMPLATES 4종을 진이 물려받았다).
## 칸 0=위(=발사 진행 방향), 시계방향 0~7. 착탄 전개 각도가 칸 인덱스에서 나오므로
## (ring_spell_system의 TAU*k/8) **배치 = 착탄 후 탄 방향**이다. 칸 수 차등은 D5(진 배치)와 묶인 밸런스 결정.
## ⚠ .tres에 이 필드가 없으면(옛 파일·깜빡함) 기본값 = 8칸 전부 — 새 진이 조용히 약해지지 않는다.
@export var glyph_slots: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
## 🔴 진의 **규모** (세션48에 DARK에서 깨어남 — 그전엔 선언만 되고 아무도 안 읽었다).
## 사용자 확정: *"크면 진마다 있는 발사 형태가 강해지는 형태"* — 단순히 몸이 커지는 게 아니라
## **그 진의 고유 강점을 키운다.** 몸(히트박스·먹선)은 전 진 공통으로 커지고, 그 위에 패턴별로:
##   단발·타겟팅=몸집(맞히기 쉬움) · 산탄/둘레/연발/분사=발수 · 나선=진폭 · 부메랑=사거리
## → 큰 산탄진은 갈래가 늘고, 큰 나선진은 더 넓게 훑는다. **"크다"의 의미가 진마다 다르다.**
@export var body_scale: float = 1.0
## 🔴 비행 경로 (세션48 신설). Enums.JinMotion: 0=직진 · 1=나선 · 2=부메랑.
## `pattern`(언제·어디로 몇 발)과 **직교하는 축**이다 — 둘을 곱하면 조합이 열려 "새 진 = .tres
## 한 장"이 비로소 성립한다(세션44엔 진 3개가 패턴 3개를 1:1로 소진해 4번째가 코드였다).
## ring_carrier가 이 값으로 `_physics_process` 경로를 고른다.
@export var motion: int = 0
## 🔴 밑그림 도형 (세션48 신설). Enums.JinShape: 0=원 1=삼각 2=팔각 3=타원 4=오각 5=마름모
## 6=물결원 7=렌즈. **손으로 긋는 궤적이 곧 이 도형**이라 진마다 손이 다르게 움직인다.
## ⚠ 반드시 **닫힌** 도형이어야 한다 — 진은 룬을 담는 그릇이고, 안에 룬이 들어갈 공간이 남아야 한다.
## 채점(`trace_scorer`)은 이 가이드 점열을 그대로 받는다 — 공식은 안 바뀌고 모양만 바뀐다.
@export var guide_shape: int = 0
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
