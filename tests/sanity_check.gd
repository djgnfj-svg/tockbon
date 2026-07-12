extends SceneTree
## Phase 0 스모크 테스트 — 스키마·샘플 도안·밸런스 로드 검증.
## 실행: Godot --headless --path . -s res://tests/sanity_check.gd

func _init() -> void:
	var failures: int = 0

	var designs := SampleDesigns.all()
	if designs.size() != 3:
		print("FAIL: 샘플 도안 3개 아님: ", designs.size())
		failures += 1
	if designs[0].arrows.size() != 8:
		print("FAIL: 노바 화살표 8개 아님")
		failures += 1
	if designs[1].circle_type != Enums.CircleType.AIMED:
		print("FAIL: 산탄이 조준진 아님")
		failures += 1
	if designs[2].is_broken():
		print("FAIL: 새 도안이 손상 상태")
		failures += 1

	var balance := load("res://data/balance.tres") as BalanceData
	if balance == null or balance.mana_max <= 0.0:
		print("FAIL: balance.tres 로드 실패")
		failures += 1

	var stroke := StrokeData.new()
	stroke.points = PackedVector2Array([Vector2.ZERO, Vector2.ONE])
	stroke.role = Enums.StrokeRole.ARROW
	var drop := DropEntry.new()
	var item := ItemDef.new()
	var enemy := EnemyDef.new()
	enemy.drops = [drop] as Array[DropEntry]
	var rune := RuneDef.new()
	if stroke == null or item == null or enemy == null or rune == null:
		failures += 1

	if failures == 0:
		print("SANITY_OK")
	quit(failures)
