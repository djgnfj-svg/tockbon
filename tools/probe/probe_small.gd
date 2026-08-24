extends SceneTree
func _initialize() -> void:
	for i in Islands.count():
		var rows: Array = Islands.rows_of(i)
		var g := Grid.new()
		g.load_rows(rows)
		var summon := 0
		var landing := 0
		for t in g.w * g.h:
			if g.can_summon_at(t):
				summon += 1
			var home := g.home_harbour_for(t)
			if home >= 0 and g.can_land_at(home, t):
				landing += 1
		print("island %d  %dx%d  harbours %d  적 %d  소환칸 %d  상륙칸 %d" % [
			i, g.w, g.h, g.harbour_tiles.size(), Islands.spawns_of(i).size(), summon, landing])
	quit()
