extends SceneTree
func _initialize() -> void:
	for i in Islands.count():
		var g := Grid.new()
		# ⚠ `Islands.load_into` and not `load_rows(rows_of(i))` — an island is terrain AND a tier board
		# since 티켓 19, and a probe that loaded only the rows reported a flat island with nothing
		# barking. The local `rows` this used to keep went with it: it had no other reader.
		Islands.load_into(g, i)
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
