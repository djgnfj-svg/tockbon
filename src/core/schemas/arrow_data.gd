class_name ArrowData
extends Resource
## 화살표 문양 파라미터 — 인식기 없이 직접 추출된다 (TECH_SPEC §6).

## rad. **캔버스 절대각** — 원본 획(strokes)·origin과 같은 좌표계다.
## 발사 시 spell_system이 `aim_angle - aim_axis` 만큼 **한 번만** 통째로 회전시킨다.
## 여기에 aim_axis를 미리 빼 두면 발사 때 또 빠져 90도 틀어진다 (세션 7 실측 버그).
@export var direction: float = 0.0
## 0..1 → 투사체 위력·크기
@export var magnitude: float = 0.5
## 발사 기점 — 진 중심 기준, **진 반지름 = 1.0 정규화** (원 가장자리 = 1.0).
## 월드 오프셋 px = origin × circle_radius × balance.circle_radius_px (모듈 B 공식)
@export var origin: Vector2 = Vector2.ZERO
## 그린 화살표 획의 곡선 경로 — "그린 대로 날아간다" (TECH_SPEC §4.4).
## 좌표계: 획 시작점 = 원점, +X = 발사 방향(direction)인 로컬 공간. 단위는 캔버스 단위
## (월드 px = × InkRender.unit_px(balance)). **비면 직선 폴백** — 샘플 도안·구세이브 호환.
@export var path: PackedVector2Array = PackedVector2Array()
## path와 짝을 이루는 필압 — 투사체 먹선의 굵기 변화. 붓을 누른 그대로 날아가야 한다
## (없으면 균일 굵기 = 진에만 붓맛이 있고 탄에는 없는 비대칭이 생긴다).
## path와 **같은 리샘플 인덱스**를 쓴다. 비어 있어도 무방 — make_line이 균일 굵기로 폴백.
@export var path_pressures: PackedFloat32Array = PackedFloat32Array()
