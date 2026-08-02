class_name JinDef
extends Resource
## 진 정의 — 마법진의 바깥 그릇(투사체 몸). data/jin/*.tres.
## 진이 연산 구조를 정한다 — 층 수·룬 자리·발사 형태·몸(비행·규모).
## 「새 진 = .tres 한 장」이 이 스키마의 목표다.

@export var id: StringName = &"plain"
@export var display_name: String = "일반진"
## 1차 고리가 주는 칸 수. ⚠ 고리 기하 계약(8점 원주)이라 8 고정이고, 라이브 값은
##  `RingBoard.SLOTS`가 쥔다 — 여긴 스키마 표기용이다.
@export var slot_count: int = 8
## 진의 층 수 — 문양-고리를 끼우는 동심원 고리가 몇 겹인가. 일반진 = 1층.
## 패널 `_bands` 크기·책 층 탭 소켓 수·판 흐린 동심원 개수가 여기서 파생된다.
## ⚠ .tres에 이 필드가 없는 옛 파일은 기본값 1로 조용히 넘어간다.
@export var band_count: int = 1
## 이 진의 룬 자리 수. 일반진 = 1(중심 하나) · 융합진 = 2(중심 좌우).
## 자리 위치는 이 값에서 파생한다(중심 둘레 균등) — 배치 좌표 필드는 실제로 필요할 때 더한다.
## ⚠ 옛 파일은 기본 1로 조용히 넘어간다. 🔴 룬 1개 진은 계산이 완전히 동일해야 한다(무회귀).
@export var rune_slots: int = 1
## 진의 규모 — 단순히 몸이 커지는 게 아니라 그 진의 고유 강점을 키운다.
## 몸(히트박스·먹선)은 전 진 공통으로 커지고, 그 위에 패턴별로:
##   단발·타겟팅=몸집 · 산탄/둘레/연발/분사=발수 · 나선=진폭 · 부메랑=사거리.
@export var body_scale: float = 1.0
## 비행 경로 — Enums.JinMotion: 0=직진 · 1=나선 · 2=부메랑. ring_carrier가 이 값으로 경로를 고른다.
## `pattern`(언제·어디로 몇 발)과 직교하는 축이다 — 둘을 곱해야 「새 진 = .tres 한 장」이 성립한다.
@export var motion: int = 0
## 밑그림 도형 — Enums.JinShape: 0=원 1=삼각 2=팔각 3=타원 4=오각 5=마름모 6=물결원 7=렌즈.
## ⚠ 반드시 **닫힌** 도형이어야 한다 — 진은 룬을 담는 그릇이라 안에 룬이 들어갈 공간이 남아야 한다.
@export var guide_shape: int = 0
## 조립 보드에서 그릇 원을 그리는 색.
@export var ui_color: Color = Color(0.42, 0.30, 0.12, 0.55)
## 발사 형태 — Enums.WandPattern 6값: 0=단발 1=산탄 2=둘레 3=연발 4=분사 5=타겟팅.
## `ring_spell_system._shot_plan`이 이 값으로 진(캐리어)을 쏜다.
## 🔴 이 필드가 형태의 유일한 소스다 — 지팡이로 되돌리지 마라.
@export var pattern: int = 0
## 해금 id (codex). 빈 값 = 항상 보유. 패널이 해금된 진만 보여준다.
@export var unlock_id: StringName = &""
## UI 열거 순서 (작을수록 앞). all_jins가 id가 아니라 이 값으로 정렬한다.
@export var sort: int = 0
