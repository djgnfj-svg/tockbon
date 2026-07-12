extends RefCounted
## 필체 라이브러리 — 인식된 룬 형태를 도장처럼 저장·재배치 (GDD §4.4).
## 스탬프 사용 시 저장 시점의 정확도(원시 $1 점수)를 그대로 보존한다 (v1.3 확정).
## 스탬프: {"rune_type": int, "score": float, "points": PackedVector2Array(단위 박스), "pressures": PackedFloat32Array}

const DesignBuilder := preload("res://src/drawing/design_builder.gd")

var _stamps: Array[Dictionary] = []


func add(stamp: Dictionary) -> int:
	_stamps.append(stamp)
	return _stamps.size() - 1


func get_stamp(index: int) -> Dictionary:
	if index < 0 or index >= _stamps.size():
		return {}
	return _stamps[index]


func count() -> int:
	return _stamps.size()


func label(index: int) -> String:
	var s := get_stamp(index)
	if s.is_empty():
		return "?"
	return "%s  정확도 %d%%" % [
		DesignBuilder.rune_name(int(s.rune_type)),
		roundi(float(s.score) * 100.0),
	]
