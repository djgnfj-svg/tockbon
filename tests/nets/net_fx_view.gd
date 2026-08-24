extends RefCounted
## The VIEW half of the twelve combat effects, rewritten for the 3D field (ticket 09, step 4). The
## sim half — what `Battle` puts in `events` — is `net_fx`'s; this file injects those facts into a
## real `FieldView`, calls `_process` by hand, and reads the surfaces the seam now names:
##
##   surface 2 — the pooled `Sprite3D` fields the engine consumes (position · modulate · scale),
##               where the body-bound effects live: flash, lunge, knockback, gait squash
##   surface 3 — the fx buffers `_g_v`/`_g_c` (ground) and `_a_v`/`_a_c` (air) after `_process`,
##               plus each layer's `mesh.get_surface_count()` — buffers prove geometry was BUILT,
##               the surface count proves `_fx_flush` COMMITTED it, and only the pair closes the
##               hole where deleting the flush stays green
##
## **Every transient is measured on the five axes the plan names**: which layer it lands in (and
## that the OTHER buffer stayed empty) · its vertex count as a hand literal · its position and
## EXTENT (a ring collapsed to radius 0 keeps the right centre and dies on the extent) · its colour
## with the fade's floor and ceiling in one equality · and ground marks follow the ground while air
## marks stand in the camera's plane, turns included.
##
## ⚠ **The exact vertex counts ARE the duty rows**: one event's floor (the mark exists, 「연출은
## 과할 정도로」's own number) and its ceiling (it does not cover the screen) in a single equality.
##
## ⚠ **Ages are injected as `<SEC constant> * 0.5`** so the fade is exactly 0.5 whatever the
## constant holds — `x * 0.5 / x` is exact in floats — and the expected colour can be compared
## outright instead of through a tolerance wide enough to hide a wrong fade.
##
## Fixtures are ARENA-small (24 x 12, and a 7 x 5 palm for the terrain rows): `setup()` rebuilds the
## whole terrain mesh, and a real island per row is what made an old net spin for 24 s unnoticed.


const ARENA_W := 24
const ARENA_H := 12

## Every `FieldView` built here, freed at the end — a `Node2D` left unfreed is a leaked RID on
## stderr, which the wrapper reads as failure.
var _created: Array = []


func run(t) -> void:
	_the_terrain_speaks_the_legend(t)
	_the_landing_ring(t)
	_the_area_ring_follows_the_ground(t)
	_the_refusal_mark(t)
	_the_intent_line(t)
	_the_tracer(t)
	_the_spark(t)
	_the_death_burst_stands_in_the_camera_plane(t)
	_the_hit_halo(t)
	_body_effects_ride_the_pooled_fields(t)
	_the_boat_route_shrinks_with_the_sim(t)
	_a_dry_slot_draws_no_plan(t)
	_the_transient_drawer_is_capped(t)
	_the_readers_themselves(t)
	for raw in _created:
		var fv: FieldView = raw
		fv.free()
	_created = []


