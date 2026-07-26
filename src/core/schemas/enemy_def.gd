class_name EnemyDef
extends Resource
## 적 정의 — data/enemies/*.tres (인스턴스 작성은 모듈 C 소유).

@export var id: StringName
@export var display_name: String = ""
@export var hp: float = 30.0
## 🔴 약점 룬 — **전투에 실재한다**(표기용이 아니다): `forest_enemy.take_hit`이 이 룬으로 맞으면
## `params.weakness_mult`를 곱한다(세86 실측). 그래서 값을 바꾸면 보스 피해량이 조용히 달라진다.
@export var counter_rune: Enums.RuneType = Enums.RuneType.FIRE
## false = 약점 없음 (counter_rune 무시, 예: 수액 슬라임 — 다발 도안이 답)
@export var has_counter: bool = true
## 전투 수치 자유 파라미터 (속도·접촉 피해·사거리 등) — 스키마 확장 대신 이것을 쓴다
@export var params: Dictionary = {}
@export var drops: Array[DropEntry] = []
## 🔴 세66: `drops_chest`는 은퇴했다 (상자 시스템 기각 — 사용자 확정). 모든 적이 보스 포함
## `drops`를 굴려 **낱개 픽업**(drop_pickup + 자석, 세46·51)으로 떨군다. 값어치는 픽업의
## **등급 후광**이 알린다(상자의 "열기 전 값어치"를 대체). 형태 분기 자체가 사라졌다.
#
# ── 🔴 세85: `night_buff`·`is_elite`를 걷었다 (세84 감사 #20 · 사용자 결정 ⑧) ──────────────
# 둘 다 **읽는 곳이 0곳**이었다(`is_elite`는 테스트 단정 1줄뿐 = 죽은 필드를 재는 그물).
#  • `night_buff`: 밤 강화 배율. 데이터는 slime 1.4·mist 1.6·gale 1.2로 **세심히 갈려 있어서**
#    「낮밤이 전투에 영향을 준다」는 거짓 신호를 줬다 — 실제로 `Clock`의 실질 역할은 자동저장
#    틱이고, 챕터 보스방 루프와 낮밤의 접점은 0이다. 코드보다 오래 산 데이터의 표본(감사 T3).
#  • `is_elite`: 드롭 형태 분기가 세66에 사라진 뒤(위 주석) 남은 라벨. 지금 「정예」는 `hp`·
#    `params.ai`·`drops`가 말한다.
# ⚠ 밤 강화를 정말 붙일 땐 **소비자를 같은 커밋에** — 그게 ⑧의 규율이다. 되돌림 = git 이력.
