extends SceneTree
## EnemyDef .tres 생성기 (모듈 C) — 손으로 .tres를 쓰지 않고 코드로 저장해 포맷 오류를 차단.
## 실행: Godot --headless --path . -s res://tests/test_field_make_defs.gd
## 아이템 ID는 모듈 D 합의 규약, 스탯 근거는 GDD §7 (적 5종 = 설계 문제).

const OUT_DIR := "res://data/enemies"

func _init() -> void:
	var errors := 0
	errors += _save(_vine())
	errors += _save(_hound())
	errors += _save(_slime())
	errors += _save(_slime_elite())
	errors += _save(_mist())
	errors += _save(_beetle())
	errors += _save(_gale())
	if errors == 0:
		print("MAKE_DEFS_OK")
	quit(errors)

func _save(def: EnemyDef) -> int:
	var path := "%s/%s.tres" % [OUT_DIR, def.id]
	var err := ResourceSaver.save(def, path)
	if err != OK:
		print("FAIL: 저장 실패 %s (err=%d)" % [path, err])
		return 1
	var check := load(path) as EnemyDef
	if check == null or check.id != def.id or check.drops.size() != def.drops.size():
		print("FAIL: 재로드 검증 실패 %s" % path)
		return 1
	print("saved: %s (hp=%.0f, drops=%d)" % [path, check.hp, check.drops.size()])
	return 0

func _drop(item_id: StringName, chance: float, min_count: int = 1, max_count: int = 1) -> DropEntry:
	var d := DropEntry.new()
	d.item_id = item_id
	d.chance = chance
	d.min_count = min_count
	d.max_count = max_count
	return d

## 재생 덩굴 — 고정형·재생, 약점 불△ (화상이 재생 정지)
func _vine() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"vine"
	d.display_name = "재생 덩굴"
	d.hp = 40.0
	d.counter_rune = Enums.RuneType.FIRE
	d.night_buff = 1.4
	d.params = {
		"move_speed": 0.0, "aggro_range": 80.0, "attack_range": 46.0,
		"attack_cooldown": 1.2, "contact_damage": 6.0, "weakness_mult": 1.75,
		"regen_per_sec": 2.5,
	}
	d.drops = [_drop(&"mat_vine", 1.0, 1, 2)] as Array[DropEntry]
	return d

## 숲 사냥개 — 돌진, 약점 바람◎ (흐름의 밀림이 돌진 캔슬) (v2.2)
func _hound() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"hound"
	d.display_name = "숲 사냥개"
	d.hp = 26.0
	d.counter_rune = Enums.RuneType.WIND
	d.night_buff = 1.5
	d.params = {
		"move_speed": 95.0, "aggro_range": 220.0, "attack_range": 20.0,
		"attack_cooldown": 1.0, "contact_damage": 8.0, "weakness_mult": 1.75,
		"charge_trigger_range": 120.0, "charge_speed": 330.0,
		"windup_sec": 0.5, "dash_sec": 0.4, "recover_sec": 0.8,
	}
	d.drops = [
		_drop(&"mat_hound_fang", 0.8),
		_drop(&"wand_basic", 0.05),
	] as Array[DropEntry]
	return d

## 수액 슬라임 — 다수 소형·분열. 약점 룬 없음(has_counter=false — 다발 도안이 답)
func _slime() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"slime"
	d.display_name = "수액 슬라임"
	d.hp = 14.0
	d.has_counter = false
	d.night_buff = 1.4
	d.params = {
		"move_speed": 55.0, "aggro_range": 160.0, "attack_range": 18.0,
		"attack_cooldown": 0.9, "contact_damage": 4.0,
	}
	d.drops = [_drop(&"mat_slime_core", 0.6)] as Array[DropEntry]
	return d

## 수액 슬라임 엘리트 — 물 룬 탁본 조각 (GDD §6 — 갑충 순환 방지)
func _slime_elite() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"slime_elite"
	d.display_name = "수액 슬라임 우두머리"
	d.hp = 60.0
	d.has_counter = false
	d.is_elite = true
	d.night_buff = 1.3
	d.params = {
		"move_speed": 45.0, "aggro_range": 160.0, "attack_range": 22.0,
		"attack_cooldown": 0.9, "contact_damage": 7.0,
	}
	d.drops = [
		_drop(&"mat_slime_core", 1.0, 2, 3),
		_drop(&"fragment_water", 1.0),    # 직접 드롭 아님 — 탁본 잔류물로 획득
	] as Array[DropEntry]
	return d

## 안개 정령 — 부유·산개, 약점 바람◎
func _mist() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"mist"
	d.display_name = "안개 정령"
	d.hp = 20.0
	d.counter_rune = Enums.RuneType.WIND
	d.night_buff = 1.6
	d.params = {
		"move_speed": 70.0, "aggro_range": 200.0, "attack_range": 30.0,
		"attack_cooldown": 1.1, "contact_damage": 5.0, "weakness_mult": 2.0,
		"dispersed_resist": 0.35, "disperse_period": 2.5,
		"hover_min": 55.0, "hover_max": 95.0,
	}
	d.drops = [
		_drop(&"mat_mist_essence", 0.7),
		_drop(&"robe_basic", 0.05),
	] as Array[DropEntry]
	return d

## 갑주 갑충 — 장갑 피해 감소, WET로 무력화, 약점 물~
func _beetle() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"beetle"
	d.display_name = "갑주 갑충"
	d.hp = 55.0
	d.counter_rune = Enums.RuneType.WATER
	d.night_buff = 1.5
	d.params = {
		"move_speed": 40.0, "aggro_range": 170.0, "attack_range": 24.0,
		"attack_cooldown": 1.4, "contact_damage": 9.0, "weakness_mult": 1.75,
		"armor_reduction": 0.7,
	}
	d.drops = [
		_drop(&"mat_beetle_shell", 0.9, 1, 2),
		_drop(&"charm_basic", 0.08),
	] as Array[DropEntry]
	return d

## 중간보스 — 바람을 품은 존재: 바람 룬 탁본 조각 (GDD §6·§7).
## 약점 불△ (v2.2: 충격 룬 폐지) — 바람 룬을 주는 보스라 자기 룬이 약점일 수 없다.
func _gale() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = &"gale"
	d.display_name = "바람을 품은 존재"
	d.hp = 250.0
	d.counter_rune = Enums.RuneType.FIRE
	d.is_elite = true          # 엘리트 경로 재사용 — 사망 시 탁본 잔류물 스폰
	d.night_buff = 1.2
	d.params = {
		"move_speed": 55.0, "aggro_range": 260.0, "attack_range": 30.0,
		"attack_cooldown": 1.5, "contact_damage": 10.0, "weakness_mult": 1.6,
		"gust_period": 3.0, "gust_windup": 0.8, "gust_radius": 90.0,
		"gust_damage": 8.0, "gust_push_dist": 70.0,
		"volley_period": 4.5, "volley_count": 3, "volley_interval": 0.25,
		"proj_speed": 170.0, "proj_damage": 6.0, "proj_lifetime": 2.8,
		"phase2_speed_mult": 1.3, "phase2_rate_mult": 0.65,
	}
	d.drops = [
		_drop(&"mat_mist_essence", 1.0, 2, 3),
		_drop(&"fragment_wind", 1.0),    # 직접 드롭 아님 — 탁본 잔류물로 획득
	] as Array[DropEntry]
	return d
