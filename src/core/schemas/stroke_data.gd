class_name StrokeData
extends Resource
## 원본 획 — 렌더링·수리·재편집용. 좌표는 캔버스 정규화(0..1).

@export var points: PackedVector2Array
@export var pressures: PackedFloat32Array
@export var role: Enums.StrokeRole = Enums.StrokeRole.DECOR
