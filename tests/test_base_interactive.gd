extends Node2D
## test_base.tscn 인터랙티브 시드 — F6 실행 시 재료·조각·도안 주입 (테스트 전용).
## 시설 3곳(작업대·창고·연구소)과 침대를 돌며 E로 패널을 열어 기능을 확인한다.

func _ready() -> void:
	GameState.add_item(&"mat_vine", 9)
	GameState.add_item(&"mat_slime_core", 4)
	GameState.add_item(&"mat_hound_fang", 2)
	GameState.add_item(&"mat_beetle_shell", 6)
	GameState.add_item(&"mat_mist_essence", 4)
	GameState.add_item(&"mat_night_bloom", 5)
	GameState.add_item(&"mat_moon_sap", 4)
	GameState.add_item(&"fragment_water", 1)
	GameState.add_item(&"fragment_wind", 1)
	GameState.add_item(&"ink_basic", 6)
	var damaged := SampleDesigns.nova_fire()
	damaged.durability = 3
	GameState.designs.append(damaged)
	var broken := SampleDesigns.aimed_shotgun_impact()
	broken.durability = 0
	GameState.designs.append(broken)
	GameState.designs.append(SampleDesigns.aimed_lance_water())
	print("[test_base] 시드 완료 — WASD 이동, E 상호작용, ESC 닫기")