# == the terrain, on a palm-sized island (verify-read A) ==============================================
## Steps 1-3 left the terrain with existence checks only — faces exist, the sea is visible — so the
## LEGEND -> COLOUR mapping could collapse to one tone and the cliff could lose its seaward wall with
## the round green. Both get hand-counted rows on a fixture small enough to count by hand:
##
##   "~~~~~~~"      cliff (1,1) stands against water on its west and north — the sea-wall subject
##   "~^.#..~"      hole (3,1) — the lowest thing on the island, nothing skirts DOWN from it
##   "~..^/.~"      inland cliff (3,2) with its ramp (4,2) — the ramp JOINS both sides, so it
##   "~.....~"      contributes exactly its own top face and no skirt
##   "~~~~~~~"
##
## A top face is 2 triangles = **6 vertices wearing the tile's own colour**; a skirt wears that
## colour `darkened(0.15)`. HOLE / CLIFF / RAMP are the three kinds whose colour is EXACTLY
## `terrain_colour_of_char` (only LAND is height-tinted and shore-blended), so their counts are
## closed hand literals: 6 · 12 (two cliffs) · 6.
func _the_terrain_speaks_the_legend(t) -> void:
	var rows := [
		"~~~~~~~",
		"~^.#..~",
		"~..^/.~",
		"~.....~",
		"~~~~~~~",
	]
	var b := _battle_of(rows, _army_of([]), [], 999.0)
	var fv := _view_of(b, rows)
	var arrays: Array = (fv._terrain.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	t.ok(verts.size() > 0 and cols.size() == verts.size(), "지형 메시에 정점과 색이 같이 들어 있다 (자가 점검)")

	# The legend -> colour mapping, one closed count per untinted kind. A mapping collapsed to one
	# tone moves every one of these counts at once.
	var hole := _mesh_verts_of(verts, cols, Look.COL_HOLE)
	t.eq(hole.size(), 6, "구덩이 색 정점이 정확히 6개다 — # 한 칸의 윗면 두 삼각형")
	t.ok(_all_inside_tile(hole, 3, 1), "그리고 전부 (3,1) 칸 안이다 — 색이 자리까지 맞다")
	var cliff := _mesh_verts_of(verts, cols, Look.COL_CLIFF)
	t.eq(cliff.size(), 12, "절벽 색 정점이 정확히 12개다 — ^ 두 칸의 윗면")
	var cliff_stray := 0
	for v: Vector3 in cliff:
		if not (_inside_tile(v, 1, 1) or _inside_tile(v, 3, 2)):
			cliff_stray += 1
	t.eq(cliff_stray, 0, "절벽 정점이 두 절벽 칸 밖으로 안 샌다")
	var ramp := _mesh_verts_of(verts, cols, Look.COL_RAMP)
	t.eq(ramp.size(), 6, "경사로 제 색 정점이 정확히 6개다 — 윗면 두 삼각형 (스커트는 어두워져 딴 색이다)")
	t.ok(_all_inside_tile(ramp, 4, 2), "그리고 전부 (4,2) 칸 안이다")
	t.eq(_mesh_verts_of(verts, cols, Look.COL_WATER).size(), 0,
		"물색 정점은 0개다 — 바다는 지형 메시가 아니라 자기 판이 그린다")

	# The cliff's SEA-SIDE wall (the skirt): cliff (1,1) faces open water west and north, so its
	# darkened wall must reach DOWN to the sea (~0.10, water height minus the pad) — flip `_skirt`'s
	# lower-neighbour test on the water side and the wall stops under the land line (~0.95+) instead.
	var wall := _mesh_verts_of(verts, cols, Look.COL_CLIFF.darkened(0.15))
	t.ok(wall.size() >= 12, "절벽의 스커트 벽 정점이 있다 (%d개)" % wall.size())
	var wall_min := 1e9
	var wall_max := -1e9
	for v: Vector3 in wall:
		wall_min = minf(wall_min, v.y)
		wall_max = maxf(wall_max, v.y)
	t.ok(wall_min < 0.4, "그 벽이 바다까지 내려간다 (min y %.2f) — 물 쪽 벽을 빼면 1.0 근처에서 멈춘다" % wall_min)
	t.ok(wall_max > 2.0, "그리고 절벽 꼭대기에서 시작한다 (max y %.2f)" % wall_max)


# == the ground transients ============================================================================

## Item 7 — the landing ring. Fixed radius 20 px, so the piece count is closed:
## ceil(TAU·20 / 20) = 7, floored to the minimum 8 segments ⇒ 8 quads = **48 vertices**, ground only.
func _the_landing_ring(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(12.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.LAND, "age": Look.LAND_RING_SEC * 0.5, "delay": 0.0,
		"life": Look.LAND_RING_SEC, "at": at})
	fv._process(0.0)
	t.eq(fv._g_v.size(), 48, "상륙 링은 바닥 정점 정확히 48개다 (8조각 x 6)")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다 — 상륙 링은 바닥의 것이다")
	t.eq(fv._decal.mesh.get_surface_count(), 1, "그리고 커밋됐다 — _fx_flush 를 지우면 버퍼만 남고 여기가 문다")
	var want := Look.COL_LAND_RING
	want.a *= 0.5
	t.ok(_cols_all_close(fv._g_c, want),
		"48개 전부 COL_LAND_RING 에 fade 0.5 를 실었다 — 바닥과 천장이 한 등식이다")
	var centre := _xz_centre_v3(fv._g_v)
	t.ok(centre.distance_to(at / Look.TILE_PX) < 0.02, "링의 중심이 상륙점이다")
	var outer := _max_dist_v3(fv._g_v, centre)
	t.ok(absf(outer - (20.0 + 2.5) / 40.0) < 0.03,
		"extent 가 반지름 20 + 굵기 절반이다 (%.3f 타일) — 반지름 0 으로 접힌 링은 여기서 문다" % outer)


## Item 5 — the area ring, AND the ground-following axis. The ring is the widest ground mark
## (r 42 px at half-life), so it is the one that crosses real slope: every vertex must sit at
## `_ground_y_px` of its own ground point.
## ⚠ The pairing closes both flattening mutations: flatten `_g_tri` and the per-vertex match bites;
## flatten `_ground_y_px` itself and the FIXTURE self-check (a real slope under the ring) bites,
## because the slope is measured through the same function.
func _the_area_ring_follows_the_ground(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	# The land tile whose surrounding ground slopes the most, found on the fixed-seed terrain — a
	# deterministic search, not a random one.
	var best := Vector2.ZERO
	var best_spread := 0.0
	for ty in range(3, ARENA_H - 3):
		for tx in range(3, ARENA_W - 3):
			var c := Look.tile_point_px(Vector2(tx, ty))
			var hs := [fv._ground_y_px(c + Vector2(42.0, 0.0)), fv._ground_y_px(c - Vector2(42.0, 0.0)),
				fv._ground_y_px(c + Vector2(0.0, 42.0)), fv._ground_y_px(c - Vector2(0.0, 42.0))]
			var spread := float(hs.max()) - float(hs.min())
			if spread > best_spread:
				best_spread = spread
				best = c
	t.ok(best_spread > 0.05, "링이 걸칠 진짜 비탈을 찾았다 (자가 점검, 높이차 %.3f 타일)" % best_spread)

	fv._fx.append({"kind": FieldView.FxKind.AREA, "age": Look.AREA_RING_SEC * 0.5, "delay": 0.0,
		"life": Look.AREA_RING_SEC, "at": best, "radius": 60.0})
	fv._process(0.0)
	# r = 60 · lerp(0.4, 1.0, 0.5) = 42 px ⇒ ceil(TAU·42 / 20) = 14 pieces = 84 vertices.
	t.eq(fv._g_v.size(), 84, "광역 링은 바닥 정점 정확히 84개다 (14조각 x 6, 반지름 42px)")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다")
	var want := Look.COL_AREA_RING
	want.a *= 0.5
	t.ok(_cols_all_close(fv._g_c, want), "84개 전부 COL_AREA_RING 에 fade 0.5 다")
	var flat := 0
	var y_min := 1e9
	var y_max := -1e9
	for v: Vector3 in fv._g_v:
		if absf(v.y - fv._ground_y_px(Vector2(v.x, v.z) * Look.TILE_PX)) > 0.001:
			flat += 1
		y_min = minf(y_min, v.y)
		y_max = maxf(y_max, v.y)
	t.eq(flat, 0, "모든 정점이 제 발밑 땅 높이에 있다 — 링이 비탈을 따라 올라간다")
	t.ok(y_max - y_min > 0.04, "그리고 링의 높이가 실제로 벌어져 있다 (%.3f 타일) — 평평하게 뭉개면 여기가 문다"
		% (y_max - y_min))


## The refusal mark — `speed-off-open-landing` 2.5's one-shot, at its fixed 26 px:
## ceil(TAU·26 / 20) = 9 pieces = **54 vertices**, `COL_LOSE` with the fade SET (not multiplied).
func _the_refusal_mark(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(10.0, 5.0))
	fv.note_refusal(at)
	var entry: Dictionary = fv._fx[fv._fx.size() - 1]
	entry["age"] = Look.REFUSE_MARK_SEC * 0.5
	fv._process(0.0)
	t.eq(fv._g_v.size(), 54, "거절 표시는 바닥 정점 정확히 54개다 (9조각 x 6)")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다")
	var want := Look.COL_LOSE
	want.a = 0.5
	t.ok(_cols_all_close(fv._g_c, want), "COL_LOSE 에 fade 0.5 — 알파가 곱해지는 게 아니라 fade 그 자체다")
	var centre := _xz_centre_v3(fv._g_v)
	t.ok(centre.distance_to(at / Look.TILE_PX) < 0.02, "표시의 중심이 거절당한 그 자리다")
	t.ok(absf(_max_dist_v3(fv._g_v, centre) - (26.0 + 2.5) / 40.0) < 0.03,
		"extent 가 후보 링(18px)과 갈리는 26px 다 — 거절이 후보로 안 읽힌다")


## Item 6 — one intent line, enemy to soldier, two tiles apart: 80 px at the intent's own coarse
## 120 px cut is ONE piece = **6 vertices**, wearing `COL_TARGET_LINE`'s deliberate 0.12 alpha.
func _the_intent_line(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([Rules.CELL_MELEE]), [_spawn(ARENA_W, Rules.BISON, 14, 6)], 999.0)
	_ashore(b, 0, Vector2(12.0, 6.0))
	b.enemy_target[0] = 0
	var fv := _view_of(b, rows)
	fv._process(0.0)
	t.eq(fv._g_v.size(), 6, "의도선 하나는 바닥 정점 정확히 6개다 — 성긴 120px 절단의 한 조각")
	t.eq(fv._a_v.size(), 0, "공중 버퍼는 조용하다")
	t.ok(_cols_all_close(fv._g_c, Look.COL_TARGET_LINE),
		"선이 COL_TARGET_LINE 그대로다 — 알파 0.12 는 일부러 희미한 면허다")
	var centre := _xz_centre_v3(fv._g_v)
	t.ok(centre.distance_to(Vector2(13.5, 6.5)) < 0.1, "선의 한가운데가 두 몸 사이다")


# == the air transients ===============================================================================

## Item 1 — the tracer: one camera-plane stub of **6 vertices**, `COL_SHOT` with NO fade, and a STUB
## — its whole extent stays far under the muzzle-to-target distance it sweeps.
func _the_tracer(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var from := Look.tile_point_px(Vector2(10.0, 6.0))
	var to := Look.tile_point_px(Vector2(14.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.SHOT, "age": Look.SHOT_SEC * 0.5, "delay": 0.0,
		"life": Look.SHOT_SEC, "from": from, "to": to})
	fv._process(0.0)
	t.eq(fv._a_v.size(), 6, "예광선은 공중 정점 정확히 6개다 — 토막 하나")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다 — 예광선은 공중의 것이다")
	t.eq(fv._air.mesh.get_surface_count(), 1, "그리고 커밋됐다")
	t.ok(_cols_all_close(fv._a_c, Look.COL_SHOT), "COL_SHOT 그대로다 — 예광선은 fade 가 없다")
	var longest := 0.0
	for i in fv._a_v.size():
		for j in range(i + 1, fv._a_v.size()):
			longest = maxf(longest, fv._a_v[i].distance_to(fv._a_v[j]))
	t.ok(longest > 0.28 and longest < 0.45,
		"토막의 최장 대각이 12px 길이 근처다 (%.3f 타일) — 전체 4타일 선을 그으면 레이저고, 0이면 접힌 것이다"
			% longest)


## Item 2② — the spark fan: six shards at half-life = 6 camera-plane segments = **36 vertices**,
## `COL_SPARK` with the fade as its alpha.
func _the_spark(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(12.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.SPARK, "age": Look.SPARK_SEC * 0.5, "delay": 0.0,
		"life": Look.SPARK_SEC, "at": at, "facing": Vector2.RIGHT})
	fv._process(0.0)
	t.eq(fv._a_v.size(), 36, "파편은 공중 정점 정확히 36개다 (조각 여섯 x 6)")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다")
	var want := Look.COL_SPARK
	want.a = 0.5
	t.ok(_cols_all_close(fv._a_c, want), "COL_SPARK 에 fade 0.5 다")


## Item 4 — the death burst, AND the camera-plane axis with a turn under it. The lion-sized ring at
## half-life is `FX_RING_SEGMENTS` 24 quads = **144 vertices**; every one lies in the camera's own
## plane, before AND after the board turns 45° — the number behind 「판을 돌려도 안 찌그러진다」.
func _the_death_burst_stands_in_the_camera_plane(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	var at := Look.tile_point_px(Vector2(12.0, 6.0))
	fv._fx.append({"kind": FieldView.FxKind.BURST, "age": Look.BURST_SEC * 0.5, "delay": 0.0,
		"life": Look.BURST_SEC, "at": at, "radius": 22.0, "colour": Look.COL_ENEMY})
	fv._process(0.0)
	t.eq(fv._a_v.size(), 144, "죽음 파열은 공중 정점 정확히 144개다 (24조각 x 6)")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다")
	var want := Look.COL_ENEMY
	want.a = 0.5
	t.ok(_cols_all_close(fv._a_c, want), "죽은 쪽의 제 색에 fade 0.5 다")
	var centre := _centre_v3(fv._a_v)
	var r_out := 0.0
	var r_in := 1e9
	for v: Vector3 in fv._a_v:
		r_out = maxf(r_out, v.distance_to(centre))
		r_in = minf(r_in, v.distance_to(centre))
	# ⚠ The picture is SPRITE-scaled (verify-look: the sim-radius ring never read under the 84 px
	# body piles): a 22 px body starts its ring at 22 x 3 = 66 px, so at half-life it stands at
	# 66 x 1.6 = 105.6 px plus half the 9 px stroke — (105.6 + 4.5) / 40 = **2.7525 tiles**, WIDER
	# than the sprite pile it has to read over. Hand arithmetic, re-derived with the scaling.
	t.ok(absf(r_out - 2.7525) < 0.03,
		"바깥 반지름이 스프라이트 반폭 66px 의 1.6 성장 + 굵기 절반이다 (%.3f 타일) — 더미 위로 읽힌다" % r_out)
	t.ok(r_in > 2.4, "안쪽 반지름도 0 이 아니다 — 접힌 링은 여기서 문다 (%.3f 타일)" % r_in)
	t.ok(is_equal_approx(Look.BURST_START_MUL, Look.BEAST_SPRITE_W_RATIO * 0.5),
		"시작 배수가 스프라이트 반폭 비율 그대로다 — 그림이 다시 커지는 날 파열이 같이 커진다")
	var plane_bad := _off_plane_count(fv._a_v, centre, fv._cam.transform.basis.z)
	t.eq(plane_bad, 0, "144개 전부 카메라 평면 위다")

	# The turn. The buffers rebuild on the next _process, the camera basis moves — and the ring must
	# have actually re-oriented (a stale buffer would pass the old basis and fail this pair).
	var before: Vector3 = fv._a_v[0]
	fv.turn_by(45.0)
	fv._process(0.0)
	t.eq(fv._a_v.size(), 144, "돌린 뒤에도 링은 그대로 144개다 (자가 점검)")
	t.ok(fv._a_v[0].distance_to(before) > 0.01, "그리고 정점이 실제로 움직였다 — 판을 따라 돈 것이다 (자가 점검)")
	var centre2 := _centre_v3(fv._a_v)
	t.eq(_off_plane_count(fv._a_v, centre2, fv._cam.transform.basis.z), 0,
		"45° 돌린 카메라의 평면 위에도 전부 서 있다 — 돌려도 안 찌그러진다")


## Item 3② — the hit halo, the area a hit is actually seen on: a camera-plane disc of 24 segments =
## **144 vertices**, `COL_HIT_HALO` with the flash's remaining fraction on its alpha.
func _the_hit_halo(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [_spawn(ARENA_W, Rules.BISON, 12, 6)], 999.0)
	var fv := _view_of(b, rows)
	fv._process(0.0)
	t.eq(fv._a_v.size(), 0, "맞은 적 없는 프레임에는 헤일로가 없다 (바닥 — 무조건 그리는 잎은 여기서 갈린다)")
	fv._body["e0"] = _body_entry(b.enemy_pos[0])
	(fv._body["e0"] as Dictionary)["flash"] = Look.HIT_FLASH_SEC * 0.5
	fv._process(0.0)
	t.eq(fv._a_v.size(), 144, "타격 헤일로는 공중 정점 정확히 144개다 (원판 24조각 x 6)")
	t.eq(fv._g_v.size(), 0, "바닥 버퍼는 조용하다")
	var want := Look.COL_HIT_HALO
	want.a *= 0.5
	t.ok(_cols_all_close(fv._a_c, want), "COL_HIT_HALO 에 남은 플래시 0.5 를 실었다")


# == the body-bound effects, on SURFACE 2 =============================================================
## Flash · lunge · knockback · gait squash never touch a buffer: they are written into the pooled
## sprite's own modulate / position / scale — the fields the engine consumes. Each is toggled on the
## SAME body against its own resting frame, so the row is the difference the effect makes.
func _body_effects_ride_the_pooled_fields(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [_spawn(ARENA_W, Rules.BISON, 12, 6)], 999.0)
	var fv := _view_of(b, rows)
	fv._body["e0"] = _body_entry(b.enemy_pos[0])
	fv._process(0.0)
	var body := _body_sprite(fv)
	t.ok(body != null, "적의 몸 스프라이트가 있다 (자가 점검)")
	var rest_mod: Color = body.modulate
	var rest_pos: Vector3 = body.position
	var rest_scale: Vector3 = body.scale
	t.eq(rest_mod, Look.beast_tint(Look.body_colour_of(true)), "쉬는 몸은 제 편 색이다 (자가 점검)")

	# Item 3① — the flash mixes COL_FLASH into the side colour before the team tint.
	(fv._body["e0"] as Dictionary)["flash"] = Look.HIT_FLASH_SEC * 0.5
	fv._process(0.0)
	var want_mod := Look.beast_tint(Look.body_colour_of(true).lerp(Look.COL_FLASH, Look.HIT_FLASH_STRENGTH))
	t.eq(_body_sprite(fv).modulate, want_mod, "플래시가 modulate 를 COL_FLASH 쪽으로 0.7 만큼 민다")
	t.ok(want_mod != rest_mod, "그리고 그 값은 쉬는 색과 실제로 다르다 (자가 점검)")
	(fv._body["e0"] as Dictionary)["flash"] = 0.0

	# Item 2① — the lunge at its peak pushes the whole body `push` px along its facing.
	var e0: Dictionary = fv._body["e0"]
	e0["lunge"] = Look.LUNGE_SEC * 0.5
	e0["lunge_dir"] = Vector2.RIGHT
	e0["push"] = 10.0
	fv._process(0.0)
	t.ok(absf(_body_sprite(fv).position.x - (rest_pos.x + 0.25)) < 0.001,
		"런지 꼭대기에서 몸이 정확히 10px(0.25타일) 앞으로 밀린다")
	e0["lunge"] = 0.0

	# Item 3③ — the knockback at half its window is half of HIT_KNOCK_PX, away from the striker.
	e0["knock"] = Look.HIT_KNOCK_SEC * 0.5
	e0["knock_dir"] = Vector2(0.0, 1.0)
	fv._process(0.0)
	t.ok(absf(_body_sprite(fv).position.z - (rest_pos.z + 1.5 / 40.0)) < 0.001,
		"넉백 반창에서 몸이 정확히 1.5px 뒤로 밀려 있다")
	e0["knock"] = 0.0

	# Item 12 — the gait squash: 0.8 along the heading, 1.2 across it, carried on scale.
	e0["gait"] = TAU * 0.25
	e0["head"] = Vector2.RIGHT
	fv._process(0.0)
	var squashed := _body_sprite(fv)
	t.ok(absf(squashed.scale.x - rest_scale.x * 0.8) < 0.0001
			and absf(squashed.scale.y - rest_scale.y * 1.2) < 0.0001,
		"걸음 스쿼시가 scale 에 (0.8, 1.2) 로 실린다 — 서 있으면 sin(0)=0 이라 안 찌그러진다")


# == the sailing boat's remaining route (the caller `_route_ahead` lost) ==============================
## Ticket 09's own founding shape, closed: the line was computed every frame and drawn by nobody.
## `_paint_boat_routes` now feeds it to the floor layer — the SIM's own `leg` decides what is behind
## the boat, and the drawn water shrinks as the crossing advances.
func _the_boat_route_shrinks_with_the_sim(t) -> void:
	var rows := _port()
	# ⚠ One idle enemy far inland, or there is nothing to win against: a battle with zero enemies
	# latches WON on its first step and the boat freezes mid-bay — measured, 4000 sub-steps of leg 0.
	var b := _planning_battle_of(rows, _army_of([Rules.CELL_MELEE]),
		[_spawn(ARENA_W, Rules.BISON, 20, 9)], 999.0)
	var fv := _view_of(b, rows)
	# The sendable tile FARTHEST from the harbour, so the route holds interior waypoints and the
	# crossing lasts long enough for `leg` to advance while the boat is still at sea.
	var target := -1
	var far := 0.0
	for tile in b.grid.passable.size():
		if b.grid.home_harbour_for(tile) < 0:
			continue
		var d := absf(float(tile % ARENA_W) - 2.0) + absf(float(tile / ARENA_W) - 5.0)
		if d > far:
			far = d
			target = tile
	t.ok(target >= 0 and far >= 4.0 and b.send(0, target) >= 0,
		"항구에서 먼 곳으로 한 척을 보냈다 (자가 점검, 맨해튼 %.0f)" % far)

	# Before the commit the boat is its plan: no aim is armed, so the water carries NO route at all.
	fv._process(0.0)
	t.eq(_verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE).size(), 0,
		"확정 전에는 항로선이 없다 — 배는 아직 계획이고 물은 계획의 것이다")

	t.ok(b.commit(), "확정했다 (자가 점검)")
	fv._process(0.0)
	var boat: Dictionary = b.boats[0]
	var path: PackedVector2Array = boat["path"]
	t.ok(path.size() >= 3, "항로에 경유점이 있다 (자가 점검, %d점)" % path.size())
	var route0 := _verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE)
	t.ok(route0.size() >= 12, "확정하자 남은 항로선이 바닥에 깔렸다 (%d 정점)" % route0.size())
	var missing := 0
	for k in range(1, path.size()):
		if _min_dist(route0, Look.tile_point_px(path[k]) / Look.TILE_PX) > 0.3:
			missing += 1
	t.eq(missing, 0, "모든 남은 경유점 곁에 정점이 있다 — 선이 sim 의 path 그대로다")
	t.ok(_min_dist(route0, Look.tile_point_px(Vector2(boat["pos"])) / Look.TILE_PX) < 0.2,
		"선의 머리가 선체 제 자리다")

	# Sail. The sim's `leg` advances; the drawn line must let go of the water already crossed.
	var guard := 0
	while guard < 4000:
		b.begin_frame()
		b.step(Rules.SIM_SUBSTEP_SEC)
		guard += 1
		if int(boat["phase"]) != Battle.Phase.OUTBOUND:
			break
		if int(boat["leg"]) >= 1 \
				and Vector2(boat["pos"]).distance_to(path[1]) > 1.5:
			break
	t.ok(int(boat["phase"]) == Battle.Phase.OUTBOUND and int(boat["leg"]) >= 1,
		"아직 항해 중인 채로 첫 경유점을 지났다 (자가 점검, leg %d)" % int(boat["leg"]))
	b.begin_frame()
	fv._process(0.0)
	var route1 := _verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE)
	t.ok(route1.size() < route0.size(),
		"가면서 선이 줄었다 (%d -> %d 정점) — 이미 지나온 물을 다시 안 그린다" % [route0.size(), route1.size()])
	t.ok(_min_dist(route1, Look.tile_point_px(path[1]) / Look.TILE_PX) > 0.8,
		"지나온 경유점 곁에는 더 이상 정점이 없다")
	t.ok(_min_dist(route1, Look.tile_point_px(Vector2(boat["pos"])) / Look.TILE_PX) < 0.2,
		"머리는 여전히 선체 자리를 따라간다")


# == the dry slot draws no plan (the fork the user closed: 「추천대로」) ================================
## ⚠ Mutation: delete `_paint_plan`'s reserve gate — the control half (a WET slot draws the refuse
## ring) proves the zero below is the gate and not a dead plan layer.
func _a_dry_slot_draws_no_plan(t) -> void:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _planning_battle_of(rows, _army_of([Rules.CELL_MELEE]), [], 999.0)
	var fv := _view_of(b, rows)
	# Aim at open water (the border ring). This arena has no summon band, so the aim is REFUSED
	# water — which draws the COL_LOSE ring: ceil(TAU·18 / 20) = 6, floored to 8 segments = 48 verts.
	var aim := 0 * ARENA_W + 5
	t.ok(b.grid.water[aim] != 0 and not b.grid.can_summon_at(aim), "띠 밖 물칸이다 (자가 점검)")
	fv.set_summon_aim(0, aim)
	fv._process(0.0)
	var wet_ring := _verts_of(fv._g_v, fv._g_c, Look.COL_LOSE)
	t.eq(wet_ring.size(), 48, "예비가 남은 슬롯의 조준은 거절 색 링 48 정점을 그린다 (대조군)")

	# Drain the slot — the only body goes TRANSIT — and the same aim must draw NOTHING.
	b.soldier_state[0] = Battle.SoldierState.TRANSIT
	t.eq(b.slot_reserve_ids(0).size(), 0, "슬롯이 말랐다 (자가 점검)")
	fv._process(0.0)
	t.eq(_verts_of(fv._g_v, fv._g_c, Look.COL_LOSE).size()
			+ _verts_of(fv._g_v, fv._g_c, Look.COL_WIN).size()
			+ _verts_of(fv._g_v, fv._g_c, Look.COL_ROUTE).size(), 0,
		"마른 슬롯은 링도 항로도 안 그린다 — sim 이 거절할 약속을 화면이 하지 않는다 (복원된 옛 규칙)")


## The ceiling on the transient drawer: `_drain_events` drops the oldest past `FX_MAX_COUNT`, so a
## refusal storm cannot pile geometry without bound.
func _the_transient_drawer_is_capped(t) -> void:
	var fx := _quiet_view()
	var fv: FieldView = fx["fv"]
	for _k in Look.FX_MAX_COUNT + 44:
		fv.note_refusal(Look.tile_point_px(Vector2(10.0, 5.0)))
	fv._process(0.0)
	t.eq(fv._fx.size(), Look.FX_MAX_COUNT,
		"일시 연출 서랍은 FX_MAX_COUNT 에서 잘린다 — 가장 오래된 것이 나간다")


# == the readers themselves ===========================================================================
## Cases that fail the INSTRUMENT rather than the tree — a colour filter that never matches reads
## exactly like a quiet frame, and a bounding box of zero extent still returns the right centre.
func _the_readers_themselves(t) -> void:
	var v := PackedVector3Array([Vector3(1, 0, 1), Vector3(3, 0, 3), Vector3(5, 0, 5)])
	var c := PackedColorArray([Color.RED, Color.BLUE, Color.RED])
	t.eq(_verts_of(v, c, Color.RED).size(), 2, "색 필터가 그 색만 고른다 (계기 자가 점검)")
	t.eq(_verts_of(v, c, Color.GREEN).size(), 0, "없는 색이면 0이다 — 조용한 프레임과 똑같이 읽힌다는 뜻이다")
	t.eq(_verts_of(PackedVector3Array(), PackedColorArray(), Color.RED).size(), 0,
		"빈 버퍼면 0이다 (계기 자가 점검)")
	var folded := PackedVector3Array([Vector3(2, 0, 2), Vector3(2, 0, 2), Vector3(2, 0, 2)])
	t.ok(_xz_centre_v3(folded).distance_to(Vector2(2, 2)) < 0.001
			and _max_dist_v3(folded, Vector2(2, 2)) == 0.0,
		"접힌 기하는 중심이 맞고 extent 가 0이다 — extent 를 같이 재는 이유다 (계기 자가 점검)")


# == fixtures =========================================================================================

## Water border, land inside — `net_fx`'s own arena shape.
func _open(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		if y == 0 or y == h - 1:
			rows.append("~".repeat(w))
		else:
			rows.append("~" + ".".repeat(w - 2) + "~")
	return rows


## A bay: rows 3-7 water for the first six columns, land from column 6 on, one harbour at (2,5) —
## `net_fx`'s port, for the rows that need a real boat.
func _port() -> Array:
	var rows := _open(ARENA_W, ARENA_H)
	for y in range(3, 8):
		rows[y] = "~~~~~~" + ".".repeat(ARENA_W - 7) + "~"
	rows[5] = "~~H~~~" + ".".repeat(ARENA_W - 7) + "~"
	return rows


func _army_of(types: Array) -> Army:
	var a := Army.new()
	for raw in types:
		for s in Rules.summon_slot_count():
			if Rules.summon_type_of(s) == int(raw):
				a.recruit(s)
				break
	return a


func _spawn(w: int, type_id: int, x: int, y: int) -> Dictionary:
	return {"type_id": type_id, "tile": y * w + x}


## Committed directly, `net_fx`'s own idiom: an uncommitted battle is inert to every driver and the
## commit gate itself is `net_plan`'s to measure.
func _battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var b := _planning_battle_of(rows, army, spawns, limit)
	b._committed = true
	return b


func _planning_battle_of(rows: Array, army: Army, spawns: Array, limit: float) -> Battle:
	var g := Grid.new()
	g.load_rows(rows)
	var b := Battle.new()
	b.setup(g, army, spawns, limit)
	return b


## Ashore the way a landing leaves a soldier — state, position, goal AND the tile reservation
## (`net_fx`'s helper: state alone teleports the unit back to its stale goal on the first move).
func _ashore(b: Battle, i: int, p: Vector2) -> void:
	b.soldier_state[i] = Battle.SoldierState.ASHORE
	b.soldier_pos[i] = p
	b._soldier_goal[i] = p
	var claimed := b.grid.reserved
	claimed[int(round(p.y)) * b.grid.w + int(round(p.x))] = i
	b.grid.reserved = claimed


func _view_of(b: Battle, rows: Array) -> FieldView:
	var fv := FieldView.new()
	_created.append(fv)
	fv.setup(b, b.army, rows)
	return fv


## An empty committed arena and its view — the fixture every pure-transient row starts from. A quiet
## control frame runs here, and the rows' EXACT counts are what make it bite: geometry left over
## from a leaf firing unconditionally breaks every equality at once.
func _quiet_view() -> Dictionary:
	var rows := _open(ARENA_W, ARENA_H)
	var b := _battle_of(rows, _army_of([]), [], 999.0)
	var fv := _view_of(b, rows)
	fv._process(0.0)
	return {"fv": fv, "b": b}


## A complete per-body drawer entry, every key `_paint_bodies` reads — injected whole so a fixture
## can light one clock without `_fx_step` refusing to create the rest. ⚠ `last` must be the body's
## OWN position: gait phase turns on distance travelled, and a stale `last` hands the first frame a
## twelve-tile step and a squash nobody asked for.
func _body_entry(at: Vector2) -> Dictionary:
	return {"flash": 0.0, "knock": 0.0, "knock_dir": Vector2.RIGHT, "lunge": 0.0,
		"lunge_dir": Vector2.RIGHT, "push": 0.0, "gait": 0.0, "head": Vector2.RIGHT,
		"last": at}


## The first pooled body sprite — anything not wearing the one-texel bar texture.
func _body_sprite(fv: FieldView) -> Sprite3D:
	for k in fv._sprites_used:
		var s: Sprite3D = fv._sprites[k]
		if s.texture != fv._tex_flat:
			return s
	return null


# == readers ==========================================================================================

## The vertices wearing exactly `col`, on the ground plane (x, z) in tile units.
func _verts_of(v: PackedVector3Array, c: PackedColorArray, col: Color) -> Array:
	var out := []
	for k in v.size():
		if _col_close(c[k], col):
			out.append(Vector2(v[k].x, v[k].z))
	return out


## ⚠ 0.0045 and not tighter, MEASURED: a committed `ArrayMesh` stores vertex colour in 8 bits and
## TRUNCATES (0.235 comes back 0.2314 — a full 1/255 off, not half). The fx buffers hold full floats
## and every pair of look.gd tones this file separates sits far outside 0.0045.
func _col_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0045 and absf(a.g - b.g) < 0.0045 \
		and absf(a.b - b.b) < 0.0045 and absf(a.a - b.a) < 0.0045


func _cols_all_close(cols: PackedColorArray, want: Color) -> bool:
	if cols.is_empty():
		return false
	for c in cols:
		if not _col_close(c, want):
			return false
	return true


func _xz_centre_v3(v: PackedVector3Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in v:
		sum += Vector2(p.x, p.z)
	return sum / float(maxi(1, v.size()))


func _max_dist_v3(v: PackedVector3Array, from: Vector2) -> float:
	var out := 0.0
	for p in v:
		out = maxf(out, Vector2(p.x, p.z).distance_to(from))
	return out


func _centre_v3(v: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in v:
		sum += p
	return sum / float(maxi(1, v.size()))


func _min_dist(pts: Array, from: Vector2) -> float:
	var out := 1e9
	for p: Vector2 in pts:
		out = minf(out, p.distance_to(from))
	return out


## How many vertices sit measurably OFF the plane through `centre` perpendicular to `normal`.
func _off_plane_count(v: PackedVector3Array, centre: Vector3, normal: Vector3) -> int:
	var out := 0
	for p in v:
		if absf((p - centre).dot(normal)) > 0.001:
			out += 1
	return out


## The mesh vertices whose colour is exactly `col` — the terrain rows' reader.
func _mesh_verts_of(verts: PackedVector3Array, cols: PackedColorArray, col: Color) -> Array:
	var out := []
	for k in verts.size():
		if _col_close(cols[k], col):
			out.append(verts[k])
	return out


func _inside_tile(v: Vector3, tx: int, ty: int) -> bool:
	return v.x >= float(tx) - 0.001 and v.x <= float(tx) + 1.001 \
		and v.z >= float(ty) - 0.001 and v.z <= float(ty) + 1.001


func _all_inside_tile(verts: Array, tx: int, ty: int) -> bool:
	if verts.is_empty():
		return false
	for v: Vector3 in verts:
		if not _inside_tile(v, tx, ty):
			return false
	return true
