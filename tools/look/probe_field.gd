extends SceneTree
## A throwaway instrument: what does the opening field actually CONTAIN, and where is it standing?
##
## Written because the user's read after playing was *"내가 때릴 수 있는 애가 없고 물만 존나 있고"* — and
## nothing in the repo counts what a run opens with. The species table says how many HERDS spawn, never how
## far away they land or how many of them the host can survive touching. Headless, no window, prints and quits.

const SCREEN := Vector2(1920.0, 1080.0)

func _initialize() -> void:
	var main: Node = load("res://src/shell/main.gd").new()
	root.add_child(main)
	await process_frame
	await process_frame
	main.title.start_pressed.emit()
	for i in 8:
		await process_frame
	var w: World = main.run.world
	var host: Vector2 = w.swarm.pos[0]
	# ⚠ **`Parts.SPECIES_NAME` itself, never a copy of it.** This line WAS a hand-written seven and the day
	# the roster grew it silently stopped printing the tail of the table — an instrument that reports a
	# shorter field than the one it is standing in.
	var names := Parts.SPECIES_NAME

	print("\n[탐침] 필드 %s · 호스트 %s · 체력 %d · 힘 %d"
			% [str(Rules.FIELD), str(host), w.host_hp, w.swarm.force[0]])

	# -- what is alive, and can the host survive being touched by it --------------------------------------
	var per := {}
	for k in w.critter_count:
		var s := int(w.critter_species[k])
		if not per.has(s):
			per[s] = {"n": 0, "near": INF, "fmin": 9999, "fmax": 0}
		per[s]["n"] += 1
		per[s]["near"] = minf(float(per[s]["near"]), host.distance_to(w.critter_pos[k]))
		per[s]["fmin"] = mini(int(per[s]["fmin"]), int(w.critter_force[k]))
		per[s]["fmax"] = maxi(int(per[s]["fmax"]), int(w.critter_force[k]))
	print("\n  종        마리  가장 가까운 것  힘        한 방인가   내가 몇 대 때려야")
	for s in range(names.size()):
		if not per.has(s):
			print("  %-8s   0" % names[s])
			continue
		var e: Dictionary = per[s]
		var one_shot: bool = int(e["fmin"]) >= w.host_hp
		var hp_of := int(e["fmin"]) * Rules.HP_PER_FORCE
		var swings := int(ceil(float(hp_of) / float(maxi(1, w.swarm.force[0]))))
		print("  %-8s  %2d   %7.0fpx   %3d~%-3d   %-8s   %d대"
				% [names[s], int(e["n"]), float(e["near"]), int(e["fmin"]), int(e["fmax"]),
						"죽는다" if one_shot else "버틴다", swings])

	# -- how much of the field is water, and how much is within one screen of the host --------------------
	var t := w.terrain
	var water_area := 0.0
	for j in t.water_radius.size():
		water_area += PI * float(t.water_radius[j]) * float(t.water_radius[j])
	var rock_area := 0.0
	for j in t.rock_radius.size():
		rock_area += PI * float(t.rock_radius[j]) * float(t.rock_radius[j])
	var field_area := Rules.FIELD.x * Rules.FIELD.y
	print("\n  연못 %d개 · 필드의 %.1f%%     바위 %d개 · %.1f%%"
			% [t.water_pos.size(), 100.0 * water_area / field_area,
					t.rock_pos.size(), 100.0 * rock_area / field_area])

	# -- the opening screen: what can the player actually see and reach ----------------------------------
	var view := Rect2(host - SCREEN * 0.5, SCREEN)
	var on_screen := 0
	var killable_on_screen := 0
	var hunters_on_screen := 0
	for k in w.critter_count:
		if not view.has_point(w.critter_pos[k]):
			continue
		on_screen += 1
		if int(w.critter_force[k]) < w.host_hp:
			killable_on_screen += 1
		if int(Rules.SPECIES_HUNTS[int(w.critter_species[k])]) == 1:
			hunters_on_screen += 1
	var food_on_screen := 0
	for i in w.food.pos.size():
		if w.food.alive[i] == 1 and view.has_point(w.food.pos[i]):
			food_on_screen += 1
	print("\n  첫 화면(1920x1080) 안: 생물 %d마리 (한 방에 안 죽는 놈 %d · 쫓아오는 놈 %d) · 먹이 %d개"
			% [on_screen, killable_on_screen, hunters_on_screen, food_on_screen])

	# -- how far to the nearest thing worth attacking ------------------------------------------------------
	var nearest_safe := INF
	var nearest_any := INF
	for k in w.critter_count:
		var d := host.distance_to(w.critter_pos[k])
		nearest_any = minf(nearest_any, d)
		if int(w.critter_force[k]) < w.host_hp:
			nearest_safe = minf(nearest_safe, d)
	print("  가장 가까운 생물 %.0fpx · 가장 가까운 「한 방에 안 죽는」 생물 %.0fpx (화면 반폭은 960px)"
			% [nearest_any, nearest_safe])
	print("  먹이 %d개가 %s에 흩어져 있다 — 한 개당 %.0f x %.0f px\n"
			% [Rules.FOOD_SPOTS, str(Rules.FIELD),
					Rules.FIELD.x / sqrt(float(Rules.FOOD_SPOTS)),
					Rules.FIELD.y / sqrt(float(Rules.FOOD_SPOTS))])
	quit(0)
