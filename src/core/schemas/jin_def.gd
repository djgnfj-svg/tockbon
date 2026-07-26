class_name JinDef
extends Resource
## 진 정의 — 마법진의 **바깥 그릇**(투사체 몸). data/jin/*.tres. (세션 13 구조화)
##
## 🔴 축 분담: 진이 **연산 구조**를 정한다 — 층 수·룬 자리·발사 형태·몸(비행·규모) (GDD §4 「세 축」).
## **"새 진 = .tres 한 장"**이 이 스키마의 목표다.

@export var id: StringName = &"plain"
@export var display_name: String = "일반진"
## 1차 고리가 주는 칸 수 (지금 8). ⚠ 고리 기하 계약(8점 원주)이라 8 고정.
## ⚠ src 소비자 0 (세86 실측) — 라이브 8은 `RingBoard.SLOTS`가 쥔다. 여긴 스키마 표기용이다.
@export var slot_count: int = 8
## ⚠ **`glyph_slots`(진이 여는 문양 칸)는 세85 ⑦에 은퇴했다** (사용자 결정 · 감사 #8) — 세79 층
## 모델이 그 자리를 대체했다. 열린 칸은 `ring_forge_panel.build_assembly()`가 **층에 실제로 놓인
## 칸의 합집합**으로 만들고, 진의 개성은 `band_count`·`rune_slots`가 쥔다.
## 🔴 **필드만 되돌리지 마라 — 소비자(`build_assembly`의 `open` 마스킹)를 같은 커밋에** 넣어라
## (소비자 없는 필드 = 거짓 손잡이, 감사 T3). 값·경위 = git 이력(세85 이전).
## ✅ 부재 자체는 `test_ring_assembly_auto`가 잰다(되살리면 빨개진다).
## 🔴 진의 **층 수** (세71c — 조립→탁본 층 시각화). 문양-고리를 끼우는 동심원 고리가 몇 겹인가.
## 일반진 = 1층. 나중 진은 2·3층으로 확장(밴드 반경은 RingBoard.BAND_RADII 앞 band_count개).
## ⚠ .tres에 이 필드가 없으면(옛 파일·jin_single) 기본값 1 — 조용히 안 깨진다(glyph_slots 선례, 세60).
## 패널 `_bands` 크기가 이 값에서 파생되고, 책 층 탭 소켓 수·판 흐린 동심원 개수가 여기서 나온다.
@export var band_count: int = 1
## 🔴 이 진의 **룬 자리 수** (세81 M2 — 융합진). 진 모양이 룬을 몇 개 담나. 일반진 = 1(중심 하나).
## 융합진 = 2(중심 좌우). ⚠ .tres에 없으면(옛 파일·jin_single) 기본 1 — 조용히 안 깨진다
## (glyph_slots·band_count 선례, 세60·71c). 자리 위치는 이 값에서 파생한다(중심 둘레 균등) —
## 배치 좌표 필드는 진마다 다른 배치가 실제로 필요할 때 더한다(YAGNI). 조립 패널 룬 소켓·밑그림
## 룬 점열이 이 값을 읽는다. **룬 1개 진은 M1과 계산이 완전히 동일**해야 한다(무회귀).
@export var rune_slots: int = 1
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
## 6=물결원 7=렌즈. 소비자 = `ring_forge_panel`(판 밑그림)·`ring_book`(진 셀 아이콘).
## ⚠ 세83 그리기 폐지 뒤엔 「손으로 긋는 궤적」이 아니라 **보이는 진 모양**이다(스위치를 되돌리면
## 다시 궤적이 된다 — `balance.skip_drawing`).
## ⚠ 반드시 **닫힌** 도형이어야 한다 — 진은 룬을 담는 그릇이고, 안에 룬이 들어갈 공간이 남아야 한다.
## 채점(`trace_scorer`)은 이 가이드 점열을 그대로 받는다 — 공식은 안 바뀌고 모양만 바뀐다.
@export var guide_shape: int = 0
## 조립 보드에서 그릇 원을 그리는 색.
@export var ui_color: Color = Color(0.42, 0.30, 0.12, 0.55)
## 🔴 발사 형태 (진=형태, 세션44). `ring_spell_system._shot_plan`이 이 값으로 진(캐리어)을 쏜다.
## Enums.WandPattern **6값**: 0=단발 1=산탄 2=둘레(전방위) 3=연발 4=분사 5=타겟팅(세48에 셋 추가).
## 🔴 지팡이가 형태를 쥐던 축은 **세85에 은퇴했다** — 이 필드가 형태의 유일한 소스다(되돌리지 마라).
@export var pattern: int = 0
## 🔴 해금 id (codex). 빈 값 = 항상 보유. RuneDef.unlock_id와 같은 규약 — 패널이 해금된 진만 보여준다.
## 시작 시드는 jin_single 하나다(GameState._seed_starting_unlocks, 세션61 콘텐츠 리셋). 나머진 큐레이션으로 는다.
@export var unlock_id: StringName = &""
## 🔴 UI 열거 순서 (작을수록 앞). all_jins가 id가 아니라 이 값으로 정렬 — 단발→산탄→둘레.
@export var sort: int = 0
