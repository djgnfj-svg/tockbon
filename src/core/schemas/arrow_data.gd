class_name ArrowData
extends Resource
## 화살표 문양 파라미터 — 인식기 없이 직접 추출된다 (TECH_SPEC §6).

## rad. 고정진=절대각 / 조준진=aim_axis 기준 상대각
@export var direction: float = 0.0
## 0..1 → 투사체 위력·크기
@export var magnitude: float = 0.5
## 진 내 상대 발사 기점 (정규 좌표, 진 중심 = 0,0)
@export var origin: Vector2 = Vector2.ZERO
